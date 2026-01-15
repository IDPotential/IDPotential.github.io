import 'dart:ui';
import 'dart:typed_data'; // for Uint8List
import 'package:share_plus/share_plus.dart';
import 'package:url_launcher/url_launcher.dart'; // import url_launcher
import 'package:flutter/foundation.dart'; // for kIsWeb
import 'package:flutter/services.dart'; // for Clipboard
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_markdown/flutter_markdown.dart';
import '../models/calculation.dart';
import '../services/calculator_service.dart';
import '../services/knowledge_service.dart';
import '../widgets/diagnostic_scheme.dart';
import '../utils/file_saver.dart';
import '../services/firestore_service.dart'; // import
import '../widgets/role_info_dialog.dart'; // Import Custom Dialog
import 'role_detail_screen.dart';

class ResultScreen extends StatefulWidget {
  final Calculation calculation;
  
  const ResultScreen({super.key, required this.calculation});
  
  @override
  State<ResultScreen> createState() => _ResultScreenState();
}

enum ResultViewMode { text, detailed }

class _ResultScreenState extends State<ResultScreen> {
  late Map<String, dynamic> _analysis;
  late String _decryptionText;
  late String _veryDetailedText;
  ResultViewMode _viewMode = ResultViewMode.text;
  bool _isDecrypted = false;
  
  @override
  void initState() {
    super.initState();
    _isDecrypted = widget.calculation.decryption == 1;
    _analysis = CalculatorService.analyzeCalculation(
      widget.calculation.numbers,
      widget.calculation.gender,
    );
    _decryptionText = KnowledgeService.generateDetailedDescription(widget.calculation);
    _veryDetailedText = KnowledgeService.generateVeryDetailedDescription(widget.calculation);
  }

  Future<void> _handleDetailedView() async {
    if (_isDecrypted) {
       setState(() {
         _viewMode = ResultViewMode.detailed;
       });
       return;
    }

    // Ask for payment
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Открыть подробное описание?'),
        content: const Text('Стоимость: 20 кредитов.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Отмена'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Открыть (-20 кр.)'),
          ),
        ],
      ),
    );

    if (confirmed == true) {
      if (!mounted) return;
      setState(() => _isSaving = true);
      
      try {
        final success = await FirestoreService().consumeCredit(20);
        if (!success) {
           throw Exception("Недостаточно кредитов!");
        }

        if (widget.calculation.firebaseId != null) {
          await FirestoreService().setCalculationPaid(widget.calculation.firebaseId!);
        }

        setState(() {
          _isDecrypted = true;
          _viewMode = ResultViewMode.detailed;
        });

        if (mounted) {
           ScaffoldMessenger.of(context).showSnackBar(
             const SnackBar(content: Text('Доступ открыт!'), backgroundColor: Colors.green),
           );
        }

      } catch (e) {
        if (mounted) {
           ScaffoldMessenger.of(context).showSnackBar(
             SnackBar(content: Text('Ошибка: $e'), backgroundColor: Colors.red),
           );
        }
      } finally {
        if (mounted) setState(() => _isSaving = false);
      }
    }
  }
  
  final GlobalKey _globalKey = GlobalKey();
  bool _isSaving = false;

  Future<Uint8List?> _capturePng() async {
    // Slight delay to ensure UI is ready (if needed)
    await Future.delayed(const Duration(milliseconds: 100));
    
    final boundary = _globalKey.currentContext?.findRenderObject() as RenderRepaintBoundary?;
    if (boundary == null) return null;
    
    final image = await boundary.toImage(pixelRatio: 3.0);
    final byteData = await image.toByteData(format: ImageByteFormat.png);
    
    return byteData?.buffer.asUint8List();
  }

  Future<void> _saveImage() async {
    try {
      setState(() => _isSaving = true);
      
      final pngBytes = await _capturePng();
      if (pngBytes == null) throw Exception('Не удалось захватить изображение');
      
      final cleanDate = widget.calculation.birthDate.replaceAll(RegExp(r'\D'), ''); // Remove non-digits (12.05.1990 -> 12051990)
      final fileName = 'diagnostic_${widget.calculation.name}_$cleanDate.png';
      
      final message = await FileSaver.saveImage(pngBytes, fileName);
      
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(message), backgroundColor: Colors.green),
        );
      }
    } catch (e) {
      debugPrint('Save error: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Ошибка: $e'), backgroundColor: Colors.red),
        );
      }
    } finally {
      if (mounted) setState(() => _isSaving = false);
    }
  }

  Future<void> _shareImage() async {
    try {
      setState(() => _isSaving = true);
      
      final pngBytes = await _capturePng();
      if (pngBytes == null) throw Exception('Не удалось захватить изображение');
      
      // Capturing caption
      const caption = 'Расчет сделан с помощью бота Индивидуальная диагностика потенциала https://t.me/id_potential_bot';
      
      final file = XFile.fromData(
        pngBytes, 
        name: 'diagnostic.png',
        mimeType: 'image/png',
      );
      
      await Share.shareXFiles([file], text: caption, subject: 'Диагностика ${widget.calculation.name}');
      
    } catch (e) {
       debugPrint('Share image error: $e');
       if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Ошибка отправки: $e'), backgroundColor: Colors.red),
        );
      }
    } finally {
      if (mounted) setState(() => _isSaving = false);
    }
  }

  String _stripMarkdown(String text) {
    // 1. Remove Headers (## Title)
    var cleaned = text.replaceAll(RegExp(r'^#{1,6}\s*', multiLine: true), '');
    // 2. Remove Bold/Italic (**text**, *text*, __text__, _text_)
    cleaned = cleaned.replaceAllMapped(RegExp(r'(\*\*|__)(.*?)\1'), (match) => match.group(2) ?? '');
    cleaned = cleaned.replaceAllMapped(RegExp(r'(\*|_)(.*?)\1'), (match) => match.group(2) ?? '');
    // 3. Remove Links ([text](url)) -> text
    cleaned = cleaned.replaceAllMapped(RegExp(r'\[(.*?)\]\(.*?\)'), (match) => match.group(1) ?? '');
    // 4. Remove unordered list markers if needed, or keep them as dashes
    // cleaned = cleaned.replaceAll(RegExp(r'^\s*[\-\*]\s+', multiLine: true), ''); 
    // We kept list markers as they are useful for structure.
    
    return cleaned;
  }

  void _shareResult() {
    String textToShare = _viewMode == ResultViewMode.text ? _decryptionText : _veryDetailedText;
    
    // Clean Markdown
    textToShare = _stripMarkdown(textToShare);
    
    // Add Footer
    textToShare += '\n\nРасчет сделан с помощью бота Индивидуальная диагностика потенциала https://t.me/id_potential_bot';

    if (kIsWeb) {
      _showWebShareDialog(textToShare);
    } else {
      Share.share(textToShare, subject: 'Результат диагностики: ${widget.calculation.name}');
    }
  }

  void _showWebShareDialog(String text) {
    showModalBottomSheet(
      context: context,
      builder: (BuildContext context) {
        return SafeArea(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              ListTile(
                leading: const Icon(Icons.copy),
                title: const Text('Скопировать текст'),
                onTap: () {
                  // Don't wait, just do it. 
                  Clipboard.setData(ClipboardData(text: text)).then((_) {
                     if (mounted) {
                        Navigator.pop(context);
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(content: Text('Текст скопирован!'), backgroundColor: Colors.green),
                        );
                     }
                  }).catchError((e) {
                     if (mounted) {
                        Navigator.pop(context);
                        showDialog(
                           context: context,
                           builder: (context) => AlertDialog(
                              title: const Text('Скопируйте текст вручную'),
                              content: SizedBox(
                                 width: double.maxFinite,
                                 child: SingleChildScrollView(
                                    child: SelectableText(text),
                                 ),
                              ),
                              actions: [
                                 TextButton(
                                    onPressed: () => Navigator.pop(context),
                                    child: const Text('Закрыть'),
                                 ),
                              ],
                           ),
                        );
                     }
                  });
                },
              ),
              ListTile(
                leading: const Icon(Icons.send, color: Colors.blue),
                title: const Text('Telegram'),
                onTap: () {
                  Navigator.pop(context);
                  // For Telegram Web Share: https://t.me/share/url?url={url}&text={text}
                  // If we only have text, we can try putting it all in text, or use a dummy URL.
                  // BETTER: Use just text param if no URL.
                  // BUT: t.me/share/url REQUIRES url param usually. 
                  // Let's use the app URL as the shared URL and the result in text.
                  _launchSocial('https://t.me/share/url?url=${Uri.encodeComponent("https://idpotential.github.io")}&text=${Uri.encodeComponent(text)}');
                },
              ),
              ListTile(
                leading: const Icon(Icons.message, color: Colors.green),
                title: const Text('WhatsApp'),
                onTap: () {
                   Navigator.pop(context);
                   _launchSocial('https://wa.me/?text=${Uri.encodeComponent(text)}');
                },
              ),
              ListTile(
                leading: const Icon(Icons.share),
                title: const Text('Другое (Email / Apps)'),
                onTap: () {
                  Navigator.pop(context);
                  Share.share(text, subject: 'Результат диагностики: ${widget.calculation.name}');
                },
              ),
            ],
          ),
        );
      },
    );
  }

  Future<void> _launchSocial(String urlString) async {
    try {
      final uri = Uri.parse(urlString);
      if (await canLaunchUrl(uri)) {
        await launchUrl(uri, mode: LaunchMode.externalApplication);
      } else {
        // Fallback or error (likely text too long)
        if (mounted) {
           ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Не удалось открыть приложение (возможно текст слишком длинный)'), backgroundColor: Colors.orange),
          );
        }
      }
    } catch (e) {
      debugPrint('Launch error: $e');
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('Результат для ${widget.calculation.name}'),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Center(
              child: Container(
                constraints: const BoxConstraints(maxWidth: 500),
                child: Card(
                  elevation: 4,
                  child: Padding(
                    padding: const EdgeInsets.all(16.0),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.center,
                      children: [
                        Text(
                          'Схема диагностики',
                          style: Theme.of(context).textTheme.titleLarge,
                        ),
                        const SizedBox(height: 16),
                        Container(
                          constraints: const BoxConstraints(maxHeight: 400, maxWidth: 400),
                          decoration: BoxDecoration(
                            color: Colors.white.withOpacity(0.05), // Subtle background
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: AspectRatio(
                            aspectRatio: 1,
                            child: RepaintBoundary(
                              key: _globalKey,
                              child: DiagnosticSchemeWidget(
                                numbers: widget.calculation.numbers,
                                gender: widget.calculation.gender,
                                name: widget.calculation.name,
                                birthDate: widget.calculation.birthDate,
                              ),
                            ),
                          ),
                        ),
                        const SizedBox(height: 15),
                        Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            ElevatedButton.icon(
                              onPressed: _isSaving ? null : _saveImage,
                              icon: const Icon(Icons.download),
                              label: const Text('Сохранить'),
                            ),
                            const SizedBox(width: 12),
                            ElevatedButton.icon(
                              onPressed: _isSaving ? null : _shareImage,
                              icon: _isSaving 
                                  ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2)) 
                                  : const Icon(Icons.share),
                              label: const Text('Поделиться'),
                              style: ElevatedButton.styleFrom(
                                backgroundColor: Colors.blueAccent,
                                foregroundColor: Colors.white,
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
            
            const SizedBox(height: 20),
            
            // Кнопки переключения режима просмотра
            Row(
              children: [
                Expanded(
                  child: ElevatedButton(
                    onPressed: () {
                      setState(() {
                        _viewMode = ResultViewMode.text;
                      });
                    },
                    style: ElevatedButton.styleFrom(
                      backgroundColor: _viewMode == ResultViewMode.text ? Theme.of(context).primaryColor : null,
                      foregroundColor: _viewMode == ResultViewMode.text ? Colors.white : null,
                    ),
                    child: const Text('Текстовый вариант'),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: ElevatedButton(
                    onPressed: () {
                         if (_viewMode == ResultViewMode.detailed) return;
                         _handleDetailedView();
                    },
                    style: ElevatedButton.styleFrom(
                      backgroundColor: _viewMode == ResultViewMode.detailed ? Theme.of(context).primaryColor : null,
                      foregroundColor: _viewMode == ResultViewMode.detailed ? Colors.white : null,
                    ),
                    child: Row(
                       mainAxisAlignment: MainAxisAlignment.center,
                       children: [
                         const Text('Подробнее'),
                         if (!_isDecrypted) ...[
                            const SizedBox(width: 4),
                            const Icon(Icons.lock, size: 14),
                         ]
                       ],
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),

            // Контент в зависимости от выбора
            Card(
              child: Padding(
                padding: const EdgeInsets.all(16.0),
                  child: MarkdownBody(
                    data: _viewMode == ResultViewMode.text 
                        ? _decryptionText 
                        : _veryDetailedText.replaceAllMapped(
                            RegExp(r'\[(.*?)\]\(.*?\)'), 
                            (match) => match.group(1) ?? ''
                          ),
                    selectable: true,
                    styleSheet: MarkdownStyleSheet(
                      h1: Theme.of(context).textTheme.headlineMedium,
                      h2: Theme.of(context).textTheme.headlineSmall,
                      p: Theme.of(context).textTheme.bodyLarge,
                      listBullet: Theme.of(context).textTheme.bodyLarge,
                      a: const TextStyle(color: Colors.blueAccent, decoration: TextDecoration.none),
                    ),
                    onTapLink: (text, href, title) {
                      if (href != null) {
                        if (href.startsWith('role:')) {
                          final roleNum = int.tryParse(href.substring(5));
                          if (roleNum != null) {
                            showDialog(
                              context: context,
                              builder: (context) => RoleInfoDialog(roleNumber: roleNum),
                            );
                          }
                        } else if (href.startsWith('aspect:')) {
                          // Format: aspect:8-14
                          final parts = href.substring(7).split('-');
                          if (parts.isNotEmpty) {
                            final aspectNum = int.tryParse(parts[0]);
                             if (aspectNum != null) {
                              Navigator.push(
                                context,
                                MaterialPageRoute(
                                  builder: (context) => RoleDetailScreen(
                                    number: aspectNum,
                                    isAspect: true,
                                  ),
                                ),
                              );
                            }
                          }
                        }
                      }
                    },
                  ),
              ),
            ),
            
            const SizedBox(height: 16),
            Center(
              child: ElevatedButton.icon(
                onPressed: _shareResult,
                icon: const Icon(Icons.share),
                label: const Text('Поделиться'),
                style: ElevatedButton.styleFrom(
                  padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 12),
                ),
              ),
            ),
            
            const SizedBox(height: 20),
             Row(
              children: [
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: () {
                      Navigator.pop(context);
                    },
                    icon: const Icon(Icons.arrow_back),
                    label: const Text('Назад'),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
