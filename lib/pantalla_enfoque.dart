import 'dart:async';
import 'dart:ui' show FontFeature;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'models/tarea.dart';
import 'services/enfoque_service.dart';
import 'services/notificacion_service.dart';
import 'theme/marca.dart';
import 'widgets/esfera_cronometro.dart';

enum _Fase { listo, corriendo, pausa, terminado }

enum _Modo { enfoque, descanso }

class _Opcion {
  final String etiqueta;
  final int minutos;
  final _Modo modo;

  const _Opcion(this.etiqueta, this.minutos, this.modo);
}

const _opciones = [
  _Opcion('15 min', 15, _Modo.enfoque),
  _Opcion('25 min', 25, _Modo.enfoque),
  _Opcion('45 min', 45, _Modo.enfoque),
  _Opcion('Descanso', 5, _Modo.descanso),
];

String _formatoMin(int min) => min < 60
    ? '$min min'
    : '${min ~/ 60} h ${(min % 60).toString().padLeft(2, '0')} min';

/// Temporizador de enfoque (Pomodoro) para una tarea.
///
/// El tiempo se calcula con la hora de fin, no contando ticks, así que sigue
/// siendo exacto aunque la app pase a segundo plano.
class PantallaEnfoque extends StatefulWidget {
  final Tarea tarea;

  /// Para el botón «Marcar tarea como hecha» al terminar una sesión.
  final VoidCallback? onCompletar;

  const PantallaEnfoque({super.key, required this.tarea, this.onCompletar});

  @override
  State<PantallaEnfoque> createState() => _PantallaEnfoqueState();
}

class _PantallaEnfoqueState extends State<PantallaEnfoque> with WidgetsBindingObserver {
  int _opcion = 1;
  int _opcionEnfoque = 1;
  _Fase _fase = _Fase.listo;

  Timer? _timer;
  DateTime? _fin;
  Duration _total = const Duration(minutes: 25);
  Duration _restante = const Duration(minutes: 25);

  bool _primerPlano = true;
  bool _pidioPermiso = false;
  bool _terminoEnfoque = true;

  int _sesionesHoy = 0;
  int _minutosHoy = 0;

  _Opcion get _actual => _opciones[_opcion];

  /// Cada 4 sesiones de enfoque, el descanso es largo.
  int get _minDescanso => (_sesionesHoy > 0 && _sesionesHoy % 4 == 0) ? 15 : 5;

  Duration get _duracion => _actual.modo == _Modo.descanso
      ? Duration(minutes: _minDescanso)
      : Duration(minutes: _actual.minutos);

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _cargarSesiones();
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _timer?.cancel();
    if (_fase == _Fase.corriendo || _fase == _Fase.pausa) {
      NotificacionService.instancia.cancelarFinEnfoque();
    }
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    _primerPlano = state == AppLifecycleState.resumed;
    // Al volver, actualiza el tiempo restante de inmediato.
    if (_primerPlano && _fase == _Fase.corriendo) _tick();
  }

  // ── Lógica del temporizador ──

  void _preparar() {
    _total = _duracion;
    _restante = _total;
    _fin = null;
  }

  Future<void> _cargarSesiones() async {
    final todas = await EnfoqueService.instancia.todas();
    final hoy = DateTime.now();
    final id = widget.tarea.id.toString();

    final deHoy = todas.where((s) =>
        s.tareaId == id &&
        s.fin.year == hoy.year &&
        s.fin.month == hoy.month &&
        s.fin.day == hoy.day);

    if (!mounted) return;
    setState(() {
      _sesionesHoy = deHoy.length;
      _minutosHoy = deHoy.fold<int>(0, (suma, s) => suma + s.minutos);
      if (_fase == _Fase.listo) _preparar();
    });
  }

  Future<void> _iniciar() async {
    HapticFeedback.mediumImpact();

    // El permiso de notificaciones se pide la primera vez que se inicia.
    if (!_pidioPermiso) {
      _pidioPermiso = true;
      await NotificacionService.instancia.pedirPermiso();
      if (!mounted) return;
    }

    if (_fase == _Fase.listo || _fase == _Fase.terminado) _preparar();

    final fin = DateTime.now().add(_restante);
    _fin = fin;
    setState(() => _fase = _Fase.corriendo);

    _timer?.cancel();
    _timer = Timer.periodic(const Duration(milliseconds: 250), (_) => _tick());

    final esEnfoque = _actual.modo == _Modo.enfoque;
    NotificacionService.instancia.programarFinEnfoque(
      cuando: fin,
      titulo: esEnfoque ? 'Sesión de enfoque terminada' : 'Descanso terminado',
      cuerpo: esEnfoque ? widget.tarea.titulo : 'Listo para otra sesión',
      payload: widget.tarea.id.toString(),
    );
  }

  void _tick() {
    final fin = _fin;
    if (fin == null || _fase != _Fase.corriendo) return;

    final resto = fin.difference(DateTime.now());
    if (resto <= Duration.zero) {
      _terminar();
      return;
    }
    setState(() => _restante = resto);
  }

  void _pausar() {
    final fin = _fin;
    if (fin == null) return;

    HapticFeedback.selectionClick();
    _timer?.cancel();
    final resto = fin.difference(DateTime.now());
    setState(() {
      _restante = resto.isNegative ? Duration.zero : resto;
      _fase = _Fase.pausa;
    });
    NotificacionService.instancia.cancelarFinEnfoque();
  }

  void _reiniciar() {
    HapticFeedback.selectionClick();
    _cancelarTodo();
    setState(() {
      _fase = _Fase.listo;
      _preparar();
    });
  }

  void _cancelarTodo() {
    _timer?.cancel();
    NotificacionService.instancia.cancelarFinEnfoque();
  }

  Future<void> _terminar() async {
    if (_fase != _Fase.corriendo) return;

    _timer?.cancel();
    final fin = _fin ?? DateTime.now();
    final eraEnfoque = _actual.modo == _Modo.enfoque;

    setState(() {
      _fase = _Fase.terminado;
      _restante = Duration.zero;
      _terminoEnfoque = eraEnfoque;
    });
    HapticFeedback.heavyImpact();

    // Si la app está a la vista, el aviso del sistema sobra.
    if (_primerPlano) NotificacionService.instancia.cancelarFinEnfoque();

    if (eraEnfoque) {
      await EnfoqueService.instancia.registrar(SesionEnfoque(
        tareaId: widget.tarea.id.toString(),
        fin: fin,
        minutos: _total.inMinutes,
      ));
      await _cargarSesiones();
    }
  }

  void _cambiarOpcion(int i) {
    if (_fase != _Fase.listo) return;
    HapticFeedback.selectionClick();
    setState(() {
      _opcion = i;
      if (_opciones[i].modo == _Modo.enfoque) _opcionEnfoque = i;
      _preparar();
    });
  }

  void _irADescanso() {
    setState(() {
      _opcion = _opciones.length - 1;
      _preparar();
    });
    _iniciar();
  }

  void _otraSesion() {
    setState(() {
      _opcion = _opcionEnfoque;
      _fase = _Fase.listo;
      _preparar();
    });
  }

  Future<bool?> _confirmarSalida() {
    return showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('¿Salir del enfoque?'),
        content: const Text('Se cancelará la sesión en curso y no se registrará.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Seguir enfocado'),
          ),
          FilledButton(
            style: FilledButton.styleFrom(minimumSize: const Size(0, 44)),
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Salir'),
          ),
        ],
      ),
    );
  }

  // ── Datos para la interfaz ──

  String get _textoTiempo {
    final seg = (_restante.inMilliseconds / 1000).ceil();
    final m = (seg ~/ 60).toString().padLeft(2, '0');
    final s = (seg % 60).toString().padLeft(2, '0');
    return '$m:$s';
  }

  double get _progreso {
    if (_fase == _Fase.terminado) return 1;
    if (_total.inMilliseconds == 0) return 0;
    return 1 - _restante.inMilliseconds / _total.inMilliseconds;
  }

  String get _etiquetaEstado {
    switch (_fase) {
      case _Fase.pausa:
        return 'En pausa';
      case _Fase.terminado:
        return '¡Completado!';
      case _Fase.listo:
      case _Fase.corriendo:
        return _actual.modo == _Modo.enfoque ? 'Enfoque' : 'Descanso';
    }
  }

  // ── Interfaz ──

  @override
  Widget build(BuildContext context) {
    final enfoque = _actual.modo == _Modo.enfoque;
    final color = enfoque ? Marca.cian : Marca.menta;
    final ancho = MediaQuery.sizeOf(context).width;
    final tamano = (ancho * 0.72).clamp(220.0, 300.0).toDouble();
    final enMarcha = _fase == _Fase.corriendo || _fase == _Fase.pausa;
    final terminado = _fase == _Fase.terminado;

    return PopScope(
      canPop: !enMarcha,
      onPopInvokedWithResult: (didPop, _) async {
        if (didPop) return;
        final salir = await _confirmarSalida();
        if (salir == true && mounted) {
          _cancelarTodo();
          Navigator.of(context).pop();
        }
      },
      child: AnnotatedRegion<SystemUiOverlayStyle>(
        value: SystemUiOverlayStyle.light,
        child: Scaffold(
          backgroundColor: Marca.marinoProfundo,
          body: Container(
            width: double.infinity,
            height: double.infinity,
            decoration: const BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                colors: [Marca.marinoProfundo, Marca.marino],
              ),
            ),
            child: SafeArea(
              child: Column(
                children: [
                  Align(
                    alignment: Alignment.centerLeft,
                    child: Padding(
                      padding: const EdgeInsets.fromLTRB(8, 4, 0, 0),
                      child: IconButton(
                        tooltip: 'Cerrar',
                        onPressed: () => Navigator.of(context).maybePop(),
                        icon: const Icon(Icons.close_rounded, color: Colors.white),
                      ),
                    ),
                  ),
                  Expanded(
                    child: Center(
                      child: SingleChildScrollView(
                        padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 8),
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Text(
                              enfoque ? 'Enfocado en' : 'Tómate un respiro',
                              style: const TextStyle(fontSize: 14, color: Colors.white70),
                            ),
                            const SizedBox(height: 6),
                            Text(
                              widget.tarea.titulo,
                              maxLines: 2,
                              overflow: TextOverflow.ellipsis,
                              textAlign: TextAlign.center,
                              style: const TextStyle(
                                fontSize: 24,
                                height: 1.2,
                                fontWeight: FontWeight.w800,
                                color: Colors.white,
                                letterSpacing: -0.4,
                              ),
                            ),
                            const SizedBox(height: 28),
                            _esfera(tamano, color, terminado),
                            const SizedBox(height: 26),
                            if (terminado)
                              _panelFinal(color)
                            else ...[
                              _selector(color),
                              const SizedBox(height: 28),
                              _controles(color),
                            ],
                            const SizedBox(height: 26),
                            _indicadorSesiones(color),
                          ],
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _esfera(double tamano, Color color, bool terminado) {
    return Semantics(
      label: '$_etiquetaEstado, $_textoTiempo restantes',
      child: EsferaCronometro(
        tamano: tamano,
        progreso: _progreso,
        duracion: Duration.zero,
        colorActivo: color,
        centro: terminado
            ? Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(Icons.check_rounded, size: tamano * 0.3, color: color),
                  const SizedBox(height: 4),
                  Text(
                    _etiquetaEstado,
                    style: const TextStyle(
                      fontSize: 15,
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
                    _textoTiempo,
                    style: TextStyle(
                      fontSize: tamano * 0.2,
                      height: 1,
                      fontWeight: FontWeight.w800,
                      color: Colors.white,
                      letterSpacing: -1,
                      fontFeatures: const [FontFeature.tabularFigures()],
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    _etiquetaEstado,
                    style: TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.w700,
                      color: color,
                    ),
                  ),
                ],
              ),
      ),
    );
  }

  Widget _selector(Color color) {
    final activo = _fase == _Fase.listo;

    return AnimatedOpacity(
      duration: const Duration(milliseconds: 200),
      opacity: activo ? 1 : 0.35,
      child: IgnorePointer(
        ignoring: !activo,
        child: Wrap(
          spacing: 8,
          runSpacing: 8,
          alignment: WrapAlignment.center,
          children: [
            for (var i = 0; i < _opciones.length; i++)
              ChoiceChip(
                label: Text(_opciones[i].etiqueta),
                selected: _opcion == i,
                showCheckmark: false,
                backgroundColor: Colors.white.withValues(alpha: 0.1),
                selectedColor: color,
                labelStyle: TextStyle(
                  fontWeight: FontWeight.w700,
                  color: _opcion == i ? Marca.marino : Colors.white,
                ),
                onSelected: (_) => _cambiarOpcion(i),
              ),
          ],
        ),
      ),
    );
  }

  Widget _controles(Color color) {
    final corriendo = _fase == _Fase.corriendo;

    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        SizedBox(
          width: 56,
          height: 56,
          child: _fase == _Fase.listo
              ? null
              : IconButton(
                  tooltip: 'Reiniciar',
                  onPressed: _reiniciar,
                  style: IconButton.styleFrom(
                    backgroundColor: Colors.white.withValues(alpha: 0.12),
                    foregroundColor: Colors.white,
                  ),
                  icon: const Icon(Icons.replay_rounded),
                ),
        ),
        const SizedBox(width: 24),
        Semantics(
          button: true,
          label: corriendo ? 'Pausar' : 'Iniciar',
          child: Material(
            color: color,
            shape: const CircleBorder(),
            elevation: 6,
            shadowColor: color.withValues(alpha: 0.5),
            child: InkWell(
              customBorder: const CircleBorder(),
              onTap: corriendo ? _pausar : _iniciar,
              child: SizedBox(
                width: 84,
                height: 84,
                child: Icon(
                  corriendo ? Icons.pause_rounded : Icons.play_arrow_rounded,
                  size: 46,
                  color: Marca.marino,
                ),
              ),
            ),
          ),
        ),
        const SizedBox(width: 24),
        const SizedBox(width: 56, height: 56),
      ],
    );
  }

  Widget _panelFinal(Color color) {
    final fueEnfoque = _terminoEnfoque;
    final puedeCompletar = fueEnfoque && widget.onCompletar != null && !widget.tarea.completada;

    return Column(
      children: [
        Text(
          fueEnfoque ? '¡Sesión completada!' : 'Descanso terminado',
          style: const TextStyle(
            fontSize: 22,
            fontWeight: FontWeight.w800,
            color: Colors.white,
          ),
        ),
        const SizedBox(height: 6),
        Text(
          fueEnfoque
              ? 'Buen trabajo. Tu sesión quedó registrada.'
              : 'Listo para otra ronda de enfoque.',
          textAlign: TextAlign.center,
          style: const TextStyle(fontSize: 15, color: Colors.white70),
        ),
        const SizedBox(height: 20),
        FilledButton.icon(
          style: FilledButton.styleFrom(
            backgroundColor: color,
            foregroundColor: Marca.marino,
          ),
          onPressed: fueEnfoque ? _irADescanso : _otraSesion,
          icon: Icon(fueEnfoque ? Icons.coffee_rounded : Icons.play_arrow_rounded),
          label: Text(
            fueEnfoque ? 'Descansar $_minDescanso min' : 'Nueva sesión de enfoque',
            style: const TextStyle(fontWeight: FontWeight.w700),
          ),
        ),
        if (fueEnfoque)
          TextButton(
            style: TextButton.styleFrom(foregroundColor: Colors.white),
            onPressed: _otraSesion,
            child: const Text('Otra sesión de enfoque'),
          ),
        if (puedeCompletar)
          OutlinedButton.icon(
            style: OutlinedButton.styleFrom(
              foregroundColor: Colors.white,
              side: const BorderSide(color: Colors.white38),
              minimumSize: const Size(0, 48),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
            ),
            onPressed: () {
              widget.onCompletar!();
              Navigator.of(context).pop();
            },
            icon: const Icon(Icons.task_alt_rounded),
            label: const Text('Marcar tarea como hecha'),
          ),
      ],
    );
  }

  /// Cuatro puntos: el ciclo Pomodoro (el cuarto da paso a un descanso largo).
  Widget _indicadorSesiones(Color color) {
    final llenos = _sesionesHoy == 0 ? 0 : ((_sesionesHoy - 1) % 4) + 1;

    return Column(
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            for (var i = 0; i < 4; i++)
              AnimatedContainer(
                duration: const Duration(milliseconds: 300),
                margin: const EdgeInsets.symmetric(horizontal: 4),
                width: 10,
                height: 10,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: i < llenos ? color : Colors.white.withValues(alpha: 0.2),
                ),
              ),
          ],
        ),
        const SizedBox(height: 8),
        Text(
          _sesionesHoy == 0
              ? 'Aún sin sesiones hoy en esta tarea'
              : 'Hoy: $_sesionesHoy ${_sesionesHoy == 1 ? 'sesión' : 'sesiones'} · ${_formatoMin(_minutosHoy)}',
          style: const TextStyle(fontSize: 13.5, color: Colors.white60),
        ),
      ],
    );
  }
}