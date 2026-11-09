# Informe — TP8 · Food Store (Base de Datos II)

Tablet offline con SQLite y semáforo de sincronización.
**Regla central: "La tablet propone, el servidor dispone."**
Estados usados: GENERADO · REVISADO ESTÁTICAMENTE · EJECUTADO ·
VERIFICADO · PENDIENTE DE EJECUCIÓN MANUAL.
La parte SQLite fue EJECUTADA y VERIFICADA con Python sqlite3
(SQLite 3.50.4, snapshot simulado) y ratificada en la ejecución
manual con el snapshot real (ver §2.c). La parte PostgreSQL fue
GENERADA y REVISADA ESTÁTICAMENTE contra el DDL real extraído del
respaldo `backups/foodstore_20261107_103401.dump` y EJECUTADA
manualmente por el alumno sobre la copia aislada
`foodstore_tp8_prueba` (resultados en §2.c, atribuidos a esa
ejecución manual; este informe no reproduce salidas de consola ni
capturas). Lo único PENDIENTE es la conversión a PDF.

Organización según consigna: §1.a datos que viajan · §2.c casos
C2–C6 · §3.a mapa de motores · §3.b mantenimiento · §3.c code
review con IA.

## 1.a · Datos que viajan de PostgreSQL a la tablet

| Dato (vista `v_snapshot_movil`) | Viaja | Destino SQLite | Observación |
|---|:---:|---|---|
| `id` | Sí | `producto_cache.id` | Identificador original de PostgreSQL |
| `nombre` | Sí | `producto_cache.nombre` | Nombre del producto |
| `precio` → `precio_centavos` | Sí | `producto_cache.precio_centavos` | `numeric(10,2)` → centavos enteros (`ROUND(precio*100)`) |
| `stock` | Sí | `producto_cache.stock_visto` | Stock al momento de la copia |
| `activo` → `disponible` | Sí | `producto_cache.disponible` | `1` si activo, `0` si baja lógica |
| `activo` → `eliminado` | Sí | `producto_cache.eliminado` | `0` si activo, `1` si baja lógica |
| `CURRENT_TIMESTAMP` | Sí | `producto_cache.fecha_copia` | Fecha de la instantánea |
| `categoria_id` | No | — | No lo necesita la tablet para vender |
| `cliente.email`, `cliente.*` | No | — | Datos personales; nunca viajan |
| `pedido`, `detalle_pedido` | No | — | Ventas reales; solo viven en el servidor |
| Usuarios, roles, contraseñas | No | — | Seguridad y privacidad |

PostgreSQL es la **fuente de verdad** (precios, stock, ventas).
SQLite mantiene una **instantánea local** (`producto_cache`) con
`fecha_copia`: puede estar desactualizada y el semáforo la compara
contra la instantánea del servidor (`snapshot_servidor`) antes de
clasificar. La tablet nunca modifica stock ni precios del servidor.

## 2.c · Casos C2–C6

Preparación común: pasos 1–6 del README (base de prueba, vista,
CSV, importación). Los borradores usan "primer producto disponible"
(subconsulta), sin ids fijos. Comandos SQLite:
`sqlite3 movil/foodstore_movil.db < movil/casos_c2_c6.sql` por
bloques y `sqlite3 movil/foodstore_movil.db < movil/semaforo.sql`
tras cada bloque. Los pasos PostgreSQL están en dos archivos
independientes, uno por caso, ambos solo sobre
`foodstore_tp8_prueba`: `sql/tp8_caso_c2_postgresql.sql`
(cambio de precio) y `sql/tp8_caso_c4_postgresql.sql`
(baja lógica). El archivo combinado anterior
(`sql/tp8_casos_c2_c6_postgresql.sql`) quedó obsoleto, sin
sentencias ejecutables, y no debe usarse.

| Caso | Preparación (comando/paso) | Resultado esperado | Resultado real |
|---|---|---|---|
| C2 cambio de precio | 1) Borrador C2a en SQLite. 2) `sql/tp8_caso_c2_postgresql.sql` (`precio+1.00`). 3) Nueva instantánea CSV. 4) Vaciar `snapshot_servidor` e importar el CSV nuevo. 5) `cargar_snapshot.sql`. 6) `semaforo.sql` | CONFLICTO | SQLite (simulado): CONFLICTO ✓. PG (manual, `foodstore_tp8_prueba`): CONFLICTO; producto ID 1 con precio 851.00 |
| C2 (2ª parte) | 7) C2b con precio actualizado y UUID nuevo. 8) `semaforo.sql` | SIMULADO_APROBADO; C2a conserva su CONFLICTO | SQLite: SIMULADO_APROBADO ✓. PG (manual): SIMULADO_APROBADO con UUID nuevo ✓ |
| C3 stock insuficiente | Borrador con `cantidad = stock+1` + semáforo | RECHAZADO (stock insuficiente) | SQLite: RECHAZADO ✓. PG (manual): RECHAZADO ✓ |
| C4 baja lógica | 1) Borrador C4a en SQLite. 2) `sql/tp8_caso_c4_postgresql.sql` (`activo=false`). 3) Nueva instantánea CSV. 4) Vaciar `snapshot_servidor` e importar el CSV nuevo. 5) `cargar_snapshot.sql` (actualiza `producto_cache` sin borrar filas). 6) `semaforo.sql` | RECHAZADO; verificando que el producto permanece en `producto_cache` con `disponible=0`, `eliminado=1` | SQLite: RECHAZADO ✓. PG (manual): RECHAZADO; producto ID 1 sigue en caché con `disponible=0`, `eliminado=1` ✓ |
| C5 sin cambios | Borrador igual a la instantánea + semáforo | SIMULADO_APROBADO (**no** es venta) | SQLite: SIMULADO_APROBADO ✓. PG (manual): SIMULADO_APROBADO sin generar venta real ✓ |
| C6 idempotencia | Re-insertar el `solicitud_uuid` de C5; re-ejecutar semáforo | El UUID repetido viola la PRIMARY KEY de `cola_sync.solicitud_uuid` y SQLite informa `UNIQUE constraint failed`. La solicitud ya procesada no se vuelve a evaluar y la segunda ejecución del semáforo no cambia los estados | SQLite: `UNIQUE constraint failed` ✓. PG/manual: reenvío rechazado; solicitudes 6 antes y 6 después; C5 conserva su estado ✓ |

Pruebas base (Consigna 1.C):

- **SQLite con snapshot simulado (ejecutado en la sesión de IA,
  Python sqlite3 3.50.4):** COMMIT deja el borrador (1 fila),
  ROLLBACK deja 0 filas, C1 lista solo disponibles sin conexión a
  PostgreSQL, C7a falla con `CHECK constraint failed: cantidad > 0`,
  C7b falla con `FOREIGN KEY constraint failed`, ambas sin filas
  nuevas. Lógica C2–C6 verificada con instantánea simulada.
- **Ejecución manual del alumno (snapshot real + PostgreSQL de
  prueba):** snapshot importado con 50.014 productos, sin IDs
  faltantes ni duplicados; COMMIT/ROLLBACK comprobados;
  C7a (CHECK, cantidad no válida rechazada) y C7b (FK, producto
  inexistente rechazado) comprobados; C2a CONFLICTO, C2b
  SIMULADO_APROBADO, C3 RECHAZADO, C4 RECHAZADO (producto ID 1 en
  caché con `disponible=0`/`eliminado=1`), C5 SIMULADO_APROBADO
  sin venta real, C6 con 6 solicitudes antes y después.
- **PostgreSQL `foodstore_tp8_prueba` (ejecución manual):**
  pedidos 200.006 antes y después; stock total 2.475.979 antes y
  después; producto ID 1 con precio 851.00 y `activo=false`
  tras C2/C4. Ningún pedido real generado ni stock modificado
  por las simulaciones.

## 3.a · Mapa de los tres motores

| | PostgreSQL | MongoDB (TP7) | SQLite (TP8) |
|---|---|---|---|
| Rol | Fuente de verdad | Parte NoSQL (TP7) | Caché local offline |
| Datos | Pedidos reales, stock, precios, integridad relacional, ventas | Documentos de pedidos con líneas embebidas, consultas documentales | `producto_cache`, borradores, `cola_sync` |
| Manda sobre | Precios, stock, ventas | Su colección `foodstore_nosql.pedidos` | Nada del servidor: solo propone |
| Escribe en PG | Sí (único que puede) | No (colección separada) | Nunca |

**La tablet propone, el servidor dispone.** MongoDB se integra
conceptualmente (TP7: `consultas_mongodb.js` sobre
`foodstore_nosql`); el TP8 no modifica su trabajo anterior.
`SIMULADO_APROBADO` nunca crea un pedido en PostgreSQL.

## 3.b · Plan de mantenimiento (Unidad 6, agregado TP8)

1. **Respaldo y restauración.** Se respalda PostgreSQL con
   `backup_foodstore.ps1` (`pg_dump -Fc`, diario, en `backups/` con
   log en `logs/`). La restauración se prueba sobre una base
   separada (`restore_test.ps1` → `foodstore_restore_test`, nunca
   sobre `foodstore`), validando conteos e inválidos; TP8 usa
   además `foodstore_tp8_prueba` como copia de trabajo desechable.
   Si `pg_dump`/`pg_restore` falla, código ≠ 0 sin éxito falso.
2. **Tablets ante un backup viejo.** Una tablet cuya caché proviene
   de una instantánea anterior a la restauración NO debe asumirla
   vigente: antes de aceptar nuevos borradores debe obtener una
   nueva instantánea (`v_snapshot_movil` → CSV → `cargar_snapshot.sql`)
   y reevaluar sus PENDIENTE con `semaforo.sql` contra la instantánea
   nueva. Los `CONFLICTO`/`RECHAZADO` ya clasificados no se
   reevalúan automáticamente.
3. **Revisión de CONFLICTO/RECHAZADO.** Política propuesta (no una
   política oficial de la cátedra): revisión periódica (p. ej.
   semanal, junto a la revisión de mantenimiento de `SPEC_U6.md`)
   por el responsable del sistema; cada solicitud se resuelve
   registrando la decisión (nuevo borrador con precio/stock
   actualizados y UUID nuevo) y **nunca** convirtiendo un conflicto
   en venta automáticamente.

## 3.c · Code review con IA

| Hallazgo | Unidad | Archivo | Problema | Decisión | Motivo | Cómo se comprobó |
|---|---|---|---|---|---|---|
| H1. Semáforo reevaluaba todo | 8 | `movil/semaforo.sql` (borrador) | `UPDATE` sin filtro de estado habría re-clasificado solicitudes ya procesadas | CORREGIDO | Idempotencia exigida por la consigna | Lectura + ejecución: CTE filtra `estado='PENDIENTE'`; segunda corrida sin cambios (EJECUTADO) |
| H2. `INSERT ... SELECT ... ON CONFLICT` | 8 | `movil/cargar_snapshot.sql` (borrador) | SQLite 3.50.4 rechaza `ON CONFLICT` tras `SELECT` (`near "DO"`) | CORREGIDO | El script no corría | Ejecución Python: error real; reemplazado por `INSERT OR IGNORE` + `UPDATE` y re-verificado |
| H3. `UPDATE` con columnas del CTE en `SET` | 8 | `movil/semaforo.sql` (borrador) | `no such column: n_items` al ejecutar | CORREGIDO | Error de SQL real | Ejecución Python; reescrito con subconsultas escalares y re-verificado |
| H4. `VACUUM FULL` como mantenimiento | 6 | `maintenance.sql` (sugerencia evaluada) | Bloquea escritura y es destructivo para el rendimiento | DESCARTADO | `AGENTS.md` y `SPEC_U6.md` lo prohíben; se mantiene `VACUUM`/`ANALYZE` solo justificado | Lectura de `AGENTS.md`, `SPEC_U6.md` y `maintenance.sql` (ya comentado por defecto) |
| H5. Consultas MongoDB sin límite | 7 | `consultas_mongodb.js` | `find({})` sin `limit` sobre pedidos | ACEPTADO | Trabajo académico TP7 con base pequeña; no se modifica trabajo anterior sin necesidad | Lectura del archivo; sin ejecución en esta sesión (pendiente si se exige) |
| H6. `SELECT` futuro a `rol_soporte` | 5 | `sql/roles.sql` §10 | `ALTER DEFAULT PRIVILEGES ... GRANT SELECT` expone tablas futuras a soporte | ACEPTADO | Soporte necesita diagnóstico completo (ya lee `email` hoy); riesgo documentado, sin datos nuevos en TP8 | Lectura de `sql/roles.sql`, `BITACORA.md` y spec de Kiro TP5 |

Cobertura: 6 hallazgos, unidades 5, 6, 7 y 8; uno DESCARTADO (H4)
con motivo técnico y tres CORREGIDOS por ejecución real (H1–H3).
Ningún archivo de TPs anteriores fue modificado.

---

*Informe generado como Markdown listo para convertir a PDF
(máx. 6 páginas). En este entorno no hay herramienta de conversión
a PDF (sin pandoc/wkhtmltopdf/reportlab), por lo que
`docs/informe.pdf` queda PENDIENTE de conversión manual.*
