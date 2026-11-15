# Spec Delta

## Purpose

Define el contenedor persistente de EcoSoft, la navegación inferior entre sus tres secciones y el contenido de acceso rápido de la pantalla de inicio.

## ADDED Requirements

### Requirement: Acceso a las tres secciones principales

La aplicación SHALL iniciar en la sección Inicio y SHALL ofrecer una barra de navegación inferior con las secciones Inicio, Escanear e Historial.

#### Scenario: Arranque en Inicio

- **WHEN** la aplicación termina de arrancar
- **THEN** se muestra la sección Inicio y su destino aparece seleccionado en la barra inferior

#### Scenario: Cambio a Escanear

- **WHEN** el usuario selecciona Escanear en la barra inferior
- **THEN** se muestra la sección de escaneo y ese destino queda seleccionado

#### Scenario: Cambio a Historial

- **WHEN** el usuario selecciona Historial en la barra inferior
- **THEN** se muestra la sección de historial y ese destino queda seleccionado

### Requirement: Conservación del estado entre secciones

Al cambiar de sección y volver, la aplicación SHALL conservar el estado ya construido de las secciones, incluida la imagen seleccionada y el resultado de clasificación visibles en Escanear.

#### Scenario: Volver a Escanear después de visitar Historial

- **WHEN** el usuario tiene una imagen y un resultado en Escanear, abre Historial y regresa a Escanear
- **THEN** la imagen y el resultado anteriores siguen visibles sin volver a seleccionarlos

### Requirement: Inicio resume el estado y da acceso directo

La sección Inicio SHALL presentar el número de registros guardados, accesos directos a Escanear y a Historial, y un consejo ecológico.

#### Scenario: Contador de registros

- **WHEN** el historial contiene registros guardados
- **THEN** Inicio muestra la cantidad actual de registros

#### Scenario: Acceso directo a Escanear

- **WHEN** el usuario toca la tarjeta "Escanear un residuo"
- **THEN** la aplicación cambia a la sección Escanear

#### Scenario: Acceso directo a Historial

- **WHEN** el usuario toca la tarjeta "Mi historial"
- **THEN** la aplicación cambia a la sección Historial

### Requirement: Identidad visible de la aplicación

La aplicación SHALL mostrar el nombre EcoSoft en la barra superior y SHALL usar una interfaz con acento verde.

#### Scenario: Barra superior

- **WHEN** el usuario abre cualquiera de las tres secciones principales
- **THEN** la barra superior muestra el nombre EcoSoft con el icono ecológico
