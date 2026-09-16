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



