# Design — Parte A: Roles y Permisos
## TP5 · Base de Datos II · Food Store

---

> **Estado de esta especificación:** documento de entrada preparado
> para ser utilizado en Kiro (no se afirma que Kiro lo haya
> generado ni ejecutado). La única implementación ejecutable es
> `sql/roles.sql`, **ejecutada sin `ERROR`** con `psql -U postgres -d foodstore_tp3_prueba -f .\sql\roles.sql` (**A**).
> **A** = ejecutado realmente en esta conversación (ejecución sin `ERROR`, `\du`, membresías, `role_table_grants`, `column_privileges`, `pg_default_acl`);
> **B** = deducido de `sql/roles.sql`/archivos; **C** = adaptación de la consigna.
> La versión `18.6` es **B** (cabecera de `roles.sql`); `SELECT version()` es **pendiente** en **A** (ver §§9 y 11).

## 1. Diseño de roles

### 1.1 Atributos

| Rol | LOGIN | NOLOGIN | INHERIT | CREATEROLE | SUPERUSER | Password |
|---|---|---|---|---|---|---|
| `rol_app_lectura` | | ✓ | ✓ | | | No (grupo) |
| `rol_app_escritura` | | ✓ | ✓ | | | No (grupo) |
| `rol_soporte` | | ✓ | ✓ | | | No (grupo) |
| `rol_reportes` | | ✓ | ✓ | | | No (grupo) |
| `app_web` | ✓ | | ✓ | | | Configurada fuera del repositorio (existencia/cifrado **pendiente** en **A**, ver §10) |
| `admin_datos` | ✓ | | ✓ | | | Idem `app_web` |
| `usuario_reportes` | ✓ | | ✓ | | | Idem `app_web` |

**Leyenda:** `NOLOGIN`/`LOGIN` según `\du` es **A** parcial (grupos con `Cannot login`); `INHERIT`, `CREATEROLE`, `SUPERUSER` y resto de atributos son **B** (constan en `roles.sql` §2, sin captura completa **A**). `INHERIT` permite que cada login reciba automáticamente los privilegios del grupo al conectarse (**B**). **B**: el script no otorga `SUPERUSER`, `CREATEROLE`, `CREATEDB` ni `BYPASSRLS`. No se incluye ningún literal de contraseña en este diseño: un marcador commiteado podría ejecutarse por error como contraseña definitiva.

### 1.2 Sentencias base (resumen)

**B** (contexto operativo + bloque `DO`): los siete roles se tratan como preexistentes con `INHERIT` y sin atributos peligrosos; **A** solo acredita existencia posterior (ver §9), no preexistencia ni atributos. `sql/roles.sql` §2 contiene un bloque `DO` de `CREATE ROLE` **condicional**: crea cada rol solo si no existe en `pg_roles`, sin `PASSWORD` y sin alterar los existentes (si existen, `ELSE RAISE NOTICE` en el código). La forma canónica que ese bloque ejecuta, aplicable también a una base nueva/vacía, es:

```sql
CREATE ROLE rol_app_lectura WITH NOLOGIN INHERIT;
CREATE ROLE rol_app_escritura WITH NOLOGIN INHERIT;
CREATE ROLE rol_soporte WITH NOLOGIN INHERIT;
CREATE ROLE rol_reportes WITH NOLOGIN INHERIT;
CREATE ROLE app_web WITH LOGIN INHERIT;
CREATE ROLE admin_datos WITH LOGIN INHERIT;
CREATE ROLE usuario_reportes WITH LOGIN INHERIT;
-- Contraseña: SOLO fuera del repositorio, p. ej. con variable
-- de entorno en psql:  ALTER ROLE app_web WITH PASSWORD :'pwd';
-- Nunca commitear un literal ni un marcador reutilizable.
```

Un `CREATE ROLE` directo sobre la base actual daría `duplicate_object` y, con `PASSWORD`, sobrescribiría credenciales vigentes (**B**); por eso el bloque condicional comprueba `pg_roles` antes de crear. Ver `requirements.md` §3.3. **Resultado:** **A** la ejecución completa transcurrió sin `ERROR` y **A** los 7 roles existen tras `\du`; que el bloque emitiera `NOTICE` sin recrear/alterar es **B** (deducido del `ELSE`), no **A**. El orden 2→3→4→5–8 (roles antes que membresías/permisos, **B** en el archivo) corrige la propuesta inicial que podía fallar por aplicar `GRANT` sobre roles aún no creados (**C**, ver §11).

### 2.1 Permisos efectivos por herencia (unión, no solo directos)

| Login | Hereda | Permisos efectivos sobre `cliente` | Otros efectivos relevantes |
|---|---|---|---|
| `app_web` | lectura + escritura | `SELECT (id,nombre,apellido)` + `INSERT,UPDATE` (sin `SELECT email`) | `SELECT` catálogo/pedidos/detalle; `INSERT` pedido; `DELETE` detalle; `SELECT` vistas sin `v_pedidos_cliente` (**A** tablas/vistas; secuencias **B**) |
| `admin_datos` | soporte | `SELECT` completo incl. `email` | `SELECT` todas las tablas/vistas/MV; `UPDATE producto`; `INSERT,UPDATE categoria` (**A** tablas; secuencia **B**) |
| `usuario_reportes` | reportes | Ninguno (sin tablas base) | Solo `SELECT` `v_productos_activos`, `v_detalle_pedido_producto`, MV; sin `v_pedidos_cliente` (**A**) |

Ningún login hereda de otro login (**B** en script); la jerarquía es plana (grupo→login) y los grupos son `NOLOGIN` (**A** por `Cannot login` en `\du`).

## 2. Jerarquía y membresías

```
rol_app_lectura ──────┐
                       ├──► app_web
rol_app_escritura ────┘

rol_soporte ──────────► admin_datos
rol_reportes ─────────► usuario_reportes
```

```sql
GRANT rol_app_lectura TO app_web;
GRANT rol_app_escritura TO app_web;
GRANT rol_soporte TO admin_datos;
GRANT rol_reportes TO usuario_reportes;
```
`usuario_reportes` hereda **únicamente** `rol_reportes` (decisión humana 2).

## 3. Hardening de PUBLIC y base/esquema/tipo

No se hardcodea el nombre de la base (§ requirements 2.3). Se usa `current_database()`:
```sql
REVOKE CREATE ON SCHEMA public FROM PUBLIC;
DO $$
BEGIN
    EXECUTE format('REVOKE CONNECT ON DATABASE %I FROM PUBLIC', current_database());
    EXECUTE format('GRANT CONNECT ON DATABASE %I TO app_web', current_database());
    EXECUTE format('GRANT CONNECT ON DATABASE %I TO admin_datos', current_database());
    EXECUTE format('GRANT CONNECT ON DATABASE %I TO usuario_reportes', current_database());
END $$;
GRANT USAGE ON SCHEMA public TO app_web, admin_datos, usuario_reportes;
GRANT USAGE ON TYPE forma_pago_enum TO app_web, admin_datos, usuario_reportes;
```
**Propuesta de IA detectada como insegura y rechazada (**C**: trazabilidad, ver `requirements.md` §9.1):** la IA propuso inicialmente `REVOKE ALL ON DATABASE ... FROM PUBLIC`. Se consideró demasiado amplio porque revocaba indiscriminadamente todos los privilegios de `PUBLIC`, cuando el objetivo concreto era impedir conexiones públicas (**C**). La solución adoptada fue restringirlo a `REVOKE CONNECT ON DATABASE ... FROM PUBLIC` y luego otorgar `CONNECT` explícitamente a los login roles necesarios (`app_web`, `admin_datos`, `usuario_reportes`), como en `sql/roles.sql` §4 (**B**); que §4 corrió sin `ERROR` es **A**, pero su ACL `CONNECT` en catálogo es **pendiente** (no hay consulta **A**).

Sin `USAGE` en esquema y tipo, el login no puede resolver tablas ni el enum de `pedido.forma_pago` (**B**). Los `USAGE` de esquema/tipo constan en `roles.sql` §4 (**B**); su estado en catálogo es **pendiente** en **A**.

## 4. Permisos a nivel de tabla

### 4.1 `rol_app_lectura`
```sql
GRANT SELECT ON TABLE producto TO rol_app_lectura;
GRANT SELECT ON TABLE categoria TO rol_app_lectura;
GRANT SELECT ON TABLE pedido TO rol_app_lectura;
GRANT SELECT ON TABLE detalle_pedido TO rol_app_lectura;
```
Sin escritura ni `v_pedidos_cliente` (expone `cliente.email`, contradice mínimo privilegio y el permiso de columna) — ausencia **A** en `role_table_grants`.

### 4.2 `rol_app_escritura`
```sql
GRANT INSERT, UPDATE ON TABLE cliente TO rol_app_escritura;
GRANT SELECT, INSERT ON TABLE pedido TO rol_app_escritura;
GRANT SELECT, INSERT, DELETE ON TABLE detalle_pedido TO rol_app_escritura;
GRANT SELECT ON TABLE producto TO rol_app_escritura;
GRANT SELECT ON TABLE categoria TO rol_app_escritura;
```
Sin `SELECT` general sobre `cliente` (un `SELECT` a nivel de tabla expondría `email` en lectura masiva y contradice el permiso por columna de §5) — ausencia **A** en `role_table_grants`; sin `UPDATE/DELETE` en `pedido` ni `UPDATE/DELETE` en `producto/categoria` (**A**). El `INSERT,UPDATE` sobre `cliente` permite escribir el `email` en alta/modificación, no leerlo masivamente (**B** justificación).

### 4.3 `rol_soporte`
```sql
GRANT SELECT ON TABLE cliente TO rol_soporte;
GRANT SELECT ON TABLE categoria TO rol_soporte;
GRANT SELECT ON TABLE producto TO rol_soporte;
GRANT SELECT ON TABLE pedido TO rol_soporte;
GRANT SELECT ON TABLE detalle_pedido TO rol_soporte;
```
Lectura completa, incluido `cliente.email`.

### 4.4 `admin_datos` (directos)
```sql
GRANT UPDATE ON TABLE producto TO admin_datos;
GRANT INSERT, UPDATE ON TABLE categoria TO admin_datos;
GRANT USAGE, SELECT ON SEQUENCE categoria_id_seq TO admin_datos;
```

## 5. Permiso a nivel de columna

```sql
GRANT SELECT (id, nombre, apellido) ON TABLE cliente TO rol_app_lectura;
```
**Adaptación a la estructura real (**C**+**B**):** la tabla `usuario` de la consigna no pertenece a Food Store (**C**); `cliente` (`id, nombre, apellido, email`, `foodstore.session.sql:12-21`) es el equivalente funcional (**B**) y `cliente.email` es el dato personal sensible. **C**: tampoco se adoptan `fn_autenticar` ni `fn_resetear_password` (**B**: sin permiso en el script). Prueba PostgreSQL de inexistencia: **pendiente** (sin consulta en **A**). `rol_soporte` sí lee `email` por soporte (GRANT a nivel de tabla, **A** por `role_table_grants`). `rol_app_escritura` no tiene `SELECT` general sobre `cliente` (**A**, ver §4.2). **Resultado A:** `rol_app_lectura` solo tiene `SELECT` sobre `id`, `nombre`, `apellido` y **no** sobre `cliente.email` (por `column_privileges`).

## 6. Permisos sobre secuencias

```sql
GRANT USAGE, SELECT ON SEQUENCE cliente_id_seq TO rol_app_escritura;
GRANT USAGE, SELECT ON SEQUENCE pedido_id_seq TO rol_app_escritura;
GRANT USAGE, SELECT ON SEQUENCE categoria_id_seq TO admin_datos;
```
`detalle_pedido` no requiere permiso (sin IDENTITY, **B**); `producto_id_seq` no se otorga porque `admin_datos` no tiene `INSERT` en `producto` (**B**). Los `GRANT` sobre secuencias son **B** (presentes en `roles.sql` §8, sin consulta **A** en esta conversación; estado en catálogo **pendiente**).

## 7. Permisos sobre vistas/MV y procedimiento

```sql
-- Lectura: sin v_pedidos_cliente
GRANT SELECT ON TABLE v_productos_activos TO rol_app_lectura;
GRANT SELECT ON TABLE v_detalle_pedido_producto TO rol_app_lectura;

-- Soporte: vistas + MV
GRANT SELECT ON TABLE v_productos_activos TO rol_soporte;
GRANT SELECT ON TABLE v_pedidos_cliente TO rol_soporte;
GRANT SELECT ON TABLE v_detalle_pedido_producto TO rol_soporte;
GRANT SELECT ON TABLE mv_ventas_mensuales_forma_pago TO rol_soporte;

-- Reportes: solo vistas + MV, SIN v_pedidos_cliente (expone email)
GRANT SELECT ON TABLE v_productos_activos TO rol_reportes;
GRANT SELECT ON TABLE v_detalle_pedido_producto TO rol_reportes;
GRANT SELECT ON TABLE mv_ventas_mensuales_forma_pago TO rol_reportes;
```
La efectividad de esos `SELECT` sobre vistas/MV es **A** (por `role_table_grants`). Procedimiento y funciones — PostgreSQL concede `EXECUTE` a `PUBLIC` por defecto (**B**). **C**: `usuario`, `fn_autenticar`, `fn_resetear_password`, `sp_desactivar_producto`, `fn_verificar_pedido_sin_detalle` y `trg_fn_validar_producto_activo` no se adoptan como objetos activos de Food Store; prueba PostgreSQL de inexistencia: **pendiente** en **A**. Por eso las sentencias siguientes están **comentadas** en `sql/roles.sql` §9 (**B**) y solo se aplicarían cuando el objeto se cree realmente; ejecutarlas sin objeto daría `ERROR` (**B**). **Decisión C:** no ejecutar permisos sobre objetos sin equivalente real (ver §11). La ejecución sobre objetos existentes transcurrió sin `ERROR` (**A**):

```sql
-- SOLO cuando existan en la base (hoy sin equivalente, C):
-- REVOKE EXECUTE ON PROCEDURE sp_desactivar_producto(bigint) FROM PUBLIC;
-- REVOKE EXECUTE ON FUNCTION fn_verificar_pedido_sin_detalle() FROM PUBLIC;
-- REVOKE EXECUTE ON FUNCTION trg_fn_validar_producto_activo() FROM PUBLIC;
-- GRANT EXECUTE ON PROCEDURE sp_desactivar_producto(bigint) TO admin_datos;
```

## 8. ALTER DEFAULT PRIVILEGES (solo dos otorgamientos + un REVOKE)

Como `ALTER DEFAULT PRIVILEGES` aplica a **todos** los objetos futuros del esquema (no por nombre) y solo puede otorgar a nivel de tabla (no por columna), otorgar `SELECT/INSERT/UPDATE` o `EXECUTE` automático indiscriminado sería exceso de privilegio y expondría datos sensibles futuros. Decisión final: solo los defaults justificados; el resto, `GRANT` explícito por objeto tras revisar sus columnas sensibles.

```sql
ALTER DEFAULT PRIVILEGES FOR ROLE "postgres" IN SCHEMA public
    REVOKE SELECT ON TABLES FROM rol_app_lectura;
ALTER DEFAULT PRIVILEGES FOR ROLE "postgres" IN SCHEMA public
    GRANT SELECT ON TABLES TO rol_soporte;
ALTER DEFAULT PRIVILEGES FOR ROLE "postgres" IN SCHEMA public
    GRANT USAGE, SELECT ON SEQUENCES TO rol_app_escritura;
```

**Corrección TP5:** la versión anterior otorgaba `GRANT SELECT ON TABLES TO rol_app_lectura`. Era inseguro porque (a) es a nivel de tabla —incluye todas las columnas futuras, p. ej. un futuro `email`/`token`/`password_hash`— y (b) `app_web` hereda `rol_app_lectura`, por lo que cualquier tabla futura creada por `postgres` habría quedado legible por la aplicación, salteando el permiso por columna de §5 y la exclusión de `v_pedidos_cliente`. PostgreSQL no permite un `DEFAULT PRIVILEGES` por columna, así que la única opción de mínimo privilegio es **no** conceder lectura futura a `rol_app_lectura` y conceder cada tabla futura con `GRANT` explícito por tabla o por columna. El `REVOKE` mantiene el uso de `ALTER DEFAULT PRIVILEGES` exigido por la consigna.

Justificación de los que se conservan (**B**): `rol_soporte` ya tiene lectura completa con `email` por soporte (§4.3); las secuencias no contienen datos personales y `USAGE,SELECT` es necesario para futuros `INSERT` con `IDENTITY` de escritura (revisable por objeto). Las filas `pg_default_acl` que los acreditan son **A** (ver §9); la correspondencia sentencia↔fila es **B**. Explícitamente **eliminado en el script (**B**)**: cualquier `INSERT/UPDATE/EXECUTE` por defecto, `SELECT` por defecto a `rol_app_escritura`/`rol_reportes`, y `SELECT` por defecto a `rol_app_lectura`.

## 9. Verificación — A (ejecutada) / B (deducida) / pendiente

`sql/roles.sql` fue ejecutado con `psql -U postgres -d foodstore_tp3_prueba -f .\sql\roles.sql` y terminó **sin ningún `ERROR`** (**A**). Solo esto es **A**:

- Paso 1 `\du` (**A**): 7 roles existen (`rol_app_lectura`, `rol_app_escritura`, `rol_soporte`, `rol_reportes`, `app_web`, `admin_datos`, `usuario_reportes`); grupos con `Cannot login`. Base `foodstore_tp3_prueba` por comando (**A**). **Pendiente** en **A**: `SELECT version()`/`\l`, `\dn+`, `\dp`, propietarios, y captura completa de `SUPERUSER`/`CREATEROLE`/`CREATEDB`/`BYPASSRLS`/`INHERIT`. Versión `18.6`: **B**.
- Paso 2 Membresías (**A**, resultado; método no detallado en esta conversación): `app_web`→`rol_app_lectura`, `app_web`→`rol_app_escritura`, `admin_datos`→`rol_soporte`, `usuario_reportes`→`rol_reportes`.
- Paso 3 `information_schema.role_table_grants` (**A**): lectura con `SELECT` sobre `categoria`, `detalle_pedido`, `pedido`, `producto`, `v_detalle_pedido_producto`, `v_productos_activos` (sin `v_pedidos_cliente`); escritura con `SELECT` sobre `categoria`/`producto`, `INSERT/UPDATE` sobre `cliente`, `INSERT/SELECT` sobre `pedido`, `INSERT/SELECT/DELETE` sobre `detalle_pedido` (sin `SELECT` general sobre `cliente`); soporte con `SELECT` sobre las 5 tablas y las 3 vistas + MV; reportes solo sobre vistas de reportes + MV (sin tablas base, sin `v_pedidos_cliente`); `admin_datos` con `INSERT/UPDATE` sobre `categoria` y `UPDATE` sobre `producto`.
- Paso 4 `information_schema.column_privileges` (**A**) sobre `cliente` para `rol_app_lectura`: solo `id`, `nombre`, `apellido`; sin `email`.
- Paso 5 `pg_default_acl` (**A**, 2 filas reales, ninguna para `rol_app_lectura`):
  ```
  postgres | public | r | {rol_soporte=r/postgres}
  postgres | public | S | {rol_app_escritura=rU/postgres}
  ```
  **B** (correspondencia): equivalen a `GRANT SELECT ON TABLES TO rol_soporte` y `GRANT USAGE, SELECT ON SEQUENCES TO rol_app_escritura` en `roles.sql` §10; el `REVOKE SELECT ON TABLES FROM rol_app_lectura` no crea entrada por defecto (semántica PostgreSQL, **B**).
- Paso 6 `GRANT ALL` (**pendiente**): no se ejecutó consulta `TRUNCATE/REFERENCES/TRIGGER` en esta conversación; no puede afirmarse como **A**. **B**: el script no contiene `GRANT ALL`.
- Secuencias y `CONNECT`/`USAGE` (**B**, **pendiente** en **A**): constan en `roles.sql` §§4/8 y no fallaron; sin consulta **A** de ACL.

## 10. Riesgos y limitaciones documentados

1. **Sin RLS (**B**):** cualquier `SELECT` sobre `pedido/cliente` ve todos los clientes; `app_web` es credencial compartida de la API (sin identidad por usuario final). Queda fuera de Parte A.
2. **MV y triggers (**B**, condicional):** `REFRESH` solo del dueño; cuando existan, las funciones de trigger se revocan de `PUBLIC` para que no sean invocables directamente (hoy comentado en `roles.sql` §9).
3. **Contrasenas (pendiente):** no hay marcador en el repo (**B**: ausencia en archivos). Desde los archivos no se puede confirmar si los tres LOGIN tienen contraseña, su cifrado (SCRAM/MD5) ni si `pg_hba.conf` la exige; **pendiente** verificar manualmente y configurar fuera del repositorio (p. ej. `ALTER ROLE` con variable de entorno en `psql`), nunca con un literal commiteado.
4. **Nombre de base y versión:** base `foodstore_tp3_prueba` por comando (**A**), versión `18.6` **B** con `SELECT version()`/`\l` **pendientes** en **A** (ver §§1–9). `sql/roles.sql` ya fue ejecutado sin `ERROR` (**A**).

## 11. Estado ejecutado, decisiones y adaptación a la consigna

**Principio de mínimo privilegio:** **B**: el script no otorga `GRANT ALL`, `SUPERUSER`, `CREATEROLE`, `CREATEDB`, `BYPASSRLS` ni DDL; **A**: la exclusión de `cliente.email`/`v_pedidos_cliente` y los permisos concedidos constan en `role_table_grants`/`column_privileges`; verificación por consulta `TRUNCATE/REFERENCES/TRIGGER` **pendiente**. Los privilegios se otorgan a roles de grupo, no directamente a logins (excepto `admin_datos` y `CONNECT/USAGE`, **B**), y cada privilegio se justifica por la función del rol (§§4–8). La exclusión de `cliente.email` y de `v_pedidos_cliente` para lectura/reportes es parte de este principio (**C** operativo).

**Decisión de no ejecutar permisos sobre objetos sin equivalente real (**C**+**B**):** `usuario`, `fn_autenticar`, `fn_resetear_password`, `sp_desactivar_producto`, `fn_verificar_pedido_sin_detalle` y `trg_fn_validar_producto_activo` no se adoptan en Food Store (**C**); no hay consulta **A** de catálogo que acredite su inexistencia (**pendiente** si se exige). **B**: sobre ninguno se ejecutaron sentencias activas de `GRANT`/`REVOKE` en `roles.sql` (comentadas en §9), porque sin objeto habrían dado `ERROR` y habrían requerido inventar objetos. Afirmar un `GRANT EXECUTE` activo sobre ellos sería inventar un permiso existente.

**Adaptación de la consigna a Food Store (**C**):** la consigna genérica (`usuario`, autenticación) se adaptó a la estructura real (**B**: `cliente`, `pedido` con `forma_pago_enum`, vistas/MV existentes) sin crear objetos hipotéticos. El permiso por columna exigido se aplicó sobre `cliente` (`id, nombre, apellido`) excluyendo `email` (**A**+**B**), y la vista con `email` (`v_pedidos_cliente`) se limita a soporte (**A**). No se agregaron tabla `usuario` ni funciones de autenticación.

**Propuestas de IA rechazadas/corregidas (**C**: detalle en `requirements.md` §9):**
1. `REVOKE ALL ON DATABASE ... FROM PUBLIC` → rechazado por demasiado amplio; corregido a `REVOKE CONNECT ON DATABASE ... FROM PUBLIC` + `GRANT CONNECT` explícito a los login roles (§3, **B**; ejecución sin `ERROR` **A**).
2. Orden incorrecto (permisos/membresías antes de que los roles existieran) → corregido ubicando la creación condicional de los siete roles (§2) antes de membresías/permisos (§§3–8, **B**), con ejecución sin `ERROR` (**A**); `NOTICE` por preexistencia: **B**.
