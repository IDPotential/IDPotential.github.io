import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import '../utils/zoom_js.dart' as zoom_js;
import '../utils/registry.dart'; 
import '../services/calculator_service.dart';
import '../services/firestore_service.dart';
import '../services/knowledge_service.dart';
import '../services/config_service.dart';
import '../models/calculation.dart';
import 'package:intl/intl.dart';
import 'dart:math';
import 'dart:async';
import 'package:record/record.dart';
import 'package:record/record.dart';
import 'package:path_provider/path_provider.dart';
import 'package:universal_io/io.dart';
import 'package:universal_html/html.dart' as html;
import 'package:flutter/foundation.dart' show kIsWeb;
import '../services/database_service.dart';
// import '../utils/situations_data.dart'; // Removed after migration


class ActiveGameScreen extends StatefulWidget {
  final String gameId;
  final Calculation? gameProfile;
  final bool isHost;
  final String? initialRoomName;

  const ActiveGameScreen({
    super.key, 
    required this.gameId, 
    this.gameProfile, 
    this.isHost = false,
    this.initialRoomName
  });

  @override
  State<ActiveGameScreen> createState() => _ActiveGameScreenState();
}

class _ActiveGameScreenState extends State<ActiveGameScreen> {
  final FirestoreService _firestoreService = FirestoreService();
  
  // Game State
  late String _targetGameId;
  String? _targetGameTitle;
  String? _gameStage = 'selection';
  String? _gameStatus = 'active';
  Map<String, dynamic> _gameStats = {};
  String? _zoomId;
  String? _zoomPassword;

  // Player State
  String? _participantStatus;
  int? _selectedRole;
  int? _playerNumber;
  
  bool _isVideoActive = false; 
  bool _isGridMode = false;
  String _roomName = '';
  final GlobalKey _zoomViewKey = GlobalKey();
  
  // Situation State
  Map<String, dynamic> _situation = {};
  List<Map<String, dynamic>> _availableSituations = [];
  bool _situationsLoaded = false;

  // Answer Input
  final TextEditingController _answerController = TextEditingController();
  Timer? _answerDebouncer;

  // Offline / Recording State
  final AudioRecorder _audioRecorder = AudioRecorder();
  bool _isOfflineMode = false;
  bool _isRecording = false;
  int _recordDuration = 0;
  Timer? _recordTimer;

  @override
  void initState() {
    super.initState();
    _targetGameId = widget.gameId;
    _roomName = widget.initialRoomName ?? '';
    _registerZoomViewFactory();
    _initGameListeners();
  }

  @override
  void dispose() {
      if (kIsWeb) {
          try {
             zoom_js.leaveZoom();
          } catch(e) {
             debugPrint("Zoom cleanup error: $e");
          }
      }
      super.dispose();
  }

  void _initGameListeners() {
      // Listen to Game Doc
      _firestoreService.getGameStream(_targetGameId).listen((doc) {
         if (!doc.exists) return;
         final data = doc.data();
         if (data != null) {
            if (mounted) setState(() {
              _gameStage = data['stage'] ?? 'selection';
              _gameStatus = data['status'] ?? 'active';
              _gameStats = data['stats'] ?? {};
              _zoomId = data['zoomId'];
              _zoomPassword = data['zoomPassword'];
              _targetGameTitle = data['title'];
              _situation = data['situation'] ?? {};
              _isOfflineMode = data['isOffline'] ?? false;
            });
            
            // Allow Host/Controller to fetch situations once
            if (!_situationsLoaded && (widget.isHost || _situation['controllerId'] == FirebaseAuth.instance.currentUser?.uid)) {
                _fetchSituations(data['situationPackId'], data['situationCategories']);
            }
         }
      });

      // Listen to My Status
      final user = FirebaseAuth.instance.currentUser;
      if (user != null) {
         _firestoreService.getGameParticipantsStream(_targetGameId).listen((event) {
            final me = event.docs.where((d) => d.id == user.uid).firstOrNull;
            
            // Check if I was kicked (existed before, now gone, and game is not archived)
            if (me == null && _participantStatus != null && _gameStatus != 'archived') {
               if (mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Вы были удалены из игры", style: TextStyle(color: Colors.red))));
                  Navigator.of(context).pop(); // Go back to home
               }
               return;
            }

            if (mounted) {
               setState(() {
                  _participantStatus = me?.data()['status'];
                  _playerNumber = me?.data()['playerNumber'];
                   _selectedRole = me?.data()['selectedRole'];
               });
            }
         });
      }
  }

  void _registerZoomViewFactory() {
    if (kIsWeb) {
      registerZoomViewFactory('zoom-container');
    }
  }

  void _connectToZoom() {
      if (_zoomId == null || _zoomId!.isEmpty) return;
      
      setState(() => _isVideoActive = true);
      
      final user = FirebaseAuth.instance.currentUser;
      final userName = user?.displayName ?? widget.gameProfile?.name.split(' ')[0] ?? "Player";

      Future.delayed(const Duration(milliseconds: 500), () {
          // Customized View Settings based on Role
          Map<String, dynamic> customize = {
             'video': {
                'isResizable': true,
                'viewSizes': {
                    'default': {'width': 960, 'height': 540}
                }
             }
          };

          zoom_js.initZoom(
              _zoomId!, 
              _zoomPassword ?? "", 
              userName,
              ConfigService().zoomKey,
              ConfigService().zoomSecret,
              customize
          );
      });
  }

  void _goHome() {
     // Using pop to close the active game overlay instead of navigating to root
     Navigator.pop(context);
  }

  @override
  Widget build(BuildContext context) {
      return Scaffold(
        body: Container(
           decoration: const BoxDecoration(
             gradient: LinearGradient(colors: [Color(0xFF0F172A), Color(0xFF1E293B)])
           ),
           child: SafeArea(
             child: _gameStatus == 'archived' 
               ? _buildGameArchivedScreen()
               : LayoutBuilder(
                   builder: (context, constraints) {
                      bool isLandscape = constraints.maxWidth > constraints.maxHeight;
                      
                      if (isLandscape) {
                        return Row(
                           crossAxisAlignment: CrossAxisAlignment.stretch,
                           children: [
                              // Left: Video (Larger)
                              Expanded(
                                flex: 6,
                                child: Container(
                                  color: Colors.black87,
                                  child: Stack(
                                    children: [
                                      _isVideoActive 
                                        ? _buildZoomPanel() 
                                        : (_isOfflineMode ? _buildOfflineLayout() : _buildVideoPlaceholder()),
                                      ]
                                    )
                                ),
                              ),
                              const VerticalDivider(width: 1, thickness: 1, color: Colors.grey),
                              // Right: Dashboard
                              Expanded(
                                flex: 4,
                                child: widget.isHost && _gameStatus != 'archived'
                                  ? _buildHostDashboard()
                                  : _buildPlayerDashboard(),
                              ),
                           ],
                        );
                      } else {
                        return Column(
                           children: [
                             // Top Section: Video
                             Expanded(
                               flex: 5,
                               child: Container(
                                 color: Colors.black87,
                                 child: Stack(
                                   children: [
                                     _isVideoActive 
                                       ? _buildZoomPanel() 
                                       : (_isOfflineMode ? _buildOfflineLayout() : _buildVideoPlaceholder()),
                                   ]
                                 )
                               ),
                             ),
                             const Divider(height: 1, thickness: 1, color: Colors.grey),
                             // Bottom Section: Dashboard
                             Expanded(
                               flex: 5,
                               child: widget.isHost && _gameStatus != 'archived'
                                 ? _buildHostDashboard()
                                 : _buildPlayerDashboard(),
                             ),
                           ],
                         );
                      }
                   }
               ),
           )
        )
      );
  }

  // --- HOST DASHBOARD ---

  Widget _buildHostDashboard() {
     return Column(
        children: [
           Container(
             color: Colors.black45,
             padding: const EdgeInsets.all(8),
             child: Row(
               children: [
                 IconButton(
                    icon: const Icon(Icons.home, color: Colors.white70, size: 20),
                    tooltip: 'На главный экран',
                    onPressed: _goHome,
                 ),
                 const Spacer(),
                  if (_gameStatus == 'finished')
                     ElevatedButton(
                        style: ElevatedButton.styleFrom(backgroundColor: Colors.purple, minimumSize: const Size(0, 30)),
                        onPressed: () => _showEndSessionDialog(),
                        child: const Text("Завершить игру", style: TextStyle(fontSize: 10, color: Colors.white, fontWeight: FontWeight.bold))
                     )
                  else ...[
                     if (_gameStage == 'voting')
                        IconButton(
                           icon: const Icon(Icons.close, color: Colors.orange),
                           tooltip: 'Завершить кон',
                           onPressed: () => _showEndRoundDialog(),
                        ),
                     const SizedBox(width: 8),
                     ElevatedButton(
                        style: ElevatedButton.styleFrom(backgroundColor: Colors.redAccent, minimumSize: const Size(0, 30)),
                        onPressed: () => _showEndGameDialog(),
                        child: const Text("Финиш", style: TextStyle(fontSize: 10, color: Colors.white))
                     ),
                  ],
                  const SizedBox(width: 8),
                  // New Search Button for Host to find specific situation
                  // New Search Button
                  IconButton(
                      icon: const Icon(Icons.search, color: Colors.white70),
                      tooltip: 'Поиск ситуации',
                      onPressed: _showSituationSearchDialog,
                  ),
                  const SizedBox(width: 8),
                  ToggleButtons(
                    isSelected: [_gameStage == 'selection', _gameStage == 'voting'],
                    onPressed: (index) async {
                       final newStage = index == 0 ? 'selection' : 'voting';
                       // Optimistic update
                       setState(() => _gameStage = newStage);
                       await _firestoreService.updateGameStage(_targetGameId, newStage);
                    },
                    color: Colors.white60,
                    selectedColor: Colors.white,
                    fillColor: Colors.blueAccent,
                    borderRadius: BorderRadius.circular(8),
                    children: const [
                       Padding(padding: EdgeInsets.symmetric(horizontal: 12), child: Text("Выбор")),
                       Padding(padding: EdgeInsets.symmetric(horizontal: 12), child: Text("Голос")),
                    ],
                 )
               ],
             ),
           ),
            Expanded(
              child: _gameStatus == 'finished' 
                ? _buildFinalResults() 
                : _gameStage == 'voting' 
                    ? _buildVotingBoard()
                    : _buildHostSelectionBoard(), 
            )
        ],
     );
  }

  // --- PLAYER DASHBOARD ---

  Widget _buildPlayerDashboard() {
    return Container(
      color: Colors.transparent, 
      child: Column(
        children: [
           if (_gameStatus == 'finished')
              Expanded(child: _buildFinalResults())
           else if (_gameStage == 'voting')
              Expanded(
                child: Column(
                  children: [
                      Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 8.0, vertical: 4.0),
                        child: Row(
                           children: [
                              IconButton(
                                  icon: const Icon(Icons.home, color: Colors.white70),
                                  onPressed: _goHome,
                              ),
                              const Expanded(
                                 child: Center(
                                    child: Text("Голосование", style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16, color: Colors.white))
                                 )
                              ),
                              const SizedBox(width: 48), 
                           ],
                        ),
                      ),
                      Expanded(child: _buildVotingBoard()),
                  ],
                )
              )
           else ...[
              // Custom Header per request
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 8.0, vertical: 4.0),
                child: Row(
                   children: [
                      // Left: Home Icon
                      IconButton(
                          icon: const Icon(Icons.home, color: Colors.white70),
                          onPressed: _goHome,
                      ),
                      
                      // Center: "My Roles"
                      const Expanded(
                         child: Center(
                            child: Text("Мои Роли", style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16, color: Colors.white))
                         )
                      ),
                      
                      // Right: Selected Role + Cancel
                      if (_selectedRole != null) ...[
                          Container(
                             padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                             decoration: BoxDecoration(color: Colors.orangeAccent.withOpacity(0.2), borderRadius: BorderRadius.circular(12)),
                             child: Row(
                               mainAxisSize: MainAxisSize.min,
                               children: [
                                  Text("Роль $_selectedRole", style: const TextStyle(color: Colors.orangeAccent, fontSize: 12)),
                                  const SizedBox(width: 4),
                                  GestureDetector(
                                    onTap: () {
                                      setState(() => _selectedRole = null);
                                      _firestoreService.updateParticipantRole(_targetGameId, null);
                                    },
                                    child: const Icon(Icons.close, color: Colors.redAccent, size: 16),
                                  )
                               ]
                             )
                          )
                      ] else 
                          // Spacer to balance the row if no role selected, or empty width
                          const SizedBox(width: 48), // Approx width of Home button
                   ],
                  ),
               ),
               // Answer Input removed by request
               // Padding(
               //   padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 8.0),
               //   child: TextField(
               //      controller: _answerController,
               //      onChanged: _onAnswerChanged,
               //      style: const TextStyle(color: Colors.white),
               //      decoration: InputDecoration(
               //         labelText: "Ваш ответ на ситуацию",
               //         labelStyle: const TextStyle(color: Colors.white70),
               //         hintText: "Введите ваш ответ здесь...",
               //         hintStyle: const TextStyle(color: Colors.white30),
               //         filled: true,
               //         fillColor: Colors.white10,
               //         border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none),
               //         contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
               //      ),
               //      maxLines: 2,
               //      minLines: 1,
               //   ),
               // ),
               Expanded(child: _buildRolesGrid()),
            ]
        ],
      ),
    );
  }

  void _onAnswerChanged(String value) {
    // Answer tracking logic
  }

  // --- OFFLINE RECORDER ---

  // --- OFFLINE LAYOUT ---
  
  Widget _buildOfflineLayout() {
      // 2/3 Situation (if visible/chosen) or Placeholder, 1/3 Recorder
      // Note: Situation is usually an overlay in Zoom panel, here we put it explicitly.
      // We reusing _buildZoomPanel's logic for Situation overlay but in a dedicated widget.
      
      final bool isSituationVisible = _situation['isVisible'] == true || widget.isHost;
      
      return Column(
        children: [
            // Top: Situation Display (2/3)
            Expanded(
                flex: 2, 
                child: Container(
                    decoration: const BoxDecoration(
                       image: DecorationImage(
                          image: AssetImage('assets/images/fon.png'),
                          fit: BoxFit.cover,
                       )
                    ),
                    child: Stack(
                        children: [
                            // Logo Top Left
                             Positioned(
                                top: 16, left: 16,
                                child: Image.asset('assets/images/logo.png', width: 60, fit: BoxFit.contain)
                             ),

                            if (_situation['text'] != null && _situation['text'].toString().isNotEmpty)
                                Center(
                                    child: Padding(
                                        padding: const EdgeInsets.symmetric(horizontal: 48), // Match ZoomPanel padding
                                        child: Text(
                                            _situation['text'] ?? "",
                                            textAlign: TextAlign.center,
                                            style: const TextStyle(
                                                fontFamily: 'DINPro',
                                                fontWeight: FontWeight.w900,
                                                fontSize: 24,
                                                color: Colors.white,
                                                shadows: [Shadow(color: Colors.black, blurRadius: 4, offset: Offset(1,1))]
                                            ),
                                        ),
                                    )
                                )
                            else 
                                const Center(
                                   child: Text("Ситуация не выбрана", style: TextStyle(color: Colors.white24))
                                ),
                                
                             // Link Bottom Left
                             Positioned(
                                bottom: 16, left: 16,
                                child: InkWell(
                                   onTap: () => launchUrl(Uri.parse("https://t.me/id_territory")),
                                   child: const Text(
                                      "https://t.me/id_territory",
                                      style: TextStyle(
                                         color: Colors.white70, 
                                         fontSize: 12, 
                                         decoration: TextDecoration.underline
                                      ),
                                   ),
                                )
                             ),

                             if (widget.isHost) _buildOfflineControlsOverlay(),
                        ],
                    ),
                )
            ),
            
            const Divider(height: 1, color: Colors.white12),
            
            // Bottom: Dictaphone (1/3)
            Expanded(
                flex: 1, 
                child: _buildOfflineRecorder(simple: true)
            )
        ],
      );
  }

  Widget _buildOfflineControlsOverlay() {
      return Positioned(
          bottom: 10, right: 10,
          child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                   // Choose Situation
                   FloatingActionButton(
                      heroTag: 'off_sit_search',
                      mini: true,
                      backgroundColor: Colors.blueAccent,
                      child: const Icon(Icons.search),
                      onPressed: _showSituationSearchDialog
                   ),
                   const SizedBox(width: 8),
                   // Toggle Visibility
                   FloatingActionButton(
                      heroTag: 'off_sit_vis',
                      mini: true,
                      backgroundColor: (_situation['isVisible'] == true) ? Colors.orange : Colors.grey,
                      child: Icon((_situation['isVisible'] == true) ? Icons.visibility : Icons.visibility_off),
                      onPressed: () {
                         final newVal = !(_situation['isVisible'] == true);
                         _firestoreService.setSituationVisible(_targetGameId, newVal);
                      }
                   )
              ],
          )
      );
  }

  Widget _buildOfflineRecorder({bool simple = false}) {
      final String durationStr = _formatDuration(_recordDuration);
      
      return Container(
          color: const Color(0xFF1E293B),
          padding: const EdgeInsets.all(8),
          child: Center(
              child: simple 
               ? Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                      // Status & Timer
                      Column(
                          mainAxisSize: MainAxisSize.min,
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                              Text(
                                 _isRecording ? "ЗАПИСЬ" : "",
                                 style: const TextStyle(color: Colors.redAccent, fontWeight: FontWeight.bold, fontSize: 10)
                              ),
                              Text(durationStr, style: const TextStyle(color: Colors.white, fontSize: 32, fontFamily: 'monospace', fontWeight: FontWeight.bold)),
                          ],
                      ),
                      const SizedBox(width: 24),
                      // Controls
                      if (!_isRecording)
                         ElevatedButton(
                             style: ElevatedButton.styleFrom(
                                shape: const CircleBorder(), 
                                padding: const EdgeInsets.all(16),
                                backgroundColor: Colors.red
                             ),
                             onPressed: _startRecording,
                             child: const Icon(Icons.mic, size: 24)
                         )
                      else 
                         ElevatedButton(
                             style: ElevatedButton.styleFrom(
                                shape: const CircleBorder(), 
                                padding: const EdgeInsets.all(16),
                                backgroundColor: Colors.grey[800]
                             ),
                             onPressed: _stopAndSaveRecording,
                             child: const Icon(Icons.stop, size: 24)
                         )
                  ],
               )
               : Column(
             mainAxisAlignment: MainAxisAlignment.center,
             children: [
                 const Icon(Icons.mic, size: 60, color: Colors.white70),
                 const SizedBox(height: 16),
                 Text(
                     _isRecording ? "Идет запись..." : "Запись остановлена",
                     style: TextStyle(color: _isRecording ? Colors.redAccent : Colors.white54, fontSize: 16)
                 ),
                 const SizedBox(height: 8),
                 Text(
                     durationStr,
                     style: const TextStyle(fontSize: 48, fontWeight: FontWeight.bold, color: Colors.white, fontFamily: 'monospace'),
                 ),
                 const SizedBox(height: 32),
                 if (!_isRecording)
                     ElevatedButton.icon(
                         style: ElevatedButton.styleFrom(
                             backgroundColor: Colors.red,
                             padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 16),
                         ),
                         icon: const Icon(Icons.fiber_manual_record, size: 30),
                         label: const Text("Начать запись", style: TextStyle(fontSize: 18)),
                         onPressed: _startRecording,
                     )
                 else 
                     ElevatedButton.icon(
                         style: ElevatedButton.styleFrom(
                             backgroundColor: Colors.grey[800],
                             padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 16),
                         ),
                         icon: const Icon(Icons.stop, size: 30),
                         label: const Text("Стоп", style: TextStyle(fontSize: 18)),
                         onPressed: _stopAndSaveRecording,
                     ),
                 
                 const SizedBox(height: 20),
                 // Info about storage
                 Padding(
                     padding: const EdgeInsets.symmetric(horizontal: 32),
                     child: Text(
                        kIsWeb 
                          ? "Записи скачиваются автоматически после завершения кона."
                          : "Записи сохраняются локально в Документы/GameRecordings/${_targetGameId}.\nПри завершении кона запись сохраняется и начинается новая автоматически.",
                        textAlign: TextAlign.center,
                        style: const TextStyle(color: Colors.white24, fontSize: 12),
                     )
                 ),
                 
                 if (!widget.isHost) ...[
                     const SizedBox(height: 20),
                     TextButton(
                         onPressed: () => Navigator.pop(context),
                         child: const Text("Выйти", style: TextStyle(color: Colors.white38)),
                     )
                 ]
             ],
          )
      ));
  }

  String _formatDuration(int totalSeconds) {
      final int m = totalSeconds ~/ 60;
      final int s = totalSeconds % 60;
      return "${m.toString().padLeft(2, '0')}:${s.toString().padLeft(2, '0')}";
  }

  Future<void> _startRecording() async {
    try {
        if (await _audioRecorder.hasPermission()) {
             final round = (_gameStats['roundCount'] as int? ?? 0) + 1;
             final timestamp = DateFormat('yyyyMMdd_HHmmss').format(DateTime.now());
             
             String path = '';
             
             if (kIsWeb) {
                // Web: Path is ignored or used as memory identifier
                // We define stream/encoder in config if needed, but default is fine
                await _audioRecorder.start(const RecordConfig(), path: ''); 
             } else {
                 final directory = await getApplicationDocumentsDirectory();
                 final gameDir = Directory('${directory.path}/GameRecordings/${_targetGameId}');
                 if (!await gameDir.exists()) {
                     await gameDir.create(recursive: true);
                 }
                 path = '${gameDir.path}/Round${round}_$timestamp.m4a';
                 await _audioRecorder.start(const RecordConfig(), path: path);
             }
             
             if (mounted) {
                 setState(() {
                     _isRecording = true;
                     _recordDuration = 0;
                 });
             }
             
             _recordTimer?.cancel();
             _recordTimer = Timer.periodic(const Duration(seconds: 1), (timer) {
                 if (mounted) setState(() => _recordDuration++);
             });
        }
    } catch (e) {
        debugPrint("Error starting recording: $e");
        if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text("Ошибка записи: $e")));
    }
  }

  Future<void> _stopAndSaveRecording() async {
    if (!_isRecording) return;
    try {
        final path = await _audioRecorder.stop();
        _recordTimer?.cancel();
        if (mounted) {
            setState(() {
                _isRecording = false;
            });
            if (path != null) {
                ScaffoldMessenger.of(context).showSnackBar(SnackBar(
                    content: Text("Запись сохранена: ...${path.substring(max(0, path.length - 30))}"),
                    duration: const Duration(seconds: 2),
                    backgroundColor: Colors.green,
                ));
            }
        }
        debugPrint("Recording saved to $path");

        if (kIsWeb && path != null) {
            // Web: 'path' is actually a Blob URL or we need to convert logic depending on package version
            // For record 5.x+, stop() returns the blob URL on web.
            
            final round = (_gameStats['roundCount'] as int? ?? 0);
            final timestamp = DateFormat('yyyyMMdd_HHmmss').format(DateTime.now());
            final filename = 'Game_${_targetGameTitle}_Round${round}_$timestamp.m4a';

            final anchor = html.AnchorElement(href: path);
            anchor.download = filename;
            anchor.click();
            anchor.remove();
        }

    } catch (e) {
        debugPrint("Error stopping recording: $e");
    }
  }

  // --- COMMON WIDGETS (Video, Grid, Voting) ---

  Widget _buildVideoPlaceholder() {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(Icons.video_call, size: 50, color: Colors.white54),
          const SizedBox(height: 10),
          Text("Игра: ${_targetGameTitle ?? _roomName}", style: const TextStyle(color: Colors.white70)),
          const SizedBox(height: 20),
          ElevatedButton.icon(
            icon: const Icon(Icons.videocam),
            label: const Text("Подключиться к видео"),
            onPressed: _connectToZoom,
          ),
          const SizedBox(height: 10),
          // "Choose another game" moved here as requested
          if (!widget.isHost)
            TextButton(
              onPressed: () {
                  // Popping active game screen returns to Lobby (GameScreen)
                  Navigator.pop(context);
              },
              child: const Text("Выбрать другую игру", style: TextStyle(color: Colors.blueAccent)),
            )
        ],
      ),
    );
  }
  
  Widget _buildVideoOffPlaceholder() {
    // When video is active/inited but camera off or disconnected in UI
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const Icon(Icons.videocam_off, color: Colors.white24, size: 48),
          const SizedBox(height: 12),
          const Text("Видео отключено", style: TextStyle(color: Colors.white38)),
          const SizedBox(height: 20),
          ElevatedButton.icon(
             icon: const Icon(Icons.videocam),
             label: const Text("Войти в конференцию"),
             onPressed: _connectToZoom,
          ),
          if (!widget.isHost)
             TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text("Выйти", style: TextStyle(color: Colors.white38)),
            )

        ],
      ),
    );
  }

  Widget _buildZoomPanel() {
    final bool isVisible = _situation['isVisible'] == true;
    final String? controllerId = _situation['controllerId'];
    final bool hasControl = widget.isHost || (FirebaseAuth.instance.currentUser?.uid == controllerId);

    return LayoutBuilder(
      builder: (context, constraints) {
        // User reports Zoom stretches well now, no need for shift
        
        return Stack(
          children: [
            // Zoom Window (Full width/height of container)
            Positioned.fill(
               child: HtmlElementView(key: _zoomViewKey, viewType: 'zoom-container'),
            ),
        
        // SITUATION OVERLAY
        if (isVisible)
           Positioned.fill(
              child: Container(
                 decoration: const BoxDecoration(
                    image: DecorationImage(
                       image: AssetImage('assets/images/fon.png'),
                       fit: BoxFit.cover,
                    )
                 ),
                 child: Stack(
                    children: [
                       // Logo Top Left
                       Positioned(
                          top: 16, left: 16,
                          child: Image.asset('assets/images/logo.png', width: 60, fit: BoxFit.contain)
                       ),
                       
                       // Center Text
                       Center(
                          child: Padding(
                             padding: const EdgeInsets.symmetric(horizontal: 48),
                             child: Text(
                                _situation['text'] ?? "",
                                textAlign: TextAlign.center,
                                style: const TextStyle(
                                   fontFamily: 'DINPro',
                                   fontWeight: FontWeight.w900,
                                   fontSize: 24,
                                   color: Colors.white,
                                   shadows: [Shadow(color: Colors.black, blurRadius: 4, offset: Offset(1,1))]
                                ),
                             ),
                          )
                       ),
                       
                       // Link Bottom Left
                       Positioned(
                          bottom: 16, left: 16,
                          child: InkWell(
                             onTap: () => launchUrl(Uri.parse("https://t.me/id_territory")),
                             child: const Text(
                                "https://t.me/id_territory",
                                style: TextStyle(
                                   color: Colors.white70, 
                                   fontSize: 12, 
                                   decoration: TextDecoration.underline
                                ),
                             ),
                          )
                       )
                    ],
                 ),
              )
           ),

        // Controls (Consolidated Bottom Right - Single Row)
        Positioned(
          bottom: 0, right: 0, 
          child: SafeArea(
            child: Padding(
              padding: const EdgeInsets.all(10),
              child: Row(
             mainAxisSize: MainAxisSize.min,
             children: [
                // 0. Grid Toggle (New)
                if (false && _isVideoActive) ...[
                   SizedBox(
                      width: 56, height: 56,
                      child: FloatingActionButton(
                        heroTag: 'toggle_grid',
                        backgroundColor: _isGridMode ? Colors.blueAccent : Colors.grey[800],
                        onPressed: () {
                            setState(() => _isGridMode = !_isGridMode);
                            if (kIsWeb) zoom_js.toggleZoomGrid(_isGridMode);
                        },
                        tooltip: _isGridMode ? "Обычный вид" : "Сетка",
                        child: Icon(_isGridMode ? Icons.grid_off : Icons.grid_view, color: Colors.white, size: 28),
                      ),
                   ),
                   const SizedBox(width: 12),
                ],

                // 1. Situation Controls (Left side of the row)
                if (hasControl) ...[
                   SizedBox(
                     width: 56, height: 56, // Explicit large size
                     child: FloatingActionButton(
                        heroTag: 'refresh_sit',
                        backgroundColor: Colors.blueGrey,
                        child: const Icon(Icons.refresh, color: Colors.white, size: 32), // Larger icon
                        onPressed: _randomizeSituation,
                     ),
                   ),
                   const SizedBox(width: 12),
                   SizedBox(
                     width: 64, height: 64, // Even larger (2x mini is ~40 -> 80, but 64 is good for FAB default)
                     child: FloatingActionButton(
                        heroTag: 'show_sit',
                        backgroundColor: isVisible ? Colors.green : Colors.orange,
                        onPressed: () => _firestoreService.setSituationVisible(_targetGameId, !isVisible),
                        tooltip: isVisible ? "Скрыть ситуацию" : "Показать ситуацию",
                        child: Icon(isVisible ? Icons.visibility_off : Icons.visibility, size: 36),
                     ),
                   ),
                   const SizedBox(width: 24), // Space between situation and host/call controls
                ],
                // 2. Host Settings
                if (widget.isHost) ...[
                   Container(
                     decoration: const BoxDecoration(shape: BoxShape.circle, color: Colors.black54),
                     child: IconButton(
                        iconSize: 36, // Larger icon
                        icon: const Icon(Icons.settings_accessibility, color: Colors.blueAccent),
                        tooltip: "Назначить управление ситуацией",
                        onPressed: _showSituationControllerDialog,
                     ),
                   ),
                   const SizedBox(width: 12),
                ],

                // 3. End Call
                SizedBox(
                  width: 56, height: 56,
                  child: FloatingActionButton(
                     backgroundColor: Colors.red,
                     child: const Icon(Icons.call_end, size: 32),
                     onPressed: () {
                        zoom_js.leaveZoom();
                        setState(() => _isVideoActive = false);
                     },
                  ),
                ),
             ],
          ),
        ),
      ),
    ),
        
        // Remove old Bottom Right Positioned block (It's now merged above)
      ],
    );
      }
    );
  }

  Future<void> _fetchSituations(String? packId, dynamic categories) async {
      if (packId == null) return;
      
      _situationsLoaded = true; // Prevent multiple fetches
      
      try {
         final packDoc = await _firestoreService.getSituationPack(packId);
         if (packDoc.exists && packDoc.data() != null) {
            final allSituations = List<Map<String, dynamic>>.from(packDoc.data()!['situations'] ?? []);
            
            // Filter
            List<String> validCategories = [];
            if (categories is List) {
               validCategories = categories.cast<String>();
            }
            
            if (validCategories.isNotEmpty) {
               _availableSituations = allSituations.where((s) => validCategories.contains(s['category'])).toList();
            } else {
               _availableSituations = allSituations;
            }
            
            debugPrint("Loaded ${_availableSituations.length} situations from pack $packId");
         }
      } catch (e) {
         debugPrint("Error loading situations: $e");
      }
  }

  void _randomizeSituation() {
      if (_availableSituations.isNotEmpty) {
         final s = _availableSituations[Random().nextInt(_availableSituations.length)];
         _firestoreService.setSituationText(_targetGameId, s['text'] ?? "Ошибка текста");
      } else {
         ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Ситуации не загружены или фильтр пуст!")));
         // Retry load if failed or empty?? Maybe user didn't select pack correctly.
         // fallback?
      }
  }

  void _showSituationControllerDialog() {
      // Fetch participants provided we have the stream or stored list. 
      // We can use the stream builder pattern or just fetch once.
      showDialog(
         context: context,
         builder: (ctx) => AlertDialog(
            title: const Text("Кто выбирает ситуацию?"),
            content: SizedBox(
               width: 300,
               height: 400,
               child: StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
                  stream: _firestoreService.getGameParticipantsStream(_targetGameId),
                  builder: (context, snapshot) {
                     if (!snapshot.hasData) return const Center(child: CircularProgressIndicator());
                     final docs = snapshot.data!.docs;
                     
                     return ListView(
                        shrinkWrap: true,
                        children: [
                           ListTile(
                              title: const Text("Только Ведущий"),
                              leading: const Icon(Icons.person_outline),
                              onTap: () {
                                 _firestoreService.setSituationController(_targetGameId, null);
                                 Navigator.pop(ctx);
                              },
                           ),
                           const Divider(),
                           ...docs.map((d) {
                              final name = d.data()['name'];
                              return ListTile(
                                 title: Text(name),
                                 leading: const Icon(Icons.face),
                                 selected: _situation['controllerId'] == d.id,
                                 onTap: () {
                                    _firestoreService.setSituationController(_targetGameId, d.id);
                                    Navigator.pop(ctx);
                                 },
                              );
                           }).toList()
                        ],
                     );
                  }
               ),
            ),
         )
      );
  }

  // Reuse logic directly
  Widget _buildRolesGrid() {
    final Set<int> uniqueNumbers = {};
    if (widget.gameProfile != null) {
      for (var n in widget.gameProfile!.numbers) {
        uniqueNumbers.add(n == 0 ? 22 : n);
      }
    }
    final sortedNumbers = uniqueNumbers.toList()..sort();

    return LayoutBuilder(
      builder: (context, constraints) {
        // RESPONSIVE: Increase columns on wider screens
        final int crossAxisCount = constraints.maxWidth > 900 ? 10 : (constraints.maxWidth > 600 ? 7 : 5);
        final double aspectRatio = constraints.maxWidth > 600 ? 0.75 : 0.65;

        return GridView.builder(
          padding: const EdgeInsets.all(12),
          gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: crossAxisCount, 
            childAspectRatio: aspectRatio, 
            crossAxisSpacing: 8, 
            mainAxisSpacing: 8,
          ),
          itemCount: sortedNumbers.length,
          itemBuilder: (context, index) {
            final number = sortedNumbers[index];
            final isSelected = _selectedRole == number;
            return GestureDetector(
              onTap: () => _showRoleInfo(number),
              child: Container(
                decoration: BoxDecoration(
                  border: isSelected ? Border.all(color: Colors.orange, width: 3) : null,
                  borderRadius: BorderRadius.circular(8),
                  boxShadow: isSelected ? [BoxShadow(color: Colors.orange.withOpacity(0.5), blurRadius: 8)] : null,
                ),
                child: Card(
                  clipBehavior: Clip.antiAlias, margin: EdgeInsets.zero, elevation: isSelected ? 8 : 2,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      Expanded(
                        child: Image.asset('assets/images/cards/role_$number.png', fit: BoxFit.cover, errorBuilder: (c,e,s)=>const Icon(Icons.image_not_supported)),
                      ),
                      Container(
                        color: isSelected ? Colors.orange : Colors.black54,
                        padding: const EdgeInsets.symmetric(vertical: 2),
                        child: Text('$number', textAlign: TextAlign.center, style: const TextStyle(fontSize: 12, color: Colors.white, fontWeight: FontWeight.bold)),
                      ),
                    ],
                  ),
                ),
              ),
            );
          },
        );
      }
    );
  }

  // Temp optimized state for local feeling (prevents "hanging")
  String? _localOptimisticVote;

  Widget _buildVotingBoard() {
      return StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
         stream: _firestoreService.getGameParticipantsStream(_targetGameId),
         builder: (context, snapshot) {
            if (!snapshot.hasData) return const Center(child: CircularProgressIndicator());
            
            final participants = snapshot.data!.docs.toList();
            final String? myUid = FirebaseAuth.instance.currentUser?.uid;
            
            // Sort: Host always first if participating, then by number
            participants.sort((a, b) {
                final nA = a.data()['playerNumber'] ?? 999;
                final nB = b.data()['playerNumber'] ?? 999;
                return nA.compareTo(nB);
            });
            
            // Define my real vote
            String? myRealVoteId;
            try {
               final myDoc = participants.where((d) => d.id == myUid).firstOrNull;
               myRealVoteId = myDoc?.data()['votedFor'];
            } catch (_) {}

            // Use Local Optimistic Vote if available and differs (avoids UI lag) (Only for non-hosts or simple user flow)
            final String? currentVoteId = _localOptimisticVote ?? myRealVoteId;

            return LayoutBuilder(
               builder: (context, constraints) {
                  // RESPONSIVE GRID
                  final int crossAxisCount = constraints.maxWidth > 900 ? 10 : (constraints.maxWidth > 600 ? 7 : 5);
                  final double aspectRatio = constraints.maxWidth > 600 ? 0.75 : 0.65;
                  
                  return Padding(
                     padding: const EdgeInsets.all(8.0),
                     child: Column(
                       children: [
                         if (widget.isHost)
                            const Text("Голосование (Нажмите на игрока для управления)", style: TextStyle(color: Colors.white, fontSize: 16)),
                         const SizedBox(height: 8),
                         Expanded(
                           child: GridView.builder(
                             gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                               crossAxisCount: crossAxisCount, 
                               childAspectRatio: aspectRatio, 
                               crossAxisSpacing: 8, 
                               mainAxisSpacing: 8,
                             ),
                             itemCount: participants.length,
                             itemBuilder: (context, index) {
                                final doc = participants[index];
                                final pData = doc.data();
                                final pUid = doc.id;
                                final pNum = pData['playerNumber'];
                                final pName = pData['name'] ?? '...';
                                final pRoleId = pData['selectedRole'];
                                
                                final bool isSelected = currentVoteId == pUid;
                                final bool isMe = myUid == pUid;

                                return GestureDetector(
                                   onTap: () {
                                      if (widget.isHost) {
                                         // Host: Proxy Control
                                         _showHostProxyDialog(doc, participants);
                                      } else {
                                         // Player: Vote Logic with Optimistic Update
                                         if (isSelected) {
                                            // Toggle Off
                                            setState(() => _localOptimisticVote = null); // Optimistic clear. Note: null might conflict if real vote exists, better use specific flag
                                            _firestoreService.clearVote(_targetGameId).then((_) {
                                                if (mounted) setState(() => _localOptimisticVote = null);
                                            });
                                         } else {
                                            // Toggle On
                                            setState(() => _localOptimisticVote = pUid);
                                            _firestoreService.voteForPlayer(_targetGameId, pUid).then((_) {
                                                // Sync finished
                                                if (mounted) setState(() => _localOptimisticVote = null); // Reset to rely on stream
                                            });
                                         }
                                      }
                                   },
                                   child: Container(
                                      decoration: BoxDecoration(
                                         borderRadius: BorderRadius.circular(8),
                                         border: Border.all(color: isSelected ? Colors.green : Colors.transparent, width: 3),
                                         boxShadow: isSelected ? [BoxShadow(color: Colors.green.withOpacity(0.5), blurRadius: 8)] : null,
                                      ),
                                      child: Card(
                                         color: isMe ? Colors.white10 : Colors.white12,
                                         clipBehavior: Clip.antiAlias,
                                         margin: EdgeInsets.zero,
                                         child: Column(
                                            crossAxisAlignment: CrossAxisAlignment.stretch,
                                            children: [
                                               Expanded(
                                                  child: Stack(
                                                     fit: StackFit.expand,
                                                     children: [
                                                        if (pRoleId != null)
                                                           Opacity(opacity: 0.3, child: Image.asset('assets/images/cards/role_$pRoleId.png', fit: BoxFit.cover, errorBuilder: (c,e,s)=>Container())),
                                                        
                                                        Center(child: Column(
                                                           mainAxisAlignment: MainAxisAlignment.center,
                                                           children: [
                                                              if (pNum != null) CircleAvatar(radius: 14, backgroundColor: Colors.white24, child: Text("$pNum", style: const TextStyle(color: Colors.white, fontSize: 14, fontWeight: FontWeight.bold))),
                                                              const SizedBox(height: 4),
                                                              Text(pName, textAlign: TextAlign.center, maxLines: 2, overflow: TextOverflow.ellipsis, style: const TextStyle(color: Colors.white, fontSize: 11, fontWeight: FontWeight.bold)),
                                                              
                                                              // Host sees votes
                                                              if (widget.isHost && pData['votedFor'] != null) ...[
                                                                 const SizedBox(height: 4),
                                                                 Builder(builder: (context) {
                                                                    final vId = pData['votedFor'];
                                                                    final target = participants.where((d) => d.id == vId).firstOrNull;
                                                                    final tName = target != null 
                                                                        ? (target.data()['playerNumber'] != null ? "${target.data()['playerNumber']}" : (target.data()['name'] ?? '?'))
                                                                        : '?';
                                                                    return Container(
                                                                      padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 2),
                                                                      decoration: BoxDecoration(color: Colors.white10, borderRadius: BorderRadius.circular(4)),
                                                                      child: Text("За: $tName", style: const TextStyle(color: Colors.yellowAccent, fontSize: 10, fontWeight: FontWeight.bold))
                                                                    );
                                                                 })
                                                              ]
                                                           ],
                                                        ))
                                                     ],
                                                  ),
                                               ),
                                               // Black Bar at bottom
                                               Container(
                                                 color: Colors.black54,
                                                 padding: const EdgeInsets.symmetric(vertical: 2, horizontal: 2),
                                                 child: Text(
                                                    pRoleId != null ? "Роль $pRoleId" : "Нет роли",
                                                    textAlign: TextAlign.center,
                                                    style: TextStyle(fontSize: 10, color: pRoleId != null ? Colors.orangeAccent : Colors.grey, fontWeight: FontWeight.bold)
                                                 ),
                                               )
                                            ],
                                         ),
                                      )
                                   )
                                );
                             },
                           ),
                         )
                       ]
                     )
                  );
               }
            );
         }
      );
  }

  void _showHostProxyDialog(QueryDocumentSnapshot<Map<String, dynamic>> subjectDoc, List<QueryDocumentSnapshot<Map<String, dynamic>>> allParticipants) {
     final sData = subjectDoc.data();
     final sName = sData['name'];
     final sId = subjectDoc.id;

     showDialog(
        context: context,
        builder: (ctx) => SimpleDialog(
           title: Text("Управление: $sName"),
           children: [
              SimpleDialogOption(
                 child: const Text("Голос ЗА кого-то..."),
                 onPressed: () {
                    Navigator.pop(ctx);
                    _showProxyVoteSelection(sId, sName, allParticipants);
                 },
              ),
              SimpleDialogOption(
                 child: const Text("Сбросить его голос"),
                 onPressed: () {
                    Navigator.pop(ctx);
                    _firestoreService.clearVote(_targetGameId, sId);
                 },
              ),
              // Add option to set role here too if needed, but currently only voting requested in this stage
           ],
        )
     );
  }

  void _showProxyVoteSelection(String voterId, String voterName, List<QueryDocumentSnapshot<Map<String, dynamic>>> candidates) {
      showDialog(
         context: context,
         builder: (ctx) => AlertDialog(
            title: Text("$voterName голосует за:"),
            content: SizedBox(
               width: 300,
               height: 400,
               child: ListView.builder(
                  shrinkWrap: true,
                  itemCount: candidates.length,
                  itemBuilder: (context, index) {
                     final c = candidates[index];
                     final name = c.data()['name'];
                     final num = c.data()['playerNumber'];
                     return ListTile(
                        leading: CircleAvatar(child: Text("$num")),
                        title: Text(name),
                        onTap: () {
                           Navigator.pop(ctx);
                           _firestoreService.voteForPlayer(_targetGameId, c.id, voterId);
                           ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text("$voterName проголосовал за $name")));
                        },
                     );
                  },
               ),
            ),
         )
      );
  }
  
    // --- HOST SPECIFIC: SELECTION/LOBBY BOARD ---

   Widget _buildHostSelectionBoard() {
      return Column(
        children: [
           Padding(
             padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
             child: ElevatedButton.icon(
                icon: const Icon(Icons.person_add),
                label: const Text("Добавить игрока (Виртуальный)"),
                style: ElevatedButton.styleFrom(backgroundColor: Colors.blueGrey),
                onPressed: _showAddVirtualPlayerDialog,
             )
           ),
           Expanded(
              child: StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
                 stream: _firestoreService.getGameParticipantsStream(_targetGameId),

         builder: (context, snapshot) {
            if (!snapshot.hasData) return const Center(child: CircularProgressIndicator());
            final docs = snapshot.data!.docs.toList();
            
            // Prioritize pending requests
            docs.sort((a, b) {
               final sA = a.data()['status'] ?? '';
               final sB = b.data()['status'] ?? '';
               if (sA == 'pending' && sB != 'pending') return -1;
               if (sA != 'pending' && sB == 'pending') return 1;
               return 0;
            });
            
            if (docs.isEmpty) return const Center(child: Text("Нет участников", style: TextStyle(color: Colors.white54)));

            if (docs.isEmpty) return const Center(child: Text("Нет участников", style: TextStyle(color: Colors.white54)));

            return LayoutBuilder(
               builder: (context, constraints) {
                 final int crossAxisCount = constraints.maxWidth > 900 ? 10 : (constraints.maxWidth > 600 ? 7 : 5);
                 final double aspectRatio = constraints.maxWidth > 600 ? 0.75 : 0.65;

                 return GridView.builder(
                   padding: const EdgeInsets.all(8),
                   gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                     crossAxisCount: crossAxisCount, 
                     childAspectRatio: aspectRatio,
                     crossAxisSpacing: 8, mainAxisSpacing: 8
                   ),
                   itemCount: docs.length,
                   itemBuilder: (context, index) {
                      final data = docs[index].data();
                      final docId = docs[index].id;
                      final name = data['name'] ?? 'Unknown';
                      final pNum = data['playerNumber'];
                      final roleId = data['selectedRole'];
                      // ... rest of item builder logic (Needs to be passed back carefully or rewritten)
                      // Since we are replacing lines 606-612, we need to ensure the itemBuilder continues correctly
                      // Wait, I can't easily break inside the itemBuilder with multiReplace if I don't provide the full content.
                      // I will replace the GridView.builder block entirely.
                      
                      return Card(
                           clipBehavior: Clip.antiAlias,
                           color: data['status'] == 'pending' ? Colors.orange.withOpacity(0.15) : Colors.white12,
                           shape: data['status'] == 'pending' 
                              ? RoundedRectangleBorder(borderRadius: BorderRadius.circular(8), side: const BorderSide(color: Colors.orangeAccent, width: 1))
                              : null,
                           child: Stack(
                              children: [
                                 if (roleId != null)
                                    Positioned.fill(
                                       child: Opacity(
                                          opacity: 0.15,
                                          child: Image.asset(
                                             'assets/images/cards/role_$roleId.png',
                                             fit: BoxFit.cover,
                                             errorBuilder: (c, e, s) => Container(),
                                          )
                                       )
                                    ),
                                 
                                 Center(
                                   child: Column(
                                     mainAxisAlignment: MainAxisAlignment.center,
                                     children: [
                                        if (pNum != null)
                                           InkWell(
                                              onTap: () {
                                                 if (widget.isHost) {
                                                    _showRemovePlayerDialog(docId, name);
                                                 }
                                              },
                                              child: CircleAvatar(
                                                 radius: 12, 
                                                 backgroundColor: Colors.white24, 
                                                 child: Text("$pNum", style: const TextStyle(fontSize: 12, color: Colors.white))
                                              ),
                                           ),
                                        const SizedBox(height: 4),
                                        Text(name, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold), textAlign: TextAlign.center),
                                        const Spacer(),
                                        if (data['status'] == 'pending') ...[
                                            // Pending Logic (Keep existing)
                                            FutureBuilder<DocumentSnapshot>(
                                               future: FirebaseFirestore.instance.collection('users').doc(data['userId'] ?? 'unknown').get(),
                                               builder: (context, snapshot) {
                                                  if (!snapshot.hasData || snapshot.data == null) return const SizedBox.shrink();
                                                  final userData = snapshot.data!.data() as Map<String, dynamic>?;
                                                  final telegram = userData?['telegram'] as String?;
                                                  
                                                  if (telegram != null && telegram.isNotEmpty) {
                                                      return TextButton.icon(
                                                          style: TextButton.styleFrom(padding: EdgeInsets.zero, minimumSize: const Size(0, 20)),
                                                          icon: const Icon(Icons.alternate_email, size: 10, color: Colors.blueAccent),
                                                          label: const Text("Написать", style: TextStyle(color: Colors.blueAccent, fontSize: 10)),
                                                          onPressed: () {
                                                              String tg = telegram.replaceAll('@', '');
                                                              launchUrl(Uri.parse("https://t.me/$tg"));
                                                          },
                                                      );
                                                  } else {
                                                      return const Text("Tg: нет", style: TextStyle(color: Colors.white30, fontSize: 10));
                                                  }
                                               }
                                            ),
                                            const SizedBox(height: 4),
                                            Row(
                                               mainAxisAlignment: MainAxisAlignment.center,
                                               children: [
                                                  ElevatedButton(
                                                     style: ElevatedButton.styleFrom(
                                                        minimumSize: const Size(0,24), 
                                                        backgroundColor: Colors.green,
                                                        padding: const EdgeInsets.symmetric(horizontal: 4)
                                                     ),
                                                     onPressed: () => _firestoreService.approveParticipant(_targetGameId, docId),
                                                     child: const Text("Да", style: TextStyle(fontSize: 10))
                                                  ),
                                                  const SizedBox(width: 4),
                                                  ElevatedButton(
                                                     style: ElevatedButton.styleFrom(
                                                        minimumSize: const Size(0,24), 
                                                        backgroundColor: Colors.redAccent,
                                                        padding: const EdgeInsets.symmetric(horizontal: 4)
                                                     ),
                                                     onPressed: () => _firestoreService.rejectParticipant(_targetGameId, docId),
                                                     child: const Text("Нет", style: TextStyle(fontSize: 10))
                                                  ),
                                               ],
                                            )
                                        ] else ...[
                                            // Active participant logic
                                            if (List<int>.from(data['numbers'] ?? []).isNotEmpty)
                                               TextButton(
                                                  style: TextButton.styleFrom(minimumSize: const Size(0, 24), padding: EdgeInsets.zero),
                                                  onPressed: () => _showDiagnosticCard(List<int>.from(data['numbers'] ?? []), name, userId: docId),
                                                  child: const Text("Карта", style: TextStyle(color: Colors.blueAccent, fontSize: 10, decoration: TextDecoration.underline))
                                               ),
                                            const SizedBox(height: 2),
                                            
                                            // Role Management (Click here to set role)
                                            InkWell(
                                               onTap: () => _showHostRoleManagement(docId, name, roleId),
                                               child: roleId != null 
                                                  ? Row(
                                                     mainAxisAlignment: MainAxisAlignment.center,
                                                     children: [
                                                        Container(
                                                           padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 1),
                                                           decoration: BoxDecoration(color: Colors.orange, borderRadius: BorderRadius.circular(4)),
                                                           child: Text("#$roleId", style: const TextStyle(color: Colors.black, fontWeight: FontWeight.bold, fontSize: 10))
                                                        ),
                                                        const SizedBox(width: 4),
                                                        InkWell(
                                                           onTap: () => _firestoreService.updateParticipantRole(_targetGameId, null, docId),
                                                           child: const Icon(Icons.close, color: Colors.red, size: 14),
                                                        )
                                                     ],
                                                  )
                                                  : Container(
                                                      padding: const EdgeInsets.all(4),
                                                      color: Colors.white10,
                                                      child: const Text("Нет роли", textAlign: TextAlign.center, style: TextStyle(color: Colors.white38, fontSize: 9))
                                                  )
                                            )
                                        ],
                                        const Spacer(),
                                     ],
                                   ),
                                 ),
                              ],
                           ),
                      );
                   },
                 );
               }
            );
            }
         )
      )
        ],
      );
 }

   void _showRemovePlayerDialog(String userId, String userName) {
      showDialog(
         context: context,
         builder: (ctx) => AlertDialog(
            backgroundColor: const Color(0xFF1E293B),
            title: Text("Удалить игрока?", style: const TextStyle(color: Colors.white)),
            content: Text("Вы действительно хотите удалить игрока $userName из игры?", style: const TextStyle(color: Colors.white70)),
            actions: [
               TextButton(
                  onPressed: () => Navigator.pop(ctx),
                  child: const Text("Отмена")
               ),
               ElevatedButton(
                  style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
                  onPressed: () async {
                     try {
                        await _firestoreService.removeParticipant(_targetGameId, userId);
                        if (ctx.mounted) Navigator.pop(ctx);
                     } catch (e) {
                        if (ctx.mounted) Navigator.pop(ctx);
                        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text("Ошибка: $e")));
                     }
                  },
                  child: const Text("Удалить")
               )
            ],
         )
      );
   }

   void _showHostRoleManagement(String userId, String userName, int? currentRole) {
      final TextEditingController roleCtrl = TextEditingController(text: currentRole?.toString() ?? "");
      
      showDialog(
         context: context,
         builder: (ctx) => AlertDialog(
            title: Text("Роль для $userName"),
            content: Column(
               mainAxisSize: MainAxisSize.min,
               children: [
                  const Text("Введите номер роли (1-22):"),
                  const SizedBox(height: 8),
                  TextField(
                     controller: roleCtrl,
                     keyboardType: TextInputType.number,
                     decoration: const InputDecoration(border: OutlineInputBorder(), labelText: "Номер роли"),
                  )
               ],
            ),
            actions: [
               TextButton(onPressed: () => Navigator.pop(ctx), child: const Text("Отмена")),
               ElevatedButton(
                  onPressed: () {
                     final val = int.tryParse(roleCtrl.text);
                     if (val != null) {
                        _firestoreService.updateParticipantRole(_targetGameId, val, userId);
                        Navigator.pop(ctx);
                     }
                  },
                  child: const Text("Сохранить")
               )
            ],
         )
      );
   }

   // --- SHOW CARD DIALOG ---
   
  void _showDiagnosticCard(List<int> numbers, String name, {String? userId}) {
   int n(int idx) => (idx < numbers.length) ? (numbers[idx] == 0 ? 22 : numbers[idx]) : 22;

   void onRoleTap(int roleId) {
       if (userId != null && widget.isHost) {
          showDialog(
             context: context,
             builder: (ctx) => AlertDialog(
                title: Text("Назначить роль $roleId игроку $name?"),
                actions: [
                   TextButton(onPressed: () => Navigator.pop(ctx), child: const Text("Отмена")),
                   ElevatedButton(
                      onPressed: () {
                         _firestoreService.updateParticipantRole(_targetGameId, roleId, userId);
                         Navigator.pop(ctx); // Close alert
                         Navigator.pop(context); // Close card
                         ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Роль назначена!")));
                      },
                      child: const Text("Да")
                   )
                ],
             )
          );
       }
   }

      showDialog(
        context: context,
        builder: (context) => Dialog(
          backgroundColor: Colors.transparent,
          child: Container(
            width: 380, // Mimicking mobile/sheet width
            height: 550,
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: const Color(0xFF0F172A),
              borderRadius: BorderRadius.circular(24),
              border: Border.all(color: Colors.white24),
              image: const DecorationImage(
                 image: AssetImage('assets/images/IDPGMD092025.png'),
                 opacity: 0.1, 
                 fit: BoxFit.cover,
              ),
              boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.7), blurRadius: 30)],
            ),
            child: Column(
              children: [
                 Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                       Padding(
                         padding: const EdgeInsets.all(8.0),
                         child: Text(name.toUpperCase(), style: const TextStyle(color: Colors.white, fontSize: 14, fontWeight: FontWeight.bold, letterSpacing: 1.2)),
                       ),
                       IconButton(onPressed: () => Navigator.pop(context), icon: const Icon(Icons.close, color: Colors.white54, size: 20)),
                    ],
                 ),
                 const Divider(color: Colors.white10, height: 1),
                 Expanded(
                    child: SingleChildScrollView(
                       padding: const EdgeInsets.symmetric(vertical: 10),
                       child: Column(
                          children: [
                              Row(
                                 crossAxisAlignment: CrossAxisAlignment.start,
                                 children: [
                                    Expanded(flex: 3, child: _buildSheetSection("ФАЗЫ ЖИЗНИ", [n(0), n(1), n(2)], onRoleTap)),
                                    Expanded(flex: 1, child: _buildSheetSection("ТОЧКА ВХОДА", [n(3)], onRoleTap)),
                                 ],
                              ),
                              Row(
                                 children: [
                                    Expanded(child: _buildSheetSection("ДУАЛЬНОСТЬ ИНЬ", [n(4), n(5)], onRoleTap)),
                                    Expanded(child: _buildSheetSection("ДУАЛЬНОСТЬ ЯН", [n(6), n(7)], onRoleTap)),
                                 ],
                              ),
                              Row(
                                 children: [
                                    Expanded(child: _buildSheetSection("МОТИВ", [n(8)], onRoleTap)),
                                    Expanded(child: _buildSheetSection("МЕТОД", [n(9)], onRoleTap)),
                                    Expanded(child: _buildSheetSection("СФЕРА", [n(10)], onRoleTap)),
                                 ]
                              ),
                              Row(
                                 children: [
                                    Expanded(child: _buildSheetSection("СТРАХИ", [n(11)], onRoleTap)),
                                    Expanded(child: _buildSheetSection("БАЛАНС", [n(13)], onRoleTap)),
                                    Expanded(child: _buildSheetSection("ТОЧКА ВЫХОДА", [n(12)], onRoleTap)),
                                 ],
                              ),
                          ],
                       ),
                    )
                 ),
              ],
            ),
          ),
        ),
      );
   }

   Widget _buildSheetSection(String title, List<int> cardNums, [Function(int)? onRoleTap]) {
      return Column(
         children: [
            Padding(
               padding: const EdgeInsets.symmetric(vertical: 6),
               child: Text(title, style: const TextStyle(color: Colors.white38, fontSize: 10, fontWeight: FontWeight.bold, letterSpacing: 0.5)),
            ),
            Row(
               mainAxisAlignment: MainAxisAlignment.center,
               children: cardNums.map<Widget>((num) {
                  return GestureDetector(
                     onTap: () => onRoleTap?.call(num),
                     child: Container(
                        width: 55,
                        height: 78,
                        margin: const EdgeInsets.symmetric(horizontal: 4),
                        decoration: BoxDecoration(
                           borderRadius: BorderRadius.circular(6),
                           border: Border.all(color: Colors.white12, width: 0.5),
                           boxShadow: [BoxShadow(color: Colors.black26, blurRadius: 4)],
                        ),
                        child: Stack(
                           children: [
                              ClipRRect(
                                 borderRadius: BorderRadius.circular(6),
                                 child: Image.asset(
                                    'assets/images/cards/role_$num.png',
                                    fit: BoxFit.cover,
                                    errorBuilder: (c, e, s) => Container(color: Colors.white.withValues(alpha: 0.05), child: Center(child: Text("$num", style: const TextStyle(color: Colors.white54, fontSize: 10)))),
                                 ),
                              ),
                              Positioned(
                                 bottom: 0, right: 0, left: 0,
                                 child: Container(
                                    decoration: BoxDecoration(
                                       color: Colors.black54,
                                       borderRadius: const BorderRadius.only(bottomLeft: Radius.circular(6), bottomRight: Radius.circular(6)),
                                    ),
                                    padding: const EdgeInsets.symmetric(vertical: 1),
                                    child: Text("$num", textAlign: TextAlign.center, style: const TextStyle(color: Colors.white, fontSize: 9, fontWeight: FontWeight.bold)),
                                 ),
                              ),
                           ],
                        ),
                     ),
                  );
               }).toList(),
            ),
         ],
      );
   }

   Widget _buildFinalResults() {
      return StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
         stream: _firestoreService.getGameParticipantsStream(_targetGameId),
         builder: (context, snapshot) {
            if (!snapshot.hasData) return const Center(child: CircularProgressIndicator());
            final participants = snapshot.data!.docs;
            
            final sorted = _gameStats.entries.toList()
               ..sort((a, b) => (b.value as int).compareTo(a.value as int));

            return Container(
               padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
               child: Column(
                  children: [
                     Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                           const Icon(Icons.emoji_events, color: Colors.orange, size: 36),
                           const SizedBox(width: 12),
                           Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                 const Text("ИГРА ЗАВЕРШЕНА", style: TextStyle(color: Colors.redAccent, fontSize: 20, fontWeight: FontWeight.bold)),
                                 Text("Итоговая статистика", style: TextStyle(color: Colors.white70.withOpacity(0.8), fontSize: 12)),
                              ],
                           )
                        ],
                     ),
                     const Divider(color: Colors.white24, height: 16),
                     Expanded(
                        child: sorted.isEmpty 
                          ? const Center(child: Text("Нет данных о голосовании", style: TextStyle(color: Colors.white54)))
                          : ListView.builder(
                              itemCount: sorted.length,
                              itemBuilder: (context, index) {
                                 final uid = sorted[index].key;
                                 final score = sorted[index].value;
                                 final pDoc = participants.where((d) => d.id == uid).firstOrNull;
                                 final name = pDoc?.data()['name'] ?? "Unknown";
                                 final pNum = pDoc?.data()['playerNumber'];

                                 return Card(
                                    color: index == 0 ? Colors.orange.withOpacity(0.2) : Colors.white10,
                                    child: ListTile(
                                       leading: CircleAvatar(
                                          backgroundColor: index == 0 ? Colors.orange : Colors.white24,
                                          child: Text("${index + 1}", style: const TextStyle(color: Colors.black, fontWeight: FontWeight.bold)),
                                       ),
                                       title: Text(name, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
                                       subtitle: Text(pNum != null ? "Игрок $pNum" : ""),
                                       trailing: Text("$score", style: const TextStyle(color: Colors.greenAccent, fontSize: 20, fontWeight: FontWeight.bold)),
                                    ),
                                 );
                              }
                           ),
                     ),
                      if (widget.isHost)
                         const SizedBox.shrink()
                  ],
               ),
            );
         }
      );
   }

   Widget _buildGameArchivedScreen() {
      return Center(
         child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
               const Icon(Icons.check_circle_outline, color: Colors.green, size: 48),
               const SizedBox(height: 12),
               const Text("ИГРА ЗАВЕРШЕНА", style: TextStyle(color: Colors.white, fontSize: 20, fontWeight: FontWeight.bold)),
               const SizedBox(height: 24),
               ElevatedButton(
                  onPressed: _goHome,
                  child: const Text("Вернуться в главное меню"),
               )
            ],
         ),
      );
   }


   void _showRoleInfo(int number) {
    final info = KnowledgeService.getRoleInfo(number);
    final name = info['role_name'] ?? 'Роль $number';
    final description = info['description'] ?? 'Описание отсутствует';
    
    final keyQuality = info['role_key'] ?? '';
    final strength = info['role_strength'] ?? '';
    final challenge = info['role_challenge'] ?? '';
    final roleInLife = info['role_inlife'] ?? '';
    final roleQuestion = info['role_question'] ?? '';
    
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('$number. $name'),
        content: SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
               if (keyQuality.isNotEmpty) 
                  Text(keyQuality, style: const TextStyle(fontStyle: FontStyle.italic, color: Colors.grey)),
               const SizedBox(height: 10),
               const Text("Описание:", style: TextStyle(fontWeight: FontWeight.bold)),
               Text(description),
               const SizedBox(height: 10),

               if (strength.isNotEmpty) ...[
                  const Text("Сила:", style: TextStyle(fontWeight: FontWeight.bold, color: Colors.green)),
                  Text(strength),
                  const SizedBox(height: 8),
               ],
               
               if (challenge.isNotEmpty) ...[
                  const Text("Вызов:", style: TextStyle(fontWeight: FontWeight.bold, color: Colors.redAccent)),
                  Text(challenge),
                  const SizedBox(height: 8),
               ],
               
               if (roleInLife.isNotEmpty) ...[
                  const SizedBox(height: 8),
                  const Text("Проявляется в жизни:", style: TextStyle(fontWeight: FontWeight.bold, color: Colors.blueAccent)),
                  Text(roleInLife),
                  const SizedBox(height: 8),
               ],
               
               if (roleQuestion.isNotEmpty) ...[
                  const Divider(),
                  const Text("Вопрос для рефлексии:", style: TextStyle(fontWeight: FontWeight.bold, color: Colors.amber)),
                  Text(roleQuestion, style: const TextStyle(fontStyle: FontStyle.italic)),
               ],
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Закрыть'),
          ),
          ElevatedButton(
            onPressed: () async {
              setState(() {
                _selectedRole = number;
              });
              
              if (_targetGameId.isNotEmpty) {
                  await _firestoreService.updateParticipantRole(_targetGameId, number);
                  if (context.mounted) {
                      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Выбрана роль: $name')));
                  }
              }
              if (context.mounted) Navigator.pop(context);
            },
            child: const Text('Выбрать роль'),
          ),
        ],
      ),
    );
  }

  void _showEndSessionDialog() {
      showDialog(
         context: context,
         builder: (c) => AlertDialog(
            title: const Text("Завершить сессию?"),
            content: const Text("Результаты будут сохранены в истории, а все участники вернутся в лобби."),
            actions: [
               TextButton(onPressed: () => Navigator.pop(c), child: const Text("Отмена")),
               ElevatedButton(
                  onPressed: () {
                     Navigator.pop(c);
                     _firestoreService.archiveGame(_targetGameId);
                  },
                  child: const Text("Завершить"),
               )
            ],
         )
      );
   }

   void _showEndRoundDialog() {
       showDialog(
          context: context,
          builder: (ctx) => AlertDialog(
             backgroundColor: const Color(0xFF1E293B),
             title: const Text("Завершить кон?", style: TextStyle(color: Colors.white)),
             content: const Text("Все текущие голоса будут занесены в статистику, а выборы (роли и голоса) будут сброшены для следующего кона.", style: TextStyle(color: Colors.white70)),
             actions: [
                TextButton(onPressed: () => Navigator.pop(ctx), child: const Text("Отмена")),
                ElevatedButton(
                   style: ElevatedButton.styleFrom(backgroundColor: Colors.orange),
                   onPressed: () async {
                      Navigator.pop(ctx);
                      
                      // Offline Recording Logic: Stop and Restart
                      if (_isOfflineMode && _isRecording) {
                          await _stopAndSaveRecording();
                          // Short delay before restart to ensure file separation
                          Future.delayed(const Duration(milliseconds: 500), () {
                              if (mounted) _startRecording(); // Start new recording for next round
                          });
                      }

                      try {
                         await _firestoreService.endRound(_targetGameId);
                      } catch (e) {
                         if (context.mounted) {
                            ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text("Ошибка: $e"), backgroundColor: Colors.red));
                         }
                      }
                   },
                   child: const Text("Завершить", style: TextStyle(color: Colors.black))
                )
             ],
          )
       );
   }

   void _showEndGameDialog() {
       showDialog(
          context: context,
          builder: (ctx) => AlertDialog(
             backgroundColor: const Color(0xFF1E293B),
             title: const Text("Завершить игру?", style: TextStyle(color: Colors.white)),
             content: const Text("Игра будет остановлена, и всем участникам будет показана итоговая статистика.", style: TextStyle(color: Colors.white70)),
             actions: [
                TextButton(onPressed: () => Navigator.pop(ctx), child: const Text("Отмена")),
                ElevatedButton(
                   style: ElevatedButton.styleFrom(backgroundColor: Colors.redAccent),
                   onPressed: () async {
                      Navigator.pop(ctx);
                      
                      // Stop recording on finish
                      if (_isOfflineMode && _isRecording) {
                          await _stopAndSaveRecording();
                      }

                      await _firestoreService.finishGame(_targetGameId);
                   },
                   child: const Text("Финиш", style: TextStyle(color: Colors.white))
                )
             ],
          )
       );
   }

   void _showSituationSearchDialog() {
       showDialog(
          context: context,
          builder: (context) => _SituationSearchDialog(
             situations: _availableSituations,
             onSelect: (sit) {
                // Update Game Situation
                _firestoreService.updateSituation(
                   _targetGameId,
                   {
                      'text': sit['text'],
                      'id': sit['id']?.toString()
                   }
                );
                // Also show it visible immediately
                _firestoreService.setSituationVisible(_targetGameId, true);
             }
          )
       );
   }

   void _showAddVirtualPlayerDialog() {
       // Fetch current participants to determine occupied numbers
       _firestoreService.getGameParticipantsStream(_targetGameId).first.then((snapshot) {
           final occupied = snapshot.docs
               .map((d) => d.data()['playerNumber'] as int?)
               .where((n) => n != null)
               .cast<int>()
               .toList();

           if (!mounted) return;

           showDialog(
               context: context,
               builder: (context) => _VirtualPlayerDialog(occupiedNumbers: occupied)
           ).then((result) {
                if (result != null && result is Map) {
                    _firestoreService.addVirtualParticipant(
                        _targetGameId, 
                        result['name'], 
                        result['numbers'] ?? [],
                        result['playerNumber'] // Pass selected number
                    );
                }
           });
       });
   }
}

class _VirtualPlayerDialog extends StatefulWidget {
  final List<int> occupiedNumbers;
  const _VirtualPlayerDialog({super.key, required this.occupiedNumbers});

  @override
  State<_VirtualPlayerDialog> createState() => _VirtualPlayerDialogState();
}

class _VirtualPlayerDialogState extends State<_VirtualPlayerDialog> {
  // Manual Tab
  final _nameCtrl = TextEditingController();
  final _dateCtrl = TextEditingController();
  String _gender = 'М';
  
  // Shared
  int? _selectedNumber; // 1-10

  // History Tab
  final FirestoreService _firestoreService = FirestoreService();
  bool _isLoadingHistory = false;
  List<Calculation> _allCalculations = [];
  List<String> _folders = [];
  String? _currentFolder;

  @override
  void initState() {
    super.initState();
    // Auto-select first available number
    for (int i = 1; i <= 10; i++) {
      if (!widget.occupiedNumbers.contains(i)) {
        _selectedNumber = i;
        break;
      }
    }
    _loadHistory();
  }

  Future<void> _loadHistory() async {
    setState(() => _isLoadingHistory = true);
    try {
      final rawDocs = await _firestoreService.getCalculationsRaw();
      final List<Calculation> loadedCalcs = [];
      final Set<String> folderSet = {};
      
      for (var doc in rawDocs) {
        try {
          final calc = Calculation.fromMap(doc);
          loadedCalcs.add(calc); // No firebaseId needed for just reading values
          if (calc.group != null && calc.group!.isNotEmpty) {
            folderSet.add(calc.group!);
          }
        } catch (e) {
          debugPrint("Error parsing doc: $e");
        }
      }
      
      if (mounted) {
        setState(() {
          _allCalculations = loadedCalcs;
          _folders = folderSet.toList()..sort();
        });
      }
    } catch (e) {
      debugPrint("Error loading history: $e");
    } finally {
      if (mounted) setState(() => _isLoadingHistory = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return DefaultTabController(
       length: 2,
       child: AlertDialog(
           backgroundColor: const Color(0xFF1E293B),
           title: const Text("Добавить Виртуального Игрока", style: TextStyle(color: Colors.white)),
           content: SizedBox(
               width: 400,
               height: MediaQuery.of(context).size.height * 0.9, 
               child: Column(
                   children: [
                       const TabBar(
                           tabs: [
                               Tab(text: "Вручную"),
                               Tab(text: "Из Истории"),
                           ]
                       ),
                       Expanded(
                           child: TabBarView(
                               children: [
                                   _buildManualTab(),
                                   _buildHistoryTab(),
                               ]
                           )
                       ),
                       const Divider(color: Colors.white24),
                       // Number Picker
                       const Padding(
                         padding: EdgeInsets.only(top: 8, bottom: 4),
                         child: Text("Выберите номер игрока:", style: TextStyle(color: Colors.white70)),
                       ),
                       Column(
                         children: [
                           // Row 1: 1-5
                           Row(
                             mainAxisAlignment: MainAxisAlignment.center,
                             children: List.generate(5, (index) {
                               final num = index + 1;
                               final isTaken = widget.occupiedNumbers.contains(num);
                               final isSelected = _selectedNumber == num;
                               return Padding(
                                 padding: const EdgeInsets.symmetric(horizontal: 4),
                                 child: ChoiceChip(
                                   label: Text(num.toString()),
                                   selected: isSelected,
                                   onSelected: isTaken ? null : (selected) {
                                     if (selected) setState(() => _selectedNumber = num);
                                   },
                                   selectedColor: Colors.blueAccent,
                                   disabledColor: Colors.grey[800],
                                   backgroundColor: Colors.grey[700],
                                   labelStyle: TextStyle(
                                     color: isSelected ? Colors.white : (isTaken ? Colors.white30 : Colors.white70)
                                   ),
                                 ),
                               );
                             }),
                           ),
                           const SizedBox(height: 8),
                           // Row 2: 6-10
                           Row(
                             mainAxisAlignment: MainAxisAlignment.center,
                             children: List.generate(5, (index) {
                               final num = index + 6;
                               final isTaken = widget.occupiedNumbers.contains(num);
                               final isSelected = _selectedNumber == num;
                               return Padding(
                                 padding: const EdgeInsets.symmetric(horizontal: 4),
                                 child: ChoiceChip(
                                   label: Text(num.toString()),
                                   selected: isSelected,
                                   onSelected: isTaken ? null : (selected) {
                                     if (selected) setState(() => _selectedNumber = num);
                                   },
                                   selectedColor: Colors.blueAccent,
                                   disabledColor: Colors.grey[800],
                                   backgroundColor: Colors.grey[700],
                                   labelStyle: TextStyle(
                                     color: isSelected ? Colors.white : (isTaken ? Colors.white30 : Colors.white70)
                                   ),
                                 ),
                               );
                             }),
                           ),
                         ],
                       )
                   ]
               )
           )
       ),
    );
  }

  Widget _buildManualTab() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
           TextField(
               controller: _nameCtrl,
               style: const TextStyle(color: Colors.white),
               decoration: const InputDecoration(
                  labelText: "Имя игрока", 
                  labelStyle: TextStyle(color: Colors.white70),
                  prefixIcon: Icon(Icons.person, color: Colors.white54)
               ),
           ),
           const SizedBox(height: 16),
           TextField(
               controller: _dateCtrl,
               style: const TextStyle(color: Colors.white),
               decoration: const InputDecoration(
                  labelText: "Дата рождения (ДД.ММ.ГГГГ)", 
                  labelStyle: TextStyle(color: Colors.white70),
                  hintText: "15.04.1990",
                  hintStyle: TextStyle(color: Colors.white30),
                  prefixIcon: Icon(Icons.calendar_today, color: Colors.white54)
               ),
               keyboardType: TextInputType.datetime,
           ),
           const SizedBox(height: 16),
           Row(
             children: [
               const Text("Пол: ", style: TextStyle(color: Colors.white70)),
               const SizedBox(width: 16),
               ChoiceChip(
                 label: const Text("Мужской"),
                 selected: _gender == 'М',
                 onSelected: (s) => setState(() => _gender = 'М'),
               ),
               const SizedBox(width: 8),
               ChoiceChip(
                 label: const Text("Женский"),
                 selected: _gender == 'Ж',
                 onSelected: (s) => setState(() => _gender = 'Ж'),
               ),
             ],
           ),
           const SizedBox(height: 24),
           ElevatedButton(
               style: ElevatedButton.styleFrom(
                 backgroundColor: Colors.blueAccent,
                 minimumSize: const Size(double.infinity, 44)
               ),
               onPressed: () async {
                   if (_nameCtrl.text.isEmpty) {
                      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Введите имя")));
                      return;
                   }
                   if (_selectedNumber == null) {
                      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Выберите номер игрока")));
                      return;
                   }
                   
                   List<int> numbers = [];
                   if (_dateCtrl.text.isNotEmpty) {
                      // Validate Date
                      final regex = RegExp(r'^\d{2}\.\d{2}\.\d{4}$');
                      if (!regex.hasMatch(_dateCtrl.text)) {
                         ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Формат даты: ДД.ММ.ГГГГ")));
                         return;
                      }
                      
                      try {
                        numbers = CalculatorService.calculateDiagnostic(_dateCtrl.text, _nameCtrl.text, _gender);
                        // Optional: Save to Firestore if desired, but user focused on loading FROM history.
                        // We will allow adding strictly as virtual player for this game session.
                      } catch (e) {
                        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text("Ошибка расчета: $e")));
                        return;
                      }
                   }
                   
                   if (mounted) {
                      Navigator.pop(context, {
                        'name': _nameCtrl.text, 
                        'numbers': numbers,
                        'playerNumber': _selectedNumber
                      });
                   }
               },
               child: const Text("Создать и Добавить")
           )
        ],
      ),
    );
  }

  Widget _buildHistoryTab() {
     if (_isLoadingHistory) {
         return const Center(child: CircularProgressIndicator());
     }
  
     // Filtered list based on Current Folder
     List<Calculation> currentList = [];
     if (_currentFolder != null) {
         currentList = _allCalculations.where((c) => c.group == _currentFolder).toList();
     } else {
         // In root, we show items with NO group
         currentList = _allCalculations.where((c) => c.group == null || c.group!.isEmpty).toList();
     }

     // If folder selected -> Show Header + Items
     // If no folder -> Show Folders + Root Items
     
     return Column(
        children: [
           // Header / Breadcrumb
           Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
              color: Colors.white10,
              child: Row(
                  children: [
                     if (_currentFolder != null) ...[
                        IconButton(
                           icon: const Icon(Icons.arrow_back, color: Colors.white, size: 20),
                           onPressed: () => setState(() => _currentFolder = null),
                           padding: EdgeInsets.zero,
                           constraints: const BoxConstraints(),
                        ),
                        const SizedBox(width: 8),
                        Icon(Icons.folder_open, color: Colors.orange[300], size: 20),
                        const SizedBox(width: 8),
                        Expanded(child: Text(_currentFolder!, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold))),
                     ] else ...[
                        const Icon(Icons.history, color: Colors.grey, size: 20),
                        const SizedBox(width: 8),
                        const Expanded(child: Text("История диагностик", style: TextStyle(color: Colors.white70))),
                     ],
                     
                     IconButton(
                       icon: const Icon(Icons.refresh, color: Colors.white54, size: 20),
                       onPressed: _loadHistory
                     )
                  ],
              ),
           ),
           
           Expanded(
              child: ListView(
                 padding: const EdgeInsets.all(8),
                 children: [
                    // FOLDERS (Only at root)
                    if (_currentFolder == null)
                       ..._folders.map((f) => Card(
                          color: Colors.white10,
                          margin: const EdgeInsets.only(bottom: 4),
                          child: ListTile(
                             dense: true,
                             leading: const Icon(Icons.folder, color: Colors.orange),
                             title: Text(f, style: const TextStyle(color: Colors.white)),
                             trailing: const Icon(Icons.chevron_right, color: Colors.white54),
                             onTap: () => setState(() => _currentFolder = f),
                          ),
                       )),
                    
                    if (_currentFolder == null && _folders.isNotEmpty)
                        const Divider(color: Colors.white24, height: 16),

                    // ITEMS
                    if (currentList.isEmpty)
                        const Padding(
                           padding: EdgeInsets.all(16), 
                           child: Center(child: Text("Пусто", style: TextStyle(color: Colors.white30)))
                        ),

                    ...currentList.map((c) => Card(
                       color: Colors.white12,
                       margin: const EdgeInsets.only(bottom: 4),
                       child: ListTile(
                          dense: true,
                          leading: Icon(
                              (c.gender=='Ж' || c.gender=='F') ? Icons.female : Icons.male, 
                              color: (c.gender=='Ж' || c.gender=='F') ? Colors.pinkAccent : Colors.blueAccent
                          ),
                          title: Text(c.name, style: const TextStyle(color: Colors.white)),
                          subtitle: Text(c.birthDate, style: const TextStyle(color: Colors.white38)),
                          trailing: const Icon(Icons.add_circle_outline, color: Colors.greenAccent),
                          onTap: () {
                             if (_selectedNumber == null) {
                               ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Выберите номер игрока!")));
                               return;
                             }
                             Navigator.pop(context, {
                               'name': c.name, 
                               'numbers': c.numbers,
                               'playerNumber': _selectedNumber
                             });
                          },
                       ),
                    ))
                 ],
              ),
           )
        ],
     );
  }
}

class _SituationSearchDialog extends StatefulWidget {
  final List<Map<String, dynamic>> situations;
  final Function(Map<String, dynamic>) onSelect;

  const _SituationSearchDialog({super.key, required this.situations, required this.onSelect});

  @override
  State<_SituationSearchDialog> createState() => _SituationSearchDialogState();
}

class _SituationSearchDialogState extends State<_SituationSearchDialog> {
  final TextEditingController _searchCtrl = TextEditingController();
  List<Map<String, dynamic>> _filtered = [];

  @override
  void initState() {
    super.initState();
    _filtered = widget.situations;
  }

  void _filter(String query) {
    setState(() {
      if (query.isEmpty) {
        _filtered = widget.situations;
      } else {
        final q = query.toLowerCase();
        _filtered = widget.situations.where((s) {
           final text = (s['text'] as String? ?? '').toLowerCase();
           final id = (s['id'].toString()).toLowerCase(); // Ensure ID is string
           return text.contains(q) || id.contains(q);
        }).toList();
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      backgroundColor: const Color(0xFF1E293B),
      title: const Text("Поиск ситуации", style: TextStyle(color: Colors.white)),
      content: SizedBox(
        width: 400,
        height: 500,
        child: Column(
          children: [
             TextField(
               controller: _searchCtrl,
               onChanged: _filter,
               style: const TextStyle(color: Colors.white),
               decoration: InputDecoration(
                 hintText: "Введите текст или номер...",
                 hintStyle: const TextStyle(color: Colors.white54),
                 filled: true,
                 fillColor: Colors.white10,
                 prefixIcon: const Icon(Icons.search, color: Colors.white54),
                 border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
               ),
             ),
             const SizedBox(height: 12),
             Expanded(
               child: ListView.separated(
                 itemCount: _filtered.length,
                 separatorBuilder: (c, i) => const Divider(color: Colors.white12),
                 itemBuilder: (context, index) {
                    final item = _filtered[index];
                    return ListTile(
                       title: Text(item['text'] ?? '---', style: const TextStyle(color: Colors.white, fontSize: 13), maxLines: 3, overflow: TextOverflow.ellipsis),
                       leading: CircleAvatar(
                          backgroundColor: Colors.blueAccent,
                          radius: 12,
                          child: Text("${item['id'] ?? '?'}", style: const TextStyle(fontSize: 10, color: Colors.white)),
                       ),
                       onTap: () {
                          widget.onSelect(item);
                          Navigator.pop(context);
                       },
                    );
                 },
               ),
             )
          ],
        ),
      ),
      actions: [
        TextButton(onPressed: () => Navigator.pop(context), child: const Text("Отмена"))
      ],
    );
  }
}

