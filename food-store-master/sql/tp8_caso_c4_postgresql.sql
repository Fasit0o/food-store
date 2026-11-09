-- ============================================================
-- tp8_caso_c4_postgresql.sql — TP8 Consigna 2.C, Caso C4 (PostgreSQL)
-- Baja logica SOLO sobre foodstore_tp8_prueba (copia de prueba).
-- NUNCA sobre foodstore (base original).
--
-- Ejecutar UNICAMENTE cuando movil/casos_c2_c6.sql llega a su
-- DETENERSE de C4a, con:
--   psql -h localhost -U postgres -d foodstore_tp8_prueba -v ON_ERROR_STOP=1 -f sql/tp8_caso_c4_postgresql.sql
-- Despues: re-ejecutar sql/tp8_snapshot.sql (regenera el CSV) y,
-- en SQLite y en este orden: DELETE FROM snapshot_servidor,
-- .import del CSV, movil/cargar_snapshot.sql (actualiza
-- producto_cache sin borrar filas) y movil/semaforo.sql
-- (esperado: la solicitud de C4a queda RECHAZADO).
--
-- Da de baja logica (activo = false) el primer producto activo
-- (ORDER BY id LIMIT 1), igual que los borradores SQLite de los
-- casos. C3, C5 y C6 no modifican PostgreSQL.
-- No ejecutado en esta revision (psql requiere contrasena
-- interactiva en este entorno): PENDIENTE de ejecucion manual.
-- ============================================================

-- ------------------------------------------------------------
-- Guardia de seguridad: abortar si no es la base de prueba.
-- ------------------------------------------------------------
DO $$
BEGIN
    IF current_database() <> 'foodstore_tp8_prueba' THEN
        RAISE EXCEPTION 'TP8: base incorrecta (%), se esperaba foodstore_tp8_prueba', current_database();
    END IF;
END $$;

-- ============================================================
-- C4 - Baja logica (solo foodstore_tp8_prueba)
-- ============================================================
-- RETURNING muestra exactamente la fila modificada (una SELECT
-- posterior con ORDER BY id LIMIT 1 podia mostrar otro producto).
UPDATE producto
SET activo = false
WHERE id = (SELECT id FROM producto WHERE activo = true ORDER BY id LIMIT 1)
RETURNING id, nombre, precio, stock, activo;

-- ============================================================
-- Verificacion FINAL (solo lectura, tras C2..C6)
-- cantidad_pedidos y stock_total deben coincidir con el
-- bloque ANTES de sql/tp8_snapshot.sql: la simulacion de la
-- tablet no creo pedidos ni modifico stock en PostgreSQL.
-- ============================================================
SELECT 'DESPUES_TP8' AS momento,
       (SELECT COUNT(*) FROM pedido) AS cantidad_pedidos,
       (SELECT COALESCE(SUM(stock), 0) FROM producto) AS stock_total;
