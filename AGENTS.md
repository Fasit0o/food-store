# AGENTS.md

Academic PostgreSQL project (TP-1, "Base de Datos II") modeling the data layer of FoodStore: customers, categories, products, orders, and order lines. All work is SQL only — there is no application code.

## Key files

- `foodstore.session.sql` — the full DDL (schema, constraints, indexes) for PostgreSQL. This is a VSCode SQLTools **session** file: run its statements through the SQLTools connection; it is not a standalone executable script.
- `datos.sql` — currently empty (0 bytes); intended for seed/INSERT data.
- `.vscode/settings.json` — SQLTools connection `foodstore` → `localhost:5432`, database `foodstore`, user `postgres`. Password is prompted (`askForPassword: true`); do not hardcode credentials.
- `.kiro/steering/product.md` — domain model reference (entities + `forma_pago_enum` values).

## Conventions to follow

- Comments, identifiers, and docs are written in Spanish (English is only used in `.kiro`). Keep new SQL comments in Spanish.
- Naming: lowercase `snake_case`; PKs as `BIGINT GENERATED ALWAYS AS IDENTITY`; money as `NUMERIC(10,2)`.
- Constraint prefixes: `pk_`, `uq_`, `fk_`, `ck_`; indexes prefixed `idx_`.
- Foreign keys use `ON DELETE RESTRICT`. Enums via `CREATE TYPE ... AS ENUM`.
- DDL ordering matters: `cliente` and `categoria` must be created before `producto`, `pedido`, and `detalle_pedido`.

## Repo state

- Git repo is initialized with **no commits**; all files are untracked. Only commit when explicitly asked.