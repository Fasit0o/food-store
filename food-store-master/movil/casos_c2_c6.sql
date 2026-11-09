PRAGMA foreign_keys = ON;

-- ============================================================
-- casos_c2_c6.sql — TP8 Consigna 2.C (parte SQLite)
-- Casos C2..C6 en orden. Los casos C2 y C4 tienen un
-- DETENERSE intermedio: en C2 se ejecuta el script PostgreSQL
-- independiente sql/tp8_caso_c2_postgresql.sql y en C4 el
-- script independiente sql/tp8_caso_c4_postgresql.sql, ambos
-- solo sobre foodstore_tp8_prueba, seguidos de una nueva
-- instantanea (CSV) para importar en SQLite.
--
-- Los borradores usan subconsultas sobre producto_cache, por lo
-- que NO dependen de ids concretos del catalogo: siempre usan
-- el primer producto disponible (ORDER BY id LIMIT 1).
-- UUIDs 100% sinteticos. Sin datos personales reales.
-- Cada solicitud de cola_sync tiene un solicitud_uuid UNICO y
-- distinto (C2a, C2b, C3, C4, C5); el unico reuso intencional
-- es C6, que reintenta el UUID de C5 para demostrar la
-- violacion de PRIMARY KEY.
-- Ejecutar SIN la opcion -bail (sqlite3 CLI): el error esperado
-- de C6 debe mostrarse y el ROLLBACK posterior debe ejecutarse.
--
-- ANTES de empezar: schema + snapshot cargados (README pasos 1-6)
-- y ejecutar movil/pruebas_sqlite.sql si se desea.
-- Despues de cada bloque: ejecutar movil/semaforo.sql
-- y verificar el estado indicado como "Esperado".
-- ============================================================

-- ============================================================
-- C2a. Cambio de precio — parte 1 (SQLite)
-- Borrador con el precio ACTUAL de producto_cache.
-- ============================================================
INSERT INTO pedido_borrador (id_local, usuario, forma_pago, fecha)
VALUES ('c2000000-0000-4000-8000-000000000001', 'usuario_prueba', 'EFECTIVO', '2026-01-02 09:00:00');

INSERT INTO item_borrador (id_local, producto_id, cantidad, precio_centavos_visto)
SELECT 'c2000000-0000-4000-8000-000000000001',
       id, 1, precio_centavos
FROM producto_cache
WHERE disponible = 1 AND eliminado = 0
ORDER BY id
LIMIT 1;

INSERT INTO cola_sync (solicitud_uuid, id_local, estado, motivo)
VALUES ('c2000000-1000-4200-8200-0000000000a1', 'c2000000-0000-4000-8000-000000000001', 'PENDIENTE', NULL);

-- >>> DETENERSE AQUI <<<
-- Ejecutar en PostgreSQL de PRUEBA (foodstore_tp8_prueba) el
-- script sql/tp8_caso_c2_postgresql.sql: sube el precio
-- del primer producto activo. Luego, en SQLite:
--   DELETE FROM snapshot_servidor;
--   .import --csv --skip 1 movil/servidor_snapshot.csv snapshot_servidor
--   sqlite3 movil/foodstore_movil.db < movil/cargar_snapshot.sql
--   sqlite3 movil/foodstore_movil.db < movil/semaforo.sql
-- Esperado: la solicitud c200....0a1 queda CONFLICTO
-- (precio visto <> precio actual del servidor).

-- ============================================================
-- C2b. Cambio de precio — parte 2 (SQLite, tras la detencion)
-- Se actualiza el precio visto al nuevo precio del servidor y
-- se crea una solicitud NUEVA (UUID nuevo). La anterior queda
-- CONFLICTO (no se re-evalua: idempotencia).
-- ============================================================
UPDATE item_borrador
SET precio_centavos_visto = (
    SELECT precio_centavos FROM snapshot_servidor WHERE id = producto_id
)
WHERE id_local = 'c2000000-0000-4000-8000-000000000001';

INSERT INTO cola_sync (solicitud_uuid, id_local, estado, motivo)
VALUES ('c2000000-2000-4300-8300-0000000000a2', 'c2000000-0000-4000-8000-000000000001', 'PENDIENTE', NULL);

-- Ejecutar movil/semaforo.sql
-- Esperado: c200....0a2 queda SIMULADO_APROBADO (NO es venta real);
-- c200....0a1 sigue CONFLICTO.

-- ============================================================
-- C3. Stock insuficiente
-- Cantidad = stock_visto + 1 del primer producto disponible.
-- ============================================================
INSERT INTO pedido_borrador (id_local, usuario, forma_pago, fecha)
VALUES ('c3000000-0000-4000-8000-000000000001', 'usuario_prueba', 'TARJETA', '2026-01-02 09:10:00');

INSERT INTO item_borrador (id_local, producto_id, cantidad, precio_centavos_visto)
SELECT 'c3000000-0000-4000-8000-000000000001',
       id, stock_visto + 1, precio_centavos
FROM producto_cache
WHERE disponible = 1 AND eliminado = 0
ORDER BY id
LIMIT 1;

INSERT INTO cola_sync (solicitud_uuid, id_local, estado, motivo)
VALUES ('c3000000-3000-4400-8400-0000000000b1', 'c3000000-0000-4000-8000-000000000001', 'PENDIENTE', NULL);

-- Ejecutar movil/semaforo.sql
-- Esperado: RECHAZADO con motivo de stock insuficiente.

-- ============================================================
-- C4a. Baja logica — parte 1 (SQLite)
-- Borrador con el primer producto disponible actual.
-- ============================================================
INSERT INTO pedido_borrador (id_local, usuario, forma_pago, fecha)
VALUES ('c4000000-0000-4000-8000-000000000001', 'usuario_prueba', 'TRANSFERENCIA', '2026-01-02 09:20:00');

INSERT INTO item_borrador (id_local, producto_id, cantidad, precio_centavos_visto)
SELECT 'c4000000-0000-4000-8000-000000000001',
       id, 1, precio_centavos
FROM producto_cache
WHERE disponible = 1 AND eliminado = 0
ORDER BY id
LIMIT 1;

INSERT INTO cola_sync (solicitud_uuid, id_local, estado, motivo)
VALUES ('c4000000-4000-4500-8500-0000000000c1', 'c4000000-0000-4000-8000-000000000001', 'PENDIENTE', NULL);

-- >>> DETENERSE AQUI <<<
-- Ejecutar en PostgreSQL de PRUEBA el script
-- sql/tp8_caso_c4_postgresql.sql: da de baja logica
-- (activo = false) el primer producto activo. Luego, en SQLite:
--   DELETE FROM snapshot_servidor;
--   .import --csv --skip 1 movil/servidor_snapshot.csv snapshot_servidor
--   sqlite3 movil/foodstore_movil.db < movil/semaforo.sql
-- Esperado: la solicitud c400....0a1 queda RECHAZADO
-- (producto dado de baja en la instantanea).

-- ============================================================
-- C4b. Baja logica — parte 2: recargar catalogo
-- cargar_snapshot.sql actualiza producto_cache (upsert):
-- el producto pasa a disponible=0/eliminado=1 SIN desaparecer
-- fisicamente. Verificar:
-- ============================================================
-- Ejecutar: sqlite3 movil/foodstore_movil.db < movil/cargar_snapshot.sql
SELECT id, nombre, disponible, eliminado
FROM producto_cache
WHERE eliminado = 1;

-- Y el catalogo disponible (C1) ya no lo muestra:
SELECT id, nombre
FROM producto_cache
WHERE disponible = 1 AND eliminado = 0
ORDER BY id;

-- ============================================================
-- C5. Sin cambios
-- Borrador que coincide exactamente con la instantanea actual.
-- ============================================================
INSERT INTO pedido_borrador (id_local, usuario, forma_pago, fecha)
VALUES ('c5000000-0000-4000-8000-000000000001', 'usuario_prueba', 'EFECTIVO', '2026-01-02 09:30:00');

INSERT INTO item_borrador (id_local, producto_id, cantidad, precio_centavos_visto)
SELECT 'c5000000-0000-4000-8000-000000000001',
       id, 1, precio_centavos
FROM producto_cache
WHERE disponible = 1 AND eliminado = 0
ORDER BY id
LIMIT 1;

INSERT INTO cola_sync (solicitud_uuid, id_local, estado, motivo)
VALUES ('c5000000-5000-4600-8600-0000000000d1', 'c5000000-0000-4000-8000-000000000001', 'PENDIENTE', NULL);

-- Ejecutar movil/semaforo.sql
-- Esperado: SIMULADO_APROBADO (NO es venta real).

-- ============================================================
-- C6. Idempotencia / UUID repetido
-- Re-insertar la solicitud_uuid de C5 debe fallar por PRIMARY KEY
-- (UNIQUE constraint failed). ERROR ESPERADO, no ocultar.
-- ============================================================
BEGIN;
-- ERROR ESPERADO: UNIQUE constraint failed: cola_sync.solicitud_uuid
INSERT INTO cola_sync (solicitud_uuid, id_local, estado, motivo)
VALUES ('c5000000-5000-4600-8600-0000000000d1', 'c5000000-0000-4000-8000-000000000001', 'PENDIENTE', NULL);
ROLLBACK;

-- Re-ejecutar movil/semaforo.sql: las solicitudes ya
-- clasificadas NO vuelven a evaluarse (solo procesa PENDIENTE).
-- Verificar que conteo por estado no cambia entre dos corridas:
SELECT estado, COUNT(*) AS solicitudes
FROM cola_sync
GROUP BY estado
ORDER BY estado;
