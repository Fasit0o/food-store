# Protocolo de Seguridad - TP2 FoodStore

## 1. COPIA

Todos los cambios y pruebas se realizarán sobre una copia de trabajo de la base de datos del proyecto FoodStore.

La base original no será utilizada para realizar pruebas de modificaciones, restricciones, transacciones o concurrencia.

## 2. TRANSACCIÓN

Toda operación que modifique datos o estructura de la base de datos se probará inicialmente dentro de una transacción.

El procedimiento será:

BEGIN;

-- operación a probar

ROLLBACK;

Luego de verificar que la operación funciona correctamente y que los resultados son los esperados, se podrá ejecutar nuevamente utilizando COMMIT.

## 3. RESPALDO

Antes de realizar modificaciones estructurales sobre la base de datos, se realizará un respaldo mediante pg_dump.

El respaldo permitirá recuperar el estado anterior en caso de producirse un error durante las pruebas o modificaciones.

## 4. VERIFICACIÓN

Todo código SQL generado con herramientas de IA será revisado línea por línea antes de ejecutarse.

Las operaciones se probarán primero sobre la copia de trabajo y se verificará su resultado antes de confirmar cualquier cambio.

## 5. CONTROL DE VERSIONES

Los cambios realizados en archivos del proyecto serán registrados mediante Git.

Antes de avanzar a una nueva etapa se verificará el estado del repositorio y se realizará un commit descriptivo cuando corresponda.