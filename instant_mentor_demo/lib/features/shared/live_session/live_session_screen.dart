import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/models/user.dart';

class LiveSessionScreen extends ConsumerStatefulWidget {
  final String? sessionId;
  final Mentor? mentor;

  const LiveSessionScreen({
    Key? key,
    this.sessionId,
    this.mentor,
  }) : super(key: key);

  @override
  ConsumerState<LiveSessionScreen> createState() => _LiveSessionScreenState();
}

class _LiveSessionScreenState extends ConsumerState<LiveSessionScreen> {
  bool _isSessionActive = false;
  bool _isVideoCallActive = false;
  bool _isMicEnabled = true;
  bool _isCameraEnabled = true;
  bool _isConnecting = false;
  final List<String> _messages = [];
  final TextEditingController _messageController = TextEditingController();

  @override
  void initState() {
    super.initState();
    // Add some demo messages
    _messages.addAll([
      "Welcome to your mentoring session!",
      "Feel free to ask any questions you have.",
      "I'm here to help you learn and grow.",
    ]);
  }

  Mentor get _mentor {
    return widget.mentor ??
        Mentor(
          id: widget.sessionId ?? 'demo',
          name: 'Demo Mentor',
          email: 'demo@example.com',
          createdAt: DateTime.now(),
          specializations: ['General Mentoring'],
          qualifications: ['Demo Qualification'],
          hourlyRate: 50.0,
          rating: 4.5,
          totalSessions: 10,
          isAvailable: true,
          totalEarnings: 500.0,
          bio: 'This is a demo mentor for testing purposes.',
          yearsOfExperience: 5,
        );
  }

  @override
  Widget build(BuildContext context) {
    if (_isVideoCallActive) {
      return _buildVideoCallInterface();
    }

    return Scaffold(
      appBar: AppBar(
        title: Text('Live Session with ${_mentor.name}'),
        backgroundColor: Theme.of(context).colorScheme.primary,
        foregroundColor: Colors.white,
        actions: [
          IconButton(
            icon:
                Icon(_isVideoCallActive ? Icons.videocam_off : Icons.videocam),
            onPressed: _toggleVideoCall,
            tooltip: _isVideoCallActive ? 'End Video Call' : 'Start Video Call',
          ),
        ],
      ),
      body: Column(
        children: [
          // Session Status Banner - Only show when video call is active
          if (_isVideoCallActive)
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(16),
              color: Colors.green,
              child: Row(
                children: [
                  const Icon(
                    Icons.videocam,
                    color: Colors.white,
                  ),
                  const SizedBox(width: 8),
                  const Text(
                    'Video Call Active 🎥',
                    style: TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ],
              ),
            ),

          // Mentor Info Card
          Card(
            margin: const EdgeInsets.all(16),
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Row(
                children: [
                  CircleAvatar(
                    radius: 30,
                    backgroundColor:
                        Theme.of(context).colorScheme.primaryContainer,
                    child: Text(
                      _mentor.name.isNotEmpty ? _mentor.name[0] : 'M',
                      style: const TextStyle(
                          fontSize: 24, fontWeight: FontWeight.bold),
                    ),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          _mentor.name,
                          style:
                              Theme.of(context).textTheme.titleLarge?.copyWith(
                                    fontWeight: FontWeight.bold,
                                  ),
                        ),
                        Text(
                          _mentor.specializations.isNotEmpty
                              ? _mentor.specializations.first
                              : 'General Mentoring',
                          style:
                              Theme.of(context).textTheme.bodyMedium?.copyWith(
                                    color: Colors.grey[600],
                                  ),
                        ),
                        const SizedBox(height: 4),
                        Row(
                          children: [
                            const Icon(Icons.star,
                                color: Colors.amber, size: 16),
                            const SizedBox(width: 4),
                            Text(
                              '${_mentor.rating}/5.0',
                              style: Theme.of(context).textTheme.bodySmall,
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),

          // Video Call Area
          if (_isVideoCallActive)
            Container(
              margin: const EdgeInsets.symmetric(horizontal: 16),
              height: 200,
              decoration: BoxDecoration(
                color: Colors.black,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: Colors.green, width: 2),
              ),
              child: Stack(
                children: [
                  // Mentor Video (simulated)
                  Container(
                    width: double.infinity,
                    height: double.infinity,
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(10),
                      gradient: LinearGradient(
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                        colors: [
                          Colors.blue.shade800,
                          Colors.blue.shade600,
                        ],
                      ),
                    ),
                    child: Center(
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          CircleAvatar(
                            radius: 40,
                            backgroundColor: Colors.white.withOpacity(0.2),
                            child: Icon(
                              Icons.videocam,
                              size: 40,
                              color: Colors.white,
                            ),
                          ),
                          const SizedBox(height: 8),
                          Text(
                            '🎥 Live Video Call',
                            style: TextStyle(
                              color: Colors.white,
                              fontSize: 16,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          Text(
                            'Connected with ${_mentor.name}',
                            style: TextStyle(
                              color: Colors.white70,
                              fontSize: 12,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                  // Your video (Picture-in-Picture)
                  Positioned(
                    top: 10,
                    right: 10,
                    child: Container(
                      width: 80,
                      height: 60,
                      decoration: BoxDecoration(
                        color: Colors.grey.shade800,
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(color: Colors.white, width: 1),
                      ),
                      child: Center(
                        child: Icon(
                          Icons.person,
                          color: Colors.white,
                          size: 30,
                        ),
                      ),
                    ),
                  ),
                  // Call controls
                  Positioned(
                    bottom: 10,
                    left: 0,
                    right: 0,
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Container(
                          padding: const EdgeInsets.all(8),
                          decoration: BoxDecoration(
                            color: Colors.black.withOpacity(0.5),
                            borderRadius: BorderRadius.circular(20),
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              IconButton(
                                onPressed: () {
                                  ScaffoldMessenger.of(context).showSnackBar(
                                    const SnackBar(
                                      content: Text('Microphone toggled'),
                                      duration: Duration(seconds: 1),
                                    ),
                                  );
                                },
                                icon:
                                    const Icon(Icons.mic, color: Colors.white),
                                iconSize: 20,
                              ),
                              IconButton(
                                onPressed: () {
                                  ScaffoldMessenger.of(context).showSnackBar(
                                    const SnackBar(
                                      content: Text('Camera toggled'),
                                      duration: Duration(seconds: 1),
                                    ),
                                  );
                                },
                                icon: const Icon(Icons.videocam,
                                    color: Colors.white),
                                iconSize: 20,
                              ),
                              IconButton(
                                onPressed: _toggleVideoCall,
                                icon: const Icon(Icons.call_end,
                                    color: Colors.red),
                                iconSize: 20,
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),

          if (_isVideoCallActive) const SizedBox(height: 16),

          // Chat Messages Area
          Expanded(
            child: Container(
              margin: const EdgeInsets.symmetric(horizontal: 16),
              decoration: BoxDecoration(
                border: Border.all(color: Colors.grey[300]!),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Column(
                children: [
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: Colors.grey[100],
                      borderRadius: const BorderRadius.only(
                        topLeft: Radius.circular(8),
                        topRight: Radius.circular(8),
                      ),
                    ),
                    child: const Text(
                      'Session Chat',
                      style: TextStyle(fontWeight: FontWeight.bold),
                    ),
                  ),
                  Expanded(
                    child: ListView.builder(
                      padding: const EdgeInsets.all(8),
                      itemCount: _messages.length,
                      itemBuilder: (context, index) {
                        return _buildMessageBubble(
                            _messages[index], index % 2 == 0);
                      },
                    ),
                  ),
                ],
              ),
            ),
          ),

          // Message Input
          Container(
            padding: const EdgeInsets.all(16),
            child: Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: _messageController,
                    decoration: InputDecoration(
                      hintText: 'Type your message...',
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(25),
                      ),
                      contentPadding: const EdgeInsets.symmetric(
                        horizontal: 16,
                        vertical: 12,
                      ),
                    ),
                    onSubmitted: _sendMessage,
                  ),
                ),
                const SizedBox(width: 8),
                FloatingActionButton.small(
                  onPressed: () => _sendMessage(_messageController.text),
                  child: const Icon(Icons.send),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildMessageBubble(String message, bool isFromMentor) {
    return Container(
      margin: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        mainAxisAlignment:
            isFromMentor ? MainAxisAlignment.start : MainAxisAlignment.end,
        children: [
          Container(
            constraints: BoxConstraints(
              maxWidth: MediaQuery.of(context).size.width * 0.7,
            ),
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
            decoration: BoxDecoration(
              color: isFromMentor
                  ? Colors.grey[200]
                  : Theme.of(context).colorScheme.primary,
              borderRadius: BorderRadius.circular(18),
            ),
            child: Text(
              message,
              style: TextStyle(
                color: isFromMentor ? Colors.black87 : Colors.white,
              ),
            ),
          ),
        ],
      ),
    );
  }

  void _sendMessage(String message) {
    if (message.trim().isEmpty) return;

    setState(() {
      _messages.add(message);
      _messageController.clear();
    });

    // Simulate mentor response
    if (_isSessionActive) {
      Future.delayed(const Duration(seconds: 2), () {
        if (mounted) {
          setState(() {
            _messages
                .add("Thank you for your message! Let me help you with that.");
          });
        }
      });
    }
  }

  void _toggleVideoCall() {
    setState(() {
      _isVideoCallActive = !_isVideoCallActive;
      _isSessionActive = _isVideoCallActive;

      if (_isVideoCallActive) {
        _isConnecting = true;
        // Simulate connection delay
        Future.delayed(const Duration(seconds: 2), () {
          if (mounted) {
            setState(() {
              _isConnecting = false;
            });
          }
        });
      }
    });

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          _isVideoCallActive
              ? 'Video call started - Connected with your mentor!'
              : 'Video call ended - Chat remains available',
        ),
        backgroundColor: _isVideoCallActive ? Colors.green : Colors.orange,
      ),
    );

    if (_isVideoCallActive) {
      setState(() {
        _messages.add("🎥 Video call has started! How can I help you today?");
      });
    } else {
      setState(() {
        _messages.add("📞 Video call ended. Feel free to continue chatting!");
      });
    }
  }

  void _toggleMicrophone() {
    setState(() {
      _isMicEnabled = !_isMicEnabled;
    });

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content:
            Text(_isMicEnabled ? 'Microphone enabled' : 'Microphone muted'),
        duration: const Duration(seconds: 1),
      ),
    );
  }

  void _toggleCamera() {
    setState(() {
      _isCameraEnabled = !_isCameraEnabled;
    });

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(_isCameraEnabled ? 'Camera enabled' : 'Camera disabled'),
        duration: const Duration(seconds: 1),
      ),
    );
  }

  void _togglePictureInPicture() {
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('Picture-in-Picture toggled'),
        duration: Duration(seconds: 1),
      ),
    );
  }

  Widget _buildVideoCallInterface() {
    return Scaffold(
      backgroundColor: const Color(0xFF1a1a2e),
      appBar: AppBar(
        title: const Text('In Call'),
        backgroundColor: const Color(0xFF16213e),
        foregroundColor: Colors.white,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: _toggleVideoCall,
        ),
      ),
      body: Stack(
        children: [
          // Main video areas
          if (_isConnecting)
            _buildConnectingScreen()
          else
            _buildActiveCallScreen(),

          // Bottom controls
          Positioned(
            bottom: 0,
            left: 0,
            right: 0,
            child: _buildCallControls(),
          ),
        ],
      ),
    );
  }

  Widget _buildConnectingScreen() {
    return Container(
      width: double.infinity,
      height: double.infinity,
      color: Colors.black,
      child: const Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            CircularProgressIndicator(
              valueColor: AlwaysStoppedAnimation<Color>(Colors.blue),
            ),
            SizedBox(height: 20),
            Text(
              'Connecting...',
              style: TextStyle(
                color: Colors.white,
                fontSize: 18,
                fontWeight: FontWeight.w500,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildActiveCallScreen() {
    return Row(
      children: [
        // Left side - Your video
        Expanded(
          child: Container(
            margin: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: Colors.grey[800],
              borderRadius: BorderRadius.circular(12),
            ),
            child: Stack(
              children: [
                // Simulated user video feed
                Container(
                  width: double.infinity,
                  height: double.infinity,
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(12),
                    gradient: LinearGradient(
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                      colors: [
                        Colors.grey[700]!,
                        Colors.grey[900]!,
                      ],
                    ),
                  ),
                  child: _isCameraEnabled
                      ? Center(
                          child: Icon(
                            Icons.person,
                            size: 100,
                            color: Colors.white.withOpacity(0.7),
                          ),
                        )
                      : const Center(
                          child: Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Icon(
                                Icons.videocam_off,
                                size: 50,
                                color: Colors.white54,
                              ),
                              SizedBox(height: 8),
                              Text(
                                'Camera Off',
                                style: TextStyle(
                                  color: Colors.white54,
                                  fontSize: 16,
                                ),
                              ),
                            ],
                          ),
                        ),
                ),
                // User label
                Positioned(
                  bottom: 8,
                  left: 8,
                  child: Container(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                    decoration: BoxDecoration(
                      color: Colors.black.withOpacity(0.6),
                      borderRadius: BorderRadius.circular(4),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(
                          _isMicEnabled ? Icons.mic : Icons.mic_off,
                          size: 14,
                          color: _isMicEnabled ? Colors.green : Colors.red,
                        ),
                        const SizedBox(width: 4),
                        const Text(
                          'You',
                          style: TextStyle(
                            color: Colors.white,
                            fontSize: 12,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
        // Right side - Mentor video
        Expanded(
          child: Container(
            margin: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: Colors.black,
              borderRadius: BorderRadius.circular(12),
            ),
            child: Stack(
              children: [
                // Simulated mentor video feed
                Container(
                  width: double.infinity,
                  height: double.infinity,
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(12),
                    gradient: LinearGradient(
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                      colors: [
                        Colors.blue[700]!,
                        Colors.blue[900]!,
                      ],
                    ),
                  ),
                  child: Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        CircleAvatar(
                          radius: 50,
                          backgroundColor: Colors.white.withOpacity(0.2),
                          child: Text(
                            _mentor.name.isNotEmpty ? _mentor.name[0] : 'M',
                            style: const TextStyle(
                              fontSize: 40,
                              fontWeight: FontWeight.bold,
                              color: Colors.white,
                            ),
                          ),
                        ),
                        const SizedBox(height: 12),
                        Text(
                          _mentor.name,
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 18,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
                // Mentor label
                Positioned(
                  bottom: 8,
                  left: 8,
                  child: Container(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                    decoration: BoxDecoration(
                      color: Colors.black.withOpacity(0.6),
                      borderRadius: BorderRadius.circular(4),
                    ),
                    child: const Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(
                          Icons.mic,
                          size: 14,
                          color: Colors.green,
                        ),
                        SizedBox(width: 4),
                        Text(
                          'Demo Mentor',
                          style: TextStyle(
                            color: Colors.white,
                            fontSize: 12,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildCallControls() {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [
            Colors.transparent,
            Colors.black.withOpacity(0.8),
            Colors.black,
          ],
        ),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceEvenly,
        children: [
          // Microphone button
          _buildControlButton(
            icon: _isMicEnabled ? Icons.mic : Icons.mic_off,
            label: 'Mic',
            isActive: _isMicEnabled,
            onPressed: _toggleMicrophone,
            activeColor: Colors.white,
            inactiveColor: Colors.red,
          ),
          // Camera button
          _buildControlButton(
            icon: _isCameraEnabled ? Icons.videocam : Icons.videocam_off,
            label: 'Camera',
            isActive: _isCameraEnabled,
            onPressed: _toggleCamera,
            activeColor: Colors.white,
            inactiveColor: Colors.red,
          ),
          // Picture-in-Picture button
          _buildControlButton(
            icon: Icons.picture_in_picture_alt,
            label: 'PiP',
            isActive: true,
            onPressed: _togglePictureInPicture,
            activeColor: Colors.white,
            inactiveColor: Colors.grey,
          ),
          // End call button
          _buildControlButton(
            icon: Icons.call_end,
            label: 'End',
            isActive: false,
            onPressed: _toggleVideoCall,
            activeColor: Colors.white,
            inactiveColor: Colors.red,
            isEndCall: true,
          ),
        ],
      ),
    );
  }

  Widget _buildControlButton({
    required IconData icon,
    required String label,
    required bool isActive,
    required VoidCallback onPressed,
    required Color activeColor,
    required Color inactiveColor,
    bool isEndCall = false,
  }) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: 60,
          height: 60,
          decoration: BoxDecoration(
            color: isEndCall
                ? Colors.red
                : (isActive ? Colors.grey[700] : Colors.grey[800]),
            shape: BoxShape.circle,
            border: Border.all(
              color: isActive ? activeColor : inactiveColor,
              width: 2,
            ),
          ),
          child: IconButton(
            onPressed: onPressed,
            icon: Icon(
              icon,
              color: isEndCall
                  ? Colors.white
                  : (isActive ? activeColor : inactiveColor),
              size: 28,
            ),
          ),
        ),
        const SizedBox(height: 8),
        Text(
          label,
          style: TextStyle(
            color: Colors.white.withOpacity(0.8),
            fontSize: 12,
            fontWeight: FontWeight.w500,
          ),
        ),
      ],
    );
  }

  @override
  void dispose() {
    _messageController.dispose();
    super.dispose();
  }
}
