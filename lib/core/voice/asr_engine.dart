/// ASR (Automatic Speech Recognition) engine interface and factory.
///
/// Modeled after ling-base's `voice/recognizer/` package.
/// Each vendor implementation registers with the factory via
/// [AsrEngineFactory.register].

import 'package:flutter/foundation.dart';

import 'package:nudgee/core/voice/voice_types.dart';

/// The core ASR engine interface that all vendors implement.
abstract class AsrEngine {
  /// The vendor identifier.
  AsrVendor get vendor;

  /// Initializes the engine with result and error callbacks.
  void init(AsrResultCallback onResult, AsrErrorCallback onError);

  /// Connects to the ASR service and starts receiving results.
  /// [dialogId] is a unique identifier for the current dialog.
  Future<void> connect(String dialogId);

  /// Whether the engine is actively connected.
  bool get isActive;

  /// Sends audio data for recognition.
  Future<void> sendAudio(Uint8List data);

  /// Signals end of audio stream.
  Future<void> sendEnd();

  /// Stops the connection and cleans up resources.
  Future<void> stop();

  /// Releases all resources.
  void dispose();
}

/// Factory that creates ASR engines by vendor.
class AsrEngineFactory {
  static final AsrEngineFactory _instance = AsrEngineFactory._();
  static AsrEngineFactory get instance => _instance;
  AsrEngineFactory._();

  final Map<AsrVendor, AsrEngine Function(AsrConfig)> _creators = {};

  /// Registers a creator function for a vendor.
  void register(AsrVendor vendor, AsrEngine Function(AsrConfig) creator) {
    _creators[vendor] = creator;
  }

  /// Creates an ASR engine for the given config.
  AsrEngine create(AsrConfig config) {
    final creator = _creators[config.vendor];
    if (creator == null) {
      throw ArgumentError('ASR vendor ${config.vendor} not registered');
    }
    return creator(config);
  }

  /// Returns all registered vendors.
  List<AsrVendor> get supportedVendors => _creators.keys.toList();

  /// Checks if a vendor is registered.
  bool isSupported(AsrVendor vendor) => _creators.containsKey(vendor);
}

/// Convenience function to create an ASR engine.
AsrEngine createAsrEngine(AsrConfig config) =>
    AsrEngineFactory.instance.create(config);
