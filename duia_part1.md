# DUIA — Part 1: Reglas de negocio

## 1. Herramienta utilizada

* Herramienta: OpenCode CLI
* Modelo/proveedor: modelo utilizado por OpenCode
* Base de datos: PostgreSQL
* Base de trabajo: foodstore_tp2
* Sistema operativo: Windows
* Control de versiones: Git

## 2. Reglas de negocio seleccionadas

### Regla B

Un pedido no puede quedar registrado sin al menos un detalle asociado en `detalle_pedido`.

### Regla C

No se puede insertar un registro en `detalle_pedido` si el producto indicado por `producto_id` tiene `activo = FALSE`.

## 3. Solicitud realizada a la IA

Se solicitó a OpenCode que propusiera una implementación en PostgreSQL para hacer cumplir las reglas de negocio seleccionadas, respetando las tablas y columnas existentes del proyecto FoodStore.

La implementación debía evitar modificar innecesariamente el esquema existente y debía permitir probar las reglas sobre una copia de trabajo.

## 4. Resultado generado por la IA

Para la Regla B, OpenCode propuso una función de validación y dos constraint triggers diferidos (`DEFERRABLE INITIALLY DEFERRED`), asociados a las tablas `pedido` y `detalle_pedido`.

La validación se ejecuta al confirmar la transacción y verifica que no exista ningún pedido sin un detalle asociado.

Para la Regla C, OpenCode propuso una función de trigger que consulta el estado `activo` del producto antes de insertar o modificar un detalle de pedido.

Si el producto no está activo, la operación genera una excepción y no puede confirmarse.

## 5. Decisión y modificaciones

Se descartó una propuesta inicial de OpenCode que agregaba una tabla `pedido_confirmado`, porque esa tabla no formaba parte del modelo original de FoodStore y agregaba una estructura innecesaria para resolver la regla.

Se aceptó posteriormente la solución basada en constraint triggers diferidos para la Regla B y un trigger `BEFORE` para la Regla C.

El código generado fue revisado antes de ejecutarse.

## 6. Verificación

Primero se probó la instalación de las reglas dentro de una transacción:

```sql
BEGIN;
\i reglas_negocio.sql
ROLLBACK;
```

La instalación se ejecutó correctamente y el `ROLLBACK` permitió comprobar que la prueba no dejaba cambios permanentes.

Luego las reglas fueron instaladas sobre la copia de trabajo `foodstore_tp2`.

### Prueba de Regla C

Se intentó agregar al pedido un producto con `activo = FALSE`.

Resultado:

```text
ERROR: El producto 2 no esta activo y no puede incluirse en un pedido
```

La operación fue rechazada.

### Prueba de Regla B — pedido sin detalle

Se creó un pedido y se intentó confirmar la transacción sin agregar ningún detalle.

Resultado:

```text
ERROR: No puede confirmarse la transaccion: existe al menos un pedido sin detalle en detalle_pedido
```

La transacción no pudo confirmarse.

### Prueba de Regla B — pedido con detalle

Se creó un pedido y se agregó un detalle utilizando un producto activo.

Resultado:

```text
BEGIN
INSERT 0 1
INSERT 0 1
COMMIT
```

La transacción fue confirmada correctamente.

### Prueba de Regla B — eliminación del último detalle

Se intentó eliminar el único detalle del pedido 3.

Resultado:

```text
BEGIN
DELETE 1
ERROR: No puede confirmarse la transaccion: existe al menos un pedido sin detalle en detalle_pedido
```

El `COMMIT` fue rechazado.

Luego se verificó el contenido de `detalle_pedido` y el registro continuaba existiendo:

```text
pedido_id | producto_id | cantidad
----------+-------------+---------
3         | 1           | 2
```

Esto confirmó que la operación rechazada no quedó persistida.

## 7. Archivos involucrados

* `reglas_negocio.sql`: implementación de las reglas B y C.
* `duia_part1.md`: documentación del proceso de generación, revisión y validación.
* `protocolo_seguridad.md`: protocolo de copia, transacción, respaldo y control de versiones.

## 8. Conclusión

Las dos reglas seleccionadas fueron implementadas y verificadas sobre la base de trabajo `foodstore_tp2`.

La Regla B impide confirmar una transacción que deje un pedido sin detalles, mientras que la Regla C impide asociar productos inactivos a los detalles de un pedido.

Las pruebas incluyeron casos válidos e inválidos y permitieron comprobar el comportamiento real de PostgreSQL.
