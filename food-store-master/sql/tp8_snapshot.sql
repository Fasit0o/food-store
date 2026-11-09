-- ============================================================
-- tp8_snapshot.sql — TP8 Consigna 2.A
-- Vista v_snapshot_movil en foodstore_tp8_prueba (SOLO prueba).
-- NUNCA ejecutar sobre foodstore (base original).
--
-- Esquema real de producto (verificado desde el respaldo
-- backups/foodstore_20261107_103401.dump el 2026-11-09):
--   producto(id bigint PK, nombre varchar(150),
--            precio numeric(10,2), stock integer DEFAULT 0,
--            activo boolean DEFAULT true, categoria_id bigint)
-- La baja logica en PostgreSQL es activo = false.
-- La conexion psql en este entorno requiere contrasena
-- interactiva (scram-sha-256): este script queda PENDIENTE
-- de ejecucion manual (ver README). No se ejecutaron
-- modificaciones sobre ninguna base en esta revision.
--
-- Uso (desde la raiz del proyecto, con psql):
--   psql -h localhost -U postgres -d foodstore_tp8_prueba -f sql/tp8_snapshot.sql
-- ============================================================

-- ------------------------------------------------------------
-- 0. Guardia de seguridad: abortar si no es la base de prueba.
-- ------------------------------------------------------------
DO $$
BEGIN
    IF current_database() <> 'foodstore_tp8_prueba' THEN
        RAISE EXCEPTION 'TP8: base incorrecta (%), se esperaba foodstore_tp8_prueba', current_database();
    END IF;
END $$;

-- ------------------------------------------------------------
-- 1. Verificacion ANTES (solo lectura): contar pedidos y stock
--    para demostrar despues que la simulacion no los altero.
-- ------------------------------------------------------------
SELECT 'ANTES' AS momento,
       (SELECT COUNT(*) FROM pedido) AS cantidad_pedidos,
       (SELECT COALESCE(SUM(stock), 0) FROM producto) AS stock_total;

-- ------------------------------------------------------------
-- 2. Vista v_snapshot_movil: minimo que necesita la tablet.
--    precio numeric -> centavos enteros (precio tiene 2 decimales
--    exactos, ROUND solo protege ante redondeo de representacion).
--    activo -> disponible (1/0) y eliminado (0/1).
-- ------------------------------------------------------------
CREATE OR REPLACE VIEW v_snapshot_movil AS
SELECT
    p.id AS id,
    p.nombre AS nombre,
    CAST(ROUND(p.precio * 100) AS BIGINT) AS precio_centavos,
    p.stock AS stock_visto,
    CASE WHEN p.activo THEN 1 ELSE 0 END AS disponible,
    CASE WHEN p.activo THEN 0 ELSE 1 END AS eliminado,
    CURRENT_TIMESTAMP AS fecha_copia
FROM producto p;

-- ------------------------------------------------------------
-- 3. Vista previa (solo lectura) y exportacion a CSV.
--    \copy es un metacomando de psql: corre en el cliente y
--    la ruta es relativa al directorio desde donde se invoca psql.
-- ------------------------------------------------------------
SELECT * FROM v_snapshot_movil ORDER BY id;

\copy (SELECT * FROM v_snapshot_movil ORDER BY id) TO 'movil/servidor_snapshot.csv' CSV HEADER

-- ------------------------------------------------------------
-- 4. Verificacion DESPUES (solo lectura): debe coincidir con ANTES.
-- ------------------------------------------------------------
SELECT 'DESPUES' AS momento,
       (SELECT COUNT(*) FROM pedido) AS cantidad_pedidos,
       (SELECT COALESCE(SUM(stock), 0) FROM producto) AS stock_total;
