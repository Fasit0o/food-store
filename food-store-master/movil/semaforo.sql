PRAGMA foreign_keys = ON;

-- ============================================================
-- semaforo.sql — TP8 Consigna 2.B
-- Compara solicitudes PENDIENTE contra snapshot_servidor
-- (instantanea del servidor importada desde el CSV) y las
-- clasifica SIN tocar PostgreSQL y SIN crear ventas reales:
--
--   ROJO    -> RECHAZADO          (producto inexistente,
--                                    no disponible, dado de baja
--                                    o stock insuficiente)
--   AMARILLO-> CONFLICTO          (precio visto <> precio actual)
--   VERDE   -> SIMULADO_APROBADO  (coincide con la instantanea;
--                                    NO es una venta real)
--
-- Regla central: "La tablet propone, el servidor dispone."
-- Idempotencia: SOLO se evaluan solicitudes en estado PENDIENTE.
-- Re-ejecutar este script NO re-evalua las ya clasificadas.
--
-- Prerequisito: snapshot_servidor cargado (ver cargar_snapshot.sql
-- y README). Si falta la tabla, el script falla con error claro.
-- ============================================================

-- Estado previo (solo lectura, para ver que se va a evaluar).
SELECT 'ANTES' AS momento, estado, COUNT(*) AS solicitudes
FROM cola_sync
GROUP BY estado
ORDER BY estado;

WITH clasif AS (
    SELECT
        c.solicitud_uuid AS solicitud_uuid,
        COUNT(ib.producto_id) AS n_items,
        SUM(CASE WHEN ib.producto_id IS NOT NULL AND ss.id IS NULL
                 THEN 1 ELSE 0 END) AS n_inexistente,
        SUM(CASE WHEN ss.id IS NOT NULL
                      AND (ss.disponible = 0 OR ss.eliminado = 1)
                 THEN 1 ELSE 0 END) AS n_no_disponible,
        SUM(CASE WHEN ss.id IS NOT NULL
                      AND ib.cantidad > ss.stock_visto
                 THEN 1 ELSE 0 END) AS n_sin_stock,
        SUM(CASE WHEN ss.id IS NOT NULL
                      AND ib.precio_centavos_visto <> ss.precio_centavos
                 THEN 1 ELSE 0 END) AS n_precio_distinto
    FROM cola_sync c
    LEFT JOIN item_borrador ib
           ON ib.id_local = c.id_local
    LEFT JOIN snapshot_servidor ss
           ON ss.id = ib.producto_id
    WHERE c.estado = 'PENDIENTE'
    GROUP BY c.solicitud_uuid
)
UPDATE cola_sync
SET estado = (
        SELECT CASE
            WHEN cl.n_items = 0 THEN 'RECHAZADO'
            WHEN cl.n_inexistente + cl.n_no_disponible + cl.n_sin_stock > 0 THEN 'RECHAZADO'
            WHEN cl.n_precio_distinto > 0 THEN 'CONFLICTO'
            ELSE 'SIMULADO_APROBADO'
        END
        FROM clasif cl
        WHERE cl.solicitud_uuid = cola_sync.solicitud_uuid
    ),
    motivo = (
        SELECT CASE
            WHEN cl.n_items = 0
                THEN 'RECHAZADO: el borrador no tiene items.'
            WHEN cl.n_inexistente > 0
                THEN 'RECHAZADO: producto inexistente en la instantanea del servidor.'
            WHEN cl.n_no_disponible > 0
                THEN 'RECHAZADO: producto no disponible o dado de baja en la instantanea del servidor.'
            WHEN cl.n_sin_stock > 0
                THEN 'RECHAZADO: stock insuficiente en la instantanea del servidor.'
            WHEN cl.n_precio_distinto > 0
                THEN 'CONFLICTO: el precio visto difiere del precio actual del servidor; requiere revision.'
            ELSE 'SIMULADO_APROBADO: coincide con la instantanea del servidor. NO es una venta real.'
        END
        FROM clasif cl
        WHERE cl.solicitud_uuid = cola_sync.solicitud_uuid
    )
WHERE solicitud_uuid IN (SELECT solicitud_uuid FROM clasif);

-- Estado posterior (solo lectura).
SELECT 'DESPUES' AS momento, estado, COUNT(*) AS solicitudes
FROM cola_sync
GROUP BY estado
ORDER BY estado;

-- Detalle de lo clasificado en esta corrida.
SELECT solicitud_uuid, id_local, estado, motivo
FROM cola_sync
WHERE motivo IS NOT NULL
ORDER BY solicitud_uuid;
