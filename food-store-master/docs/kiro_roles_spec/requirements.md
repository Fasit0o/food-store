# Requirements — Parte A: Roles y Permisos
## TP5 · Base de Datos II · Food Store

---

> **Estado de esta especificación:** documento de entrada preparado
> para ser utilizado en Kiro. No se afirma que Kiro la haya generado
> ni que haya sido ejecutada en Kiro; ninguna ejecución de Kiro se
> documenta como evidencia en este archivo. La implementación es
> `sql/roles.sql`, **ejecutada sin `ERROR`** con `psql -U postgres -d foodstore_tp3_prueba -f .\sql\roles.sql` (**A**).
> Clasificación de evidencia en todo el documento:
> **A** = verificado por comandos ejecutados realmente en esta conversación
> (ejecución sin `ERROR`, `\du`, membresías, `role_table_grants`, `column_privileges`, `pg_default_acl`);
> **B** = deducido de `sql/roles.sql` y archivos del proyecto;
> **C** = decisión/adaptación de la consigna a Food Store.
> La versión `18.6` es **B** (declarada en `roles.sql`); no se ejecutó
> `SELECT version()` en esta conversación (**pendiente**).
> Ver §2.3 y §6.

## 1. Objetivo

Diseñar e implementar un esquema de roles y permisos en PostgreSQL (versión declarada `18.6` en **`B`**: cabecera de `sql/roles.sql`; **pendiente** `SELECT version()` en **A**) para la base de datos de Food Store que aplique el principio de mínimo privilegio. Cada rol recibe exactamente los permisos que necesita y ninguno más. El entregable ejecutable es `sql/roles.sql` con `CREATE ROLE` (condicional), `GRANT`, `REVOKE` y `ALTER DEFAULT PRIVILEGES`, **ejecutado sin `ERROR`** con `psql -U postgres -d foodstore_tp3_prueba -f .\sql\roles.sql` (**A**). Respecto de `CREATE ROLE`: deducido de **`B`** (bloque `DO` en `sql/roles.sql` §2), los siete roles se tratan como preexistentes según contexto operativo previo; **A** solo prueba existencia posterior a la ejecución (ver §6, no preexistencia). En **`B`**, §2 crea cada rol **solo si no existe** en `pg_roles`, sin contraseñas y sin alterar los existentes, para no provocar `duplicate_object` ni sobrescribir credenciales/atributos vigentes. La forma canónica de creación en base nueva/vacía se documenta en §3.3 y en `design.md` §1.2.

## 2. Alcance

### 2.1 Objetos del esquema existente (**B**: lectura de archivos del proyecto)

| Tipo | Nombre | Descripción resumida (**B**) |
|---|---|---|
| Tabla | `cliente` | Compradores; contiene `email` sensible |
| Tabla | `categoria` | Agrupaciones de productos |
| Tabla | `producto` | Catálogo con precio, stock y categoría |
| Tabla | `pedido` | Compras realizadas por clientes |
| Tabla | `detalle_pedido` | Líneas de detalle (PK compuesta, sin secuencia) |
| Vista | `v_productos_activos` | Catálogo activo con nombre de categoría |
| Vista | `v_pedidos_cliente` | Pedidos con nombre y **email** del cliente |
| Vista | `v_detalle_pedido_producto` | Líneas de detalle con nombre del producto |
| Vista materializada | `mv_ventas_mensuales_forma_pago` | Resumen mensual por forma de pago |
| Procedimiento | `sp_desactivar_producto(bigint)` | Definido en `foodstore.session.sql:102-120` (**B**); **C**: no se crea ni se le otorga permiso activo (ver §2.2) |
| Funciones | `fn_verificar_pedido_sin_detalle()`, `trg_fn_validar_producto_activo()` | Definidas en `reglas_negocio.sql` (**B**); **C**: sin permiso activo (ver §2.2) |
| Tabla de la consigna | `usuario` | **C**: sin equivalente en Food Store; el equivalente real es `cliente` (ver §5) |
| Funciones de la consigna | `fn_autenticar`, `fn_resetear_password` | **C**: sin equivalente en la base real; **B**: sin `GRANT`/`REVOKE` activo sobre ellas en `roles.sql` |
| Tipo enum | `forma_pago_enum` | EFECTIVO, TARJETA, TRANSFERENCIA |
| Secuencias | `cliente_id_seq`, `categoria_id_seq`, `producto_id_seq`, `pedido_id_seq` | Implícitas por `GENERATED ALWAYS AS IDENTITY` (**B**) |

### 2.2 Objetos fuera del alcance

- Gestión de superusuarios de instancia y RLS/auditoría (Partes siguientes del TP).
- `REFRESH MATERIALIZED VIEW` (requiere ser dueño; queda en manos de `postgres`).
- Objetos de otras bases o esquemas distintos de `public`.
- **Tabla `usuario`, funciones `fn_autenticar` y `fn_resetear_password`, procedimiento `sp_desactivar_producto` y funciones `fn_verificar_pedido_sin_detalle` / `trg_fn_validar_producto_activo`:** **C** (adaptación: la base real de Food Store no los contiene; no hay consulta de catálogo en **A** que lo acredite — **pendiente** si se requiere prueba PostgreSQL). **B**: en `sql/roles.sql` §9 no hay `GRANT`/`REVOKE` activo sobre ellos (sentencias comentadas); ejecutarlas habría dado `ERROR`. No se inventan esos objetos (ver `design.md` §§7 y 11).

### 2.3 Nombre de la base de datos

La base de trabajo es `foodstore_tp3_prueba` (**A** por comando `psql ... -d foodstore_tp3_prueba`; versión `18.6` **B** de cabecera de `roles.sql`, **pendiente** `SELECT version()` en **A**). Archivos de TPs anteriores mencionan además `foodstore` (`.vscode/settings.json`) y `foodstore_tp2` (`protocolo_seguridad.md`): son nombres de instancias de trabajo de etapas anteriores, no la base actual del TP5 (**B**). `sql/roles.sql` usa `current_database()` mediante bloques `DO ... format(...)` en §4 (**B**); §1 recomienda `\l` antes de ejecutar (**pendiente** en **A**, no ejecutado en esta conversación). Que `current_database()` devuelva esa base es **B** (lectura del script + comando), no **A** (no hay `SELECT current_database()` en la evidencia).

## 3. Roles requeridos

### 3.1 Roles de grupo (`NOLOGIN`)

| Rol | Justificación | Necesita | No necesita |
|---|---|---|---|
| `rol_app_lectura` | Lecturas de catálogo/pedidos para la web | `SELECT` catálogo/pedidos; `cliente` solo `id,nombre,apellido` a nivel de columna | Escritura; `cliente.email`; `v_pedidos_cliente` (expone el email) |
| `rol_app_escritura` | Escrituras de la web | `INSERT,UPDATE` cliente (**sin `SELECT` general sobre `cliente`**: el `email` solo aparece como valor de alta/modificación, no como lectura masiva); `SELECT,INSERT` pedido; `SELECT,INSERT,DELETE` detalle | `SELECT` general sobre `cliente`; `UPDATE/DELETE` pedido y producto/categoria; DDL; reportes |
| `rol_soporte` | Diagnóstico con lectura completa | `SELECT` todas las tablas, vistas y MV, incluido `cliente.email` (justificado por soporte/incidencias) | Escritura; `EXECUTE` |
| `rol_reportes` | Reportes solo sobre vistas/MV | `SELECT` sobre `v_productos_activos`, `v_detalle_pedido_producto` y `mv_ventas_mensuales_forma_pago` | Acceso a tablas base; `v_pedidos_cliente` (expone `email`); escritura |

### 3.2 Roles LOGIN (`LOGIN`)

| Rol | Hereda | Privilegios directos |
|---|---|---|
| `app_web` | `rol_app_lectura`, `rol_app_escritura` | Solo `CONNECT/USAGE` de base/esquema/tipo |
| `admin_datos` | `rol_soporte` | `UPDATE producto`; `INSERT,UPDATE categoria`; `USAGE,SELECT categoria_id_seq` |
| `usuario_reportes` | `rol_reportes` (único) | Solo `CONNECT/USAGE` de base/esquema/tipo |

**B**: el script no otorga `SUPERUSER`, `CREATEROLE`, `CREATEDB`, `BYPASSRLS` ni permisos DDL; que esa ausencia se viera en `\du` es **pendiente** en **A** (la evidencia **A** de `\du` en esta conversación solo confirma `Cannot login` de los grupos). Las contraseñas reales quedan fuera del repositorio y **no se incluye ningún marcador que pueda usarse accidentalmente como contraseña definitiva**: **B**: `sql/roles.sql` no contiene `PASSWORD` (su `CREATE ROLE` condicional crea sin contraseña, §3.3). La configuración/verificación de contraseñas (existencia, cifrado SCRAM, `pg_hba.conf`) es **pendiente** y externa al repositorio (no se ejecutó en esta conversación).

**Permisos efectivos por herencia** (unión de grupo heredado + directos; ver matriz completa en `design.md` §2.1): `app_web` = lectura+escritura (incluye `INSERT,UPDATE` en `cliente` y `SELECT` solo de `id,nombre,apellido`, sin `email`); `admin_datos` = soporte (lectura completa con `email`) + `UPDATE producto`/`INSERT,UPDATE categoria`; `usuario_reportes` = solo reportes (vistas/MV sin `v_pedidos_cliente`, sin tablas base).

**`EXECUTE` condicionado (**C**+**B**):** `sp_desactivar_producto(bigint)` está definido en `foodstore.session.sql` (**B**); **C**: no se le otorga permiso activo. Por eso el `REVOKE EXECUTE ... FROM PUBLIC` y el `GRANT EXECUTE ... TO admin_datos` quedan comentados en `sql/roles.sql` §9 (**B**) y solo se aplicarían el día en que el objeto se cree realmente en la base. Afirmar un `GRANT EXECUTE` activo sería inventar un objeto/permisio existente. Prueba PostgreSQL de inexistencia: **pendiente** (no hay `\df`/consulta en **A**).

### 3.3 Reconstrucción de roles (`CREATE ROLE`) sin romper el estado actual

La consigna menciona `CREATE ROLE`. **B**: deducido del bloque `DO` de `sql/roles.sql` §2, si los roles ya existían, un `CREATE ROLE` directo produciría `duplicate_object` y, si incluyera `PASSWORD`, sobrescribiría credenciales vigentes. **A** solo acredita que tras la ejecución los 7 roles existen (ver §6); la preexistencia y los atributos `INHERIT`/ausencia de `SUPERUSER` etc. son **B** (no hay captura de `\du` completo ni log de `NOTICE` en **A**).

1. Sobre `foodstore_tp3_prueba` el `CREATE ROLE` de `sql/roles.sql` §2 es un bloque `DO` condicional (**B**): crea cada rol **solo si no existe** en `pg_roles` y, si ya existe, no hace nada (sin `PASSWORD`, sin `ALTER ROLE`, sin cambio de atributos). Así se cumple el requisito de `CREATE ROLE` sin `duplicate_object` y sin sobrescribir credenciales (**B**). Si un rol existente tuviera atributos divergentes, el bloque no los corrige (**B**); detectarlo exigiría consulta de atributos, **pendiente** en **A**. **A**: el bloque corrió sin `ERROR` como parte de la ejecución completa; que emitiera `NOTICE` es **B** (deducido del código), no **A** (no hay log capturado).
2. Solo en una base **nueva/vacía** (reconstrucción desde cero) los roles se crearían con esa misma forma `CREATE ROLE ... WITH LOGIN/NOLOGIN INHERIT` **sin literal de contraseña en el repositorio**; un LOGIN creado así nace sin contraseña y la fija después, fuera del repo, con `ALTER ROLE` mediante variable de entorno en `psql`. Verificación de conexión de prueba: **pendiente** en **A**.
3. No se usa `CREATE ROLE` directo ni `DROP ROLE` (**B**): evitarían la idempotencia y podrían alterar el estado vigente.
4. **Orden adoptado:** `sql/roles.sql` ubica la creación condicional (§2) **antes** de membresías (§3), hardening (§4) y permisos (§§5–8) (**B**, lectura del archivo). Una propuesta inicial que ubicaba `GRANT` antes de que los roles existieran podía provocar `ERROR` al ejecutar el script; se corrigió haciendo que los roles existan antes de aplicar membresías/permisos (ver §9, **C**).

## 4. Permisos requeridos por rol

**Principio de mínimo privilegio (**C** operativo, **B** en enunciados, **A** parcial):** cada rol recibe exactamente los permisos que necesita para su función y ninguno más. **B**: el script no usa `GRANT ALL`; privilegios otorgados a roles de grupo, no directamente a logins (excepto los directos de `admin_datos` junto con `CONNECT/USAGE`). La ausencia de `GRANT ALL` por consulta **A** queda **pendiente** (no se ejecutó consulta `TRUNCATE/REFERENCES/TRIGGER`).

Ver detalle sentencia por sentencia en `design.md` y en `sql/roles.sql` (**B**). Resumen: **A** en tablas/vistas/MV y columna; **B** en secuencias/`CONNECT`/`USAGE` (ver §6):

- `rol_app_lectura` (**A** por `role_table_grants` + `column_privileges`): `SELECT` sobre `categoria`, `detalle_pedido`, `pedido`, `producto`, `v_detalle_pedido_producto` y `v_productos_activos`; `SELECT (id,nombre,apellido)` sobre `cliente` (sin `email`); sin `v_pedidos_cliente` ni escritura.
- `rol_app_escritura` (**A** por `role_table_grants`): `SELECT` sobre `categoria`, `producto`; `INSERT/UPDATE` sobre `cliente`; `INSERT/SELECT` sobre `pedido`; `INSERT/SELECT/DELETE` sobre `detalle_pedido`. Sin `SELECT` general sobre `cliente` (evita lectura masiva de `email`).
- `rol_soporte` (**A** por `role_table_grants`): `SELECT` sobre las 5 tablas base (`cliente`, `categoria`, `producto`, `pedido`, `detalle_pedido`) y sobre las 3 vistas (`v_productos_activos`, `v_pedidos_cliente`, `v_detalle_pedido_producto`) más la MV `mv_ventas_mensuales_forma_pago`, incluido `cliente.email` por soporte. Sin escritura.
- `rol_reportes` (**A** por `role_table_grants`): `SELECT` solo sobre `v_productos_activos`, `v_detalle_pedido_producto` y `mv_ventas_mensuales_forma_pago`; sin tablas base y sin `v_pedidos_cliente`.
- `admin_datos` (directos, sobre lo heredado de soporte) (**A** por `role_table_grants`): `INSERT/UPDATE` sobre `categoria` y `UPDATE` sobre `producto`.
- `app_web` / `usuario_reportes` directos `CONNECT/USAGE` y resto por herencia: **B** (código en §4 + membresías **A**); no hay consulta **A** de ACL `CONNECT`/`USAGE`.
- Secuencias (**B**, sin consulta **A** en esta conversación): `USAGE,SELECT` sobre `cliente_id_seq` y `pedido_id_seq` a `rol_app_escritura`; sobre `categoria_id_seq` a `admin_datos`. Sin `producto_id_seq` (ningún rol tiene `INSERT` en `producto`, **B**).
- Usos de base/esquema/tipo (**B**): `CONNECT` sobre la base y `USAGE` sobre esquema `public` y tipo `forma_pago_enum` presentes en el script (§4, ver `design.md` §3); estado en catálogo: **pendiente** en **A**.

## 5. Permiso a nivel de columna y adaptación de la consigna

La consigna exige al menos un permiso a nivel de columna y menciona la tabla `usuario` y funciones de autenticación (`fn_autenticar`, `fn_resetear_password`). **C**: la tabla `usuario` no pertenece a Food Store; la base real usa `cliente` (**B**: `foodstore.session.sql:12-21`, con `id, nombre, apellido, email`). **C**: tampoco se adoptan `fn_autenticar` ni `fn_resetear_password`. La adaptación adoptada usa exclusivamente la estructura real de Food Store:

| Consigna (**C**) | Estructura real (**B**) | Tratamiento aplicado (**B**+**C**) |
|---|---|---|
| Tabla `usuario` | `cliente (id, nombre, apellido, email)` | Permiso por columna sobre `cliente` |
| `fn_autenticar`, `fn_resetear_password` | Sin funciones equivalentes en la base | Ningún `GRANT`/`REVOKE` activo sobre ellas (**B**) |
| `sp_desactivar_producto` | Definido en `foodstore.session.sql:102-120` (**B**) | Sin `GRANT`/`REVOKE` activo; bloque comentado en `sql/roles.sql` §9 (**B**) |
| `usuario` / `v_pedidos_cliente` con `email` | `cliente.email` es el dato sensible real (**B**) | Exclusión de `email` y de `v_pedidos_cliente` donde corresponda (**C**) |

```sql
GRANT SELECT (id, nombre, apellido) ON TABLE cliente TO rol_app_lectura;
```
La columna `email` queda excluida para `rol_app_lectura` (**A**: sin permiso sobre `cliente.email` en `column_privileges`). `rol_soporte` sí la lee por soporte (**A** por `role_table_grants` + **B** por `GRANT` a nivel de tabla). `rol_app_escritura` no tiene `SELECT` general sobre `cliente` (**A** por ausencia en `role_table_grants`): su `INSERT,UPDATE` permiten escribir el `email` en alta/modificación, pero no leerlo masivamente (**B**).

## 6. Criterios de aceptación y verificación — A (ejecutado) / B (deducido) / pendiente

`sql/roles.sql` fue ejecutado con `psql -U postgres -d foodstore_tp3_prueba -f .\sql\roles.sql` y terminó **sin ningún `ERROR`** (**A**). Solo lo listado como **A** fue ejecutado en esta conversación; nada más puede llamarse verificado PostgreSQL:

**A — verificado por comandos ejecutados realmente:**
- `\du`: existen los 7 roles (`rol_app_lectura`, `rol_app_escritura`, `rol_soporte`, `rol_reportes`, `app_web`, `admin_datos`, `usuario_reportes`); los grupos muestran `Cannot login` y los login roles constan como roles de login. La ausencia de `SUPERUSER`/`CREATEROLE`/`CREATEDB`/`BYPASSRLS`/`INHERIT` en `\du` es **pendiente** en **A** (no consta captura completa).
- Consulta de membresías: `app_web` → `rol_app_lectura`; `app_web` → `rol_app_escritura`; `admin_datos` → `rol_soporte`; `usuario_reportes` → `rol_reportes`.
- `information_schema.role_table_grants` (tablas/vistas/MV): lo detallado en §4 para lectura/escritura/soporte/reportes/`admin_datos`.
- `information_schema.column_privileges` sobre `cliente` para `rol_app_lectura`: solo `id`, `nombre`, `apellido`; sin `email`.
- `pg_default_acl` (2 filas reales):
  ```
  postgres | public | r | {rol_soporte=r/postgres}
  postgres | public | S | {rol_app_escritura=rU/postgres}
  ```

**B — deducido del código (no consultado en A):**
- La correspondencia de esas 2 filas con `GRANT SELECT ON TABLES TO rol_soporte` y `GRANT USAGE, SELECT ON SEQUENCES TO rol_app_escritura` y que el `REVOKE SELECT ON TABLES FROM rol_app_lectura` no crea entrada por defecto (lectura de `sql/roles.sql` §10 + semántica PostgreSQL).
- Secuencias (`§4`), `CONNECT`/`USAGE` de base/esquema/tipo (`design.md` §3) y ausencia de `SUPERUSER`/`INHERIT`: constan en el script y no fallaron (**B**); su estado en catálogo queda **pendiente** en **A**.
- Ausencia de `GRANT`/`REVOKE` activo sobre `usuario`, `fn_autenticar`, `fn_resetear_password`, `sp_desactivar_producto`, `fn_verificar_pedido_sin_detalle`, `trg_fn_validar_producto_activo` (comentados en §9, **B**). Su inexistencia en catálogo es **C** (adaptación); prueba PostgreSQL: **pendiente**.

**Pendiente (no ejecutado en esta conversación, no afirmar como A):** `SELECT version()`, `\l`, `\dn+`, `\dp`, consultas de propietarios, consulta `TRUNCATE/REFERENCES/TRIGGER` (por tanto la no-existencia de `GRANT ALL` por esa vía), consulta específica de secuencias/`CONNECT`, y verificación de contraseñas/cifrado/`pg_hba.conf`.

## 7. Restricciones de seguridad (principio de mínimo privilegio)

1. Prohibición de `GRANT ALL` (**B** en script; verificación por consulta **pendiente**).
2. Sin `LOGIN` en grupos (**A** por `Cannot login` en `\du`); sin atributos superusuario (**B** en script, **pendiente** en **A**).
3. Sin DDL para la aplicación (**B**); `REVOKE CREATE ON SCHEMA public FROM PUBLIC` (**B**); revocación de `EXECUTE` de `PUBLIC` y `GRANT EXECUTE` sobre procedimiento/funciones **solo cuando existan** (**C**+**B**; prueba de inexistencia **pendiente**, ver §§2.2 y 3.2).
4. Contraseñas fuera del repositorio, sin marcadores reutilizables (**B**; verificación **pendiente**).
5. Sin `SELECT` automático por defecto sobre tablas futuras para `rol_app_lectura`: `ALTER DEFAULT PRIVILEGES ... REVOKE SELECT ON TABLES FROM rol_app_lectura` (**B**, ver `design.md` §8; ausencia de fila **A** por `pg_default_acl`). Las tablas futuras se conceden con `GRANT` explícito por tabla/columna tras revisar datos sensibles (**C**).
6. Sin permisos activos sobre objetos sin equivalente en Food Store (`usuario`, `fn_autenticar`, `fn_resetear_password`, `sp_desactivar_producto`, `fn_verificar_pedido_sin_detalle`, `trg_fn_validar_producto_activo`) (**B** code + **C** decisión); ver §9.
7. Decisiones de riesgo/duda en `design.md` §§10–11.

## 8. Trazabilidad

- `sql/roles.sql`: implementación **ejecutada sin `ERROR` (A)** y verificada parcialmente en **A** (§6: roles/membresías/tablas/columna/`pg_default_acl`); el resto es **B** o **pendiente**.
- `design.md`: diseño detalle (esta carpeta) con misma clasificación **A/B/C**.
- Archivos originales de unidades anteriores: sin modificaciones.

## 9. Propuestas de IA detectadas como inseguras o incorrectas y rechazadas/corregidas (**C**: trazabilidad de la decisión)

### 9.1 `REVOKE ALL ON DATABASE ... FROM PUBLIC` (inseguro, rechazado)

La IA propuso inicialmente:

```sql
REVOKE ALL ON DATABASE ... FROM PUBLIC
```

Se consideró **demasiado amplio** porque revocaba indiscriminadamente todos los privilegios de `PUBLIC` sobre la base, cuando el objetivo concreto era impedir conexiones públicas (rompería permisos no relacionados con la conexión y dificultaría el control por rol).

La solución adoptada fue restringirlo a:

```sql
REVOKE CONNECT ON DATABASE ... FROM PUBLIC
```

y luego otorgar `CONNECT` explícitamente a los login roles necesarios (`app_web`, `admin_datos`, `usuario_reportes`), mediante `current_database()` como en `sql/roles.sql` §4 (`design.md` §3). Así se cumple el objetivo (sin conexiones públicas) sin revocar de más.

### 9.2 Orden de creación de roles frente a membresías/permisos (incorrecto, corregido)

Una propuesta inicial no respetaba el orden de creación de roles/membresías y podía provocar `ERROR` al ejecutar el script (ej. `GRANT rol_app_lectura TO app_web` antes de que ambos roles existieran, o `GRANT` sobre roles aún no creados).

Corrección aplicada: `sql/roles.sql` crea condicionalmente los siete roles en §2 **antes** de membresías (§3), hardening (§4) y permisos (§§5–8) (**B**, orden en el archivo). Ejecución sin `ERROR` (**A**); que el bloque emitiera `NOTICE` por preexistencia es **B** (deducido del `ELSE RAISE NOTICE`), no **A** (sin log) — ver §3.3.
