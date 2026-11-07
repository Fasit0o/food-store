-- health_check.sql — Chequeo de solo lectura para foodstore (PostgreSQL 16+)
-- Ejecutar: psql -h localhost -p 5432 -U postgres -d foodstore -f health_check.sql

\pset pager off

-- Control 1: tamano de la base
SELECT datname, pg_size_pretty(pg_database_size('foodstore')) AS tamano
FROM pg_database WHERE datname = 'foodstore';

-- Control 2: actividad de conexiones
SELECT datname, numbackends, xact_commit, xact_rollback
FROM pg_stat_database WHERE datname = 'foodstore';

-- Control 3: estado de tablas (mayor a menor tuplas muertas)
SELECT relname, n_live_tup, n_dead_tup, last_autovacuum, last_autoanalyze
FROM pg_stat_user_tables
ORDER BY n_dead_tup DESC;

-- Control 4: consultas activas (sin idle)
SELECT pid, state, now() - query_start AS duracion, query
FROM pg_stat_activity
WHERE datname = 'foodstore' AND state <> 'idle' AND pid <> pg_backend_pid()
ORDER BY query_start;
