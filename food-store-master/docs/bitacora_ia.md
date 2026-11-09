# Bitácora de IA — TP8 (Unidad 8)

Food Store · Base de Datos II. Solo se registran interacciones reales
de esta sesión de trabajo (2026-11-09) y la documentación de la
ejecución manual informada por el alumno (Entrada 6). La IA no
ejecutó PostgreSQL.

---

## Entrada 1 — Esquema SQLite de la tablet

- **Fecha:** 2026-11-09
- **Herramienta:** OpenCode (CLI, modelo Crouton Alpha)
- **Pedido realizado:** generar únicamente `movil/schema_sqlite.sql`,
  con `PRAGMA foreign_keys = ON;` inicial, 4 tablas STRICT, sin datos
  de prueba, sin tocar PostgreSQL ni otros archivos.
- **Propuesta recibida:** 4 tablas STRICT con CHECK de
  `precio_centavos >= 0`, `disponible/eliminado IN (0,1)`,
  `forma_pago` acotada, FK en `item_borrador` y `estado` acotado en
  `cola_sync`; `id_local`/`solicitud_uuid` como TEXT de 36 caracteres.
- **Qué se aceptó:** todo el esquema, tal como fue generado
  (ningún otro archivo modificado en esa etapa).
- **Qué se descartó o corrigió:** nada en esta etapa.
- **Por qué:** cumplía la consigna sin tablas ni datos extra.
- **Cómo se verificó:** lectura del archivo generado y
  `Test-Path` (existe). La validación por ejecución llegó después
  (Entrada 4).

## Entrada 2 — Esquema real de PostgreSQL sin conexión viva

- **Fecha:** 2026-11-09
- **Herramienta:** OpenCode (psql 18.6, `pg_restore`, Python 3.14)
- **Pedido realizado:** completar el TP8 inspeccionando primero el
  esquema real de `producto` antes de escribir `v_snapshot_movil`,
  sin inventar columnas y sin tocar la base original.
- **Propuesta recibida:** consultar `\d producto` / `information_schema`
  sobre `foodstore_tp8_prueba` para confirmar nombres y tipos.
- **Qué se aceptó:** la idea de verificar el esquema antes de la vista.
- **Qué se descartó o corrigió:** la conexión psql quedó esperando
  contraseña interactiva (se interrumpió por timeout), por lo que
  la propuesta de "inspeccionar en vivo" se descartó en esta sesión.
  En su lugar se extrajo el DDL real con
  `pg_restore -s -f - backups/foodstore_20261107_103401.dump`
  (lectura del archivo de respaldo, sin conectar a ninguna base):
  `producto(id bigint, nombre varchar(150), precio numeric(10,2),
  stock integer, activo boolean, categoria_id bigint)`.
- **Por qué:** el dump es la única fuente real accesible sin
  contraseña; inventar columnas habría violado la consigna. La
  ejecución en vivo de la vista queda marcada como pendiente manual.
- **Cómo se verificó:** salida de `pg_restore --list` y del DDL de
  `producto`, `pedido`, `cliente`, `forma_pago_enum` y
  `v_productos_activos` desde el dump. Decisión derivada: como
  PostgreSQL solo tiene `activo`, la vista expone
  `disponible = activo` y `eliminado = NOT activo`.

## Entrada 3 — Correcciones por ejecución real (SQLite)

- **Fecha:** 2026-11-09
- **Herramienta:** OpenCode + Python sqlite3 (SQLite 3.50.4)
- **Pedido realizado:** verificar `pruebas_sqlite.sql`, `semaforo.sql`,
  `cargar_snapshot.sql` y `casos_c2_c6.sql` ejecutándolos, sin
  declarar "funciona" por inspección visual.
- **Propuesta recibida (borradores iniciales):** (a) `UPDATE` del
  semáforo referenciando columnas del CTE en `SET`;
  (b) upsert `INSERT ... SELECT ... ON CONFLICT DO UPDATE` en la carga.
- **Qué se aceptó:** la estructura general (CTE + agregación en el
  semáforo; carga con actualización sin borrar filas).
- **Qué se descartó o corrigió:** ambas construcciones fueron
  CORREGIDAS tras la ejecución: (a) el `UPDATE` dio
  `no such column: n_items` → se reescribió con subconsultas
  escalares correlacionadas; (b) SQLite rechazó
  `INSERT ... SELECT ... ON CONFLICT` (`near "DO"`) → se reemplazó
  por `INSERT OR IGNORE` + `UPDATE` con subconsultas.
- **Por qué:** la ejecución manda sobre la inspección visual;
  conservar la propuesta habría entregado scripts rotos.
- **Cómo se verificó:** re-ejecución completa tras cada corrección:
  semáforo VERDE/AMARILLO/ROJO e idempotente, C7a (CHECK) y C7b (FK),
  C2–C6 con instantánea simulada, C6 con `UNIQUE constraint failed`.

## Entrada 4 — Alcance ejecutado vs. pendiente (PostgreSQL)

- **Fecha:** 2026-11-09
- **Herramienta:** OpenCode (psql, SQLite vía Python)
- **Pedido realizado:** TP8 completo con la regla "si no puede
  verificarse, decirlo; no inventar resultados".
- **Propuesta recibida:** generar todos los archivos y marcar
  claramente qué está ejecutado y qué queda pendiente.
- **Qué se aceptó:** separar la entrega en EJECUTADO (SQLite),
  GENERADO/REVISADO ESTÁTICAMENTE (SQL PostgreSQL) y PENDIENTE DE
  EJECUCIÓN MANUAL (vista, CSV real, casos contra
  `foodstore_tp8_prueba`, conversión a PDF).
- **Qué se descartó o corrigió:** se descartó generar un
  `servidor_snapshot.csv` con filas inventadas: el archivo quedó
  solo con encabezado y la regeneración con `\copy` quedó como
  paso manual del README. También se descartó declarar verificada
  la parte PostgreSQL sin haberla ejecutado.
- **Por qué:** sin contraseña de psql en este entorno, cualquier
  "resultado" PostgreSQL sería inventado.
- **Cómo se verificó:** SQLite EJECUTADO/VERIFICADO con Python
  (salidas reales registradas en el informe); PostgreSQL queda
  GENERADO y pendiente, con orden de ejecución manual en README.

## Entrada 5 — Revisión de UUIDs en casos C2–C6 (corrección)

- **Fecha:** 2026-11-09
- **Herramienta:** OpenCode + Python sqlite3 (SQLite 3.50.4)
- **Pedido realizado:** revisar `movil/casos_c2_c6.sql` porque los
  `solicitud_uuid` de C3/C4/C5 parecían repetirse (misma cola
  `...0000000000a1`, difiriendo solo en el primer segmento) y
  garantizar unicidad sin cambiar la lógica del semáforo,
  conservando el error esperado de C6.
- **Propuesta recibida (archivo original):** UUIDs con patrón
  común `cX000000-0000-4000-8000-0000000000a1` (C2b con `a2`).
- **Qué se aceptó:** la estructura de los casos y el esquema
  C6 = reintento del UUID de C5; no se modificó `semaforo.sql`
  ni ningún archivo de TPs anteriores.
- **Qué se descartó o corrigió:** se CORRIGIERON los 5
  `solicitud_uuid` por valores sintéticos distintos en varios
  segmentos (C2a `c2000000-1000-4200-8200-...a1`, C2b
  `c2000000-2000-4300-8300-...a2`, C3 `c3000000-3000-4400-8400-...b1`,
  C4 `c4000000-4000-4500-8500-...c1`, C5
  `c5000000-5000-4600-8600-...d1`). También se agregó al
  encabezado la nota de ejecución sin `-bail`.
- **Por qué:** aunque los valores originales eran técnicamente
  únicos, la cola común los hacía ambiguos y propensos a error
  de reuso; la unicidad debe ser evidente en la revisión.
- **Cómo se verificó:** extracción programática de los literales
  (6 inserts, 5 distintos de 36 caracteres, único duplicado =
  C5/C6) y ejecución completa del orden C2a→C6 con datos
  sintéticos: únicos errores = `UNIQUE constraint failed` de C6
  (con ROLLBACK posterior ejecutado y consulta final OK);
  estados finales CONFLICTO×1, RECHAZADO×2, SIMULADO_APROBADO×2.
  No se afirma ejecución contra PostgreSQL: sigue pendiente
  manual (psql requiere contraseña).

## Entrada 6 — Ejecución manual del alumno (cierre de la documentación)

- **Fecha:** no registrada (resultados informados por el alumno al
  cerrar la documentación; no se inventa fecha ni evidencia).
- **Herramienta:** ejecución manual del alumno (psql, SQLite,
  entorno local). La IA solo documentó los resultados informados.
- **Pedido realizado:** cerrar la documentación del TP8 incorporando
  los resultados reales de la ejecución manual, diferenciando
  SQLite simulado de PostgreSQL de prueba.
- **Propuesta recibida (de la IA):** actualizar `docs/informe.md`
  con los resultados, manteniendo la atribución de ejecución
  manual y sin declarar pruebas de PostgreSQL como ejecutadas
  por la IA.
- **Qué se aceptó:** incorporar los números informados por el
  alumno (snapshot 50.014 productos sin IDs faltantes ni
  duplicados; COMMIT/ROLLBACK; C7a CHECK y C7b FK; C2a CONFLICTO,
  C2b SIMULADO_APROBADO, C3 RECHAZADO, C4 RECHAZADO con producto
  ID 1 en caché `disponible=0`/`eliminado=1`, C5
  SIMULADO_APROBADO sin venta, C6 6 solicitudes antes/después;
  pedidos 200.006 y stock 2.475.979 antes/después en
  `foodstore_tp8_prueba`; producto ID 1 precio 851.00 y
  `activo=false`).
- **Qué se descartó o corrigió:** nada de los resultados; solo
  se corrigió el estado anterior "PG PENDIENTE" a "ejecutado
  manualmente por el alumno". No se completó `docs/DUIA.md`
  (falta el texto oficial) ni se declaró generado el PDF.
- **Por qué:** la evidencia de PostgreSQL solo puede provenir de
  la ejecución manual con contraseña interactiva.
- **Cómo se verificó:** los resultados se transcribieron tal como
  fueron informados; la IA no ejecutó PostgreSQL, no modifica
  bases y no depone sobre capturas ni salidas de consola que no
  vio. Pendiente: PDF y DUIA oficial.

## Declaración de Uso de IA de la cátedra

Ver `docs/DUIA.md` (marcador para pegar el texto oficial cuando
esté disponible; no se inventó su contenido).
