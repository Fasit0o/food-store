# TP8 — Design (Kiro)

Food Store · Base de Datos II · Unidad 8.

## Arquitectura

```
PostgreSQL (foodstore_tp8_prueba, SOLO prueba)
  producto(id, nombre, precio numeric, stock, activo, categoria_id)
        │  vista v_snapshot_movil  (sql/tp8_snapshot.sql)
        │  \copy CSV HEADER
        ▼
movil/servidor_snapshot.csv
        │  .import (sqlite3 CLI) → snapshot_servidor (staging)
        │  movil/cargar_snapshot.sql (upsert en producto_cache)
        ▼
SQLite foodstore_movil.db  (movil/schema_sqlite.sql)
  producto_cache · pedido_borrador · item_borrador · cola_sync
        │  movil/semaforo.sql (compara PENDIENTE vs snapshot_servidor)
        ▼
  RECHAZADO / CONFLICTO / SIMULADO_APROBADO  (solo simulación, sin venta)
```

**Responsabilidad:** PostgreSQL es la única fuente de verdad para
precios, stock y ventas. SQLite solo consulta una instantánea y arma
borradores; nunca modifica PostgreSQL. La tablet propone, el servidor
dispone. `SIMULADO_APROBADO` significa "coincide con la instantánea y
pasaría la validación simulada"; NO crea un pedido ni una venta en
PostgreSQL.

## Tablas SQLite (STRICT, `PRAGMA foreign_keys = ON;`)

- **producto_cache**: instantánea del catálogo. `id` conserva el de
  PostgreSQL (bigint → INTEGER). `precio_centavos INTEGER >= 0`,
  `stock_visto`, `disponible 0/1`, `eliminado 0/1`, `fecha_copia`.
  En PostgreSQL solo existe `activo boolean` (baja lógica), por lo que
  la vista expone `disponible = activo` y `eliminado = NOT activo`.
- **pedido_borrador**: `id_local TEXT` (UUID local, 36 caracteres),
  `usuario` sintético, `forma_pago` ∈ {EFECTIVO, TARJETA,
  TRANSFERENCIA}, `fecha`.
- **item_borrador**: PK compuesta (`id_local`, `producto_id`),
  FK a `pedido_borrador` (ON DELETE CASCADE) y a `producto_cache`,
  `cantidad > 0`, `precio_centavos_visto >= 0` (precio que la
  tablet vio al crear el borrador).
- **cola_sync**: `solicitud_uuid TEXT PRIMARY KEY` (36 caracteres),
  FK a `pedido_borrador`, `estado` ∈ {PENDIENTE, CONFLICTO,
  RECHAZADO, SIMULADO_APROBADO}, `motivo` explicativo.
- **snapshot_servidor** (staging, fuera de `schema_sqlite.sql`):
  copia del CSV para comparar. Sin STRICT a propósito: sus columnas
  INTEGER aplican afinidad numérica, de modo que el texto del CSV se
  almacena como entero y las comparaciones del semáforo son
  numéricas.

## Semáforo (`movil/semaforo.sql`)

Un solo `UPDATE` con CTE de agregación y `LEFT JOIN` a
`snapshot_servidor` (evita errores por NULL cuando el producto no
existe). Por solicitud PENDIENTE cuenta ítems inexistentes, no
disponibles/dados de baja, sin stock y con precio distinto:

- algún problema de existencia/disponibilidad/baja/stock → RECHAZADO
- solo precio distinto → CONFLICTO
- sin problemas → SIMULADO_APROBADO (motivo aclara que no es venta)

**Idempotencia:** el CTE filtra `estado = 'PENDIENTE'`, por lo que
re-ejecutar el semáforo no reevalúa solicitudes clasificadas; y la
PRIMARY KEY de `solicitud_uuid` impide duplicados. En un sistema real
la idempotencia también debe existir en el servidor (clave
idempotente UNIQUE + transacción).

## Casos C2–C6

Los borradores usan subconsultas ("primer producto disponible")
para no depender de ids concretos del catálogo. C2 y C4 intercalan
cambios en `foodstore_tp8_prueba` (precio +1.00; `activo = false`)
con re-exportación de la instantánea. C3/C5/C6 no tocan PostgreSQL.
La verificación final compara conteo de `pedido` y suma de `stock`
antes/después: deben coincidir.

## Estado de verificación

SQLite: schema, pruebas (COMMIT/ROLLBACK, C1, C7a/C7b), semáforo y
C2–C6 EJECUTADOS con Python sqlite3 3.50.4 (ver README § Pruebas).
PostgreSQL: scripts GENERADOS y REVISADOS ESTÁTICAMENTE contra el
esquema real extraído del respaldo `backups/foodstore_*.dump`;
PENDIENTES de ejecución manual (psql requiere contraseña
interactiva en este entorno).
