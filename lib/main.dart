import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart' show PostgrestException;

import 'auth/auth_gate.dart';
import 'auth/login_page.dart';
import 'models/tarea.dart';
import 'pantalla.dart';
import 'pantalla_enfoque.dart';
import 'pantalla_estadisticas.dart';
import 'services/auth_service.dart';
import 'services/notificacion_service.dart';
import 'services/supabase_service.dart';
import 'widgets/esfera_cronometro.dart';

/// Colores de marca de KronoFlow.
class _Marca {
  static const marino = Color(0xFF1D385B);
  static const marinoClaro = Color(0xFF2B4F7E);
  static const marinoProfundo = Color(0xFF122740);
  static const cian = Color(0xFF6FE3F0);
}

// ─────────────────────────── ARRANQUE ───────────────────────────

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await _arrancar();
}

Future<void> _arrancar() async {
  try {
    await SupabaseService.inicializar();
    // Si las notificaciones fallan, la app debe seguir funcionando.
    try {
      await NotificacionService.instancia.inicializar();
    } catch (e) {
      debugPrint('Error al inicializar notificaciones: $e');
    }
    runApp(const KronoFlowApp());
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
      theme: _crearTema(Brightness.light),
      home: Scaffold(
        body: _EstadoVacio(
          icono: Icons.cloud_off_outlined,
          titulo: 'No se pudo iniciar KronoFlow',
          texto: mensaje,
          accion: FilledButton.icon(
            onPressed: onReintentar,
            icon: const Icon(Icons.refresh),
            label: const Text('Reintentar'),
          ),
        ),
      ),
    );
  }
}

// ─────────────────────────── APLICACIÓN Y TEMA ───────────────────────────

ThemeData _crearTema(Brightness brillo) {
  final oscuro = brillo == Brightness.dark;
  final base = ColorScheme.fromSeed(seedColor: _Marca.marinoClaro, brightness: brillo);

  final esquema = oscuro
      ? base.copyWith(
          primary: _Marca.cian,
          onPrimary: _Marca.marino,
          primaryContainer: const Color(0xFF24456F),
          onPrimaryContainer: Colors.white,
          surface: const Color(0xFF0C1726),
          surfaceContainerLow: const Color(0xFF142238),
          surfaceContainerHighest: const Color(0xFF1D3150),
          outlineVariant: const Color(0xFF2A4064),
        )
      : base.copyWith(
          primary: _Marca.marino,
          onPrimary: Colors.white,
          primaryContainer: const Color(0xFFD9E5F5),
          onPrimaryContainer: _Marca.marino,
          surface: const Color(0xFFF2F6FB),
          surfaceContainerLow: Colors.white,
          surfaceContainerHighest: const Color(0xFFE4EBF5),
          outlineVariant: const Color(0xFFD3DDEB),
        );

  OutlineInputBorder borde(Color color, [double ancho = 0]) => OutlineInputBorder(
        borderRadius: BorderRadius.circular(16),
        borderSide: ancho == 0 ? BorderSide.none : BorderSide(color: color, width: ancho),
      );

  return ThemeData(
    useMaterial3: true,
    colorScheme: esquema,
    scaffoldBackgroundColor: esquema.surface,
    splashFactory: InkSparkle.splashFactory,
    inputDecorationTheme: InputDecorationTheme(
      filled: true,
      fillColor: esquema.surfaceContainerHighest,
      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
      border: borde(Colors.transparent),
      enabledBorder: borde(Colors.transparent),
      focusedBorder: borde(esquema.primary, 2),
      errorBorder: borde(esquema.error, 1.5),
      focusedErrorBorder: borde(esquema.error, 2),
    ),
    filledButtonTheme: FilledButtonThemeData(
      style: FilledButton.styleFrom(
        minimumSize: const Size(0, 52),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      ),
    ),
    floatingActionButtonTheme: FloatingActionButtonThemeData(
      backgroundColor: esquema.primary,
      foregroundColor: esquema.onPrimary,
      elevation: 3,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
    ),
    chipTheme: ChipThemeData(
      shape: const StadiumBorder(),
      side: BorderSide.none,
      backgroundColor: esquema.surfaceContainerHighest,
      selectedColor: esquema.primaryContainer,
      showCheckmark: false,
      labelStyle: const TextStyle(fontWeight: FontWeight.w600),
    ),
    bottomSheetTheme: BottomSheetThemeData(
      backgroundColor: esquema.surfaceContainerLow,
      surfaceTintColor: Colors.transparent,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
      ),
    ),
    dialogTheme: DialogThemeData(
      backgroundColor: esquema.surfaceContainerLow,
      surfaceTintColor: Colors.transparent,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
    ),
    snackBarTheme: SnackBarThemeData(
      behavior: SnackBarBehavior.floating,
      backgroundColor: oscuro ? esquema.surfaceContainerHighest : _Marca.marinoProfundo,
      contentTextStyle: TextStyle(
        fontSize: 14.5,
        fontWeight: FontWeight.w600,
        color: oscuro ? esquema.onSurface : Colors.white,
      ),
      actionTextColor: _Marca.cian,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
    ),
  );
}

class KronoFlowApp extends StatefulWidget {
  const KronoFlowApp({super.key});

  @override
  State<KronoFlowApp> createState() => _KronoFlowAppState();
}

class _KronoFlowAppState extends State<KronoFlowApp> {
  // Se mantiene la clave antigua para no resetear el tema de usuarios actuales.
  static const _claveTema = 'taskflow_tema';
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
      final modo = switch (prefs.getString(_claveTema)) {
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
      title: 'KronoFlow',
      themeMode: _themeMode,
      theme: _crearTema(Brightness.light),
      darkTheme: _crearTema(Brightness.dark),
      home: AuthGate(
        autenticado: (_) => TaskHomePage(cambiarTema: _cambiarTema),
        noAutenticado: (_) => LoginPage(),
      ),
    );
  }
}

// ─────────────────────────── PANTALLA PRINCIPAL ───────────────────────────

enum _Filtro { todas, pendientes, completadas }

const _diasCortos = ['Lun', 'Mar', 'Mié', 'Jue', 'Vie', 'Sáb', 'Dom'];
const _diasLargos = [
  'Lunes',
  'Martes',
  'Miércoles',
  'Jueves',
  'Viernes',
  'Sábado',
  'Domingo',
];

/// Un bloque de tareas agrupadas por tiempo (vencidas, hoy, próximas…).
class _Grupo {
  final String titulo;
  final IconData icono;
  final Color? color;
  final List<Tarea> tareas;

  const _Grupo(this.titulo, this.icono, this.color, this.tareas);
}

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
  DateTime? _diaSel;
  bool _lanzamientoRevisado = false;

  @override
  void initState() {
    super.initState();
    NotificacionService.instancia.alAbrirTarea = _abrirDesdeAviso;
    _cargar();
  }

  @override
  void dispose() {
    NotificacionService.instancia.alAbrirTarea = null;
    super.dispose();
  }

  // ── Avisos ──

  /// Reprograma los recordatorios con el estado actual de las tareas.
  void _sincronizarAvisos() => NotificacionService.instancia.sincronizar(_tareas);

  void _abrirDesdeAviso(String id) {
    final i = _tareas.indexWhere((t) => t.id.toString() == id);
    if (i != -1 && mounted) _abrirDetalle(_tareas[i]);
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

  static DateTime _dia(DateTime f) {
    final l = f.toLocal();
    return DateTime(l.year, l.month, l.day);
  }

  static DateTime get _hoy {
    final h = DateTime.now();
    return DateTime(h.year, h.month, h.day);
  }

  String _etiquetaDia(DateTime d) {
    final hoy = _hoy;
    if (d == hoy) return 'Para hoy';
    if (d == DateTime(hoy.year, hoy.month, hoy.day + 1)) return 'Mañana';
    return '${_diasLargos[d.weekday - 1]} ${d.day}';
  }

  int get _totalCompletadas => _tareas.where((t) => t.completada).length;

  int get _totalVencidas {
    final hoy = _hoy;
    return _tareas
        .where((t) =>
            !t.completada && t.fechaLimite != null && _dia(t.fechaLimite!).isBefore(hoy))
        .length;
  }

  /// Pendientes primero; dentro de cada grupo, la fecha límite más cercana
  /// arriba (las tareas sin fecha al final) y luego las más recientes.
  List<Tarea> get _visibles {
    Iterable<Tarea> base = switch (_filtro) {
      _Filtro.todas => _tareas,
      _Filtro.pendientes => _tareas.where((t) => !t.completada),
      _Filtro.completadas => _tareas.where((t) => t.completada),
    };
    final dia = _diaSel;
    if (dia != null) {
      base = base.where((t) => t.fechaLimite != null && _dia(t.fechaLimite!) == dia);
    }
    final lista = base.toList();
    lista.sort((a, b) {
      if (a.completada != b.completada) return a.completada ? 1 : -1;
      final fa = a.fechaLimite, fb = b.fechaLimite;
      if (fa != null && fb != null) {
        final c = fa.compareTo(fb);
        if (c != 0) return c;
      } else if (fa != null) {
        return -1;
      } else if (fb != null) {
        return 1;
      }
      final ca = a.createdAt, cb = b.createdAt;
      if (ca != null && cb != null) return cb.compareTo(ca);
      return 0;
    });
    return lista;
  }

  /// Reparte las tareas visibles en bloques de tiempo.
  List<_Grupo> get _grupos {
    final seleccionado = _diaSel;
    if (seleccionado != null) {
      final lista = _visibles;
      return lista.isEmpty
          ? []
          : [_Grupo(_etiquetaDia(seleccionado), Icons.event_rounded, null, lista)];
    }
    final hoy = _hoy;
    final vencidas = <Tarea>[];
    final deHoy = <Tarea>[];
    final proximas = <Tarea>[];
    final sinFecha = <Tarea>[];
    final hechas = <Tarea>[];

    for (final t in _visibles) {
      final f = t.fechaLimite;
      if (t.completada) {
        hechas.add(t);
      } else if (f == null) {
        sinFecha.add(t);
      } else {
        final d = _dia(f);
        if (d.isBefore(hoy)) {
          vencidas.add(t);
        } else if (d == hoy) {
          deHoy.add(t);
        } else {
          proximas.add(t);
        }
      }
    }

    return [
      if (vencidas.isNotEmpty)
        _Grupo('Vencidas', Icons.local_fire_department_rounded, EstiloTarea.peligro, vencidas),
      if (deHoy.isNotEmpty) _Grupo('Para hoy', Icons.wb_sunny_rounded, null, deHoy),
      if (proximas.isNotEmpty)
        _Grupo('Próximas', Icons.update_rounded, const Color(0xFF8A99AE), proximas),
      if (sinFecha.isNotEmpty)
        _Grupo('Sin fecha', Icons.all_inclusive_rounded, const Color(0xFF8A99AE), sinFecha),
      if (hechas.isNotEmpty)
        _Grupo('Completadas', Icons.task_alt_rounded, const Color(0xFF8A99AE), hechas),
    ];
  }

  // ── Operaciones con Supabase ──

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
      _sincronizarAvisos();

      // Si la app se abrió tocando un aviso, ir directo a esa tarea.
      if (!_lanzamientoRevisado) {
        _lanzamientoRevisado = true;
        final id = await NotificacionService.instancia.idDeLanzamiento();
        if (id != null) _abrirDesdeAviso(id);
      }
    } catch (e) {
      debugPrint('Error al obtener tareas: $e');
      if (!mounted) return;
      setState(() {
        _cargando = false;
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
    if (datos.fechaLimite != null) await NotificacionService.instancia.pedirPermiso();

    try {
      final fila = await SupabaseService.cliente
          .from('tareas')
          .insert({
            'user_id': user.id,
            'titulo': datos.titulo,
            'descripcion': datos.descripcion,
            'completada': false,
            'prioridad': datos.prioridad.name,
            'fecha_limite': datos.fechaLimite?.toUtc().toIso8601String(),
          })
          .select()
          .single();

      if (!mounted) return;
      setState(() {
        _tareas.insert(0, Tarea.fromJson(fila));
        _error = null;
      });
      _sincronizarAvisos();
      _mostrarMensaje('Tarea creada');
    } catch (e) {
      debugPrint('Error al insertar tarea: $e');
      _mostrarMensaje('No se pudo crear la tarea: ${_textoError(e)}');
    }
  }

  Future<void> _editarTarea(Tarea tarea) async {
    final user = _authService.usuarioActual;
    if (user == null) return;

    final datos = await _abrirFormulario(tarea: tarea);
    if (datos == null) return;
    if (datos.fechaLimite != null) await NotificacionService.instancia.pedirPermiso();

    try {
      final fila = await SupabaseService.cliente
          .from('tareas')
          .update({
            'titulo': datos.titulo,
            'descripcion': datos.descripcion,
            'prioridad': datos.prioridad.name,
            'fecha_limite': datos.fechaLimite?.toUtc().toIso8601String(),
          })
          .eq('id', tarea.id)
          .eq('user_id', user.id)
          .select()
          .single();

      if (!mounted) return;
      final i = _tareas.indexWhere((t) => t.id == tarea.id);
      if (i != -1) setState(() => _tareas[i] = Tarea.fromJson(fila));
      _sincronizarAvisos();
      _mostrarMensaje('Tarea actualizada');
    } catch (e) {
      debugPrint('Error al editar tarea: $e');
      _mostrarMensaje('No se pudo editar la tarea: ${_textoError(e)}');
    }
  }

  /// Actualización optimista: la UI cambia al instante y se revierte si falla.
  Future<void> _cambiarEstado(Tarea tarea, bool completada) async {
    final user = _authService.usuarioActual;
    if (user == null) return;

    HapticFeedback.selectionClick();
    final anterior = tarea.completada;
    setState(() => tarea.completada = completada);
    _sincronizarAvisos();

    try {
      await SupabaseService.cliente
          .from('tareas')
          .update({
            'completada': completada,
            'completada_en': completada ? DateTime.now().toUtc().toIso8601String() : null,
          })
          .eq('id', tarea.id)
          .eq('user_id', user.id);
    } catch (e) {
      debugPrint('Error al actualizar estado: $e');
      if (!mounted) return;
      setState(() => tarea.completada = anterior);
      _sincronizarAvisos();
      _mostrarMensaje('No se pudo actualizar la tarea');
    }
  }

  Future<void> _eliminarTarea(Tarea tarea) async {
    final user = _authService.usuarioActual;
    final indice = _tareas.indexWhere((t) => t.id == tarea.id);
    if (user == null || indice == -1) return;

    setState(() => _tareas.removeAt(indice));
    _sincronizarAvisos();

    try {
      await SupabaseService.cliente
          .from('tareas')
          .delete()
          .eq('id', tarea.id)
          .eq('user_id', user.id);

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
      _sincronizarAvisos();
      _mostrarMensaje('No se pudo eliminar la tarea');
    }
  }

  Future<void> _restaurarTarea(Tarea tarea, String userId) async {
    try {
      await SupabaseService.cliente.from('tareas').insert({
        'id': tarea.id,
        ...tarea.toJson(),
        'user_id': userId,
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
            style: FilledButton.styleFrom(minimumSize: const Size(0, 44)),
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

  // ── Navegación y formulario ──

  void _abrirDetalle(Tarea tarea) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => PantallaDetalle(
          tarea: tarea,
          onAlternarEstado: () => _cambiarEstado(tarea, !tarea.completada),
          onEditar: () => _editarTarea(tarea),
          onEliminar: () => _eliminarTarea(tarea),
        ),
      ),
    );
  }

  void _enfocar(Tarea tarea) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => PantallaEnfoque(
          tarea: tarea,
          onCompletar: () => _cambiarEstado(tarea, true),
        ),
      ),
    );
  }

  void _abrirEstadisticas() {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => PantallaEstadisticas(tareas: List.of(_tareas)),
      ),
    );
  }

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
    final email = _authService.usuarioActual?.email ?? 'usuario';
    final nombre = _nombreBonito(email);
    final esOscuro = Theme.of(context).brightness == Brightness.dark;

    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: SystemUiOverlayStyle.light,
      child: Scaffold(
        body: Column(
          children: [
            _CabeceraHome(
              nombre: nombre,
              total: _tareas.length,
              completadas: _totalCompletadas,
              vencidas: _totalVencidas,
              esOscuro: esOscuro,
              onTema: widget.cambiarTema,
              onSalir: _cerrarSesion,
              onEstadisticas: _abrirEstadisticas,
            ),
            _barraFiltros(),
            Expanded(
              child: AnimatedSwitcher(
                duration: const Duration(milliseconds: 220),
                child: KeyedSubtree(
                  key: ValueKey('$_filtro$_diaSel$_cargando${_error != null}'),
                  child: _construirContenido(),
                ),
              ),
            ),
          ],
        ),
        floatingActionButton: FloatingActionButton.extended(
          onPressed: _crearTarea,
          icon: const Icon(Icons.add_rounded),
          label: const Text('Nueva tarea', style: TextStyle(fontWeight: FontWeight.w700)),
        ),
      ),
    );
  }

  /// Selector de filtro con una píldora que se desliza entre opciones.
  Widget _barraFiltros() {
    final esquema = Theme.of(context).colorScheme;
    final pendientes = _tareas.length - _totalCompletadas;
    final indice = _Filtro.values.indexOf(_filtro);

    (String, int) dato(_Filtro f) => switch (f) {
          _Filtro.todas => ('Todas', _tareas.length),
          _Filtro.pendientes => ('Pendientes', pendientes),
          _Filtro.completadas => ('Hechas', _totalCompletadas),
        };

    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 4),
      child: Container(
        height: 48,
        padding: const EdgeInsets.all(4),
        decoration: BoxDecoration(
          color: esquema.surfaceContainerHighest,
          borderRadius: BorderRadius.circular(16),
        ),
        child: Stack(
          children: [
            AnimatedAlign(
              duration: const Duration(milliseconds: 280),
              curve: Curves.easeOutCubic,
              alignment: Alignment(-1.0 + indice, 0),
              child: FractionallySizedBox(
                widthFactor: 1 / 3,
                heightFactor: 1,
                child: DecoratedBox(
                  decoration: BoxDecoration(
                    color: esquema.primary,
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
              ),
            ),
            Row(
              children: [
                for (final f in _Filtro.values)
                  Expanded(
                    child: Semantics(
                      button: true,
                      selected: _filtro == f,
                      child: GestureDetector(
                        behavior: HitTestBehavior.opaque,
                        onTap: () {
                          HapticFeedback.selectionClick();
                          setState(() => _filtro = f);
                        },
                        child: Center(
                          child: FittedBox(
                            fit: BoxFit.scaleDown,
                            child: AnimatedDefaultTextStyle(
                              duration: const Duration(milliseconds: 200),
                              style: TextStyle(
                                fontSize: 14,
                                fontWeight: FontWeight.w700,
                                color: _filtro == f
                                    ? esquema.onPrimary
                                    : esquema.onSurfaceVariant,
                              ),
                              child: Text('${dato(f).$1}  ${dato(f).$2}'),
                            ),
                          ),
                        ),
                      ),
                    ),
                  ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _construirContenido() {
    if (_cargando) return const Center(child: CircularProgressIndicator());

    if (_error != null) {
      return _EstadoVacio(
        icono: Icons.cloud_off_outlined,
        titulo: 'No se pudieron cargar las tareas',
        texto: _error!,
        accion: FilledButton.icon(
          onPressed: () => _cargar(),
          icon: const Icon(Icons.refresh),
          label: const Text('Reintentar'),
        ),
      );
    }

    final grupos = _grupos;
    final tira = _tareas.isEmpty ? null : _tiraSemana();

    if (grupos.isEmpty) {
      final (icono, titulo, texto) = _diaSel != null
          ? (
              Icons.beach_access_rounded,
              'Día libre',
              'No tienes tareas para este día.',
            )
          : switch (_filtro) {
              _Filtro.todas => (
                  Icons.event_available_rounded,
                  'Aún no tienes tareas',
                  'Toca «Nueva tarea» para crear la primera.',
                ),
              _Filtro.pendientes => (
                  Icons.celebration_rounded,
                  '¡Todo al día!',
                  'No tienes tareas pendientes.',
                ),
              _Filtro.completadas => (
                  Icons.task_alt_rounded,
                  'Nada completado todavía',
                  'Marca una tarea como hecha y aparecerá aquí.',
                ),
            };
      final puedeCrear = _diaSel == null && _filtro == _Filtro.todas && _tareas.isEmpty;

      return RefreshIndicator(
        onRefresh: () => _cargar(conSpinner: false),
        child: LayoutBuilder(
          builder: (context, c) {
            final alto = math.max(c.maxHeight - (tira == null ? 8 : 96), 320.0);
            return ListView(
              primary: false,
              physics: const AlwaysScrollableScrollPhysics(),
              padding: const EdgeInsets.fromLTRB(16, 8, 16, 0),
              children: [
                if (tira != null) tira,
                SizedBox(
                  height: alto,
                  child: _EstadoVacio(
                    icono: icono,
                    titulo: titulo,
                    texto: texto,
                    accion: puedeCrear
                        ? FilledButton.tonalIcon(
                            onPressed: _crearTarea,
                            icon: const Icon(Icons.add_rounded),
                            label: const Text('Crear tarea'),
                          )
                        : null,
                  ),
                ),
              ],
            );
          },
        ),
      );
    }

    return RefreshIndicator(
      onRefresh: () => _cargar(conSpinner: false),
      child: ListView(
        primary: false,
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.fromLTRB(16, 8, 16, 100),
        children: [
          if (tira != null) tira,
          for (final g in grupos) ...[
            _EncabezadoGrupo(grupo: g),
            _BloqueTareas(
              children: [
                for (final tarea in g.tareas)
                  _FilaTarea(
                    key: ValueKey(tarea.id),
                    tarea: tarea,
                    onCambiar: (v) => _cambiarEstado(tarea, v),
                    onAbrir: () => _abrirDetalle(tarea),
                    onEliminar: () => _eliminarTarea(tarea),
                    onEnfocar: () => _enfocar(tarea),
                  ),
              ],
            ),
            const SizedBox(height: 8),
          ],
        ],
      ),
    );
  }

  /// Los próximos 7 días: puntos de color según la prioridad de lo que vence.
  Widget _tiraSemana() {
    final hoy = _hoy;
    final dias = List.generate(7, (i) => DateTime(hoy.year, hoy.month, hoy.day + i));
    final porDia = <DateTime, List<Tarea>>{};
    for (final t in _tareas) {
      final f = t.fechaLimite;
      if (t.completada || f == null) continue;
      porDia.putIfAbsent(_dia(f), () => []).add(t);
    }

    return _TiraSemana(
      dias: dias,
      porDia: porDia,
      seleccionado: _diaSel,
      onTap: (d) {
        HapticFeedback.selectionClick();
        setState(() => _diaSel = _diaSel == d ? null : d);
      },
    );
  }
}

// ─────────────────────────── CABECERA CON CRONÓMETRO ───────────────────────────

/// «imarestudiante2@mail.com» → «Imarestudiante»
String _nombreBonito(String email) {
  final crudo = email.split('@').first;
  final limpio = crudo
      .replaceAll(RegExp(r'\d+$'), '')
      .replaceAll(RegExp(r'[._\-]+'), ' ')
      .trim();
  if (limpio.isEmpty) return 'Usuario';
  return limpio
      .split(' ')
      .where((p) => p.isNotEmpty)
      .map((p) => p[0].toUpperCase() + p.substring(1))
      .join(' ');
}

String _saludo() {
  final h = DateTime.now().hour;
  if (h < 12) return 'Buenos días';
  if (h < 20) return 'Buenas tardes';
  return 'Buenas noches';
}

/// Cabecera de marca: el progreso se lee como la esfera de un cronómetro.
class _CabeceraHome extends StatelessWidget {
  final String nombre;
  final int total;
  final int completadas;
  final int vencidas;
  final bool esOscuro;
  final VoidCallback onTema;
  final VoidCallback onSalir;
  final VoidCallback onEstadisticas;

  const _CabeceraHome({
    required this.nombre,
    required this.total,
    required this.completadas,
    required this.vencidas,
    required this.esOscuro,
    required this.onTema,
    required this.onSalir,
    required this.onEstadisticas,
  });

  @override
  Widget build(BuildContext context) {
    final pendientes = total - completadas;
    final progreso = total == 0 ? 0.0 : completadas / total;
    final subtitulo = total == 0
        ? 'Crea tu primera tarea para empezar'
        : pendientes == 0
            ? '¡Todo al día! Buen trabajo'
            : 'Tienes $pendientes ${pendientes == 1 ? 'tarea pendiente' : 'tareas pendientes'}';

    const radio = BorderRadius.vertical(bottom: Radius.circular(36));

    return Container(
      width: double.infinity,
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [_Marca.marinoProfundo, _Marca.marino, _Marca.marinoClaro],
          stops: [0, 0.55, 1],
        ),
        borderRadius: radio,
      ),
      child: ClipRRect(
        borderRadius: radio,
        child: Stack(
          children: [
            const Positioned.fill(child: CustomPaint(painter: _FondoOndasPainter())),
            SafeArea(
              bottom: false,
              child: Padding(
                padding: const EdgeInsets.fromLTRB(20, 8, 14, 26),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        const Icon(Icons.timelapse_rounded, color: _Marca.cian, size: 26),
                        const SizedBox(width: 8),
                        const Text(
                          'KronoFlow',
                          style: TextStyle(
                            fontSize: 21,
                            fontWeight: FontWeight.w800,
                            color: Colors.white,
                            letterSpacing: -0.3,
                          ),
                        ),
                        const Spacer(),
                        _BotonCristal(
                          tooltip: 'Estadísticas',
                          icono: Icons.insights_rounded,
                          onPressed: onEstadisticas,
                        ),
                        const SizedBox(width: 6),
                        _BotonCristal(
                          tooltip: 'Cambiar tema',
                          icono: esOscuro
                              ? Icons.light_mode_rounded
                              : Icons.dark_mode_rounded,
                          onPressed: onTema,
                        ),
                        const SizedBox(width: 6),
                        _BotonCristal(
                          tooltip: 'Cerrar sesión',
                          icono: Icons.logout_rounded,
                          onPressed: onSalir,
                        ),
                      ],
                    ),
                    const SizedBox(height: 20),
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.center,
                      children: [
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                _saludo(),
                                style: const TextStyle(fontSize: 15, color: Colors.white70),
                              ),
                              const SizedBox(height: 2),
                              FittedBox(
                                fit: BoxFit.scaleDown,
                                alignment: Alignment.centerLeft,
                                child: Text(
                                nombre,
                                maxLines: 1,
                                style: const TextStyle(
                                  fontSize: 30,
                                  height: 1.1,
                                  fontWeight: FontWeight.w800,
                                  color: Colors.white,
                                  letterSpacing: -0.8,
                                ),
                              ),
                              ),
                              const SizedBox(height: 8),
                              Text(
                                subtitulo,
                                style: const TextStyle(
                                  fontSize: 14.5,
                                  height: 1.3,
                                  color: Colors.white70,
                                ),
                              ),
                              if (vencidas > 0) ...[
                                const SizedBox(height: 12),
                                Container(
                                  padding: const EdgeInsets.symmetric(
                                      horizontal: 10, vertical: 5),
                                  decoration: BoxDecoration(
                                    color: EstiloTarea.peligro.withValues(alpha: 0.28),
                                    borderRadius: BorderRadius.circular(999),
                                    border: Border.all(
                                      color: EstiloTarea.peligro.withValues(alpha: 0.5),
                                    ),
                                  ),
                                  child: Row(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      const Icon(Icons.warning_amber_rounded,
                                          size: 16, color: Colors.white),
                                      const SizedBox(width: 6),
                                      Text(
                                        vencidas == 1
                                            ? '1 tarea vencida'
                                            : '$vencidas tareas vencidas',
                                        style: const TextStyle(
                                          fontSize: 13,
                                          fontWeight: FontWeight.w700,
                                          color: Colors.white,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              ],
                            ],
                          ),
                        ),
                        const SizedBox(width: 12),
                        Padding(
                          padding: const EdgeInsets.only(right: 6),
                          child: _Cronometro(
                            progreso: progreso,
                            completadas: completadas,
                            total: total,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _BotonCristal extends StatelessWidget {
  final IconData icono;
  final String tooltip;
  final VoidCallback onPressed;

  const _BotonCristal({
    required this.icono,
    required this.tooltip,
    required this.onPressed,
  });

  @override
  Widget build(BuildContext context) {
    return IconButton(
      tooltip: tooltip,
      onPressed: onPressed,
      style: IconButton.styleFrom(
        backgroundColor: Colors.white.withValues(alpha: 0.12),
        foregroundColor: Colors.white,
        minimumSize: const Size(40, 40),
        padding: EdgeInsets.zero,
      ),
      icon: Icon(icono, size: 20),
    );
  }
}

/// Esfera de la cabecera: el progreso de las tareas completadas.
class _Cronometro extends StatelessWidget {
  final double progreso;
  final int completadas;
  final int total;

  const _Cronometro({
    required this.progreso,
    required this.completadas,
    required this.total,
  });

  @override
  Widget build(BuildContext context) {
    final completo = total > 0 && completadas == total;

    return Semantics(
      label: 'Progreso: $completadas de $total tareas completadas',
      child: EsferaCronometro(
        progreso: progreso,
        centro: total == 0
            ? const Icon(Icons.hourglass_empty_rounded, color: Colors.white54, size: 30)
            : completo
                ? const Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(Icons.check_rounded, color: _Marca.cian, size: 38),
                      SizedBox(height: 2),
                      Text(
                        'Todo hecho',
                        style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w700,
                          color: Colors.white70,
                        ),
                      ),
                    ],
                  )
                : Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        '$completadas',
                        style: const TextStyle(
                          fontSize: 34,
                          height: 1,
                          fontWeight: FontWeight.w800,
                          color: Colors.white,
                          letterSpacing: -1,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        'de $total',
                        style: const TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.w600,
                          color: Colors.white70,
                        ),
                      ),
                    ],
                  ),
      ),
    );
  }
}

/// Ondas que nacen de la esfera, con un halo cian muy suave detrás.
class _FondoOndasPainter extends CustomPainter {
  const _FondoOndasPainter();

  @override
  void paint(Canvas canvas, Size size) {
    // Centro aproximado de la esfera (112 px, a 20 px del borde y 26 px del pie).
    final centro = Offset(size.width - 76, size.height - 82);

    canvas.drawCircle(
      centro,
      170,
      Paint()
        ..shader = RadialGradient(
          colors: [
            _Marca.cian.withValues(alpha: 0.16),
            _Marca.cian.withValues(alpha: 0),
          ],
        ).createShader(Rect.fromCircle(center: centro, radius: 170)),
    );

    final pincel = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.2;

    for (var i = 1; i <= 5; i++) {
      pincel.color = Colors.white.withValues(alpha: 0.075 - i * 0.01);
      canvas.drawCircle(centro, 62.0 * i, pincel);
    }
  }

  @override
  bool shouldRepaint(_FondoOndasPainter old) => false;
}

// ─────────────────────────── LISTA DE TAREAS ───────────────────────────

/// Siete días hacia delante. Toca uno para ver solo lo que vence ese día.
class _TiraSemana extends StatelessWidget {
  final List<DateTime> dias;
  final Map<DateTime, List<Tarea>> porDia;
  final DateTime? seleccionado;
  final ValueChanged<DateTime> onTap;

  const _TiraSemana({
    required this.dias,
    required this.porDia,
    required this.seleccionado,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(top: 6, bottom: 2),
      child: Row(
        children: [
          for (var i = 0; i < dias.length; i++)
            Expanded(
              child: Padding(
                padding: EdgeInsets.only(right: i == dias.length - 1 ? 0 : 6),
                child: _CeldaDia(
                  dia: dias[i],
                  esHoy: i == 0,
                  seleccionada: seleccionado == dias[i],
                  tareas: porDia[dias[i]] ?? const [],
                  onTap: () => onTap(dias[i]),
                ),
              ),
            ),
        ],
      ),
    );
  }
}

class _CeldaDia extends StatelessWidget {
  final DateTime dia;
  final bool esHoy;
  final bool seleccionada;
  final List<Tarea> tareas;
  final VoidCallback onTap;

  const _CeldaDia({
    required this.dia,
    required this.esHoy,
    required this.seleccionada,
    required this.tareas,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final esquema = Theme.of(context).colorScheme;
    final sel = seleccionada;
    final etiqueta = esHoy ? 'Hoy' : _diasCortos[dia.weekday - 1];

    return Semantics(
      button: true,
      selected: sel,
      label: '${_diasLargos[dia.weekday - 1]} ${dia.day}, '
          '${tareas.length} ${tareas.length == 1 ? 'tarea' : 'tareas'}',
      child: GestureDetector(
        onTap: onTap,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 220),
          curve: Curves.easeOut,
          height: 72,
          decoration: BoxDecoration(
            color: sel ? esquema.primary : esquema.surfaceContainerLow,
            borderRadius: BorderRadius.circular(18),
            border: Border.all(
              color: sel
                  ? esquema.primary
                  : esHoy
                      ? esquema.primary.withValues(alpha: 0.55)
                      : esquema.outlineVariant.withValues(alpha: 0.6),
              width: esHoy && !sel ? 1.6 : 1,
            ),
          ),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Text(
                etiqueta,
                style: TextStyle(
                  fontSize: 11.5,
                  fontWeight: FontWeight.w700,
                  color: sel
                      ? esquema.onPrimary.withValues(alpha: 0.8)
                      : esquema.onSurfaceVariant,
                ),
              ),
              const SizedBox(height: 3),
              Text(
                '${dia.day}',
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.w800,
                  color: sel ? esquema.onPrimary : esquema.onSurface,
                ),
              ),
              const SizedBox(height: 6),
              SizedBox(
                height: 5,
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    for (final t in tareas.take(3))
                      Container(
                        width: 5,
                        height: 5,
                        margin: const EdgeInsets.symmetric(horizontal: 1.5),
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          color: sel
                              ? esquema.onPrimary
                              : EstiloTarea.prioridad(t.prioridad).color,
                        ),
                      ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _EncabezadoGrupo extends StatelessWidget {
  final _Grupo grupo;
  const _EncabezadoGrupo({required this.grupo});

  @override
  Widget build(BuildContext context) {
    final esquema = Theme.of(context).colorScheme;
    final color = grupo.color ?? esquema.primary;

    return Padding(
      padding: const EdgeInsets.fromLTRB(6, 14, 6, 8),
      child: Row(
        children: [
          Icon(grupo.icono, size: 18, color: color),
          const SizedBox(width: 8),
          Text(
            grupo.titulo,
            style: TextStyle(
              fontSize: 15,
              fontWeight: FontWeight.w800,
              color: grupo.color == null ? esquema.onSurface : color,
              letterSpacing: -0.1,
            ),
          ),
          const SizedBox(width: 8),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 1),
            decoration: BoxDecoration(
              color: color.withValues(alpha: 0.14),
              borderRadius: BorderRadius.circular(999),
            ),
            child: Text(
              '${grupo.tareas.length}',
              style: TextStyle(fontSize: 12, fontWeight: FontWeight.w800, color: color),
            ),
          ),
        ],
      ),
    );
  }
}

/// Superficie única que agrupa varias filas separadas por divisores finos.
class _BloqueTareas extends StatelessWidget {
  final List<Widget> children;
  const _BloqueTareas({required this.children});

  @override
  Widget build(BuildContext context) {
    final esquema = Theme.of(context).colorScheme;

    return Container(
      decoration: BoxDecoration(
        color: esquema.surfaceContainerLow,
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: esquema.outlineVariant.withValues(alpha: 0.6)),
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(23),
        child: Material(
          color: Colors.transparent,
          child: Column(
            children: [
              for (var i = 0; i < children.length; i++) ...[
                if (i > 0)
                  Divider(
                    height: 1,
                    thickness: 1,
                    indent: 64,
                    color: esquema.outlineVariant.withValues(alpha: 0.45),
                  ),
                children[i],
              ],
            ],
          ),
        ),
      ),
    );
  }
}

/// Fila de tarea. Desliza a la derecha para completar y a la izquierda para eliminar.
class _FilaTarea extends StatelessWidget {
  final Tarea tarea;
  final ValueChanged<bool> onCambiar;
  final VoidCallback onAbrir;
  final VoidCallback onEliminar;
  final VoidCallback onEnfocar;

  const _FilaTarea({
    super.key,
    required this.tarea,
    required this.onCambiar,
    required this.onAbrir,
    required this.onEliminar,
    required this.onEnfocar,
  });

  @override
  Widget build(BuildContext context) {
    final esquema = Theme.of(context).colorScheme;
    final prio = EstiloTarea.prioridad(tarea.prioridad);
    final fecha = tarea.fechaLimite;
    final urgencia = fecha == null ? null : EstiloTarea.urgencia(fecha, tarea.completada);
    final hecha = tarea.completada;

    return Dismissible(
      key: ValueKey('dismiss_${tarea.id}'),
      background: Container(
        color: esquema.primaryContainer,
        padding: const EdgeInsets.only(left: 24),
        alignment: Alignment.centerLeft,
        child: Icon(
          hecha ? Icons.undo_rounded : Icons.check_rounded,
          color: esquema.onPrimaryContainer,
        ),
      ),
      secondaryBackground: Container(
        color: esquema.errorContainer,
        padding: const EdgeInsets.only(right: 24),
        alignment: Alignment.centerRight,
        child: Icon(Icons.delete_outline_rounded, color: esquema.onErrorContainer),
      ),
      confirmDismiss: (direccion) async {
        if (direccion == DismissDirection.startToEnd) {
          onCambiar(!hecha);
          return false;
        }
        return true;
      },
      onDismissed: (_) => onEliminar(),
      child: InkWell(
        onTap: onAbrir,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(6, 4, 16, 4),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _CirculoEstado(
                hecha: hecha,
                color: prio.color,
                onTap: () => onCambiar(!hecha),
              ),
              Expanded(
                child: Padding(
                  padding: const EdgeInsets.only(top: 12, bottom: 12),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      AnimatedDefaultTextStyle(
                        duration: const Duration(milliseconds: 200),
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          fontSize: 16,
                          height: 1.25,
                          fontWeight: FontWeight.w700,
                          decoration: hecha ? TextDecoration.lineThrough : null,
                          decorationColor: esquema.onSurfaceVariant,
                          color: hecha ? esquema.onSurfaceVariant : esquema.onSurface,
                        ),
                        child: Text(tarea.titulo),
                      ),
                      if (tarea.descripcion.isNotEmpty) ...[
                        const SizedBox(height: 3),
                        Text(
                          tarea.descripcion,
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                            fontSize: 13.5,
                            height: 1.3,
                            color: esquema.onSurfaceVariant,
                          ),
                        ),
                      ],
                      const SizedBox(height: 10),
                      Wrap(
                        spacing: 8,
                        runSpacing: 6,
                        children: [
                          _Etiqueta(
                            icono: prio.icono,
                            texto: tarea.prioridad.etiqueta,
                            color: hecha ? esquema.onSurfaceVariant : prio.color,
                          ),
                          if (urgencia != null)
                            _Etiqueta(
                              icono: Icons.event_rounded,
                              texto: urgencia.texto,
                              color: urgencia.color,
                            ),
                        ],
                      ),
                    ],
                  ),
                ),
              ),
              if (!hecha)
                Padding(
                  padding: const EdgeInsets.only(top: 10),
                  child: IconButton(
                    tooltip: 'Enfocar',
                    onPressed: onEnfocar,
                    style: IconButton.styleFrom(
                      backgroundColor: esquema.primary.withValues(alpha: 0.1),
                      foregroundColor: esquema.primary,
                      minimumSize: const Size(36, 36),
                      padding: EdgeInsets.zero,
                    ),
                    icon: const Icon(Icons.timer_outlined, size: 20),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Casilla circular: el borde lleva el color de la prioridad.
class _CirculoEstado extends StatelessWidget {
  final bool hecha;
  final Color color;
  final VoidCallback onTap;

  const _CirculoEstado({required this.hecha, required this.color, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final esquema = Theme.of(context).colorScheme;

    return Semantics(
      checked: hecha,
      label: hecha ? 'Marcar como pendiente' : 'Marcar como hecha',
      child: InkResponse(
        onTap: onTap,
        radius: 26,
        child: SizedBox(
          width: 52,
          height: 52,
          child: Center(
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 220),
              curve: Curves.easeOutBack,
              width: 26,
              height: 26,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: hecha ? esquema.outlineVariant : Colors.transparent,
                border: Border.all(
                  color: hecha ? esquema.outlineVariant : color,
                  width: 2.2,
                ),
              ),
              child: AnimatedScale(
                scale: hecha ? 1 : 0,
                duration: const Duration(milliseconds: 220),
                curve: Curves.easeOutBack,
                child: Icon(Icons.check_rounded, size: 16, color: esquema.surface),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _Etiqueta extends StatelessWidget {
  const _Etiqueta({required this.icono, required this.texto, required this.color});

  final IconData icono;
  final String texto;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 4),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.13),
        borderRadius: BorderRadius.circular(999),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icono, size: 14, color: color),
          const SizedBox(width: 5),
          Text(
            texto,
            style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: color),
          ),
        ],
      ),
    );
  }
}

class _EstadoVacio extends StatelessWidget {
  final IconData icono;
  final String titulo;
  final String texto;
  final Widget? accion;

  const _EstadoVacio({
    required this.icono,
    required this.titulo,
    required this.texto,
    this.accion,
  });

  @override
  Widget build(BuildContext context) {
    final esquema = Theme.of(context).colorScheme;

    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 132,
              height: 132,
              alignment: Alignment.center,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                border: Border.all(color: esquema.primary.withValues(alpha: 0.1), width: 1.5),
              ),
              child: Container(
                width: 100,
                height: 100,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: esquema.primary.withValues(alpha: 0.1),
                  border: Border.all(color: esquema.primary.withValues(alpha: 0.2)),
                ),
                child: Icon(icono, size: 44, color: esquema.primary),
              ),
            ),
            const SizedBox(height: 22),
            Text(
              titulo,
              textAlign: TextAlign.center,
              style: const TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.w800,
                letterSpacing: -0.3,
              ),
            ),
            const SizedBox(height: 6),
            Text(
              texto,
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: 15, height: 1.35, color: esquema.onSurfaceVariant),
            ),
            if (accion != null) ...[const SizedBox(height: 22), accion!],
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
  final Prioridad prioridad;
  final DateTime? fechaLimite;

  const _DatosTarea({
    required this.titulo,
    required this.descripcion,
    required this.prioridad,
    this.fechaLimite,
  });
}

class _FormularioTarea extends StatefulWidget {
  final Tarea? tarea;
  const _FormularioTarea({this.tarea});

  @override
  State<_FormularioTarea> createState() => _FormularioTareaState();
}

class _FormularioTareaState extends State<_FormularioTarea> {
  final _formKey = GlobalKey<FormState>();
  late final _titulo = TextEditingController(text: widget.tarea?.titulo);
  late final _desc = TextEditingController(text: widget.tarea?.descripcion);
  late Prioridad _prioridad = widget.tarea?.prioridad ?? Prioridad.media;
  late DateTime? _fecha = widget.tarea?.fechaLimite;

  @override
  void dispose() {
    _titulo.dispose();
    _desc.dispose();
    super.dispose();
  }

  bool _esDia(DateTime? a, DateTime b) {
    if (a == null) return false;
    final l = a.toLocal();
    return l.year == b.year && l.month == b.month && l.day == b.day;
  }

  Future<void> _elegirFecha() async {
    final hoy = DateTime.now();
    final r = await showDatePicker(
      context: context,
      initialDate: _fecha ?? hoy,
      firstDate: DateTime(hoy.year - 1),
      lastDate: DateTime(hoy.year + 5),
    );
    if (r != null) setState(() => _fecha = DateTime(r.year, r.month, r.day));
  }

  void _guardar() {
    if (!_formKey.currentState!.validate()) return;
    Navigator.pop(
      context,
      _DatosTarea(
        titulo: _titulo.text.trim(),
        descripcion: _desc.text.trim(),
        prioridad: _prioridad,
        fechaLimite: _fecha,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final editando = widget.tarea != null;
    final ahora = DateTime.now();
    final hoy = DateTime(ahora.year, ahora.month, ahora.day);
    final manana = DateTime(ahora.year, ahora.month, ahora.day + 1);
    final esHoy = _esDia(_fecha, hoy);
    final esManana = _esDia(_fecha, manana);
    final personalizada = _fecha != null && !esHoy && !esManana;

    return Padding(
      padding: EdgeInsets.fromLTRB(
        24,
        0,
        24,
        MediaQuery.viewInsetsOf(context).bottom + 24,
      ),
      child: SingleChildScrollView(
        child: Form(
          key: _formKey,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(
                editando ? 'Editar tarea' : 'Nueva tarea',
                style: const TextStyle(
                  fontSize: 24,
                  fontWeight: FontWeight.w800,
                  letterSpacing: -0.5,
                ),
              ),
              const SizedBox(height: 18),
              TextFormField(
                controller: _titulo,
                autofocus: true,
                textCapitalization: TextCapitalization.sentences,
                textInputAction: TextInputAction.next,
                maxLength: 120,
                style: const TextStyle(fontSize: 17, fontWeight: FontWeight.w600),
                decoration: const InputDecoration(
                  labelText: 'Título',
                  counterText: '',
                ),
                validator: (v) => (v == null || v.trim().isEmpty)
                    ? 'Escribe un título para la tarea'
                    : null,
              ),
              const SizedBox(height: 12),
              TextFormField(
                controller: _desc,
                textCapitalization: TextCapitalization.sentences,
                maxLines: 3,
                decoration: const InputDecoration(labelText: 'Descripción (opcional)'),
              ),
              const SizedBox(height: 22),
              Text('Prioridad', style: Theme.of(context).textTheme.titleSmall),
              const SizedBox(height: 10),
              Row(
                children: [
                  for (final p in Prioridad.values)
                    Expanded(
                      child: Padding(
                        padding: EdgeInsets.only(
                          right: p == Prioridad.values.last ? 0 : 8,
                        ),
                        child: _OpcionPrioridad(
                          prioridad: p,
                          seleccionada: _prioridad == p,
                          onTap: () {
                            HapticFeedback.selectionClick();
                            setState(() => _prioridad = p);
                          },
                        ),
                      ),
                    ),
                ],
              ),
              const SizedBox(height: 22),
              Text('Fecha límite', style: Theme.of(context).textTheme.titleSmall),
              const SizedBox(height: 10),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  ChoiceChip(
                    label: const Text('Sin fecha'),
                    selected: _fecha == null,
                    onSelected: (_) => setState(() => _fecha = null),
                  ),
                  ChoiceChip(
                    label: const Text('Hoy'),
                    selected: esHoy,
                    onSelected: (_) => setState(() => _fecha = hoy),
                  ),
                  ChoiceChip(
                    label: const Text('Mañana'),
                    selected: esManana,
                    onSelected: (_) => setState(() => _fecha = manana),
                  ),
                  ChoiceChip(
                    avatar: const Icon(Icons.event_rounded, size: 18),
                    label: Text(personalizada ? EstiloTarea.fechaCorta(_fecha!) : 'Elegir fecha'),
                    selected: personalizada,
                    onSelected: (_) => _elegirFecha(),
                  ),
                ],
              ),
              const SizedBox(height: 26),
              FilledButton(
                onPressed: _guardar,
                child: Text(
                  editando ? 'Guardar cambios' : 'Crear tarea',
                  style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w700),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _OpcionPrioridad extends StatelessWidget {
  final Prioridad prioridad;
  final bool seleccionada;
  final VoidCallback onTap;

  const _OpcionPrioridad({
    required this.prioridad,
    required this.seleccionada,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final esquema = Theme.of(context).colorScheme;
    final estilo = EstiloTarea.prioridad(prioridad);

    return Semantics(
      button: true,
      selected: seleccionada,
      child: GestureDetector(
        onTap: onTap,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          curve: Curves.easeOut,
          padding: const EdgeInsets.symmetric(vertical: 14),
          decoration: BoxDecoration(
            color: seleccionada
                ? estilo.color.withValues(alpha: 0.16)
                : esquema.surfaceContainerHighest,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(
              color: seleccionada ? estilo.color : Colors.transparent,
              width: 1.8,
            ),
          ),
          child: Column(
            children: [
              Icon(
                estilo.icono,
                size: 22,
                color: seleccionada ? estilo.color : esquema.onSurfaceVariant,
              ),
              const SizedBox(height: 6),
              Text(
                prioridad.etiqueta,
                style: TextStyle(
                  fontSize: 13.5,
                  fontWeight: FontWeight.w700,
                  color: seleccionada ? estilo.color : esquema.onSurfaceVariant,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}