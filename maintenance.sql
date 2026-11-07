-- maintenance.sql — Revisión semanal para foodstore (PostgreSQL 16+)
-- 1. REVISIÓN PREVIA: observar estado actual antes de actuar.
-- 2. ACCIÓN: solo si se justifica por el estado observado (ver resultado previo).
-- 3. RESULTADO POSTERIOR: repetir la revisión para verificar.
-- Nunca VACUUM FULL. Si autovacuum/autoanalyze funcionan, no ejecutar VACUUM/ANALYZE innecesario.

\pset pager off

-- 1. REVISION PREVIA
SELECT relname, n_live_tup, n_dead_tup, last_autovacuum, last_autoanalyze
FROM pg_stat_user_tables
ORDER BY n_dead_tup DESC;

-- Árbol de autovacuum (status actual)
SELECT schemaname, relname, last_autovacuum, last_autoanalyze
FROM pg_stat_user_tables
ORDER BY n_dead_tup DESC;

-- 2. ACCIÓN (documentar justificación según la revisión previa)
-- Ejemplo justificado solo si hay alto volumen de muertas sin autovacuum reciente:
-- VACUUM (ANALYZE) <tabla>;
-- Por defecto no se fuerza mantenimiento agresivo: se deja comentado hasta observar el resultado previo.

-- 3. RESULTADO POSTERIOR (descomentar tras ejecutar la acción justificada, o re-ejecutar el bloque 1)
SELECT relname, n_live_tup, n_dead_tup, last_autovacuum, last_autoanalyze
FROM pg_stat_user_tables
ORDER BY n_dead_tup DESC;
