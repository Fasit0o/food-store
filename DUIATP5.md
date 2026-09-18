# DUIA — Base de Datos II — TP5

## Parte B — Vistas

### Vistas de FoodStore

**Herramienta:** Kiro

**Propósito:** definir las tres vistas requeridas para la Parte B del TP5.

**Especificación:** `specs/views.md`

**Propuesta generada:**
- `v_productos_activos`
- `v_pedidos_cliente`
- `v_detalle_pedido_producto`

**Decisión:** aceptada.

**Justificación técnica:**
Las tres vistas utilizan columnas explícitas, simplifican consultas frecuentes y evitan exponer columnas que no son necesarias para cada caso de uso. No se utilizó `SELECT *` en las definiciones.

### Verificación de equivalencia

Se comparó cada vista con su consulta SQL manual equivalente utilizando `EXCEPT`.

Resultados:
- `v_productos_activos`: 0 diferencias.
- `v_pedidos_cliente`: 0 diferencias.
- `v_detalle_pedido_producto`: 0 diferencias.

**Conclusión:** las tres vistas fueron verificadas y producen exactamente los mismos resultados que sus consultas manuales equivalentes.