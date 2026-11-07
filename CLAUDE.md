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
| Datos | `localStorage`, clave `cafe-demo-v1`. Cada navegador tiene los suyos |

## Cómo trabajar y publicar

1. Antes de empezar: `git pull`. No editar en dos computadoras a la vez.
2. Editar `index.html`. Todavía no existe base de datos: no dependas de una.
3. Revisar la sintaxis: extraer lo que hay entre `<script>` y `</script>` y correr `node --check`.
4. Probar en tamaño laptop (1300 × 760) y celular (375 × 812). Usar Dueño para ver todas las pantallas.
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

El rol se elige a mano en "Entraste como". No hay inicio de sesión todavía.

## Decisiones del dueño (respetarlas)

**Tipos de pedido**
- Mesa y Para llevar: los toma el mesero o Caja, con el cliente en el local.
- Delivery y Recoger: los toma quien atiende WhatsApp, en la laptop. Recoger pide solo el nombre.
- El pedido de Recoger lo puede entregar el mesero o Caja.
- Separar mesa: lo hacen Caja o Dueño, con nombre y hora. Una separación por mesa y solo en mesas libres.

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

**Google Maps**
- Campos Dirección y Distrito o ciudad; este último viene con la ciudad del negocio (Admin → Negocio).
- Botón Probar en Google Maps y enlace opcional de ubicación exacta del cliente.
- Google no conoce todas las direcciones del Perú. Para esos casos, usar el enlace del cliente.

## Pendientes

1. **Conectar la base de datos (el siguiente paso grande).** Hoy los equipos no comparten pedidos. Plan: Supabase con
   `negocio_id` y seguridad por fila, tiempo real e inicio de sesión. Antes de usar datos reales de clientes hay que
   agregar inicio de sesión: hoy cualquiera con el enlace abre el sistema y elige un rol.
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
