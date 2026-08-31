import 'dart:async';

import 'package:flutter/material.dart';
import 'package:just_audio/just_audio.dart';

/// Audio player variant.
enum LingAudioPlayerVariant {
  /// Compact horizontal bar with play/pause + progress.
  compact,

  /// Full card with artwork, title, progress, and controls.
  full,

  /// Minimal — just play/pause button + time.
  minimal,
}

/// A reusable audio player widget built on [just_audio].
///
/// Supports three variants:
/// - [LingAudioPlayerVariant.compact]: horizontal bar with play/pause + seek bar.
/// - [LingAudioPlayerVariant.full]: card with artwork, title, subtitle, controls.
/// - [LingAudioPlayerVariant.minimal]: just play/pause + time display.
class LingAudioPlayer extends StatefulWidget {
  final String url;
  final String? title;
  final String? subtitle;
  final Widget? artwork;
  final LingAudioPlayerVariant variant;
  final bool autoLoad;
  final Color? backgroundColor;
  final double? artworkSize;

  const LingAudioPlayer({
    super.key,
    required this.url,
    this.title,
    this.subtitle,
    this.artwork,
    this.variant = LingAudioPlayerVariant.compact,
    this.autoLoad = true,
    this.backgroundColor,
    this.artworkSize,
  });

  @override
  State<LingAudioPlayer> createState() => _LingAudioPlayerState();
}

class _LingAudioPlayerState extends State<LingAudioPlayer> {
  late final AudioPlayer _player;
  final List<StreamSubscription> _subs = [];
  bool _isLoading = false;
  bool _hasError = false;
  bool _isPlaying = false;
  Duration _duration = Duration.zero;
  Duration _position = Duration.zero;

  @override
  void initState() {
    super.initState();
    _player = AudioPlayer();
    _setupListeners();
    if (widget.autoLoad) {
      _loadAudio();
    }
  }

  void _setupListeners() {
    _subs.add(_player.playerStateStream.listen((state) {
      if (!mounted) return;
      setState(() {
        _isPlaying = state.playing;
        if (state.processingState == ProcessingState.completed) {
          _player.seek(Duration.zero);
          _player.pause();
        }
      });
    }));

    _subs.add(_player.durationStream.listen((d) {
      if (!mounted) return;
      setState(() => _duration = d ?? Duration.zero);
    }));

    _subs.add(_player.positionStream.listen((p) {
      if (!mounted) return;
      setState(() => _position = p);
    }));

    _subs.add(_player.processingStateStream.listen((state) {
      if (!mounted) return;
      setState(() {
        _isLoading = state == ProcessingState.loading || state == ProcessingState.buffering;
        _hasError = false;
      });
    }));

    _subs.add(_player.playbackEventStream.listen(
      (_) {},
      onError: (Object e, StackTrace st) {
        if (!mounted) return;
        setState(() {
          _isLoading = false;
          _hasError = true;
        });
      },
    ));
  }

  Future<void> _loadAudio() async {
    try {
      setState(() {
        _isLoading = true;
        _hasError = false;
      });
      await _player.setUrl(widget.url);
      setState(() => _isLoading = false);
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _isLoading = false;
        _hasError = true;
      });
    }
  }

  Future<void> _togglePlay() async {
    if (_hasError) {
      await _loadAudio();
      return;
    }
    if (_isPlaying) {
      await _player.pause();
    } else {
      await _player.play();
    }
  }

  String _formatDuration(Duration d) {
    final m = d.inMinutes.remainder(60).toString().padLeft(2, '0');
    final s = d.inSeconds.remainder(60).toString().padLeft(2, '0');
    return '$m:$s';
  }

  @override
  void dispose() {
    for (final s in _subs) {
      s.cancel();
    }
    _subs.clear();
    _player.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    switch (widget.variant) {
      case LingAudioPlayerVariant.compact:
        return _buildCompact(context);
      case LingAudioPlayerVariant.full:
        return _buildFull(context);
      case LingAudioPlayerVariant.minimal:
        return _buildMinimal(context);
    }
  }

  Widget _buildCompact(BuildContext context) {
    final theme = Theme.of(context);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: widget.backgroundColor ?? theme.colorScheme.surfaceContainerHighest,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        children: [
          _buildPlayButton(context, size: 36),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                if (widget.title != null)
                  Text(widget.title!, maxLines: 1, overflow: TextOverflow.ellipsis,
                      style: theme.textTheme.bodyMedium?.copyWith(fontWeight: FontWeight.w600)),
                const SizedBox(height: 4),
                Row(
                  children: [
                    Text(_formatDuration(_position), style: theme.textTheme.labelSmall),
                    Expanded(
                      child: Slider(
                        value: _duration.inMilliseconds > 0
                            ? _position.inMilliseconds / _duration.inMilliseconds
                            : 0,
                        onChanged: _duration.inMilliseconds > 0
                            ? (v) => _player.seek(Duration(milliseconds: (v * _duration.inMilliseconds).toInt()))
                            : null,
                      ),
                    ),
                    Text(_formatDuration(_duration), style: theme.textTheme.labelSmall),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildFull(BuildContext context) {
    final theme = Theme.of(context);
    final artSize = widget.artworkSize ?? 120;
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: widget.backgroundColor ?? theme.colorScheme.surface,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.08),
            blurRadius: 12,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // Artwork
          Container(
            width: artSize,
            height: artSize,
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(12),
              color: theme.colorScheme.primaryContainer,
            ),
            child: widget.artwork ??
                Icon(Icons.music_note, size: artSize * 0.4, color: theme.colorScheme.onPrimaryContainer),
          ),
          const SizedBox(height: 16),
          // Title
          if (widget.title != null)
            Text(widget.title!, maxLines: 1, overflow: TextOverflow.ellipsis,
                style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w600)),
          if (widget.subtitle != null) ...[
            const SizedBox(height: 4),
            Text(widget.subtitle!, maxLines: 1, overflow: TextOverflow.ellipsis,
                style: theme.textTheme.bodySmall?.copyWith(color: theme.colorScheme.onSurfaceVariant)),
          ],
          const SizedBox(height: 16),
          // Progress bar
          Slider(
            value: _duration.inMilliseconds > 0
                ? _position.inMilliseconds / _duration.inMilliseconds
                : 0,
            onChanged: _duration.inMilliseconds > 0
                ? (v) => _player.seek(Duration(milliseconds: (v * _duration.inMilliseconds).toInt()))
                : null,
          ),
          // Time labels
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(_formatDuration(_position), style: theme.textTheme.labelSmall),
              Text(_formatDuration(_duration), style: theme.textTheme.labelSmall),
            ],
          ),
          const SizedBox(height: 12),
          // Controls
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              IconButton(
                icon: const Icon(Icons.replay_10),
                iconSize: 28,
                onPressed: () => _player.seek(_position - const Duration(seconds: 10)),
              ),
              const SizedBox(width: 16),
              _buildPlayButton(context, size: 56),
              const SizedBox(width: 16),
              IconButton(
                icon: const Icon(Icons.forward_10),
                iconSize: 28,
                onPressed: () => _player.seek(_position + const Duration(seconds: 10)),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildMinimal(BuildContext context) {
    final theme = Theme.of(context);
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        _buildPlayButton(context, size: 32),
        const SizedBox(width: 8),
        Text(
          '${_formatDuration(_position)} / ${_formatDuration(_duration)}',
          style: theme.textTheme.labelMedium,
        ),
      ],
    );
  }

  Widget _buildPlayButton(BuildContext context, {double size = 48}) {
    final theme = Theme.of(context);
    if (_isLoading) {
      return SizedBox(
        width: size,
        height: size,
        child: Padding(
          padding: const EdgeInsets.all(8),
          child: CircularProgressIndicator(strokeWidth: 2, color: theme.colorScheme.primary),
        ),
      );
    }
    return SizedBox(
      width: size,
      height: size,
      child: IconButton.filled(
        icon: Icon(_isPlaying ? Icons.pause : Icons.play_arrow, size: size * 0.5),
        onPressed: _togglePlay,
        style: IconButton.styleFrom(
          backgroundColor: theme.colorScheme.primary,
          foregroundColor: theme.colorScheme.onPrimary,
        ),
      ),
    );
  }
}
