# Spec Delta

## Purpose

Permite obtener una imagen, clasificarla con el modelo local de doce categorías y presentar al usuario el nombre del residuo, su contenedor y una recomendación de manejo.

## ADDED Requirements

### Requirement: Selección de imagen desde cámara o galería

La sección Escanear SHALL permitir elegir una imagen desde la cámara o la galería. Tras elegirla, SHALL mostrar una vista previa y el nombre del archivo. Cancelar el selector SHALL conservar la imagen y el resultado previos.

#### Scenario: Elegir una imagen de la galería

- **WHEN** el usuario abre las opciones de imagen, elige "Elegir de la galería" y selecciona un archivo
- **THEN** la imagen se muestra en la vista previa y aparece el nombre del archivo seleccionado

#### Scenario: Tomar una fotografía

- **WHEN** el usuario abre las opciones de imagen, elige "Tomar fotografía" y confirma la captura
- **THEN** la fotografía se muestra en la vista previa y aparece su nombre de archivo

#### Scenario: Cancelar la selección

- **WHEN** el usuario cierra el selector sin elegir una imagen
- **THEN** la imagen y el resultado anteriores permanecen sin cambios y no se muestra un error

#### Scenario: Fallo al abrir la imagen

- **WHEN** el selector o la lectura del archivo producen un error
- **THEN** la aplicación muestra un mensaje de error y no reemplaza la imagen actual

### Requirement: Carga validada del modelo local

La aplicación SHALL cargar bajo demanda el modelo incluido en la app y SHALL validar que su entrada sea `[1, 224, 224, 3]` y su salida `[1, 12]`. Si las dimensiones no coinciden, SHALL rechazar el modelo y mostrar un error.

#### Scenario: Carga manual correcta

- **WHEN** el usuario pulsa "Probar carga del modelo"
- **THEN** el modelo se carga, se muestra una confirmación y la interfaz indica que el modelo está cargado

#### Scenario: Modelo incompatible

- **WHEN** las dimensiones de entrada o salida no coinciden con las esperadas
- **THEN** la aplicación muestra un error y el modelo no queda disponible para clasificar

#### Scenario: Error de lectura del modelo

- **WHEN** el asset del modelo falta o no puede inicializarse
- **THEN** la aplicación muestra un mensaje de error y sigue operativa

### Requirement: Clasificación en doce categorías

Toda imagen válida SHALL clasificarse en exactamente una de estas categorías: `battery`, `biological`, `brown-glass`, `cardboard`, `clothes`, `green-glass`, `metal`, `paper`, `plastic`, `shoes`, `trash` y `white-glass`.

#### Scenario: Imagen válida

- **WHEN** el usuario pulsa "Analizar residuo" con una imagen disponible
- **THEN** la aplicación muestra la categoría en español y la confianza reportada por el modelo con un decimal

#### Scenario: Carga automática antes de analizar

- **WHEN** el usuario analiza una imagen sin haber cargado el modelo manualmente
- **THEN** la aplicación carga el modelo antes de clasificar y continúa con el análisis

#### Scenario: Imagen ilegible

- **WHEN** los bytes de la imagen no pueden decodificarse
- **THEN** la aplicación muestra un mensaje de error y no presenta un resultado de clasificación

### Requirement: Presentación de contenedor y recomendación

Para cada resultado, la aplicación SHALL mostrar un contenedor y una recomendación correspondientes a la categoría detectada.

#### Scenario: Baterías

- **WHEN** la categoría detectada es `battery`
- **THEN** el contenedor es "Recolección especial" y la recomendación indica llevar la batería a un punto de recolección especializado

#### Scenario: Residuos orgánicos

- **WHEN** la categoría detectada es `biological`
- **THEN** el contenedor es "Residuos orgánicos" y la recomendación menciona el compostaje o la separación de restos orgánicos

#### Scenario: Materiales aprovechables

- **WHEN** la categoría detectada es `brown-glass`, `green-glass`, `white-glass`, `cardboard`, `metal`, `paper` o `plastic`
- **THEN** el contenedor es "Material aprovechable" y la recomendación es específica para ese material

#### Scenario: Textiles y calzado

- **WHEN** la categoría detectada es `clothes` o `shoes`
- **THEN** el contenedor es "Reutilización o recolección textil" y la recomendación sugiere reutilizar, donar o buscar un punto de recolección textil

#### Scenario: Residuos no aprovechables

- **WHEN** la categoría detectada es `trash`
- **THEN** el contenedor es "Residuos no aprovechables" y la recomendación remite a las opciones locales de disposición

### Requirement: Estado de carga durante el análisis

La aplicación SHALL impedir análisis simultáneos mientras una clasificación está en curso y SHALL reactivar la acción al terminar, tanto con éxito como con error.

#### Scenario: Análisis en curso

- **WHEN** el usuario inicia un análisis
- **THEN** el botón muestra el estado "Analizando..." y no acepta una segunda ejecución hasta finalizar

#### Scenario: Análisis fallido

- **WHEN** la clasificación termina con error
- **THEN** la aplicación muestra el mensaje de error, reactiva el botón y permite intentarlo de nuevo
