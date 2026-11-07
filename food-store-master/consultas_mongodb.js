db = db.getSiblingDB("foodstore_nosql");

print("CONSULTA 1: Listar pedidos");
db.pedidos.find(
  {},
  { _id: 1, forma_pago: 1 }
).forEach(printjson);

print("CONSULTA 2: Pedidos pagados en efectivo");
db.pedidos.find(
  { forma_pago: "EFECTIVO" },
  { _id: 1, forma_pago: 1 }
).forEach(printjson);

print("CONSULTA 3: Pedidos que contienen Agua Mineral (producto_id = 1)");
db.pedidos.find(
  { "productos.producto_id": 1 },
  { _id: 1, productos: 1 }
).forEach(printjson);

print("CONSULTA 4: Pedidos con total superior a $5000");
db.pedidos.find(
  { total: { $gt: 5000 } },
  { _id: 1, total: 1 }
).forEach(printjson);
