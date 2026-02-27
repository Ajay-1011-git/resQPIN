import 'dart:async';
import 'package:flutter/services.dart';

/// Service that handles panic mode:
/// - Listens for volume triple-press via platform channel
/// - Controls native audio recording via platform channel
/// - Provides recording file path
class PanicService {
  static final PanicService _instance = PanicService._internal();
  factory PanicService() => _instance;
  PanicService._internal();

  static const _channel = MethodChannel('com.resqpin/panic');
  bool _isRecording = false;
  String? _currentRecordingPath;
  Function()? _onPanicTriggered;

  /// Initialize the panic service and listen for platform events
  void initialize({required Function() onPanicTriggered}) {
    _onPanicTriggered = onPanicTriggered;
    _channel.setMethodCallHandler((call) async {
      if (call.method == 'triggerPanic') {
        _onPanicTriggered?.call();
      }
    });
  }

  /// Start audio recording via native Android MediaRecorder
  Future<bool> startRecording() async {
    if (_isRecording) return true;

    try {
      final path = await _channel.invokeMethod<String>('startRecording');
      if (path != null) {
        _currentRecordingPath = path;
        _isRecording = true;
        return true;
      }
      return false;
    } catch (e) {
      _isRecording = false;
      return false;
    }
  }

  /// Stop recording and return file path
  Future<String?> stopRecording() async {
    if (!_isRecording) return null;

    try {
      final path = await _channel.invokeMethod<String>('stopRecording');
      _isRecording = false;
      return path;
    } catch (e) {
      _isRecording = false;
      return null;
    }
  }

  bool get isRecording => _isRecording;
  String? get currentRecordingPath => _currentRecordingPath;

  void dispose() {
    // Nothing to dispose — native side handles cleanup
  }
}
