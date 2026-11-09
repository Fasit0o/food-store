# TP8 — Tasks (Kiro)

Food Store · Base de Datos II · Unidad 8.
Estado de cada tarea: [x] hecho (generado/verificado), [ ] pendiente
de ejecución manual. El orden detallado está en `README.md`.

## Base SQLite
- [x] T1. Crear `movil/schema_sqlite.sql`: `PRAGMA foreign_keys = ON;`
      + 4 tablas STRICT (`producto_cache`, `pedido_borrador`,
      `item_borrador`, `cola_sync`) con PK/FK/CHECK.
- [x] T2. Crear `movil/pruebas_sqlite.sql`: COMMIT, ROLLBACK,
      C1 (catálogo offline), C7 (cantidad 0 y producto inexistente).
- [x] T3. Crear `movil/semaforo.sql`: clasifica solo PENDIENTE
      (ROJO/AMARILLO/VERDE) contra `snapshot_servidor`, idempotente.
- [x] T4. Verificar en SQLite (Python sqlite3 3.50.4): schema,
      pruebas, semáforo y lógica C2–C6 con instantánea simulada.

## Snapshot PostgreSQL → SQLite
- [x] T5. Inspeccionar esquema real de `producto` (desde el respaldo
      `backups/foodstore_20261107_103401.dump`, sin tocar bases vivas).
- [x] T6. Crear `sql/tp8_snapshot.sql`: guardia de base de prueba,
      vista `v_snapshot_movil` (precio numeric → centavos,
      `activo` → disponible/eliminado) y `\copy` a CSV.
- [x] T7. Crear `movil/cargar_snapshot.sql` (staging
      `snapshot_servidor` + carga/upsert de `producto_cache`)
      y `movil/foodstore_movil.db` (esquema vacío).
- [ ] T8. (MANUAL) Crear `foodstore_tp8_prueba` como copia de
      `foodstore` y ejecutar `sql/tp8_snapshot.sql` con psql.
- [ ] T9. (MANUAL) Verificar `movil/servidor_snapshot.csv`:
      encabezado, filas > 0, `precio_centavos` coherente con
      `precio * 100`, fecha de copia registrada.
- [ ] T10. (MANUAL) Importar el CSV en SQLite (`DELETE` +
      `.import --skip 1`) y ejecutar `movil/cargar_snapshot.sql`.

## Casos C2–C6
- [x] T11. Crear `movil/casos_c2_c6.sql` (borradores de los 5 casos
      con subconsultas, sin ids fijos) y
      `sql/tp8_casos_c2_c6_postgresql.sql` (mutaciones C2/C4 solo en
      `foodstore_tp8_prueba`, por secciones).
- [ ] T12. (MANUAL) Ejecutar C2–C6 en orden siguiendo README paso 10,
      con los DETENERSE intercalados y `movil/semaforo.sql` tras
      cada bloque. Anotar estados obtenidos.
- [ ] T13. (MANUAL) Verificación final PostgreSQL: conteo de
      `pedido` y suma de `stock` ANTES = DESPUÉS (bloques de
      `sql/tp8_snapshot.sql` y sección final de
      `sql/tp8_casos_c2_c6_postgresql.sql`).

## Documentación
- [x] T14. Escribir `docs/kiro/` (requirements EARS, design, tasks),
      `docs/bitacora_ia.md`, `docs/DUIA.md` (marcador oficial),
      `docs/informe.md` (1.a, 2.c, 3.a, 3.b, 3.c) y `README.md`.
- [ ] T15. (MANUAL) Convertir `docs/informe.md` a `docs/informe.pdf`
      (máx. 6 páginas) con la herramienta de preferencia y pegar la
      DUIA oficial en `docs/DUIA.md`.
