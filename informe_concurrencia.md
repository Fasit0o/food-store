# Informe de Concurrencia - TP2 FoodStore

## 1. Objetivo

Se realizaron pruebas de concurrencia sobre la base de datos `foodstore_tp2` utilizando dos sesiones independientes de PostgreSQL.

El objetivo fue observar el comportamiento de distintos niveles de aislamiento y mecanismos de bloqueo, reproduciendo fenómenos de concurrencia sobre el esquema real del proyecto.

## 2. Escenario 1 - Lectura no repetible

### Cómo se reprodujo

Se utilizaron dos sesiones independientes de PostgreSQL sobre la base `foodstore_tp2`.

Primero se trabajó con el nivel de aislamiento `READ COMMITTED`.

En la Sesión 1 se inició una transacción y se consultó el stock del producto con `id = 1`:

```sql
BEGIN;

SELECT stock
FROM producto
WHERE id = 1;
```

El primer resultado fue:

```text
stock = 50
```

Mientras la transacción de la Sesión 1 permanecía abierta, en la Sesión 2 se ejecutó:

```sql
BEGIN;

UPDATE producto
SET stock = 40
WHERE id = 1;

COMMIT;
```

Luego, en la Sesión 1 se repitió la consulta:

```sql
SELECT stock
FROM producto
WHERE id = 1;
```

El resultado fue:

```text
stock = 40
```

Finalmente se realizó `ROLLBACK` en la Sesión 1.

### Qué se observó

Con `READ COMMITTED`, la primera consulta devolvió `10` y la segunda consulta, realizada dentro de la misma transacción después del `COMMIT` de la Sesión 2, devolvió `20`.

Esto demuestra una lectura no repetible: una misma consulta dentro de una transacción puede devolver valores diferentes si otra transacción confirma una modificación entre ambas lecturas.

### REPEATABLE READ

Se repitió la prueba utilizando:

```sql
BEGIN;

SET TRANSACTION ISOLATION LEVEL REPEATABLE READ;

SELECT stock
FROM producto
WHERE id = 1;
```

La Sesión 1 obtuvo inicialmente:

```text
stock = 40
```

Mientras la transacción permanecía abierta, la Sesión 2 ejecutó:

```sql
BEGIN;

UPDATE producto
SET stock = 50
WHERE id = 1;

COMMIT;
```

Luego se repitió la consulta desde la Sesión 1:

```sql
SELECT stock
FROM producto
WHERE id = 1;
```

El resultado continuó siendo:

```text
stock = 40
```

Finalmente se ejecutó:

```sql
ROLLBACK;
```

### Explicación de la IA

La lectura no repetible ocurre cuando una transacción realiza dos veces la misma consulta y obtiene resultados diferentes porque otra transacción modificó y confirmó los datos entre ambas lecturas.

En PostgreSQL, `READ COMMITTED` utiliza una instantánea para cada sentencia, por lo que una segunda consulta puede observar cambios confirmados por otras transacciones.

`REPEATABLE READ` mantiene una visión consistente de los datos durante toda la transacción, por lo que una segunda lectura de las mismas filas conserva los valores observados al inicio de la transacción.

### Verificación en el motor

La explicación fue verificada directamente en PostgreSQL.

Con `READ COMMITTED`, el stock pasó de `10` a `20` entre las dos consultas realizadas desde la misma transacción.

Con `REPEATABLE READ`, el stock permaneció en `20` aunque otra sesión modificó el valor a `30` y confirmó la transacción.

### Conclusión

El experimento confirmó que `READ COMMITTED` permite observar lecturas no repetibles, mientras que `REPEATABLE READ` mantiene una visión estable de los datos durante la transacción.

## 3. Escenario 2 - Lectura fantasma

### Cómo se reprodujo

Se inició una transacción en la Sesión 1 utilizando `READ COMMITTED`:

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

Mientras la transacción permanecía abierta, en la Sesión 2 se ejecutó:

```sql
BEGIN;

INSERT INTO producto (nombre, precio, stock, activo, categoria_id)
VALUES ('Producto Phantom', 150.00, 5, TRUE, 1);

COMMIT;
```

Luego se repitió la consulta desde la Sesión 1:

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

Finalmente se realizó:

```sql
ROLLBACK;
```

En la Sesión 2 se eliminó el registro temporal utilizado para la prueba:

```sql
BEGIN;

DELETE FROM producto
WHERE nombre = 'Producto Phantom';

COMMIT;
```

### Qué se observó

La primera consulta devolvió `1` producto activo.

Después de que la Sesión 2 insertó y confirmó `Producto Phantom`, la misma consulta realizada desde la Sesión 1 devolvió `2`.

La segunda consulta encontró una fila adicional que no estaba presente en el resultado anterior. Esto demuestra una lectura fantasma bajo `READ COMMITTED`.

El registro temporal fue eliminado posteriormente para restaurar los datos originales.

### Explicación de la IA

Una lectura fantasma ocurre cuando una transacción ejecuta dos veces una consulta que devuelve un conjunto de filas y, entre ambas consultas, otra transacción inserta o elimina filas que cumplen la condición de búsqueda.

Con `READ COMMITTED`, cada sentencia puede observar una instantánea diferente de los datos confirmados. Por eso, una segunda consulta puede encontrar nuevas filas que cumplen la condición.

### Verificación en el motor

La explicación fue verificada directamente en PostgreSQL mediante dos sesiones.

La primera consulta sobre los productos activos devolvió `1`.

La segunda sesión insertó `Producto Phantom` con `activo = TRUE` y confirmó la transacción.

Al repetir el `COUNT(*)` desde la Sesión 1, el resultado pasó a `2`.

Después de finalizar la prueba, `Producto Phantom` fue eliminado y se confirmó la eliminación.

### Conclusión

El experimento confirmó que bajo `READ COMMITTED` una segunda consulta puede observar nuevas filas confirmadas por otra transacción, produciendo una lectura fantasma.

## 4. Escenario 3 - Espera por bloqueo

### Cómo se reprodujo

Se utilizaron dos sesiones independientes de PostgreSQL sobre la base `foodstore_tp2`.

En la Sesión A se inició una transacción y se bloqueó la fila del producto con `id = 1` mediante `FOR UPDATE`:

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

La transacción de la Sesión A quedó abierta, manteniendo el bloqueo sobre esa fila.

Luego, en la Sesión B se inició otra transacción y se solicitó un bloqueo `FOR UPDATE` sobre la misma fila:

```sql
BEGIN;

SELECT id, nombre, stock
FROM producto
WHERE id = 1
FOR UPDATE;
```

La Sesión B quedó esperando y no devolvió inmediatamente el resultado, porque la fila permanecía bloqueada por la Sesión A.

Mientras la Sesión B permanecía esperando, en la Sesión A se ejecutó:

```sql
COMMIT;
```

Al liberarse el bloqueo, la Sesión B pudo continuar y obtener la fila.

### Qué se observó

La Sesión A obtuvo la fila:

```text
id | nombre          | stock
---+-----------------+------
1  | Producto Activo | 30
```

y mantuvo abierta la transacción con el bloqueo `FOR UPDATE`.

La Sesión B ejecutó el mismo tipo de bloqueo sobre la misma fila y quedó esperando.

Después de que la Sesión A ejecutó `COMMIT`, la Sesión B continuó su ejecución.

Esto demuestra que PostgreSQL hace esperar a una segunda transacción cuando intenta adquirir un bloqueo incompatible sobre una fila que permanece bloqueada por otra transacción.

### Explicación de la IA

La espera por bloqueo ocurre cuando una transacción mantiene un bloqueo sobre una fila y otra transacción intenta adquirir un bloqueo incompatible sobre esa misma fila.

En este caso, `SELECT ... FOR UPDATE` bloquea la fila seleccionada para que otra transacción no pueda adquirir simultáneamente un bloqueo de actualización sobre ella.

La segunda transacción debe esperar hasta que la primera libere el bloqueo mediante `COMMIT` o `ROLLBACK`.

Este mecanismo permite coordinar operaciones concurrentes sobre los mismos datos y evita que dos transacciones obtengan simultáneamente un bloqueo incompatible sobre la misma fila.

### Verificación en el motor

La explicación fue verificada directamente en PostgreSQL utilizando dos sesiones.

La Sesión A mantuvo abierta una transacción con `SELECT ... FOR UPDATE`.

La Sesión B intentó ejecutar `SELECT ... FOR UPDATE` sobre la misma fila y quedó esperando.

La espera finalizó cuando la Sesión A ejecutó `COMMIT`, confirmando que PostgreSQL estaba respetando el bloqueo existente.

### Conclusión

El experimento confirmó que `SELECT ... FOR UPDATE` puede provocar una espera cuando una segunda transacción intenta adquirir el mismo bloqueo sobre una fila que permanece bloqueada por otra transacción.

El bloqueo se mantiene hasta que la transacción que lo posee finaliza mediante `COMMIT` o `ROLLBACK`.

## DUIA - Declaración de Uso de IA

### Herramienta

OpenCode / modelo configurado en el entorno de trabajo.

### Spec o prompt utilizado

Se solicitó trabajar sobre la base `foodstore_tp2` y reproducir escenarios reales de concurrencia utilizando dos sesiones concurrentes de PostgreSQL. Para cada escenario se debía explicar el fenómeno observado, indicar el nivel de aislamiento o mecanismo de bloqueo relacionado y verificar la explicación mediante una nueva prueba en el motor.

### Qué generó

La IA propuso procedimientos SQL para reproducir:

* Lectura no repetible con `READ COMMITTED`.
* Lectura no repetible evitada mediante `REPEATABLE READ`.
* Lectura fantasma con `READ COMMITTED`.
* Espera por bloqueo mediante `SELECT ... FOR UPDATE`.

También propuso las consultas necesarias para verificar los resultados y limpiar los datos utilizados durante las pruebas.

### Qué se aceptó

Se aceptaron los procedimientos de prueba y las explicaciones conceptuales utilizadas para realizar los tres escenarios seleccionados, realizando las adaptaciones necesarias al esquema y a los datos reales de `foodstore_tp2`.

### Qué se modificó o descartó, y por qué

Los comandos se adaptaron durante la ejecución para trabajar con los datos reales de `foodstore_tp2`.

En la primera reproducción de la espera por bloqueo se utilizó un `UPDATE` en la Sesión B. Posteriormente se corrigió la prueba para reproducir literalmente el escenario solicitado por la consigna: ambas sesiones utilizaron `SELECT ... FOR UPDATE` sobre la misma fila.

La prueba corregida mostró que la Sesión B quedó esperando hasta que la Sesión A ejecutó `COMMIT`.

También se eliminó el registro temporal `Producto Phantom` utilizado para reproducir la lectura fantasma.

### Verificación realizada

La explicación de la IA fue contrastada mediante pruebas reales sobre PostgreSQL.

La lectura no repetible se verificó primero con `READ COMMITTED`, donde el valor del stock cambió de 10 a 20 dentro de la misma transacción. Luego se utilizó `REPEATABLE READ`, donde el valor permaneció en 20 aunque otra sesión modificó el stock a 30.

La lectura fantasma se verificó mediante un `COUNT(*)` de productos activos. El resultado pasó de 1 a 2 después de que otra sesión insertara un producto activo y confirmara la transacción.

La espera por bloqueo se verificó mediante `SELECT ... FOR UPDATE` en ambas sesiones sobre la misma fila. La Sesión B quedó esperando hasta que la Sesión A liberó el bloqueo mediante `COMMIT`.

### Conclusión de la DUIA

La IA permitió proponer los experimentos y explicar los fenómenos, pero los resultados considerados válidos fueron los observados directamente en el motor PostgreSQL.

Las pruebas confirmaron que `READ COMMITTED` permite observar lecturas no repetibles y lecturas fantasma, que `REPEATABLE READ` mantiene una visión estable de los datos durante la transacción y que `FOR UPDATE` puede provocar una espera cuando otra transacción mantiene bloqueada la misma fila.
