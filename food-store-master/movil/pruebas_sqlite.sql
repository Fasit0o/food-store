PRAGMA foreign_keys = ON;

-- ============================================================
-- pruebas_sqlite.sql — TP8 Consigna 1.C
-- Base: foodstore_movil.db (SQLite, creada con schema_sqlite.sql)
-- Alcance: SOLO SQLite local. No toca PostgreSQL.
-- Datos: 100% sinteticos (ids 900001/900002, usuarios_prueba,
--        UUID sinteticos). Sin datos personales reales.
-- Estado: GENERADO y verificado con Python sqlite3 (ver README).
--        Re-ejecutable: las inserciones de catalogo usan
--        INSERT OR IGNORE para no fallar si ya existen.
--
-- Forma de ejecucion recomendada (sqlite3 CLI):
--   sqlite3 movil/foodstore_movil.db < movil/pruebas_sqlite.sql
-- SIN la opcion -bail: los errores ESPERADOS del Caso C7 deben
-- mostrarse en pantalla y el script debe continuar, para que el
-- lector vea claramente que restriccion salto. Si se usa
-- DB Browser for SQLite, ejecutar bloque por bloque.
-- ============================================================

-- ------------------------------------------------------------
-- 0. Catalogo sintetico minimo (standalone, sin PostgreSQL)
-- ------------------------------------------------------------
-- Simula una instantanea ya cargada en producto_cache.
-- Si ya cargaste el snapshot real, estas filas sinteticas
-- conviven con el catalogo real y no lo modifican.
INSERT OR IGNORE INTO producto_cache
    (id, nombre, precio_centavos, stock_visto, disponible, eliminado, fecha_copia)
VALUES
    (900001, 'Agua Mineral Prueba', 15000, 10, 1, 0, '2026-01-01 00:00:00'),
    (900002, 'Gaseosa Prueba Sin Stock', 22000, 0, 0, 0, '2026-01-01 00:00:00');

-- ------------------------------------------------------------
-- 1. Borrador completo con COMMIT
--    pedido_borrador + item_borrador + cola_sync (PENDIENTE)
-- ------------------------------------------------------------
BEGIN;
INSERT INTO pedido_borrador (id_local, usuario, forma_pago, fecha)
VALUES ('11111111-1111-4111-8111-111111111111', 'usuario_prueba', 'EFECTIVO', '2026-01-01 10:00:00');

INSERT INTO item_borrador (id_local, producto_id, cantidad, precio_centavos_visto)
VALUES ('11111111-1111-4111-8111-111111111111', 900001, 2, 15000);

INSERT INTO cola_sync (solicitud_uuid, id_local, estado, motivo)
VALUES ('aaaaaaaa-aaaa-4aaa-8aaa-aaaaaaaaaaaa', '11111111-1111-4111-8111-111111111111', 'PENDIENTE', NULL);
COMMIT;

-- Verificacion: el borrador quedo almacenado.
SELECT 'COMMIT_OK' AS caso,
       pb.id_local, pb.usuario, pb.forma_pago, ib.producto_id,
       ib.cantidad, ib.precio_centavos_visto, cs.estado
FROM pedido_borrador pb
JOIN item_borrador ib ON ib.id_local = pb.id_local
JOIN cola_sync cs ON cs.id_local = pb.id_local
WHERE pb.id_local = '11111111-1111-4111-8111-111111111111';

-- ------------------------------------------------------------
-- 2. Operacion con ROLLBACK: no debe quedar almacenada
-- ------------------------------------------------------------
BEGIN;
INSERT INTO pedido_borrador (id_local, usuario, forma_pago, fecha)
VALUES ('22222222-2222-4222-8222-222222222222', 'usuario_prueba', 'TARJETA', '2026-01-01 10:05:00');

INSERT INTO item_borrador (id_local, producto_id, cantidad, precio_centavos_visto)
VALUES ('22222222-2222-4222-8222-222222222222', 900001, 1, 15000);

INSERT INTO cola_sync (solicitud_uuid, id_local, estado, motivo)
VALUES ('bbbbbbbb-bbbb-4bbb-8bbb-bbbbbbbbbbbb', '22222222-2222-4222-8222-222222222222', 'PENDIENTE', NULL);
ROLLBACK;

-- Verificacion: debe dar 0 (nada de esta operacion persistio).
SELECT 'ROLLBACK_OK' AS caso, COUNT(*) AS filas_restantes
FROM pedido_borrador
WHERE id_local = '22222222-2222-4222-8222-222222222222';

-- ------------------------------------------------------------
-- 3. Caso C1 — Catalogo disponible SIN conexion a PostgreSQL
--    (consulta offline sobre producto_cache)
-- ------------------------------------------------------------
SELECT 'C1_CATALOGO_DISPONIBLE' AS caso,
       id, nombre, precio_centavos, stock_visto
FROM producto_cache
WHERE disponible = 1 AND eliminado = 0
ORDER BY nombre;

-- ------------------------------------------------------------
-- 4. Caso C7 — Errores ESPERADOS (no ocultar)
--    Cada intento va en su propia transaccion con ROLLBACK
--    y conteo posterior. Los errores deben verse en pantalla:
--      4a: CHECK constraint failed (cantidad > 0)
--      4b: FOREIGN KEY constraint failed (producto inexistente)
-- ------------------------------------------------------------

-- 4a. Cantidad = 0 -> debe fallar por CHECK (cantidad > 0).
BEGIN;
INSERT INTO pedido_borrador (id_local, usuario, forma_pago, fecha)
VALUES ('33333333-3333-4333-8333-333333333333', 'usuario_prueba', 'EFECTIVO', '2026-01-01 10:10:00');

-- ERROR ESPERADO: CHECK constraint failed: cantidad > 0
INSERT INTO item_borrador (id_local, producto_id, cantidad, precio_centavos_visto)
VALUES ('33333333-3333-4333-8333-333333333333', 900001, 0, 15000);
ROLLBACK;

SELECT 'C7a_CANTIDAD_CERO' AS caso, COUNT(*) AS filas_nuevas
FROM item_borrador
WHERE id_local = '33333333-3333-4333-8333-333333333333';

-- 4b. Producto inexistente (999999) -> debe fallar por FOREIGN KEY.
BEGIN;
INSERT INTO pedido_borrador (id_local, usuario, forma_pago, fecha)
VALUES ('44444444-4444-4444-8444-444444444444', 'usuario_prueba', 'TRANSFERENCIA', '2026-01-01 10:15:00');

-- ERROR ESPERADO: FOREIGN KEY constraint failed
INSERT INTO item_borrador (id_local, producto_id, cantidad, precio_centavos_visto)
VALUES ('44444444-4444-4444-8444-444444444444', 999999, 1, 15000);
ROLLBACK;

SELECT 'C7b_PRODUCTO_INEXISTENTE' AS caso, COUNT(*) AS filas_nuevas
FROM item_borrador
WHERE id_local = '44444444-4444-4444-8444-444444444444';
