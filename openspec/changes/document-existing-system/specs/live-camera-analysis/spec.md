# Spec Delta

## Purpose

Permite abrir la cámara del dispositivo, previsualizar la imagen y clasificar bajo demanda una captura, mostrando el residuo detectado y su confianza sin guardarlo automáticamente.

## ADDED Requirements

### Requirement: Apertura de la cámara en vivo

La aplicación SHALL abrir una pantalla con vista previa de la primera cámara disponible y SHALL mostrar un indicador mientras inicializa la cámara y el modelo. Si la cámara o el modelo no pueden inicializarse, SHALL mostrar un mensaje de error en lugar de la vista previa.

#### Scenario: Apertura correcta

- **WHEN** el usuario pulsa "Cámara en vivo" y el dispositivo tiene una cámara disponible
- **THEN** la aplicación muestra la vista previa y el botón "Analizar imagen"

#### Scenario: Inicialización en curso

- **WHEN** la pantalla de cámara todavía está inicializando la cámara o el modelo
- **THEN** se muestra un indicador de progreso en lugar de la vista previa

#### Scenario: Cámara no disponible

- **WHEN** no existe una cámara o la inicialización falla
- **THEN** la aplicación muestra el texto de error de apertura y no habilita el análisis

### Requirement: Análisis de una captura bajo demanda

La aplicación SHALL capturar una imagen fija y clasificarla únicamente cuando el usuario pulsa "Analizar imagen". El resultado SHALL mostrar la categoría en español y la confianza con un decimal.

#### Scenario: Primera captura

- **WHEN** el usuario pulsa "Analizar imagen" con la vista previa activa
- **THEN** la aplicación captura una imagen, la clasifica y muestra la categoría y el porcentaje de confianza

#### Scenario: Captura repetida

- **WHEN** el usuario vuelve a pulsar "Analizar imagen" después de un resultado
- **THEN** la aplicación captura una nueva imagen y reemplaza el resultado anterior

#### Scenario: Análisis en curso

- **WHEN** hay una captura o clasificación en curso
- **THEN** el botón muestra "Analizando..." y no acepta una segunda ejecución

#### Scenario: Fallo de captura o clasificación

- **WHEN** la captura o la clasificación producen un error
- **THEN** la pantalla permanece abierta, conserva el último resultado visible y reactiva el botón

### Requirement: Liberación de la cámara al salir

La aplicación SHALL liberar el control de la cámara cuando el usuario abandona la pantalla de cámara en vivo.

#### Scenario: Regreso a Escanear

- **WHEN** el usuario vuelve desde la cámara en vivo a la sección Escanear
- **THEN** la cámara se libera y una nueva apertura puede inicializar la vista previa otra vez

### Requirement: Resultados sin guardado automático

El resultado obtenido en la cámara en vivo SHALL mostrarse en pantalla, pero no SHALL añadirse automáticamente al historial.

#### Scenario: Resultado no persistido

- **WHEN** el usuario analiza una captura en vivo y después abre Historial
- **THEN** el historial no contiene un registro nuevo por ese análisis
