# Food Store - TP8 (Base de Datos II, Unidad 8)

Tablet offline: SQLite con instantanea del catalogo, borradores de
pedidos y semaforo de sincronizacion simulada.

**Regla central: "La tablet propone, el servidor dispone."**

`SIMULADO_APROBADO` significa que el borrador coincide con la
instantanea del servidor. **NO es una venta real**: nunca crea
pedidos ni modifica stock ni precios en PostgreSQL.

## 1. Requisitos

- PostgreSQL 16+ (entorno: 18.6) con `psql`, `pg_dump` y `pg_restore`
- SQLite 3.37+ (STRICT): CLI `sqlite3` **o** DB Browser for SQLite
- OpenCode / Kiro (solo para desarrollo y documentacion)
- Autenticacion normal del entorno para PostgreSQL. **Sin
  contrasenas en archivos, scripts ni en esta documentacion.**
  Si `psql` pide contrasena, escribila en la consola; no la
  guardes en ningun archivo.

Todos los comandos `psql` de este README usan
`-v ON_ERROR_STOP=1`: si una sentencia falla, `psql` se detiene
con codigo distinto de cero en vez de seguir a ciegas.

## 2. Comprobar si `foodstore_tp8_prueba` ya existe

Antes de crear nada, verifica si la base de prueba ya existe.

```powershell
psql -h localhost -U postgres -d postgres -v ON_ERROR_STOP=1 -tAc "SELECT datname FROM pg_database WHERE datname = 'foodstore_tp8_prueba';"
```

- Si el comando **muestra** `foodstore_tp8_prueba`: la base ya
  existe. **DETENTE.** No la elimines, no la sobrescribas y no la
  recrees automaticamente. Consultalo con tu docente o revisalo
  manualmente: solo se puede seguir trabajando sobre ella si
  confirmas que es una copia de prueba del TP8. Si no estas
  seguro, no continues.
- Si el comando **no muestra nada** (salida vacia): la base no
  existe y podes crearla con el paso 3.

## 3. Crear la copia de prueba

La copia se construye **desde** la base original `foodstore`
(origen, solo lectura) **hacia** `foodstore_tp8_prueba` (destino
exclusivo de las pruebas del TP8). Nunca al reves.

Protecciones que no se negocian (ver `AGENTS.md`):

- Nunca modificar `foodstore` (sin UPDATE, DELETE, ALTER ni DROP).
- Nunca tocar `foodstore_tp3_prueba` (base historica de TPs
  anteriores) ni ninguna otra base historica.
- Nunca restaurar sobre `foodstore`. Unicamente
  `foodstore_tp8_prueba` (y `foodstore_restore_test` para el
  simulacro U6) son bases de prueba.
- Antes de cada comando, verifica a que base apunta.

Solo si el paso 2 confirmo que `foodstore_tp8_prueba` **no existe**:

```powershell
pg_dump -h localhost -U postgres -Fc -f backups/foodstore_tp8_origen.dump foodstore
if ($LASTEXITCODE -ne 0) { throw "pg_dump fallo con codigo $LASTEXITCODE" }

createdb -h localhost -U postgres foodstore_tp8_prueba
if ($LASTEXITCODE -ne 0) { throw "createdb fallo con codigo $LASTEXITCODE" }

pg_restore -h localhost -U postgres -d foodstore_tp8_prueba --no-owner --no-privileges backups/foodstore_tp8_origen.dump
if ($LASTEXITCODE -ne 0) { throw "pg_restore fallo con codigo $LASTEXITCODE" }
```

Verificacion (debe mostrar `foodstore_tp8_prueba`):

```powershell
psql -h localhost -U postgres -d foodstore_tp8_prueba -v ON_ERROR_STOP=1 -c "SELECT current_database();"
```

## 4-5. Vista del snapshot y exportacion del CSV

```powershell
psql -h localhost -U postgres -d foodstore_tp8_prueba -v ON_ERROR_STOP=1 -f sql/tp8_snapshot.sql
```

El script incluye una guardia: si no estas conectado a
`foodstore_tp8_prueba`, aborta con error. Lo que hace:

1. Muestra ANTES: cantidad de pedidos y suma de stock
   (anotalos para el paso 11).
2. Crea `v_snapshot_movil`: `precio` (`numeric`) convertido a
   centavos enteros, `activo` convertido a `disponible` (1/0) y
   `eliminado` (0/1), mas `fecha_copia`.
3. Exporta `movil/servidor_snapshot.csv` con `\copy ... CSV HEADER`.
4. Muestra DESPUES: debe coincidir con ANTES.

Verifica el CSV: encabezado presente, filas > 0,
`precio_centavos = precio * 100` y `fecha_copia` registrada.
**No inventes filas**: el CSV solo es valido si salio de este
`\copy` sobre tu copia de prueba.

## 6. Crear e importar la base SQLite

Orden estricto: primero crear `snapshot_servidor`, **despues**
importar el CSV (el `.import` falla si la tabla no existe).

```powershell
sqlite3 movil/foodstore_movil.db < movil/schema_sqlite.sql

sqlite3 movil/foodstore_movil.db "CREATE TABLE IF NOT EXISTS snapshot_servidor (id INTEGER PRIMARY KEY, nombre TEXT NOT NULL, precio_centavos INTEGER NOT NULL, stock_visto INTEGER NOT NULL, disponible INTEGER NOT NULL, eliminado INTEGER NOT NULL, fecha_copia TEXT NOT NULL);"

sqlite3 movil/foodstore_movil.db ".import --csv --skip 1 movil/servidor_snapshot.csv snapshot_servidor"

sqlite3 movil/foodstore_movil.db < movil/cargar_snapshot.sql
```

Con DB Browser for SQLite: abri/crea `movil/foodstore_movil.db`,
ejecuta `schema_sqlite.sql`, ejecuta el `CREATE TABLE` de arriba,
importa el CSV (CSV con primera fila = encabezado) y ejecuta
`cargar_snapshot.sql`. Lo esencial: `snapshot_servidor` contiene
las filas del CSV y `producto_cache` las mismas filas.

- `snapshot_servidor` es solo un **staging** (copia del CSV). No
  usa STRICT a proposito: sus columnas INTEGER aplican afinidad
  numerica, asi el texto del CSV se guarda como entero.
- `cargar_snapshot.sql` copia `snapshot_servidor` a
  `producto_cache` actualizando filas existentes (sin borrarlas),
  para preservar las FOREIGN KEY de los borradores.

## 7. Pruebas SQLite (datos sinteticos)

```powershell
sqlite3 movil/foodstore_movil.db < movil/pruebas_sqlite.sql
```

Sin `-bail`: los errores de C7a (`CHECK constraint failed`) y C7b
(`FOREIGN KEY constraint failed`) deben verse en pantalla y no
dejar filas nuevas. Tambien valida COMMIT (borrador guardado) y
ROLLBACK (borrador descartado) y C1 (catalogo disponible sin
conexion a PostgreSQL).

## 8-9. Borradores y semaforo

Los borradores se crean con `pruebas_sqlite.sql` (bloque 1) o con
los bloques de `casos_c2_c6.sql` (paso 10). El semaforo:

```powershell
sqlite3 movil/foodstore_movil.db < movil/semaforo.sql
```

Solo procesa solicitudes en estado `PENDIENTE`: volver a
ejecutarlo no cambia nada (idempotencia). Resultados:
`RECHAZADO` (rojo), `CONFLICTO` (amarillo), `SIMULADO_APROBADO`
(verde, sin venta real).

## 10. Casos C2-C6 (por bloques, con detenciones)

> **Advertencia:** `casos_c2_c6.sql` debe ejecutarse **por
> bloques, nunca completo de una sola vez**. El archivo esta
> pensado para ejecutarse bloque por bloque en orden (en DB
> Browser: selecciona y ejecuta cada bloque; en `sqlite3` CLI:
> pega cada bloque en la consola interactiva). Si ejecutas el
> archivo entero de una vez, los bloques C2b/C4b/C5/C6 corren
> antes de los cambios de PostgreSQL y los resultados quedan
> invalidados.

Re-importar la instantanea (pasos necesarios en C2 y C4):

```powershell
sqlite3 movil/foodstore_movil.db "DELETE FROM snapshot_servidor;"
sqlite3 movil/foodstore_movil.db ".import --csv --skip 1 movil/servidor_snapshot.csv snapshot_servidor"
sqlite3 movil/foodstore_movil.db < movil/cargar_snapshot.sql
```

`DELETE FROM snapshot_servidor` vacia **solamente** el staging.
No toca `producto_cache`, `pedido_borrador`, `item_borrador` ni
`cola_sync`: ninguna tabla tiene FOREIGN KEY hacia
`snapshot_servidor`, y los borradores se conservan. Luego
`cargar_snapshot.sql` actualiza `producto_cache` sin borrar filas.

### C2a - Cambio de precio, parte 1 (solo SQLite)

1. Ejecuta el bloque C2a de `casos_c2_c6.sql` (borrador con el
   precio actual de `producto_cache`).
2. **DETENTE.** No ejecutes C2b todavia.

### C2a (continuacion) - Volver a PostgreSQL y generar nuevo CSV

3. En PostgreSQL de prueba, ejecuta el archivo **exclusivo del
   caso C2** (no hay que editar ningun script):

```powershell
psql -h localhost -U postgres -d foodstore_tp8_prueba -v ON_ERROR_STOP=1 -f sql/tp8_caso_c2_postgresql.sql
```

Este archivo sube 1.00 al primer producto activo y luego
muestra su fila para verificar el cambio.
4. Vuelve a ejecutar el paso 4-5 (`tp8_snapshot.sql`) para
   generar un **nuevo** `servidor_snapshot.csv`.
5. **Regresa a SQLite** y ejecuta, en este orden:

```powershell
sqlite3 movil/foodstore_movil.db "DELETE FROM snapshot_servidor;"
sqlite3 movil/foodstore_movil.db ".import --csv --skip 1 movil/servidor_snapshot.csv snapshot_servidor"
sqlite3 movil/foodstore_movil.db < movil/cargar_snapshot.sql
sqlite3 movil/foodstore_movil.db < movil/semaforo.sql
```

   Esperado: la solicitud de C2a queda `CONFLICTO`.

### C2b - Cambio de precio, parte 2 (solo SQLite)

6. Ejecuta el bloque C2b (actualiza el precio visto y crea una
   solicitud nueva con UUID nuevo) y luego `semaforo.sql`.
   Esperado: la solicitud nueva queda `SIMULADO_APROBADO`
   (no es venta); la de C2a sigue `CONFLICTO`.

### C3 - Stock insuficiente (solo SQLite)

7. Ejecuta el bloque C3 (`cantidad = stock + 1`) y `semaforo.sql`.
   Esperado: `RECHAZADO` por stock insuficiente. No toca
   PostgreSQL.

### C4a - Baja logica, parte 1 (solo SQLite)

8. Ejecuta el bloque C4a (borrador con el primer producto
   disponible actual).
9. **DETENTE.** No ejecutes C4b todavia.

### C4a (continuacion) - Volver a PostgreSQL y generar nuevo CSV

10. En PostgreSQL de prueba, ejecuta el archivo **exclusivo del
    caso C4** (no hay que editar ningun script):

```powershell
psql -h localhost -U postgres -d foodstore_tp8_prueba -v ON_ERROR_STOP=1 -f sql/tp8_caso_c4_postgresql.sql
```

Este archivo pone `activo = false` en el primer producto
activo, muestra su fila y termina con la verificacion final
(pedidos y stock, paso 11).
11. Vuelve a ejecutar el paso 4-5 para generar un **nuevo** CSV.
12. **Regresa a SQLite** y ejecuta, en este orden:

```powershell
sqlite3 movil/foodstore_movil.db "DELETE FROM snapshot_servidor;"
sqlite3 movil/foodstore_movil.db ".import --csv --skip 1 movil/servidor_snapshot.csv snapshot_servidor"
sqlite3 movil/foodstore_movil.db < movil/cargar_snapshot.sql
sqlite3 movil/foodstore_movil.db < movil/semaforo.sql
```

    Esperado: la solicitud de C4a queda `RECHAZADO`
    (producto dado de baja en la instantanea).

### C4b - Baja logica, parte 2: recargar catalogo (solo SQLite)

13. Verifica con las consultas del bloque C4b que la fila del
    producto **sigue existiendo** en `producto_cache` con
    `disponible=0` y `eliminado=1` (la recarga de la cache ya se
    ejecuto en el paso 12, no hace falta repetirla), y que el
    catalogo disponible (C1) ya no lo muestra.

### C5 - Sin cambios (solo SQLite)

14. Ejecuta el bloque C5 y `semaforo.sql`.
    Esperado: `SIMULADO_APROBADO` (coincide con la instantanea;
    no es venta real).

### C6 - Idempotencia / UUID repetido (solo SQLite)

15. Ejecuta el bloque C6: reintenta el `solicitud_uuid` de C5.
    Debe verse `UNIQUE constraint failed` (error esperado) y el
    `ROLLBACK` posterior debe ejecutarse. Vuelve a ejecutar
    `semaforo.sql`: los conteos por estado no cambian.

## 11. Verificar que PostgreSQL no cambio

Compara el bloque DESPUES de `sql/tp8_snapshot.sql` (y la consulta
final de `sql/tp8_caso_c4_postgresql.sql`) con el ANTES del paso 4:
`cantidad_pedidos` y `stock_total` deben coincidir. La simulacion
de la tablet no crea pedidos ni toca stock en PostgreSQL.

## 12. Que representa SIMULADO_APROBADO

Solo que el borrador coincide con la instantanea del servidor y
pasaria la validacion simulada. La venta real la confirma el
servidor por otro canal; la tablet offline nunca vende.

## Pruebas: que se ejecuto y que falta

- **SQLite con snapshot simulado: EJECUTADO en esta sesion**
  (Python sqlite3, SQLite 3.50.4, datos sinteticos): schema
  (4 tablas STRICT), `pruebas_sqlite.sql` (COMMIT/ROLLBACK, C1,
  C7a/C7b), `semaforo.sql` (verde/amarillo/rojo, idempotente) y
  la logica C2-C6 con una instantanea simulada. Esto **no** es
  una prueba contra PostgreSQL.
- **PostgreSQL real: EJECUTADO manualmente por el alumno** sobre
  `foodstore_tp8_prueba` (pasos 2-5 y 10): vista, CSV real y casos
  C2-C6 (pedidos 200.006 y stock 2.475.979 antes/despues,
  producto ID 1 precio 851.00 y `activo=false`). La IA no ejecuto
  PostgreSQL; documenta los resultados informados (ver
  `docs/informe.md` y `docs/bitacora_ia.md`).
- Tambien pendiente: convertir `docs/informe.md` a
  `docs/informe.pdf` y pegar la DUIA oficial en `docs/DUIA.md`.

## Estructura TP8

```
movil/schema_sqlite.sql        movil/pruebas_sqlite.sql
movil/semaforo.sql             movil/cargar_snapshot.sql
movil/casos_c2_c6.sql          movil/servidor_snapshot.csv
movil/foodstore_movil.db
sql/tp8_snapshot.sql           sql/tp8_caso_c2_postgresql.sql
sql/tp8_caso_c4_postgresql.sql sql/tp8_casos_c2_c6_postgresql.sql (obsoleto, no ejecutar)
docs/informe.md                docs/kiro/{requirements,design,tasks}.md
docs/bitacora_ia.md            docs/DUIA.md
```
