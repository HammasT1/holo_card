import 'dart:ui' as ui;

import 'package:flutter/foundation.dart';

/// Asset path of the compiled foil fragment shader.
const String kFoilShaderAsset = 'packages/holo_card/shaders/holo_foil.frag';

/// Loads and caches the foil [ui.FragmentProgram].
///
/// The program is loaded once per isolate. If loading fails (unsupported
/// platform or renderer) [load] completes with `null` so callers can fall back
/// to the gradient foil instead of crashing.
abstract final class FoilShader {
  static Future<ui.FragmentProgram?>? _future;

  /// Replaces the loader in tests. Call [resetForTesting] afterwards.
  @visibleForTesting
  static Future<ui.FragmentProgram> Function() loader =
      () => ui.FragmentProgram.fromAsset(kFoilShaderAsset);

  /// The program, or `null` if it could not be loaded.
  static Future<ui.FragmentProgram?> load() => _future ??= _load();

  static Future<ui.FragmentProgram?> _load() async {
    try {
      return await loader();
    } catch (error) {
      debugPrint('holo_card: foil shader unavailable, using fallback ($error)');
      return null;
    }
  }

  /// Forgets the cached program.
  @visibleForTesting
  static void resetForTesting() => _future = null;
}
