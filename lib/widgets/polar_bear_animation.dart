import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
// Alias: la API de rive 0.14+ exporta clases con nombres genéricos (File, Factory…).
import 'package:rive/rive.dart' as rive;

import '../theme/app_colors.dart';

/// Nombres de las entradas de la State Machine que Flutter intenta usar.
/// Deben existir EXACTAMENTE así en el .riv. Si alguna no existe se muestra
/// un aviso de depuración y se continúa sin ella.
class PolarBearInputs {
  PolarBearInputs._();
  static const isChecking = 'isChecking'; // Boolean: el oso mira el correo
  static const isHandsUp = 'isHandsUp'; // Boolean: se tapa los ojos
  static const numLook = 'numLook'; // Number: dirección de la mirada
  static const trigSuccess = 'trigSuccess'; // Trigger: login correcto
  static const trigFail = 'trigFail'; // Trigger: login fallido
}

enum _BearStatus { loading, ready, missingAsset, failed }

/// RiveNative.init() es obligatorio en rive 0.14+ antes de usar Rive.
/// Se llama aquí (una sola vez) para no tocar main.dart.
Future<void>? _riveInit;
Future<void> _ensureRiveInit() {
  return _riveInit ??= rive.RiveNative.init().catchError((Object e) {
    _riveInit = null; // permite reintentar si falló
    throw e;
  });
}

/// Carga el .riv real y lo conecta con los campos del formulario.
/// Si el archivo no existe NO se simula ningún personaje.
class PolarBearAnimation extends StatefulWidget {
  const PolarBearAnimation({
    super.key,
    required this.emailFocusNode,
    required this.passwordFocusNode,
    required this.emailController,
    required this.passwordVisible,
    this.assetPath = 'assets/animations/animated_login_bear.riv',

    /// Si es null se usa la State Machine por defecto del artboard principal.
    this.stateMachineName,

    /// Rango real de lookX/lookY en tu .riv (compruébalo en el editor de Rive).
    this.lookMin = 0,
    this.lookMax = 100,

    /// Nº de caracteres del correo a partir del cual la mirada llega al máximo.
    this.maxLookChars = 30,
    this.height = 200,

    /// Espera antes de disparar éxito/fallo, para que el oso termine de bajar
    /// las manos y el disparador no se pierda.
    this.triggerDelay = const Duration(milliseconds: 400),

    /// Reinicia la State Machine antes de cada animación de éxito/fallo, salvo
    /// la primera. Evita que el oso se quede atascado tras la primera animación.
    this.resetBetweenTriggers = true,
  });

  final FocusNode emailFocusNode;
  final FocusNode passwordFocusNode;
  final TextEditingController emailController;
  final ValueListenable<bool> passwordVisible;
  final String assetPath;
  final String? stateMachineName;
  final double lookMin;
  final double lookMax;
  final int maxLookChars;
  final double height;
  final Duration triggerDelay;
  final bool resetBetweenTriggers;

  @override
  State<PolarBearAnimation> createState() => PolarBearAnimationState();
}

class PolarBearAnimationState extends State<PolarBearAnimation> {
  _BearStatus _status = _BearStatus.loading;
  bool _disposed = false;

  rive.File? _file;
  rive.RiveWidgetController? _controller;

  rive.BooleanInput? _isChecking;
  rive.BooleanInput? _isHandsUp;
  rive.NumberInput? _numLook;
  rive.TriggerInput? _trigSuccess;
  rive.TriggerInput? _trigFail;

  Timer? _fireTimer;
  int _fireToken = 0;

  /// true cuando ya se disparó una animación de éxito/fallo y la State Machine
  /// podría haber quedado en un estado final.
  bool _needsReset = false;

  bool get _ready => _status == _BearStatus.ready && !_disposed;

  @override
  void initState() {
    super.initState();
    widget.emailFocusNode.addListener(_syncEmailFocus);
    widget.passwordFocusNode.addListener(_syncPasswordFocus);
    widget.emailController.addListener(_syncLook);
    widget.passwordVisible.addListener(_syncVisibility);
    _load();
  }

  @override
  void dispose() {
    _disposed = true;
    _fireTimer?.cancel();
    widget.emailFocusNode.removeListener(_syncEmailFocus);
    widget.passwordFocusNode.removeListener(_syncPasswordFocus);
    widget.emailController.removeListener(_syncLook);
    widget.passwordVisible.removeListener(_syncVisibility);
    _releaseRive();
    super.dispose();
  }

  // ───────── Utilidades ─────────

  static void _safe(void Function() f) {
    try {
      f();
    } catch (e) {
      debugPrint('PolarBear: error al liberar recursos: $e');
    }
  }

  /// Libera inputs, controlador y archivo (en ese orden). Nunca lanza.
  void _releaseRive() {
    _safe(() => _isChecking?.dispose());
    _safe(() => _isHandsUp?.dispose());
    _safe(() => _numLook?.dispose());
    _safe(() => _trigSuccess?.dispose());
    _safe(() => _trigFail?.dispose());
    _safe(() => _controller?.dispose());
    _safe(() => _file?.dispose());

    _isChecking = null;
    _isHandsUp = null;
    _numLook = null;
    _trigSuccess = null;
    _trigFail = null;
    _controller = null;
    _file = null;
  }

  void _setStatus(_BearStatus s) {
    if (_disposed || !mounted) return;
    setState(() => _status = s);
  }

  // ───────── Animaciones de resultado ─────────

  /// Animación de login correcto (trigSuccess).
  void fireLoginSuccess() => _requestTrigger(PolarBearInputs.trigSuccess);

  /// Animación de login fallido (trigFail).
  void fireLoginFail() => _requestTrigger(PolarBearInputs.trigFail);

  /// Se conserva por compatibilidad: equivale a [fireLoginSuccess].
  void fireLoginTrigger() => fireLoginSuccess();

  void _requestTrigger(String name) {
    if (!_ready) return;
    debugPrint('PolarBear: petición de $name');

    // Si había otra petición pendiente, manda la última.
    _fireTimer?.cancel();
    final token = ++_fireToken;

    // El oso baja las manos y deja de mirar el correo antes del disparo.
    _isHandsUp?.value = false;
    _isChecking?.value = false;

    _fireTimer = Timer(widget.triggerDelay, () async {
      if (!_ready || token != _fireToken) return;

      if (widget.resetBetweenTriggers && _needsReset) {
        await _rebuildController();
        if (!_ready || token != _fireToken) return;
      }

      _fire(name);
      _needsReset = true;
    });
  }

  void _fire(String name) {
    if (!_ready) return;
    final trigger = name == PolarBearInputs.trigFail ? _trigFail : _trigSuccess;
    if (trigger == null) {
      debugPrint('PolarBear: la entrada $name no existe, no se dispara');
      return;
    }
    try {
      trigger.fire();
      debugPrint('PolarBear: disparado $name');
    } catch (e) {
      debugPrint('PolarBear: no se pudo disparar $name: $e');
    }
  }

  // ───────── Carga y reinicio de la State Machine ─────────

  rive.RiveWidgetController _crearControlador(rive.File file) {
    final name = widget.stateMachineName;
    return name == null
        ? rive.RiveWidgetController(file)
        : rive.RiveWidgetController(
            file,
            stateMachineSelector: rive.StateMachineSelector.byName(name),
          );
  }

  /// Busca las entradas por nombre y tipo; si faltan se avisa y se sigue.
  void _enlazarEntradas(rive.RiveWidgetController controller, {bool listar = false}) {
    final sm = controller.stateMachine;
    _isChecking = _input<rive.BooleanInput>(
        () => sm.boolean(PolarBearInputs.isChecking), PolarBearInputs.isChecking, 'Boolean');
    _isHandsUp = _input<rive.BooleanInput>(
        () => sm.boolean(PolarBearInputs.isHandsUp), PolarBearInputs.isHandsUp, 'Boolean');
    _numLook = _input<rive.NumberInput>(
        () => sm.number(PolarBearInputs.numLook), PolarBearInputs.numLook, 'Number');
    _trigSuccess = _input<rive.TriggerInput>(
        () => sm.trigger(PolarBearInputs.trigSuccess), PolarBearInputs.trigSuccess, 'Trigger');
    _trigFail = _input<rive.TriggerInput>(
        () => sm.trigger(PolarBearInputs.trigFail), PolarBearInputs.trigFail, 'Trigger');

    // Diagnóstico: imprime las entradas REALES del .riv (solo en debug).
    if (listar && kDebugMode) {
      try {
        final lista = sm.inputs.map((i) => '${i.name} (${i.runtimeType})').join(', ');
        debugPrint('PolarBear: entradas reales de la State Machine -> $lista');
      } catch (e) {
        debugPrint('PolarBear: no se pudieron listar las entradas: $e');
      }
    }
  }

  /// Crea una State Machine nueva (el oso vuelve a su estado inicial) y
  /// libera la anterior cuando la nueva ya se está dibujando.
  Future<void> _rebuildController() async {
    final file = _file;
    if (file == null || !_ready) return;
    debugPrint('PolarBear: reiniciando la State Machine');

    final oldChecking = _isChecking;
    final oldHandsUp = _isHandsUp;
    final oldLook = _numLook;
    final oldSuccess = _trigSuccess;
    final oldFail = _trigFail;
    final oldController = _controller;

    try {
      final nuevo = _crearControlador(file);
      _controller = nuevo;
      _enlazarEntradas(nuevo);
      _needsReset = false;
      if (mounted) setState(() {});
    } catch (e, st) {
      debugPrint('PolarBear: no se pudo reiniciar la State Machine: $e\n$st');
      return;
    }

    // Espera a que el widget nuevo se dibuje antes de liberar el anterior.
    await WidgetsBinding.instance.endOfFrame;

    _safe(() => oldChecking?.dispose());
    _safe(() => oldHandsUp?.dispose());
    _safe(() => oldLook?.dispose());
    _safe(() => oldSuccess?.dispose());
    _safe(() => oldFail?.dispose());
    _safe(() => oldController?.dispose());

    if (!_ready) return;
    _isHandsUp?.value = false;
    _isChecking?.value = false;
    _syncLook();

    // Un instante para que la nueva State Machine arranque antes del disparo.
    await Future<void>.delayed(const Duration(milliseconds: 60));
  }

  Future<void> _load() async {
    try {
      // 1) ¿Existe el asset declarado en pubspec.yaml?
      final manifest = await AssetManifest.loadFromAssetBundle(rootBundle);
      if (_disposed) return;
      if (!manifest.listAssets().contains(widget.assetPath)) {
        debugPrint('PolarBear: no existe ${widget.assetPath} '
            '(falta el archivo o no está declarado en pubspec.yaml)');
        _setStatus(_BearStatus.missingAsset);
        return;
      }

      // 2) Inicializar el runtime de Rive y cargar el archivo.
      await _ensureRiveInit();
      if (_disposed) return;

      final file = await rive.File.asset(
        widget.assetPath,
        riveFactory: rive.Factory.rive,
      );
      if (file == null) {
        debugPrint('PolarBear: File.asset devolvió null para ${widget.assetPath}');
        _setStatus(_BearStatus.failed);
        return;
      }
      if (_disposed) {
        file.dispose();
        return;
      }
      _file = file;

      // 3) Controlador (artboard + State Machine) y entradas.
      final controller = _crearControlador(file);
      _controller = controller;
      _enlazarEntradas(controller, listar: true);

      if (_disposed) {
        _releaseRive();
        return;
      }
      _setStatus(_BearStatus.ready);
      _syncEmailFocus();
      _syncPasswordFocus();
      _syncVisibility();
      _syncLook();
    } catch (e, st) {
      debugPrint('PolarBear: error al cargar el .riv: $e\n$st');
      _releaseRive();
      _setStatus(_BearStatus.failed);
    }
  }

  T? _input<T>(T? Function() read, String name, String tipo) {
    try {
      final input = read();
      if (input == null) {
        debugPrint('PolarBear: la entrada "$name" ($tipo) no existe en el .riv; se ignora');
      }
      return input;
    } catch (e) {
      debugPrint('PolarBear: no se pudo leer la entrada "$name" ($tipo): $e');
      return null;
    }
  }

  // ───────── Sincronización con el formulario ─────────

  // Correo con foco -> el oso "revisa" (isChecking).
  void _syncEmailFocus() {
    if (!_ready) return;
    _isChecking?.value = widget.emailFocusNode.hasFocus;
  }

  // Contraseña con foco -> se tapa los ojos, salvo que la contraseña sea visible.
  void _syncPasswordFocus() => _syncHandsUp();
  void _syncVisibility() => _syncHandsUp();

  void _syncHandsUp() {
    if (!_ready) return;
    _isHandsUp?.value = widget.passwordFocusNode.hasFocus && !widget.passwordVisible.value;
  }

  // La mirada sigue la longitud del correo (numLook, rango lookMin..lookMax).
  void _syncLook() {
    if (!_ready) return;
    final span = widget.lookMax - widget.lookMin;
    final t = math.min(widget.emailController.text.length / widget.maxLookChars, 1.0);
    _numLook?.value = widget.lookMin + span * t;
  }

  // ───────── Interfaz ─────────

  @override
  Widget build(BuildContext context) {
    final controller = _controller;

    return SizedBox(
      height: widget.height,
      width: double.infinity,
      child: switch (_status) {
        _BearStatus.ready when controller != null => Semantics(
            label: 'Oso polar guardián de KronoFlow',
            image: true,
            child: rive.RiveWidget(
              key: ObjectKey(controller),
              controller: controller,
              fit: rive.Fit.contain,
            ),
          ),
        _BearStatus.loading => const Center(
            child: SizedBox(
              width: 24,
              height: 24,
              child: CircularProgressIndicator(strokeWidth: 2, color: AppColors.textOnDark),
            ),
          ),
        // Sin archivo real no se dibuja ningún personaje.
        _ => kDebugMode
            ? _DebugAviso(assetPath: widget.assetPath, status: _status)
            : const SizedBox.shrink(),
      },
    );
  }
}

class _DebugAviso extends StatelessWidget {
  const _DebugAviso({required this.assetPath, required this.status});
  final String assetPath;
  final _BearStatus status;

  @override
  Widget build(BuildContext context) {
    final texto = status == _BearStatus.missingAsset
        ? 'Falta $assetPath\n(o no está declarado en pubspec.yaml)'
        : 'No se pudo cargar el .riv.\nRevisa la consola.';
    return Center(
      child: Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          border: Border.all(color: AppColors.textOnDarkSoft),
          borderRadius: BorderRadius.circular(12),
        ),
        child: Text(
          texto,
          textAlign: TextAlign.center,
          style: TextStyle(color: AppColors.textOnDarkSoft, fontSize: 12),
        ),
      ),
    );
  }
}