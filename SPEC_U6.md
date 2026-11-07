# SPEC_U6 — Mantenimiento, respaldo y recuperación (Food Store)

## Tareas automatizadas

| Tarea | Frecuencia | Evidencia |
|---|---|---|
| Respaldo `foodstore` (`backup_foodstore.ps1`, `pg_dump -Fc`) | Diaria | `backups/foodstore_YYYYMMDD_HHMMSS.dump` + `logs/backup_*.log` |
| Chequeo de salud `foodstore` (`health_check.sql`, solo lectura) | Diaria | `evidencias/evidencia_health_check.txt` |
| Revisión de mantenimiento (`maintenance.sql`) | Semanal | `evidencias/evidencia_maintenance.txt` |
| Restauración de prueba (`restore_test.ps1` -> `foodstore_restore_test`) | Semanal | `evidencias/evidencia_restore.txt` |

Condición de éxito: cada tarea termina con código 0 y log/evidencia correspondiente. Si `pg_dump`/`pg_restore` falla, código != 0 y error en log, sin informar éxito falso.

## Reglas de seguridad

No eliminar/borrar/recrear bases. `foodstore_tp3_prueba` intangible. `foodstore` nunca se elimina, trunca ni restaura encima. Solo `foodstore_restore_test` para restauraciones. Sin contraseñas en archivos/scripts/logs; autenticación normal del entorno. PostgreSQL 16+ (18.6 verificado). Antes de ejecutar, verificar base destino.

## Políticas

- **Backup:** diario `pg_dump -Fc -h localhost -p 5432 -U postgres foodstore` a `backups/` con fecha/hora; crea `backups/` y `logs/` si faltan. Retención mínima 7 días (borrado manual, nunca automático sobre `foodstore`).
- **Monitoreo:** diario `health_check.sql` (tamaño, `pg_stat_database`, `pg_stat_user_tables` ordenado por muertas, `pg_stat_activity` sin `idle`); semanal análisis de muertas/autovacuum.
- **Mantenimiento:** semanal revisión; `VACUUM`/`ANALYZE` solo si el estado observado lo justifica; nunca `VACUUM FULL`.
- **Restauración:** semanal sobre `foodstore_restore_test` con último `.dump`; si existe, reutilización segura (solo esa base); validaciones de conteos e inválidos.

## RPO / RTO

RPO = antigüedad del backup usado (inicio restore − fecha backup). RTO = tiempo desde inicio restore hasta validaciones OK. `RPO ≠ RTO`.

## Verificación manual

Ejecutar manualmente `backup_foodstore.ps1`, `psql -f health_check.sql` y `restore_test.ps1` sobre `foodstore`, revisar logs/evidencias, confirmar conteos coinciden con `foodstore` y `productos_invalidos=0`, `detalles_invalidos=0`.
