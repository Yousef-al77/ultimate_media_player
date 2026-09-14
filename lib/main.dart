import 'dart:io';

import 'package:dio/dio.dart';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:media_kit/media_kit.dart';
import 'package:media_kit_video/media_kit_video.dart';
import 'package:path_provider/path_provider.dart';
import 'package:screen_brightness/screen_brightness.dart';
import 'package:volume_controller/volume_controller.dart';
import 'package:youtube_explode_dart/youtube_explode_dart.dart' as yt_exp;

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  MediaKit.ensureInitialized();

  runApp(
    const MaterialApp(
      debugShowCheckedModeBanner: false,
      home: MainNavigationScreen(),
    ),
  );
}

class MainNavigationScreen extends StatefulWidget {
  const MainNavigationScreen({super.key});

  @override
  State<MainNavigationScreen> createState() =>
      _MainNavigationScreenState();
}

class _MainNavigationScreenState extends State<MainNavigationScreen> {
  int _currentIndex = 0;

  final List<Widget> _screens = const [
    VideoPlayerCustomScreen(),
    AudioPlayerScreen(),
    DownloaderScreen(),
  ];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: _screens[_currentIndex],
      bottomNavigationBar: BottomNavigationBar(
        currentIndex: _currentIndex,
        onTap: (index) {
          setState(() {
            _currentIndex = index;
          });
        },
        items: const [
          BottomNavigationBarItem(
            icon: Icon(Icons.movie),
            label: 'الفيديو',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.music_note),
            label: 'الموسيقى',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.download),
            label: 'التحميل',
          ),
        ],
      ),
    );
  }
}

// ============================================================
// VIDEO PLAYER
// ============================================================

class VideoPlayerCustomScreen extends StatefulWidget {
  final String? videoPath;

  const VideoPlayerCustomScreen({
    super.key,
    this.videoPath,
  });

  @override
  State<VideoPlayerCustomScreen> createState() =>
      _VideoPlayerCustomScreenState();
}

class _VideoPlayerCustomScreenState
    extends State<VideoPlayerCustomScreen> {
  late final Player _player;
  late final VideoController _controller;

  double _currentBrightness = 0.5;
  double _currentVolume = 0.5;

  @override
  void initState() {
    super.initState();

    _player = Player();
    _controller = VideoController(_player);

    _initializeControls();

    if (widget.videoPath != null) {
      _player.open(
        Media(widget.videoPath!),
      );
    }
  }

  Future<void> _initializeControls() async {
    try {
      _currentBrightness =
          await ScreenBrightness().application;
    } catch (_) {
      _currentBrightness = 0.5;
    }

    try {
      _currentVolume =
          await VolumeController.instance.getVolume();
    } catch (_) {
      _currentVolume = 0.5;
    }
  }

  Future<void> _pickLocalVideo() async {
    final result = await FilePicker.platform.pickFiles(
      type: FileType.video,
    );

    if (!mounted) return;

    final path = result?.files.single.path;

    if (path != null) {
      await _player.open(
        Media(path),
      );
    }
  }

  Future<void> _pickSubtitleFile() async {
    final result = await FilePicker.platform.pickFiles(
      type: FileType.custom,
      allowedExtensions: [
        'srt',
        'vtt',
        'ass',
      ],
    );

    if (!mounted) return;

    final path = result?.files.single.path;

    if (path != null) {
      await _player.setSubtitleTrack(
        SubtitleTrack.uri(path),
      );
    }
  }

  Future<void> _handleVerticalDrag(
    DragUpdateDetails details,
    bool isLeft,
  ) async {
    final primaryDelta = details.primaryDelta;

    if (primaryDelta == null) return;

    final delta = -primaryDelta / 200;

    if (isLeft) {
      try {
        _currentBrightness =
            (_currentBrightness + delta).clamp(0.0, 1.0);

        await ScreenBrightness().setApplicationScreenBrightness(
          _currentBrightness,
        );
      } catch (_) {}
    } else {
      try {
        _currentVolume =
            (_currentVolume + delta).clamp(0.0, 1.0);

        await VolumeController.instance.setVolume(
          _currentVolume,
        );
      } catch (_) {}
    }
  }

  @override
  void dispose() {
    _player.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        title: const Text('مشغل الفيديو'),
        backgroundColor: Colors.black87,
        actions: [
          IconButton(
            icon: const Icon(Icons.folder_open),
            onPressed: _pickLocalVideo,
          ),
          IconButton(
            icon: const Icon(Icons.subtitles),
            onPressed: _pickSubtitleFile,
          ),
          PopupMenuButton<double>(
            icon: const Icon(Icons.speed),
            onSelected: (speed) {
              _player.setRate(speed);
            },
            itemBuilder: (context) {
              const speeds = [
                0.5,
                0.75,
                1.0,
                1.25,
                1.5,
                2.0,
              ];

              return speeds
                  .map(
                    (speed) => PopupMenuItem<double>(
                      value: speed,
                      child: Text('${speed}x'),
                    ),
                  )
                  .toList();
            },
          ),
        ],
      ),
      body: Stack(
        children: [
          Center(
            child: Video(
              controller: _controller,
            ),
          ),

          Row(
            children: [
              Expanded(
                child: GestureDetector(
                  onVerticalDragUpdate: (details) {
                    _handleVerticalDrag(
                      details,
                      true,
                    );
                  },
                  onDoubleTap: () {
                    _player.seek(
                      _player.state.position -
                          const Duration(seconds: 10),
                    );
                  },
                  behavior: HitTestBehavior.translucent,
                ),
              ),

              Expanded(
                child: GestureDetector(
                  onVerticalDragUpdate: (details) {
                    _handleVerticalDrag(
                      details,
                      false,
                    );
                  },
                  onDoubleTap: () {
                    _player.seek(
                      _player.state.position +
                          const Duration(seconds: 10),
                    );
                  },
                  behavior: HitTestBehavior.translucent,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

// ============================================================
// AUDIO PLAYER
// ============================================================

class AudioPlayerScreen extends StatefulWidget {
  const AudioPlayerScreen({super.key});

  @override
  State<AudioPlayerScreen> createState() =>
      _AudioPlayerScreenState();
}

class _AudioPlayerScreenState
    extends State<AudioPlayerScreen> {
  late final Player _audioPlayer;

  String _trackTitle = 'لم يتم اختيار ملف صوتي';

  @override
  void initState() {
    super.initState();
    _audioPlayer = Player();
  }

  Future<void> _pickAudio() async {
    final result = await FilePicker.platform.pickFiles(
      type: FileType.audio,
    );

    if (!mounted) return;

    final path = result?.files.single.path;

    if (path != null) {
      setState(() {
        _trackTitle = result!.files.single.name;
      });

      await _audioPlayer.open(
        Media(path),
      );
    }
  }

  @override
  void dispose() {
    _audioPlayer.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('مشغل الموسيقى'),
      ),
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(
              Icons.music_note,
              size: 100,
              color: Colors.blueAccent,
            ),

            const SizedBox(height: 20),

            Padding(
              padding:
                  const EdgeInsets.symmetric(horizontal: 20),
              child: Text(
                _trackTitle,
                textAlign: TextAlign.center,
                style: const TextStyle(
                  fontSize: 16,
                ),
              ),
            ),

            const SizedBox(height: 30),

            ElevatedButton.icon(
              onPressed: _pickAudio,
              icon: const Icon(Icons.audio_file),
              label: const Text('فتح ملف صوتي'),
            ),

            const SizedBox(height: 20),

            Row(
              mainAxisAlignment:
                  MainAxisAlignment.center,
              children: [
                IconButton(
                  icon: const Icon(Icons.replay_10),
                  onPressed: () {
                    _audioPlayer.seek(
                      _audioPlayer.state.position -
                          const Duration(seconds: 10),
                    );
                  },
                ),

                IconButton(
                  icon: const Icon(
                    Icons.play_arrow,
                    size: 40,
                  ),
                  onPressed: () {
                    _audioPlayer.playOrPause();
                  },
                ),

                IconButton(
                  icon: const Icon(Icons.forward_10),
                  onPressed: () {
                    _audioPlayer.seek(
                      _audioPlayer.state.position +
                          const Duration(seconds: 10),
                    );
                  },
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

// ============================================================
// DOWNLOADER
// ============================================================

class DownloaderScreen extends StatefulWidget {
  const DownloaderScreen({super.key});

  @override
  State<DownloaderScreen> createState() =>
      _DownloaderScreenState();
}

class _DownloaderScreenState
    extends State<DownloaderScreen> {
  final TextEditingController _urlController =
      TextEditingController();

  final Dio _dio = Dio();

  double _progress = 0.0;

  bool _isDownloading = false;

  String _status = '';

  Future<void> _startDownload(
    bool audioOnly,
  ) async {
    final url = _urlController.text.trim();

    if (url.isEmpty) {
      setState(() {
        _status = 'ضع رابط الفيديو أولاً';
      });
      return;
    }

    setState(() {
      _isDownloading = true;
      _progress = 0.0;
      _status = 'جاري الاتصال والتحميل...';
    });

    try {
      final Directory? dir =
          await getExternalStorageDirectory();

      if (dir == null) {
        throw Exception(
          'تعذر الوصول إلى مساحة التخزين',
        );
      }

      final extension =
          audioOnly ? 'm4a' : 'mp4';

      final savePath =
          '${dir.path}/download_${DateTime.now().millisecondsSinceEpoch}.$extension';

      final isYouTube =
          url.contains('youtube.com') ||
          url.contains('youtu.be');

      if (isYouTube) {
        await _downloadYouTube(
          url,
          savePath,
          audioOnly,
        );
      } else {
        await _downloadDirectUrl(
          url,
          savePath,
        );
      }

      if (!mounted) return;

      setState(() {
        _isDownloading = false;
        _progress = 1.0;
        _status =
            'اكتمل التحميل بنجاح\nالمسار:\n$savePath';
      });
    } catch (e) {
      if (!mounted) return;

      setState(() {
        _isDownloading = false;
        _status =
            'فشل التحميل\n$e';
      });
    }
  }

  Future<void> _downloadYouTube(
    String url,
    String savePath,
    bool audioOnly,
  ) async {
    final yt = yt_exp.YoutubeExplode();

    try {
      final video = await yt.videos.get(url);

      final manifest =
          await yt.videos.streamsClient.getManifest(
        video.id,
      );

      final streamInfo = audioOnly
          ? manifest.audioOnly.withHighestBitrate()
          : manifest.muxed.withHighestBitrate();

      final stream =
          yt.videos.streamsClient.get(streamInfo);

      final file = File(savePath);

      final output = file.openWrite();

      var bytesReceived = 0;

      await for (final chunk in stream) {
        bytesReceived += chunk.length;

        output.add(chunk);

        if (mounted &&
            streamInfo.size.totalBytes > 0) {
          setState(() {
            _progress =
                bytesReceived /
                    streamInfo.size.totalBytes;
          });
        }
      }

      await output.close();
    } finally {
      yt.close();
    }
  }

  Future<void> _downloadDirectUrl(
    String url,
    String savePath,
  ) async {
    await _dio.download(
      url,
      savePath,
      onReceiveProgress: (received, total) {
        if (!mounted) return;

        if (total > 0) {
          setState(() {
            _progress =
                received / total;
          });
        }
      },
    );
  }

  @override
  void dispose() {
    _urlController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('أداة التحميل'),
      ),

      body: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            TextField(
              controller: _urlController,
              keyboardType: TextInputType.url,
              decoration: const InputDecoration(
                hintText:
                    'ضع الرابط هنا',
                border: OutlineInputBorder(),
              ),
            ),

            const SizedBox(height: 16),

            Row(
              mainAxisAlignment:
                  MainAxisAlignment.spaceEvenly,
              children: [
                ElevatedButton.icon(
                  onPressed: _isDownloading
                      ? null
                      : () {
                          _startDownload(false);
                        },
                  icon: const Icon(
                    Icons.video_collection,
                  ),
                  label: const Text(
                    'تحميل فيديو',
                  ),
                ),

                ElevatedButton.icon(
                  onPressed: _isDownloading
                      ? null
                      : () {
                          _startDownload(true);
                        },
                  icon: const Icon(
                    Icons.audiotrack,
                  ),
                  label: const Text(
                    'تحميل صوت',
                  ),
                ),
              ],
            ),

            const SizedBox(height: 24),

            if (_isDownloading) ...[
              LinearProgressIndicator(
                value: _progress,
              ),

              const SizedBox(height: 8),

              Text(
                '${(_progress * 100).toStringAsFixed(1)}%',
              ),
            ],

            const SizedBox(height: 12),

            Text(
              _status,
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }
}
