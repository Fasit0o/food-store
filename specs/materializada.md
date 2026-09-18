# Especificación — Vista materializada FoodStore

## Objetivo

Crear una vista materializada para guardar el resultado del informe de ventas mensuales por forma de pago.

## Informe elegido

Se utilizará la consulta Q5 de `queries.sql`, que calcula:

- mes
- forma de pago
- cantidad de pedidos
- cantidad de líneas
- monto total vendido

La consulta trabaja sobre las tablas `pedido` y `detalle_pedido`.

## Nombre

`mv_ventas_mensuales_forma_pago`

## Requisitos

La vista materializada debe crearse con `WITH DATA`.

Debe tener un índice UNIQUE sobre:

- `mes`
- `forma_pago`

El índice permitirá realizar posteriormente `REFRESH MATERIALIZED VIEW CONCURRENTLY`.

## Verificación

Se deberá comparar el tiempo de ejecución de la consulta original con el tiempo de consulta de la vista materializada mediante `EXPLAIN ANALYZE`.

También se deberá documentar la frecuencia de actualización y la posibilidad de que los datos queden temporalmente desactualizados.