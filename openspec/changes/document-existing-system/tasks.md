# Tasks

## 1. Verificación de las specs base

- [ ] 1.1 Contrastar `specs/app-shell/spec.md` con `lib/main.dart` (shell, `IndexedStack`, navegación, inicio y contador) y corregir cualquier divergencia; verificar que cada escenario sea observable en la app
- [ ] 1.2 Contrastar `specs/waste-classification/spec.md` con `lib/main.dart` y `lib/services/clasificador_residuos.dart` (selección, carga validada, doce etiquetas, confianza, contenedor y recomendación); verificar que no se documente ninguna categoría o acción inexistente
- [ ] 1.3 Contrastar `specs/live-camera-analysis/spec.md` con `lib/camara_en_vivo.dart` (inicialización, captura única, errores, liberación y ausencia de guardado automático); verificar el comportamiento en un dispositivo con cámara
- [ ] 1.4 Contrastar `specs/classification-history/spec.md` con `lib/main.dart` (guardado, clave `historial_ecosoft`, orden, estado vacío y tolerancia a datos corruptos); verificar que el texto describa el formato y el comportamiento reales

## 2. Verificación del diseño y del alcance

- [ ] 2.1 Revisar `design.md` contra `pubspec.yaml`, `pubspec.lock`, `analysis_options.yaml` y los manifiestos de plataforma; corregir versiones, rutas o estados que no coincidan con el repositorio
- [ ] 2.2 Confirmar que `proposal.md` no atribuya funcionalidades no implementadas y que todas las mejoras estén solo en "Fuera de alcance" o en "Trabajo futuro propuesto"; verificar que `tasks.md` no incluya tareas de esas mejoras

## 3. Validación final

- [ ] 3.1 Ejecutar `openspec validate "document-existing-system" --strict` y corregir todos los errores y avisos de estructura, scenarios, Purpose o requisitos sin `SHALL`/`MUST`
- [ ] 3.2 Ejecutar `git diff --stat -- lib pubspec.yaml pubspec.lock assets android ios web linux macos windows` y confirmar que la salida está vacía, es decir, que no se modificó código ni configuración
- [ ] 3.3 Ejecutar `flutter analyze` y confirmar que el único aviso sigue siendo el `unnecessary_import` existente en `lib/services/clasificador_residuos.dart`; si aparece un aviso nuevo, investigar antes de cerrar el cambio

## Workflow follow-up

- Revisar y aprobar la propuesta antes de archivar; este cambio no implementa mejoras ni corrige defectos.
- Archivar con `@opsx-archive` cuando la validación estricta pase.
- Tras archivar, ejecutar `openspec list --specs` y confirmar que aparecen las cuatro capacidades: `app-shell`, `waste-classification`, `live-camera-analysis` y `classification-history`.
