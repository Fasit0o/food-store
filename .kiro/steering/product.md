# Product

**FoodStore** is an academic database design project (TP-1, Base de Datos II). It models the backend data layer for a simple food store, covering product catalog management, customer records, and order processing.

## Core Domain

- **Customers** (`cliente`): registered buyers identified by email.
- **Categories** (`categoria`): groupings for products, can be activated/deactivated.
- **Products** (`producto`): catalog items with price, stock, and category assignment.
- **Orders** (`pedido`): purchases made by customers, recorded with payment method and date.
- **Order details** (`detalle_pedido`): line items linking orders to products with quantity and unit price at time of purchase.

## Payment Methods

Orders support three payment types via the `forma_pago_enum`: `EFECTIVO`, `TARJETA`, `TRANSFERENCIA`.
