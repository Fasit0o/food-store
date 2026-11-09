PRAGMA foreign_keys = ON;

-- ============================================================
-- cargar_snapshot.sql — TP8 Importacion del snapshot en SQLite
-- Tabla de staging snapshot_servidor (NO es parte de
-- schema_sqlite.sql, que define solo las 4 tablas principales).
-- snapshot_servidor guarda el CSV tal como vino del servidor;
-- desde ella se carga/actualiza producto_cache SIN borrar filas
-- fisicas (relevante para C4: la baja logica no elimina la fila).
--
-- Orden de uso (sqlite3 CLI, ver README):
--   1) sqlite3 movil/foodstore_movil.db < movil/schema_sqlite.sql
--   2) sqlite3 movil/foodstore_movil.db ".import --csv --skip 1 movil/servidor_snapshot.csv snapshot_servidor"
--      (requiere ejecutar antes el CREATE TABLE de abajo)
--   3) sqlite3 movil/foodstore_movil.db < movil/cargar_snapshot.sql
--
-- snapshot_servidor NO usa STRICT a proposito: es staging del
-- CSV (texto) y sus columnas INTEGER aplican afinidad numerica,
-- de modo que "15000" del CSV se almacena como entero 15000 y
-- las comparaciones del semaforo son numericas, no lexicas.
-- Si el CSV se regenera (C2/C4), repetir: DELETE + .import + este script.
-- ============================================================

CREATE TABLE IF NOT EXISTS snapshot_servidor (
    id INTEGER PRIMARY KEY,
    nombre TEXT NOT NULL,
    precio_centavos INTEGER NOT NULL,
    stock_visto INTEGER NOT NULL,
    disponible INTEGER NOT NULL,
    eliminado INTEGER NOT NULL,
    fecha_copia TEXT NOT NULL
);

-- Carga inicial y recarga por id, en dos pasos equivalentes a un
-- upsert (esta version de SQLite no acepta INSERT ... SELECT ...
-- ON CONFLICT: verificado por ejecucion):
--   1) inserta los productos nuevos,
--   2) actualiza los existentes en lugar de borrarlos/reemplazarlos,
--      para no romper las FOREIGN KEY de item_borrador ni perder
--      el historial local (relevante para C4).
INSERT OR IGNORE INTO producto_cache
    (id, nombre, precio_centavos, stock_visto, disponible, eliminado, fecha_copia)
SELECT id, nombre, precio_centavos, stock_visto, disponible, eliminado, fecha_copia
FROM snapshot_servidor;

UPDATE producto_cache
SET nombre = (SELECT nombre FROM snapshot_servidor WHERE id = producto_cache.id),
    precio_centavos = (SELECT precio_centavos FROM snapshot_servidor WHERE id = producto_cache.id),
    stock_visto = (SELECT stock_visto FROM snapshot_servidor WHERE id = producto_cache.id),
    disponible = (SELECT disponible FROM snapshot_servidor WHERE id = producto_cache.id),
    eliminado = (SELECT eliminado FROM snapshot_servidor WHERE id = producto_cache.id),
    fecha_copia = (SELECT fecha_copia FROM snapshot_servidor WHERE id = producto_cache.id)
WHERE EXISTS (SELECT 1 FROM snapshot_servidor WHERE id = producto_cache.id);

-- Verificacion (solo lectura).
SELECT 'SNAPSHOT' AS origen, COUNT(*) AS filas FROM snapshot_servidor
UNION ALL
SELECT 'PRODUCTO_CACHE' AS origen, COUNT(*) AS filas FROM producto_cache;
