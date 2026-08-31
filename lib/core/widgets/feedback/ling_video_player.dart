import 'package:flutter/material.dart';
import 'package:video_player/video_player.dart';

/// A reusable video player widget with controls overlay.
///
/// Supports:
/// - Play/pause toggle.
/// - Seek bar with time display.
/// - Fullscreen toggle.
/// - Mute/unmute.
/// - Loading and error states.
class LingVideoPlayer extends StatefulWidget {
  final String url;
  final bool autoPlay;
  final bool loop;
  final double aspectRatio;
  final Color? overlayColor;
  final bool showControls;
  final Widget? placeholder;

  const LingVideoPlayer({
    super.key,
    required this.url,
    this.autoPlay = false,
    this.loop = false,
    this.aspectRatio = 16 / 9,
    this.overlayColor,
    this.showControls = true,
    this.placeholder,
  });

  @override
  State<LingVideoPlayer> createState() => _LingVideoPlayerState();
}

class _LingVideoPlayerState extends State<LingVideoPlayer> {
  VideoPlayerController? _controller;
  bool _isInitialized = false;
  bool _hasError = false;
  bool _isPlaying = false;
  bool _showOverlay = true;
  bool _isMuted = false;

  @override
  void initState() {
    super.initState();
    _setupController();
  }

  void _setupController() {
    _controller = VideoPlayerController.networkUrl(
      Uri.parse(widget.url),
      videoPlayerOptions: VideoPlayerOptions(mixWithOthers: true),
    );
    // Add listener BEFORE initialize so we catch all events
    _controller!.addListener(_onControllerChanged);
    _initController();
  }

  void _onControllerChanged() {
    if (!mounted || _controller == null) return;
    final ctrl = _controller!;
    if (ctrl.value.hasError) {
      debugPrint('LingVideoPlayer error: ${ctrl.value.errorDescription}');
      if (!_hasError) setState(() => _hasError = true);
      return;
    }
    if (ctrl.value.isInitialized && !_isInitialized) {
      setState(() => _isInitialized = true);
    }
    final playing = ctrl.value.isPlaying;
    if (playing != _isPlaying) {
      setState(() => _isPlaying = playing);
    }
  }

  @override
  void didUpdateWidget(covariant LingVideoPlayer oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.url != widget.url) {
      _controller?.removeListener(_onControllerChanged);
      _controller?.dispose();
      _isInitialized = false;
      _hasError = false;
      _isPlaying = false;
      _setupController();
    }
  }

  Future<void> _initController() async {
    try {
      await _controller!.initialize();
      if (!mounted) {
        _controller?.dispose();
        return;
      }
      _controller!.setLooping(widget.loop);
      if (widget.autoPlay) {
        await _controller!.play();
      }
      // _isInitialized is set by listener
      if (mounted && !_isInitialized) {
        setState(() => _isInitialized = true);
      }
    } catch (e) {
      debugPrint('LingVideoPlayer init error: $e');
      if (!mounted) return;
      setState(() => _hasError = true);
    }
  }

  void _togglePlay() {
    final ctrl = _controller;
    if (ctrl == null || !ctrl.value.isInitialized) return;
    if (ctrl.value.isPlaying) {
      ctrl.pause();
    } else {
      ctrl.play();
    }
  }

  void _toggleMute() {
    final ctrl = _controller;
    if (ctrl == null) return;
    setState(() {
      _isMuted = !_isMuted;
      ctrl.setVolume(_isMuted ? 0 : 1);
    });
  }

  void _toggleOverlay() {
    setState(() => _showOverlay = !_showOverlay);
  }

  String _formatDuration(Duration d) {
    final h = d.inHours;
    final m = d.inMinutes.remainder(60).toString().padLeft(2, '0');
    final s = d.inSeconds.remainder(60).toString().padLeft(2, '0');
    return h > 0 ? '$h:$m:$s' : '$m:$s';
  }

  @override
  void dispose() {
    _controller?.removeListener(_onControllerChanged);
    _controller?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (_hasError) {
      return _buildError(context);
    }
    if (!_isInitialized) {
      return _buildLoading(context);
    }

    final ctrl = _controller;
    if (ctrl == null || !ctrl.value.isInitialized) {
      return _buildLoading(context);
    }

    // Use actual video aspect ratio if available
    final videoAspect = ctrl.value.aspectRatio;
    return AspectRatio(
      aspectRatio: videoAspect > 0 ? videoAspect : widget.aspectRatio,
      child: GestureDetector(
        onTap: widget.showControls ? _toggleOverlay : null,
        child: Stack(
          alignment: Alignment.center,
          children: [
            ClipRRect(
              borderRadius: BorderRadius.circular(12),
              child: VideoPlayer(ctrl),
            ),
            if (widget.showControls && _showOverlay) _buildControls(context),
          ],
        ),
      ),
    );
  }

  Widget _buildLoading(BuildContext context) {
    return AspectRatio(
      aspectRatio: widget.aspectRatio,
      child: Container(
        decoration: BoxDecoration(
          color: Colors.black,
          borderRadius: BorderRadius.circular(12),
        ),
        child: widget.placeholder ??
            const Center(
              child: CircularProgressIndicator(color: Colors.white),
            ),
      ),
    );
  }

  Widget _buildError(BuildContext context) {
    return AspectRatio(
      aspectRatio: widget.aspectRatio,
      child: Container(
        decoration: BoxDecoration(
          color: Colors.black,
          borderRadius: BorderRadius.circular(12),
        ),
        child: const Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(Icons.error_outline, color: Colors.white54, size: 48),
              SizedBox(height: 8),
              Text('播放失败', style: const TextStyle(color: Colors.white54)),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildControls(BuildContext context) {
    final ctrl = _controller;
    if (ctrl == null) return const SizedBox.shrink();
    final position = ctrl.value.position;
    final duration = ctrl.value.duration;
    final progress = duration.inMilliseconds > 0
        ? position.inMilliseconds / duration.inMilliseconds
        : 0.0;

    return Stack(
      children: [
        // Dark gradient overlay
        Positioned.fill(
          child: DecoratedBox(
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(12),
              gradient: LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                colors: [
                  Colors.black.withOpacity(0.3),
                  Colors.transparent,
                  Colors.transparent,
                  Colors.black.withOpacity(0.5),
                ],
                stops: const [0, 0.15, 0.85, 1],
              ),
            ),
          ),
        ),
        // Center play/pause
        Center(
          child: Container(
            width: 56,
            height: 56,
            decoration: const BoxDecoration(
              color: Colors.black54,
              shape: BoxShape.circle,
            ),
            child: IconButton(
              icon: Icon(_isPlaying ? Icons.pause : Icons.play_arrow, color: Colors.white, size: 28),
              onPressed: _togglePlay,
            ),
          ),
        ),
        // Bottom controls
        Positioned(
          left: 0,
          right: 0,
          bottom: 0,
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                // Seek bar
                Row(
                  children: [
                    Text(
                      _formatDuration(position),
                      style: const TextStyle(color: Colors.white, fontSize: 12),
                    ),
                    Expanded(
                      child: Slider(
                        value: progress.clamp(0.0, 1.0),
                        activeColor: Colors.white,
                        inactiveColor: Colors.white24,
                        onChanged: (v) {
                          _controller?.seekTo(Duration(
                            milliseconds: (v * duration.inMilliseconds).toInt(),
                          ));
                        },
                      ),
                    ),
                    Text(
                      _formatDuration(duration),
                      style: const TextStyle(color: Colors.white, fontSize: 12),
                    ),
                    // Mute button
                    IconButton(
                      icon: Icon(_isMuted ? Icons.volume_off : Icons.volume_up,
                          color: Colors.white, size: 20),
                      onPressed: _toggleMute,
                      visualDensity: VisualDensity.compact,
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }
}
