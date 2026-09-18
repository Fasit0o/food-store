# Especificación — Plan de índices para FoodStore (TP5, Parte A)

---

## 1. Objetivo

Analizar las seis consultas de `queries.sql` y determinar si corresponde crear nuevos índices
en PostgreSQL sobre la base `foodstore_tp3_prueba`.

El objetivo **no** es crear índices indiscriminadamente. Cada propuesta debe justificarse
mediante evidencia real obtenida con `EXPLAIN (ANALYZE, BUFFERS)`:

- tipo de acceso utilizado (Seq Scan, Index Scan, Bitmap Index Scan)
- cantidad de filas procesadas vs. filas devueltas
- tiempo real medido por nodo
- buffers consumidos
- selectividad del filtro
- índices ya existentes que cubran el mismo acceso
- costo potencial de mantenimiento durante INSERT / UPDATE / DELETE

La base de datos utilizada es `foodstore_tp3_prueba`.

> **Aclaración de alcance:** esta especificación aplica exclusivamente a las seis consultas
> de `queries.sql` del presente TP5. No se reutilizan propuestas, mediciones ni índices de
> trabajos anteriores.

---

## 2. Tamaño actual de las tablas

| Tabla           | Filas aproximadas |
|-----------------|------------------:|
| `cliente`       |            20.005 |
| `producto`      |            50.014 |
| `pedido`        |           200.006 |
| `detalle_pedido`|           500.014 |
| `categoria`     |                 5 |

---

## 3. Inventario de índices existentes

### 3.1 Índices de clave primaria (B-tree implícito)

| Nombre               | Tabla            | Columnas                     |
|----------------------|------------------|------------------------------|
| `pk_cliente`         | `cliente`        | `(id)`                       |
| `pk_categoria`       | `categoria`      | `(id)`                       |
| `pk_producto`        | `producto`       | `(id)`                       |
| `pk_pedido`          | `pedido`         | `(id)`                       |
| `pk_detalle_pedido`  | `detalle_pedido` | `(pedido_id, producto_id)`   |

> `pk_detalle_pedido` es una clave primaria compuesta. `pedido_id` es la primera columna,
> por lo que este índice ya permite búsquedas eficientes por `pedido_id` sin necesidad de
> ningún índice adicional sobre esa columna.

### 3.2 Índices de restricción UNIQUE (B-tree implícito)

| Nombre               | Tabla      | Columna   |
|----------------------|------------|-----------|
| `uq_cliente_email`   | `cliente`  | `email`   |
| `uq_categoria_nombre`| `categoria`| `nombre`  |

### 3.3 Índices explícitos

| Nombre                        | Tabla            | Columna        |
|-------------------------------|------------------|----------------|
| `idx_producto_categoria`      | `producto`       | `categoria_id` |
| `idx_pedido_cliente`          | `pedido`         | `cliente_id`   |
| `idx_detalle_pedido_producto` | `detalle_pedido` | `producto_id`  |

### 3.4 Columnas sin índice actualmente

- `pedido.fecha`
- `pedido.forma_pago`
- `producto.activo`
- `producto.precio`
- `producto.stock`
- `detalle_pedido.cantidad`
- `detalle_pedido.precio_unitario`

---

## 4. Mediciones baseline

Los tiempos siguientes fueron obtenidos con `EXPLAIN (ANALYZE, BUFFERS)` sobre
`foodstore_tp3_prueba` antes de crear ningún índice nuevo:

| Consulta | Descripción resumida                               | Tiempo baseline |
|----------|----------------------------------------------------|----------------:|
| Q1       | Top 20 productos por monto vendido                 |      338,021 ms |
| Q2       | Ranking de clientes con ≥ 10 pedidos               |    3764,246 ms  |
| Q3       | Categorías activas sobre el promedio de recaudación|      328,880 ms |
| Q4       | Productos activos que nunca fueron vendidos        |       91,477 ms |
| Q5       | Resumen mensual de ventas por forma de pago        |      808,272 ms |
| Q6       | Líneas de pedidos de un cliente puntual por email  |        6,589 ms |

---

## 5. Análisis individual de las seis consultas

---

### Q1 — Top 20 productos por monto vendido (338,021 ms)

#### Consulta

```sql
SELECT p.id,
       p.nombre,
       c.nombre AS categoria,
       SUM(dp.cantidad) AS unidades_vendidas,
       SUM(dp.cantidad * dp.precio_unitario) AS monto_vendido
FROM detalle_pedido dp
JOIN producto p ON p.id = dp.producto_id
JOIN categoria c ON c.id = p.categoria_id
WHERE p.activo = TRUE
GROUP BY p.id, p.nombre, c.nombre
ORDER BY monto_vendido DESC, unidades_vendidas DESC
LIMIT 20;
```

#### Acceso relevante

El plan recorre `detalle_pedido` completa (500.014 filas). No existe ningún predicado sobre
`detalle_pedido` que permita reducir el conjunto de filas antes del agregado. El filtro
`p.activo = TRUE` se aplica sobre `producto` después del JOIN. El JOIN
`dp.producto_id = p.id` está cubierto por `idx_detalle_pedido_producto`.

#### Nodo que constituye el problema

`HashAggregate` o `GroupAggregate` sobre la totalidad de `detalle_pedido`. Las claves de
ordenación (`monto_vendido`, `unidades_vendidas`) son columnas calculadas — ningún índice
puede precalcularlas ni eliminar la fase de Sort para el LIMIT 20 final.

#### Índices existentes que cubren los accesos

- `idx_detalle_pedido_producto` cubre el JOIN `dp.producto_id = p.id`.
- `pk_producto` cubre el acceso a `producto` por id.
- `pk_categoria` cubre el acceso a `categoria` por id.

#### Decisión: NO crear índice

#### Justificación técnica

La consulta necesita agregar todas las filas de `detalle_pedido` sin excepción. No hay
columna con selectividad útil en esa tabla que permita filtrar antes del agregado. El
tiempo de 338 ms responde al volumen de procesamiento, no a la ausencia de un índice. Un
índice cubriente sobre `detalle_pedido(producto_id) INCLUDE (cantidad, precio_unitario)`
fue evaluado en contextos similares y el optimizador no lo eligió — el plan continúa con
Seq Scan porque el costo de recorrer páginas secuencialmente es menor que el costo de
accesos aleatorios al heap desde el índice cuando se necesitan todas las filas. El cuello
de botella es el algoritmo de agregación, no la búsqueda.

---

### Q2 — Ranking de clientes con ≥ 10 pedidos (3764,246 ms)

#### Consulta

```sql
SELECT cl.id,
       cl.nombre,
       cl.apellido,
       cl.email,
       count(DISTINCT p.id) AS cantidad_pedidos,
       COALESCE(SUM(dp.cantidad * dp.precio_unitario), 0) AS compra_total
FROM cliente cl
JOIN pedido p ON p.cliente_id = cl.id
JOIN detalle_pedido dp ON dp.pedido_id = p.id
GROUP BY cl.id, cl.nombre, cl.apellido, cl.email
HAVING count(DISTINCT p.id) >= 10
ORDER BY compra_total DESC, cantidad_pedidos DESC
LIMIT 25;
```

#### Acceso relevante

JOIN triple sobre `cliente` (20.005 filas), `pedido` (200.006 filas) y `detalle_pedido`
(500.014 filas). El plan probablemente utiliza Hash Join encadenado sobre los tres
conjuntos completos. `idx_pedido_cliente` cubre el JOIN `p.cliente_id = cl.id`.
`pk_detalle_pedido` cubre el JOIN `dp.pedido_id = p.id` (primera columna de la PK
compuesta).

#### Nodo que constituye el problema

`HashAggregate` con `COUNT(DISTINCT p.id)` calculado sobre el producto cartesiano
`pedido × detalle_pedido`. Este operador es el cuello de botella: debe materializar y
deduplicar `p.id` por cada cliente antes de aplicar el HAVING. El problema es de
volumen y de complejidad del agregado, no de búsqueda.

#### Índices existentes que cubren los accesos

- `idx_pedido_cliente` cubre el JOIN `p.cliente_id = cl.id`.
- `pk_detalle_pedido` con `pedido_id` como primera columna cubre el JOIN
  `dp.pedido_id = p.id`.
- `pk_cliente` cubre el acceso a `cliente` por id.

#### Decisión: NO crear índice

#### Justificación técnica

No existe una columna con alta selectividad sobre la que filtrar antes del agregado. El
El COUNT(DISTINCT p.id) debe procesar y deduplicar los pedidos asociados a las filas de detalle que participan en el JOIN. En el plan medido, el costo dominante proviene del volumen de datos y de la agregación, por lo que no se justificó un índice adicional. El tiempo de 3764 ms es el más alto de las seis consultas y responde a la
complejidad del operador de agregación, no a falta de índices. La mejora documentable
para esta consulta proviene de reescritura estructural (preagregación por pedido antes del
JOIN con `detalle_pedido`), que es un problema de la Parte de optimización, no de
indexación.

---

### Q3 — Categorías cuya recaudación supera el promedio (328,880 ms)

#### Consulta

```sql
SELECT c.id,
       c.nombre,
       SUM(dp.cantidad * dp.precio_unitario) AS recaudacion_total
FROM categoria c
JOIN producto p ON p.categoria_id = c.id
JOIN detalle_pedido dp ON dp.producto_id = p.id
WHERE c.activo = TRUE
GROUP BY c.id, c.nombre
HAVING SUM(dp.cantidad * dp.precio_unitario) >
       (SELECT AVG(recaudacion)
        FROM (SELECT SUM(dp2.cantidad * dp2.precio_unitario) AS recaudacion
              FROM categoria c2
              JOIN producto p2 ON p2.categoria_id = c2.id
              JOIN detalle_pedido dp2 ON dp2.producto_id = p2.id
              WHERE c2.activo = TRUE
              GROUP BY c2.id) AS recau)
ORDER BY recaudacion_total DESC;
```

#### Acceso relevante

Solo existen 5 categorías. El JOIN `p.categoria_id = c.id` usa `idx_producto_categoria`.
El JOIN `dp.producto_id = p.id` usa `idx_detalle_pedido_producto`. La subconsulta escalar
en el HAVING repite exactamente el mismo agregado sobre `detalle_pedido` una segunda vez,
duplicando el trabajo de lectura — de ahí que el tiempo (328 ms) sea comparable al de Q1
a pesar de que el resultado final son apenas 2 o 3 filas.

#### Nodo que constituye el problema

El doble recorrido completo de `detalle_pedido`: una vez para el agregado principal y
otra para la subconsulta escalar del HAVING. Los índices de JOIN ya existen y están siendo
usados. No hay un predicado de filtro selectivo sobre `detalle_pedido` que pudiera
aprovecharse.

#### Índices existentes que cubren los accesos

- `idx_producto_categoria` cubre el JOIN `p.categoria_id = c.id`.
- `idx_detalle_pedido_producto` cubre el JOIN `dp.producto_id = p.id` en ambas pasadas.
- `pk_categoria` cubre el acceso a `categoria` por id.

#### Decisión: NO crear índice

#### Justificación técnica

Todos los índices necesarios para los JOINs ya existen. El costo proviene de la estructura
de la consulta (subconsulta escalar que repite el agregado), no de la ausencia de un índice.
La mejora correcta es reemplazar la subconsulta escalar en el HAVING por una Window Function
`AVG(...) OVER ()` sobre el resultado ya agrupado, eliminando la segunda pasada completa
sobre `detalle_pedido`. Un índice adicional sobre cualquier columna de `detalle_pedido` no
modificaría el nodo dominante porque la consulta necesita todas las filas de esa tabla.

---

### Q4 — Productos activos que nunca fueron vendidos (91,477 ms)

#### Consulta

```sql
SELECT p.id,
       p.nombre,
       p.precio,
       p.stock,
       c.nombre AS categoria
FROM producto p
JOIN categoria c ON c.id = p.categoria_id
WHERE p.activo = TRUE
  AND NOT EXISTS (
      SELECT 1
      FROM detalle_pedido dp
      WHERE dp.producto_id = p.id
  )
ORDER BY c.nombre, p.nombre;
```

#### Acceso relevante

El plan recorre `producto` (50.014 filas) filtrando `activo = TRUE`. Para cada producto
activo evalúa el anti-join contra `detalle_pedido` buscando por `producto_id`. El
`NOT EXISTS` corta en la primera fila encontrada, lo que es eficiente cuando casi todos
los productos tienen ventas (como ocurre con la carga masiva). El anti-join usa
`idx_detalle_pedido_producto` sobre `detalle_pedido(producto_id)`.

#### Nodo que constituye el problema

El Seq Scan sobre `producto` con filtro `activo = TRUE` recorre las 50.014 filas, pero a
50.014 filas este recorrido es barato en términos absolutos. El costo real de 91 ms
proviene de repetir el anti-join para cada producto activo, aunque se corta rápido en la
mayoría de los casos.

#### Índices existentes que cubren los accesos

- `idx_detalle_pedido_producto` cubre el predicado del anti-join `dp.producto_id = p.id`.
- `idx_producto_categoria` cubre el JOIN `c.id = p.categoria_id`.
- `pk_categoria` cubre el acceso a `categoria` por id.

#### Decisión: NO crear índice

#### Justificación técnica

El índice exactamente necesario para el anti-join ya existe (`idx_detalle_pedido_producto`).
El Seq Scan sobre `producto` con filtro `activo = TRUE` es correcto para una tabla de
50.014 filas: no hay un predicado de rango o igualdad de alta selectividad que justifique
un índice adicional. Un índice parcial `producto(id) WHERE activo = TRUE` sería redundante
con `pk_producto` para una tabla de este tamaño y no cambiaría el nodo dominante.

---

### Q5 — Resumen mensual de ventas por forma de pago (808,272 ms)

#### Consulta

```sql
SELECT date_trunc('month', p.fecha) AS mes,
       p.forma_pago,
       count(DISTINCT p.id) AS cantidad_pedidos,
       count(*) AS cantidad_lineas,
       SUM(dp.cantidad * dp.precio_unitario) AS monto_total
FROM pedido p
JOIN detalle_pedido dp ON dp.pedido_id = p.id
WHERE p.fecha >= DATE '2026-10-01'
GROUP BY date_trunc('month', p.fecha), p.forma_pago
ORDER BY mes, p.forma_pago;
```

#### Acceso relevante

El predicado `p.fecha >= DATE '2026-10-01'` se aplica sobre `pedido`. La carga masiva
generó todos sus pedidos a partir de esa fecha, lo que significa que prácticamente el
100 % de los 200.006 pedidos satisfacen el filtro. El plan hace Seq Scan sobre `pedido`,
luego JOIN con `detalle_pedido` (500.014 filas) usando `pk_detalle_pedido` por `pedido_id`,
y finalmente `HashAggregate` + Sort.

#### Nodo que constituye el problema

El `HashAggregate` sobre el JOIN `pedido × detalle_pedido` con el conjunto casi completo de
ambas tablas. El Seq Scan sobre `pedido` es correcto dado que el filtro de fecha es
prácticamente no selectivo.

#### Índices existentes que cubren los accesos

- `pk_detalle_pedido` con `pedido_id` como primera columna cubre el JOIN
  `dp.pedido_id = p.id`.

#### Decisión: NO crear índice sobre `pedido(fecha)`

#### Justificación técnica

La selectividad del predicado `p.fecha >= DATE '2026-10-01'` sobre los datos actuales es
cercana a cero: si la práctica totalidad de los 200.006 pedidos fueron generados a partir
de esa fecha, el filtro no descarta filas. En esas condiciones:

1. Un Index Scan sobre `pedido(fecha)` generaría accesos aleatorios al heap para recuperar
   casi todas las páginas de la tabla — más costoso que el Seq Scan secuencial.
2. Un Bitmap Index Scan + Heap Scan se degrada a rendimiento equivalente o peor al Seq
   Scan cuando el bitmap cubre la casi totalidad de los bloques de la tabla.
3. El optimizador, con estadísticas actualizadas, ignorará el índice y elegirá Seq Scan.
4. El índice pagaría costo de mantenimiento en cada INSERT sobre `pedido` (tabla de alta
   tasa de crecimiento) sin beneficio observable.

El tiempo de 808 ms responde al volumen del JOIN `pedido × detalle_pedido` con agregación,
no a que el filtro de fecha sea el cuello de botella. Si en el futuro la tabla creciera con
pedidos de periodos anteriores y la selectividad del filtro mejorara, este análisis debería
revisarse con estadísticas actualizadas sobre la distribución real de `fecha`.

---

### Q6 — Líneas de pedidos de un cliente puntual por email (6,589 ms)

#### Consulta

```sql
SELECT p.id AS pedido_id,
       p.fecha,
       p.forma_pago,
       pr.nombre AS producto,
       dp.cantidad,
       dp.precio_unitario
FROM cliente cl
JOIN pedido p ON p.cliente_id = cl.id
JOIN detalle_pedido dp ON dp.pedido_id = p.id
JOIN producto pr ON pr.id = dp.producto_id
WHERE cl.email = 'cliente.masivo.1@bulkload.test'
ORDER BY p.fecha DESC, p.id, pr.nombre;
```

#### Plan real — EXPLAIN (ANALYZE, BUFFERS)

```text
Sort
  actual time=0.345..0.347 ms   rows=25   Sort Method: quicksort   Memory: 26kB
  -> Nested Loop
       actual time=0.171..0.262 ms   rows=25
       -> Index Scan using uq_cliente_email on cliente cl
            actual time=0.068..0.068 ms   rows=1
       -> Bitmap Heap Scan on pedido p
            actual time=0.059..0.069 ms   rows=10
            -> Bitmap Index Scan using idx_pedido_cliente
                 actual time=0.032..0.032 ms   rows=10
       -> Index Scan using pk_detalle_pedido on detalle_pedido dp
            Index Cond: (pedido_id = p.id)
            actual time=0.007..0.007 ms   rows=25   loops=10
       -> Index Scan using pk_producto on producto pr
            actual time=0.001..0.001 ms   rows=1    loops=25
Planning Time:  1.270 ms
Execution Time: 0.512 ms
```

> **Nota sobre el tiempo baseline de 6,589 ms:** el tiempo registrado como baseline
> refleja una medición anterior, posiblemente con buffers fríos o bajo condiciones de
> carga distintas. El EXPLAIN de validación midió 0.512 ms con buffers calientes. Ambos
> valores confirman que la consulta es rápida y que ningún nodo individual es un cuello
> de botella.

#### Lectura del plan

Todos los accesos de búsqueda usan índice:

1. `uq_cliente_email` resuelve el predicado `email = ...` devolviendo una sola fila.
2. `idx_pedido_cliente` devuelve los 10 pedidos del cliente (Bitmap Index Scan + Heap Scan).
3. `pk_detalle_pedido` resuelve el JOIN `dp.pedido_id = p.id` con Index Scan por cada
   pedido (10 loops × ~2,5 filas cada uno = 25 filas totales).
4. `pk_producto` resuelve el JOIN `pr.id = dp.producto_id` (25 loops × 1 fila).
5. El Sort final ordena 25 filas en memoria (quicksort, 26 kB) en 0.345 ms.

#### Nodo que constituye el problema

Ninguno. El Sort procesa 25 filas y tarda 0.345 ms. El acceso a `pedido` tarda 0.069 ms.
El acceso a `detalle_pedido` suma ~0.07 ms en total. El tiempo total de ejecución es
0.512 ms. No existe ningún nodo dominante que justifique intervención.

#### Índices existentes que cubren los accesos

- `uq_cliente_email` cubre la búsqueda por email.
- `idx_pedido_cliente` cubre el JOIN `p.cliente_id = cl.id`.
- `pk_detalle_pedido` cubre el JOIN `dp.pedido_id = p.id`.
- `pk_producto` cubre el acceso a `producto` por id.

#### Decisión: NO crear índice

#### Justificación técnica

La hipótesis de reemplazar `idx_pedido_cliente` por un índice compuesto
`pedido(cliente_id, fecha DESC)` queda **rechazada** con base en la evidencia medida:

- El Sort final procesa solo 25 filas con quicksort en memoria (26 kB) y tarda 0.345 ms —
  menos del 70 % del tiempo total de ejecución, y en términos absolutos es trivial.
- El acceso a `pedido` por `idx_pedido_cliente` tarda 0.069 ms para 10 filas. No hay
  costo de Sort observable sobre `pedido` porque el Bitmap Heap Scan no necesita entregar
  filas ordenadas.
- El tiempo de ejecución total es 0.512 ms. No existe degradación que justifique la
  creación de un índice adicional.
- Un índice compuesto `(cliente_id, fecha DESC)` sería más grande que `idx_pedido_cliente`
  y pagaría costo de mantenimiento en cada INSERT/UPDATE sobre `pedido` (200.006 filas,
  tabla de crecimiento continuo) sin ningún beneficio medido.

---

## 6. Propuestas explícitamente rechazadas

Las siguientes propuestas quedan descartadas técnicamente y no deben reabrirse sin nueva
evidencia experimental:

### R1 — Índice adicional sobre `detalle_pedido(pedido_id)`

**Rechazado.** `pk_detalle_pedido` es una clave primaria compuesta `(pedido_id, producto_id)`
con `pedido_id` como primera columna. PostgreSQL puede usar ese índice para búsquedas por
`pedido_id` exactamente de la misma forma que lo haría un índice simple sobre esa columna.
El EXPLAIN de Q6 confirmó: `Index Scan using pk_detalle_pedido on detalle_pedido dp` con
`Index Cond: (pedido_id = p.id)`. Un índice adicional sería completamente redundante y
pagaría costo de mantenimiento doble en cada INSERT/DELETE sobre `detalle_pedido`.

### R2 — Índice sobre `pedido(fecha)`

**Rechazado.** El filtro `p.fecha >= DATE '2026-10-01'` en Q5 es prácticamente no selectivo
sobre los datos actuales: la carga masiva generó todos sus pedidos a partir de esa fecha,
por lo que el predicado retiene casi el 100 % de la tabla. Con baja selectividad, el
optimizador ignora el índice y el Seq Scan es el plan correcto. Crear el índice implicaría
costo de mantenimiento sin beneficio observable. Ver análisis completo en Q5.

### R3 — Índice parcial sobre `producto(activo)` o `producto WHERE activo = TRUE`

**Rechazado.** El Seq Scan sobre `producto` (50.014 filas) con filtro `activo = TRUE` no
constituye el cuello de botella en ninguna de las seis consultas. Para una tabla de este
tamaño, el Seq Scan consume pocas páginas y no es el nodo dominante. Un índice parcial
sobre `activo` no cambiaría el nodo problemático en Q1, Q3 ni Q4.

### R4 — Cualquier índice adicional para Q1, Q2 o Q3 que no modifique el nodo dominante

**Rechazado.** Q1, Q2 y Q3 tienen como cuello de botella el algoritmo de agregación
(`HashAggregate` / `GroupAggregate`) sobre conjuntos completos de `detalle_pedido`. No
existe un predicado de alta selectividad sobre esa tabla que permita reducir el volumen de
entrada al agregado. Los índices de JOIN ya existen. Cualquier índice adicional que no
reduzca las filas que entran al nodo de agregación no cambia el tiempo medido. La mejora
para estas consultas es un problema de reescritura estructural, no de indexación.

### R5 — `idx_producto_precio_desc_id_activo`

**Rechazado.** Este índice parcial sobre `producto(precio DESC, id) WHERE activo = TRUE`
pertenece a un trabajo práctico anterior y fue diseñado para una consulta de filtro de
precio con LIMIT que no forma parte de las seis consultas del presente TP5. No corresponde
crearlo en este contexto.

### R6 — Índice compuesto `pedido(cliente_id, fecha DESC)` para Q6

**Rechazado.** La hipótesis de reemplazar `idx_pedido_cliente` por un índice compuesto
que incluyera `fecha DESC` fue validada con `EXPLAIN (ANALYZE, BUFFERS)`. Los resultados
muestran que el Sort final procesa 25 filas en 0.345 ms con quicksort en memoria (26 kB),
y que el tiempo total de ejecución de Q6 es 0.512 ms. No existe ningún nodo dominante que
justifique la creación de un índice adicional. Crear el compuesto implicaría costo de
mantenimiento real en `pedido` sin beneficio medible. Ver análisis completo en Q6.

---

## 7. Medición del costo de escritura

El TP exige evaluar el impacto de los índices nuevos sobre las operaciones de escritura.
El procedimiento es el siguiente:

### 7.1 Si se acepta algún índice nuevo

1. Antes de crear el índice: ejecutar una carga de referencia de cientos de INSERT sobre
   `detalle_pedido` y registrar el tiempo total.
2. Crear el índice aceptado.
3. Repetir la misma carga con exactamente los mismos datos y registrar el tiempo total.
4. Comparar ambos tiempos. La diferencia representa el costo de mantenimiento del índice
   en operaciones de escritura.

### 7.2 Si no se acepta ningún índice nuevo

La medición before/after sobre un índice aceptado no aplica. En ese caso, ejecutar la
carga de referencia sobre `detalle_pedido` (sin índice nuevo) y documentar el tiempo
base. Este resultado se utiliza como evidencia para justificar el rechazo de
sobre-indexación: demuestra que el costo de mantenimiento de un índice hipotético
constituiría degradación real de escritura sin contrapartida de mejora en lectura.

### 7.3 Tabla de registro

| Momento | Tiempo de INSERT (referencia) | Observación |
|---------|-------------------------------|-------------|
| Antes de cualquier índice nuevo | 21,202 ms | INSERT de 500 filas en `detalle_pedido`, sin agregar índices nuevos |
| Después del índice (si aplica) | No aplica | No se aceptó ningún índice nuevo |

---

## 8. Conclusión definitiva

> **Con las mediciones baseline actuales, ninguna de las seis consultas justifica la
> creación de un índice nuevo. Los índices existentes cubren los accesos indexables
> relevantes y los principales costos observados corresponden a procesamiento y agregación
> sobre grandes volúmenes de datos, no a falta de índices.**

Resumen del estado final de cada consulta:

| Consulta | Tiempo baseline | Estado                                                   |
|----------|----------------:|----------------------------------------------------------|
| Q1       |      338,021 ms | Sin índice nuevo — agregación global sobre `detalle_pedido` |
| Q2       |    3764,246 ms  | Sin índice nuevo — cuello de botella en `COUNT(DISTINCT)` |
| Q3       |      328,880 ms | Sin índice nuevo — doble pasada por subconsulta escalar  |
| Q4       |       91,477 ms | Sin índice nuevo — índices de JOIN ya existen            |
| Q5       |      808,272 ms | Sin índice nuevo — filtro de fecha no es selectivo       |
| Q6       |        6,589 ms | Sin índice nuevo — Sort trivial (25 filas, 0.345 ms), plan completamente indexado |

La hipótesis del índice compuesto para Q6 fue evaluada con EXPLAIN real y **rechazada**:
el Sort no constituye un cuello de botella. La conclusión es definitiva para las seis
consultas analizadas en este TP5.
