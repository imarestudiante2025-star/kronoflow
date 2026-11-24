import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:supabase_flutter/supabase_flutter.dart' show PostgrestException;

import 'models/tarea.dart';
import 'services/auth_service.dart';
import 'services/enfoque_service.dart';
import 'services/supabase_service.dart';
import 'theme/marca.dart';
import 'widgets/esfera_cronometro.dart';

const _letrasDias = ['L', 'M', 'X', 'J', 'V', 'S', 'D'];
const _metaRacha = 30;

DateTime _soloDia(DateTime d) => DateTime(d.year, d.month, d.day);
DateTime _sumarDias(DateTime d, int n) => DateTime(d.year, d.month, d.day + n);
DateTime _lunes(DateTime d) => DateTime(d.year, d.month, d.day - (d.weekday - 1));

String _formatoMin(int min) => min < 60
    ? '$min min'
    : '${min ~/ 60} h ${(min % 60).toString().padLeft(2, '0')} min';

/// Estadísticas: racha, tareas completadas por día/semana y tiempo de enfoque.
///
/// Un día cuenta para la racha cuando se completa al menos una tarea.
/// Requiere la columna `completada_en` en la tabla `tareas` de Supabase.
class PantallaEstadisticas extends StatefulWidget {
  final List<Tarea> tareas;

  const PantallaEstadisticas({super.key, required this.tareas});

  @override
  State<PantallaEstadisticas> createState() => _PantallaEstadisticasState();
}

class _PantallaEstadisticasState extends State<PantallaEstadisticas> {
  bool _cargando = true;
  String? _error;
  List<DateTime> _completadas = [];
  List<SesionEnfoque> _sesiones = [];
  bool _verSemanas = false;

  @override
  void initState() {
    super.initState();
    _cargar();
  }

  Future<void> _cargar({bool conSpinner = true}) async {
    if (conSpinner) {
      setState(() {
        _cargando = true;
        _error = null;
      });
    }

    try {
      final userId = AuthService().usuarioActual?.id;
      if (userId == null) throw StateError('Sin sesión');

      final res = await SupabaseService.cliente
          .from('tareas')
          .select('completada_en')
          .eq('user_id', userId)
          .not('completada_en', 'is', null);

      final fechas = (res as List)
          .map((r) =>
              DateTime.parse((r as Map<String, dynamic>)['completada_en'] as String)
                  .toLocal())
          .toList();
      final sesiones = await EnfoqueService.instancia.todas();

      if (!mounted) return;
      setState(() {
        _completadas = fechas;
        _sesiones = sesiones;
        _cargando = false;
        _error = null;
      });
    } catch (e) {
      debugPrint('Error al cargar estadísticas: $e');
      if (!mounted) return;
      setState(() {
        _cargando = false;
        _error = e is PostgrestException
            ? e.message
            : 'Revisa tu conexión e inténtalo de nuevo';
      });
    }
  }

  // ── Cálculos ──

  Map<DateTime, int> get _porDia {
    final mapa = <DateTime, int>{};
    for (final f in _completadas) {
      final d = _soloDia(f);
      mapa[d] = (mapa[d] ?? 0) + 1;
    }
    return mapa;
  }

  int _contar(Map<DateTime, int> porDia, DateTime desde, DateTime hasta) {
    var total = 0;
    for (var d = desde; !d.isAfter(hasta); d = _sumarDias(d, 1)) {
      total += porDia[d] ?? 0;
    }
    return total;
  }

  /// Racha actual y mejor racha. Hoy aún puede completarse, así que si hoy
  /// no hay nada la racha se cuenta desde ayer sin romperse.
  (int, int) _rachas(Map<DateTime, int> porDia, DateTime hoy) {
    var actual = 0;
    var cursor = porDia.containsKey(hoy) ? hoy : _sumarDias(hoy, -1);
    while (porDia.containsKey(cursor)) {
      actual++;
      cursor = _sumarDias(cursor, -1);
    }

    final dias = porDia.keys.toList()..sort();
    var mejor = 0;
    var corrida = 0;
    DateTime? anterior;
    for (final d in dias) {
      corrida = (anterior != null && _sumarDias(anterior, 1) == d) ? corrida + 1 : 1;
      mejor = math.max(mejor, corrida);
      anterior = d;
    }
    return (actual, mejor);
  }

  (int, int) _enfoque(DateTime hoy) {
    final inicioSemana = _lunes(hoy);
    var minHoy = 0;
    var minSemana = 0;
    for (final s in _sesiones) {
      final d = _soloDia(s.fin);
      if (d == hoy) minHoy += s.minutos;
      if (!d.isBefore(inicioSemana) && !d.isAfter(hoy)) minSemana += s.minutos;
    }
    return (minHoy, minSemana);
  }

  // ── Interfaz ──

  @override
  Widget build(BuildContext context) {
    final hoy = _soloDia(DateTime.now());
    final porDia = _porDia;
    final (racha, mejor) = _rachas(porDia, hoy);

    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: SystemUiOverlayStyle.light,
      child: Scaffold(
        body: Column(
          children: [
            _Cabecera(
              racha: racha,
              mejor: mejor,
              hoyCuenta: porDia.containsKey(hoy),
              cargando: _cargando,
            ),
            Expanded(child: _contenido(porDia, hoy)),
          ],
        ),
      ),
    );
  }

  Widget _contenido(Map<DateTime, int> porDia, DateTime hoy) {
    if (_cargando) return const Center(child: CircularProgressIndicator());

    if (_error != null) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(32),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(Icons.cloud_off_outlined, size: 48),
              const SizedBox(height: 12),
              const Text(
                'No se pudieron cargar las estadísticas',
                textAlign: TextAlign.center,
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.w800),
              ),
              const SizedBox(height: 6),
              Text(
                _error!,
                textAlign: TextAlign.center,
                style: TextStyle(color: Theme.of(context).colorScheme.onSurfaceVariant),
              ),
              const SizedBox(height: 18),
              FilledButton.icon(
                onPressed: _cargar,
                icon: const Icon(Icons.refresh),
                label: const Text('Reintentar'),
              ),
            ],
          ),
        ),
      );
    }

    final inicioSemana = _lunes(hoy);
    final estaSemana = _contar(porDia, inicioSemana, hoy);
    final semanaPasada =
        _contar(porDia, _sumarDias(inicioSemana, -7), _sumarDias(inicioSemana, -1));
    final delta = estaSemana - semanaPasada;
    final (minHoy, minSemana) = _enfoque(hoy);
    final pendientes = widget.tareas.where((t) => !t.completada).length;

    return RefreshIndicator(
      onRefresh: () => _cargar(conSpinner: false),
      child: ListView(
        primary: false,
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.fromLTRB(16, 16, 16, 32),
        children: [
          Row(
            children: [
              Expanded(
                child: _Dato(
                  icono: Icons.task_alt_rounded,
                  valor: '$estaSemana',
                  etiqueta: 'Completadas esta semana',
                  detalle: delta > 0
                      ? '+$delta vs. semana pasada'
                      : delta == 0
                          ? 'Igual que la semana pasada'
                          : '$delta vs. semana pasada',
                  colorDetalle: delta > 0 ? const Color(0xFF2FBF71) : null,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: _Dato(
                  icono: Icons.emoji_events_rounded,
                  valor: '${_completadas.length}',
                  etiqueta: 'Completadas en total',
                  detalle: '$pendientes ${pendientes == 1 ? 'pendiente' : 'pendientes'} ahora',
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: _Dato(
                  icono: Icons.timer_rounded,
                  valor: _formatoMin(minHoy),
                  etiqueta: 'Enfoque hoy',
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: _Dato(
                  icono: Icons.local_fire_department_rounded,
                  valor: _formatoMin(minSemana),
                  etiqueta: 'Enfoque esta semana',
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          _Tarjeta(
            titulo: 'Tareas completadas',
            accion: SegmentedButton<bool>(
              showSelectedIcon: false,
              style: const ButtonStyle(
                visualDensity: VisualDensity.compact,
                tapTargetSize: MaterialTapTargetSize.shrinkWrap,
              ),
              segments: const [
                ButtonSegment(value: false, label: Text('7 días')),
                ButtonSegment(value: true, label: Text('8 semanas')),
              ],
              selected: {_verSemanas},
              onSelectionChanged: (s) => setState(() => _verSemanas = s.first),
            ),
            child: _Barras(
              key: ValueKey(_verSemanas),
              datos: _verSemanas ? _datosSemanas(porDia, hoy) : _datosDias(porDia, hoy),
            ),
          ),
          const SizedBox(height: 16),
          _Tarjeta(
            titulo: 'Últimas 4 semanas',
            child: _MapaCalor(porDia: porDia, hoy: hoy),
          ),
          const SizedBox(height: 16),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 8),
            child: Text(
              'Un día cuenta para tu racha cuando completas al menos una tarea. '
              'El tiempo de enfoque se guarda en este dispositivo.',
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 12.5,
                height: 1.4,
                color: Theme.of(context).colorScheme.onSurfaceVariant,
              ),
            ),
          ),
        ],
      ),
    );
  }

  List<_Barra> _datosDias(Map<DateTime, int> porDia, DateTime hoy) {
    return [
      for (var i = 6; i >= 0; i--)
        () {
          final d = _sumarDias(hoy, -i);
          return _Barra(i == 0 ? 'Hoy' : _letrasDias[d.weekday - 1], porDia[d] ?? 0, i == 0);
        }(),
    ];
  }

  List<_Barra> _datosSemanas(Map<DateTime, int> porDia, DateTime hoy) {
    final lunes = _lunes(hoy);
    return [
      for (var i = 7; i >= 0; i--)
        () {
          final inicio = _sumarDias(lunes, -7 * i);
          final fin = i == 0 ? hoy : _sumarDias(inicio, 6);
          return _Barra(
            i == 0 ? 'Esta' : '${inicio.day}/${inicio.month}',
            _contar(porDia, inicio, fin),
            i == 0,
          );
        }(),
    ];
  }
}

// ─────────────────────────── CABECERA ───────────────────────────

class _Cabecera extends StatelessWidget {
  final int racha;
  final int mejor;
  final bool hoyCuenta;
  final bool cargando;

  const _Cabecera({
    required this.racha,
    required this.mejor,
    required this.hoyCuenta,
    required this.cargando,
  });

  @override
  Widget build(BuildContext context) {
    final String mensaje;
    if (cargando) {
      mensaje = 'Calculando tu racha…';
    } else if (racha == 0) {
      mensaje = 'Completa una tarea hoy para empezar tu racha';
    } else if (!hoyCuenta) {
      mensaje = 'Completa una tarea hoy para mantenerla';
    } else if (racha >= mejor) {
      mensaje = '¡Es tu mejor racha!';
    } else {
      mensaje = 'Tu mejor racha: $mejor ${mejor == 1 ? 'día' : 'días'}';
    }

    return Container(
      width: double.infinity,
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [Marca.marinoProfundo, Marca.marino, Marca.marinoClaro],
          stops: [0, 0.55, 1],
        ),
        borderRadius: BorderRadius.vertical(bottom: Radius.circular(36)),
      ),
      child: SafeArea(
        bottom: false,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(8, 4, 20, 26),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  IconButton(
                    tooltip: 'Volver',
                    onPressed: () => Navigator.of(context).maybePop(),
                    icon: const Icon(Icons.arrow_back_rounded, color: Colors.white),
                  ),
                  const Text(
                    'Tu progreso',
                    style: TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.w800,
                      color: Colors.white,
                      letterSpacing: -0.3,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              Padding(
                padding: const EdgeInsets.only(left: 12),
                child: Row(
                  children: [
                    EsferaCronometro(
                      tamano: 132,
                      progreso: math.min(racha, _metaRacha) / _metaRacha,
                      centro: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Text(
                            '$racha',
                            style: const TextStyle(
                              fontSize: 40,
                              height: 1,
                              fontWeight: FontWeight.w800,
                              color: Colors.white,
                              letterSpacing: -1,
                            ),
                          ),
                          const SizedBox(height: 2),
                          Text(
                            racha == 1 ? 'día' : 'días',
                            style: const TextStyle(
                              fontSize: 13,
                              fontWeight: FontWeight.w600,
                              color: Colors.white70,
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(width: 20),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text(
                            'Racha actual',
                            style: TextStyle(
                              fontSize: 22,
                              fontWeight: FontWeight.w800,
                              color: Colors.white,
                              letterSpacing: -0.4,
                            ),
                          ),
                          const SizedBox(height: 6),
                          Text(
                            mensaje,
                            style: const TextStyle(
                              fontSize: 14.5,
                              height: 1.3,
                              color: Colors.white70,
                            ),
                          ),
                          const SizedBox(height: 10),
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                            decoration: BoxDecoration(
                              color: Colors.white.withValues(alpha: 0.12),
                              borderRadius: BorderRadius.circular(999),
                            ),
                            child: const Text(
                              'Meta: $_metaRacha días',
                              style: TextStyle(
                                fontSize: 12.5,
                                fontWeight: FontWeight.w700,
                                color: Marca.cian,
                              ),
                            ),
                          ),
                        ],
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

// ─────────────────────────── COMPONENTES ───────────────────────────

class _Dato extends StatelessWidget {
  final IconData icono;
  final String valor;
  final String etiqueta;
  final String? detalle;
  final Color? colorDetalle;

  const _Dato({
    required this.icono,
    required this.valor,
    required this.etiqueta,
    this.detalle,
    this.colorDetalle,
  });

  @override
  Widget build(BuildContext context) {
    final esquema = Theme.of(context).colorScheme;

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: esquema.surfaceContainerLow,
        borderRadius: BorderRadius.circular(22),
        border: Border.all(color: esquema.outlineVariant.withValues(alpha: 0.6)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: esquema.primary.withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Icon(icono, size: 20, color: esquema.primary),
          ),
          const SizedBox(height: 12),
          FittedBox(
            fit: BoxFit.scaleDown,
            alignment: Alignment.centerLeft,
            child: Text(
              valor,
              style: const TextStyle(
                fontSize: 26,
                height: 1,
                fontWeight: FontWeight.w800,
                letterSpacing: -0.6,
              ),
            ),
          ),
          const SizedBox(height: 4),
          Text(
            etiqueta,
            style: TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w600,
              color: esquema.onSurfaceVariant,
            ),
          ),
          if (detalle != null) ...[
            const SizedBox(height: 6),
            Text(
              detalle!,
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w700,
                color: colorDetalle ?? esquema.onSurfaceVariant,
              ),
            ),
          ],
        ],
      ),
    );
  }
}

class _Tarjeta extends StatelessWidget {
  final String titulo;
  final Widget? accion;
  final Widget child;

  const _Tarjeta({required this.titulo, this.accion, required this.child});

  @override
  Widget build(BuildContext context) {
    final esquema = Theme.of(context).colorScheme;

    return Container(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 18),
      decoration: BoxDecoration(
        color: esquema.surfaceContainerLow,
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: esquema.outlineVariant.withValues(alpha: 0.6)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  titulo,
                  style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w800),
                ),
              ),
              if (accion != null) accion!,
            ],
          ),
          const SizedBox(height: 16),
          child,
        ],
      ),
    );
  }
}

class _Barra {
  final String etiqueta;
  final int valor;
  final bool actual;

  const _Barra(this.etiqueta, this.valor, this.actual);
}

/// Gráfico de barras hecho con widgets: sin paquetes externos.
class _Barras extends StatelessWidget {
  final List<_Barra> datos;

  const _Barras({super.key, required this.datos});

  static const _alturaMax = 110.0;

  @override
  Widget build(BuildContext context) {
    final esquema = Theme.of(context).colorScheme;
    final maximo = math.max(1, datos.fold<int>(0, (m, b) => math.max(m, b.valor)));

    return SizedBox(
      height: _alturaMax + 56,
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          for (final b in datos)
            Expanded(
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 3),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.end,
                  children: [
                    Text(
                      b.valor == 0 ? '' : '${b.valor}',
                      style: TextStyle(
                        fontSize: 12.5,
                        fontWeight: FontWeight.w800,
                        color: b.actual ? esquema.primary : esquema.onSurfaceVariant,
                      ),
                    ),
                    const SizedBox(height: 4),
                    TweenAnimationBuilder<double>(
                      tween: Tween(begin: 0, end: b.valor / maximo),
                      duration: const Duration(milliseconds: 650),
                      curve: Curves.easeOutCubic,
                      builder: (context, f, _) => Container(
                        height: 4 + f * (_alturaMax - 4),
                        decoration: BoxDecoration(
                          color: b.valor == 0
                              ? esquema.surfaceContainerHighest
                              : b.actual
                                  ? esquema.primary
                                  : esquema.primary.withValues(alpha: 0.38),
                          borderRadius: BorderRadius.circular(8),
                        ),
                      ),
                    ),
                    const SizedBox(height: 8),
                    FittedBox(
                      fit: BoxFit.scaleDown,
                      child: Text(
                        b.etiqueta,
                        style: TextStyle(
                          fontSize: 11.5,
                          fontWeight: b.actual ? FontWeight.w800 : FontWeight.w600,
                          color: b.actual ? esquema.onSurface : esquema.onSurfaceVariant,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
        ],
      ),
    );
  }
}

/// Cuadrícula de 4 semanas (lunes a domingo); más oscuro = más tareas.
class _MapaCalor extends StatelessWidget {
  final Map<DateTime, int> porDia;
  final DateTime hoy;

  const _MapaCalor({required this.porDia, required this.hoy});

  @override
  Widget build(BuildContext context) {
    final esquema = Theme.of(context).colorScheme;
    final inicio = _sumarDias(_lunes(hoy), -21);

    return Column(
      children: [
        Row(
          children: [
            for (final l in _letrasDias)
              Expanded(
                child: Center(
                  child: Text(
                    l,
                    style: TextStyle(
                      fontSize: 11.5,
                      fontWeight: FontWeight.w700,
                      color: esquema.onSurfaceVariant,
                    ),
                  ),
                ),
              ),
          ],
        ),
        for (var semana = 0; semana < 4; semana++)
          Padding(
            padding: const EdgeInsets.only(top: 4),
            child: Row(
              children: [
                for (var dia = 0; dia < 7; dia++)
                  Expanded(
                    child: Padding(
                      padding: const EdgeInsets.all(2),
                      child: _celda(esquema, _sumarDias(inicio, semana * 7 + dia)),
                    ),
                  ),
              ],
            ),
          ),
      ],
    );
  }

  Widget _celda(ColorScheme esquema, DateTime d) {
    final futuro = d.isAfter(hoy);
    final cuenta = porDia[d] ?? 0;
    final esHoy = d == hoy;

    final Color fondo;
    if (futuro) {
      fondo = Colors.transparent;
    } else if (cuenta == 0) {
      fondo = esquema.surfaceContainerHighest;
    } else if (cuenta == 1) {
      fondo = esquema.primary.withValues(alpha: 0.35);
    } else if (cuenta == 2) {
      fondo = esquema.primary.withValues(alpha: 0.65);
    } else {
      fondo = esquema.primary;
    }

    return AspectRatio(
      aspectRatio: 1,
      child: Container(
        alignment: Alignment.center,
        decoration: BoxDecoration(
          color: fondo,
          borderRadius: BorderRadius.circular(10),
          border: Border.all(
            color: esHoy
                ? esquema.primary
                : futuro
                    ? esquema.outlineVariant.withValues(alpha: 0.4)
                    : Colors.transparent,
            width: esHoy ? 2 : 1,
          ),
        ),
        child: Text(
          '${d.day}',
          style: TextStyle(
            fontSize: 11,
            fontWeight: FontWeight.w700,
            color: futuro
                ? esquema.outlineVariant
                : cuenta >= 3
                    ? esquema.onPrimary
                    : esquema.onSurfaceVariant,
          ),
        ),
      ),
    );
  }
}