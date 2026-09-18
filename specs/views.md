# Especificación — Vistas para FoodStore (TP5, Parte B)

---

## 1. Objetivo

Definir las vistas que se crearán sobre el esquema de `foodstore_tp3_prueba` para la
Parte B del TP5. Cada vista persigue dos objetivos complementarios:

- **Simplificación**: ocultar la complejidad de los JOINs al consumidor de la vista,
  que puede hacer `SELECT ... FROM <vista>` con un `WHERE` simple en lugar de escribir
  el JOIN completo cada vez.
- **Control de exposición**: exponer únicamente las columnas necesarias para el caso de
  uso previsto, ocultando datos que no corresponde revelar en ese contexto.

Las vistas son de solo lectura (no se requiere `WITH CHECK OPTION` ni operaciones DML
a través de ellas). No se generan sentencias SQL ejecutables en esta especificación.

> **Alcance:** estas tres vistas corresponden exclusivamente al modelo actual de
> FoodStore y a las consultas del TP5. No se incorporan propuestas de trabajos anteriores.

---

## 2. Modelo de referencia

Tablas y columnas relevantes para las vistas:

| Tabla            | Columnas                                                       |
|------------------|----------------------------------------------------------------|
| `cliente`        | `id`, `nombre`, `apellido`, `email`                            |
| `categoria`      | `id`, `nombre`, `activo`                                       |
| `producto`       | `id`, `nombre`, `precio`, `stock`, `activo`, `categoria_id`    |
| `pedido`         | `id`, `fecha`, `forma_pago`, `cliente_id`                      |
| `detalle_pedido` | `pedido_id`, `producto_id`, `cantidad`, `precio_unitario`      |

---

## 3. Vistas especificadas

---

### V1 — `v_productos_activos`

#### Objetivo

Permitir consultar el catálogo de productos activos junto con el nombre de su categoría,
sin necesidad de escribir el JOIN ni el filtro `activo = TRUE` en cada consulta.

#### Tablas involucradas

- `producto` (tabla principal)
- `categoria` (para resolver el nombre de la categoría)

#### JOINs

```
producto  INNER JOIN  categoria  ON  producto.categoria_id = categoria.id
```

El JOIN es `INNER JOIN` porque todo producto tiene una `categoria_id` no nula (restricción
`NOT NULL` del esquema) y toda categoría referenciada existe (integridad referencial).

#### Filtros aplicados dentro de la vista

| Condición               | Razón                                                        |
|-------------------------|--------------------------------------------------------------|
| `producto.activo = TRUE` | La vista representa el catálogo visible; los productos inactivos no deben aparecer. |

No se filtra por `categoria.activo`. Una categoría puede estar desactivada mientras
sus productos siguen activos y siendo consultados históricamente; ese criterio es
una decisión de negocio que debe resolverse en la consulta, no en la vista base.

#### Columnas que expone

| Columna en la vista     | Origen                        | Notas                            |
|-------------------------|-------------------------------|----------------------------------|
| `producto_id`           | `producto.id`                 | Identificador del producto       |
| `nombre`                | `producto.nombre`             | Nombre del producto              |
| `precio`                | `producto.precio`             | Precio actual                    |
| `stock`                 | `producto.stock`              | Unidades disponibles             |
| `categoria_id`          | `producto.categoria_id`       | FK por si se necesita filtrar    |
| `categoria`             | `categoria.nombre`            | Nombre legible de la categoría   |

#### Columnas que deliberadamente NO expone

| Columna omitida         | Razón                                                        |
|-------------------------|--------------------------------------------------------------|
| `producto.activo`       | La vista ya filtra solo activos; exponer la columna sería redundante y podría inducir a error si alguien filtra `WHERE activo = FALSE` sobre la vista. |
| `categoria.id`          | Ya está disponible como `categoria_id` desde `producto`; duplicarla sin alias confundiría el resultado. |
| `categoria.activo`      | No es relevante para el caso de uso de consultar el catálogo de productos. |

#### Equivalente manual (verificación)

```sql
SELECT p.id         AS producto_id,
       p.nombre,
       p.precio,
       p.stock,
       p.categoria_id,
       c.nombre     AS categoria
FROM producto p
JOIN categoria c ON c.id = p.categoria_id
WHERE p.activo = TRUE;
```

Una consulta `SELECT * FROM v_productos_activos` debe devolver exactamente el mismo
conjunto de filas que el equivalente manual ejecutado directamente sobre las tablas.

#### Criterio de seguridad y simplificación

La vista no expone la columna `activo` de `producto`. Esto impide que un consumidor de
la vista obtenga accidentalmente filas inactivas con un filtro incorrecto. Cualquier
consulta sobre `v_productos_activos` opera ya sobre el subconjunto correcto sin que el
consumidor deba conocer la existencia de la columna `activo`.

---

### V2 — `v_pedidos_cliente`

#### Objetivo

Permitir consultar pedidos junto con los datos necesarios del cliente (nombre, apellido,
email), sin exponer columnas sensibles de la tabla `cliente` ni requerir que el
consumidor conozca la estructura del JOIN.

#### Tablas involucradas

- `pedido` (tabla principal)
- `cliente` (para resolver los datos del cliente)

#### JOINs

```
pedido  INNER JOIN  cliente  ON  pedido.cliente_id = cliente.id
```

El JOIN es `INNER JOIN` porque todo pedido tiene un `cliente_id` no nulo e íntegro.

#### Filtros aplicados dentro de la vista

Ninguno. La vista expone todos los pedidos de todos los clientes; el filtrado por
cliente, fecha o forma de pago es responsabilidad de la consulta que usa la vista.

#### Columnas que expone

| Columna en la vista     | Origen                | Notas                                  |
|-------------------------|-----------------------|----------------------------------------|
| `pedido_id`             | `pedido.id`           | Identificador del pedido               |
| `fecha`                 | `pedido.fecha`        | Fecha del pedido                       |
| `forma_pago`            | `pedido.forma_pago`   | Valor del enum `forma_pago_enum`       |
| `cliente_id`            | `pedido.cliente_id`   | FK al cliente, disponible para filtros |
| `nombre`                | `cliente.nombre`      | Nombre del cliente                     |
| `apellido`              | `cliente.apellido`    | Apellido del cliente                   |
| `email`                 | `cliente.email`       | Email del cliente                      |

#### Columnas que deliberadamente NO expone

| Columna omitida         | Razón                                                              |
|-------------------------|--------------------------------------------------------------------|
| `cliente.id`            | Ya está disponible como `cliente_id` desde `pedido`; no es necesario duplicarla. |

#### Nota sobre datos sensibles

La consigna requiere que una de las vistas demuestre el principio de no exponer
información sensible del cliente (en particular, contraseña). En el modelo actual de
FoodStore **la tabla `cliente` no tiene columna `password`**; el esquema solo almacena
`id`, `nombre`, `apellido` y `email`. Por lo tanto:

- No existe riesgo de exposición de contraseña en la implementación actual.
- Si en el futuro se agregara una columna `password` (o equivalente: `password_hash`,
  `token`, `salt`) a `cliente`, esta vista debería actualizarse explícitamente para
  **omitir** esa columna. La lista de columnas de la vista debe ser siempre explícita
  (`SELECT col1, col2, ...`), nunca `SELECT *`, precisamente para que una columna nueva
  en la tabla base no aparezca automáticamente en la vista.
- Este criterio queda documentado aquí como decisión de diseño: la vista de pedidos con
  datos del cliente es el punto natural de control para la exposición de información
  personal, y su definición debe revisarse ante cualquier cambio en el esquema de
  `cliente`.

#### Equivalente manual (verificación)

```sql
SELECT p.id          AS pedido_id,
       p.fecha,
       p.forma_pago,
       p.cliente_id,
       cl.nombre,
       cl.apellido,
       cl.email
FROM pedido p
JOIN cliente cl ON cl.id = p.cliente_id;
```

Una consulta `SELECT * FROM v_pedidos_cliente` debe devolver exactamente el mismo
conjunto de filas que el equivalente manual.

#### Criterio de seguridad y simplificación

La vista expone únicamente los datos de identificación del cliente que son pertinentes
para operar con pedidos. Al definir las columnas explícitamente, la vista actúa como
contrato: cualquier columna que se agregue a `cliente` en el futuro (incluida una posible
`password`) no aparecerá en la vista a menos que se la incluya deliberadamente.

---

### V3 — `v_detalle_pedido_producto`

#### Objetivo

Permitir consultar las líneas de detalle de pedidos junto con el nombre del producto,
sin necesidad de escribir el JOIN contra `producto` ni de conocer la clave primaria
compuesta de `detalle_pedido`.

#### Tablas involucradas

- `detalle_pedido` (tabla principal)
- `producto` (para resolver el nombre del producto)

#### JOINs

```
detalle_pedido  INNER JOIN  producto  ON  detalle_pedido.producto_id = producto.id
```

El JOIN es `INNER JOIN` porque toda fila de `detalle_pedido` referencia un `producto_id`
válido y existente (integridad referencial).

#### Filtros aplicados dentro de la vista

Ninguno. La vista expone todas las líneas de detalle independientemente del estado del
producto. Si el producto fue desactivado después de haber sido vendido, la línea histórica
de venta sigue siendo válida y debe ser consultable.

#### Columnas que expone

| Columna en la vista     | Origen                          | Notas                                   |
|-------------------------|---------------------------------|-----------------------------------------|
| `pedido_id`             | `detalle_pedido.pedido_id`      | Parte de la PK compuesta                |
| `producto_id`           | `detalle_pedido.producto_id`    | Parte de la PK compuesta                |
| `nombre_producto`       | `producto.nombre`               | Nombre legible del producto             |
| `cantidad`              | `detalle_pedido.cantidad`       | Unidades compradas                      |
| `precio_unitario`       | `detalle_pedido.precio_unitario`| Precio al momento de la compra          |

#### Columnas que deliberadamente NO expone

| Columna omitida           | Razón                                                            |
|---------------------------|------------------------------------------------------------------|
| `producto.precio`         | Es el precio actual del catálogo, distinto del `precio_unitario` histórico registrado en `detalle_pedido`. Exponer ambos en la misma vista induciría a confusión. |
| `producto.stock`          | No es relevante para el contexto de consulta de un detalle de pedido histórico. |
| `producto.activo`         | El estado actual del producto no afecta la validez del detalle histórico. |
| `producto.categoria_id`   | No es necesario para el caso de uso de esta vista; si se requiere, se puede hacer JOIN adicional sobre la vista. |

#### Equivalente manual (verificación)

```sql
SELECT dp.pedido_id,
       dp.producto_id,
       pr.nombre     AS nombre_producto,
       dp.cantidad,
       dp.precio_unitario
FROM detalle_pedido dp
JOIN producto pr ON pr.id = dp.producto_id;
```

Una consulta `SELECT * FROM v_detalle_pedido_producto` debe devolver exactamente el mismo
conjunto de filas que el equivalente manual.

#### Criterio de seguridad y simplificación

La vista separa explícitamente `precio_unitario` (precio histórico del detalle) de
`producto.precio` (precio vigente), exponiendo solo el primero. Esto evita que un
consumidor de la vista confunda ambos valores al analizar ventas históricas.

---

## 4. Tabla resumen

| Vista                        | Tablas base                         | Filtro interno     | Columnas sensibles omitidas        |
|------------------------------|-------------------------------------|--------------------|------------------------------------|
| `v_productos_activos`        | `producto`, `categoria`             | `activo = TRUE`    | `producto.activo`, `categoria.activo` |
| `v_pedidos_cliente`          | `pedido`, `cliente`                 | Ninguno            | Futuras columnas sensibles de `cliente` (p. ej. `password`) |
| `v_detalle_pedido_producto`  | `detalle_pedido`, `producto`        | Ninguno            | `producto.precio`, `producto.stock`, `producto.activo` |

---

## 5. Consideraciones de implementación

Las siguientes decisiones deben aplicarse al momento de escribir las sentencias
`CREATE VIEW` en `views.sql`:

1. **Columnas explícitas siempre.** Nunca usar `SELECT *` en la definición de la vista.
   Las columnas deben listarse una a una para que cambios en las tablas base no modifiquen
   silenciosamente la interfaz de la vista.

2. **Alias claros.** Cuando dos tablas contribuyen columnas de nombres iguales o similares
   (por ejemplo, `producto.nombre` y `categoria.nombre`), se debe usar alias descriptivos
   (`nombre`, `categoria`, `nombre_producto`) para evitar ambigüedad.

3. **Sin lógica de negocio derivada.** Las vistas de esta especificación no calculan
   totales ni agregan datos. Son proyecciones y joins simples. Las consultas de agregación
   se construyen sobre las vistas (o sobre las tablas directamente) según la necesidad.

4. **Convención de nombres.** El prefijo `v_` identifica las vistas en el esquema y las
   distingue de las tablas base.

5. **Sin `WITH CHECK OPTION`.** Las vistas son de solo lectura para los casos de uso
   previstos; no se planifica DML a través de ellas.
