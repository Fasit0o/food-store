# Bitácora de uso de IA — TP5 (Unidad 5)

Base de datos II · Food Store · `foodstore_tp3_prueba` (PostgreSQL 18.6)

Durante el desarrollo se ejecutaron manualmente partes del TP para validar el funcionamiento. Los archivos que se entregan contienen las versiones finales de los scripts. En la Parte D se trabajó con una copia local (`sql/usuario_anon_local.sql`) con un salt generado para la prueba; esa copia ya fue eliminada antes de preparar la entrega. La salt real no aparece en ningún archivo versionado.

Tabla con tres columnas: 1) Prompt enviado a la IA, 2) Respuesta relevante recibida, 3) Validación o corrección realizada.

| # | Prompt enviado a la IA | Respuesta relevante recibida | Validación o corrección realizada |
|---|---|---|---|
| A1 | "Inspeccioná el proyecto completo y proponé una estrategia de roles con mínimo privilegio, sin modificar archivos en la etapa de análisis." | La IA analizó los SQL existentes y el borrador previo en `.kiro/specs/design.md`, que traía `ALTER DEFAULT PRIVILEGES` amplios y la opción de `GRANT ALL ON ALL TABLES` a `app_web`. | Se rechazaron las opciones amplias: `GRANT ALL` incluía `TRUNCATE`, `REFERENCES` y `TRIGGER`; la escritura por defecto expondría tablas futuras sin revisar; `EXECUTE` por defecto expondría funciones sin análisis; el `SELECT` por defecto a reportes contradecía su rol limitado a vistas/MV. El diseño final quedó en `sql/roles.sql` y la spec de Kiro. |
| A2 | "Revisá `ALTER DEFAULT PRIVILEGES` en `roles.sql` sin modificar ni ejecutar. Decime qué permisos otorga y si `rol_app_lectura` recibiría `SELECT` automático sobre tablas futuras, con riesgo para `app_web`." | La IA respondió que sí: `rol_app_lectura` recibía `SELECT` sobre tablas futuras, `app_web` lo hereda, y una tabla futura con `email` quedaría legible saltando el permiso por columna. Propuso cambiarlo por `REVOKE`. | Se revisó el archivo y se aceptó la corrección: `sql/roles.sql` §10 pasó a `REVOKE SELECT ON TABLES FROM rol_app_lectura` y mantuvo solo `rol_soporte` y secuencias de `rol_app_escritura`. También se sincronizaron `requirements.md`/`design.md`. |
| A3 | "Completá el TP5 (Partes A–E) inspeccionando estructura, SQL existentes, documentación y estado de Git. No ejecutes SQL, no modifiques PostgreSQL, no inventes resultados y prepará todos los archivos necesarios." | La IA revisó el proyecto y preparó los archivos de las Partes A–E sin ejecutar SQL ni afirmar ejecuciones. | Quedó como base de trabajo; las ejecuciones se hicieron después manualmente y se documentaron en filas posteriores (B4, C2, D1). |
| B1/C1/D1 (componentes de A3) | Dentro del mismo pedido A3, Partes B, C y D. | La IA preparó los archivos de auditoría, simulacro y anonimización como borradores sin ejecutar. | Quedó como antecedente. La ejecución manual de B, C y D se registró en B4, C2 y D1. |
| A4 | "Revisá el cumplimiento del TP5 sin ejecutar SQL, prestando atención a `CREATE ROLE` condicional, herencia, cobertura de B, adaptación de C y tabla `usuario_anon` de D." | Se corrigieron varios puntos: `CREATE ROLE` condicional, bug de `WHERE email` (por `id`), `log_connections='all'` con reload, cambio de vista a tabla con `id_hash` y referencias entre partes. | Se aplicaron las correcciones. Faltaba todavía la ejecución manual, que se hizo en B4, C2 y D1. |
| B2 | "Prepará la Parte B inspeccionando PostgreSQL y el proyecto, activá `log_connections`/`log_disconnections`/`log_statement='mod'`, armá `auditoria_test.sql` con SELECT/INSERT/UPDATE reversible, login fallido y log real sin inventar evidencia." | OpenCode inspeccionó archivos (`logging_collector=on`, defaults, `scram-sha-256`, ruta del log) y dejó preparados `auditoria_test.sql`, informe y log. No se ejecutó nada porque faltaba la contraseña (`fe_sendauth: no password supplied`). | Se aceptó dejar B como pendiente de ejecución manual. Se cambió `log_statement` de `'all'` a `'mod'` y se hizo el `UPDATE` reproducible por `lastval()`. El `FATAL` por timeout no se presentó como login fallido. |
| B3 | "Evaluá si `log_statement='mod'` alcanza para demostrar conexión, login fallido, SELECT, INSERT, UPDATE y usuario/base/fecha. Si no alcanza, corregí la estrategia mínima sin afirmar ejecución." | La IA concluyó que con `'mod'` el `SELECT` no se registra y que haría falta `'all'` temporal. | Se adoptó `'all'` solo durante la ventana de prueba y con vuelta a `'none'`. B2 pasó a quedar como histórico y B3 quedó como la estrategia final. |
| B4 | "Completá la evidencia real de B con el log 13:52:25–13:53:01, sin ejecutar SQL adicional ni inventar líneas, separando log previo, preparación y prueba." | Se revisó el log real y quedó: conexión `postgres` 13:52:25, 5 `SELECT`, `INSERT` con `ROLLBACK`, `INSERT`+`UPDATE` con `ROLLBACK`, desconexión y login fallido `rol_inexistente_parteB` 13:52:50 (segundo marcó a las 13:53:01). | Se dejó claro que la prueba se hizo con `postgres` y no con `app_web`, por eso sirve para auditoría de conexiones pero no prueba permisos de la Parte A. El `FATAL` de las 12:22:45 por timeout quedó separado del login controlado. Quedó pendiente revertir `log_statement` a `'none'`. |
| C1 | "Prepará la Parte C sin ejecutar SQL ni conectar a PostgreSQL, adaptando a `cliente` (sin `usuario`/`fn_autenticar`), con etapas de autenticación, lectura, escalación, registro, contención y reconstrucción, y dejala preparada." | OpenCode revisó los archivos y dejó preparados SQL, log anonimizado e informe con etapas A–E y recreación de logging temporal. Después se corrigió el conteo a `count(id)` en `cliente`, se pasó a autocommit sin envolver todo en una transacción, se dejó escalación con mensajes reales sin asumir texto, se documentó la dependencia de contraseña y se aclaró que el conteo no prueba extracción. | Se mantuvo lo preparado como antecedente. La ejecución real se registra en C2. |
| C2 | "Ejecutá autónomamente la Parte C: inspeccioná, resolvé la contraseña de `app_web` sin guardar credenciales, activá logging temporal, ejecutá A–E, recuperá evidencias, completá el informe y restaurá todo." | El primer intento autónomo no pudo ejecutarse por falta de contraseña (`fe_sendauth: no password supplied`). Después se ejecutó manualmente en la ventana 14:30–14:37. | Lo que quedó registrado fue: 5 FATAL (3 deliberados y 2 adicionales, no 5 ataques), conexión `app_web` 14:33:44, `count(id)` 20005, `count(*)` 200006, `email` y `v_pedidos_cliente` rechazados, 4 escalaciones rechazadas, verificación `rolsuper=false`, `rolcreaterole=false`, `rolcanlogin=true`, logging revertido y nueva contraseña con `\password` después de notar hashes en el log. Se aclaró que los conteos solo muestran cantidades y no permiten afirmar que se hayan extraído datos. Reconstrucción con OpenCode pendiente. |
| D1 | "Prepará la Parte D sin ejecutar SQL: auditoria de anonimización con `usuario_anon` derivada de `cliente`, sin copiar datos reales, sin sal en el repo, con evidencia de equivalencia sin ejecutar todavía." | OpenCode auditó el diseño, detectó `count(*)` como contador de líneas, corrigió a `count(DISTINCT p.id)`, mantuvo `JOIN` internos con alcance explícito y dejó validaciones solo con conteos. | Quedó preparado. Después se ejecutó manualmente con copia local: `INSERT 0 20005`, 18 grupos en ambas consultas, `EXCEPT` 0 en ambos sentidos, conteos 20005/20005, `duplicados=0`, fuera de lista `0/0`, `.test` `0` y formato `0`. Copia local eliminada y `sql/usuario_anon.sql` conservado con `<SALTO_SECRETO>`. |

## Errores y sugerencias inseguras detectadas

### SELECT general sobre `cliente` para `rol_app_escritura`

- **Dónde apareció:** `docs/kiro_roles_spec/design.md` §4.2 y `requirements.md` §3.1 de una versión anterior.
- **Por qué era inseguro:** un `SELECT` a nivel tabla daba lectura de todas las columnas, incluido `email`, en lectura masiva por `app_web`, contradiciendo el permiso por columna (solo `id`, `nombre`, `apellido`).
- **Qué se hizo:** se cambió a `INSERT, UPDATE` sin `SELECT`. El `email` solo se escribe en alta/modificación.

### SELECT sobre `v_pedidos_cliente` para `rol_reportes`

- **Dónde apareció:** `docs/kiro_roles_spec/design.md` §7 de una versión anterior.
- **Por qué era inseguro:** `v_pedidos_cliente` expone `cliente.email` y `rol_reportes` lo leería sin necesidad.
- **Qué se hizo:** se dejó `rol_reportes` solo con `v_productos_activos`, `v_detalle_pedido_producto` y `mv_ventas_mensuales_forma_pago`.

### ALTER DEFAULT PRIVILEGES con SELECT automático para `rol_app_lectura`

- **Dónde apareció:** `sql/roles.sql` §10 y `design.md` §8 de una versión anterior.
- **Por qué era inseguro:** toda tabla futura creada por `postgres` con datos sensibles quedaba legible por `app_web` sin ningún `GRANT` adicional.
- **Qué se hizo:** se reemplazó por `REVOKE SELECT ON TABLES FROM rol_app_lectura`. Las tablas futuras se otorgan con `GRANT` explícito tras revisar sus columnas.

### Otras correcciones hechas en la revisión

- Se eliminó el marcador `CAMBIAR_ANTES_DE_EJECUTAR` y se pasó a `CREATE ROLE` condicional.
- `REVOKE ALL ON DATABASE` se corrigió a `REVOKE CONNECT`.
- `GRANT EXECUTE` sobre `sp_desactivar_producto` se dejó condicionado y comentado, porque ese procedimiento no existe en la base de trabajo.
- Se fijaron base y versión (`foodstore_tp3_prueba`, PostgreSQL 18.6).
- Se agregó la nota sobre el `SELECT` por defecto de `rol_app_lectura` que luego pasó a `REVOKE`.

## Error de IA más significativo

Fue el `ALTER DEFAULT PRIVILEGES` de `rol_app_lectura`. El problema no era visible en las consultas actuales sino hacia el futuro: cualquier tabla nueva de `postgres` nacía legible por `app_web`, con el riesgo de exponer columnas como `email`, `token` o `password_hash` sin que nadie lo notara. PostgreSQL no admite `DEFAULT PRIVILEGES` por columna, por eso la única salida segura era no otorgar lectura futura y hacerlo por `GRANT` explícito. Se detectó comparando la sección de `ALTER DEFAULT PRIVILEGES` con el permiso por columna de `cliente` y la exclusión de `v_pedidos_cliente` (fila A2) y se corrigió en `sql/roles.sql`, la spec de Kiro y la bitácora.

## Interacciones con Kiro y otras IA

La carpeta `docs/kiro_roles_spec/` contiene la especificación de la Parte A preparada para usarse en Kiro. No se documenta ninguna sesión de Kiro como evidencia de ejecución. Las interacciones de la tabla corresponden a revisiones documentadas de la Parte A y a la sesión de trabajo actual.

## Estado de Git

El directorio de trabajo no es un repositorio Git. No se hizo `push` ni se inicializó nada porque la consigna exigía condiciones seguras y no se cumplían. Cuando se inicialice, conviene un commit inicial con solo los archivos de entrega (sin respaldos de 21 MB) y después un commit por parte (`tp5-A`, `tp5-B`, `tp5-C`, `tp5-D`, `tp5-E`).
