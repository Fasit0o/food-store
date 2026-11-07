-- ============================================================
-- TP FOODSTORE - PARTE D: ANONIMIZACION DE CLIENTE
-- Base de Datos II - PostgreSQL 18.6
-- ------------------------------------------------------------
-- ESTADO: PREPARADO, NO EJECUTADO.
-- Este archivo NO fue ejecutado contra PostgreSQL al entregarse.
-- No modifica ni destruye los datos originales: solo crea (al
-- ejecutarse manualmente) la TABLA fisica `usuario_anon`, una
-- copia anonimizada derivada de `cliente`. La tabla puede
-- eliminarse (DROP TABLE usuario_anon) sin tocar `cliente`.
--
-- ADAPTACION: la consigna pide una TABLA llamada `usuario_anon`.
-- La base real no tiene tabla `usuario`; tiene `cliente`
-- (id, nombre, apellido, email). Se cumple el nombre literal de
-- la consigna (`usuario_anon`) con contenido derivado de
-- `cliente`: no se crea una tabla `usuario` que no existe. La
-- tabla es una foto (snapshot) al momento de su creacion; si
-- `cliente` cambia despues, debe recrearse para refrescarla.
-- La version anterior como VISTA `cliente_anon` queda sustituida
-- por esta tabla, porque la consigna exige tabla y porque una
-- tabla permite demostrar una anonimización materializada sin
-- exponer los datos originales tras su creacion.
--
-- METODO (determinista, reproducible, sintetico, con md5):
--   - Cada fila original produce siempre el mismo seudo-anonimo
--     para el mismo `id` y la misma SAL (salto) secreta. Se usa
--     md5 (estable entre versiones de PostgreSQL), NO hashtext
--     (no garantizado estable entre versiones) y NO pgcrypto
--     (no esta declarado en el proyecto; no se instala).
--   - id_hash: md5 completo (32 hex) de id+sal+'id'. NO se
--     trunca y NO se conserva el id real. La equivalencia usa
--     count(DISTINCT id_hash) = count(DISTINCT id) si el hash
--     es 1:1, y el JOIN de equivalencia se hace por hash.
--   - nombre/apellido: nombres ficticios de una lista cerrada
--     derivada por columna con md5(id+sal+'nombre'/'apellido').
--   - email: 'cliente_' + md5(id+sal+'email')[1:12] + '@anonimo.test'.
--   - ADVERTENCIA: md5 no es una funcion criptografica moderna.
--     Se usa solo como identificador derivado determinista para
--     esta practica; la seguridad depende de mantener secreta la
--     sal. Si la sal se expone, existe riesgo de enumeracion/
--     reidentificacion por diccionario.
--
-- SAL (secreto): NO commitear el valor real. Antes de ejecutar,
-- reemplazar el marcador <SALTO_SECRETO> SOLO en la copia local
-- de trabajo (fuera del repositorio) por un valor generado para
-- la prueba. Con la misma sal, el resultado es reproducible; con
-- otra sal, cambia. Un hash sin sal secreta de un id/email
-- conocido es vulnerable a diccionario.
-- ============================================================

-- ------------------------------------------------------------
-- 1. Tabla anonimizada (determinista y reproducible)
-- ------------------------------------------------------------
-- RECONSTRUCCION EXPLICITA: el DROP siguiente solo elimina la
-- tabla DERIVADA usuario_anon (artefacto de esta Parte D), nunca
-- a `cliente`, y es necesario para reconstruir el snapshot con la
-- sal de la copia local. NO es un borrado silencioso: si
-- usuario_anon contuviera datos ajenos a esta prueba, detenerse
-- y revisar antes de ejecutar.
DROP TABLE IF EXISTS usuario_anon;
CREATE TABLE usuario_anon (
    id_hash TEXT NOT NULL,
    nombre_anon VARCHAR(100) NOT NULL,
    apellido_anon VARCHAR(100) NOT NULL,
    email_anon VARCHAR(150) NOT NULL,
    CONSTRAINT pk_usuario_anon PRIMARY KEY (id_hash),
    CONSTRAINT uq_usuario_anon_email UNIQUE (email_anon)
);

-- REEMPLAZAR <SALTO_SECRETO> en la copia local antes de ejecutar.
-- Lista de nombres ficticios: valores sinteticos, sin relacion
-- con los datos reales de la base.
INSERT INTO usuario_anon (id_hash, nombre_anon, apellido_anon, email_anon)
SELECT
    md5(c.id::text || '<SALTO_SECRETO>' || 'id') AS id_hash,
    (ARRAY[
        'Ana', 'Bruno', 'Carla', 'Diego', 'Elena',
        'Fabio', 'Greta', 'Hugo', 'Ines', 'Jorge'
    ])[1 + ((('x' || substr(md5(c.id::text || '<SALTO_SECRETO>' || 'nombre'), 1, 2))::bit(8)::int) % 10)]
        AS nombre_anon,
    (ARRAY[
        'Alvarez', 'Benitez', 'Castro', 'Duarte', 'Espinoza',
        'Ferrari', 'Gomez', 'Herrera', 'Ibarra', 'Juarez'
    ])[1 + ((('x' || substr(md5(c.id::text || '<SALTO_SECRETO>' || 'apellido'), 1, 2))::bit(8)::int) % 10)]
        AS apellido_anon,
    'cliente_' || substr(md5(c.id::text || '<SALTO_SECRETO>' || 'email'), 1, 12)
        || '@anonimo.test' AS email_anon
FROM cliente c;

-- Propiedades esperadas (a verificar tras ejecutar):
--   - 1 fila en usuario_anon por cada fila de cliente (1:1 por hash).
--   - Mismo id + misma sal => mismo seudo-anonimo (reproducible).
--   - Ninguna columna contiene el id real, nombres, apellidos ni
--     emails reales.
-- PERMISOS: no se otorga SELECT a ningun rol de la aplicacion.
-- Solo postgres (dueno) y, si se justifica, rol_soporte para
-- verificacion. Otorgarlo a rol_app_lectura reintroduciria el
-- problema de la Parte A.

-- ------------------------------------------------------------
-- 2. Consulta agregada sobre datos ORIGINALES
-- ------------------------------------------------------------
-- Alcance (ver docs/verificacion_equivalencia.md §3): JOIN internos;
-- pedidos con al menos un detalle; clientes participantes; agrupacion
-- por forma_pago y mes. clientes sin pedidos no se incluyen.
-- Agrupa por dimensiones NO identificables (forma de pago y mes),
-- para que pueda compararse fila a fila con la seccion 3.
SELECT
    p.forma_pago,
    date_trunc('month', p.fecha) AS mes,
    count(DISTINCT p.id) AS cantidad_pedidos,
    count(DISTINCT p.cliente_id) AS cantidad_clientes,
    sum(dp.cantidad * dp.precio_unitario) AS monto_total
FROM pedido p
JOIN cliente c ON c.id = p.cliente_id
JOIN detalle_pedido dp ON dp.pedido_id = p.id
GROUP BY p.forma_pago, date_trunc('month', p.fecha)
ORDER BY p.forma_pago, mes;

-- ------------------------------------------------------------
-- 3. Consulta agregada EQUIVALENTE sobre datos ANONIMIZADOS
-- ------------------------------------------------------------
-- Misma estructura, mismos GROUP BY y mismos conteos. La tabla
-- anonimizada se une por hash: el id real NO esta en la tabla.
-- REEMPLAZAR <SALTO_SECRETO> igual que en la seccion 1.
SELECT
    p.forma_pago,
    date_trunc('month', p.fecha) AS mes,
    count(DISTINCT p.id) AS cantidad_pedidos,
    count(DISTINCT ua.id_hash) AS cantidad_clientes,
    sum(dp.cantidad * dp.precio_unitario) AS monto_total
FROM pedido p
JOIN usuario_anon ua
  ON ua.id_hash = md5(p.cliente_id::text || '<SALTO_SECRETO>' || 'id')
JOIN detalle_pedido dp ON dp.pedido_id = p.id
GROUP BY p.forma_pago, date_trunc('month', p.fecha)
ORDER BY p.forma_pago, mes;

-- ------------------------------------------------------------
-- 4. Verificacion de equivalencia (comparacion por EXCEPT)
-- ------------------------------------------------------------
-- Si ambas consultas agregadas son equivalentes, cada EXCEPT
-- debe devolver 0 filas. No se afirma equivalencia hasta que
-- estas consultas se ejecuten y den 0 (ver
-- docs/verificacion_equivalencia.md).
SELECT 'original_menos_anonimo' AS diferencia, count(*) AS filas
FROM (
    SELECT p.forma_pago, date_trunc('month', p.fecha) AS mes,
           count(DISTINCT p.id) AS cantidad_pedidos,
           count(DISTINCT p.cliente_id) AS cantidad_clientes,
           sum(dp.cantidad * dp.precio_unitario) AS monto_total
    FROM pedido p
    JOIN cliente c ON c.id = p.cliente_id
    JOIN detalle_pedido dp ON dp.pedido_id = p.id
    GROUP BY p.forma_pago, date_trunc('month', p.fecha)
    EXCEPT
    SELECT p.forma_pago, date_trunc('month', p.fecha) AS mes,
           count(DISTINCT p.id) AS cantidad_pedidos,
           count(DISTINCT ua.id_hash) AS cantidad_clientes,
           sum(dp.cantidad * dp.precio_unitario) AS monto_total
    FROM pedido p
    JOIN usuario_anon ua
      ON ua.id_hash = md5(p.cliente_id::text || '<SALTO_SECRETO>' || 'id')
    JOIN detalle_pedido dp ON dp.pedido_id = p.id
    GROUP BY p.forma_pago, date_trunc('month', p.fecha)
) d
UNION ALL
SELECT 'anonimo_menos_original' AS diferencia, count(*) AS filas
FROM (
    SELECT p.forma_pago, date_trunc('month', p.fecha) AS mes,
           count(DISTINCT p.id) AS cantidad_pedidos,
           count(DISTINCT ua.id_hash) AS cantidad_clientes,
           sum(dp.cantidad * dp.precio_unitario) AS monto_total
    FROM pedido p
    JOIN usuario_anon ua
      ON ua.id_hash = md5(p.cliente_id::text || '<SALTO_SECRETO>' || 'id')
    JOIN detalle_pedido dp ON dp.pedido_id = p.id
    GROUP BY p.forma_pago, date_trunc('month', p.fecha)
    EXCEPT
    SELECT p.forma_pago, date_trunc('month', p.fecha) AS mes,
           count(DISTINCT p.id) AS cantidad_pedidos,
           count(DISTINCT p.cliente_id) AS cantidad_clientes,
           sum(dp.cantidad * dp.precio_unitario) AS monto_total
    FROM pedido p
    JOIN cliente c ON c.id = p.cliente_id
    JOIN detalle_pedido dp ON dp.pedido_id = p.id
    GROUP BY p.forma_pago, date_trunc('month', p.fecha)
) d;

-- ------------------------------------------------------------
-- 5. Validaciones seguras (solo conteos/indicadores; no imprimir
--    nombres, apellidos ni emails reales)
-- ------------------------------------------------------------
-- 5.1 Conteo 1:1 (evidencia documental segura):
-- SELECT
--   (SELECT count(*) FROM cliente) AS total_cliente,
--   (SELECT count(*) FROM usuario_anon) AS total_anonimo,
--   (SELECT count(*) FROM cliente) = (SELECT count(*) FROM usuario_anon) AS iguales;
-- 5.2 id_hash sin duplicados (PK lo garantiza, pero se valida):
-- SELECT count(*) AS duplicados_id_hash FROM (
--   SELECT id_hash FROM usuario_anon GROUP BY id_hash HAVING count(*) > 1
-- ) d;
-- 5.3 Nombres/apellidos solo de las listas sinteticas (conteos):
-- Comparar contra cliente podria coincidir por azar y no prueba
-- copia; por eso se valida pertenencia a las listas del INSERT.
-- SELECT
--   (SELECT count(*) FROM usuario_anon
--    WHERE nombre_anon NOT IN ('Ana','Bruno','Carla','Diego','Elena',
--                               'Fabio','Greta','Hugo','Ines','Jorge'))
--     AS nombres_fuera_de_lista,
--   (SELECT count(*) FROM usuario_anon
--    WHERE apellido_anon NOT IN ('Alvarez','Benitez','Castro','Duarte',
--                                'Espinoza','Ferrari','Gomez','Herrera',
--                                'Ibarra','Juarez'))
--     AS apellidos_fuera_de_lista;
-- Esperado: 0 en ambos casos. No mostrar nombres ni filas.
-- 5.4 Emails con dominio .test (conteo de no conformes):
-- SELECT count(*) AS emails_no_test FROM usuario_anon
-- WHERE email_anon NOT LIKE '%@anonimo.test';
-- Esperado: 0. No mostrar emails ni nombres/apellidos reales.
-- 5.5 Ausencia de id real (indicador, sin mostrar hashes):
-- SELECT count(*) AS sin_id_real_visible FROM usuario_anon
-- WHERE id_hash !~ '^[0-9a-f]{32}$';
-- Esperado: 0 (todo id_hash es hex md5 completo de 32).

-- ------------------------------------------------------------
-- 6. Limpieza (opcional; la tabla es derivada y no altera
--    los datos originales)
-- ------------------------------------------------------------
-- DROP TABLE IF EXISTS usuario_anon;
