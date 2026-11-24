enum Prioridad {
  alta('Alta'),
  media('Media'),
  baja('Baja');

  final String etiqueta;
  const Prioridad(this.etiqueta);

  static Prioridad desdeTexto(String? v) =>
      Prioridad.values.firstWhere((p) => p.name == v, orElse: () => Prioridad.media);
}

class Tarea {
  final String id;
  final String userId;
  String titulo;
  String descripcion;
  bool completada;
  Prioridad prioridad;
  DateTime? fechaLimite;
  final DateTime? createdAt;
  final DateTime? updatedAt;

  Tarea({
    required this.id,
    required this.userId,
    required this.titulo,
    this.descripcion = '',
    this.completada = false,
    this.prioridad = Prioridad.media,
    this.fechaLimite,
    this.createdAt,
    this.updatedAt,
  });

  factory Tarea.fromJson(Map<String, dynamic> json) {
    return Tarea(
      id: json['id'].toString(),
      userId: json['user_id'].toString(),
      titulo: json['titulo']?.toString() ?? '',
      descripcion: json['descripcion']?.toString() ?? '',
      completada: json['completada'] == true,
      prioridad: Prioridad.desdeTexto(json['prioridad']?.toString()),
      fechaLimite: json['fecha_limite'] != null
          ? DateTime.tryParse(json['fecha_limite'].toString())?.toLocal()
          : null,
      createdAt: json['created_at'] != null
          ? DateTime.tryParse(json['created_at'].toString())
          : null,
      updatedAt: json['updated_at'] != null
          ? DateTime.tryParse(json['updated_at'].toString())
          : null,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'user_id': userId,
      'titulo': titulo,
      'descripcion': descripcion,
      'completada': completada,
      'prioridad': prioridad.name,
      'fecha_limite': fechaLimite?.toUtc().toIso8601String(),
    };
  }

  Tarea copyWith({
    String? id,
    String? userId,
    String? titulo,
    String? descripcion,
    bool? completada,
    Prioridad? prioridad,
    DateTime? fechaLimite,
    bool quitarFecha = false,
    DateTime? createdAt,
    DateTime? updatedAt,
  }) {
    return Tarea(
      id: id ?? this.id,
      userId: userId ?? this.userId,
      titulo: titulo ?? this.titulo,
      descripcion: descripcion ?? this.descripcion,
      completada: completada ?? this.completada,
      prioridad: prioridad ?? this.prioridad,
      fechaLimite: quitarFecha ? null : (fechaLimite ?? this.fechaLimite),
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }
}