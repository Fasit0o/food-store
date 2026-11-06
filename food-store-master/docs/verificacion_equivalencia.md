# Verificación de equivalencia — Parte D (anonimización)

## TP5 · Base de Datos II · Food Store

> **Estado: EJECUTADO MANUALMENTE — EQUIVALENCIA COMPROBADA.**
> Resultados reales de la ejecución manual de `sql/usuario_anon.sql`
> sobre `foodstore_tp3_prueba` (sin modificar `cliente`). **PARTE D
> DOCUMENTADA — NO MODIFICAR SQL.**
> La equivalencia queda comprobada **únicamente** para el alcance
> definido en §4 y con las métricas de §5.

## 1. Qué contiene `usuario_anon`

Tabla física derivada con solo columnas sintéticas:

- `id_hash` (TEXT, PK): `md5(id || sal || 'id')` completo (32 hex).
- `nombre_anon` / `apellido_anon`: nombres ficticios de listas cerradas.
- `email_anon`: `'cliente_' || md5(id||sal||'email')[1:12] || '@anonimo.test'`.

No contiene `id` real ni nombres/apellidos/emails reales. Es un snapshot:
si `cliente` cambia después de crearla, debe recrearse.

## 2. Cómo se genera `id_hash`

`md5(id::text || '<SALTO_SECRETO>' || 'id')` completo (32 caracteres hex),
sin `substr`. Determinista por `id` + sal secreta. Se usa `md5` (estable entre
versiones; no `hashtext`) — **no es una función criptográfica moderna**.
Para esta práctica funciona solo como identificador derivado determinista;
la seguridad depende de mantener secreta la sal. No se instala `pgcrypto`
(no estaba declarado en el proyecto) ni se agrega dependencia nueva. `id_hash`
no se trunca.

## 3. Cómo se generan los datos sintéticos

Derivación por columna desde `id + sal` (4 hashes con dominios distintos):

- `id_hash`: `md5(id||sal||'id')`.
- `nombre_anon`: lista de 10 ficticios indexada por `md5(id||sal||'nombre')[1:2]`.
- `apellido_anon`: lista de 10 ficticios indexada por `md5(id||sal||'apellido')[1:2]`.
- `email_anon`: `'cliente_' || md5(id||sal||'email')[1:12] || '@anonimo.test'`.

La sal real **nunca** va al repositorio: se reemplaza `<SALTO_SECRETO>` solo
en una copia local/no versionada. Sin sal, `md5` es vulnerable a diccionario;
con sal expuesta existe riesgo de enumeración/reidentificación. No es
anonimización irreversible, sino seudonimización reversible con la sal.

## 4. Alcance de la comparación mensual

`JOIN` internos; no se cambia a `LEFT JOIN`:

- pedidos que tienen al menos un registro en `detalle_pedido`;
- clientes que participan en esos pedidos;
- agrupación por `forma_pago` y `mes` (`date_trunc('month', fecha)`).

No se incluye inventario de clientes sin pedidos. El conteo total de filas
`cliente` vs. `usuario_anon` se verifica por separado (§5).

## 5. Métricas que se comparan

Ambas agregaciones comparan, por `forma_pago` y `mes`:

- `cantidad_pedidos`: `COUNT(DISTINCT p.id)` (pedidos, no líneas).
- `cantidad_clientes`: `COUNT(DISTINCT p.cliente_id)` original vs.
  `COUNT(DISTINCT ua.id_hash)` anonimizado.
- `monto_total`: `SUM(dp.cantidad * dp.precio_unitario)`.

La única diferencia es la tabla de clientes: `cliente` vs. `usuario_anon`
por hash. Las validaciones seguras de §5 del SQL (`count(*)` 1:1, `id_hash`
sin duplicados, nombres ficticios sin copiar reales, emails `.test`, formato
hex) producen solo conteos/indicadores; no imprimen nombres, apellidos ni
emails reales.

## 6. Comparación con `EXCEPT` en ambos sentidos

Si ambas consultas agregadas son equivalentes, ambos `EXCEPT` deben devolver
**0 filas**; si no, cada dirección cuenta sus diferencias. La equivalencia
solo podrá afirmarse después de ejecutar y obtener 0 en ambas direcciones.

## 7. Resultados reales (ejecución manual)

| Prueba | Resultado real |
|---|---|
| `cliente`: 20005 filas | 20005 |
| `usuario_anon`: 20005 filas | 20005 |
| Correspondencia 1:1 | `true` |
| `duplicados_id_hash` | 0 |
| `nombres_fuera_de_lista` | 0 |
| `apellidos_fuera_de_lista` | 0 |
| `emails_no_test` | 0 |
| `hashes_formato_invalido` | 0 |
| Agregación original (§2) | 18 filas |
| Agregación anonimizada (§3) | 18 filas |
| `original_menos_anonimo` | 0 |
| `anonimo_menos_original` | 0 |

Las 18 filas fueron equivalentes; ambos `EXCEPT` devolvieron **0**.
No se ejecutó Python/LANDFS ni SQL adicional en esta tarea documental.

## 8. Qué información personal nunca debe enviarse a una IA sin anonimizar antes

- Nombres, apellidos, emails e ids reales de clientes (o cualquier identificador directo).
- Archivos de log sin anonimizar, contraseñas, hashes de contraseña, tokens,
  claves de API, cadenas de conexión y fragmentos de `pg_hba.conf` con secretos.
- Volcados/`pg_dump` completos o extractos masivos de tablas con datos personales.
- IPs reales de origen, rutas locales con datos y cualquier identificador que permita reidentificar a una persona.
- La sal secreta de anonimización.

**Qué sí puede compartirse:** esquema sin datos, consultas agregadas anonimizadas
(conteos por forma de pago/mes), resultados de `EXCEPT` (conteos de diferencias)
y logs ya anonimizados según `docs/log_simulacro_anonimizado.txt`.

## 9. Aclaraciones (ejecución manual)

- `usuario_anon` es un snapshot derivado de `cliente` (congelado al ejecutar §1).
- Nombres/apellidos son sintéticos de listas cerradas; emails usan `.test`.
- `id_hash` es MD5 con sal secreta.
- Esto se considera seudonimización/datos sintéticos para la práctica, no
  anonimización irreversible (sin sal no hay diccionario; con sal expuesta sí).
- La sal real no debe incluirse en Git ni en la entrega.
- No se deben compartir datos reales (nombres, apellidos, emails, ids).
- Los resultados documentados corresponden a la ejecución manual realizada.

## 10. Limitaciones/riesgos de seudonimización

- `md5` con sal no es anonimización irreversible; con la sal expuesta se puede
  enumerar `id` y reidentificar.
- Nombres ficticios de lista cerrada pueden colisionar: aceptable para agregados
  por forma de pago/mes, no para identificar personas.
- Si `cliente` se modifica tras crear la tabla, la equivalencia deja de valer
  hasta recrearla (snapshot).
- La tabla `usuario_anon` es una copia derivada: protegerla como dato sensible,
  definir retención y eliminarla tras la verificación; no otorgar `SELECT` a
  `app_web` ni a `rol_app_lectura` (reintroduciría el problema de la Parte A).
