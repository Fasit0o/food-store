-- CONSULTA 1: Listar los cinco pedidos
SELECT id, forma_pago
FROM pedido
WHERE id BETWEEN 1 AND 5
ORDER BY id;

-- CONSULTA 2: Pedidos pagados en efectivo
SELECT id, forma_pago
FROM pedido
WHERE id BETWEEN 1 AND 5
  AND forma_pago = 'EFECTIVO'
ORDER BY id;

-- CONSULTA 3: Pedidos que contienen Agua Mineral (producto_id = 1)
SELECT DISTINCT p.id
FROM pedido p
JOIN detalle_pedido dp ON dp.pedido_id = p.id
WHERE p.id BETWEEN 1 AND 5
  AND dp.producto_id = 1
ORDER BY p.id;

-- CONSULTA 4: Pedidos con total superior a $5000
SELECT
    p.id,
    SUM(dp.cantidad * dp.precio_unitario) AS total
FROM pedido p
JOIN detalle_pedido dp ON dp.pedido_id = p.id
WHERE p.id BETWEEN 1 AND 5
GROUP BY p.id
HAVING SUM(dp.cantidad * dp.precio_unitario) > 5000
ORDER BY p.id;
