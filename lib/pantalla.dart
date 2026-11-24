import 'package:flutter/material.dart';

import 'models/tarea.dart';

/// Colores y textos compartidos por la tarjeta y la pantalla de detalle.
class EstiloTarea {
  static const exito = Color(0xFF2E9E6B);
  static const aviso = Color(0xFFE0922F);
  static const peligro = Color(0xFFD64545);
  static const neutro = Color(0xFF5B8BD0);

  static ({Color color, IconData icono}) prioridad(Prioridad p) => switch (p) {
        Prioridad.alta => (color: peligro, icono: Icons.keyboard_double_arrow_up_rounded),
        Prioridad.media => (color: aviso, icono: Icons.drag_handle_rounded),
        Prioridad.baja => (color: exito, icono: Icons.keyboard_double_arrow_down_rounded),
      };

  static const _meses = [
    'ene', 'feb', 'mar', 'abr', 'may', 'jun',
    'jul', 'ago', 'sep', 'oct', 'nov', 'dic',
  ];

  static String fechaCorta(DateTime f) => '${f.day} ${_meses[f.month - 1]} ${f.year}';

  /// Texto de urgencia ("Vence mañana", "Venció hace 2 días"…).
  static ({String texto, Color color}) urgencia(DateTime f, bool completada) {
    if (completada) return (texto: 'Tarea cerrada', color: exito);

    final hoy = DateTime.now();
    final h0 = DateTime(hoy.year, hoy.month, hoy.day);
    final f0 = DateTime(f.year, f.month, f.day);
    final dias = f0.difference(h0).inDays;

    if (dias < 0) {
      final n = -dias;
      return (texto: 'Venció hace $n ${n == 1 ? 'día' : 'días'}', color: peligro);
    }
    if (dias == 0) return (texto: 'Vence hoy', color: aviso);
    if (dias == 1) return (texto: 'Vence mañana', color: aviso);
    if (dias <= 7) return (texto: 'Vence en $dias días', color: neutro);
    return (texto: 'Faltan $dias días', color: neutro);
  }
}

/// Detalle de una tarea. Cada acción cierra la pantalla y luego se ejecuta.
class PantallaDetalle extends StatelessWidget {
  final Tarea tarea;
  final VoidCallback? onAlternarEstado;
  final VoidCallback? onEditar;
  final VoidCallback? onEliminar;

  const PantallaDetalle({
    super.key,
    required this.tarea,
    this.onAlternarEstado,
    this.onEditar,
    this.onEliminar,
  });

  static const _marino = Color(0xFF1D385B);
  static const _marinoClaro = Color(0xFF2B4F7E);
  static const _cian = Color(0xFF6FE3F0);

  void _cerrarYEjecutar(BuildContext context, VoidCallback? accion) {
    Navigator.pop(context);
    accion?.call();
  }

  Future<void> _confirmarEliminar(BuildContext context) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: const Text('¿Eliminar esta tarea?'),
        content: const Text('Podrás deshacerlo unos segundos después de eliminarla.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Cancelar'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(ctx, true),
            style: FilledButton.styleFrom(backgroundColor: EstiloTarea.peligro),
            child: const Text('Eliminar'),
          ),
        ],
      ),
    );
    if (ok == true && context.mounted) _cerrarYEjecutar(context, onEliminar);
  }

  @override
  Widget build(BuildContext context) {
    final prio = EstiloTarea.prioridad(tarea.prioridad);
    final fecha = tarea.fechaLimite;
    final urgencia = fecha == null ? null : EstiloTarea.urgencia(fecha, tarea.completada);

    final datos = <Widget>[
      _TarjetaDato(
        icono: prio.icono,
        etiqueta: 'Prioridad',
        valor: tarea.prioridad.etiqueta,
        colorAcento: prio.color,
        comoInsignia: true,
      ),
      _TarjetaDato(
        icono: Icons.event_rounded,
        etiqueta: 'Fecha límite',
        valor: fecha != null ? EstiloTarea.fechaCorta(fecha) : 'Sin fecha',
        colorAcento: urgencia?.color,
        pie: urgencia?.texto,
      ),
      if (tarea.descripcion.trim().isNotEmpty)
        _TarjetaDato(
          icono: Icons.notes_rounded,
          etiqueta: 'Descripción',
          valor: tarea.descripcion,
          comoTexto: true,
        ),
      if (tarea.createdAt != null)
        _TarjetaDato(
          icono: Icons.history_rounded,
          etiqueta: 'Creada',
          valor: EstiloTarea.fechaCorta(tarea.createdAt!.toLocal()),
        ),
    ];

    return Scaffold(
      backgroundColor: Theme.of(context).colorScheme.surface,
      body: Column(
        children: [
          _Cabecera(titulo: tarea.titulo, completada: tarea.completada),
          Expanded(
            child: ListView.separated(
              padding: const EdgeInsets.fromLTRB(20, 24, 20, 16),
              itemCount: datos.length,
              separatorBuilder: (_, __) => const SizedBox(height: 12),
              itemBuilder: (context, i) => _Entrada(indice: i, child: datos[i]),
            ),
          ),
          _BarraAcciones(
            completada: tarea.completada,
            onAlternar: onAlternarEstado == null
                ? null
                : () => _cerrarYEjecutar(context, onAlternarEstado),
            onEditar: onEditar == null ? null : () => _cerrarYEjecutar(context, onEditar),
            onEliminar: onEliminar == null ? null : () => _confirmarEliminar(context),
            onVolver: () => Navigator.pop(context),
          ),
        ],
      ),
    );
  }
}

class _Cabecera extends StatelessWidget {
  const _Cabecera({required this.titulo, required this.completada});

  final String titulo;
  final bool completada;

  @override
  Widget build(BuildContext context) {
    final color = completada ? EstiloTarea.exito : PantallaDetalle._cian;

    return Container(
      width: double.infinity,
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [PantallaDetalle._marino, PantallaDetalle._marinoClaro],
        ),
        borderRadius: BorderRadius.vertical(bottom: Radius.circular(32)),
      ),
      child: Stack(
        children: [
          Positioned(
            right: -24,
            bottom: -30,
            child: IgnorePointer(
              child: Icon(
                completada ? Icons.check_circle_rounded : Icons.timelapse_rounded,
                size: 170,
                color: Colors.white.withValues(alpha: 0.06),
              ),
            ),
          ),
          SafeArea(
            bottom: false,
            child: Padding(
              padding: const EdgeInsets.fromLTRB(8, 4, 20, 28),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  IconButton(
                    tooltip: 'Volver',
                    onPressed: () => Navigator.pop(context),
                    icon: const Icon(Icons.arrow_back_rounded, color: Colors.white),
                  ),
                  Padding(
                    padding: const EdgeInsets.only(left: 12),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                          decoration: BoxDecoration(
                            color: color.withValues(alpha: 0.18),
                            borderRadius: BorderRadius.circular(999),
                            border: Border.all(color: color.withValues(alpha: 0.5)),
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(
                                completada
                                    ? Icons.check_circle_rounded
                                    : Icons.pending_actions_rounded,
                                size: 16,
                                color: color,
                              ),
                              const SizedBox(width: 6),
                              Text(
                                completada ? 'Completada' : 'Pendiente',
                                style: TextStyle(
                                  fontSize: 13,
                                  fontWeight: FontWeight.w700,
                                  color: color,
                                ),
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(height: 14),
                        Text(
                          titulo,
                          maxLines: 4,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                            fontSize: 28,
                            height: 1.15,
                            fontWeight: FontWeight.w800,
                            letterSpacing: -0.5,
                            color: Colors.white,
                            decoration: completada ? TextDecoration.lineThrough : null,
                            decorationColor: Colors.white54,
                          ),
                        ),
                      ],
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

class _TarjetaDato extends StatelessWidget {
  const _TarjetaDato({
    required this.icono,
    required this.etiqueta,
    required this.valor,
    this.colorAcento,
    this.comoInsignia = false,
    this.comoTexto = false,
    this.pie,
  });

  final IconData icono;
  final String etiqueta;
  final String valor;
  final Color? colorAcento;
  final bool comoInsignia;
  final bool comoTexto;
  final String? pie;

  @override
  Widget build(BuildContext context) {
    final esquema = Theme.of(context).colorScheme;
    final acento = colorAcento ?? esquema.primary;

    return Semantics(
      label: '$etiqueta: $valor${pie != null ? ', $pie' : ''}',
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: esquema.surfaceContainerHighest.withValues(alpha: 0.55),
          borderRadius: BorderRadius.circular(18),
          border: Border.all(color: esquema.outlineVariant.withValues(alpha: 0.6)),
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              width: 46,
              height: 46,
              decoration: BoxDecoration(
                color: acento.withValues(alpha: 0.14),
                borderRadius: BorderRadius.circular(14),
              ),
              child: Icon(icono, size: 24, color: acento),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    etiqueta,
                    style: TextStyle(
                      fontSize: 12.5,
                      fontWeight: FontWeight.w600,
                      color: esquema.onSurfaceVariant,
                    ),
                  ),
                  const SizedBox(height: 4),
                  if (comoInsignia)
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                      decoration: BoxDecoration(
                        color: acento.withValues(alpha: 0.14),
                        borderRadius: BorderRadius.circular(999),
                      ),
                      child: Text(
                        valor,
                        style: TextStyle(
                          fontSize: 15,
                          fontWeight: FontWeight.w800,
                          color: acento,
                        ),
                      ),
                    )
                  else
                    Text(
                      valor,
                      style: comoTexto
                          ? const TextStyle(fontSize: 15, height: 1.4)
                          : const TextStyle(fontSize: 17, fontWeight: FontWeight.w700),
                    ),
                  if (pie != null) ...[
                    const SizedBox(height: 6),
                    Text(
                      pie!,
                      style: TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w600,
                        color: acento,
                      ),
                    ),
                  ],
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _Entrada extends StatelessWidget {
  const _Entrada({required this.indice, required this.child});

  final int indice;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    if (MediaQuery.disableAnimationsOf(context)) return child;

    return TweenAnimationBuilder<double>(
      tween: Tween(begin: 0, end: 1),
      duration: Duration(milliseconds: 380 + indice * 120),
      curve: Curves.easeOutCubic,
      builder: (context, t, hijo) => Opacity(
        opacity: t,
        child: Transform.translate(offset: Offset(0, (1 - t) * 18), child: hijo),
      ),
      child: child,
    );
  }
}

class _BarraAcciones extends StatelessWidget {
  const _BarraAcciones({
    required this.completada,
    required this.onAlternar,
    required this.onEditar,
    required this.onEliminar,
    required this.onVolver,
  });

  final bool completada;
  final VoidCallback? onAlternar;
  final VoidCallback? onEditar;
  final VoidCallback? onEliminar;
  final VoidCallback onVolver;

  Widget _botonIcono(String tooltip, IconData icono, Color color, VoidCallback onTap) {
    return Tooltip(
      message: tooltip,
      child: SizedBox(
        height: 52,
        width: 52,
        child: OutlinedButton(
          onPressed: onTap,
          style: OutlinedButton.styleFrom(
            padding: EdgeInsets.zero,
            foregroundColor: color,
            side: BorderSide(color: color.withValues(alpha: 0.5)),
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          ),
          child: Icon(icono),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final esquema = Theme.of(context).colorScheme;

    return SafeArea(
      top: false,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(20, 4, 20, 16),
        child: Row(
          children: [
            if (onEliminar != null) ...[
              _botonIcono('Eliminar tarea', Icons.delete_outline_rounded,
                  EstiloTarea.peligro, onEliminar!),
              const SizedBox(width: 12),
            ],
            if (onEditar != null) ...[
              _botonIcono('Editar tarea', Icons.edit_outlined, esquema.primary, onEditar!),
              const SizedBox(width: 12),
            ],
            Expanded(
              child: SizedBox(
                height: 52,
                child: onAlternar != null
                    ? FilledButton.icon(
                        onPressed: onAlternar,
                        style: FilledButton.styleFrom(
                          backgroundColor:
                              completada ? esquema.secondary : PantallaDetalle._marino,
                          foregroundColor: Colors.white,
                          shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(16)),
                        ),
                        icon: Icon(completada ? Icons.undo_rounded : Icons.check_rounded),
                        label: Text(
                          completada ? 'Reabrir tarea' : 'Marcar como hecha',
                          style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w700),
                        ),
                      )
                    : FilledButton.icon(
                        onPressed: onVolver,
                        icon: const Icon(Icons.arrow_back_rounded),
                        label: const Text('Volver a mis tareas'),
                      ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}