import 'dart:async';
import 'package:audioplayers/audioplayers.dart';
import 'package:flutter/material.dart';
import 'package:open_filex/open_filex.dart';
import 'package:path/path.dart' as p;

bool isAudioAttachment(String path) => const {
  '.mp3',
  '.m4a',
  '.aac',
  '.wav',
  '.ogg',
  '.opus',
  '.flac',
  '.amr',
}.contains(p.extension(path).toLowerCase());

class AudioAttachment extends StatefulWidget {
  const AudioAttachment({super.key, required this.path});
  final String path;
  @override
  State<AudioAttachment> createState() => _AudioAttachmentState();
}

class _AudioAttachmentState extends State<AudioAttachment>
    with WidgetsBindingObserver {
  final player = AudioPlayer();
  final subscriptions = <StreamSubscription<dynamic>>[];
  Duration duration = Duration.zero, position = Duration.zero;
  bool playing = false, loading = false, ready = false;
  String? error;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    subscriptions.addAll([
      player.onDurationChanged.listen((value) {
        if (mounted) setState(() => duration = value);
      }),
      player.onPositionChanged.listen((value) {
        if (mounted) setState(() => position = value);
      }),
      player.onPlayerStateChanged.listen((value) {
        if (mounted) setState(() => playing = value == PlayerState.playing);
      }),
      player.onPlayerComplete.listen((_) {
        if (mounted)
          setState(() {
            playing = false;
            position = Duration.zero;
          });
      }),
    ]);
    for (final subscription in subscriptions) {
      subscription.onError(_onAudioError);
    }
  }

  void _onAudioError(Object _) {
    if (mounted)
      setState(() {
        error = '无法播放此音频，可尝试用系统应用打开';
        playing = false;
        ready = false;
        loading = false;
      });
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state != AppLifecycleState.resumed && playing)
      unawaited(player.pause().catchError(_onAudioError));
  }

  Future<void> toggle() async {
    if (loading) return;
    setState(() {
      loading = true;
      error = null;
    });
    try {
      if (playing) {
        await player.pause();
      } else {
        if (!ready) {
          await player.setReleaseMode(ReleaseMode.stop);
          await player.setSource(DeviceFileSource(widget.path));
          ready = true;
        }
        await player.resume();
      }
    } catch (_) {
      if (mounted) setState(() => error = '无法播放此音频，可尝试用系统应用打开');
    } finally {
      if (mounted) setState(() => loading = false);
    }
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    for (final subscription in subscriptions) {
      unawaited(subscription.cancel());
    }
    unawaited(player.dispose());
    super.dispose();
  }

  String time(Duration value) =>
      '${value.inMinutes}:${(value.inSeconds % 60).toString().padLeft(2, '0')}';

  @override
  Widget build(BuildContext context) => Card(
    child: Padding(
      padding: const EdgeInsets.all(12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            p.basename(widget.path),
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
          ),
          Row(
            children: [
              IconButton(
                tooltip: playing ? '暂停音频' : '播放音频',
                onPressed: loading ? null : toggle,
                icon: loading
                    ? const SizedBox(
                        width: 22,
                        height: 22,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : Icon(
                        playing
                            ? Icons.pause_circle_filled
                            : Icons.play_circle_fill,
                      ),
              ),
              Expanded(
                child: Slider(
                  value: position.inMilliseconds.toDouble().clamp(
                    0,
                    duration.inMilliseconds.toDouble(),
                  ),
                  max: duration.inMilliseconds > 0
                      ? duration.inMilliseconds.toDouble()
                      : 1,
                  onChanged: !ready || duration == Duration.zero
                      ? null
                      : (value) {
                          setState(
                            () => position = Duration(
                              milliseconds: value.round(),
                            ),
                          );
                          unawaited(player.seek(position));
                        },
                ),
              ),
              Text(
                '${time(position)} / ${time(duration)}',
                style: Theme.of(context).textTheme.bodySmall,
              ),
            ],
          ),
          if (error != null)
            TextButton(
              onPressed: () => OpenFilex.open(widget.path),
              child: Text(error!),
            ),
        ],
      ),
    ),
  );
}
