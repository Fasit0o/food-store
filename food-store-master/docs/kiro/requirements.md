# TP8 — Requirements (Kiro)

Food Store · Base de Datos II · Unidad 8: tablet offline (SQLite) + semáforo de sincronización.
Regla central: **"La tablet propone, el servidor dispone."**
Cada requisito usa notación EARS e indica el caso que lo prueba.
Los casos C2–C6 se ejecutan según `movil/casos_c2_c6.sql` y `README.md`.

---

### REQ-01 — Cambio de precio detectado como CONFLICTO

**Requisito:**
WHEN el precio actual del servidor (`snapshot_servidor.precio_centavos`) es distinto del precio visto por la tablet (`item_borrador.precio_centavos_visto`) para un producto que existe, está disponible, no está dado de baja y tiene stock suficiente,
THE SYSTEM SHALL marcar la solicitud en `cola_sync` como `CONFLICTO` con un motivo que indique el cambio de precio, sin crear ninguna venta real.

**Caso que lo prueba:** C2 (ver `movil/casos_c2_c6.sql`, bloques C2a/C2b).
**Estado:** GENERADO; lógica EJECUTADA y verificada en SQLite con Python sqlite3 (instantánea simulada). Pendiente de ejecución manual contra PostgreSQL `foodstore_tp8_prueba`.

---

### REQ-02 — Stock insuficiente detectado como RECHAZADO

**Requisito:**
WHEN la cantidad solicitada en un ítem del borrador (`item_borrador.cantidad`) es mayor que el stock de la instantánea del servidor (`snapshot_servidor.stock_visto`) para ese producto,
THE SYSTEM SHALL marcar la solicitud en `cola_sync` como `RECHAZADO` con un motivo de stock insuficiente, sin modificar el stock de PostgreSQL.

**Caso que lo prueba:** C3 (ver `movil/casos_c2_c6.sql`, bloque C3).
**Estado:** GENERADO; lógica EJECUTADA y verificada en SQLite con Python sqlite3. Pendiente de ejecución manual contra `foodstore_tp8_prueba`.

---

### REQ-03 — Baja lógica detectada como RECHAZADO

**Requisito:**
WHEN un producto del borrador figura dado de baja en la instantánea del servidor (`snapshot_servidor.eliminado = 1` o `disponible = 0`, derivados de `producto.activo = false` en PostgreSQL),
THE SYSTEM SHALL marcar la solicitud en `cola_sync` como `RECHAZADO` con un motivo de baja/no disponibilidad, y al recargar el catálogo la fila de `producto_cache` SHALL actualizarse sin desaparecer físicamente.

**Caso que lo prueba:** C4 (ver `movil/casos_c2_c6.sql`, bloques C4a/C4b, y sección C4 de `sql/tp8_casos_c2_c6_postgresql.sql`).
**Estado:** GENERADO; lógica EJECUTADA y verificada en SQLite con Python sqlite3. Pendiente de ejecución manual contra `foodstore_tp8_prueba`.

---

### REQ-04 — Coincidencia exacta como SIMULADO_APROBADO e idempotencia

**Requisito:**
WHEN todos los productos del borrador existen en la instantánea, están disponibles, no están dados de baja, tienen stock suficiente y los precios coinciden,
THE SYSTEM SHALL marcar la solicitud como `SIMULADO_APROBADO` indicando que NO es una venta real; AND WHEN se reenvía una solicitud con un `solicitud_uuid` ya existente o se re-ejecuta el semáforo,
THE SYSTEM SHALL no duplicar la solicitud (PRIMARY KEY) y SHALL no reevaluar solicitudes que no estén en estado `PENDIENTE`.

**Casos que lo prueban:** C5 (coincidencia) y C6 (idempotencia/UUID repetido), en `movil/casos_c2_c6.sql`.
**Estado:** GENERADO; lógica EJECUTADA y verificada en SQLite con Python sqlite3 (re-ejecución del semáforo sin cambios y rechazo de UUID duplicado). Pendiente de ejecución manual contra `foodstore_tp8_prueba`.
