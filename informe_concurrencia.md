\# Informe de Concurrencia - TP2 FoodStore



\## 1. Objetivo



Se realizaron pruebas de concurrencia sobre la base de datos `foodstore\_tp2` utilizando dos sesiones independientes de PostgreSQL.



El objetivo fue observar el comportamiento de distintos niveles de aislamiento y mecanismos de bloqueo.



\## 2. Escenario 1 - Lectura no repetible



\### READ COMMITTED



En la Sesión 1 se inició una transacción y se consultó el stock del producto con `id = 1`.



El primer resultado fue:



```text

stock = 10

```



Mientras la transacción de la Sesión 1 permanecía abierta, en la Sesión 2 se modificó el stock:



```sql

UPDATE producto

SET stock = 20

WHERE id = 1;

```



La modificación fue confirmada con `COMMIT`.



Al repetir la misma consulta desde la Sesión 1, el resultado fue:



```text

stock = 20

```



Esto demuestra una lectura no repetible: dentro de la misma transacción se obtuvo un valor diferente al repetir la consulta porque otra transacción había confirmado una modificación.



\### REPEATABLE READ



Se repitió la prueba utilizando:



```sql

SET TRANSACTION ISOLATION LEVEL REPEATABLE READ;

```



La Sesión 1 obtuvo inicialmente:



```text

stock = 20

```



Luego la Sesión 2 modificó el stock a:



```text

stock = 30

```



y confirmó la transacción.



Al repetir la consulta desde la Sesión 1, el resultado continuó siendo:



```text

stock = 20

```



Por lo tanto, `REPEATABLE READ` mantuvo la misma visión de los datos durante la transacción y evitó la lectura no repetible.



\## 3. Escenario 2 - Lectura fantasma



Se inició una transacción con `READ COMMITTED` y se consultó la cantidad de productos activos:



```sql

SELECT COUNT(\*)

FROM producto

WHERE activo = TRUE;

```



El resultado inicial fue:



```text

1

```



Mientras la transacción permanecía abierta, la Sesión 2 insertó un nuevo producto activo llamado `Producto Phantom` y confirmó la operación.



Al repetir la misma consulta desde la Sesión 1, el resultado fue:



```text

2

```



La segunda consulta devolvió una fila adicional que no estaba presente en la primera consulta. Esto demuestra una lectura fantasma bajo `READ COMMITTED`.



El producto utilizado para la prueba fue eliminado posteriormente para restaurar los datos originales.



\## 4. Escenario 3 - Espera por bloqu

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

Se aceptaron los procedimientos de prueba y las explicaciones conceptuales utilizadas para realizar los tres escenarios seleccionados.

### Qué se modificó o descartó, y por qué

Los comandos se adaptaron durante la ejecución cuando fue necesario para trabajar con los datos reales de `foodstore_tp2`.

Durante la prueba de espera por bloqueo, una instrucción escrita accidentalmente como `UPDATE 1` produjo un error de sintaxis en la Sesión 2. La transacción quedó abortada y fue revertida mediante `ROLLBACK`. La verificación posterior confirmó que el stock permaneció en 30.

También se eliminó el registro temporal `Producto Phantom` utilizado para reproducir la lectura fantasma.

### Verificación realizada

La explicación de la IA fue contrastada mediante pruebas reales sobre PostgreSQL.

La lectura no repetible se verificó primero con `READ COMMITTED`, donde el valor del stock cambió de 10 a 20 dentro de la misma transacción. Luego se utilizó `REPEATABLE READ`, donde el valor permaneció en 20 aunque otra sesión modificó el stock a 30.

La lectura fantasma se verificó mediante un `COUNT(*)` de productos activos. El resultado pasó de 1 a 2 después de que otra sesión insertara un producto activo y confirmara la transacción.

La espera por bloqueo se verificó mediante `SELECT ... FOR UPDATE`. Una segunda sesión intentó modificar la misma fila y quedó esperando hasta que la primera sesión liberó el bloqueo mediante `COMMIT`.

### Conclusión de la DUIA

La IA permitió proponer los experimentos y explicar los fenómenos, pero los resultados considerados válidos fueron los observados directamente en el motor PostgreSQL.

Las pruebas confirmaron que `READ COMMITTED` permite observar lecturas no repetibles y lecturas fantasma, que `REPEATABLE READ` mantiene una visión estable de las filas durante la transacción y que `FOR UPDATE` puede provocar espera cuando otra transacción mantiene bloqueada la misma fila.


