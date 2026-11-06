# Informe de auditoría — Parte B

## TP5 · Base de Datos II · Food Store

> **Estado:** prueba **ejecutada** el 2026-11-06 13:52:25–13:53:01 -03 sobre
> `foodstore_tp3_prueba` (**A**: fragmento verbatim en
> `docs/log_auditoria_prueba.txt` §B). La actividad 13:49–13:51 (`SHOW` /
> `ALTER SYSTEM`) es preparación, no prueba funcional. El `FATAL` de las
> 12:22:45 por timeout es revisión previa, **no** es el login fallido
> controlado (13:52:50).
>
> Clasificación: **A** = ejecutado y observado en el log real; **B** =
> inspeccionado leyendo archivos; **C** = pendiente (reversión de parámetros,
> ver §6). Base: `foodstore_tp3_prueba`, PostgreSQL local 18.6 (**B**).

## 1. Entorno

| Ítem | Valor | Evidencia |
|---|---|---|
| Motor | PostgreSQL 18.6 local (`postgresql-x64-18`, servicio en `NT AUTHORITY\NetworkService`) | **B** (servicio + `psql --version`) |
| Base | `foodstore_tp3_prueba` | **A** (`conexión autorizada: ... base_de_datos=foodstore_tp3_prueba`, 13:52:25) |
| Fecha de prueba | 2026-11-06 13:52:25–13:53:01 -03 | **A** (log real) |
| Esquema (5 tablas) | `categoria`, `cliente`, `producto`, `pedido`, `detalle_pedido` | **B** (`foodstore.session.sql`) |
| Adaptación | La consigna menciona `usuario`/`fn_autenticar`; **C**: se usa `cliente` (con `id,nombre,apellido,email`, **B**) y no se crean esos objetos | **C** |

## 2. Configuración

**Valores leídos de archivos (**B**) y método (**B**):**

| Parámetro | Valor actual (**B**, archivo) | Valor propuesto | Motivo |
|---|---|---|---|
| `logging_collector` | `on` (activo, `postgresql.conf:495`) | mantener `on` | Necesario para escribir log a archivo |
| `log_directory` | comentado → default `log` (**B**) | mantener default | Ya se localizó el log real vía `current_logfiles` |
| `log_filename` | comentado → default `postgresql-%Y-%m-%d_%H%M%S.log` (**B**) | mantener default | Genera el archivo del día |
| `log_file_mode` | `0640` (activo, **B**) | mantener | Legible solo por dueño/grupo servicio |
| `log_connections` | comentado → default `''` (**B**: `postgresql.conf:598`) | `ALTER SYSTEM SET log_connections='all'` | Registra quién/se conecta desde dónde |
| `log_disconnections` | comentado → default `off` (**B**) | `ALTER SYSTEM SET log_disconnections='on'` | Registra cierre/duración |
| `log_statement` | comentado → default `'none'` (**B**) | `ALTER SYSTEM SET log_statement='all'` **TEMPORAL** durante la prueba, luego volver a `'none'` | Único nivel que captura en el log SELECT+INSERT+UPDATE exigidos por la consigna. `'mod'` es insuficiente (no registra SELECT) y `'ddl'` solo DDL. Ver §4 |

**Corrección de estrategia (BITACORA B3):** la consigna exige en el log
SELECT, INSERT, UPDATE, conexión exitosa/fallida y usuario/base/fecha. Con
`log_statement='mod'` el SELECT no queda registrado (solo modificación), por lo
que no cumpliría la consigna. La estrategia corregida es `log_statement='all'`
**solo durante la ventana controlada**, con datos sintéticos y reversión
inmediata a `'none'`. Es un ejercicio académico con prueba acotada: el costo
de volumen/litérales de `'all'` se mitiga por la ventana breve y por no volcar
filas reales; no debe quedar permanente. El valor `'mod'` puede quedar como
habitual posterior, pero no sirve como evidencia de esta prueba.

**Activación ejecutada (**A** en su efecto, **B** en método):** preparación
13:49–13:51 muestra `SHOW` y `ALTER SYSTEM SET log_connections='all'` /
`log_disconnections='on'` + `pg_reload_conf()` en el log. El `ALTER` de
`log_statement='all'` no aparece logueado porque antes era `'none'`; su
activación queda demostrada porque los `SELECT` de 13:52:25 sí se registrarán
en el log (ver §3). Método fue `ALTER SYSTEM` (escribe `postgresql.auto.conf`)
+ `SELECT pg_reload_conf()` (aplica a sesiones nuevas; sin reinicio porque
`logging_collector` ya estaba en `on`, **B**). La reversión de `log_statement`
a `'none'` queda **pendiente** (**C**, ver §6; no realizada en esta etapa).

**Log real localizado (**B**):** `C:\Program Files\PostgreSQL\18\data\log\postgresql-2026-11-06_090643.log`
(vía `current_logfiles`; líneas del día en `docs/log_auditoria_prueba.txt`).

## 3. Prueba realizada — ejecutada 13:52:25–13:53:01 (**A**)

Ejecutada sobre `foodstore_tp3_prueba` como `postgres` (observado en
`conexión autorizada: usuario=postgres ...`, **no** como `app_web`; ver
Limitaciones). Definición reproducible en `sql/auditoria_test.sql` §§1–4.

- **Conexión exitosa:** 13:52:25 `conexión autenticada: identidad=postgres
  método=scram-sha-256 (pg_hba.conf:117)` + `conexión autorizada:
  usuario=postgres base_de_datos=foodstore_tp3_prueba` + `connection ready`.
- **SELECT (§1):** 5 sentencias registradas a las 13:52:25
  (`current_user`/`current_database()` + conteos de `cliente`, `producto`,
  `pedido`, `v_productos_activos`). Prueban que `log_statement='all'`
  temporal capturó lectura.
- **INSERT reversible (§2):** `BEGIN; INSERT INTO cliente ... VALUES
  ('Prueba','Auditoria','auditoria.prueba@foodstore.test') RETURNING id;
  ROLLBACK;` — `ROLLBACK` logueado; reversible por semántica PostgreSQL (**B**).
- **UPDATE reversible (§3):** `BEGIN; INSERT ... RETURNING id; UPDATE cliente
  SET apellido='AuditoriaModificado' WHERE id=lastval() RETURNING ...;
  ROLLBACK;` — por `id`, sin tocar filas reales.
- **Login fallido controlado (§4, no SQL):** 13:52:50 (principal) y segundo
  intento 13:53:01: `conexión recibida: host=::1` + `FATAL: la autenticación
  password falló para el usuario rol_inexistente_parteB` + `DETALLE: No existe
  el rol rol_inexistente_parteB` + regla `::1/128 scram-sha-256` línea 117.
  Sin almacenar contraseñas. El `FATAL` de 12:22:45 por timeout **no** es
  este evento.

Sin `TRUNCATE`, `DROP`, `DELETE` masivo ni cambios estructurales (**B**);
sin datos personales reales (solo `@foodstore.test`). La actividad
13:49–13:51 (`SHOW`, `ALTER SYSTEM`) es configuración, no prueba funcional.

## 4. Análisis de auditoría

**Qué permitió demostrar cada mecanismo (ejecutado, **A**; explicación **B**):**

| Requisito consigna | Mecanismo en la estrategia corregida |
|---|---|
| Conexión exitosa | `log_connections='all'` (línea con `user=`, `database=`, `host=`/socket, marca temporal) |
| Conexión fallida | `pg_hba.conf` scram + `logging_collector=on` (línea `FATAL: password authentication failed`); `log_connections` no condiciona el fallo, pero el intento queda en el log del servidor |
| SELECT | `log_statement='all'` (línea `statement: SELECT ...` con usuario/base/fecha) |
| INSERT | `log_statement='all'` (línea `statement: INSERT ...`) |
| UPDATE | `log_statement='all'` (línea `statement: UPDATE ...`) |
| Usuario/base/fecha | En cada línea de conexión y de sentencia (`user=`, `database=`, marca temporal) |

Con `log_statement='mod'` el SELECT no habría quedado demostrado; la ejecución
con `'all'` temporal sí lo demostró (SELECT presentes en el log). El extracto
previo de checkpoints/timeout (**A**, `docs/log_auditoria_prueba.txt` §A) es
log no relacionado y no debe confundirse con la prueba (§B).

**Qué no proporciona el log nativo (**B**, conceptual):** no devuelve filas ni
conteos de sentencias (eso solo lo ve el cliente `psql`); no distingue el usuario
final web (todo pasa por `app_web` compartido); con valores menores a `'all'`
puede no registrar alguna de las sentencias exigidas (en particular `'mod'` no
registra `SELECT`); es texto plano rotativo sin estructura ni encadenamiento
inmutable, y puede incluir literales sensibles de las sentencias logueadas
con `'all'` (mitigado aquí por la ventana breve y datos sintéticos).

**`pgaudit` (conceptual, no instalado):** auditoría estructurada por objeto/
columna (sesión, objeto, rol, sentencia, filas) filtrable por tipo de sentencia y
apta para SIEM; requiere `shared_preload_libraries='pgaudit'` + reinicio y registra
sin autorizar. Diferencia clave: nativo narra frases de modificación; `pgaudit`
descompone el acceso a nivel de objeto/columna con granularidad fila/objeto. No se
instaló en este TP (**C**).

## 5. Sensibilidad del log

El archivo de log es un activo sensible: contiene usuarios, hosts, sentencias y
posibles datos personales, por lo que debe tratarse como evidencia protegida.
Solo debería leerlo el personal autorizado (DBA/seguridad), con permisos restrictivos
a nivel de sistema operativo (p. ej. `0640` y directorio no público) y del motor
(solo superusuario/administrador de log), y anonimizarlo antes de compartirlo.

## 6. Limitaciones y pendiente

- La prueba corrió como `postgres` (**A**), no como `app_web`/`admin_datos`/
  `usuario_reportes`: demostró auditoría (quién/base/cuándo) pero no ejerció
  permisos de Parte A. Una repetición como `app_web` queda como **pendiente**
  opcional.
- La no persistencia tras `ROLLBACK` se infiere por semántica PostgreSQL (**B**);
  el conteo `count=0` posterior no está en el fragmento (**pendiente** si se exige).
- **C — pendiente (única tarea):** revertir `log_statement` temporal a `'none'`
  con `ALTER SYSTEM` + `pg_reload_conf()` y verificar con `SHOW log_statement`.
  No realizada en esta etapa por instrucción expresa.
