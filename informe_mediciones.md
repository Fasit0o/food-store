# Informe de mediciones — TP5

## Parte A — Medición del costo de escritura

### Carga de referencia

Se realizó una prueba de inserción de 500 filas en `detalle_pedido`, utilizando la estructura de índices existente y sin agregar nuevos índices.

La operación se ejecutó dentro de una transacción y posteriormente se realizó `ROLLBACK`, por lo que las filas utilizadas para la prueba no quedaron almacenadas permanentemente.

**Resultado:**

- Filas insertadas: 500
- Execution Time: 21,202 ms
- Nuevos índices agregados para la prueba: ninguno

## Verificación de vistas — Parte B

Se crearon y probaron correctamente las tres vistas mediante consultas SELECT.

- `v_productos_activos`: devolvió productos activos junto con su categoría.
- `v_pedidos_cliente`: devolvió pedidos junto con los datos del cliente.
- `v_detalle_pedido_producto`: devolvió los detalles de pedidos junto con el nombre del producto.

Las consultas de prueba devolvieron resultados coherentes con lo definido en `specs/views.md`.

### Verificación de equivalencia

Se verificó cada vista contra su consulta manual equivalente mediante `EXCEPT`.

- `v_productos_activos`: 0 diferencias.
- `v_pedidos_cliente`: 0 diferencias.
- `v_detalle_pedido_producto`: 0 diferencias.

Los resultados confirman que las tres vistas devuelven exactamente el mismo conjunto de filas y columnas que sus consultas manuales equivalentes.

## Verificación de vista materializada — Parte C

Se comparó la consulta original Q5 con la consulta sobre la vista materializada `mv_ventas_mensuales_forma_pago`.

| Consulta | Tiempo de ejecución |
|---|---:|
| Consulta original Q5 | 1044,058 ms |
| Vista materializada | 0,041 ms |

La consulta original procesa aproximadamente 500.000 filas de `detalle_pedido`, realiza un JOIN, ordenamiento y agregación.

La vista materializada ya contiene el resultado agregado, por lo que la consulta posterior solo debe leer las 12 filas almacenadas y ordenarlas.

La vista materializada fue comparada con la consulta original mediante `EXCEPT` y presentó **0 diferencias**, por lo que ambos resultados son equivalentes en el momento del refresco.

### Actualización y datos desactualizados

La vista materializada almacena físicamente el resultado de la consulta. Por este motivo, los nuevos pedidos o modificaciones en las tablas originales no aparecen automáticamente en la vista.

Para este informe mensual se propone realizar un `REFRESH MATERIALIZED VIEW` al actualizar el informe, por ejemplo una vez por mes. Entre refrescos, los datos pueden quedar temporalmente desactualizados.

## Parte C — Vista materializada

**Herramienta:** OpenCode

**Propósito:** generar el SQL para la vista materializada a partir de `specs/materializada.md`.

**Propuesta:** crear `mv_ventas_mensuales_forma_pago` con `WITH DATA` y un índice UNIQUE sobre `(mes, forma_pago)`.

**Decisión:** aceptada con una corrección de sintaxis.

**Corrección realizada:** OpenCode generó inicialmente `WITH DATA AS`, que no corresponde a la sintaxis de PostgreSQL. Se corrigió a `CREATE MATERIALIZED VIEW ... AS SELECT ... WITH DATA`.

**Verificación:** la vista materializada fue creada correctamente y su resultado presentó 0 diferencias respecto de la consulta original Q5.

**Mediciones:**
- Consulta original Q5: 1044,058 ms.
- Consulta sobre vista materializada: 0,041 ms.

**Justificación:** la vista materializada evita recalcular el JOIN, la agregación y el ordenamiento sobre aproximadamente 500.000 filas cada vez que se consulta el informe.

**Actualización:** los datos almacenados pueden quedar desactualizados hasta ejecutar un `REFRESH MATERIALIZED VIEW`. Para este informe mensual se propone actualizarla al cierre o actualización de cada período.

**Índice:** se creó `idx_mv_ventas_mensuales_forma_pago` sobre `(mes, forma_pago)` para permitir posteriormente `REFRESH MATERIALIZED VIEW CONCURRENTLY`.

### Verificación de REFRESH CONCURRENTLY

Se ejecutó correctamente:

REFRESH MATERIALIZED VIEW CONCURRENTLY mv_ventas_mensuales_forma_pago;

La operación finalizó correctamente en aproximadamente 1,061 segundos, confirmando que el índice UNIQUE sobre `(mes, forma_pago)` permite utilizar la actualización concurrente de la vista materializada.