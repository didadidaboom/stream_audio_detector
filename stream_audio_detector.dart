import 'dart:async';
import 'dart:typed_data';
import 'dart:math';
import 'package:flutter/foundation.dart';
import 'package:flutter_sound/flutter_sound.dart';

/// Stream Audio Detector - Real Audio Processing
/// 使用真实的音频录制和播放功能，无需权限处理
/// 基于 flutter_sound 的流处理实现
class StreamAudioDetector {
  // State management
  bool _isInitialized = false;
  bool _isListening = false;
  
  // Callbacks
  VoidCallback? onStrikeDetected;
  Function(String)? onError;
  Function(String)? onStatusUpdate;
  
  // Audio processing
  final FlutterSoundRecorder _recorder = FlutterSoundRecorder();
  final FlutterSoundPlayer _player = FlutterSoundPlayer();
  
  // Stream subscriptions
  StreamSubscription? _amplitudeSubscription;
  StreamSubscription? _audioDataSubscription;
  
  // Audio data buffers
  List<List<Float32List>> _audioBuffer = [];
  List<Uint8List> _audioBufferUint8 = [];
  
  // Stream controllers
  StreamController<List<Float32List>>? _audioDataController;
  StreamController<Uint8List>? _audioDataControllerUint8;
  
  // Audio configuration
  static const int _sampleRate = 48000;
  static const int _numChannels = 1; // 单声道
  static const int _bufferSize = 1024;
  static const Duration _subscriptionDuration = Duration(milliseconds: 100);
  
  // Detection parameters
  double _currentDb = 0.0;
  int _hitCount = 0;
  DateTime? _lastStrikeTime;
  static const double _dbThreshold = 50.0;
  static const int _minStrikeInterval = 200;
  
  // Audio processing mode
  bool _interleaved = false;
  Codec _codecSelected = Codec.pcmFloat32;
  
  /// Initialize detector
  Future<bool> initialize() async {
    try {
      if (_isInitialized) {
        _updateStatus('Stream audio detector already initialized');
        print('🎯 Stream audio detector already initialized');
        return true;
      }
      
      // Initialize recorder
      print('🎯 Opening flutter_sound recorder...');
      await _recorder.openRecorder();
      print('🎯 Flutter_sound recorder opened successfully');
      
      // Initialize player
      print('🎯 Opening flutter_sound player...');
      await _player.openPlayer();
      print('🎯 Flutter_sound player opened successfully');
      
      // Set subscription duration
      await _recorder.setSubscriptionDuration(_subscriptionDuration);
      print('🎯 Subscription duration set to ${_subscriptionDuration.inMilliseconds}ms');
      
      _isInitialized = true;
      _updateStatus('Stream audio detector initialized');
      print('🎯 Stream audio detector initialized successfully');
      return true;
    } catch (e) {
      print('❌ Failed to initialize stream audio detector: $e');
      _handleError('Failed to initialize stream audio detector: $e');
      return false;
    }
  }
  
  /// Start listening to microphone input
  Future<bool> startListening() async {
    if (!_isInitialized) {
      _handleError('Stream audio detector not initialized');
      return false;
    }
    
    if (_isListening) {
      print('🎯 Stream audio detection already listening');
      return true;
    }
    
    try {
      // Check if recorder is already recording
      if (_recorder.isRecording) {
        print('🎯 Recorder already recording, stopping first');
        await _recorder.stopRecorder();
      }
      
      // Clear previous data
      _audioBuffer.clear();
      _audioBufferUint8.clear();
      _hitCount = 0;
      _lastStrikeTime = null;
      _currentDb = 0.0;
      
      // Create stream controllers
      if (_interleaved) {
        _audioDataControllerUint8 = StreamController<Uint8List>();
        _audioDataControllerUint8!.stream.listen((Uint8List buf) {
          _audioBufferUint8.add(buf);
          _processAudioDataUint8(buf);
        });
      } else {
        _audioDataController = StreamController<List<Float32List>>();
        _audioDataController!.stream.listen((audioData) {
          _audioBuffer.add(audioData);
          _processAudioData(audioData);
        });
      }
      
      // Start recording
      if (_interleaved) {
        await _recorder.startRecorder(
          codec: _codecSelected,
          sampleRate: _sampleRate,
          numChannels: _numChannels,
          audioSource: AudioSource.defaultSource,
          toStream: _audioDataControllerUint8!.sink,
          bufferSize: _bufferSize,
        );
      } else if (_codecSelected == Codec.pcmFloat32) {
        await _recorder.startRecorder(
          codec: _codecSelected,
          sampleRate: _sampleRate,
          numChannels: _numChannels,
          audioSource: AudioSource.defaultSource,
          toStreamFloat32: _audioDataController!.sink,
          bufferSize: _bufferSize,
        );
      } else if (_codecSelected == Codec.pcm16) {
        // For PCM16, we'll use a different approach
        await _recorder.startRecorder(
          codec: _codecSelected,
          sampleRate: _sampleRate,
          numChannels: _numChannels,
          audioSource: AudioSource.defaultSource,
          bufferSize: _bufferSize,
        );
      }
      
      _isListening = true;
      _updateStatus('Started listening to microphone');
      
      // Subscribe to amplitude data
      _amplitudeSubscription = _recorder.onProgress!.listen((e) {
        _processAmplitudeData(e);
      });
      
      print('🎯 Stream audio detection started successfully');
      return true;
    } catch (e) {
      print('❌ Failed to start stream audio detection: $e');
      _handleError('Failed to start stream audio detection: $e');
      return false;
    }
  }
  
  /// Stop listening
  Future<void> stopListening() async {
    if (!_isListening) return;
    
    try {
      print('🎯 Stopping stream audio detection...');
      
      // Cancel subscriptions
      await _amplitudeSubscription?.cancel();
      _amplitudeSubscription = null;
      
      await _audioDataSubscription?.cancel();
      _audioDataSubscription = null;
      
      // Close stream controllers
      await _audioDataController?.close();
      _audioDataController = null;
      
      await _audioDataControllerUint8?.close();
      _audioDataControllerUint8 = null;
      
      // Stop recording
      if (_recorder.isRecording) {
        await _recorder.stopRecorder();
        print('🎯 Recording stopped');
      }
      
      _isListening = false;
      _updateStatus('Stopped listening to microphone');
      
      print('🎯 Stream audio detection stopped');
    } catch (e) {
      _handleError('Failed to stop stream audio detection: $e');
    }
  }
  
  /// Play recorded audio
  Future<void> playRecordedAudio() async {
    try {
      if (_player.isPlaying) {
        await _player.stopPlayer();
        return;
      }
      
      print('🎵 Starting audio playback...');
      
      await _player.startPlayerFromStream(
        codec: _codecSelected,
        sampleRate: _sampleRate,
        numChannels: _numChannels,
        interleaved: _interleaved,
        bufferSize: _bufferSize,
      );
      
      // Feed audio data to player
      if (_interleaved && _audioBufferUint8.isNotEmpty) {
        for (var data in _audioBufferUint8) {
          await _player.feedUint8FromStream(data);
        }
      } else if (!_interleaved && _audioBuffer.isNotEmpty) {
        for (var data in _audioBuffer) {
          await _player.feedF32FromStream(data);
        }
      }
      
      print('🎵 Audio playback completed');
    } catch (e) {
      print('❌ Failed to play recorded audio: $e');
      _handleError('Failed to play recorded audio: $e');
    }
  }
  
  /// Process amplitude data
  void _processAmplitudeData(RecordingDisposition e) {
    try {
      _currentDb = e.decibels ?? 0.0;
      
      // Detect strike from amplitude
      _checkStrikeFromAmplitude(_currentDb);
      
      // Debug logging
      if (_hitCount % 3 == 0 || _currentDb > _dbThreshold * 0.8) {
        print('🎤 Current dB: ${_currentDb.toStringAsFixed(1)} dB (threshold: $_dbThreshold)');
      }
    } catch (e) {
      print('⚠️ Amplitude processing error: $e');
    }
  }
  
  /// Process audio data (Float32)
  void _processAudioData(List<Float32List> audioData) {
    try {
      // Calculate RMS energy
      double rmsEnergy = _calculateRMSEnergy(audioData);
      double dbFromAudio = _rmsToDecibels(rmsEnergy);
      
      // Additional strike detection from audio data
      if (dbFromAudio > _dbThreshold * 1.2) {
        print('🎵 Audio data detected high energy: ${dbFromAudio.toStringAsFixed(1)} dB');
        _checkStrikeFromAudioData(dbFromAudio);
      }
    } catch (e) {
      print('⚠️ Audio data processing error: $e');
    }
  }
  
  /// Process audio data (Uint8)
  void _processAudioDataUint8(Uint8List audioData) {
    try {
      // Convert Uint8 to Float32 for processing
      Float32List floatData = Float32List(audioData.length ~/ 4);
      for (int i = 0; i < floatData.length; i++) {
        int offset = i * 4;
        floatData[i] = _bytesToFloat32(audioData, offset);
      }
      
      // Calculate RMS energy
      double rmsEnergy = _calculateRMSEnergyFromList(floatData);
      double dbFromAudio = _rmsToDecibels(rmsEnergy);
      
      if (dbFromAudio > _dbThreshold * 1.2) {
        print('🎵 Uint8 audio data detected high energy: ${dbFromAudio.toStringAsFixed(1)} dB');
        _checkStrikeFromAudioData(dbFromAudio);
      }
    } catch (e) {
      print('⚠️ Uint8 audio data processing error: $e');
    }
  }
  
  /// Calculate RMS energy from Float32List
  double _calculateRMSEnergy(List<Float32List> audioData) {
    if (audioData.isEmpty) return 0.0;
    
    double sum = 0.0;
    int count = 0;
    
    for (var channel in audioData) {
      for (var sample in channel) {
        sum += sample * sample;
        count++;
      }
    }
    
    if (count == 0) return 0.0;
    return sqrt(sum / count);
  }
  
  /// Calculate RMS energy from single Float32List
  double _calculateRMSEnergyFromList(Float32List audioData) {
    if (audioData.isEmpty) return 0.0;
    
    double sum = 0.0;
    for (var sample in audioData) {
      sum += sample * sample;
    }
    
    return sqrt(sum / audioData.length);
  }
  
  /// Convert bytes to Float32
  double _bytesToFloat32(Uint8List bytes, int offset) {
    ByteData byteData = ByteData.view(bytes.buffer, offset, 4);
    return byteData.getFloat32(0, Endian.little);
  }
  
  /// Convert RMS to decibels
  double _rmsToDecibels(double rms) {
    if (rms <= 0.0) return -60.0;
    return 20.0 * log(rms) / ln10;
  }
  
  /// Check strike from amplitude
  void _checkStrikeFromAmplitude(double db) {
    final now = DateTime.now();
    
    if (db > _dbThreshold) {
      if (_lastStrikeTime == null || 
          now.difference(_lastStrikeTime!).inMilliseconds > _minStrikeInterval) {
        
        _lastStrikeTime = now;
        _hitCount++;
        
        print('🎯 STRIKE DETECTED! dB: ${db.toStringAsFixed(1)} (threshold: $_dbThreshold), Count: $_hitCount');
        
        onStrikeDetected?.call();
      } else {
        final timeSinceLast = now.difference(_lastStrikeTime!).inMilliseconds;
        print('⚠️ Strike ignored (too soon): dB ${db.toStringAsFixed(1)}, Time since last: ${timeSinceLast}ms');
      }
    }
  }
  
  /// Check strike from audio data
  void _checkStrikeFromAudioData(double db) {
    final now = DateTime.now();
    
    if (db > _dbThreshold * 1.2) {
      if (_lastStrikeTime == null || 
          now.difference(_lastStrikeTime!).inMilliseconds > _minStrikeInterval * 1.5) {
        
        _lastStrikeTime = now;
        _hitCount++;
        
        print('🎵 AUDIO STRIKE DETECTED! dB: ${db.toStringAsFixed(1)}, Count: $_hitCount');
        
        onStrikeDetected?.call();
      }
    }
  }
  
  /// Set audio processing mode
  void setAudioMode({bool interleaved = false, Codec codec = Codec.pcmFloat32}) {
    _interleaved = interleaved;
    _codecSelected = codec;
    print('🎵 Audio mode set: interleaved=$interleaved, codec=$codec');
  }
  
  /// Get listening status
  bool get isListening => _isListening;
  
  /// Get initialization status
  bool get isInitialized => _isInitialized;
  
  /// Get current decibel level
  double get currentDb => _currentDb;
  
  /// Get hit count
  int get hitCount => _hitCount;
  
  /// Get audio buffer size
  int get audioBufferSize => _interleaved ? _audioBufferUint8.length : _audioBuffer.length;
  
  /// Reset hit count
  void resetHitCount() {
    _hitCount = 0;
    _lastStrikeTime = null;
    print('🎯 Stream hit count reset to 0');
  }
  
  /// Update status
  void _updateStatus(String status) {
    onStatusUpdate?.call(status);
  }
  
  /// Handle errors
  void _handleError(String error) {
    onError?.call(error);
  }
  
  /// Dispose resources
  void dispose() {
    try {
      stopListening();
      _amplitudeSubscription?.cancel();
      _audioDataSubscription?.cancel();
      _audioDataController?.close();
      _audioDataControllerUint8?.close();
      _recorder.closeRecorder();
      _player.closePlayer();
      print('🎯 Stream audio detector disposed');
    } catch (e) {
      _handleError('Error disposing stream audio detector: $e');
    }
  }
} 