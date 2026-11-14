-- =====================================================================
-- Cambio 2: los trabajadores se unen con un código, no por correo
-- (el correo gratis de Supabase solo llega al equipo del proyecto).
-- Se pega completo en Supabase → SQL Editor → New query → Run.
-- Se puede volver a correr. Borra solo las invitaciones pendientes.
-- =====================================================================

drop function if exists public.aceptar_invitaciones();
drop table if exists public.invitaciones;

-- El Dueño crea un código para cada trabajador; sirve una vez y vence en 7 días
create table public.invitaciones (
  codigo      text primary key default upper(substr(replace(gen_random_uuid()::text,'-',''),1,8)),
  negocio_id  uuid not null references public.negocios(id) on delete cascade,
  nombre      text not null,
  rol         text not null check (rol in ('cajero','mesero','cocina','moto')),
  creado      timestamptz not null default now(),
  vence       timestamptz not null default now() + interval '7 days'
);
create index if not exists invitaciones_negocio_idx on public.invitaciones(negocio_id);

alter table public.invitaciones enable row level security;
drop policy if exists invitaciones_dueno on public.invitaciones;
create policy invitaciones_dueno on public.invitaciones for all to authenticated
  using (public.mi_rol(negocio_id) = 'dueno') with check (public.mi_rol(negocio_id) = 'dueno');

revoke all on public.invitaciones from anon, authenticated;
grant select, delete on public.invitaciones to authenticated;
grant insert (negocio_id, nombre, rol) on public.invitaciones to authenticated;

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
revoke execute on function public.usar_codigo(text) from public, anon;
grant execute on function public.usar_codigo(text) to authenticated;

-- Listo. Debería ver "Success. No rows returned".
