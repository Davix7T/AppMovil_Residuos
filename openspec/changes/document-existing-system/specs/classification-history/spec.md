# Spec Delta

## Purpose

Permite guardar una clasificación con su imagen, persistirla localmente entre reinicios y consultar el conjunto de registros en orden cronológico desde la sección Historial.

## ADDED Requirements

### Requirement: Guardado explícito de una clasificación

Tras una clasificación en Escanear, la aplicación SHALL ofrecer guardar el resultado. Al guardarlo, SHALL añadir un registro con imagen, nombre del residuo, contenedor, recomendación y fecha, y SHALL confirmar la acción.

#### Scenario: Guardar un resultado

- **WHEN** el usuario pulsa "Guardar en historial" con una clasificación visible
- **THEN** se añade un registro nuevo, se muestra una confirmación y la aplicación cambia a la sección Historial

#### Scenario: Sin clasificación disponible

- **WHEN** no hay imagen ni resultado de clasificación
- **THEN** la acción de guardar no está disponible

#### Scenario: Guardados sucesivos

- **WHEN** el usuario guarda clasificaciones en momentos distintos
- **THEN** cada guardado crea un registro independiente y el más reciente queda al principio

### Requirement: Persistencia local entre reinicios

Los registros guardados SHALL persistir en el almacenamiento local del dispositivo y SHALL recuperarse al volver a iniciar la aplicación.

#### Scenario: Recuperación después de cerrar la app

- **WHEN** el usuario guarda un registro, cierra la aplicación y la vuelve a abrir
- **THEN** el registro sigue presente con su imagen, nombre, contenedor, fecha y recomendación

#### Scenario: Arranque con historial existente

- **WHEN** la aplicación inicia y existen registros almacenados
- **THEN** la sección Historial se llena con esos registros sin requerir una nueva clasificación

### Requirement: Listado cronológico del historial

La sección Historial SHALL mostrar los registros del último guardado al primero, cada uno con miniatura, nombre del residuo, contenedor, fecha y recomendación.

#### Scenario: Orden de los registros

- **WHEN** existen varios registros guardados
- **THEN** el último guardado aparece primero y los anteriores le siguen en orden inverso al guardado

#### Scenario: Contenido de un registro

- **WHEN** el usuario consulta un registro del historial
- **THEN** se muestran la miniatura, el nombre del residuo, el contenedor, la fecha en formato `d/M/yyyy` y la recomendación

#### Scenario: Historial vacío

- **WHEN** no hay registros guardados
- **THEN** la sección Historial muestra un estado vacío con un mensaje informativo

### Requirement: Tolerancia a datos almacenados inválidos

Si el contenido almacenado no puede interpretarse, la aplicación SHALL continuar operativa y SHALL mostrar el historial vacío o el último estado válido, sin cerrarse.

#### Scenario: Datos corruptos al iniciar

- **WHEN** el contenido local del historial no es JSON válido o no tiene la estructura esperada
- **THEN** la aplicación termina de arrancar, muestra el historial vacío y registra el error sin bloquear la interfaz
