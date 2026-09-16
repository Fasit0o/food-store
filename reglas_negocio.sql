-- ============================================================
-- TP FOODSTORE - REGLAS DE NEGOCIO B Y C
-- PostgreSQL
-- ============================================================
-- Probar dentro de una transaccion contra foodstore_tp2:
--   BEGIN;
--   <instrucciones de prueba>
--   COMMIT;  -- o ROLLBACK;
--
-- Regla B: un pedido no puede quedar registrado sin al menos un
--          detalle_pedido asociado (valida al COMMIT).
-- Regla C: no se admite un detalle de producto inactivo.
--
-- No se modifican restricciones existentes ni columnas de tablas.
-- PostgreSQL >= 11 (usa EXECUTE FUNCTION).


-- ============================================================
-- REGLA B - TODO PEDIDO DEBE TENER AL MENOS UN DETALLE (AL COMMIT)
-- ============================================================
-- Un CHECK normal no sirve: no puede cruzar tablas. Un trigger AFTER
-- inmediato tampoco: bloquearia el INSERT INTO pedido antes de que
-- existan sus detalles.
--
-- Solucion: constraint triggers DEFERRABLE INITIALLY DEFERRED.
--   * Se disparan por INSERT/UPDATE/DELETE sobre pedido Y sobre
--     detalle_pedido (ambas, porque la violacion puede surgir del
--     alta de un pedido o de la eliminacion del ultimo detalle).
--   * Al ser INITIALLY DEFERRED, su ejecucion se pospone al COMMIT:
--     ahi se evalua el estado FINAL de toda la transaccion y, si hay
--     algun pedido sin detalle, el COMMIT falla (la transaccion se
--     revierte).
--   * Asi se permite el flujo normal:
--       INSERT INTO pedido;
--       INSERT INTO detalle_pedido;
--       COMMIT;  -- ok
--   * Y se impide:
--       INSERT INTO pedido; COMMIT;            -- falla al confirmar
--       DELETE ultimo detalle; COMMIT;         -- falla al confirmar

-- Funcion compartida por ambos constraint triggers.
-- Verifica el invariante global: que NO exista ningun pedido
-- sin al menos un registro en detalle_pedido.
CREATE OR REPLACE FUNCTION fn_verificar_pedido_sin_detalle()
RETURNS TRIGGER
LANGUAGE plpgsql
AS $$
BEGIN
    IF EXISTS (
        SELECT 1
        FROM pedido p
        WHERE NOT EXISTS (
            SELECT 1
            FROM detalle_pedido d
            WHERE d.pedido_id = p.id
        )
    ) THEN
        RAISE EXCEPTION
            'No puede confirmarse la transaccion: existe al menos un pedido sin detalle en detalle_pedido';
    END IF;

    -- Los AFTER triggers ignoran el valor devuelto.
    RETURN NULL;
END;
$$;

-- Se dispara con cualquier cambio en pedido (alta, modificacion, baja)
-- y retiene su chequeo hasta el COMMIT.
-- DROP TRIGGER IF EXISTS trg_ck_pedido_con_detalle ON pedido;
CREATE CONSTRAINT TRIGGER trg_ck_pedido_con_detalle
    AFTER INSERT OR UPDATE OR DELETE
    ON pedido
    DEFERRABLE INITIALLY DEFERRED
    FOR EACH ROW
    EXECUTE FUNCTION fn_verificar_pedido_sin_detalle();

-- Se dispara con cualquier cambio en detalle_pedido (necesario para
-- detectar la ELIMINACION del ultimo detalle de un pedido).
-- DROP TRIGGER IF EXISTS trg_ck_detalle_pedido_con_detalle ON detalle_pedido;
CREATE CONSTRAINT TRIGGER trg_ck_detalle_pedido_con_detalle
    AFTER INSERT OR UPDATE OR DELETE
    ON detalle_pedido
    DEFERRABLE INITIALLY DEFERRED
    FOR EACH ROW
    EXECUTE FUNCTION fn_verificar_pedido_sin_detalle();

-- Nota: los constraint triggers solo soportan INSERT/UPDATE/DELETE.
-- Un TRUNCATE sobre detalle_pedido (o pedido) NO los dispararia.
-- Si se quiere cubrir ese caso, agregar estos triggers normales
-- (no constraint), que corren la misma verificacion por sentencia:
--
--   CREATE OR REPLACE FUNCTION fn_truncate_verificar_pedido_sin_detalle()
--   RETURNS TRIGGER LANGUAGE plpgsql AS $$
--   BEGIN
--       IF EXISTS (
--           SELECT 1
--           FROM pedido p
--           WHERE NOT EXISTS (
--               SELECT 1 FROM detalle_pedido d WHERE d.pedido_id = p.id
--           )
--       ) THEN
--           RAISE EXCEPTION 'No puede truncarse: existe un pedido sin detalle';
--       END IF;
--       RETURN NULL;
--   END;
--   $$;
--
--   CREATE TRIGGER trg_truncate_detalle_pedido
--       AFTER TRUNCATE ON detalle_pedido
--       FOR EACH STATEMENT
--       EXECUTE FUNCTION fn_truncate_verificar_pedido_sin_detalle();


-- ============================================================
-- REGLA C - PRODUCTO INACTIVO NO ADMITE DETALLE
-- ============================================================
-- Trigger inmediato (no diferido): rechaza en el acto cualquier
-- INSERT/UPDATE de detalle_pedido cuyo producto tenga activo = FALSE.

CREATE OR REPLACE FUNCTION trg_fn_validar_producto_activo()
RETURNS TRIGGER
LANGUAGE plpgsql
AS $$
DECLARE
    v_activo BOOLEAN;
BEGIN
    SELECT activo
    INTO v_activo
    FROM producto
    WHERE id = NEW.producto_id;

    IF NOT COALESCE(v_activo, FALSE) THEN
        RAISE EXCEPTION
            'El producto % no esta activo y no puede incluirse en un pedido',
            NEW.producto_id;
    END IF;

    RETURN NEW;
END;
$$;

-- DROP TRIGGER IF EXISTS trg_detalle_pedido_producto_activo ON detalle_pedido;
CREATE TRIGGER trg_detalle_pedido_producto_activo
    BEFORE INSERT OR UPDATE OF producto_id
    ON detalle_pedido
    FOR EACH ROW
    EXECUTE FUNCTION trg_fn_validar_producto_activo();


-- ============================================================
-- EJEMPLOS DE PRUEBA (descomentar para ejecutar)
-- ============================================================
-- -- Flujo normal aceptado:
-- BEGIN;
-- INSERT INTO pedido (forma_pago, cliente_id) VALUES ('EFECTIVO', 1);
-- INSERT INTO detalle_pedido (pedido_id, producto_id, cantidad, precio_unitario)
-- VALUES (LASTVAL(), 1, 2, 100.00);
-- COMMIT;
--
-- -- Pedido sin detalle: el COMMIT falla.
-- BEGIN;
-- INSERT INTO pedido (forma_pago, cliente_id) VALUES ('EFECTIVO', 1);
-- COMMIT;  -- ERROR
--
-- -- Eliminar el ultimo detalle: el COMMIT falla.
-- BEGIN;
-- DELETE FROM detalle_pedido
-- WHERE pedido_id = 1 AND producto_id = 1;
-- COMMIT;  -- ERROR
--
-- -- Producto inactivo: falla en el INSERT (inmediato).
-- UPDATE producto SET activo = FALSE WHERE id = 2;
-- INSERT INTO detalle_pedido (pedido_id, producto_id, cantidad, precio_unitario)
-- VALUES (1, 2, 1, 50.00);  -- ERROR

