import  dart:io ;
import  package:flutter/material.dart ;
import  package:flutter/services.dart ;
import  package:media_kit/media_kit.dart ;
import  package:media_kit_video/media_kit_video.dart ;
import  package:screen_brightness/screen_brightness.dart ;
import  package:volume_controller/volume_controller.dart ;
import  package:file_picker/file_picker.dart ;
import  package:dio/dio.dart ;
import  package:path_provider/path_provider.dart ;
import  package:permission_handler/permission_handler.dart ;
import  package:youtube_explode_dart/youtube_explode_dart.dart  as yt_exp;

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  MediaKit.ensureInitialized();
  runApp(const MaterialApp(
    home: MainNavigationScreen(),
    debugShowCheckedModeBanner: false,
  ));
}

class MainNavigationScreen extends StatefulWidget {
  const MainNavigationScreen({super.key});

  @override
  State<MainNavigationScreen> createState() => _MainNavigationScreenState();
}

class _MainNavigationScreenState extends State<MainNavigationScreen> {
  int _currentIndex = 0;
  final List<Widget> _screens = [
    const VideoPlayerCustomScreen(),
    const AudioPlayerScreen(),
    const DownloaderScreen(),
  ];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: _screens[_currentIndex],
      bottomNavigationBar: BottomNavigationBar(
        currentIndex: _currentIndex,
        onTap: (index) => setState(() => _currentIndex = index),
        items: const [
          BottomNavigationBarItem(icon: Icon(Icons.movie), label:  الفيديو ),
          BottomNavigationBarItem(icon: Icon(Icons.music_note), label:  الموسيقى ),
          BottomNavigationBarItem(icon: Icon(Icons.download), label:  التحميل ),
        ],
      ),
    );
  }
}

// ---------------------- 1. مشغل الفيديو بجميع الصيغ والإيماءات ----------------------
class VideoPlayerCustomScreen extends StatefulWidget {
  final String? videoPath;
  const VideoPlayerCustomScreen({super.key, this.videoPath});

  @override
  State<VideoPlayerCustomScreen> createState() => _VideoPlayerCustomScreenState();
}

class _VideoPlayerCustomScreenState extends State<VideoPlayerCustomScreen> {
  late final Player _player = Player();
  late final VideoController _controller = VideoController(_player);

  double _currentBrightness = 0.5;
  double _currentVolume = 0.5;

  @override
  void initState() {
    super.initState();
    if (widget.videoPath != null) {
      _player.open(Media(widget.videoPath!));
    }
  }

  void _pickLocalVideo() async {
    FilePickerResult? result = await FilePicker.platform.pickFiles(type: FileType.video);
    if (result != null && result.files.single.path != null) {
      _player.open(Media(result.files.single.path!));
    }
  }

  void _pickSubtitleFile() async {
    FilePickerResult? result = await FilePicker.platform.pickFiles(
      type: FileType.custom,
      allowedExtensions: [ srt ,  vtt ,  ass ],
    );
    if (result != null && result.files.single.path != null) {
      _player.setSubtitleTrack(SubtitleTrack.uri(result.files.single.path!));
    }
  }

  void _handleVerticalDrag(DragUpdateDetails details, bool isLeft) async {
    double delta = -details.primaryDelta! / 200;
    if (isLeft) {
      // تعديل السطوع للجهة اليسرى
      try {
        _currentBrightness = (_currentBrightness + delta).clamp(0.0, 1.0);
        await ScreenBrightness().setScreenBrightness(_currentBrightness);
      } catch (_) {}
    } else {
      // تعديل الصوت للجهة اليمنى
      _currentVolume = (_currentVolume + delta).clamp(0.0, 1.0);
      VolumeController().setVolume(_currentVolume);
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
        title: const Text( مشغل الفيديو المتقدم ),
        backgroundColor: Colors.black87,
        actions: [
          IconButton(icon: const Icon(Icons.folder_open), onPressed: _pickLocalVideo),
          IconButton(icon: const Icon(Icons.subtitles), onPressed: _pickSubtitleFile),
          PopupMenuButton<double>(
            icon: const Icon(Icons.speed),
            onSelected: (speed) => _player.setRate(speed),
            itemBuilder: (context) => [
              0.5, 0.75, 1.0, 1.25, 1.5, 2.0
            ].map((s) => PopupMenuItem(value: s, child: Text( ${s}x ))).toList(),
          )
        ],
      ),
      body: Stack(
        children: [
          Center(child: Video(controller: _controller)),
          // التحكم بالإيماءات يميناً ويساراً
          Row(
            children: [
              Expanded(
                child: GestureDetector(
                  onVerticalDragUpdate: (d) => _handleVerticalDrag(d, true),
                  onDoubleTap: () => _player.seek(_player.state.position - const Duration(seconds: 10)),
                  behavior: HitTestBehavior.translucent,
                ),
              ),
              Expanded(
                child: GestureDetector(
                  onVerticalDragUpdate: (d) => _handleVerticalDrag(d, false),
                  onDoubleTap: () => _player.seek(_player.state.position + const Duration(seconds: 10)),
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

// ---------------------- 2. مشغل الموسيقى والصوت ----------------------
class AudioPlayerScreen extends StatefulWidget {
  const AudioPlayerScreen({super.key});

  @override
  State<AudioPlayerScreen> createState() => _AudioPlayerScreenState();
}

class _AudioPlayerScreenState extends State<AudioPlayerScreen> {
  late final Player _audioPlayer = Player();
  String _trackTitle = "لم يتم اختيار ملف صوتي";

  void _pickAudio() async {
    FilePickerResult? result = await FilePicker.platform.pickFiles(type: FileType.audio);
    if (result != null && result.files.single.path != null) {
      setState(() => _trackTitle = result.files.single.name);
      _audioPlayer.open(Media(result.files.single.path!));
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
      appBar: AppBar(title: const Text( مشغل الموسيقى )),
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.music_note, size: 100, color: Colors.blueAccent),
            const SizedBox(height: 20),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20),
              child: Text(_trackTitle, textAlign: TextAlign.center, style: const TextStyle(fontSize: 16)),
            ),
            const SizedBox(height: 30),
            ElevatedButton.icon(
              onPressed: _pickAudio,
              icon: const Icon(Icons.audio_file),
              label: const Text( فتح ملف صوتي ),
            ),
            const SizedBox(height: 20),
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                IconButton(icon: const Icon(Icons.replay_10), onPressed: () => _audioPlayer.seek(_audioPlayer.state.position - const Duration(seconds: 10))),
                IconButton(icon: const Icon(Icons.play_arrow, size: 40), onPressed: () => _audioPlayer.playOrPause()),
                IconButton(icon: const Icon(Icons.forward_10), onPressed: () => _audioPlayer.seek(_audioPlayer.state.position + const Duration(seconds: 10))),
              ],
            )
          ],
        ),
      ),
    );
  }
}

// ---------------------- 3. أداة التحميل الشاملة ----------------------
class DownloaderScreen extends StatefulWidget {
  const DownloaderScreen({super.key});

  @override
  State<DownloaderScreen> createState() => _DownloaderScreenState();
}

class _DownloaderScreenState extends State<DownloaderScreen> {
  final TextEditingController _urlController = TextEditingController();
  final Dio _dio = Dio();
  double _progress = 0.0;
  bool _isDownloading = false;
  String _status =   ;

  Future<void> _startDownload(bool audioOnly) async {
    String url = _urlController.text.trim();
    if (url.isEmpty) return;

    setState(() {
      _isDownloading = true;
      _progress = 0.0;
      _status =  جاري الاتصال واستخراج الرابط... ;
    });

    await Permission.storage.request();
    await Permission.manageExternalStorage.request();

    try {
      Directory? dir = await getExternalStorageDirectory();
      String ext = audioOnly ?  mp3  :  mp4 ;
      String savePath = "${dir!.path}/download_${DateTime.now().millisecondsSinceEpoch}.$ext";

      if (url.contains( youtube.com ) || url.contains( youtu.be )) {
        var yt = yt_exp.YoutubeExplode();
        var video = await yt.videos.get(url);
        var manifest = await yt.videos.streamsClient.getManifest(video.id);

        var streamInfo = audioOnly
            ? manifest.audioOnly.withHighestBitrate()
            : manifest.muxed.withHighestBitrate();

        var stream = yt.videos.streamsClient.get(streamInfo);
        var file = File(savePath);
        var output = file.openWrite();
        var bytes = 0;

        await for (final chunk in stream) {
          bytes += chunk.length;
          output.add(chunk);
          setState(() => _progress = bytes / streamInfo.size.totalBytes);
        }
        await output.close();
        yt.close();
      } else {
        await _dio.download(url, savePath, onReceiveProgress: (rec, total) {
          if (total != -1) setState(() => _progress = rec / total);
        });
      }

      setState(() {
        _isDownloading = false;
        _status =  اكتمل التحميل بنجاح!\nالمسار: $savePath ;
      });
    } catch (e) {
      setState(() {
        _isDownloading = false;
        _status =  فشل التحميل، تأكد من صحة الرابط أو الأذونات. ;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text( أداة التحميل )),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          children: [
            TextField(
              controller: _urlController,
              decoration: const InputDecoration(
                hintText:  ضع الرابط هنا (YouTube, TikTok, FB...) ,
                border: OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 16),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceEvenly,
              children: [
                ElevatedButton.icon(
                  onPressed: _isDownloading ? null : () => _startDownload(false),
                  icon: const Icon(Icons.video_collection),
                  label: const Text( تحميل فيديو ),
                ),
                ElevatedButton.icon(
                  onPressed: _isDownloading ? null : () => _startDownload(true),
                  icon: const Icon(Icons.audiotrack),
                  label: const Text( تحميل صوت MP3 ),
                ),
              ],
            ),
            const SizedBox(height: 24),
            if (_isDownloading) ...[
              LinearProgressIndicator(value: _progress),
              const SizedBox(height: 8),
              Text( ${(_progress * 100).toStringAsFixed(1)}% ),
            ],
            const SizedBox(height: 12),
            Text(_status, textAlign: TextAlign.center),
          ],
        ),
      ),
    );
  }
}
