class Tarea {
  final String id;
  final String userId;
  String titulo;
  String descripcion;
  bool completada;
  final DateTime? createdAt;
  final DateTime? updatedAt;

  Tarea({
    required this.id,
    required this.userId,
    required this.titulo,
    this.descripcion = '',
    this.completada = false,
    this.createdAt,
    this.updatedAt,
  });

  /// Crea una instancia de Tarea a partir de un mapa JSON (respuesta de Supabase/PostgreSQL).
  factory Tarea.fromJson(Map<String, dynamic> json) {
    return Tarea(
      id: json['id'].toString(),
      userId: json['user_id'].toString(),
      titulo: json['titulo']?.toString() ?? '',
      descripcion: json['descripcion']?.toString() ?? '',
      completada: json['completada'] == true,
      createdAt: json['created_at'] != null 
          ? DateTime.tryParse(json['created_at'].toString()) 
          : null,
      updatedAt: json['updated_at'] != null 
          ? DateTime.tryParse(json['updated_at'].toString()) 
          : null,
    );
  }

  /// Convierte la Tarea a un mapa JSON para enviarla a Supabase/PostgreSQL.
  Map<String, dynamic> toJson() {
    return {
      'user_id': userId,
      'titulo': titulo,
      'descripcion': descripcion,
      'completada': completada,
      // 'id', 'created_at' y 'updated_at' los gestiona automáticamente PostgreSQL/Supabase,
      // pero se pueden incluir si se requiere una operación específica.
    };
  }

  /// Permite clonar la tarea modificando solo los campos requeridos.
  Tarea copyWith({
    String? id,
    String? userId,
    String? titulo,
    String? descripcion,
    bool? completada,
    DateTime? createdAt,
    DateTime? updatedAt,
  }) {
    return Tarea(
      id: id ?? this.id,
      userId: userId ?? this.userId,
      titulo: titulo ?? this.titulo,
      descripcion: descripcion ?? this.descripcion,
      completada: completada ?? this.completada,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }
}
