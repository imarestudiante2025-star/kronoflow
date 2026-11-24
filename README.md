# TaskFlow Pro

Aplicación Flutter para organizar tareas personales. Las tareas se guardan en
el dispositivo mediante `shared_preferences`; crear, listar, consultar, editar,
eliminar, completar, buscar, filtrar y ordenar tareas no requiere conexión.

## Funcionalidades

- Tareas con categoría, prioridad y fecha límite opcional.
- Búsqueda, filtros, orden, progreso y tema claro/oscuro.
- Detalle, edición, eliminación con opción para deshacer y limpieza de tareas
  completadas.

## Ejecutar y validar

```shell
flutter pub get
flutter run -d chrome
flutter test
flutter build apk --debug
```

## Supabase

La aplicación inicializa Supabase y ofrece una comprobación de lectura de la
tabla `tareas`. La gestión de tareas de la interfaz sigue siendo local: no se
sincronizan registros con Supabase. El inicio de sesión existente tampoco está
conectado a la navegación principal.

La URL y la clave publicable se configuran en
`lib/config/supabase_config.dart` y pueden sobrescribirse con
`--dart-define=SUPABASE_URL=...` y `--dart-define=SUPABASE_KEY=...`. No incluyas
claves secretas o `service_role` en una aplicación cliente. No hay migraciones
ni políticas RLS en este repositorio; verifica la existencia de `tareas` y sus
permisos en Supabase antes de habilitar operaciones remotas.
