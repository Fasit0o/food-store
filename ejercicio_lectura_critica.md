\# Ejercicio de lectura crítica



\## Script 1



\### Script recibido



```sql

UPDATE funcion

SET activa = FALSE;

```



\### Qué filas afectaría realmente



El script modifica \*\*todas las filas de la tabla `funcion`\*\*.



Como no contiene ninguna cláusula `WHERE`, todas las funciones existentes quedarían con:



```text

activa = FALSE

```



Por lo tanto, no solamente se darían de baja las funciones correspondientes a películas retiradas de cartel, sino también todas las demás funciones, incluso aquellas que deberían continuar activas.



\### Por qué no coincide con la consigna



La consigna indica que el objetivo es dar de baja únicamente las funciones de películas retiradas de cartel.



El script no identifica cuáles funciones corresponden a películas retiradas. Al no utilizar ninguna condición, aplica el cambio indiscriminadamente sobre toda la tabla.



\### Versión corregida



La corrección debe incluir una condición que identifique únicamente las funciones asociadas a películas retiradas.



Una forma posible, suponiendo que el esquema utilice una relación entre `funcion` y `pelicula`, sería:



```sql

UPDATE funcion

SET activa = FALSE

WHERE pelicula\_id IN (

&#x20;   SELECT id

&#x20;   FROM pelicula

&#x20;   WHERE retirada = TRUE

);

```



Los nombres exactos de las columnas pueden variar según el esquema utilizado por la cátedra. Lo fundamental es que el `UPDATE` tenga un `WHERE` que limite la operación a las funciones correspondientes a películas retiradas.



\## Script 2



\### Script recibido



```sql

DELETE FROM categoria

WHERE id NOT IN (SELECT categoria\_id FROM producto);

```



\### Qué filas afectaría realmente



La intención aparente del script es eliminar las categorías que no tienen productos asociados.



El problema está en el uso de `NOT IN` cuando la subconsulta puede devolver valores `NULL`.



Por ejemplo, si la subconsulta:



```sql

SELECT categoria\_id

FROM producto;

```



devuelve algún `NULL`, la expresión:



```sql

id NOT IN (...)

```



puede producir el valor lógico `UNKNOWN` para determinadas filas.



En SQL, una condición que resulta `UNKNOWN` no satisface el `WHERE`. Por lo tanto, el `DELETE` puede dejar sin eliminar categorías que deberían considerarse sin productos asociados.



\### Por qué no coincide con la consigna



La consigna busca identificar las categorías para las cuales \*\*no existe ningún producto asociado\*\*.



El uso de `NOT IN` introduce un problema cuando la subconsulta contiene `NULL`. Para expresar directamente la ausencia de una relación, resulta más apropiado utilizar `NOT EXISTS`.



\### Versión corregida



```sql

DELETE FROM categoria c

WHERE NOT EXISTS (

&#x20;   SELECT 1

&#x20;   FROM producto p

&#x20;   WHERE p.categoria\_id = c.id

);

```



Esta versión elimina una categoría únicamente cuando no existe ningún producto cuyo `categoria\_id` coincida con el `id` de esa categoría.



Además, `NOT EXISTS` evita el problema lógico que puede producir un `NULL` dentro de la subconsulta utilizada por `NOT IN`.



\## Conclusión



Los dos ejemplos muestran por qué un script SQL debe leerse antes de ejecutarse.



En el primer caso, la ausencia de `WHERE` provoca una modificación masiva de todas las filas de la tabla.



En el segundo caso, la consulta expresa una intención aparentemente correcta, pero `NOT IN` puede tener un comportamiento problemático cuando la subconsulta contiene `NULL`.



La corrección no consiste solamente en escribir un SQL que funcione sintácticamente, sino en verificar que el efecto real del comando coincida con la intención de negocio.



\## DUIA - Declaración de Uso de IA



\### Herramienta



OpenCode / modelo configurado en el entorno de trabajo.



\### Spec o prompt utilizado



Se solicitó analizar críticamente dos scripts SQL deliberadamente peligrosos proporcionados por la consigna de la Parte 3, indicando qué filas afectarían realmente, por qué su comportamiento no coincide con la consigna y proponiendo una versión corregida.



\### Qué generó



La IA generó el análisis de ambos scripts, explicó el efecto de la ausencia de `WHERE` en el primer `UPDATE` y el problema de `NULL` asociado al uso de `NOT IN` en el segundo `DELETE`. También propuso versiones corregidas.



\### Qué se aceptó



Se aceptó el análisis conceptual de los dos scripts y la corrección del segundo mediante `NOT EXISTS`.



\### Qué se modificó o descartó, y por qué



La corrección del primer script se presentó de forma condicionada porque los nombres exactos de las columnas de las tablas `funcion` y `pelicula` del esquema genérico de la cátedra no fueron proporcionados en la consigna.



Por ese motivo, no se considera que los nombres `pelicula\_id`, `id` o `retirada` sean necesariamente los nombres reales del esquema utilizado por la cátedra.



\### Verificación realizada



Los scripts no fueron ejecutados sobre `foodstore\_tp2`, porque las tablas `funcion` y `pelicula` no forman parte del esquema del proyecto FoodStore.



La actividad solicitada en esta parte consiste en realizar una lectura crítica del SQL y corregirlo.



\### Conclusión de la DUIA



La IA fue utilizada como herramienta de generación y análisis, pero la decisión sobre el efecto real de cada sentencia se realizó mediante revisión del SQL y comparación con la consigna.





