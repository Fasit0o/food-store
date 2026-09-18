-- ============================================================
-- TP FOODSTORE - VISTA MATERIALIZADA
-- Base de Datos II
-- ------------------------------------------------------------
-- Crea la vista materializada mv_ventas_mensuales_forma_pago
-- a partir de la consulta Q5 de queries.sql.
--
-- Se guarda el resultado con WITH DATA y se agrega un índice
-- UNIQUE sobre (mes, forma_pago) para permitir futuros
-- REFRESH MATERIALIZED VIEW ... CONCURRENTLY.
--
-- NOTA: los datos quedan congelados al momento del refresh;
-- reflejarán un punto en el tiempo y pueden quedar
-- temporalmente desactualizados entre refrescos.
-- ============================================================


-- ------------------------------------------------------------
-- MV1: mv_ventas_mensuales_forma_pago
--
-- Resumen de ventas mensuales por forma de pago:
--   mes              -> inicio del mes
--   forma_pago       -> valor del enum forma_pago_enum
--   cantidad_pedidos -> pedidos distintos del mes/forma_pago
--   cantidad_lineas  -> líneas de detalle agrupadas
--   monto_total      -> suma de cantidad * precio_unitario
--
-- Es la consulta Q5 de queries.sql ejecutada con el filtro
-- p.fecha >= DATE '2026-10-01'.
-- ------------------------------------------------------------

CREATE MATERIALIZED VIEW mv_ventas_mensuales_forma_pago AS
SELECT date_trunc('month', p.fecha) AS mes,
       p.forma_pago,
       count(DISTINCT p.id) AS cantidad_pedidos,
       count(*) AS cantidad_lineas,
       SUM(dp.cantidad * dp.precio_unitario) AS monto_total
FROM pedido p
JOIN detalle_pedido dp ON dp.pedido_id = p.id
WHERE p.fecha >= DATE '2026-10-01'
GROUP BY date_trunc('month', p.fecha), p.forma_pago
ORDER BY mes, p.forma_pago
WITH DATA;


-- ------------------------------------------------------------
-- Índice UNIQUE sobre la vista materializada.
--
-- Permite utilizar posteriormente:
-- REFRESH MATERIALIZED VIEW CONCURRENTLY
--
-- La combinación (mes, forma_pago) identifica de manera única
-- cada fila del resumen.
-- ------------------------------------------------------------

CREATE UNIQUE INDEX idx_mv_ventas_mensuales_forma_pago
    ON mv_ventas_mensuales_forma_pago (mes, forma_pago);