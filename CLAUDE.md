# Sistema de pedidos para cafeterías: guía de continuación

Prototipo de un sistema interno de pedidos para cafeterías y restaurantes pequeños en Perú. El dueño quiere probarlo y,
más adelante, ofrecerlo a varios negocios.

El dueño no es programador. Explícale en español sencillo, trátalo de "usted", paso a paso, y que él haga los clics en
GitHub, Supabase y similares. Nunca pidas ni escribas contraseñas o claves en el chat ni en archivos. Este repositorio
es público: no guardes aquí datos reales de clientes ni secretos.

## Dónde vive cada cosa

| Parte | Dónde |
|---|---|
| Sistema | `index.html` de este repositorio: todo en un archivo (HTML, CSS y JavaScript) |
| Enlace público | https://limafiestasyeventos-pixel.github.io/cafe-demo/ (GitHub Pages, rama `main`) |
| Diagrama, PDF y su generador | Repositorio privado `limafiestasyeventos-pixel/cafe-demo-docs`; lee su README |
| Datos de la demostración | `localStorage`, clave `cafe-demo-v1`. Cada navegador tiene los suyos |
| Cuentas, negocios y personal | Supabase, proyecto `cafe-demo`, plan gratis, región Este de EE. UU. (la pantalla nueva no ofreció São Paulo) |
| Pedidos y carta con cuenta | Todavía en `localStorage`, clave `cafe-real-<negocio_id>`, hasta la etapa 3 |
| SQL de Supabase | `supabase/01-tablas.sql` (instalación completa) y `02-invitaciones-con-codigo.sql` (cambio ya aplicado o por aplicar en el proyecto del dueño) |

## Cómo trabajar y publicar

1. Antes de empezar: `git pull`. No editar en dos computadoras a la vez.
2. Editar `index.html`. La demostración no usa la base de datos y debe seguir funcionando sin internet.
3. Revisar la sintaxis: extraer lo que hay entre `<script>` y `</script>` y correr `node --check`.
4. Probar en tamaño laptop (1300 × 760) y celular (375 × 812). Usar Dueño para ver todas las pantallas. Para probar
   el acceso sin crear cuentas en Supabase, usar una copia `_prueba-*.html` con un Supabase simulado y borrarla al terminar.
   Los cambios de SQL se prueban con PGlite (`@electric-sql/pglite`) antes de dárselos al dueño.
5. `git add index.html`, commit en español y `git push origin main`. GitHub Pages tarda uno o dos minutos.
6. Si un cambio afecta el flujo, actualizar el diagrama y el PDF en `cafe-demo-docs`.

Si cambias datos guardados, agrega la conversión en `migrate()`: el dueño tiene pedidos y ajustes en sus navegadores.

## Pantallas y roles

| Rol | Pantallas |
|---|---|
| Dueño | Mesas, Delivery, Tickets, Cocina, Moto, Caja, Admin |
| Caja | Mesas, Delivery, Tickets, Caja |
| Mesero | Mesas |
| Cocina | Cocina |
| Repartidor | Moto |

**Acceso (etapa 2, hecha):** la página abre en "Entrar". Hay dos caminos:
- **Ver la demostración:** datos de ejemplo en el aparato; el rol se elige a mano (`cafe-modo=demo` en `localStorage`).
- **Cuenta:** correo y contraseña de Supabase. Sin negocio, la persona crea el suyo (queda como Dueño, `crear_negocio`)
  o escribe un código de invitación (`usar_codigo`). El rol lo pone el dueño en Admin → Personal; no se elige a mano.
- Invitaciones por **código** de 8 caracteres (un uso, vence en 7 días) que el dueño envía por WhatsApp. No se usa correo:
  el correo gratis de Supabase solo llega al equipo del proyecto (2 por hora). Por eso "Confirm email" va **apagado**.
- La clave `sb_publishable_…` está en `index.html` a propósito (es pública). La secreta nunca.

## Decisiones del dueño (respetarlas)

**Tipos de pedido**
- Mesa y Para llevar: los toma el mesero o Caja, con el cliente en el local.
- Delivery y Recoger: los toma quien atiende WhatsApp, en la laptop. Recoger pide solo el nombre.
- El pedido de Recoger lo puede entregar el mesero o Caja.
- Separar mesa: lo hacen Caja o Dueño, con nombre y hora. Una separación por mesa y solo en mesas libres.
- Unir mesas (grupos grandes): desde una mesa se juntan otras mesas libres (`S.uniones`: mesa unida → principal). Queda
  "Mesa 2 + 3", con una sola cuenta y comanda a nombre de la principal. Al cobrar se separan solas; "Separar mesas" las
  libera y la cuenta queda en la principal. No se unen mesas ocupadas ni separadas.

**Asistente de delivery: 3 pasos**
- Cliente, Productos y Pago.
- Costo de delivery: un solo campo, decidido en cada pedido según su tamaño. Se puede poner en el paso 1 o en Pago, y es
  obligatorio antes de confirmar. Se quitaron las zonas a propósito.
- En laptop, el ticket digital se arma a la derecha, con cabecera resaltada y el nombre del cliente grande.
- En el paso 2 no se repiten los datos del cliente, para que se vea toda la carta.

**Ticket**
- Cada línea tiene − y + (el − se desactiva en 1), lápiz para editar y ✕ para eliminar.
- Las opciones y notas se eligen en la ventana del producto, no en el ticket.

**Pagos**
- Efectivo, Yape, Plin, Tarjeta y Ambos (efectivo + Yape o Plin). Yape y Plin van por fuera, con captura por WhatsApp; el
  sistema no los comprueba.
- Ambos: se escribe lo de Yape o Plin, el efectivo se calcula solo y se pregunta con cuánto paga. Ejemplo: S/ 48, 40 por
  Yape, 8 en efectivo, paga con 10, vuelto 2.
- Caja separa cada forma de pago. El repartidor rinde solo el efectivo.

**Tickets ya enviados**
- Se editan o anulan en Nuevo, En preparación y Listo. No en En camino, Entregado ni mesa cobrada.
- Si agregan algo a un pedido Listo, vuelve a En preparación. Cocina ve "Ticket editado" con lo agregado y quitado.
- Si cambia el total, se muestran antes, ahora y la diferencia.
- Anular no borra: el pedido pasa a `S.anulados`, sale de cocina, moto y caja, y queda en el filtro Anulados.

**Opciones de producto**
- Tocar un producto abre su ventana. Cafés, frappés y jugos preguntan azúcar (Sin, Poca, Mediana). Jugos también
  temperatura (Helada, Normal, Sin helar).
- BURGERS PARRILLERAS: ensalada; papa PF, PH, Mix o SP con Aparte; cremas clásicas y parrilleras con Todas y Aparte;
  extras con precio; observaciones.
- Cada crema, en el mismo botón: 1 toque Normal (azul), 2 Harta (rojo), 3 Poca (verde), 4 sin crema (blanco).
- Aparte activo: color mostaza con ✓.
- La carta de burgers se dejó tal como está en la imagen del dueño, incluidas sus dudas de escritura y de precio en los
  productos 12 y 13. No corregirla sin que él lo pida.

**Diseño**
- Paleta de cafetería, en tonos tenues y no muy claros: fondo latte, superficies crema, café espresso para botones y
  textos, caramelo y oliva como acentos. Títulos en Fraunces y textos en Poppins.
- Los colores están en las variables de `:root`, con su versión oscura. No cambiarlos sin que el dueño lo pida.

**Google Maps**
- Campos Dirección y Distrito o ciudad; este último viene con la ciudad del negocio (Admin → Negocio).
- Botón Probar en Google Maps y enlace opcional de ubicación exacta del cliente.
- Google no conoce todas las direcciones del Perú. Para esos casos, usar el enlace del cliente.

## Pendientes

1. **Conectar la base de datos (el siguiente paso grande).** Hoy los equipos no comparten pedidos. Plan: Supabase con
   `negocio_id` y seguridad por fila, tiempo real e inicio de sesión. Antes de usar datos reales de clientes hay que
   agregar inicio de sesión: hoy cualquiera con el enlace abre el sistema y elige un rol.
   - Etapas: 1) cuenta y tablas (hecha), 2) inicio de sesión y roles (hecha), 3) pantallas conectadas en tiempo real,
     4) pasar la carta, 5) prueba con varios equipos.
   - Pendiente conocido: cualquiera con el enlace puede crear una cuenta y su propio negocio (queda aislado). Cuando se
     venda, limitar quién crea negocios. Sin correo, el trabajador que olvida su contraseña necesita cuenta y código nuevos.
   - `supabase/01-tablas.sql`: negocios, miembros (roles `dueno`, `cajero`, `mesero`, `cocina`, `moto`), invitaciones con
     código, categorías, productos, clientes, pedidos (detalle en `datos` jsonb; el número `n` lo pone la base de datos) y
     `mesas_estado` (cuenta, reserva, `unida_a`). Seguridad por fila con `es_miembro()` y `mi_rol()`; funciones
     `crear_negocio()` y `usar_codigo()`. Se probó con PGlite; se puede volver a correr.
   - Solo la clave pública (publishable) va en la página. La secreta nunca se pide ni se escribe.
2. Confirmar con el dueño que PH significa papa hilo (lo dijo por voz como "papa lilo").
3. Posibles mejoras, solo si él las pide: extras con cantidad y "Carne clásica", cambiar papas y cremas desde Admin,
   vuelto en efectivo de mesa y para llevar, Ambos con tarjeta, boletas o facturas.

## Mapa del código en `index.html`

- `S`: estado guardado (`menu`, `cats`, `config`, `personal`, `pedidos`, `anulados`, `clientes`, `cuenta`, `reservas`).
- `seed()`, `blank()`, `migrate()`, `save()`: datos de ejemplo, reinicio, conversión y guardado.
- `ROLES`, `NAV`, `VIEWS`, `ADMIN`: roles y pantallas. `render()` dibuja la pantalla actual.
- `ACT`: todas las acciones; los botones las llaman con `data-act`.
- `sheetWiz`, `detPago`, `ticketHtml`, `totalesHtml`: asistente, pago y ticket.
- `sheetBuilder`: pedido de mesa y para llevar.
- `prodsHtml`, `popPintar`, `prodGrupos`, `armHtml`, `armPartes`: carta y ventana del producto.
- `ARMADO_BURGER`, `DEF_CATS`, `DEF_MENU`: opciones de burgers, categorías y carta.
- `ticketsLista`, `marcarEdicion`, `guardarEdicion`, `editable`: pantalla Tickets y edición.
- `mapQuery`, `mapLink`, `dirTxt`: Google Maps.
- `SB_URL`, `SB_KEY`, `MODO`, `YO`: conexión y cuenta. `arrancar`, `acceso`, `entrarReal`: pantalla de acceso.
- `personalReal`, `cargarEquipo`, `invCrear`, `mAct`: personal y códigos en Admin (modo con cuenta).
