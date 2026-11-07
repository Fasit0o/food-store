-- ============================================================
-- TP FOODSTORE - PARTE B: ACTIVACION Y PRUEBA DE LA AUDITORIA
-- Base de Datos II - PostgreSQL 18.6
-- Base de trabajo: foodstore_tp3_prueba
-- ------------------------------------------------------------
-- ESTADO: PREPARADO, NO EJECUTADO EN ESTA REVISION.
-- Motivo (ver docs/informe_auditoria.md): la sesion psql requiere
-- contrasena (pg_hba.conf scram-sha-256) y no se posee; por tanto
-- no se ejecuto ALTER SYSTEM ni las pruebas controladas en esta
-- revision. Este script queda listo para ejecucion manual.
--
-- Que prueba: SELECT, INSERT, UPDATE y login fallido, de forma
-- breve, controlada y reversible, solo sobre foodstore_tp3_prueba:
--   - SELECT: lecturas de verificacion (sin cambios).
--   - INSERT/UPDATE: sobre un registro sintetico @foodstore.test
--     dentro de transaccion con ROLLBACK (nunca persiste).
--   - Login fallido: NO es SQL; es un psql con credencial
--     inexistente/incorrecta (ver seccion 4).
--
-- Reglas de seguridad:
--   - Solo datos sinteticos (@foodstore.test). Nunca emails reales.
--   - Verificar current_database() = 'foodstore_tp3_prueba'.
--   - Sin TRUNCATE, DROP, DELETE masivo ni cambios estructurales.
--   - Si una sentencia da ERROR inesperado, detener y revisar.
-- ============================================================

-- ------------------------------------------------------------
-- 0. CONFIGURACION DE AUDITORIA (manual, pendiente de ejecucion)
-- ------------------------------------------------------------
-- Metodo recomendado en este entorno (B: inspeccion de
-- postgresql.conf/postgresql.auto.conf): ALTER SYSTEM, que escribe
-- en postgresql.auto.conf, seguido de recarga (reload). No editar
-- postgresql.conf a mano ni reiniciar si basta con reload.
--
-- Valores propuestos (ver docs/informe_auditoria.md):
--   log_connections = 'all'  -- registra aspectos de cada conexion
--   log_disconnections = 'on' -- registra cierre/duracion
--   log_statement = 'all' TEMPORAL durante la ventana de prueba,
--     luego revertir a 'none'. Ver correccion B3 (BITACORA.md):
--     'mod' NO alcanza: registra INSERT/UPDATE/DELETE pero NO
--     SELECT, y la consigna exige evidencia en log de SELECT,
--     INSERT, UPDATE, conexion exitosa/fallida y
--     usuario/base/fecha. 'all' es el unico log_statement que
--     captura todo en una sola ventana controlada acotada.
--     'ddl' tampoco alcanza (solo DDL). la reutilizacion
--     'mod' quedaria como valor habitual posterior, nunca como
--     evidencia de esta prueba.
--   log_directory / log_filename: se mantienen por defecto
--     ('log' / 'postgresql-%Y-%m-%d_%H%M%S.log') porque ya se
--     localizo el archivo real via current_logfiles.
--   logging_collector = on (ya activo en postgresql.conf)
--
-- Comandos (ejecutar CONECTADO COMO SUPERUSUARIO, con contrasena
-- ingresada interactivamente; nunca commitear la contrasena):
--   psql -U postgres -d foodstore_tp3_prueba
--   ALTER SYSTEM SET log_connections = 'all';
--   ALTER SYSTEM SET log_disconnections = 'on';
--   ALTER SYSTEM SET log_statement = 'all';  -- TEMPORAL
--   -- Recarga (SIGHUP; aplica a sesiones nuevas):
--   SELECT pg_reload_conf();
--   -- Verificacion:
--   SHOW log_connections;      -- esperado: all
--   SHOW log_disconnections;   -- esperado: on
--   SHOW log_statement;        -- esperado: all (solo en ventana)
--   SHOW logging_collector;    -- esperado: on
--   SHOW log_directory;        -- esperado: log
--   SHOW log_filename;         -- esperado: patron por fecha
--   SHOW config_file;          -- ruta de postgresql.conf
--   -- AL TERMINAR LA PRUEBA (misma sesion superusuario):
--   ALTER SYSTEM SET log_statement = 'none';
--   SELECT pg_reload_conf();
--   SHOW log_statement;        -- esperado: none
--
-- Consideracion: al activar log_statement='all', las sesiones
-- nuevas registrarán SELECT/INSERT/UPDATE (conveniente para
-- la consigna). Es mas verboso y puede incluir literales
-- sensibles, por eso se limita a una ventana breve con datos
-- sinteticos @foodstore.test y sin volcar filas reales. No
-- dejar 'all' permanente. Las sesiones ya abiertas no heredan
-- el cambio hasta reconectar.

-- ------------------------------------------------------------
-- 1. SELECT (lectura; no modifica datos)
-- ------------------------------------------------------------
-- Ejecutar conectado como rol de la aplicacion (app_web) o como
-- postgres para verificacion. Registrar current_user/base primero:
SELECT current_user AS usuario_prueba, current_database() AS base_prueba;
-- Debe ser 'foodstore_tp3_prueba'.
SELECT count(*) AS total_clientes_legibles FROM cliente;
SELECT count(*) AS total_productos FROM producto;
SELECT count(*) AS total_pedidos FROM pedido;
SELECT count(*) AS total_v_productos FROM v_productos_activos;

-- ------------------------------------------------------------
-- 2. INSERT (transaccion con ROLLBACK; no persiste)
-- ------------------------------------------------------------
-- Conectado como app_web (INSERT sobre cliente via rol_app_escritura).
-- Registro sintetico, dominio .test; respeta NOT NULL y UNIQUE(email)
-- (cliente: id, nombre, apellido, email; ver foodstore.session.sql).
-- Se verifica por id (RETURNING), NO por email: app_web no tiene
-- SELECT sobre cliente.email por la Parte A.
BEGIN;
INSERT INTO cliente (nombre, apellido, email)
VALUES ('Prueba', 'Auditoria', 'auditoria.prueba@foodstore.test')
RETURNING id;
-- Verificacion dentro de la transaccion (por id devuelto):
-- SELECT id, nombre, apellido FROM cliente WHERE id = lastval();
ROLLBACK;
-- Verificacion posterior (fuera de la transaccion):
-- SELECT count(*) AS filas_persistidas_ins FROM cliente
--   WHERE nombre = 'Prueba' AND apellido = 'Auditoria';
-- Debe dar 0 (el INSERT no persistio).

-- ------------------------------------------------------------
-- 3. UPDATE (transaccion con ROLLBACK; no persiste)
-- ------------------------------------------------------------
-- Conectado como app_web. Se inserta un registro sintetico y se
-- modifica por su id (lastval(), NO por email: app_web no puede
-- leer email). Siempre con ROLLBACK final.
BEGIN;
INSERT INTO cliente (nombre, apellido, email)
VALUES ('Prueba', 'Auditoria', 'auditoria.prueba@foodstore.test')
RETURNING id;
UPDATE cliente SET apellido = 'AuditoriaModificado'
WHERE id = lastval()
RETURNING id, nombre, apellido;
ROLLBACK;
-- Verificacion posterior: debe dar 0 filas persistidas, igual que
-- en la seccion 2 (conteo por nombre/apellido sintetico).

-- ------------------------------------------------------------
-- 4. INTENTO DE LOGIN FALLIDO (NO es SQL)
-- ------------------------------------------------------------
-- No existe una sentencia SQL para "intentar autenticarse con
-- contrasena incorrecta": la autenticacion ocurre al abrir la
-- conexion. Ejecutar desde la terminal local, de forma controlada:
--
--   $env:PGPASSWORD = 'contrasena_intencionalmente_incorrecta'
--   psql -h localhost -U rol_inexistente_parteB -d foodstore_tp3_prueba
--   Remove-Item Env:PGPASSWORD
--
-- Alternativa interactiva (sin almacenar la contrasena):
--   psql -h localhost -U app_web -d foodstore_tp3_prueba
--   (ingresar una contrasena INCORRECTA a proposito)
--
-- Resultado esperado: FATAL: password authentication failed
-- (rol inexistente puede dar "no existe el rol" según pg_hba;
-- en ambos casos el evento queda en el log si logging_collector=on).
-- Condicion: pg_hba.conf debe exigir contrasena (scram-sha-256 en
-- este entorno, B). Si la conexion fuera 'trust', no habría fallo
-- significativo y debe documentarse como limitacion.
-- Registrar en docs/log_auditoria_prueba.txt: fecha/hora, rol
-- intentado y linea de log extraida, SIN la contrasena intentada.

-- ------------------------------------------------------------
-- 5. Verificacion de cierre (solo lectura)
-- ------------------------------------------------------------
-- Confirmar que no quedo ningun registro sintetico (ejecutar como
-- postgres/admin_datos; como app_web el WHERE sobre email daría
-- permission denied por la Parte A):
-- SELECT count(*) AS registros_sinteticos_restantes
-- FROM cliente
-- WHERE email LIKE '%@foodstore.test';
-- Debe dar 0.
