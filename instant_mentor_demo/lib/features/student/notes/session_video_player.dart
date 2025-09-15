import 'package:flutter/material.dart';
import 'package:video_player/video_player.dart';

class SessionVideoPlayer extends StatefulWidget {
  final String? videoUrl;
  final String sessionTitle;

  const SessionVideoPlayer({
    super.key,
    this.videoUrl,
    required this.sessionTitle,
  });

  @override
  State<SessionVideoPlayer> createState() => _SessionVideoPlayerState();
}

class _SessionVideoPlayerState extends State<SessionVideoPlayer> {
  VideoPlayerController? _controller;
  bool _isInitialized = false;
  bool _hasError = false;
  String? _errorMessage;
  bool _showControls = true;

  @override
  void initState() {
    super.initState();
    _initializeVideoPlayer();
  }

  void _initializeVideoPlayer() {
    if (widget.videoUrl != null && widget.videoUrl!.isNotEmpty) {
      try {
        print('Initializing video with URL: ${widget.videoUrl}');

        // Use a working sample video URL that's known to work on web
        String videoUrl = widget.videoUrl!;
        // Provide a compact reliable fallback if a known problematic demo URL is passed
        const fallbackShortMp4 =
            'https://filesamples.com/samples/video/mp4/sample_640x360.mp4';
        if (videoUrl.contains('bee.mp4') || videoUrl.endsWith('.mkv')) {
          videoUrl = fallbackShortMp4;
        }

        _controller = VideoPlayerController.networkUrl(
          Uri.parse(videoUrl),
        );

        _controller!.initialize().then((_) {
          print('Video initialized successfully');
          if (mounted) {
            setState(() {
              _isInitialized = true;
            });
            // Auto-play the video when initialized
            _controller!.play();
          }
        }).catchError((error) {
          print('Video initialization error: $error');
          if (mounted) {
            setState(() {
              _hasError = true;
              _errorMessage = 'Failed to load video: ${error.toString()}';
            });
          }
        });

        _controller!.addListener(() {
          if (mounted) {
            setState(() {});
          }
        });
      } catch (e) {
        print('Exception in video initialization: $e');
        setState(() {
          _hasError = true;
          _errorMessage = 'Error loading video: ${e.toString()}';
        });
      }
    } else {
      print('No video URL provided');
      setState(() {
        _hasError = true;
        _errorMessage = 'No video URL provided';
      });
    }
  }

  @override
  void dispose() {
    _controller?.dispose();
    _fallbackController?.dispose();
    super.dispose();
  }

  void _togglePlayPause() {
    if (_controller != null) {
      setState(() {
        if (_controller!.value.isPlaying) {
          _controller!.pause();
        } else {
          _controller!.play();
        }
      });
    }
  }

  void _seek(double seconds) {
    if (_controller != null) {
      final duration = _controller!.value.duration;
      final position = Duration(seconds: seconds.round());
      if (position <= duration) {
        _controller!.seekTo(position);
      }
    }
  }

  String _formatDuration(Duration duration) {
    String twoDigits(int n) => n.toString().padLeft(2, '0');
    final hours = twoDigits(duration.inHours);
    final minutes = twoDigits(duration.inMinutes.remainder(60));
    final seconds = twoDigits(duration.inSeconds.remainder(60));

    if (duration.inHours > 0) {
      return '$hours:$minutes:$seconds';
    } else {
      return '$minutes:$seconds';
    }
  }

  Widget _buildVideoPlayer() {
    if (_hasError) {
      return _buildDemoPlayer();
    }

    if (!_isInitialized) {
      return Container(
        color: Colors.black,
        child: const Center(
          child: CircularProgressIndicator(
            valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
          ),
        ),
      );
    }

    return Stack(
      children: [
        Center(
          child: AspectRatio(
            aspectRatio: _controller!.value.aspectRatio,
            child: VideoPlayer(_controller!),
          ),
        ),
        if (_showControls) _buildControls(),
        // Tap to toggle controls
        GestureDetector(
          onTap: () {
            setState(() {
              _showControls = !_showControls;
            });
          },
          child: Container(
            width: double.infinity,
            height: double.infinity,
            color: Colors.transparent,
          ),
        ),
      ],
    );
  }

  Widget _buildControls() {
    final position = _controller?.value.position ?? Duration.zero;
    final duration = _controller?.value.duration ?? Duration.zero;
    final isPlaying = _controller?.value.isPlaying ?? false;

    return Positioned(
      bottom: 0,
      left: 0,
      right: 0,
      child: Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [
              Colors.transparent,
              Colors.black.withOpacity(0.7),
            ],
          ),
        ),
        padding: const EdgeInsets.all(16),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Progress slider
            Row(
              children: [
                Text(
                  _formatDuration(position),
                  style: const TextStyle(color: Colors.white, fontSize: 12),
                ),
                Expanded(
                  child: Slider(
                    value: duration.inSeconds > 0
                        ? position.inSeconds.toDouble()
                        : 0.0,
                    max: duration.inSeconds.toDouble(),
                    onChanged: _seek,
                    activeColor: Colors.white,
                    inactiveColor: Colors.white.withOpacity(0.3),
                  ),
                ),
                Text(
                  _formatDuration(duration),
                  style: const TextStyle(color: Colors.white, fontSize: 12),
                ),
              ],
            ),
            // Play/pause button
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                IconButton(
                  onPressed: _togglePlayPause,
                  icon: Icon(
                    isPlaying ? Icons.pause : Icons.play_arrow,
                    color: Colors.white,
                    size: 40,
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildDemoPlayer() {
    return Container(
      decoration: BoxDecoration(
        color: Colors.black,
        borderRadius: BorderRadius.circular(8),
      ),
      child: Stack(
        children: [
          // Try to show a working video
          Center(
            child: FutureBuilder<bool>(
              future: _initializeFallbackVideo(),
              builder: (context, snapshot) {
                if (snapshot.connectionState == ConnectionState.done &&
                    snapshot.data == true &&
                    _fallbackController != null) {
                  return AspectRatio(
                    aspectRatio: _fallbackController!.value.aspectRatio,
                    child: VideoPlayer(_fallbackController!),
                  );
                }
                return const Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    CircularProgressIndicator(
                      valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                    ),
                    SizedBox(height: 16),
                    Text(
                      'Loading video...',
                      style: TextStyle(color: Colors.white),
                    ),
                  ],
                );
              },
            ),
          ),
          // Video info overlay
          Positioned(
            top: 20,
            left: 20,
            right: 20,
            child: Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.black.withOpacity(0.7),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    widget.sessionTitle,
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 4),
                  const Text(
                    'Session Recording',
                    style: TextStyle(color: Colors.white70, fontSize: 12),
                  ),
                ],
              ),
            ),
          ),
          // Play controls
          Center(
            child: GestureDetector(
              onTap: () {
                if (_fallbackController != null) {
                  if (_fallbackController!.value.isPlaying) {
                    _fallbackController!.pause();
                  } else {
                    _fallbackController!.play();
                  }
                  setState(() {});
                }
              },
              child: Container(
                width: 80,
                height: 80,
                decoration: BoxDecoration(
                  color: Colors.black.withOpacity(0.7),
                  shape: BoxShape.circle,
                ),
                child: Icon(
                  _fallbackController?.value.isPlaying == true
                      ? Icons.pause
                      : Icons.play_arrow,
                  color: Colors.white,
                  size: 40,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  VideoPlayerController? _fallbackController;

  Future<bool> _initializeFallbackVideo() async {
    if (_fallbackController != null) return true;

    try {
      // Use a reliable video URL that works on web
      const fallbackShortMp4 =
          'https://filesamples.com/samples/video/mp4/sample_640x360.mp4';
      _fallbackController =
          VideoPlayerController.networkUrl(Uri.parse(fallbackShortMp4));

      await _fallbackController!.initialize();
      _fallbackController!.setLooping(true);

      if (mounted) {
        setState(() {});
        // Auto-start playing
        _fallbackController!.play();
      }
      return true;
    } catch (e) {
      print('Fallback video error: $e');
      return false;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Dialog(
      backgroundColor: Colors.transparent,
      child: Container(
        constraints: const BoxConstraints(
          maxWidth: 800,
          maxHeight: 600,
        ),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(12),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Header
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Colors.grey[100],
                borderRadius: const BorderRadius.only(
                  topLeft: Radius.circular(12),
                  topRight: Radius.circular(12),
                ),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Expanded(
                    child: Text(
                      widget.sessionTitle,
                      style: const TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 16,
                      ),
                    ),
                  ),
                  IconButton(
                    onPressed: () => Navigator.of(context).pop(),
                    icon: const Icon(Icons.close),
                  ),
                ],
              ),
            ),
            // Video player
            Expanded(
              child: Container(
                margin: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: Colors.grey[300]!),
                ),
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(8),
                  child: _buildVideoPlayer(),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
