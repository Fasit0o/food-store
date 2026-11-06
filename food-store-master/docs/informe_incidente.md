# Informe del simulacro de incidente — Parte C

## TP5 · Base de Datos II · Food Store

> **Estado: PARTE C — EJECUTADA 2026-11-06 (ventana aprox. 14:30-14:37 -03).**
> Base: `foodstore_tp3_prueba`, PostgreSQL 18.6. Resultados desde consola
> proporcionada + log local anonimizado (`docs/log_simulacro_anonimizado.txt`).
> Sin hashes/contraseñas en los documentos. El log bruto con SCRAM **no**
> debe incluirse en el ZIP de entrega.

## 1. Diferencia entre consigna y modelo real

| Consigna | Modelo real (operador + archivos) | Adaptación aplicada |
|---|---|---|
| Tabla `usuario` | **No existe**; existe `cliente` (`id, nombre, apellido, email`) | Lectura masiva controlada sobre `cliente` |
| `fn_autenticar` / `fn_resetear_password` | **No existen** en la base | Autenticación simulada a nivel de **conexión PostgreSQL** (`psql`); **no equivale** a `fn_autenticar` |
| `sp_desactivar_producto` y funciones de trigger | Definidas en `foodstore.session.sql` / `reglas_negocio.sql`, **no instaladas** en la base | Sin `GRANT EXECUTE` activo (Parte A §9) |

No se inventa la existencia de `usuario` ni de `fn_autenticar`. La
reconstrucción de esos objetos es una **propuesta separada no
ejecutada** (§12).

### Evaluación de la adaptación y aceptación docente requerida

- **Adaptación actual (conexión PostgreSQL + `cliente`):**
  razonable como *mínimo* sin alterar el esquema: prueba la capa
  de conexión y el mínimo privilegio reales de esta base, con
  diferencia explícita de que **no equivale** a `fn_autenticar`.
  **Requiere aceptación docente** para presentarla como
  cumplimiento del simulacro de la consigna.
- **Alternativa mejor si la cátedra exige literalidad:** reconstruir
  `usuario` + `fn_autenticar` + `fn_resetear_password` en una
  **base clonada separada** (nunca en `foodstore_tp3_prueba` sin
  respaldo) con `password_hash` y `EXECUTE` restringido, y rehacer
  los 9 pasos literales contra esa clona (§12). Es más fiel a la
  consigna pero implica crear objetos nuevos y su revisión de
  seguridad.
- **Estado de aceptación docente:** PENDIENTE (decisión humana).
  Hasta que se obtenga, este informe no afirma equivalencia con
  `fn_autenticar`.

## 2. Escenario y alcance

- **Actor atacante simulado:** sesión `app_web` (bajo privilegio:
  hereda `rol_app_lectura` + `rol_app_escritura`).
- **Objetivo del simulacro:** verificar que (a) la autenticación de
  conexión queda registrada, (b) un usuario de bajo privilegio no
  puede leer masivamente datos sensibles ni escalarse a
  `admin_datos`.
- **Alcance:** solo `foodstore_tp3_prueba` (copia de trabajo con
  respaldo previo). Sin ataques a sistemas externos, sin datos
  personales reales en la evidencia entregada a IA.
- **Fecha/hora:** 2026-11-06 aprox. 14:30–14:37 -03; conexión exitosa
  **14:33:44** confirmada. Horas de otros eventos solo como ventana
  (no inventadas).
- **Logging (ejecutado):** temporal `all`/`on`/`all` + `pg_reload_conf()`,
  luego `RESET` de los tres + `pg_reload_conf()=true`. Verificación final:
  `log_connections` default (vacío), `log_disconnections=off`,
  `log_statement=none`. Restauración completa.

## 3. ETAPA A — Autenticación fallida

- **Evento definido:** adivinación de credenciales de rol **existente**
  (`app_web` ×3 con contraseña incorrecta, terminal, no SQL). No se usa
  rol inexistente (Parte B ya demostró esa otra variante).
- **Dependencia de contraseña:** `app_web` tiene `LOGIN` (Parte A, `roles.sql`
  §2) pero el repositorio no contiene su contraseña. Durante la ejecución se
  cambió temporalmente por gestión de sesión administrativa, se restauró el
  hash original y luego se fijó una contraseña nueva por precaución (sin
  reproducir hashes). Ver §13.
- **Resultado real:** 5 FATAL en la ventana: **3 deliberados** de simulación
  (adivinación como `app_web`) + **2 adicionales** en pruebas posteriores.
  No contabilizar los 5 como deliberados. Ver timeline §8/log.
- **Resultado esperado:** `FATAL: password authentication failed` +
  `DETALLE` + regla `pg_hba` (conservar el mensaje real de PostgreSQL).

## 4. ETAPA B — Autenticación exitosa

- **Método:** conexión `psql -U app_web` con contraseña correcta;
  verificación de `current_user`/`session_user` y membresías.
- **Dependencia de contraseña:** la conexión exitosa se logró con una
  contraseña temporal configurada para la prueba; finalizó con una contraseña
  nueva (sin reproducirla).
- **Resultado real:** conexión autenticada/autorizada de `app_web` a
  `foodstore_tp3_prueba` a las **14:33:44** (consola + log).

## 5. ETAPA C — Lectura contada de `cliente`

- **Método (autocommit, sentencias independientes como `app_web`):**
  `count(id)` sobre `cliente` + `count(*)` sobre `pedido` + intentos
  sensibles por separado. Sin `BEGIN` común y sin escrituras.
- **Justificación:** `id` tiene `SELECT` por columna para `rol_app_lectura`
  (`roles.sql` §6) y por herencia `app_web`; `pedido` tiene `SELECT` a nivel
  de tabla para lectura/escritura (§5). Por eso `count(id)` es el conteo
  correcto sobre `cliente` (no `count(*)` general).
- **Alcance:** `count(id)`/`count(*)` registran lectura y conteo en el log,
  pero **no** demuestran extracción masiva de filas por sí solos. Mantiene
  mínima exposición (sin dump ni personales).
- **Resultado real:** `count(id)` cliente = **20.005**; `count(*)` pedido =
  **200.006** (permitidos). Conteos no prueban dump ni exfiltración.
- **¿Fue posible leer `email` masivamente?** No. `SELECT id,email` y
  `SELECT * FROM v_pedidos_cliente` rechazados por permisos.

## 6. ETAPA D — Intento de escalamiento hacia `admin_datos`

- **Métodos (individualmente, en autocommit, como `app_web`):**
  `GRANT admin_datos TO app_web;`, `GRANT rol_soporte TO app_web;`,
  `SET ROLE admin_datos;`, `SET ROLE rol_soporte;`
  **Resultado real:** los 4 rechazados (mensajes reales conservados en consola).
  Ningún `GRANT SUPERUSER`; verificar sin cambios de membresía.

## 7. ETAPA E — Verificación + cierre/contención

- `app_web` no miembro de `admin_datos`/`rol_soporte`: **OK**.
- `app_web` miembro de `rol_app_lectura`/`rol_app_escritura`: **OK**.
- `rolsuper=false`, `rolcreaterole=false`, `rolcanlogin=true`: **OK**,
  existe contraseña.
- Logging restaurado; cierre cronológico en log anonimizado.

## 8. Cronología (sin timestamps inventados más allá de los reales)

```text
aprox. 14:30-14:37 -03: config temporal + gestión credencial (sin hashes)
ventana 14:30-14:37: 5 FATAL (3 deliberados + 2 adicionales)
14:33:44: conexión exitosa app_web a foodstore_tp3_prueba
tras 14:33:44: count(id)=20005, count(*)=200006; SELECT email / vista rechazados
tras 14:33:44: 4 escalaciones rechazadas
final ventana: verificación roles + RESET logging + verificación SHOW
```
Horas individuales no confirmadas se reportan solo como ventana.

## 9. Evidencias

- Autenticación → `FATAL` ×5 (3+2) y `autenticada/autorizada` 14:33:44 en log anonimizado.
- Lectura contada → `SELECT count(id)...` (=20005), `SELECT count(*)...` (=200006).
- Accesos sensibles → `ERROR` por permisos sobre `cliente` y `v_pedidos_cliente`.
- Escalación → 4 `ERROR` rechazados; verificación sin membresía nueva.

## 10. Reconstrucción con OpenCode — comparación

Reconstrucción desde el **log anonimizado** (orden, usuario, base, tipo,
resultado; sin hashes). Tabla a completar por OpenCode con esa única fuente;
lo no inferible = DESCONOCIDO. No se ha ejecutado aún la reconstrucción.

| Evento | Real | Reconstruido (pendiente) |
|---|---|---|
| Autenticación fallida (5, 3+2) | FATAL ventana | — |
| Autenticación exitosa 14:33:44 | autenticada/autorizada | — |
| Lectura contada (=20005/200006) | sentencias OK | — |
| Accesos sensibles | 2 ERROR | — |
| Escalación ×4 | 4 ERROR | — |
| Cierre | RESET+SHOW OK | — |

## 11. Contención — SIMULACIÓN vs RESPUESTA REAL

- **SIMULACIÓN (ejecutada):** solo observar/registrar, verificar sin cambios,
  revertir logging y gestionar credencial (`\password` final). Sin bloqueo ni
  revocación por denegaciones esperadas.
- **RESPUESTA REAL (hipotética):** si hubiera lectura/escalación exitosa ⇒
  revocar privilegio, rotar credenciales (ya hecho por precaución), auditar y
  preservar logs. Como no hubo éxito, contención mínima: documentar y mantener esquema.

## 12. Propuesta separada: reconstruir `usuario` + `fn_autenticar`

**No ejecutada; no altera el esquema actual.** Implicaciones
(detalle en `sql/simulacro_incidente.sql`, bloque final; corrección del typo
anterior `simulacro_incidade.sql`):

1. Definir primero la relación `usuario`↔`cliente` (¿misma
   persona? ¿FK?) y el modelo de credenciales: solo
   `password_hash` con algoritmo adecuado, nunca claro.
2. `fn_autenticar` sin filtrar existencia de email; si es
   `SECURITY DEFINER`, revocar `EXECUTE` de `PUBLIC` y otorgar
   solo al rol exacto.
3. `fn_resetear_password` con token de un solo uso y expiración.
4. Solo entonces rehacer el simulacro literal de la consigna
   contra los objetos nuevos, en base de prueba separada.

## 13. Conclución, recuperación y limitaciones

- **Conclusión:** mínimo privilegio se mantuvo: conteos permitidos (20005/
  200006), sensibles y escalación rechazados, sin membresía ni atributos
  nuevos, logging restaurado.
- **Recuperación ejecutada:** restauración de hash temporal en sesión
  administrativa y luego `\password app_web` con logging restaurado
  (precaución por hashes en log). Verificación final OK.
- **Limitaciones:** adaptación a conexión PostgreSQL no prueba `fn_autenticar`
  inexistente (cumplimiento a evaluar por docente); conteos no prueban dump;
  reconstrucción OpenCode pendiente; log bruto con SCRAM no debe ir al ZIP.
