-- ============================================================
-- tp8_caso_c2_postgresql.sql — TP8 Consigna 2.C, Caso C2 (PostgreSQL)
-- Cambio de precio SOLO sobre foodstore_tp8_prueba (copia de prueba).
-- NUNCA sobre foodstore (base original).
--
-- Ejecutar UNICAMENTE cuando movil/casos_c2_c6.sql llega a su
-- DETENERSE de C2a, con:
--   psql -h localhost -U postgres -d foodstore_tp8_prueba -v ON_ERROR_STOP=1 -f sql/tp8_caso_c2_postgresql.sql
-- Despues: re-ejecutar sql/tp8_snapshot.sql (regenera el CSV),
-- re-importar en SQLite y correr movil/semaforo.sql
-- (esperado: la solicitud de C2a queda CONFLICTO).
--
-- Sube 1.00 el precio del primer producto activo (ORDER BY id
-- LIMIT 1), igual que los borradores SQLite de los casos, para
-- apuntar al mismo producto sin depender de ids concretos.
-- Reconstruir la copia si hace falta: pg_dump de foodstore |
-- pg_restore en foodstore_tp8_prueba (ver README pasos 2-3).
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
-- C2 - Cambio de precio (solo foodstore_tp8_prueba)
-- ============================================================
UPDATE producto
SET precio = precio + 1.00
WHERE id = (SELECT id FROM producto WHERE activo = true ORDER BY id LIMIT 1);

SELECT id, nombre, precio, stock, activo
FROM producto
WHERE id = (SELECT id FROM producto WHERE activo = true ORDER BY id LIMIT 1);
