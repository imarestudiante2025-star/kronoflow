import 'package:flutter/material.dart';

class PantallaDetalle extends StatelessWidget {
  final String titulo;
  final String categoria;
  final String prioridad;
  final String fecha;
  final bool completada;

  const PantallaDetalle({
    super.key,
    required this.titulo,
    required this.categoria,
    required this.prioridad,
    required this.fecha,
    required this.completada,
  });

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Detalle de tarea'), centerTitle: true),

      body: Center(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(20),
          child: Card(
            elevation: 4,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(16),
            ),
            child: Padding(
              padding: const EdgeInsets.all(24),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  Icon(
                    Icons.task_alt,
                    size: 70,
                    color: Theme.of(context).colorScheme.primary,
                  ),

                  const SizedBox(height: 16),

                  const Text(
                    'Información de la tarea',
                    style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold),
                  ),

                  const SizedBox(height: 24),

                  // Título
                  const Align(
                    alignment: Alignment.centerLeft,
                    child: Text(
                      'Título:',
                      style: TextStyle(fontWeight: FontWeight.bold),
                    ),
                  ),

                  const SizedBox(height: 6),

                  Text(
                    titulo,
                    style: const TextStyle(fontSize: 18),
                    textAlign: TextAlign.center,
                  ),

                  const Divider(height: 30),

                  // Categoría
                  _crearDato(
                    icono: Icons.category,
                    etiqueta: 'Categoría',
                    valor: categoria,
                  ),

                  const SizedBox(height: 18),

                  // Prioridad
                  _crearDato(
                    icono: Icons.flag,
                    etiqueta: 'Prioridad',
                    valor: prioridad,
                  ),

                  const SizedBox(height: 18),

                  // Fecha límite
                  _crearDato(
                    icono: Icons.calendar_today,
                    etiqueta: 'Fecha límite',
                    valor: fecha,
                  ),

                  const SizedBox(height: 24),

                  // Estado de la tarea
                  Chip(
                    avatar: Icon(
                      completada ? Icons.check_circle : Icons.pending_actions,
                      color: completada ? Colors.green : Colors.orange,
                    ),
                    label: Text(completada ? 'Completada' : 'Pendiente'),
                    backgroundColor: completada
                        ? Colors.green.withValues(alpha: 0.12)
                        : Colors.orange.withValues(alpha: 0.12),
                  ),

                  const SizedBox(height: 24),

                  // Botón para regresar
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton.icon(
                      onPressed: () {
                        Navigator.pop(context);
                      },
                      icon: const Icon(Icons.arrow_back),
                      label: const Text('Volver'),
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

  // Método para mostrar cada dato
  Widget _crearDato({
    required IconData icono,
    required String etiqueta,
    required String valor,
  }) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(icono, size: 22),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                etiqueta,
                style: const TextStyle(fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 4),
              Text(valor, style: const TextStyle(fontSize: 16)),
            ],
          ),
        ),
      ],
    );
  }
}
