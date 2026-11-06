-- ============================================================
-- TP FOODSTORE - PARTE A: ROLES Y PERMISOS
-- Base de Datos II - PostgreSQL 18.6
-- ------------------------------------------------------------
-- Contexto real de la base de trabajo (confirmado por el
-- operador, no inferido de los archivos):
--   Base:      foodstore_tp3_prueba
--   Motor:     PostgreSQL 18.6
--   Conectado: como postgres
--   Respaldo:  foodstore_tp3_prueba_antes_tp5.sql
--   Datos:     base con datos reales de prueba que NO deben
--              perderse ni modificarse. Este archivo solo
--              otorga/revoca privilegios; no modifica datos
--              ni estructuras de tablas.
--
-- Estado comprobado en el servidor (segun el operador):
--   Roles existentes -> ver seccion 2. Los siete roles ya
--     existen con INHERIT, sin SUPERUSER/CREATEDB/CREATEROLE.
--   Secuencias, tablas, vistas y vista materializada
--     existentes -> ver secciones 5-8.
--   El procedimiento y las funciones de trigger NO existen
--     en esta base -> ver seccion 9 (sin GRANT/REVOKE
--     activos sobre ellos para no fallar ni inventarlos).
--
-- Decision sobre roles y contrasenas:
--   La consigna exige CREATE ROLE. Los siete roles YA existen
--   en la base de trabajo, por lo que un CREATE ROLE directo
--   daria error duplicate_object y un PASSWORD sobrescribiria
--   la contrasena vigente. Para cumplir la consigna sin
--   recrear ni alterar los existentes, la seccion 2 crea cada
--   rol SOLO si no existe en pg_roles (DO condicional), con
--   LOGIN/NOLOGIN INHERIT y SIN password ni ALTER ROLE sobre
--   los existentes: si el rol ya existe, el bloque no hace
--   nada (no modifica contrasena ni atributos). Las
--   contrasenas NO se guardan en este repositorio.
--   Un LOGIN creado por este bloque nace SIN contrasena y
--   debera configurarla fuera del repo antes de poder
--   autenticarse con password; nunca con un literal commiteado.
--   DUDA/VERIFICACION MANUAL: desde los archivos no se
--   puede confirmar si los tres LOGIN tienen contrasena
--   configurada, ni su metodo de cifrado (SCRAM/MD5), ni
--   si pg_hba.conf exige contrasena. Eso debe verificarse
--   y, de ser necesario, configurarse por separado fuera
--   del repositorio (p. ej. ALTER ROLE con variable de
--   entorno en psql), nunca con un literal commiteado.
--   Este archivo NO contiene ninguna contrasena.
--
-- Orden de este archivo (sin GRANT antes que los roles):
--   1. Verificacion previa (solo comentarios)
--   2. Creacion condicional de roles faltantes
--   3. Membresias
--   4. Hardening + CONNECT/USAGE
--   5-8. Tablas / columna / vistas+MV / secuencias
--   9. EXECUTE adaptado (sin sentencias activas)
--   10. ALTER DEFAULT PRIVILEGES
--   11. Verificaciones (solo comentarios)
--
-- Reglas aplicadas:
--   - Sin SUPERUSER, sin CREATEROLE, sin CREATEDB,
--     sin BYPASSRLS, sin GRANT ALL y sin DDL para la
--     aplicacion. Solo GRANT / REVOKE / ALTER DEFAULT
--     PRIVILEGES sobre los siete roles existentes.
--   - rol_app_lectura NO recibe SELECT sobre
--     v_pedidos_cliente porque esa vista expone
--     cliente.email y contradice el minimo privilegio
--     y el permiso a nivel de columna sobre cliente.
--   - rol_reportes solo lee vistas/MV, nunca tablas base.
--   - rol_app_lectura NO recibe SELECT por defecto sobre
--     tablas futuras (seccion 10): el REVOKE evita que
--     futuras columnas sensibles queden expuestas a
--     app_web por herencia.
--   - NO se ejecuto este archivo contra PostgreSQL al
--     entregarse la correccion.
-- ============================================================

-- ------------------------------------------------------------
-- 1. Verificacion previa (NO otorga nada; ejecutar manual)
-- ------------------------------------------------------------
-- Antes de aplicar lo siguiente, conectarse como postgres
-- a foodstore_tp3_prueba y verificar en la base real:
--   SELECT version();
--   SELECT current_database();
--   \l          -- debe mostrar foodstore_tp3_prueba
--   \du         -- deben aparecer los 7 roles de seccion 2
--   \d+ cliente
--   \d+ producto
--   \d+ pedido
--   \d+ detalle_pedido
--   \d+ categoria
--   \d v_productos_activos
--   \d v_pedidos_cliente
--   \d v_detalle_pedido_producto
--   \d+ mv_ventas_mensuales_forma_pago
--   \ds         -- secuencias: categoria_id_seq,
--                -- cliente_id_seq, pedido_id_seq,
--                -- producto_id_seq
--   \df sp_desactivar_producto
--   \df fn_verificar_pedido_sin_detalle
--   \df trg_fn_validar_producto_activo
--                -- esperado en esta base: los tres NO
--                -- existen (ver comentarios en seccion 9)

-- ------------------------------------------------------------
-- 2. Creacion condicional de roles faltantes (CREATE ROLE)
-- ------------------------------------------------------------
-- Los siguientes siete roles YA existen en el servidor con
-- INHERIT y sin SUPERUSER/CREATEDB/CREATEROLE:
--   Grupos NOLOGIN:  rol_app_lectura, rol_app_escritura,
--                    rol_soporte, rol_reportes
--   LOGIN:           app_web, admin_datos, usuario_reportes
-- El bloque DO crea cada rol SOLO si no existe en pg_roles.
-- Si el rol ya existe, NO lo recrea, NO modifica su contrasena
-- (no hay PASSWORD) y NO altera sus atributos: solo emite un
-- NOTICE. Si un rol existente tuviera atributos distintos de
-- los esperados (p. ej. SUPERUSER), este bloque NO los corrige:
-- debe detectarse con \du y revisarse manualmente. No se emite
-- DROP ROLE. La descripcion de los roles se explica en
-- docs/kiro_roles_spec/. Debe ejecutarse conectado como
-- postgres (unico rol con CREATEROLE en este diseño).
DO $$
BEGIN
    IF NOT EXISTS (SELECT 1 FROM pg_roles WHERE rolname = 'rol_app_lectura') THEN
        EXECUTE format('CREATE ROLE %I WITH NOLOGIN INHERIT', 'rol_app_lectura');
    ELSE
        RAISE NOTICE 'rol_app_lectura ya existe: no se recrea ni se alteran sus atributos';
    END IF;
    IF NOT EXISTS (SELECT 1 FROM pg_roles WHERE rolname = 'rol_app_escritura') THEN
        EXECUTE format('CREATE ROLE %I WITH NOLOGIN INHERIT', 'rol_app_escritura');
    ELSE
        RAISE NOTICE 'rol_app_escritura ya existe: no se recrea ni se alteran sus atributos';
    END IF;
    IF NOT EXISTS (SELECT 1 FROM pg_roles WHERE rolname = 'rol_soporte') THEN
        EXECUTE format('CREATE ROLE %I WITH NOLOGIN INHERIT', 'rol_soporte');
    ELSE
        RAISE NOTICE 'rol_soporte ya existe: no se recrea ni se alteran sus atributos';
    END IF;
    IF NOT EXISTS (SELECT 1 FROM pg_roles WHERE rolname = 'rol_reportes') THEN
        EXECUTE format('CREATE ROLE %I WITH NOLOGIN INHERIT', 'rol_reportes');
    ELSE
        RAISE NOTICE 'rol_reportes ya existe: no se recrea ni se alteran sus atributos';
    END IF;
    IF NOT EXISTS (SELECT 1 FROM pg_roles WHERE rolname = 'app_web') THEN
        EXECUTE format('CREATE ROLE %I WITH LOGIN INHERIT', 'app_web');
    ELSE
        RAISE NOTICE 'app_web ya existe: no se recrea ni se alteran sus atributos';
    END IF;
    IF NOT EXISTS (SELECT 1 FROM pg_roles WHERE rolname = 'admin_datos') THEN
        EXECUTE format('CREATE ROLE %I WITH LOGIN INHERIT', 'admin_datos');
    ELSE
        RAISE NOTICE 'admin_datos ya existe: no se recrea ni se alteran sus atributos';
    END IF;
    IF NOT EXISTS (SELECT 1 FROM pg_roles WHERE rolname = 'usuario_reportes') THEN
        EXECUTE format('CREATE ROLE %I WITH LOGIN INHERIT', 'usuario_reportes');
    ELSE
        RAISE NOTICE 'usuario_reportes ya existe: no se recrea ni se alteran sus atributos';
    END IF;
END $$;

-- ------------------------------------------------------------
-- 3. Membresias (GRANT de rol de grupo TO rol LOGIN)
-- ------------------------------------------------------------
-- app_web: lectura + escritura de la aplicacion web.
-- admin_datos: soporte (lectura completa) + permisos
--   directos de administracion de datos.
-- usuario_reportes: solo reportes.
-- Re-ejecutar un GRANT de membresia ya existente solo
-- produce un WARNING de membresia redundante y no altera
-- los datos; por ello se mantienen como sentencias activas.
GRANT rol_app_lectura TO app_web;
GRANT rol_app_escritura TO app_web;
GRANT rol_soporte TO admin_datos;
GRANT rol_reportes TO usuario_reportes;

-- ------------------------------------------------------------
-- 4. Hardening de PUBLIC (esquema public y base actual)
-- ------------------------------------------------------------
-- En PostgreSQL 15+ PUBLIC ya no tiene CREATE en public por
-- defecto, pero el REVOKE se mantiene como hardening
-- explicito y auditable. El REVOKE CONNECT / GRANT CONNECT sobre
-- la base se hace con current_database() porque, aunque la
-- base de trabajo es foodstore_tp3_prueba, el archivo
-- mantiene la connexion verificada en seccion 1 como
-- referencia y no hardcodea otro nombre.

REVOKE CREATE ON SCHEMA public FROM PUBLIC;

DO $$
BEGIN
    EXECUTE format('REVOKE CONNECT ON DATABASE %I FROM PUBLIC', current_database());
    EXECUTE format('GRANT CONNECT ON DATABASE %I TO app_web', current_database());
    EXECUTE format('GRANT CONNECT ON DATABASE %I TO admin_datos', current_database());
    EXECUTE format('GRANT CONNECT ON DATABASE %I TO usuario_reportes', current_database());
END $$;

GRANT USAGE ON SCHEMA public TO app_web;
GRANT USAGE ON SCHEMA public TO admin_datos;
GRANT USAGE ON SCHEMA public TO usuario_reportes;

-- USAGE sobre el tipo enum usado por pedido.forma_pago.
-- Necesario para SELECT/INSERT sobre pedido y para las
-- vistas que exponen forma_pago. Verificar existencia
-- del tipo junto con \d pedido (seccion 1); si el tipo
-- no existiera en la base real, esta sentencia fallaria
-- y debe detenerse para revision.
GRANT USAGE ON TYPE forma_pago_enum TO app_web;
GRANT USAGE ON TYPE forma_pago_enum TO admin_datos;
GRANT USAGE ON TYPE forma_pago_enum TO usuario_reportes;

-- ------------------------------------------------------------
-- 5. Privilegios sobre tablas base
-- ------------------------------------------------------------
-- 5.1 rol_app_lectura: solo SELECT de catalogo/pedidos.
-- El acceso a cliente es solo a nivel de columna (seccion 6),
-- sin email. No recibe v_pedidos_cliente (expone el email).
GRANT SELECT ON TABLE producto TO rol_app_lectura;
GRANT SELECT ON TABLE categoria TO rol_app_lectura;
GRANT SELECT ON TABLE pedido TO rol_app_lectura;
GRANT SELECT ON TABLE detalle_pedido TO rol_app_lectura;

-- 5.2 rol_app_escritura: registro/modificacion de la app.
-- Sin UPDATE/DELETE sobre pedido: el modelo no contempla
-- modificar ni eliminar pedidos confirmados. Sin UPDATE/
-- DELETE sobre producto/categoria: eso es admin_datos.
GRANT INSERT, UPDATE ON TABLE cliente TO rol_app_escritura;
GRANT SELECT, INSERT ON TABLE pedido TO rol_app_escritura;
GRANT SELECT, INSERT, DELETE ON TABLE detalle_pedido TO rol_app_escritura;
GRANT SELECT ON TABLE producto TO rol_app_escritura;
GRANT SELECT ON TABLE categoria TO rol_app_escritura;

-- 5.3 rol_soporte: lectura completa para diagnostico,
-- incluyendo cliente.email (necesario para incidencias).
GRANT SELECT ON TABLE cliente TO rol_soporte;
GRANT SELECT ON TABLE categoria TO rol_soporte;
GRANT SELECT ON TABLE producto TO rol_soporte;
GRANT SELECT ON TABLE pedido TO rol_soporte;
GRANT SELECT ON TABLE detalle_pedido TO rol_soporte;

-- 5.4 admin_datos (directos, sobre lo heredado de soporte):
-- actualizar producto y mantener categorias. Sin DELETE
-- ni DDL. REFRESH de la MV queda fuera (solo dueno/postgres).
GRANT UPDATE ON TABLE producto TO admin_datos;
GRANT INSERT, UPDATE ON TABLE categoria TO admin_datos;

-- ------------------------------------------------------------
-- 6. Permiso a nivel de columna (cliente sin email)
-- ------------------------------------------------------------
-- rol_app_lectura solo identifica al comprador por
-- id/nombre/apellido. La columna email queda excluida.
GRANT SELECT (id, nombre, apellido) ON TABLE cliente TO rol_app_lectura;

-- ------------------------------------------------------------
-- 7. Privilegios sobre vistas y vista materializada
-- ------------------------------------------------------------
-- 7.1 Vistas para la aplicacion (sin v_pedidos_cliente
-- en lectura, porque expone el email).
GRANT SELECT ON TABLE v_productos_activos TO rol_app_lectura;
GRANT SELECT ON TABLE v_detalle_pedido_producto TO rol_app_lectura;

-- 7.2 Vistas + MV para soporte (lectura completa).
GRANT SELECT ON TABLE v_productos_activos TO rol_soporte;
GRANT SELECT ON TABLE v_pedidos_cliente TO rol_soporte;
GRANT SELECT ON TABLE v_detalle_pedido_producto TO rol_soporte;
GRANT SELECT ON TABLE mv_ventas_mensuales_forma_pago TO rol_soporte;

-- 7.3 Vistas + MV para reportes. Sin acceso a tablas base:
-- las vistas ya exponen las columnas controladas.
GRANT SELECT ON TABLE v_productos_activos TO rol_reportes;
GRANT SELECT ON TABLE v_detalle_pedido_producto TO rol_reportes;
GRANT SELECT ON TABLE mv_ventas_mensuales_forma_pago TO rol_reportes;

-- ------------------------------------------------------------
-- 8. Privilegios sobre secuencias IDENTITY
-- ------------------------------------------------------------
-- Sin USAGE/SELECT, el INSERT con GENERATED ALWAYS AS
-- IDENTITY falla para un rol sin superusuario.
-- detalle_pedido no tiene secuencia (PK compuesta).
-- producto_id_seq existe en la base pero NO se otorga:
-- ningun rol tiene INSERT sobre producto, por lo que
-- otorgarla seria exceso de privilegio.
GRANT USAGE, SELECT ON SEQUENCE cliente_id_seq TO rol_app_escritura;
GRANT USAGE, SELECT ON SEQUENCE pedido_id_seq TO rol_app_escritura;
GRANT USAGE, SELECT ON SEQUENCE categoria_id_seq TO admin_datos;

-- ------------------------------------------------------------
-- 9. Procedimiento y funciones de trigger (sin sentencias
--    activas porque NO existen en esta base)
-- ------------------------------------------------------------
-- Definiciones revisadas en el proyecto (NO en la base):
--   - sp_desactivar_producto(p_producto_id BIGINT) en
--     foodstore.session.sql:102-120 (baja logica de producto).
--   - fn_verificar_pedido_sin_detalle() RETURNS TRIGGER
--     PL/pgSQL en reglas_negocio.sql:44-65.
--   - trg_fn_validar_producto_activo() RETURNS TRIGGER
--     PL/pgSQL en reglas_negocio.sql:120-140.
-- Confirmado por el operador: ninguno de los tres objetos
-- existe en foodstore_tp3_prueba. Las sentencias directas
--   REVOKE EXECUTE ON PROCEDURE sp_desactivar_producto(bigint)
--     FROM PUBLIC;
--   REVOKE EXECUTE ON FUNCTION fn_verificar_pedido_sin_detalle()
--     FROM PUBLIC;
--   REVOKE EXECUTE ON FUNCTION trg_fn_validar_producto_activo()
--     FROM PUBLIC;
--   GRANT EXECUTE ON PROCEDURE sp_desactivar_producto(bigint)
--     TO admin_datos;
-- fallarian con ERROR (objeto inexistente) y no deben
-- ejecutarse en esta base. No se inventan los objetos ni
-- se hace GRANT ALL como alternativa.
-- Cuando (y si) dichos objetos se creen en la base (p. ej.
-- ejecutando foodstore.session.sql / reglas_negocio.sql
-- sobre la base de trabajo verificada), aplicar entonces
-- el REVOKE EXECUTE de PUBLIC y el GRANT EXECUTE a
-- admin_datos el mismo dia, en el orden comentado arriba,
-- y verificarlo con \df. Hasta entonces admin_datos no
-- puede ejecutar una baja logica que no existe, y no se
-- pierde funcionalidad existente.

-- ------------------------------------------------------------
-- 10. ALTER DEFAULT PRIVILEGES (solo futuro, minimo)
-- ------------------------------------------------------------
-- Decision humana: NO se otorga SELECT/INSERT/UPDATE
-- automatico a rol_app_escritura sobre tablas futuras, NO
-- se otorga EXECUTE automatico sobre funciones futuras a
-- admin_datos y NO se otorga nada automatico a rol_reportes.
-- Esos casos se conceden con GRANT explicito por objeto.
-- Los DEFAULT PRIVILEGES solo aplican a partir de su
-- ejecucion y para el FOR ROLE indicado (postgres).
--
-- CORRECCION TP5 (revision completa): la version anterior
-- otorgaba aqui SELECT automatico sobre TODAS las tablas
-- futuras a rol_app_lectura. Eso era inseguro: GRANT SELECT
-- ON TABLES es a nivel de tabla (todas las columnas) y
-- PostgreSQL no permite un DEFAULT PRIVILEGES a nivel de
-- columna. En consecuencia, cualquier tabla futura creada
-- por postgres con datos sensibles (p. ej. email, token,
-- password_hash) habria quedado legible por app_web, que
-- hereda rol_app_lectura, salteando el permiso por columna
-- de la seccion 6 (cliente sin email) y la exclusion de
-- v_pedidos_cliente. Se reemplaza por REVOKE explicito:
-- mantiene el uso de ALTER DEFAULT PRIVILEGES exigido por
-- la consigna sin conceder lectura futura a rol_app_lectura.
-- Las tablas futuras se conceden con GRANT explicito por
-- tabla o por columna, luego de revisar sus datos sensibles.
-- Se conservan solo los dos defaults justificados:
--   - rol_soporte: lectura completa futura, justificada por
--     soporte/diagnostico (ya tiene SELECT con email sobre
--     las tablas actuales, seccion 5.3);
--   - rol_app_escritura: USAGE/SELECT sobre secuencias
--     futuras (sin datos personales; necesario para INSERT
--     con IDENTITY futuros, salvo revision por objeto).
-- Ninguno de ellos concede SELECT sobre tablas futuras a
-- rol_app_lectura ni a rol_app_escritura.

ALTER DEFAULT PRIVILEGES FOR ROLE "postgres" IN SCHEMA public
    REVOKE SELECT ON TABLES FROM rol_app_lectura;

ALTER DEFAULT PRIVILEGES FOR ROLE "postgres" IN SCHEMA public
    GRANT SELECT ON TABLES TO rol_soporte;

ALTER DEFAULT PRIVILEGES FOR ROLE "postgres" IN SCHEMA public
    GRANT USAGE, SELECT ON SEQUENCES TO rol_app_escritura;

-- ------------------------------------------------------------
-- 11. Verificaciones (ejecutar manualmente, no parte del
-- otorgamiento; se dejan comentadas para auditoria)
-- ------------------------------------------------------------
-- \du
-- SELECT r.rolname AS rol_login, m.rolname AS miembro_de
-- FROM pg_roles r
-- JOIN pg_auth_members am ON am.member = r.oid
-- JOIN pg_roles m ON m.oid = am.roleid
-- WHERE r.rolname IN ('app_web', 'admin_datos', 'usuario_reportes')
-- ORDER BY r.rolname, m.rolname;
--
-- SELECT grantee, table_name, privilege_type
-- FROM information_schema.role_table_grants
-- WHERE grantee IN ('rol_app_lectura', 'rol_app_escritura',
--                   'rol_soporte', 'rol_reportes',
--                   'app_web', 'admin_datos', 'usuario_reportes')
-- ORDER BY grantee, table_name, privilege_type;
--
-- SELECT grantee, table_name, column_name, privilege_type
-- FROM information_schema.column_privileges
-- WHERE table_name = 'cliente' AND grantee = 'rol_app_lectura'
-- ORDER BY column_name;
-- -- Esperado: id, nombre, apellido. NO debe aparecer email.
--
-- SELECT defaclrole::regrole AS propietario,
--        defaclnamespace::regnamespace AS esquema,
--        defaclobjtype AS tipo_objeto, defaclacl AS acl
-- FROM pg_default_acl
-- WHERE defaclnamespace = 'public'::regnamespace;
-- -- Esperado tras la correccion TP5: solo 2 entradas
-- -- (SELECT a rol_soporte y USAGE,SELECT secuencias a
-- -- rol_app_escritura). NO debe aparecer ninguna entrada
-- -- SELECT ON TABLES para rol_app_lectura: el REVOKE de
-- -- la seccion 10 no crea una ACL por defecto.
--
-- -- Sin GRANT ALL: TRUNCATE/REFERENCES/TRIGGER solo aparecen
-- -- si se hizo GRANT ALL o privilegios no otorgados aqui.
-- SELECT grantee, table_name, privilege_type
-- FROM information_schema.role_table_grants
-- WHERE grantee IN ('rol_app_lectura', 'rol_app_escritura',
--                   'rol_soporte', 'rol_reportes',
--                   'app_web', 'admin_datos', 'usuario_reportes')
--   AND privilege_type IN ('TRUNCATE', 'REFERENCES', 'TRIGGER');
-- -- Esperado: 0 filas.
