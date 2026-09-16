# Protocolo de Seguridad - TP2 FoodStore

## 1. COPIA

El trabajo práctico se realizará sobre la base de datos de prueba `foodstore_tp2`, creada como copia de trabajo de la base original `foodstore` en PostgreSQL.

Las pruebas de reglas de negocio, transacciones y concurrencia se realizarán únicamente sobre `foodstore_tp2`.

La base original `foodstore` no será utilizada para ejecutar modificaciones durante las pruebas.

Para trabajar con una copia de la base se utiliza PostgreSQL y, cuando sea necesario crear nuevamente la copia, se puede utilizar:

```powershell
createdb -U postgres -T foodstore foodstore_tp2
```

## 2. TRANSACCIÓN

Toda operación que modifique datos o estructura de la base de datos se probará inicialmente dentro de una transacción.

El procedimiento utilizado será:

```sql
BEGIN;

-- operación a probar

ROLLBACK;
```

Después de revisar el resultado y comprobar que la operación funciona correctamente, se podrá repetir utilizando `COMMIT` cuando corresponda.

Las pruebas de concurrencia se realizarán utilizando dos sesiones independientes conectadas a `foodstore_tp2`.

## 3. RESPALDO

Antes de realizar modificaciones estructurales sobre la base de datos se realizará un respaldo mediante `pg_dump`.

El respaldo utilizado durante este trabajo se encuentra en:

```text
C:\Users\ServSPSanMartin\foodstore_backup.sql
```

El comando utilizado para generar el respaldo es:

```powershell
pg_dump -U postgres -d foodstore_tp2 -f C:\Users\ServSPSanMartin\foodstore_backup.sql
```

El respaldo permitirá recuperar el estado de la base de datos en caso de producirse un error durante una modificación estructural.

## 4. VERIFICACIÓN

Todo código SQL generado con herramientas de IA será revisado antes de ejecutarse.

Las operaciones se probarán primero sobre `foodstore_tp2` y se verificará su resultado mediante consultas SQL antes de confirmar los cambios.

Cuando una operación pueda afectar datos existentes, se utilizará primero `ROLLBACK` para comprobar su comportamiento sin conservar el cambio.

## 5. CONTROL DE VERSIONES

Los archivos del trabajo práctico se encuentran dentro de un repositorio Git.

Antes de confirmar una etapa se verificará el estado del repositorio mediante:

```powershell
git status
```

Los cambios correspondientes a cada etapa se registrarán mediante commits descriptivos.

El repositorio permite identificar qué archivos fueron modificados y conservar el historial de los cambios realizados durante el trabajo práctico.

## 6. ENTORNO DE TRABAJO

El motor de base de datos utilizado es PostgreSQL 18.

El trabajo se desarrolla en Windows utilizando PowerShell, PostgreSQL, Git y las herramientas de asistencia OpenCode y Kiro.

La base utilizada para las pruebas es:

```text
foodstore_tp2
```

y el usuario de PostgreSQL utilizado es:

```text
postgres
```

El objetivo de estas medidas es evitar modificaciones accidentales sobre la base original, poder recuperar el estado anterior mediante un respaldo y mantener un registro de los cambios realizados durante el desarrollo del TP2.
