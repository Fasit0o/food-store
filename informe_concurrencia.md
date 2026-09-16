# Informe de Concurrencia - TP2 FoodStore

## 1. Objetivo

Se realizaron pruebas de concurrencia sobre la base de datos `foodstore_tp2` utilizando dos sesiones independientes de PostgreSQL.

El objetivo fue observar el comportamiento de distintos niveles de aislamiento y mecanismos de bloqueo, reproduciendo fenÃ³menos de concurrencia sobre el esquema real del proyecto.

## 2. Escenario 1 - Lectura no repetible

### CÃ³mo se reprodujo

Se utilizaron dos sesiones independientes de PostgreSQL sobre la base `foodstore_tp2`.

Primero se trabajÃ³ con el nivel de aislamiento `READ COMMITTED`.

En la SesiÃ³n 1 se iniciÃ³ una transacciÃ³n y se consultÃ³ el stock del producto con `id = 1`:

```sql
BEGIN;

SELECT stock
FROM producto
WHERE id = 1;
```

El primer resultado fue:

```text
stock = 10
```

Mientras la transacciÃ³n de la SesiÃ³n 1 permanecÃ­a abierta, en la SesiÃ³n 2 se ejecutÃ³:

```sql
BEGIN;

UPDATE producto
SET stock = 20
WHERE id = 1;

COMMIT;
```

Luego, en la SesiÃ³n 1 se repitiÃ³ la consulta:

```sql
SELECT stock
FROM producto
WHERE id = 1;
```

El resultado fue:

```text
stock = 20
```

Finalmente se realizÃ³ `ROLLBACK` en la SesiÃ³n 1.

### QuÃ© se observÃ³

Con `READ COMMITTED`, la primera consulta devolviÃ³ `10` y la segunda consulta, realizada dentro de la misma transacciÃ³n despuÃ©s del `COMMIT` de la SesiÃ³n 2, devolviÃ³ `20`.

Esto demuestra una lectura no repetible: una misma consulta dentro de una transacciÃ³n puede devolver valores diferentes si otra transacciÃ³n confirma una modificaciÃ³n entre ambas lecturas.

### REPEATABLE READ

Se repitiÃ³ la prueba utilizando:

```sql
BEGIN;

SET TRANSACTION ISOLATION LEVEL REPEATABLE READ;

SELECT stock
FROM producto
WHERE id = 1;
```

La SesiÃ³n 1 obtuvo inicialmente:

```text
stock = 20
```

Mientras la transacciÃ³n permanecÃ­a abierta, la SesiÃ³n 2 ejecutÃ³:

```sql
BEGIN;

UPDATE producto
SET stock = 30
WHERE id = 1;

COMMIT;
```

Luego se repitiÃ³ la consulta desde la SesiÃ³n 1:

```sql
SELECT stock
FROM producto
WHERE id = 1;
```

El resultado continuÃ³ siendo:

```text
stock = 20
```

Finalmente se ejecutÃ³:

```sql
ROLLBACK;
```

### ExplicaciÃ³n de la IA

La lectura no repetible ocurre cuando una transacciÃ³n realiza dos veces la misma consulta y obtiene resultados diferentes porque otra transacciÃ³n modificÃ³ y confirmÃ³ los datos entre ambas lecturas.

En PostgreSQL, `READ COMMITTED` utiliza una instantÃ¡nea para cada sentencia, por lo que una segunda consulta puede observar cambios confirmados por otras transacciones.

`REPEATABLE READ` mantiene una visiÃ³n consistente de los datos durante toda la transacciÃ³n, por lo que una segunda lectura de las mismas filas conserva los valores observados al inicio de la transacciÃ³n.

### VerificaciÃ³n en el motor

La explicaciÃ³n fue verificada directamente en PostgreSQL.

Con `READ COMMITTED`, el stock pasÃ³ de `10` a `20` entre las dos consultas realizadas desde la misma transacciÃ³n.

Con `REPEATABLE READ`, el stock permaneciÃ³ en `20` aunque otra sesiÃ³n modificÃ³ el valor a `30` y confirmÃ³ la transacciÃ³n.

### ConclusiÃ³n

El experimento confirmÃ³ que `READ COMMITTED` permite observar lecturas no repetibles, mientras que `REPEATABLE READ` mantiene una visiÃ³n estable de los datos durante la transacciÃ³n.

## 3. Escenario 2 - Lectura fantasma

### CÃ³mo se reprodujo

Se iniciÃ³ una transacciÃ³n en la SesiÃ³n 1 utilizando `READ COMMITTED`:

```sql
BEGIN;

SET TRANSACTION ISOLATION LEVEL READ COMMITTED;

SELECT COUNT(*)
FROM producto
WHERE activo = TRUE;
```

El resultado inicial fue:

```text
count
-----
1
```

Mientras la transacciÃ³n permanecÃ­a abierta, en la SesiÃ³n 2 se ejecutÃ³:

```sql
BEGIN;

INSERT INTO producto (nombre, precio, stock, activo, categoria_id)
VALUES ('Producto Phantom', 150.00, 5, TRUE, 1);

COMMIT;
```

Luego se repitiÃ³ la consulta desde la SesiÃ³n 1:

```sql
SELECT COUNT(*)
FROM producto
WHERE activo = TRUE;
```

El resultado fue:

```text
count
-----
2
```

Finalmente se realizÃ³:

```sql
ROLLBACK;
```

En la SesiÃ³n 2 se eliminÃ³ el registro temporal utilizado para la prueba:

```sql
BEGIN;

DELETE FROM producto
WHERE nombre = 'Producto Phantom';

COMMIT;
```

### QuÃ© se observÃ³

La primera consulta devolviÃ³ `1` producto activo.

DespuÃ©s de que la SesiÃ³n 2 insertÃ³ y confirmÃ³ `Producto Phantom`, la misma consulta realizada desde la SesiÃ³n 1 devolviÃ³ `2`.

La segunda consulta encontrÃ³ una fila adicional que no estaba presente en el resultado anterior. Esto demuestra una lectura fantasma bajo `READ COMMITTED`.

El registro temporal fue eliminado posteriormente para restaurar los datos originales.

### ExplicaciÃ³n de la IA

Una lectura fantasma ocurre cuando una transacciÃ³n ejecuta dos veces una consulta que devuelve un conjunto de filas y, entre ambas consultas, otra transacciÃ³n inserta o elimina filas que cumplen la condiciÃ³n de bÃºsqueda.

Con `READ COMMITTED`, cada sentencia puede observar una instantÃ¡nea diferente de los datos confirmados. Por eso, una segunda consulta puede encontrar nuevas filas que cumplen la condiciÃ³n.

### VerificaciÃ³n en el motor

La explicaciÃ³n fue verificada directamente en PostgreSQL mediante dos sesiones.

La primera consulta sobre los productos activos devolviÃ³ `1`.

La segunda sesiÃ³n insertÃ³ `Producto Phantom` con `activo = TRUE` y confirmÃ³ la transacciÃ³n.

Al repetir el `COUNT(*)` desde la SesiÃ³n 1, el resultado pasÃ³ a `2`.

DespuÃ©s de finalizar la prueba, `Producto Phantom` fue eliminado y se confirmÃ³ la eliminaciÃ³n.

### ConclusiÃ³n

El experimento confirmÃ³ que bajo `READ COMMITTED` una segunda consulta puede observar nuevas filas confirmadas por otra transacciÃ³n, produciendo una lectura fantasma.

## 4. Escenario 3 - Espera por bloqueo

### CÃ³mo se reprodujo

Se utilizaron dos sesiones independientes de PostgreSQL sobre la base `foodstore_tp2`.

En la SesiÃ³n A se iniciÃ³ una transacciÃ³n y se bloqueÃ³ la fila del producto con `id = 1` mediante `FOR UPDATE`:

```sql
BEGIN;

SELECT id, nombre, stock
FROM producto
WHERE id = 1
FOR UPDATE;
```

El resultado observado fue:

```text
 id |     nombre      | stock
----+-----------------+-------
  1 | Producto Activo |    30
```

La transacciÃ³n de la SesiÃ³n A quedÃ³ abierta, manteniendo el bloqueo sobre esa fila.

Luego, en la SesiÃ³n B se iniciÃ³ otra transacciÃ³n y se solicitÃ³ un bloqueo `FOR UPDATE` sobre la misma fila:

```sql
BEGIN;

SELECT id, nombre, stock
FROM producto
WHERE id = 1
FOR UPDATE;
```

La SesiÃ³n B quedÃ³ esperando y no devolviÃ³ inmediatamente el resultado, porque la fila permanecÃ­a bloqueada por la SesiÃ³n A.

Mientras la SesiÃ³n B permanecÃ­a esperando, en la SesiÃ³n A se ejecutÃ³:

```sql
COMMIT;
```

Al liberarse el bloqueo, la SesiÃ³n B pudo continuar y obtener la fila.

### QuÃ© se observÃ³

La SesiÃ³n A obtuvo la fila:

```text
id | nombre          | stock
---+-----------------+------
1  | Producto Activo | 30
```

y mantuvo abierta la transacciÃ³n con el bloqueo `FOR UPDATE`.

La SesiÃ³n B ejecutÃ³ el mismo tipo de bloqueo sobre la misma fila y quedÃ³ esperando.

DespuÃ©s de que la SesiÃ³n A ejecutÃ³ `COMMIT`, la SesiÃ³n B continuÃ³ su ejecuciÃ³n.

Esto demuestra que PostgreSQL hace esperar a una segunda transacciÃ³n cuando intenta adquirir un bloqueo incompatible sobre una fila que permanece bloqueada por otra transacciÃ³n.

### ExplicaciÃ³n de la IA

La espera por bloqueo ocurre cuando una transacciÃ³n mantiene un bloqueo sobre una fila y otra transacciÃ³n intenta adquirir un bloqueo incompatible sobre esa misma fila.

En este caso, `SELECT ... FOR UPDATE` bloquea la fila seleccionada para que otra transacciÃ³n no pueda adquirir simultÃ¡neamente un bloqueo de actualizaciÃ³n sobre ella.

La segunda transacciÃ³n debe esperar hasta que la primera libere el bloqueo mediante `COMMIT` o `ROLLBACK`.

Este mecanismo permite coordinar operaciones concurrentes sobre los mismos datos y evita que dos transacciones obtengan simultÃ¡neamente un bloqueo incompatible sobre la misma fila.

### VerificaciÃ³n en el motor

La explicaciÃ³n fue verificada directamente en PostgreSQL utilizando dos sesiones.

La SesiÃ³n A mantuvo abierta una transacciÃ³n con `SELECT ... FOR UPDATE`.

La SesiÃ³n B intentÃ³ ejecutar `SELECT ... FOR UPDATE` sobre la misma fila y quedÃ³ esperando.

La espera finalizÃ³ cuando la SesiÃ³n A ejecutÃ³ `COMMIT`, confirmando que PostgreSQL estaba respetando el bloqueo existente.

### ConclusiÃ³n

El experimento confirmÃ³ que `SELECT ... FOR UPDATE` puede provocar una espera cuando una segunda transacciÃ³n intenta adquirir el mismo bloqueo sobre una fila que permanece bloqueada por otra transacciÃ³n.

El bloqueo se mantiene hasta que la transacciÃ³n que lo posee finaliza mediante `COMMIT` o `ROLLBACK`.

## DUIA - DeclaraciÃ³n de Uso de IA

### Herramienta

OpenCode / modelo configurado en el entorno de trabajo.

### Spec o prompt utilizado

Se solicitÃ³ trabajar sobre la base `foodstore_tp2` y reproducir escenarios reales de concurrencia utilizando dos sesiones concurrentes de PostgreSQL. Para cada escenario se debÃ­a explicar el fenÃ³meno observado, indicar el nivel de aislamiento o mecanismo de bloqueo relacionado y verificar la explicaciÃ³n mediante una nueva prueba en el motor.

### QuÃ© generÃ³

La IA propuso procedimientos SQL para reproducir:

* Lectura no repetible con `READ COMMITTED`.
* Lectura no repetible evitada mediante `REPEATABLE READ`.
* Lectura fantasma con `READ COMMITTED`.
* Espera por bloqueo mediante `SELECT ... FOR UPDATE`.

TambiÃ©n propuso las consultas necesarias para verificar los resultados y limpiar los datos utilizados durante las pruebas.

### QuÃ© se aceptÃ³

Se aceptaron los procedimientos de prueba y las explicaciones conceptuales utilizadas para realizar los tres escenarios seleccionados, realizando las adaptaciones necesarias al esquema y a los datos reales de `foodstore_tp2`.

### QuÃ© se modificÃ³ o descartÃ³, y por quÃ©

Los comandos se adaptaron durante la ejecuciÃ³n para trabajar con los datos reales de `foodstore_tp2`.

En la primera reproducciÃ³n de la espera por bloqueo se utilizÃ³ un `UPDATE` en la SesiÃ³n B. Posteriormente se corrigiÃ³ la prueba para reproducir literalmente el escenario solicitado por la consigna: ambas sesiones utilizaron `SELECT ... FOR UPDATE` sobre la misma fila.

La prueba corregida mostrÃ³ que la SesiÃ³n B quedÃ³ esperando hasta que la SesiÃ³n A ejecutÃ³ `COMMIT`.

TambiÃ©n se eliminÃ³ el registro temporal `Producto Phantom` utilizado para reproducir la lectura fantasma.

### VerificaciÃ³n realizada

La explicaciÃ³n de la IA fue contrastada mediante pruebas reales sobre PostgreSQL.

La lectura no repetible se verificÃ³ primero con `READ COMMITTED`, donde el valor del stock cambiÃ³ de 10 a 20 dentro de la misma transacciÃ³n. Luego se utilizÃ³ `REPEATABLE READ`, donde el valor permaneciÃ³ en 20 aunque otra sesiÃ³n modificÃ³ el stock a 30.

La lectura fantasma se verificÃ³ mediante un `COUNT(*)` de productos activos. El resultado pasÃ³ de 1 a 2 despuÃ©s de que otra sesiÃ³n insertara un producto activo y confirmara la transacciÃ³n.

La espera por bloqueo se verificÃ³ mediante `SELECT ... FOR UPDATE` en ambas sesiones sobre la misma fila. La SesiÃ³n B quedÃ³ esperando hasta que la SesiÃ³n A liberÃ³ el bloqueo mediante `COMMIT`.

### ConclusiÃ³n de la DUIA

La IA permitiÃ³ proponer los experimentos y explicar los fenÃ³menos, pero los resultados considerados vÃ¡lidos fueron los observados directamente en el motor PostgreSQL.

Las pruebas confirmaron que `READ COMMITTED` permite observar lecturas no repetibles y lecturas fantasma, que `REPEATABLE READ` mantiene una visiÃ³n estable de los datos durante la transacciÃ³n y que `FOR UPDATE` puede provocar una espera cuando otra transacciÃ³n mantiene bloqueada la misma fila.

