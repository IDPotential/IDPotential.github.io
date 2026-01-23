import 'package:flutter/material.dart';
import 'package:video_player/video_player.dart';
import 'package:chewie/chewie.dart';
import 'package:flutter_markdown/flutter_markdown.dart';
import '../data/diagnostic_data.dart';

class RoleDetailScreen extends StatefulWidget {
  final int number;
  final bool isAspect;

  const RoleDetailScreen({
    super.key,
    required this.number,
    required this.isAspect,
  });

  @override
  State<RoleDetailScreen> createState() => _RoleDetailScreenState();
}

class _RoleDetailScreenState extends State<RoleDetailScreen> {
  VideoPlayerController? _videoController;
  ChewieController? _chewieController;
  bool _isLoadingVideo = true;
  String? _errorMessage;

  @override
  void initState() {
    super.initState();
    if (!widget.isAspect) {
      _initializePlayer();
    }
  }

  Future<void> _initializePlayer() async {
    // Format: "role_01.mp4"
    final folderName = widget.number.toString(); // e.g. "1", "22"
    final assetPath = 'video/role_$folderName.mp4';

    try {
      _videoController = VideoPlayerController.asset(assetPath);
      await _videoController!.initialize();
      
      _chewieController = ChewieController(
        videoPlayerController: _videoController!,
        autoPlay: false,
        looping: false,
        aspectRatio: _videoController!.value.aspectRatio,
        errorBuilder: (context, errorMessage) {
          return Center(
            child: Text(
              'Ошибка видео: $errorMessage',
              style: const TextStyle(color: Colors.white),
            ),
          );
        },
      );
      
      if (mounted) {
        setState(() {
          _isLoadingVideo = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _errorMessage = 'Не удалось загрузить видео: $e';
          _isLoadingVideo = false;
        });
      }
    }
  }

  @override
  void dispose() {
    _videoController?.dispose();
    _chewieController?.dispose();
    super.dispose();
  }

  Map<String, String> _getAspectData() {
    // Logic to find the aspect pair containing the number
    // Pairs sum to 22. e.g. 1-21, 2-20, ... 11-11, 22 (0-0)
    int n = widget.number;
    
    // Handle 0 or 22 as 0-0
    if (n == 0 || n == 22) {
       if (aspectsRole.containsKey("0-0")) return aspectsRole["0-0"]!;
       // If stored as 22-22 or something else, handle here. Assuming "0-0".
    }

    int partner = 22 - n;
    
    // Look for key "n-partner" or "partner-n"
    String key1 = "$n-$partner";
    String key2 = "$partner-$n";
    
    if (aspectsRole.containsKey(key1)) return aspectsRole[key1]!;
    if (aspectsRole.containsKey(key2)) return aspectsRole[key2]!;

    return {};
  }

  @override
  Widget build(BuildContext context) {
    // Decide what data to show
    String title = '';
    String content = '';
    
    if (widget.isAspect) {
      final aspectData = _getAspectData();
      if (aspectData.isEmpty) {
        title = 'Аспект ${widget.number}';
        content = 'Информация об аспекте отсутствует.';
      } else {
        title = aspectData['aspect_name'] ?? 'Аспект';
        content = 
            "**Аспект ${aspectData['aspect_display'] ?? 'x → x'}: ${aspectData['aspect_name'] ?? 'Название'}**\n\n"
            "**🧠 Ключевое качество:**\n${aspectData['aspect_strength'] ?? 'Описание отсутствует'}\n\n"
            "**⚡ Вызов (опасность):**\n${aspectData['aspect_challenge'] ?? 'Описание отсутствует'}\n\n"
            "**🌍 Проявление в жизни:**\n${aspectData['aspect_inlife'] ?? 'Описание отсутствует'}\n\n"
            "**💥 Эмоциональный посыл:**\n${aspectData['aspect_emotion'] ?? 'Описание отсутствует'}\n\n"
            "**🎭 Как выглядит:**\n${aspectData['aspect_manifestation'] ?? 'Описание отсутствует'}\n\n"
            "**❓ Вопрос для рефлексии:**\n*${aspectData['aspect_question'] ?? 'Вопрос отсутствует'}*";
      }
    } else {
      final roleData = zones[widget.number] ?? {};
      title = roleData['role_name'] ?? roleData['name'] ?? 'Роль ${widget.number}';
      content = 
          "**Роль подсознания ${widget.number}: ${roleData['role_name'] ?? 'Название'}**\n\n"
          "**🧠 Ключевое качество:**\n${roleData['role_key'] ?? 'Описание отсутствует'}\n\n"
          "**💪 Сильная сторона:**\n${roleData['role_strength'] ?? 'Описание отсутствует'}\n\n"
          "**⚡ Вызов (опасность):**\n${roleData['role_challenge'] ?? 'Описание отсутствует'}\n\n"
          "**🌍 Проявление в жизни:**\n${roleData['role_inlife'] ?? 'Описание отсутствует'}\n\n"
          "**💥 Эмоциональный посыл:**\n${roleData['emotion'] ?? 'Описание отсутствует'}\n\n"
          "**🎭 Как выглядит:**\n${roleData['manifestation'] ?? 'Описание отсутствует'}\n\n"
          "**❓ Вопрос для рефлексии:**\n*${roleData['role_question'] ?? 'Вопрос отсутствует'}*";
    }

    return Scaffold(
      appBar: AppBar(
        title: Text(title),
      ),
      body: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 800),
          child: SingleChildScrollView(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                if (!widget.isAspect) ...[
                  AspectRatio(
                    aspectRatio: 16 / 9,
                    child: Container(
                      color: Colors.black,
                      child: _isLoadingVideo
                          ? const Center(child: CircularProgressIndicator())
                          : _errorMessage != null
                              ? Center(child: Text(_errorMessage!))
                              : Chewie(controller: _chewieController!),
                    ),
                  ),
                  const SizedBox(height: 16),
                ],
                Padding(
                  padding: const EdgeInsets.all(16.0),
                  child: MarkdownBody(
                    data: content,
                    styleSheet: MarkdownStyleSheet(
                      p: const TextStyle(fontSize: 16, color: Colors.white),
                      strong: const TextStyle(fontWeight: FontWeight.bold, color: Colors.blueAccent),
                      blockSpacing: 16,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
