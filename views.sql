-- ============================================================
-- TP FOODSTORE - PARTE B: VISTAS
-- Base de Datos II
-- ------------------------------------------------------------
-- Tres vistas de solo lectura sobre el esquema de FoodStore.
-- Cada vista expone columnas explícitas según specs/views.md.
-- No se usa SELECT * en ninguna definición.
-- ============================================================


-- ------------------------------------------------------------
-- V1: v_productos_activos
--
-- Expone el catálogo de productos activos junto con el nombre
-- de su categoría. Aplica el filtro producto.activo = TRUE
-- internamente; el consumidor no necesita conocer esa columna.
--
-- Columnas omitidas deliberadamente:
--   producto.activo    — ya está implícito en el filtro WHERE
--   categoria.id       — disponible como categoria_id desde producto
--   categoria.activo   — no relevante para este caso de uso
-- ------------------------------------------------------------
CREATE VIEW v_productos_activos AS
SELECT p.id             AS producto_id,
       p.nombre,
       p.precio,
       p.stock,
       p.categoria_id,
       c.nombre         AS categoria
FROM producto p
JOIN categoria c ON c.id = p.categoria_id
WHERE p.activo = TRUE;


-- ------------------------------------------------------------
-- V2: v_pedidos_cliente
--
-- Expone pedidos junto con los datos de identificación del
-- cliente (nombre, apellido, email). Sin filtro interno:
-- el filtrado por cliente, fecha o forma de pago queda en
-- manos de la consulta que usa la vista.
--
-- Nota de seguridad: la tabla cliente no tiene columna password
-- en el modelo actual. Las columnas se listan explícitamente
-- para que cualquier columna sensible que se agregue en el
-- futuro (p. ej. password_hash) no aparezca automáticamente.
--
-- Columnas omitidas deliberadamente:
--   cliente.id   — disponible como cliente_id desde pedido
-- ------------------------------------------------------------
CREATE VIEW v_pedidos_cliente AS
SELECT p.id             AS pedido_id,
       p.fecha,
       p.forma_pago,
       p.cliente_id,
       cl.nombre,
       cl.apellido,
       cl.email
FROM pedido p
JOIN cliente cl ON cl.id = p.cliente_id;


-- ------------------------------------------------------------
-- V3: v_detalle_pedido_producto
--
-- Expone las líneas de detalle de pedidos junto con el nombre
-- del producto. Sin filtro interno: las líneas históricas son
-- válidas aunque el producto esté actualmente desactivado.
--
-- Columnas omitidas deliberadamente:
--   producto.precio      — es el precio vigente, distinto del
--                          precio_unitario histórico del detalle
--   producto.stock       — no relevante para detalle histórico
--   producto.activo      — no afecta la validez del detalle
--   producto.categoria_id — no necesario en este caso de uso
-- ------------------------------------------------------------
CREATE VIEW v_detalle_pedido_producto AS
SELECT dp.pedido_id,
       dp.producto_id,
       pr.nombre        AS nombre_producto,
       dp.cantidad,
       dp.precio_unitario
FROM detalle_pedido dp
JOIN producto pr ON pr.id = dp.producto_id;
