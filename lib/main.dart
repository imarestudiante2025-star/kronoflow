import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart' show PostgrestException;

import 'auth/auth_gate.dart';
import 'auth/login_page.dart';
import 'models/tarea.dart';
import 'services/auth_service.dart';
import 'services/supabase_service.dart';

// ─────────────────────────── ARRANQUE ───────────────────────────

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await _arrancar();
}

/// Inicializa Supabase y lanza la app. Si falla, muestra una pantalla
/// con botón de reintento (útil cuando no hay internet al abrir la app).
Future<void> _arrancar() async {
  try {
    await SupabaseService.inicializar();
    runApp(const TaskFlowApp());
  } catch (e) {
    debugPrint('Error al inicializar Supabase: $e');
    runApp(_ErrorInicio(mensaje: e.toString(), onReintentar: _arrancar));
  }
}

class _ErrorInicio extends StatelessWidget {
  final String mensaje;
  final Future<void> Function() onReintentar;

  const _ErrorInicio({required this.mensaje, required this.onReintentar});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      home: Scaffold(
        body: Center(
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Icon(Icons.cloud_off_outlined, size: 64, color: Colors.red),
                const SizedBox(height: 16),
                const Text(
                  'No se pudo iniciar TaskFlow Pro',
                  style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 8),
                Text(
                  mensaje,
                  textAlign: TextAlign.center,
                  style: const TextStyle(color: Colors.grey),
                ),
                const SizedBox(height: 24),
                FilledButton.icon(
                  onPressed: onReintentar,
                  icon: const Icon(Icons.refresh),
                  label: const Text('Reintentar'),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

// ─────────────────────────── APLICACIÓN PRINCIPAL ───────────────────────────

class TaskFlowApp extends StatefulWidget {
  const TaskFlowApp({super.key});

  @override
  State<TaskFlowApp> createState() => _TaskFlowAppState();
}

class _TaskFlowAppState extends State<TaskFlowApp> {
  static const _claveTema = 'taskflow_tema'; // 'light' | 'dark' | (nada = sistema)
  ThemeMode _themeMode = ThemeMode.system;

  @override
  void initState() {
    super.initState();
    _cargarTema();
  }

  bool get _esOscuroEfectivo {
    if (_themeMode == ThemeMode.system) {
      return WidgetsBinding.instance.platformDispatcher.platformBrightness ==
          Brightness.dark;
    }
    return _themeMode == ThemeMode.dark;
  }

  Future<void> _cargarTema() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final guardado = prefs.getString(_claveTema);
      final modo = switch (guardado) {
        'dark' => ThemeMode.dark,
        'light' => ThemeMode.light,
        _ => ThemeMode.system,
      };
      if (mounted) setState(() => _themeMode = modo);
    } catch (e) {
      debugPrint('Error al cargar el tema: $e');
    }
  }

  Future<void> _cambiarTema() async {
    final nuevo = _esOscuroEfectivo ? ThemeMode.light : ThemeMode.dark;
    setState(() => _themeMode = nuevo);
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(_claveTema, nuevo == ThemeMode.dark ? 'dark' : 'light');
    } catch (e) {
      debugPrint('Error al guardar el tema: $e');
    }
  }

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      title: 'TaskFlow Pro',
      themeMode: _themeMode,
      theme: ThemeData(
        useMaterial3: true,
        colorScheme: ColorScheme.fromSeed(seedColor: const Color(0xFF6558E8)),
      ),
      darkTheme: ThemeData(
        useMaterial3: true,
        brightness: Brightness.dark,
        colorScheme: ColorScheme.fromSeed(
          seedColor: const Color(0xFF9388FF),
          brightness: Brightness.dark,
        ),
      ),
      // AuthGate decide entre Login y la app principal según la sesión.
      home: AuthGate(
        autenticado: (_) => TaskHomePage(cambiarTema: _cambiarTema),
        noAutenticado: (_) => LoginPage(),
      ),
    );
  }
}

// ─────────────────────────── PANTALLA PRINCIPAL ───────────────────────────

enum _Filtro { todas, pendientes, completadas }

class TaskHomePage extends StatefulWidget {
  final VoidCallback cambiarTema;

  const TaskHomePage({super.key, required this.cambiarTema});

  @override
  State<TaskHomePage> createState() => _TaskHomePageState();
}

class _TaskHomePageState extends State<TaskHomePage> {
  final _authService = AuthService();

  List<Tarea> _tareas = [];
  bool _cargando = true;
  String? _error;
  _Filtro _filtro = _Filtro.todas;

  @override
  void initState() {
    super.initState();
    _cargar();
  }

  // ── Utilidades ──

  String _textoError(Object e) {
    if (e is PostgrestException) return e.message;
    return 'Revisa tu conexión e inténtalo de nuevo';
  }

  void _mostrarMensaje(String texto, {SnackBarAction? accion}) {
    if (!mounted) return;
    final messenger = ScaffoldMessenger.of(context);
    messenger.hideCurrentSnackBar();
    messenger.showSnackBar(SnackBar(content: Text(texto), action: accion));
  }

  List<Tarea> get _visibles => switch (_filtro) {
        _Filtro.todas => _tareas,
        _Filtro.pendientes => _tareas.where((t) => !t.completada).toList(),
        _Filtro.completadas => _tareas.where((t) => t.completada).toList(),
      };

  // ── Operaciones con Supabase (protegidas por RLS en 'tareas') ──

  /// [conSpinner] = false se usa en pull-to-refresh y recargas silenciosas.
  Future<void> _cargar({bool conSpinner = true}) async {
    final userId = _authService.usuarioActual?.id;
    if (userId == null) {
      if (mounted) setState(() => _cargando = false);
      return;
    }

    if (conSpinner) setState(() => _cargando = true);

    try {
      final response = await SupabaseService.cliente
          .from('tareas')
          .select()
          .eq('user_id', userId)
          .order('created_at', ascending: false);

      final lista = (response as List)
          .map((item) => Tarea.fromJson(item as Map<String, dynamic>))
          .toList();

      if (!mounted) return;
      setState(() {
        _tareas = lista;
        _cargando = false;
        _error = null;
      });
    } catch (e) {
      debugPrint('Error al obtener tareas: $e');
      if (!mounted) return;
      setState(() {
        _cargando = false;
        // Si ya había datos en pantalla, los conservamos y solo avisamos.
        if (_tareas.isEmpty) _error = _textoError(e);
      });
      if (_tareas.isNotEmpty) _mostrarMensaje('No se pudo sincronizar');
    }
  }

  Future<void> _crearTarea() async {
    final user = _authService.usuarioActual;
    if (user == null) return;

    final datos = await _abrirFormulario();
    if (datos == null) return;

    try {
      // .select().single() devuelve la fila creada: no hace falta recargar todo.
      final fila = await SupabaseService.cliente
          .from('tareas')
          .insert({
            'user_id': user.id,
            'titulo': datos.titulo,
            'descripcion': datos.descripcion,
            'completada': false,
          })
          .select()
          .single();

      if (!mounted) return;
      setState(() {
        _tareas.insert(0, Tarea.fromJson(fila));
        _error = null;
      });
      _mostrarMensaje('Tarea creada');
    } catch (e) {
      debugPrint('Error al insertar tarea: $e');
      _mostrarMensaje('No se pudo crear la tarea: ${_textoError(e)}');
    }
  }

  Future<void> _editarTarea(Tarea tarea) async {
    final datos = await _abrirFormulario(tarea: tarea);
    if (datos == null) return;

    try {
      final fila = await SupabaseService.cliente
          .from('tareas')
          .update({'titulo': datos.titulo, 'descripcion': datos.descripcion})
          .eq('id', tarea.id)
          .select()
          .single();

      if (!mounted) return;
      final i = _tareas.indexWhere((t) => t.id == tarea.id);
      if (i != -1) setState(() => _tareas[i] = Tarea.fromJson(fila));
      _mostrarMensaje('Tarea actualizada');
    } catch (e) {
      debugPrint('Error al editar tarea: $e');
      _mostrarMensaje('No se pudo editar la tarea: ${_textoError(e)}');
    }
  }

  /// Actualización optimista: la UI cambia al instante y se revierte si falla.
  Future<void> _cambiarEstado(Tarea tarea, bool completada) async {
    final anterior = tarea.completada;
    setState(() => tarea.completada = completada);

    try {
      await SupabaseService.cliente
          .from('tareas')
          .update({'completada': completada}).eq('id', tarea.id);
    } catch (e) {
      debugPrint('Error al actualizar estado: $e');
      if (!mounted) return;
      setState(() => tarea.completada = anterior);
      _mostrarMensaje('No se pudo actualizar la tarea');
    }
  }

  /// Elimina con opción de deshacer (vuelve a insertar la misma fila).
  Future<void> _eliminarTarea(Tarea tarea) async {
    final user = _authService.usuarioActual;
    final indice = _tareas.indexWhere((t) => t.id == tarea.id);
    if (user == null || indice == -1) return;

    setState(() => _tareas.removeAt(indice));

    try {
      await SupabaseService.cliente.from('tareas').delete().eq('id', tarea.id);

      _mostrarMensaje(
        'Tarea eliminada',
        accion: SnackBarAction(
          label: 'Deshacer',
          onPressed: () => _restaurarTarea(tarea, user.id),
        ),
      );
    } catch (e) {
      debugPrint('Error al eliminar tarea: $e');
      if (!mounted) return;
      setState(() => _tareas.insert(indice.clamp(0, _tareas.length), tarea));
      _mostrarMensaje('No se pudo eliminar la tarea');
    }
  }

  Future<void> _restaurarTarea(Tarea tarea, String userId) async {
    try {
      await SupabaseService.cliente.from('tareas').insert({
        'id': tarea.id,
        'user_id': userId,
        'titulo': tarea.titulo,
        'descripcion': tarea.descripcion,
        'completada': tarea.completada,
      });
      await _cargar(conSpinner: false);
    } catch (e) {
      debugPrint('Error al restaurar tarea: $e');
      _mostrarMensaje('No se pudo restaurar la tarea');
    }
  }

  Future<void> _cerrarSesion() async {
    final confirmar = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Cerrar sesión'),
        content: const Text('¿Seguro que quieres salir de tu cuenta?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Cancelar'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Salir'),
          ),
        ],
      ),
    );
    if (confirmar != true) return;

    try {
      await _authService.cerrarSesion();
    } catch (e) {
      _mostrarMensaje('Error al cerrar sesión: ${_textoError(e)}');
    }
  }

  // ── Formulario (crear / editar) ──

  Future<_DatosTarea?> _abrirFormulario({Tarea? tarea}) {
    return showModalBottomSheet<_DatosTarea>(
      context: context,
      isScrollControlled: true,
      showDragHandle: true,
      builder: (_) => _FormularioTarea(tarea: tarea),
    );
  }

  // ── Interfaz ──

  @override
  Widget build(BuildContext context) {
    final emailUsuario = _authService.usuarioActual?.email ?? 'Usuario';
    final esOscuro = Theme.of(context).brightness == Brightness.dark;

    return Scaffold(
      appBar: AppBar(
        title: const Text('TaskFlow Pro', style: TextStyle(fontWeight: FontWeight.bold)),
        actions: [
          IconButton(
            tooltip: 'Cambiar tema',
            onPressed: widget.cambiarTema,
            icon: Icon(esOscuro ? Icons.light_mode : Icons.dark_mode),
          ),
          IconButton(
            tooltip: 'Cerrar sesión',
            onPressed: _cerrarSesion,
            icon: const Icon(Icons.logout),
          ),
        ],
      ),
      body: Column(
        children: [
          _CabeceraUsuario(
            email: emailUsuario,
            total: _tareas.length,
            completadas: _tareas.where((t) => t.completada).length,
            onActualizar: _cargar,
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
            child: SegmentedButton<_Filtro>(
              showSelectedIcon: false,
              segments: const [
                ButtonSegment(value: _Filtro.todas, label: Text('Todas')),
                ButtonSegment(value: _Filtro.pendientes, label: Text('Pendientes')),
                ButtonSegment(value: _Filtro.completadas, label: Text('Hechas')),
              ],
              selected: {_filtro},
              onSelectionChanged: (s) => setState(() => _filtro = s.first),
            ),
          ),
          Expanded(child: _construirContenido()),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _crearTarea,
        icon: const Icon(Icons.add),
        label: const Text('Nueva Tarea'),
      ),
    );
  }

  Widget _construirContenido() {
    if (_cargando) return const Center(child: CircularProgressIndicator());

    if (_error != null) {
      return _EstadoVacio(
        icono: Icons.cloud_off_outlined,
        texto: 'No se pudieron cargar las tareas.\n$_error',
        accion: FilledButton.icon(
          onPressed: _cargar,
          icon: const Icon(Icons.refresh),
          label: const Text('Reintentar'),
        ),
      );
    }

    final visibles = _visibles;

    if (visibles.isEmpty) {
      final texto = switch (_filtro) {
        _Filtro.todas => 'No tienes tareas creadas.\n¡Agrega la primera!',
        _Filtro.pendientes => '¡Todo al día! No tienes tareas pendientes.',
        _Filtro.completadas => 'Aún no has completado ninguna tarea.',
      };
      // ListView para que el pull-to-refresh funcione también aquí.
      return RefreshIndicator(
        onRefresh: () => _cargar(conSpinner: false),
        child: ListView(
          children: [
            SizedBox(
              height: 300,
              child: _EstadoVacio(icono: Icons.checklist_rtl, texto: texto),
            ),
          ],
        ),
      );
    }

    return RefreshIndicator(
      onRefresh: () => _cargar(conSpinner: false),
      child: ListView.builder(
        itemCount: visibles.length,
        padding: const EdgeInsets.fromLTRB(12, 8, 12, 88),
        itemBuilder: (context, index) {
          final tarea = visibles[index];
          return _TarjetaTarea(
            key: ValueKey(tarea.id),
            tarea: tarea,
            onCambiar: (v) => _cambiarEstado(tarea, v),
            onEditar: () => _editarTarea(tarea),
            onEliminar: () => _eliminarTarea(tarea),
          );
        },
      ),
    );
  }
}

// ─────────────────────────── WIDGETS AUXILIARES ───────────────────────────

class _CabeceraUsuario extends StatelessWidget {
  final String email;
  final int total;
  final int completadas;
  final VoidCallback onActualizar;

  const _CabeceraUsuario({
    required this.email,
    required this.total,
    required this.completadas,
    required this.onActualizar,
  });

  @override
  Widget build(BuildContext context) {
    final progreso = total == 0 ? 0.0 : completadas / total;

    return Container(
      padding: const EdgeInsets.all(16),
      color: Theme.of(context).colorScheme.surfaceContainerLow,
      child: Column(
        children: [
          Row(
            children: [
              const CircleAvatar(child: Icon(Icons.person)),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text('Conectado como:',
                        style: TextStyle(fontSize: 12, color: Colors.grey)),
                    Text(
                      email,
                      style: const TextStyle(fontWeight: FontWeight.bold),
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                ),
              ),
              IconButton(
                tooltip: 'Actualizar lista',
                onPressed: onActualizar,
                icon: const Icon(Icons.refresh),
              ),
            ],
          ),
          if (total > 0) ...[
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(8),
                    child: LinearProgressIndicator(value: progreso, minHeight: 8),
                  ),
                ),
                const SizedBox(width: 12),
                Text('$completadas/$total', style: const TextStyle(fontWeight: FontWeight.w600)),
              ],
            ),
          ],
        ],
      ),
    );
  }
}

class _TarjetaTarea extends StatelessWidget {
  final Tarea tarea;
  final ValueChanged<bool> onCambiar;
  final VoidCallback onEditar;
  final VoidCallback onEliminar;

  const _TarjetaTarea({
    super.key,
    required this.tarea,
    required this.onCambiar,
    required this.onEditar,
    required this.onEliminar,
  });

  @override
  Widget build(BuildContext context) {
    final colores = Theme.of(context).colorScheme;

    return Dismissible(
      key: ValueKey('dismiss_${tarea.id}'),
      direction: DismissDirection.endToStart,
      background: Container(
        margin: const EdgeInsets.symmetric(vertical: 6),
        padding: const EdgeInsets.only(right: 24),
        alignment: Alignment.centerRight,
        decoration: BoxDecoration(
          color: colores.errorContainer,
          borderRadius: BorderRadius.circular(12),
        ),
        child: Icon(Icons.delete_outline, color: colores.onErrorContainer),
      ),
      onDismissed: (_) => onEliminar(),
      child: Card(
        elevation: 1,
        margin: const EdgeInsets.symmetric(vertical: 6),
        child: ListTile(
          onTap: onEditar,
          leading: Checkbox(
            value: tarea.completada,
            onChanged: (v) => onCambiar(v ?? false),
          ),
          title: Text(
            tarea.titulo,
            style: TextStyle(
              fontWeight: FontWeight.w600,
              decoration: tarea.completada ? TextDecoration.lineThrough : null,
              color: tarea.completada ? Colors.grey : null,
            ),
          ),
          subtitle: tarea.descripcion.isNotEmpty
              ? Text(tarea.descripcion, maxLines: 2, overflow: TextOverflow.ellipsis)
              : null,
          trailing: IconButton(
            tooltip: 'Eliminar',
            icon: Icon(Icons.delete_outline, color: colores.error),
            onPressed: onEliminar,
          ),
        ),
      ),
    );
  }
}

class _EstadoVacio extends StatelessWidget {
  final IconData icono;
  final String texto;
  final Widget? accion;

  const _EstadoVacio({required this.icono, required this.texto, this.accion});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icono, size: 56, color: Colors.grey),
            const SizedBox(height: 12),
            Text(
              texto,
              textAlign: TextAlign.center,
              style: const TextStyle(color: Colors.grey, fontSize: 16),
            ),
            if (accion != null) ...[const SizedBox(height: 16), accion!],
          ],
        ),
      ),
    );
  }
}

// ─────────────────────────── FORMULARIO (CREAR / EDITAR) ───────────────────────────

class _DatosTarea {
  final String titulo;
  final String descripcion;
  const _DatosTarea(this.titulo, this.descripcion);
}

class _FormularioTarea extends StatefulWidget {
  final Tarea? tarea;
  const _FormularioTarea({this.tarea});

  @override
  State<_FormularioTarea> createState() => _FormularioTareaState();
}

class _FormularioTareaState extends State<_FormularioTarea> {
  final _formKey = GlobalKey<FormState>();
  late final TextEditingController _titulo =
      TextEditingController(text: widget.tarea?.titulo);
  late final TextEditingController _desc =
      TextEditingController(text: widget.tarea?.descripcion);

  @override
  void dispose() {
    _titulo.dispose();
    _desc.dispose();
    super.dispose();
  }

  void _guardar() {
    if (!_formKey.currentState!.validate()) return;
    Navigator.pop(context, _DatosTarea(_titulo.text.trim(), _desc.text.trim()));
  }

  @override
  Widget build(BuildContext context) {
    final editando = widget.tarea != null;

    return Padding(
      padding: EdgeInsets.fromLTRB(
        24,
        8,
        24,
        MediaQuery.of(context).viewInsets.bottom + 24,
      ),
      child: Form(
        key: _formKey,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(
              editando ? 'Editar tarea' : 'Nueva tarea',
              style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 16),
            TextFormField(
              controller: _titulo,
              autofocus: true,
              textCapitalization: TextCapitalization.sentences,
              textInputAction: TextInputAction.next,
              maxLength: 120,
              decoration: const InputDecoration(
                labelText: 'Título',
                border: OutlineInputBorder(),
              ),
              validator: (v) =>
                  (v == null || v.trim().isEmpty) ? 'Escribe un título para la tarea' : null,
            ),
            const SizedBox(height: 12),
            TextFormField(
              controller: _desc,
              textCapitalization: TextCapitalization.sentences,
              maxLines: 3,
              decoration: const InputDecoration(
                labelText: 'Descripción (opcional)',
                border: OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 20),
            FilledButton(
              onPressed: _guardar,
              child: Text(editando ? 'Guardar cambios' : 'Crear tarea'),
            ),
          ],
        ),
      ),
    );
  }
}