import 'dart:async';
import 'package:flutter/material.dart';
import 'stream_audio_detector.dart';

/// Example usage of StreamAudioDetector
/// 展示如何在 Flutter 应用中使用 StreamAudioDetector
class StreamAudioDetectorExample extends StatefulWidget {
  const StreamAudioDetectorExample({super.key});

  @override
  State<StreamAudioDetectorExample> createState() => _StreamAudioDetectorExampleState();
}

class _StreamAudioDetectorExampleState extends State<StreamAudioDetectorExample> {
  final StreamAudioDetector _detector = StreamAudioDetector();
  
  bool _isInitialized = false;
  bool _isListening = false;
  bool _isPlaying = false;
  int _hitCount = 0;
  double _currentDb = 0.0;
  int _audioBufferSize = 0;
  String _status = 'Not initialized';
  
  @override
  void initState() {
    super.initState();
    _setupDetector();
  }
  
  void _setupDetector() {
    _detector.onStrikeDetected = () {
      setState(() {
        _hitCount = _detector.hitCount;
      });
      print('🎯 Strike detected! Count: $_hitCount');
    };
    
    _detector.onError = (error) {
      setState(() {
        _status = 'Error: $error';
      });
      print('❌ Error: $error');
    };
    
    _detector.onStatusUpdate = (status) {
      setState(() {
        _status = status;
      });
      print('📝 Status: $status');
    };
  }
  
  Future<void> _initializeDetector() async {
    setState(() {
      _status = 'Initializing...';
    });
    
    final success = await _detector.initialize();
    setState(() {
      _isInitialized = success;
      _status = success ? 'Initialized' : 'Initialization failed';
    });
  }
  
  Future<void> _startListening() async {
    if (!_isInitialized) {
      await _initializeDetector();
    }
    
    setState(() {
      _status = 'Starting...';
    });
    
    final success = await _detector.startListening();
    setState(() {
      _isListening = success;
      _status = success ? 'Listening' : 'Failed to start';
    });
    
    if (success) {
      // Start monitoring
      Timer.periodic(Duration(milliseconds: 100), (timer) {
        if (!_isListening) {
          timer.cancel();
          return;
        }
        
        setState(() {
          _currentDb = _detector.currentDb;
          _audioBufferSize = _detector.audioBufferSize;
        });
      });
    }
  }
  
  Future<void> _stopListening() async {
    await _detector.stopListening();
    setState(() {
      _isListening = false;
      _status = 'Stopped';
    });
  }
  
  Future<void> _playRecordedAudio() async {
    if (_detector.audioBufferSize == 0) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('No audio data to play')),
      );
      return;
    }
    
    setState(() {
      _isPlaying = true;
      _status = 'Playing...';
    });
    
    await _detector.playRecordedAudio();
    
    setState(() {
      _isPlaying = false;
      _status = 'Playback completed';
    });
  }
  
  void _resetCount() {
    _detector.resetHitCount();
    setState(() {
      _hitCount = 0;
    });
  }
  
  @override
  void dispose() {
    _detector.dispose();
    super.dispose();
  }
  
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('Stream Audio Detector Example'),
        backgroundColor: Colors.blue,
        foregroundColor: Colors.white,
      ),
      body: Padding(
        padding: EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // Status Card
            Card(
              child: Padding(
                padding: EdgeInsets.all(16.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Status',
                      style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                    ),
                    SizedBox(height: 8),
                    Text('State: $_status'),
                    Text('Initialized: $_isInitialized'),
                    Text('Listening: $_isListening'),
                    Text('Playing: $_isPlaying'),
                  ],
                ),
              ),
            ),
            
            SizedBox(height: 16),
            
            // Audio Info Card
            Card(
              child: Padding(
                padding: EdgeInsets.all(16.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Audio Information',
                      style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                    ),
                    SizedBox(height: 8),
                    Text('Current dB: ${_currentDb.toStringAsFixed(1)}'),
                    Text('Hit Count: $_hitCount'),
                    Text('Audio Buffer Size: $_audioBufferSize'),
                  ],
                ),
              ),
            ),
            
            SizedBox(height: 16),
            
            // Controls
            Card(
              child: Padding(
                padding: EdgeInsets.all(16.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Text(
                      'Controls',
                      style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                    ),
                    SizedBox(height: 16),
                    
                    // Initialize Button
                    ElevatedButton(
                      onPressed: _isInitialized ? null : _initializeDetector,
                      child: Text('Initialize Detector'),
                    ),
                    
                    SizedBox(height: 8),
                    
                    // Start/Stop Button
                    ElevatedButton(
                      onPressed: _isListening ? _stopListening : _startListening,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: _isListening ? Colors.red : Colors.green,
                        foregroundColor: Colors.white,
                      ),
                      child: Text(_isListening ? 'Stop Listening' : 'Start Listening'),
                    ),
                    
                    SizedBox(height: 8),
                    
                    // Play Button
                    ElevatedButton(
                      onPressed: _audioBufferSize > 0 && !_isListening ? _playRecordedAudio : null,
                      child: Text('Play Recorded Audio'),
                    ),
                    
                    SizedBox(height: 8),
                    
                    // Reset Button
                    ElevatedButton(
                      onPressed: _hitCount > 0 ? _resetCount : null,
                      child: Text('Reset Count'),
                    ),
                  ],
                ),
              ),
            ),
            
            SizedBox(height: 16),
            
            // Instructions
            Card(
              child: Padding(
                padding: EdgeInsets.all(16.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Instructions',
                      style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                    ),
                    SizedBox(height: 8),
                    Text('1. Initialize the detector'),
                    Text('2. Start listening to microphone'),
                    Text('3. Make sounds (clap, tap, etc.)'),
                    Text('4. Watch the hit count increase'),
                    Text('5. Stop listening when done'),
                    Text('6. Play back the recorded audio'),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
} 