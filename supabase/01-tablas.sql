-- =====================================================================
-- Sistema de pedidos para cafeterías: tablas y seguridad en Supabase
-- Se pega completo en Supabase → SQL Editor → New query → Run.
-- Se puede volver a correr sin perder datos: solo crea lo que falta.
-- No contiene claves ni datos de clientes.
-- =====================================================================

-- ---------- Tablas ----------

-- Cada cafetería o restaurante que usa el sistema
create table if not exists public.negocios (
  id             uuid primary key default gen_random_uuid(),
  nombre         text not null,
  ciudad         text not null default 'Lima',
  mesas          int  not null default 5 check (mesas between 0 and 200),
  ultimo_numero  int  not null default 0,          -- contador de pedidos
  creado         timestamptz not null default now()
);

-- Trabajadores con cuenta: quién es y qué rol tiene en cada negocio
create table if not exists public.miembros (
  negocio_id  uuid not null references public.negocios(id) on delete cascade,
  user_id     uuid not null references auth.users(id) on delete cascade,
  nombre      text not null,
  rol         text not null check (rol in ('dueno','cajero','mesero','cocina','moto')),
  activo      boolean not null default true,
  creado      timestamptz not null default now(),
  primary key (negocio_id, user_id)
);
create index if not exists miembros_user_idx on public.miembros(user_id);

-- El Dueño crea un código para cada trabajador; sirve una vez y vence en 7 días
create table if not exists public.invitaciones (
  codigo      text primary key default upper(substr(replace(gen_random_uuid()::text,'-',''),1,8)),
  negocio_id  uuid not null references public.negocios(id) on delete cascade,
  nombre      text not null,
  rol         text not null check (rol in ('cajero','mesero','cocina','moto')),
  creado      timestamptz not null default now(),
  vence       timestamptz not null default now() + interval '7 days'
);
create index if not exists invitaciones_negocio_idx on public.invitaciones(negocio_id);

-- Carta: categorías y productos (lo demás de cada uno va en "datos")
create table if not exists public.categorias (
  negocio_id  uuid not null references public.negocios(id) on delete cascade,
  id          text not null,
  nombre      text not null,
  oculta      boolean not null default false,
  orden       int not null default 0,
  datos       jsonb not null default '{}'::jsonb,  -- azúcar, temperatura, extras
  primary key (negocio_id, id)
);

create table if not exists public.productos (
  negocio_id  uuid not null references public.negocios(id) on delete cascade,
  id          text not null,
  cat         text not null,
  nombre      text not null,
  precio      numeric(10,2) not null check (precio >= 0),
  agotado     boolean not null default false,
  oculto      boolean not null default false,
  orden       int not null default 0,
  datos       jsonb not null default '{}'::jsonb,  -- descripción, opciones
  primary key (negocio_id, id)
);

-- Clientes de delivery, por celular
create table if not exists public.clientes (
  negocio_id  uuid not null references public.negocios(id) on delete cascade,
  cel         text not null,
  datos       jsonb not null default '{}'::jsonb,  -- nombre, dirección, referencia, ubicación
  actualizado timestamptz not null default now(),
  primary key (negocio_id, cel)
);

-- Pedidos (también los anulados). El detalle completo va en "datos".
create table if not exists public.pedidos (
  negocio_id  uuid not null references public.negocios(id) on delete cascade,
  id          text not null,
  n           int,                                  -- número del pedido, lo pone la base de datos
  tipo        text not null check (tipo in ('mesa','llevar','delivery','recoger')),
  mesa        int,
  estado      text not null default 'nuevo' check (estado in ('nuevo','preparando','listo','en_camino','entregado')),
  pagado      boolean not null default false,
  anulado     boolean not null default false,
  datos       jsonb not null default '{}'::jsonb,  -- productos, cliente, pago, ediciones
  creado      timestamptz not null default now(),
  actualizado timestamptz not null default now(),
  creado_por  uuid default auth.uid(),
  primary key (negocio_id, id)
);
create index if not exists pedidos_dia_idx on public.pedidos(negocio_id, creado desc);
create index if not exists pedidos_abiertos_idx on public.pedidos(negocio_id) where not pagado and not anulado;

-- Estado de cada mesa: pidió la cuenta, separada (reserva) o unida a otra
create table if not exists public.mesas_estado (
  negocio_id  uuid not null references public.negocios(id) on delete cascade,
  mesa        int not null,
  cuenta      boolean not null default false,
  reserva     jsonb,                                -- {nombre, hora, personas}
  unida_a     int,                                  -- mesa principal si está unida
  actualizado timestamptz not null default now(),
  primary key (negocio_id, mesa),
  check (unida_a is null or unida_a <> mesa)
);

-- ---------- Funciones de ayuda para la seguridad ----------

-- ¿El usuario que entró trabaja en este negocio?
create or replace function public.es_miembro(neg uuid)
returns boolean language sql stable security definer set search_path = '' as $$
  select exists (
    select 1 from public.miembros m
    where m.negocio_id = neg and m.user_id = auth.uid() and m.activo
  );
$$;

-- Rol del usuario que entró en este negocio (o nada)
create or replace function public.mi_rol(neg uuid)
returns text language sql stable security definer set search_path = '' as $$
  select m.rol from public.miembros m
  where m.negocio_id = neg and m.user_id = auth.uid() and m.activo;
$$;

-- ---------- Funciones que llama la página ----------

-- Crea un negocio nuevo y deja como Dueño a quien lo crea
create or replace function public.crear_negocio(p_nombre text, p_ciudad text, p_mesas int, p_mi_nombre text)
returns uuid language plpgsql security definer set search_path = '' as $$
declare nuevo uuid;
begin
  if auth.uid() is null then raise exception 'Primero inicie sesión'; end if;
  if coalesce(trim(p_nombre),'') = '' then raise exception 'Falta el nombre del negocio'; end if;
  insert into public.negocios(nombre, ciudad, mesas)
    values (trim(p_nombre), coalesce(nullif(trim(p_ciudad),''),'Lima'), coalesce(p_mesas,5))
    returning id into nuevo;
  insert into public.miembros(negocio_id, user_id, nombre, rol)
    values (nuevo, auth.uid(), coalesce(nullif(trim(p_mi_nombre),''),'Dueño'), 'dueno');
  return nuevo;
end $$;

-- El trabajador escribe su código y queda unido al negocio con su rol
create or replace function public.usar_codigo(p_codigo text)
returns uuid language plpgsql security definer set search_path = '' as $$
declare inv public.invitaciones%rowtype;
begin
  if auth.uid() is null then raise exception 'Primero inicie sesión'; end if;
  select * into inv from public.invitaciones
    where codigo = upper(trim(p_codigo)) and vence > now();
  if not found then raise exception 'Código no válido o vencido. Pídale uno nuevo al dueño.'; end if;
  insert into public.miembros(negocio_id, user_id, nombre, rol)
    values (inv.negocio_id, auth.uid(), inv.nombre, inv.rol)
    on conflict (negocio_id, user_id) do update set rol = excluded.rol, nombre = excluded.nombre, activo = true
      where public.miembros.rol <> 'dueno';  -- nunca le quita el rol de Dueño a nadie
  delete from public.invitaciones where codigo = inv.codigo;
  return inv.negocio_id;
end $$;

-- ---------- Automatismos ----------

-- Número de pedido correlativo por negocio, sin repetirse aunque dos equipos envíen a la vez
create or replace function public.numerar_pedido()
returns trigger language plpgsql security definer set search_path = '' as $$
begin
  update public.negocios set ultimo_numero = ultimo_numero + 1
    where id = new.negocio_id returning ultimo_numero into new.n;
  return new;
end $$;
drop trigger if exists pedidos_numero on public.pedidos;
create trigger pedidos_numero before insert on public.pedidos
  for each row execute function public.numerar_pedido();

-- Fecha de la última modificación
create or replace function public.marcar_actualizado()
returns trigger language plpgsql set search_path = '' as $$
begin new.actualizado = now(); return new; end $$;
drop trigger if exists pedidos_actualizado on public.pedidos;
create trigger pedidos_actualizado before update on public.pedidos
  for each row execute function public.marcar_actualizado();
drop trigger if exists mesas_actualizado on public.mesas_estado;
create trigger mesas_actualizado before update on public.mesas_estado
  for each row execute function public.marcar_actualizado();
drop trigger if exists clientes_actualizado on public.clientes;
create trigger clientes_actualizado before update on public.clientes
  for each row execute function public.marcar_actualizado();

-- ---------- Seguridad por fila: cada negocio ve solo lo suyo ----------

alter table public.negocios      enable row level security;
alter table public.miembros      enable row level security;
alter table public.invitaciones  enable row level security;
alter table public.categorias    enable row level security;
alter table public.productos     enable row level security;
alter table public.clientes      enable row level security;
alter table public.pedidos       enable row level security;
alter table public.mesas_estado  enable row level security;

-- Negocio: lo ven sus trabajadores; solo el Dueño cambia nombre, ciudad y mesas
drop policy if exists negocio_ver on public.negocios;
create policy negocio_ver on public.negocios for select to authenticated using (public.es_miembro(id));
drop policy if exists negocio_editar on public.negocios;
create policy negocio_editar on public.negocios for update to authenticated
  using (public.mi_rol(id) = 'dueno') with check (public.mi_rol(id) = 'dueno');

-- Personal: lo ven todos; el Dueño lo maneja, pero no puede quitarse ni cambiarse a sí mismo
drop policy if exists miembros_ver on public.miembros;
create policy miembros_ver on public.miembros for select to authenticated using (public.es_miembro(negocio_id));
drop policy if exists miembros_editar on public.miembros;
create policy miembros_editar on public.miembros for update to authenticated
  using (public.mi_rol(negocio_id) = 'dueno' and user_id <> auth.uid())
  with check (public.mi_rol(negocio_id) = 'dueno' and user_id <> auth.uid());
drop policy if exists miembros_quitar on public.miembros;
create policy miembros_quitar on public.miembros for delete to authenticated
  using (public.mi_rol(negocio_id) = 'dueno' and user_id <> auth.uid());

-- Invitaciones (códigos): solo el Dueño
drop policy if exists invitaciones_dueno on public.invitaciones;
create policy invitaciones_dueno on public.invitaciones for all to authenticated
  using (public.mi_rol(negocio_id) = 'dueno') with check (public.mi_rol(negocio_id) = 'dueno');

-- Carta: la ven todos; solo el Dueño la cambia
drop policy if exists categorias_ver on public.categorias;
create policy categorias_ver on public.categorias for select to authenticated using (public.es_miembro(negocio_id));
drop policy if exists categorias_dueno on public.categorias;
create policy categorias_dueno on public.categorias for all to authenticated
  using (public.mi_rol(negocio_id) = 'dueno') with check (public.mi_rol(negocio_id) = 'dueno');
drop policy if exists productos_ver on public.productos;
create policy productos_ver on public.productos for select to authenticated using (public.es_miembro(negocio_id));
drop policy if exists productos_dueno on public.productos;
create policy productos_dueno on public.productos for all to authenticated
  using (public.mi_rol(negocio_id) = 'dueno') with check (public.mi_rol(negocio_id) = 'dueno');

-- Clientes, pedidos y mesas: los trabajadores del negocio los ven y los cambian.
-- Los pedidos no se borran (se anulan); solo el Dueño puede borrarlos.
drop policy if exists clientes_equipo on public.clientes;
create policy clientes_equipo on public.clientes for all to authenticated
  using (public.es_miembro(negocio_id)) with check (public.es_miembro(negocio_id));
drop policy if exists pedidos_ver on public.pedidos;
create policy pedidos_ver on public.pedidos for select to authenticated using (public.es_miembro(negocio_id));
drop policy if exists pedidos_crear on public.pedidos;
create policy pedidos_crear on public.pedidos for insert to authenticated with check (public.es_miembro(negocio_id));
drop policy if exists pedidos_editar on public.pedidos;
create policy pedidos_editar on public.pedidos for update to authenticated
  using (public.es_miembro(negocio_id)) with check (public.es_miembro(negocio_id));
drop policy if exists pedidos_borrar on public.pedidos;
create policy pedidos_borrar on public.pedidos for delete to authenticated using (public.mi_rol(negocio_id) = 'dueno');
drop policy if exists mesas_equipo on public.mesas_estado;
create policy mesas_equipo on public.mesas_estado for all to authenticated
  using (public.es_miembro(negocio_id)) with check (public.es_miembro(negocio_id));

-- ---------- Permisos: nada para quien no inició sesión ----------

-- Supabase da todos los permisos por defecto; se quitan y se dan solo los necesarios
revoke all on public.negocios, public.miembros, public.invitaciones, public.categorias,
  public.productos, public.clientes, public.pedidos, public.mesas_estado
  from anon, authenticated;
grant select, insert, update, delete on
  public.miembros, public.categorias,
  public.productos, public.clientes, public.mesas_estado
  to authenticated;
-- El negocio solo se crea con crear_negocio y el contador solo lo cambia la base de datos
grant select on public.negocios to authenticated;
grant update (nombre, ciudad, mesas) on public.negocios to authenticated;
-- El número del pedido y su negocio no se cambian desde la página
grant select, delete on public.pedidos to authenticated;
grant insert (negocio_id, id, tipo, mesa, estado, pagado, anulado, datos, creado) on public.pedidos to authenticated;
grant update (tipo, mesa, estado, pagado, anulado, datos) on public.pedidos to authenticated;
-- Invitaciones: el código lo pone la base de datos
grant select, delete on public.invitaciones to authenticated;
grant insert (negocio_id, nombre, rol) on public.invitaciones to authenticated;

revoke execute on function public.es_miembro(uuid), public.mi_rol(uuid),
  public.crear_negocio(text,text,int,text), public.usar_codigo(text),
  public.numerar_pedido(), public.marcar_actualizado() from public, anon;
grant execute on function public.es_miembro(uuid), public.mi_rol(uuid),
  public.crear_negocio(text,text,int,text), public.usar_codigo(text) to authenticated;

-- ---------- Tiempo real: avisar al instante a los otros equipos ----------

do $$
declare t text;
begin
  foreach t in array array['pedidos','mesas_estado','productos','categorias','negocios'] loop
    if not exists (select 1 from pg_publication_tables
                   where pubname = 'supabase_realtime' and schemaname = 'public' and tablename = t) then
      execute format('alter publication supabase_realtime add table public.%I', t);
    end if;
  end loop;
end $$;

-- Listo. Debería ver "Success. No rows returned".
