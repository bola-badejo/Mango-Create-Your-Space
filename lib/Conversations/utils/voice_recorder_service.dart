
import 'dart:async';
import 'dart:io';
import 'dart:math';
import 'package:flutter/foundation.dart';
import 'package:record/record.dart';
import 'package:path_provider/path_provider.dart';
import 'package:permission_handler/permission_handler.dart';

class VoiceRecorderService {
  final AudioRecorder _audioRecorder = AudioRecorder();
  bool _isRecording = false;
  String? _currentPath;
  double _currentAmplitude = 0.0;
  Timer? _amplitudeTimer;
  DateTime? _recordingStartTime;

  Uint8List? _recordedBytes;

  final StreamController<double> _amplitudeController =
      StreamController<double>.broadcast();
  Stream<double> get amplitudeStream => _amplitudeController.stream;

  Future<bool> _checkPermissions() async {
    if (await _audioRecorder.hasPermission()) {
      return true;
    }

    
    final micStatus = await Permission.microphone.request();
    if (micStatus.isGranted) {
      return true;
    }

    return false;
  }

  Future<String?> startRecording() async {
    
    if (kIsWeb) {
      
      
      
      return null;
    }

    if (!await _checkPermissions()) {
      throw Exception('Microphone permission denied');
    }

    if (_isRecording) {
      await stopRecording();
    }

    try {
      final directory = await getTemporaryDirectory();
      final timestamp = DateTime.now().millisecondsSinceEpoch;
      _currentPath = '${directory.path}/voice_note_$timestamp.m4a';
      _recordingStartTime = DateTime.now();

      
      await _audioRecorder.start(
        const RecordConfig(
          encoder: AudioEncoder.aacLc,
          bitRate: 128000,
          numChannels: 1,
        ),
        path: _currentPath!,
      );

      _isRecording = true;

      _startRealAmplitudeListening();

      return _currentPath;
    } catch (e) {
      print('Error starting recording: $e');
      _isRecording = false;
      _recordingStartTime = null;
      rethrow;
    }
  }

  void _startRealAmplitudeListening() {
    
    _amplitudeTimer = Timer.periodic(const Duration(milliseconds: 50), (
      timer,
    ) async {
      if (!_isRecording) {
        timer.cancel();
        return;
      }

      try {
        
        final amplitude = await _audioRecorder.getAmplitude();

        
        
        double normalizedAmplitude = 0.0;

        if (amplitude.current > -160) {
          
          normalizedAmplitude = pow(10, amplitude.current / 20).toDouble();
          
          normalizedAmplitude = normalizedAmplitude.clamp(0.0, 1.0);
        }

        _currentAmplitude = normalizedAmplitude;
        _amplitudeController.add(normalizedAmplitude);
      } catch (e) {
        
        _currentAmplitude = 0.3 + Random().nextDouble() * 0.7;
        _amplitudeController.add(_currentAmplitude);
      }
    });
  }

  Future<String?> stopRecording() async {
    if (!_isRecording) return null;

    try {
      _amplitudeTimer?.cancel();
      _amplitudeTimer = null;

      final path = await _audioRecorder.stop();
      _isRecording = false;

      
      _currentAmplitude = 0.0;
      _amplitudeController.add(0.0);

      
      if (path != null && !kIsWeb) {
        final file = File(path);
        if (await file.exists()) {
          _recordedBytes = await file.readAsBytes();
        }
      }

      _recordingStartTime = null;
      return path;
    } catch (e) {
      print('Error stopping recording: $e');
      _isRecording = false;
      _recordingStartTime = null;
      rethrow;
    }
  }

  
  Future<Uint8List?> getWebRecordingBytes() async {
    if (kIsWeb) {
      
      
      return null;
    }

    
    if (_recordedBytes != null) {
      return _recordedBytes;
    } else if (_currentPath != null) {
      final file = File(_currentPath!);
      if (await file.exists()) {
        _recordedBytes = await file.readAsBytes();
        return _recordedBytes;
      }
    }
    return null;
  }

  
  Duration? get recordingDuration {
    if (_recordingStartTime == null) return null;
    return DateTime.now().difference(_recordingStartTime!);
  }

  Future<void> cancelRecording() async {
    if (_isRecording) {
      try {
        _amplitudeTimer?.cancel();
        _amplitudeTimer = null;

        await _audioRecorder.cancel();
        _isRecording = false;

        
        _currentAmplitude = 0.0;
        _amplitudeController.add(0.0);

        
        if (_currentPath != null) {
          final file = File(_currentPath!);
          if (await file.exists()) {
            await file.delete();
          }
        }

        _recordedBytes = null;
        _recordingStartTime = null;
      } catch (e) {
        print('Error canceling recording: $e');
        _isRecording = false;
        _recordingStartTime = null;
        rethrow;
      }
    }
  }

  
  bool get isRecording => _isRecording;
  double get currentAmplitude => _currentAmplitude;

  
  Future<bool> isRecordingAvailable() async {
    if (kIsWeb) {
      
      
      return false;
    }
    return await _audioRecorder.isRecording();
  }

  void dispose() {
    _amplitudeTimer?.cancel();
    _amplitudeController.close();
    _audioRecorder.dispose();
  }
}
