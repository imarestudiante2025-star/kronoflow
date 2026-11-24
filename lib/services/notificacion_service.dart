import 'package:flutter/foundation.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:timezone/data/latest.dart' as tzdata;
import 'package:timezone/timezone.dart' as tz;

import '../models/tarea.dart';

/// Recordatorios locales de tareas. Se programan en el propio dispositivo,
/// así que funcionan sin conexión y sin servidor.
///
/// Estrategia: cada vez que cambia la lista de tareas se cancelan todos los
/// avisos pendientes y se vuelven a programar desde cero. Así nunca quedan
/// avisos huérfanos de tareas eliminadas, completadas o con otra fecha.
class NotificacionService {
  NotificacionService._();
  static final instancia = NotificacionService._();

  /// Hora del aviso el mismo día que vence la tarea.
  static const _horaDelDia = 9;

  /// Hora del aviso la tarde anterior.
  static const _horaPrevia = 18;

  /// iOS solo admite 64 avisos pendientes por app.
  static const _maximo = 60;

  /// Id reservado para el aviso de fin de sesión de enfoque.
  static const _idEnfoque = 9000;

  static const _detallesEnfoque = NotificationDetails(
    android: AndroidNotificationDetails(
      'enfoque',
      'Sesiones de enfoque',
      channelDescription: 'Aviso cuando termina una sesión de enfoque o un descanso',
      importance: Importance.high,
      priority: Priority.high,
    ),
    iOS: DarwinNotificationDetails(),
  );

  static const _detalles = NotificationDetails(
    android: AndroidNotificationDetails(
      'tareas',
      'Recordatorios de tareas',
      channelDescription: 'Avisos de las tareas que vencen hoy o mañana',
      importance: Importance.high,
      priority: Priority.high,
    ),
    iOS: DarwinNotificationDetails(),
  );

  final _plugin = FlutterLocalNotificationsPlugin();
  bool _listo = false;

  /// Se llama con el id de la tarea cuando el usuario toca un aviso.
  void Function(String idTarea)? alAbrirTarea;

  Future<void> inicializar() async {
    if (_listo || kIsWeb) return;

    tzdata.initializeTimeZones();

    await _plugin.initialize(
      settings: const InitializationSettings(
        android: AndroidInitializationSettings('@mipmap/ic_launcher'),
        // El permiso se pide más tarde, cuando el usuario pone su primera fecha.
        iOS: DarwinInitializationSettings(
          requestAlertPermission: false,
          requestBadgePermission: false,
          requestSoundPermission: false,
        ),
      ),
      onDidReceiveNotificationResponse: (respuesta) {
        final id = respuesta.payload;
        if (id != null) alAbrirTarea?.call(id);
      },
    );
    _listo = true;
  }

  /// Pide permiso al usuario. Es seguro llamarlo varias veces: si ya lo
  /// concedió, no vuelve a mostrar el diálogo.
  Future<bool> pedirPermiso() async {
    if (!_listo) return false;
    try {
      final android = _plugin.resolvePlatformSpecificImplementation<
          AndroidFlutterLocalNotificationsPlugin>();
      final ios = _plugin.resolvePlatformSpecificImplementation<
          IOSFlutterLocalNotificationsPlugin>();

      final a = await android?.requestNotificationsPermission();
      final i = await ios?.requestPermissions(alert: true, badge: true, sound: true);
      return a ?? i ?? false;
    } catch (e) {
      debugPrint('Error al pedir permiso de notificaciones: $e');
      return false;
    }
  }

  /// Si la app se abrió tocando un aviso, devuelve el id de esa tarea.
  Future<String?> idDeLanzamiento() async {
    if (!_listo) return null;
    final detalles = await _plugin.getNotificationAppLaunchDetails();
    if (detalles?.didNotificationLaunchApp ?? false) {
      return detalles?.notificationResponse?.payload;
    }
    return null;
  }

  /// Reprograma los avisos a partir de la lista actual de tareas.
  Future<void> sincronizar(List<Tarea> tareas) async {
    if (!_listo) return;

    try {
      // Solo se cancelan los avisos de tareas (ids 0 a _maximo - 1), para no
      // borrar el aviso de una sesión de enfoque que esté en marcha.
      final programados = await _plugin.pendingNotificationRequests();
      for (final p in programados) {
        if (p.id < _maximo) await _plugin.cancel(id: p.id);
      }

      final ahora = DateTime.now();
      final avisos = <_Aviso>[];

      for (final t in tareas) {
        final limite = t.fechaLimite?.toLocal();
        if (t.completada || limite == null) continue;

        avisos.add(_Aviso(
          DateTime(limite.year, limite.month, limite.day, _horaDelDia),
          'Vence hoy',
          t,
        ));
        avisos.add(_Aviso(
          DateTime(limite.year, limite.month, limite.day - 1, _horaPrevia),
          'Vence mañana',
          t,
        ));
      }

      // Solo los futuros, los más cercanos primero.
      final pendientes = avisos.where((a) => a.cuando.isAfter(ahora)).toList()
        ..sort((a, b) => a.cuando.compareTo(b.cuando));

      for (var i = 0; i < pendientes.length && i < _maximo; i++) {
        final aviso = pendientes[i];
        await _plugin.zonedSchedule(
          id: i,
          title: aviso.titulo,
          body: aviso.tarea.titulo,
          // Instante absoluto: para avisos de una sola vez no hace falta
          // conocer la zona horaria del dispositivo.
          scheduledDate: tz.TZDateTime.from(aviso.cuando, tz.UTC),
          notificationDetails: _detalles,
          // «inexact» evita pedir el permiso de alarmas exactas en Android.
          androidScheduleMode: AndroidScheduleMode.inexactAllowWhileIdle,
          payload: aviso.tarea.id.toString(),
        );
      }
    } catch (e) {
      debugPrint('Error al programar avisos: $e');
    }
  }

  /// Programa el aviso de fin de una sesión de enfoque (o de un descanso).
  Future<void> programarFinEnfoque({
    required DateTime cuando,
    required String titulo,
    required String cuerpo,
    String? payload,
  }) async {
    if (!_listo) return;
    try {
      await _plugin.cancel(id: _idEnfoque);
      await _plugin.zonedSchedule(
        id: _idEnfoque,
        title: titulo,
        body: cuerpo,
        scheduledDate: tz.TZDateTime.from(cuando, tz.UTC),
        notificationDetails: _detallesEnfoque,
        androidScheduleMode: AndroidScheduleMode.inexactAllowWhileIdle,
        payload: payload,
      );
    } catch (e) {
      debugPrint('Error al programar el aviso de enfoque: $e');
    }
  }

  Future<void> cancelarFinEnfoque() async {
    if (!_listo) return;
    try {
      await _plugin.cancel(id: _idEnfoque);
    } catch (e) {
      debugPrint('Error al cancelar el aviso de enfoque: $e');
    }
  }

  /// Solo para pruebas: muestra un aviso al instante.
  Future<void> probarYa() async {
    if (!_listo) return;
    await _plugin.show(
      id: 9998,
      title: 'Vence hoy',
      body: 'Así se verá tu recordatorio',
      notificationDetails: _detalles,
    );
  }

  /// Solo para pruebas: lanza un aviso dentro de 5 segundos.
  Future<void> probar() async {
    if (!_listo) return;
    await _plugin.zonedSchedule(
      id: 9999,
      title: 'Vence hoy',
      body: 'Así se verá tu recordatorio',
      scheduledDate: tz.TZDateTime.from(
        DateTime.now().add(const Duration(seconds: 5)),
        tz.UTC,
      ),
      notificationDetails: _detalles,
      androidScheduleMode: AndroidScheduleMode.inexactAllowWhileIdle,
    );
  }
}

class _Aviso {
  final DateTime cuando;
  final String titulo;
  final Tarea tarea;

  const _Aviso(this.cuando, this.titulo, this.tarea);
}