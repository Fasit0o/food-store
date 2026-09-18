# Food Store — Base de Datos II — TP5

## Descripción

Trabajo Práctico de la Unidad 3 — Semana 5 de Base de Datos II.

El trabajo analiza índices, vistas y vistas materializadas sobre el proyecto Food Store utilizando PostgreSQL 16+.

## Contenido

- `indices.sql`: decisiones y objetos de indexado de la Parte A.
- `views.sql`: vistas de la Parte B.
- `materializada.sql`: vista materializada e índice único de la Parte C.
- `specs/`: especificaciones utilizadas para Kiro.
- `informe_mediciones.md`: mediciones mediante `EXPLAIN ANALYZE`, verificaciones y resultados.
- `DUIATP5.md`: bitácora del uso de IA durante el TP5.
- `queries.sql`: consultas utilizadas como carga de trabajo.
- `data.sql`: datos utilizados para las pruebas.

## Base de datos

Motor utilizado:

- PostgreSQL 16+

Base utilizada durante las pruebas:

- `foodstore_tp3_prueba`

## Reproducción

1. Crear la base de datos Food Store.
2. Ejecutar el esquema y cargar los datos.
3. Ejecutar las consultas de `queries.sql`.
4. Ejecutar `indices.sql`.
5. Ejecutar `views.sql`.
6. Ejecutar `materializada.sql`.
7. Utilizar las consultas documentadas en `informe_mediciones.md` para reproducir las mediciones.

## Vista materializada

Se creó:

`mv_ventas_mensuales_forma_pago`

La vista materializada contiene el reporte mensual agrupado por forma de pago.

Se creó un índice UNIQUE sobre:

`(mes, forma_pago)`

Este índice permite utilizar:

`REFRESH MATERIALIZED VIEW CONCURRENTLY`

## Flujo de trabajo

El desarrollo siguió el flujo solicitado por la cátedra:

**Kiro → OpenCode → revisión humana → ejecución y verificación → Git**

Las decisiones técnicas fueron tomadas a partir de las mediciones obtenidas mediante PostgreSQL y no únicamente de las propuestas de la IA.