import 'package:speech_to_text/speech_to_text.dart' as stt;
import 'package:speech_to_text/speech_recognition_result.dart';

/// Service that wraps the speech_to_text plugin for voice-based emergency
/// reporting. This service ONLY handles microphone listening and speech
/// recognition — it does NOT interact with SOS creation.
class VoiceEmergencyService {
  final stt.SpeechToText _speech = stt.SpeechToText();
  bool _isInitialized = false;
  void Function(String status)? _onStatusChange;

  /// Whether the speech recognizer has been initialized successfully.
  bool get isAvailable => _isInitialized;

  /// Whether the microphone is currently listening.
  bool get isListening => _speech.isListening;

  /// Initialize the speech recognizer. Call once before first use.
  /// Returns `true` if speech recognition is available on this device.
  Future<bool> initialize() async {
    if (_isInitialized) {
      print('[VoiceEmergency] Already initialized');
      return true;
    }
    print('[VoiceEmergency] Initializing speech recognition...');
    _isInitialized = await _speech.initialize(
      onError: (error) {
        print('[VoiceEmergency] Speech error: ${error.errorMsg}');
      },
      onStatus: (status) {
        print('[VoiceEmergency] Speech status: $status');
        _onStatusChange?.call(status);
      },
    );
    print('[VoiceEmergency] Initialization result: $_isInitialized');
    return _isInitialized;
  }

  /// Start listening to the microphone.
  ///
  /// [onResult] is called with (recognizedText, isFinal) whenever the
  /// recognizer produces a result (partial or final).
  ///
  /// [onStatusChange] is called with the raw status string whenever the
  /// speech recognizer changes state (e.g. 'listening', 'notListening',
  /// 'done'). Use this to drive UI indicators like the mic icon.
  ///
  /// [localeId] defaults to the device locale. Pass e.g. 'en_IN' to force
  /// a specific locale.
  Future<void> startListening({
    required void Function(String text, bool isFinal) onResult,
    void Function(String status)? onStatusChange,
    String? localeId,
  }) async {
    if (!_isInitialized) {
      final available = await initialize();
      if (!available) {
        print('[VoiceEmergency] Speech recognition not available, aborting listen');
        return;
      }
    }

    _onStatusChange = onStatusChange;

    print('[VoiceEmergency] Warming up microphone...');
    await Future.delayed(const Duration(milliseconds: 500));

    print('[VoiceEmergency] Listening started');
    await _speech.listen(
      onResult: (SpeechRecognitionResult result) {
        if (result.finalResult) {
          print('[VoiceEmergency] Final text: "${result.recognizedWords}"');
        } else {
          print('[VoiceEmergency] Partial text: "${result.recognizedWords}"');
        }
        onResult(result.recognizedWords, result.finalResult);
      },
      listenFor: const Duration(seconds: 15),
      pauseFor: const Duration(seconds: 5),
      localeId: localeId,
      listenOptions: stt.SpeechListenOptions(
        partialResults: true,
        cancelOnError: false,
        listenMode: stt.ListenMode.dictation,
      ),
    );
  }

  /// Stop listening immediately.
  Future<void> stopListening() async {
    if (_speech.isListening) {
      print('[VoiceEmergency] Stopping listener...');
      await _speech.stop();
      print('[VoiceEmergency] Listening stopped');
    }
  }

  /// Cancel listening and discard any partial results.
  Future<void> cancel() async {
    if (_speech.isListening) {
      print('[VoiceEmergency] Cancelling listener...');
      await _speech.cancel();
    }
  }
}
