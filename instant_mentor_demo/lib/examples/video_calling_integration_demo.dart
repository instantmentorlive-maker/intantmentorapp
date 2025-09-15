import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:agora_rtc_engine/agora_rtc_engine.dart';

import '../core/services/video_calling_service.dart';
import '../core/services/call_quality_monitoring_service.dart';
import '../core/services/call_recording_service.dart';

/// Phase 2 Days 19-21: Complete video calling integration example
/// Demonstrates the integration of all video calling services
class VideoCallingIntegrationDemo extends StatefulWidget {
  const VideoCallingIntegrationDemo({super.key});

  @override
  State<VideoCallingIntegrationDemo> createState() =>
      _VideoCallingIntegrationDemoState();
}

class _VideoCallingIntegrationDemoState
    extends State<VideoCallingIntegrationDemo> {
  // Services
  late VideoCallingService _videoService;
  late CallQualityMonitoringService _qualityService;
  late CallRecordingService _recordingService;

  // UI State
  bool _isInitialized = false;
  bool _isInCall = false;
  bool _isVideoEnabled = true;
  bool _isAudioEnabled = true;
  bool _isRecording = false;

  // Call data
  String _channelName = 'demo-channel-${DateTime.now().millisecondsSinceEpoch}';
  final int _userId = 12345; // In production, this would be dynamic

  // Quality monitoring
  CallQualityStats _qualityStats = CallQualityStats.empty();
  final List<QualityAlert> _qualityAlerts = [];

  // Event subscriptions
  StreamSubscription? _videoEventSub;
  StreamSubscription? _qualityAlertSub;
  StreamSubscription? _recordingEventSub;

  // Agora widgets
  AgoraVideoView? _localVideoWidget;
  final Map<int, AgoraVideoView> _remoteVideoWidgets = {};

  @override
  void initState() {
    super.initState();
    _initializeServices();
  }

  @override
  void dispose() {
    _cleanupSubscriptions();
    _disposeServices();
    super.dispose();
  }

  /// Initialize all video calling services
  Future<void> _initializeServices() async {
    try {
      debugPrint('🔄 Initializing video calling services...');

      // Initialize video service
      _videoService = VideoCallingService();
      final videoInitialized = await _videoService.initialize();

      if (!videoInitialized) {
        throw Exception('Failed to initialize video service');
      }

      // Initialize quality monitoring
      _qualityService = CallQualityMonitoringService(_videoService);

      // Initialize recording service
      _recordingService = CallRecordingService(_videoService);
      final recordingInitialized = await _recordingService.initialize();

      if (!recordingInitialized) {
        debugPrint(
            '⚠️ Recording service initialization failed, continuing without recording');
      }

      // Set up event listeners
      _setupEventListeners();

      // Setup local video preview
      await _setupLocalVideoPreview();

      setState(() {
        _isInitialized = true;
      });

      debugPrint('✅ All video calling services initialized successfully');

      // Show success message
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('📹 Video calling services ready!'),
            backgroundColor: Colors.green,
          ),
        );
      }
    } catch (e) {
      debugPrint('❌ Failed to initialize services: $e');

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('❌ Initialization failed: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  /// Setup event listeners for all services
  void _setupEventListeners() {
    // Video service events
    _videoEventSub = _videoService.eventStream.listen((event) {
      debugPrint('📹 Video Event: ${event.type} - ${event.message}');

      switch (event.type) {
        case VideoCallEventType.callJoined:
          setState(() {
            _isInCall = true;
          });
          // Start quality monitoring when call begins
          _qualityService.startMonitoring();
          break;

        case VideoCallEventType.callEnded:
          setState(() {
            _isInCall = false;
            _isRecording = false;
          });
          // Stop quality monitoring
          _qualityService.stopMonitoring();
          // Update quality stats
          _updateQualityStats();
          break;

        case VideoCallEventType.userJoined:
          _setupRemoteVideo(event.data?['userId'] as int?);
          break;

        case VideoCallEventType.userLeft:
          _removeRemoteVideo(event.data?['userId'] as int?);
          break;

        case VideoCallEventType.videoToggled:
          setState(() {
            _isVideoEnabled = event.data?['enabled'] ?? false;
          });
          break;

        case VideoCallEventType.audioToggled:
          setState(() {
            _isAudioEnabled = event.data?['enabled'] ?? false;
          });
          break;

        default:
          break;
      }

      // Show event notification
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(event.message),
            duration: const Duration(seconds: 2),
          ),
        );
      }
    });

    // Quality monitoring alerts
    _qualityAlertSub = _qualityService.alertStream.listen((alert) {
      debugPrint('📊 Quality Alert: ${alert.type} - ${alert.message}');

      _qualityAlerts.insert(0, alert);
      if (_qualityAlerts.length > 10) {
        _qualityAlerts.removeRange(10, _qualityAlerts.length);
      }

      // Show quality alert for warnings and errors
      if (alert.severity != AlertSeverity.info && mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Row(
              children: [
                Icon(
                  alert.severity == AlertSeverity.warning
                      ? Icons.warning_amber
                      : Icons.error,
                  color: Colors.white,
                ),
                const SizedBox(width: 8),
                Expanded(child: Text(alert.message)),
              ],
            ),
            backgroundColor: alert.severity == AlertSeverity.warning
                ? Colors.orange
                : Colors.red,
            duration: const Duration(seconds: 4),
          ),
        );
      }
    });

    // Recording events
    _recordingEventSub = _recordingService.eventStream.listen((event) {
      debugPrint('🎥 Recording Event: ${event.type} - ${event.message}');

      switch (event.type) {
        case RecordingEventType.recordingStarted:
          setState(() {
            _isRecording = true;
          });
          break;

        case RecordingEventType.recordingStopped:
          setState(() {
            _isRecording = false;
          });
          break;

        default:
          break;
      }

      // Show recording notification
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('🎥 ${event.message}'),
            backgroundColor: event.type == RecordingEventType.recordingFailed
                ? Colors.red
                : Colors.blue,
          ),
        );
      }
    });
  }

  /// Setup local video preview
  Future<void> _setupLocalVideoPreview() async {
    try {
      _localVideoWidget = AgoraVideoView(
        controller: VideoViewController(
          rtcEngine: _videoService.rtcEngine!,
          canvas: const VideoCanvas(uid: 0),
        ),
      );

      setState(() {});
    } catch (e) {
      debugPrint('❌ Failed to setup local video preview: $e');
    }
  }

  /// Setup remote video for a user
  void _setupRemoteVideo(int? userId) {
    if (userId == null) return;

    try {
      _remoteVideoWidgets[userId] = AgoraVideoView(
        controller: VideoViewController.remote(
          rtcEngine: _videoService.rtcEngine!,
          canvas: VideoCanvas(uid: userId),
          connection: RtcConnection(channelId: _channelName),
        ),
      );

      setState(() {});
    } catch (e) {
      debugPrint('❌ Failed to setup remote video for user $userId: $e');
    }
  }

  /// Remove remote video for a user
  void _removeRemoteVideo(int? userId) {
    if (userId == null) return;

    _remoteVideoWidgets.remove(userId);
    setState(() {});
  }

  /// Update quality statistics
  void _updateQualityStats() {
    final stats = _qualityService.getCurrentQuality();
    setState(() {
      _qualityStats = stats;
    });
  }

  /// Join video call
  Future<void> _joinCall() async {
    if (!_isInitialized) {
      debugPrint('⚠️ Services not initialized');
      return;
    }

    final success = await _videoService.joinCall(
      channelName: _channelName,
      userId: _userId,
    );

    if (success) {
      debugPrint('✅ Successfully joined call: $_channelName');
    } else {
      debugPrint('❌ Failed to join call');
    }
  }

  /// Leave video call
  Future<void> _leaveCall() async {
    await _videoService.leaveCall();
    debugPrint('✅ Left call');
  }

  /// Toggle video
  Future<void> _toggleVideo() async {
    await _videoService.toggleVideo();
  }

  /// Toggle audio
  Future<void> _toggleAudio() async {
    await _videoService.toggleAudio();
  }

  /// Switch camera
  Future<void> _switchCamera() async {
    await _videoService.switchCamera();
  }

  /// Toggle call recording
  Future<void> _toggleRecording() async {
    if (_isRecording) {
      await _recordingService.stopRecording();
    } else {
      await _recordingService.startRecording();
    }
  }

  /// Cleanup subscriptions
  void _cleanupSubscriptions() {
    _videoEventSub?.cancel();
    _qualityAlertSub?.cancel();
    _recordingEventSub?.cancel();
  }

  /// Dispose all services
  Future<void> _disposeServices() async {
    await _videoService.dispose();
    await _qualityService.dispose();
    await _recordingService.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('📹 Video Calling Demo'),
        backgroundColor: Colors.blue,
        foregroundColor: Colors.white,
        actions: [
          if (_isInCall) ...[
            IconButton(
              onPressed: _toggleRecording,
              icon: Icon(_isRecording ? Icons.stop : Icons.fiber_manual_record),
              color: _isRecording ? Colors.red : Colors.white,
              tooltip: _isRecording ? 'Stop Recording' : 'Start Recording',
            ),
            IconButton(
              onPressed: () => _updateQualityStats(),
              icon: const Icon(Icons.analytics),
              tooltip: 'Update Quality Stats',
            ),
          ],
        ],
      ),
      body: !_isInitialized
          ? const Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  CircularProgressIndicator(),
                  SizedBox(height: 16),
                  Text('Initializing video services...'),
                ],
              ),
            )
          : Column(
              children: [
                // Video area
                Expanded(
                  flex: 3,
                  child: Container(
                    color: Colors.black,
                    child: _isInCall ? _buildVideoLayout() : _buildPreCallUI(),
                  ),
                ),

                // Quality monitoring panel
                if (_isInCall)
                  Expanded(
                    flex: 1,
                    child: _buildQualityPanel(),
                  ),

                // Control buttons
                Container(
                  padding: const EdgeInsets.all(16),
                  child: _buildControlButtons(),
                ),
              ],
            ),
    );
  }

  /// Build video layout during call
  Widget _buildVideoLayout() {
    return Stack(
      children: [
        // Remote videos (main view)
        if (_remoteVideoWidgets.isNotEmpty)
          _remoteVideoWidgets.values.first
        else
          const Center(
            child: Text(
              'Waiting for other participants...',
              style: TextStyle(color: Colors.white, fontSize: 16),
            ),
          ),

        // Local video (picture-in-picture)
        if (_localVideoWidget != null)
          Positioned(
            right: 16,
            top: 16,
            width: 120,
            height: 160,
            child: Container(
              decoration: BoxDecoration(
                border: Border.all(color: Colors.white, width: 2),
                borderRadius: BorderRadius.circular(8),
              ),
              child: ClipRRect(
                borderRadius: BorderRadius.circular(6),
                child: _isVideoEnabled
                    ? _localVideoWidget!
                    : Container(
                        color: Colors.grey[800],
                        child: const Icon(
                          Icons.videocam_off,
                          color: Colors.white,
                          size: 32,
                        ),
                      ),
              ),
            ),
          ),

        // Call info overlay
        Positioned(
          left: 16,
          top: 16,
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
            decoration: BoxDecoration(
              color: Colors.black.withOpacity(0.7),
              borderRadius: BorderRadius.circular(16),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Icon(Icons.circle, color: Colors.green, size: 8),
                const SizedBox(width: 6),
                Text(
                  'Live • ${_remoteVideoWidgets.length + 1} participants',
                  style: const TextStyle(color: Colors.white, fontSize: 12),
                ),
              ],
            ),
          ),
        ),

        // Recording indicator
        if (_isRecording)
          Positioned(
            right: 16,
            bottom: 16,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
              decoration: BoxDecoration(
                color: Colors.red,
                borderRadius: BorderRadius.circular(16),
              ),
              child: const Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(Icons.fiber_manual_record,
                      color: Colors.white, size: 12),
                  SizedBox(width: 4),
                  Text('REC',
                      style: TextStyle(color: Colors.white, fontSize: 10)),
                ],
              ),
            ),
          ),
      ],
    );
  }

  /// Build pre-call UI
  Widget _buildPreCallUI() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          if (_localVideoWidget != null)
            Container(
              width: 200,
              height: 300,
              decoration: BoxDecoration(
                border: Border.all(color: Colors.white, width: 2),
                borderRadius: BorderRadius.circular(12),
              ),
              child: ClipRRect(
                borderRadius: BorderRadius.circular(10),
                child: _isVideoEnabled
                    ? _localVideoWidget!
                    : Container(
                        color: Colors.grey[800],
                        child: const Icon(
                          Icons.videocam_off,
                          color: Colors.white,
                          size: 48,
                        ),
                      ),
              ),
            ),
          const SizedBox(height: 24),
          Text(
            'Channel: $_channelName',
            style: const TextStyle(color: Colors.white, fontSize: 14),
          ),
          const SizedBox(height: 8),
          const Text(
            'Ready to join call',
            style: TextStyle(color: Colors.white70, fontSize: 16),
          ),
        ],
      ),
    );
  }

  /// Build quality monitoring panel
  Widget _buildQualityPanel() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.grey[100],
        border: Border(top: BorderSide(color: Colors.grey[300]!)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            '📊 Call Quality',
            style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
          ),
          const SizedBox(height: 8),
          Expanded(
            child: Row(
              children: [
                // Quality stats
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('Network: ${_qualityStats.networkQuality}'),
                      Text('Latency: ${_qualityStats.averageLatency}ms'),
                      Text(
                          'Packet Loss: ${(_qualityStats.averagePacketLoss * 100).toStringAsFixed(1)}%'),
                      Text('Quality Score: ${_qualityStats.qualityScore}/100'),
                    ],
                  ),
                ),

                // Recent alerts
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text('Recent Alerts:',
                          style: TextStyle(fontWeight: FontWeight.w500)),
                      Expanded(
                        child: ListView.builder(
                          itemCount: _qualityAlerts.take(3).length,
                          itemBuilder: (context, index) {
                            final alert = _qualityAlerts[index];
                            return Text(
                              '• ${alert.message}',
                              style: TextStyle(
                                fontSize: 12,
                                color: alert.severity == AlertSeverity.error
                                    ? Colors.red
                                    : alert.severity == AlertSeverity.warning
                                        ? Colors.orange
                                        : Colors.grey[600],
                              ),
                            );
                          },
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  /// Build control buttons
  Widget _buildControlButtons() {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceEvenly,
      children: [
        // Join/Leave call button
        ElevatedButton.icon(
          onPressed: _isInCall ? _leaveCall : _joinCall,
          icon: Icon(_isInCall ? Icons.call_end : Icons.video_call),
          label: Text(_isInCall ? 'Leave Call' : 'Join Call'),
          style: ElevatedButton.styleFrom(
            backgroundColor: _isInCall ? Colors.red : Colors.green,
            foregroundColor: Colors.white,
          ),
        ),

        if (_isInCall) ...[
          // Video toggle
          IconButton(
            onPressed: _toggleVideo,
            icon: Icon(_isVideoEnabled ? Icons.videocam : Icons.videocam_off),
            style: IconButton.styleFrom(
              backgroundColor: _isVideoEnabled ? Colors.blue : Colors.grey,
              foregroundColor: Colors.white,
            ),
          ),

          // Audio toggle
          IconButton(
            onPressed: _toggleAudio,
            icon: Icon(_isAudioEnabled ? Icons.mic : Icons.mic_off),
            style: IconButton.styleFrom(
              backgroundColor: _isAudioEnabled ? Colors.blue : Colors.grey,
              foregroundColor: Colors.white,
            ),
          ),

          // Camera switch
          IconButton(
            onPressed: _switchCamera,
            icon: const Icon(Icons.cameraswitch),
            style: IconButton.styleFrom(
              backgroundColor: Colors.blue,
              foregroundColor: Colors.white,
            ),
          ),
        ],
      ],
    );
  }
}
