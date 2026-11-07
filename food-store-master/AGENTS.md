# AGENTS.md — Unidad 6 Food Store

## Ordenes permanentes para OpenCode

- No eliminar, borrar, sobrescribir ni recrear bases de datos PostgreSQL.
- No ejecutar `DROP DATABASE`, `dropdb`, `TRUNCATE`, `DELETE` masivo ni comandos destructivos sobre ninguna base.
- No modificar ni eliminar `foodstore_tp3_prueba`. Es basehistorica de trabajos anteriores, no tocar.
- La base principal es `foodstore`. No debe eliminarse ni reemplazarse durante el simulacro de desastre.
- La unica base destinada a restauraciones de prueba es `foodstore_restore_test`. Las pruebas destructivas, si fueran necesarias, solo sobre esa base.
- No restaurar nunca sobre `foodstore`.
- No guardar contrasenas de PostgreSQL en ningun archivo, script, documentacion o repositorio. Usar el mecanismo normal de autenticacion del entorno (prompt interactivo). No hardcodear credenciales ni secretos.
- Respetar PostgreSQL 16 o superior. El entorno actual es PostgreSQL 18.6.
- Revisar antes de ejecutar comandos: verificar a que base apunta cada comando, que no sea `foodstore_tp3_prueba` ni otra base de trabajos anteriores, y evitar cualquier operacion destructiva sobre `foodstore`.
- No inventar resultados, tiempos, evidencias ni conteos. Toda evidencia debe ser salida real de comandos ejecutados.
- No considerar un script terminado hasta haberlo probado. Si `pg_dump`/`pg_restore` falla, registrar el error y salir con codigo distinto de cero.
- No usar `VACUUM FULL` como mantenimiento periodico. Preferir accion segura y justificada por el estado observado.
- La intervencion de OpenCode es subordinada a revision humana.
