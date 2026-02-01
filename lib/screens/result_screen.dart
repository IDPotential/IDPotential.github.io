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
import '../widgets/tarot_card_widget.dart';
import '../widgets/pythagoras_matrix_widget.dart';
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
  
  // Custom type state for switching views without saving
  late String _currentType;
  Map<String, dynamic>? _classicData;

  @override
  void initState() {
    super.initState();
    _currentType = widget.calculation.type;
    _isDecrypted = widget.calculation.decryption == 1;

    // Standard IDP Init (even if classic, we might want to switch)
    // NOTE: If stored type is classic, 'numbers' might be working nums or empty.
    // If classic, we rely on extraData.
    // If we want to support switching, we should calc IDP if current is classic, etc.
    
    if (_currentType == 'idp') {
       _analysis = CalculatorService.analyzeCalculation(
        widget.calculation.numbers,
        widget.calculation.gender,
      );
      _decryptionText = KnowledgeService.generateDetailedDescription(widget.calculation);
      _veryDetailedText = KnowledgeService.generateVeryDetailedDescription(widget.calculation);
    } else {
       _classicData = widget.calculation.extraData;
       _analysis = {};
       _decryptionText = "Классическая диагностика";
       _veryDetailedText = "";
    }
  }

  // Calculate generic on the fly if user switches
  void _switchSystem(String newSystem) {
    if (newSystem == _currentType) return;
    
    setState(() {
      _currentType = newSystem;
      if (newSystem == 'classic') {
         if (_classicData == null) {
           _classicData = CalculatorService.calculateClassic(widget.calculation.birthDate);
         }
      } else {
         // Switch to IDP
         if (widget.calculation.numbers.isEmpty || widget.calculation.type == 'classic') {
            // Need to recalc IDP stats
            final ids = CalculatorService.calculateDiagnostic(widget.calculation.birthDate, widget.calculation.name, widget.calculation.gender);
            // We need a temp calculation object to generate text
            final tempCalc = widget.calculation.copyWith(numbers: ids);
            _analysis = CalculatorService.analyzeCalculation(ids, widget.calculation.gender);
            _decryptionText = KnowledgeService.generateDetailedDescription(tempCalc);
            _veryDetailedText = KnowledgeService.generateVeryDetailedDescription(tempCalc);
         }
      }
    });
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
      
      final cleanDate = widget.calculation.birthDate.replaceAll(RegExp(r'\D'), ''); 
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
      
      const caption = 'Расчет бота https://t.me/id_potential_bot';
      final file = XFile.fromData(pngBytes, name: 'diagnostic.png', mimeType: 'image/png');
      
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
    var cleaned = text.replaceAll(RegExp(r'^#{1,6}\s*', multiLine: true), '');
    cleaned = cleaned.replaceAllMapped(RegExp(r'(\*\*|__)(.*?)\1'), (match) => match.group(2) ?? '');
    cleaned = cleaned.replaceAllMapped(RegExp(r'(\*|_)(.*?)\1'), (match) => match.group(2) ?? '');
    cleaned = cleaned.replaceAllMapped(RegExp(r'\[(.*?)\]\(.*?\)'), (match) => match.group(1) ?? '');
    return cleaned;
  }

  void _shareResult() {
    String textToShare = "";
    if (_currentType == "classic") {
       textToShare = "Классическая диагностика: ${_classicData.toString()}"; // Simplified
    } else {
       textToShare = _viewMode == ResultViewMode.text ? _decryptionText : _veryDetailedText;
    }
    
    textToShare = _stripMarkdown(textToShare);
    textToShare += '\n\nРасчет бота https://t.me/id_potential_bot';

    if (kIsWeb) {
      _showWebShareDialog(textToShare);
    } else {
      Share.share(textToShare, subject: 'Результат: ${widget.calculation.name}');
    }
  }

  void _showWebShareDialog(String text) {
     // ... keeping existing implementation ...
     showModalBottomSheet(context: context, builder: (c) => SafeArea(child: Column(mainAxisSize: MainAxisSize.min, children: [
         ListTile(leading: const Icon(Icons.copy), title: const Text('Copy'), onTap: () { Clipboard.setData(ClipboardData(text: text)); Navigator.pop(c); }),
     ])));
  }

  Future<void> _launchSocial(String urlString) async {
    try {
      final uri = Uri.parse(urlString);
      if (await canLaunchUrl(uri)) {
        await launchUrl(uri, mode: LaunchMode.externalApplication);
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
        actions: [
          // Switcher in AppBar or just below
           PopupMenuButton<String>(
            onSelected: _switchSystem,
            icon: const Icon(Icons.swap_horiz),
            tooltip: 'Сменить систему',
            itemBuilder: (BuildContext context) {
              return {'idp', 'classic'}.map((String choice) {
                return PopupMenuItem<String>(
                  value: choice,
                  child: Text(choice == 'idp' ? 'ИДП' : 'Классика'),
                );
              }).toList();
            },
          ),
        ],
      ),
      body: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 800),
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(16.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                if (_currentType == 'classic') _buildClassicView() else _buildIDPView(),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildClassicView() {
    if (_classicData == null) return const CircularProgressIndicator();
    
    final tarot = _classicData!['tarot'] as Map<String, dynamic>?;
    final pythagoras = _classicData!['pythagoras'] as Map<String, dynamic>?;
    
    // Safety check
    if (tarot == null || pythagoras == null) return const Text("Ошибка данных");

    return Column(
      children: [
        Text("Таро (Старшие Арканы)", style: Theme.of(context).textTheme.headlineSmall),
        const SizedBox(height: 16),
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceEvenly,
          children: [
            TarotCardWidget(number: tarot['personality'], label: "Личность (День)"),
            TarotCardWidget(number: tarot['soul'], label: "Душа (Месяц)"),
            TarotCardWidget(number: tarot['lifePath'], label: "Жизненный путь"),
          ],
        ),
        const SizedBox(height: 32),
        const Divider(),
        const SizedBox(height: 16),
        Text("Квадрат Пифагора", style: Theme.of(context).textTheme.headlineSmall),
        const SizedBox(height: 16),
        RepaintBoundary(
           key: _globalKey, // Move global key here if we want to snap this
           child: Container(
             color: Colors.white,
             padding: const EdgeInsets.all(8),
             child: PythagorasMatrixWidget(
                matrix: (pythagoras['matrix'] as List).map((row) => (row as List).cast<int>()).toList(),
             ),
           ),
        ),
        const SizedBox(height: 16),
        Text("Рабочие числа: ${(pythagoras['workingNumbers'] as List).join(', ')}", style: const TextStyle(fontWeight: FontWeight.bold)),
        const SizedBox(height: 16),
        // Simple Analysis List
        if (pythagoras['analysis'] != null)
           ...((pythagoras['analysis'] as Map).entries.map((e) {
               final data = e.value as Map;
               return ListTile(
                 title: Text("Цифра ${e.key} (${data['count']})"),
                 subtitle: Text("Сила качества: ${data['strength']}"),
                 dense: true,
               );
           })),
           
         const SizedBox(height: 20),
         Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
            ElevatedButton.icon(
                onPressed: _isSaving ? null : _saveImage, // Uses _globalKey which is now on Matrix
                icon: const Icon(Icons.download),
                label: const Text('Сохранить матрицу'),
            ),
            ],
        ),
      ],
    );
  }

  Widget _buildIDPView() {
    // Existing IDP Build Logic
    // Need to handle nulls if switched from Classic without full calc (but we did handle in switch)
    // Actually we need 'numbers' for DiagnosticScheme
    
    List<int> displayNumbers = widget.calculation.numbers;
    if (widget.calculation.type == 'classic') {
       // If stored as classic, 'numbers' might be wrong or empty.
       // We relied on _switchSystem to recalc IDP stats into _analysis, but DiagnosticScheme needs List<int>
       // Let's recalc numbers just in case
       displayNumbers = CalculatorService.calculateDiagnostic(widget.calculation.birthDate, widget.calculation.name, widget.calculation.gender);
    }

    return Column(
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
                        color: Colors.white.withOpacity(0.05),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: AspectRatio(
                        aspectRatio: 1,
                        child: RepaintBoundary(
                          key: _currentType == 'idp' ? _globalKey : null, // Only attach key if active
                          child: DiagnosticSchemeWidget(
                            numbers: displayNumbers,
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
    );
  }
}
