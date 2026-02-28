import 'dart:async';
import 'package:flutter/services.dart';

/// Service that handles panic mode:
/// - Listens for volume triple-press via platform channel
/// - Controls native audio recording via platform channel
/// - Provides recording file path
/// - Manages RECORD_AUDIO runtime permission
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

  /// Request microphone permission before it's needed (call during app init)
  Future<bool> requestMicPermission() async {
    try {
      final result = await _channel.invokeMethod<dynamic>('requestMicPermission');
      return result == true;
    } catch (e) {
      return false;
    }
  }

  /// Start audio recording via native Android MediaRecorder.
  /// Automatically requests mic permission if not yet granted.
  Future<bool> startRecording() async {
    if (_isRecording) return true;

    try {
      final result = await _channel.invokeMethod<dynamic>('startRecording');
      if (result is String) {
        _currentRecordingPath = result;
        _isRecording = true;
        return true;
      }
      // result == false means permission was denied or failed
      _isRecording = false;
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
