import 'dart:async';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart' show debugPrint;
import '../models/calculation.dart';
import '../models/promo_code.dart';
import '../models/festival_game.dart';
import 'n8n_service.dart';

class FirestoreService {
  final FirebaseFirestore _db = FirebaseFirestore.instance;
  final FirebaseAuth _auth = FirebaseAuth.instance;

  // --- Users & Profiles ---

  Future<void> saveUser(User user, Map<String, dynamic> additionalData) async {
    final docRef = _db.collection('users').doc(user.uid);
    await docRef.set({
      'email': user.email,
      'createdAt': FieldValue.serverTimestamp(),
      'role': 'user', // Default role
      'credits': 5, // Welcome bonus
      ...additionalData,
    }, SetOptions(merge: true));
  }

  Future<void> updateUserProfile(String uid, {String? firstName, String? phoneNumber, DateTime? birthDate}) async {
    final Map<String, dynamic> data = {};
    if (firstName != null) data['first_name'] = firstName;
    if (phoneNumber != null) data['phoneNumber'] = phoneNumber; // Consistent naming
    if (birthDate != null) data['birthDate'] = Timestamp.fromDate(birthDate);
    
    if (data.isNotEmpty) {
      await _db.collection('users').doc(uid).update(data);
    }
  }

  Stream<DocumentSnapshot<Map<String, dynamic>>> getUserData() {
    final user = _auth.currentUser;
    if (user == null) return const Stream.empty();
    return _db.collection('users').doc(user.uid).snapshots();
  }

  Future<bool> isTester() async {
    final user = _auth.currentUser;
    if (user == null) return false;
    try {
      final doc = await _db.collection('users').doc(user.uid).get();
      final data = doc.data();
      if (data != null && data['tester'] == 1) {
        return true;
      }
    } catch (e) {
      debugPrint("Error checking tester status: $e");
    }
    return false;
  }

  // --- Calculations ---

  Future<String> saveCalculation(Calculation calc) async {
    final user = _auth.currentUser;
    if (user == null) throw Exception("User not logged in");

    final docRef = await _db
        .collection('users')
        .doc(user.uid)
        .collection('calculations')
        .add(calc.toMap());
        
    return docRef.id;
  }
  
  Future<void> updateCalculation(String id, Calculation calc) async {
      final user = _auth.currentUser;
      if (user == null) return;
      
      await _db
        .collection('users')
        .doc(user.uid)
        .collection('calculations')
        .doc(id)
        .update(calc.toMap());
  }
  
  // Game Profile (Single active profile for the game context)
  Future<void> saveGameProfile(Calculation calc) async {
    final user = _auth.currentUser;
    if (user == null) throw Exception("User not logged in");
    
    // Save as a specific document 'current_game_profile' or similar, 
    // or just use the local state. For persistance across reloads:
    await _db.collection('users').doc(user.uid).update({
      'game_profile': calc.toMap(),
    });
  }

  Future<Calculation?> getGameProfile() async {
    final user = _auth.currentUser;
    if (user == null) return null;
    
    final doc = await _db.collection('users').doc(user.uid).get();
    if (doc.exists && doc.data()!.containsKey('game_profile')) {
      return Calculation.fromMap(doc.data()!['game_profile']);
    }
    return null;
  }

  Stream<QuerySnapshot<Map<String, dynamic>>> getCalculationsStream() {
    final user = _auth.currentUser;
    if (user == null) return const Stream.empty();
    
    return _db
        .collection('users')
        .doc(user.uid)
        .collection('calculations')
        .orderBy('createdAt', descending: true)
        .snapshots();
  }

  Future<void> deleteCalculation(String docId) async {
     final user = _auth.currentUser;
    if (user == null) throw Exception("User not logged in");
    
    await _db
        .collection('users')
        .doc(user.uid)
        .collection('calculations')
        .doc(docId)
        .delete();
  }

  Future<List<Map<String, dynamic>>> getCalculationsRaw() async {
    final user = _auth.currentUser;
    if (user == null) return [];
    
    final query = await _db
        .collection('users')
        .doc(user.uid)
        .collection('calculations')
        .orderBy('createdAt', descending: true)
        .get();
        
    return query.docs.map((d) {
      final data = d.data();
      data['id'] = d.id; // Inject ID
      return data;
    }).toList();
  }

  Future<Map<String, dynamic>?> getLatestCalculation() async {
    final user = _auth.currentUser;
    if (user == null) return null;
    
    final query = await _db
        .collection('users')
        .doc(user.uid)
        .collection('calculations')
        .orderBy('createdAt', descending: true)
        .limit(1)
        .get();
        
    if (query.docs.isEmpty) return null;
    return query.docs.first.data();
  }

  Future<void> updateGroup(String calculationId, String? groupName) async {
      final user = _auth.currentUser;
      if (user == null) return;
      
      await _db
        .collection('users')
        .doc(user.uid)
        .collection('calculations')
        .doc(calculationId)
        .update({'group': groupName}); // 'group' field in Model
  }

  // --- Credits & Payments ---

  Future<bool> consumeCredits(int amount) async {
    final user = _auth.currentUser;
    if (user == null) return false;

    final docRef = _db.collection('users').doc(user.uid);
    final result = await _db.runTransaction((transaction) async {
      final snapshot = await transaction.get(docRef);
      if (!snapshot.exists) return false;

      final currentCredits = snapshot.data()?['credits'] ?? 0;
      if (currentCredits >= amount) {
        transaction.update(docRef, {'credits': currentCredits - amount});
        return true;
      } else {
        return false;
      }
    });

    return result;
  }
  
  // --- Admin/Support Requests ---
  
  Future<void> createRequest({required String type, String? text, int? value}) async {
    final user = _auth.currentUser;
    if (user == null) return;
    
    final userDoc = await _db.collection('users').doc(user.uid).get();
    final userData = userDoc.data()!;
    
    await _db.collection('requests').add({
      'userId': user.uid,
      'userName': userData['first_name'] ?? 'Unknown',
      'userContact': userData['username'], // Telegram username often stored here
      'type': type, // 'deposit', 'question', 'upgrade'
      'text': text,
      'value': value,
      'status': 'pending',
      'createdAt': FieldValue.serverTimestamp(),
    });

    // Notify N8n
    try {
      await N8nService().sendSupportRequest(
        userId: user.uid,
        userName: userData['first_name'] ?? 'Unknown',
        contact: userData['username'] ?? user.email ?? 'Unknown',
        type: type,
        text: text,
      );
    } catch (e) {
      debugPrint("Error notifying N8n: $e");
    }
  }
  
  Stream<QuerySnapshot<Map<String, dynamic>>> getPendingRequests() {
    return _db.collection('requests')
      .where('status', isEqualTo: 'pending')
      .orderBy('createdAt', descending: true)
      .snapshots();
  }
  
  Stream<QuerySnapshot<Map<String, dynamic>>> getUserRequests() {
    final user = _auth.currentUser;
    if (user == null) return const Stream.empty();

    return _db.collection('requests')
      .where('userId', isEqualTo: user.uid)
      .orderBy('createdAt', descending: true)
      .snapshots();
  }
  
  Future<void> processRequest(String requestId, String userId, String action, int? value) async {
    final requestRef = _db.collection('requests').doc(requestId);
    final userRef = _db.collection('users').doc(userId);
    
    await _db.runTransaction((transaction) async {
      final requestDoc = await transaction.get(requestRef);
      if (!requestDoc.exists) throw Exception("Request not found");

      if (action == 'approve_deposit' || action == 'approve_bonus' || action == 'approve_subscription' || action == 'approve_credits') {
         transaction.update(userRef, {'credits': FieldValue.increment(value ?? 0)});
         transaction.update(requestRef, {'status': 'completed', 'answer': 'Approved +$value credits'});
      } else if (action == 'approve_upgrade') {
         transaction.update(userRef, {'pgmd': 2}); // Example logic
         transaction.update(requestRef, {'status': 'completed', 'answer': 'Level Upgraded'});
      } else if (action == 'manual_close') {
         transaction.update(requestRef, {'status': 'closed'});
      } else if (action == 'reply_question') {
         // Handled separately usually, but here for status
      }
    });
  }
  
  Future<void> answerRequest(String requestId, String answer) async {
    await _db.collection('requests').doc(requestId).update({
      'status': 'answered',
      'answer': answer,
    });
  }

  // Helper alias for compatibility
  Future<bool> consumeCredit(int amount) => consumeCredits(amount);

  Future<void> setCalculationPaid(String calculationId) async {
      final user = _auth.currentUser;
      if (user == null) return;
      
      await _db
        .collection('users')
        .doc(user.uid)
        .collection('calculations')
        .doc(calculationId)
        .update({'isPaid': true});
  }

  // --- Game Host Features ---

  Future<void> toggleHostMode(bool isHostMode) async {
    final user = _auth.currentUser;
    if (user == null) return;
    await _db.collection('users').doc(user.uid).update({
      'isHostMode': isHostMode
    });
  }

  // --- Game Stage & Voting ---

  Future<void> updateGameStage(String gameId, String stage) async {
      // stage: 'selection', 'voting'
      await _db.collection('games').doc(gameId).update({
          'stage': stage
      });
  }

  Future<void> endRound(String gameId) async {
      final gameRef = _db.collection('games').doc(gameId);
      
      // Fetch Game Doc first to get Situation and Stats
      final gameDoc = await gameRef.get();
      final gameData = gameDoc.data() ?? {};
      final String situationText = (gameData['situation'] as Map?)?['text'] ?? "Контекст не сохранен";
      final int currentRoundCount = (gameData['roundCount'] ?? 0) + 1; // Increment for new round
      final Map<String, dynamic> currentStats = Map<String, dynamic>.from(gameData['stats'] ?? {});

      final participants = await gameRef.collection('participants').get();
      final batch = _db.batch();

      // 1. Calculate votes for this round
      Map<String, int> roundVotes = {};
      for (var doc in participants.docs) {
          final data = doc.data();
          final votedFor = data['votedFor'];
          if (votedFor != null) {
              roundVotes[votedFor] = (roundVotes[votedFor] ?? 0) + 1;
          }
      }

      // 2. Prepare Round Actions Data
      List<Map<String, dynamic>> actions = [];

      roundVotes.forEach((uid, voteCount) {
          currentStats[uid] = (currentStats[uid] ?? 0) + voteCount;
      });

      for (var doc in participants.docs) {
          final data = doc.data();
          final uid = doc.id;
          final receivedVotes = roundVotes[uid] ?? 0;
          final role = data['selectedRole'];
          final answer = data['currentAnswer'];
          final votedFor = data['votedFor'];
          final name = data['name'] ?? 'Unknown';
          final pNum = data['playerNumber'];

          // Add to centralized actions list
          if (role != null || answer != null || votedFor != null) {
              actions.add({
                  'userId': uid,
                  'name': name,
                  'playerNumber': pNum,
                  'role': role,
                  'answer': answer,
                  'votedFor': votedFor,
                  'receivedVotes': receivedVotes
              });
          }

          // Save History for User (Legacy individual history)
          if (role != null || answer != null) {
             final historyRef = _db.collection('users').doc(uid).collection('game_history').doc(gameId).collection('rounds').doc();
             batch.set(historyRef, {
                 'situation': situationText,
                 'answer': answer, 
                 'role': role,
                 'votes': receivedVotes,
                 'timestamp': FieldValue.serverTimestamp(),
                 'roundIndex': currentRoundCount
             });
          }

          // Reset Participant
          batch.update(doc.reference, {
              'selectedRole': FieldValue.delete(),
              'votedFor': FieldValue.delete(),
              'votes': [], 
              'currentAnswer': FieldValue.delete(),
          });
      }
      
      // 3. Save Centralized Round Document
      if (actions.isNotEmpty) {
         final roundRef = gameRef.collection('rounds').doc(currentRoundCount.toString());
         batch.set(roundRef, {
             'roundIndex': currentRoundCount,
             'situation': situationText,
             'actions': actions,
             'timestamp': FieldValue.serverTimestamp(),
         });
      }

      // 4. Update Game State
      batch.update(gameRef, {
          'stats': currentStats,
          'stage': 'selection',
          'roundCount': currentRoundCount 
      });

      await batch.commit();
  }

  Future<void> finishGame(String gameId) async {
      await _db.collection('games').doc(gameId).update({
          'status': 'finished'
      });
      // Trigger n8n report
      _triggerN8nReport(gameId);
      
      // Optionally record history immediately or wait for "End Session"
      await recordGameHistory(gameId);
  }

  Future<void> _triggerN8nReport(String gameId) async {
     try {
        final gameDoc = await _db.collection('games').doc(gameId).get();
        final data = gameDoc.data();
        if (data == null) return;
        
        final zoomId = data['zoomId'];
        if (zoomId == null || zoomId.isEmpty) return; // No zoom, no report
        
        final participants = await _db.collection('games').doc(gameId).collection('participants').get();
        final names = participants.docs.map((d) => d.data()['name'] as String? ?? 'Unknown').toList();
        
        await N8nService().triggerGameReport(
           gameId: gameId, 
           meetingId: zoomId, 
           playerNames: names, 
           date: data['scheduledAt'] ?? DateTime.now().toIso8601String()
        );
     } catch (e) {
        debugPrint("Error triggering n8n: $e");
     }
  }

  Future<void> recordGameHistory(String gameId) async {
    final gameDoc = await _db.collection('games').doc(gameId).get();
    final stats = Map<String, dynamic>.from(gameDoc.data()?['stats'] ?? {});
    final title = gameDoc.data()?['title'] ?? 'Игра без названия';
    final date = gameDoc.data()?['scheduledAt'] ?? DateTime.now().toIso8601String();

    if (stats.isEmpty) return;

    // Sort to determine ranks
    final sorted = stats.entries.toList()
      ..sort((a, b) => (b.value as int).compareTo(a.value as int));

    final batch = _db.batch();
    for (int i = 0; i < sorted.length; i++) {
      final uid = sorted[i].key;
      final score = sorted[i].value as int;
      final rank = i + 1;

      final historyRef = _db.collection('users').doc(uid).collection('game_history').doc(gameId);
      batch.set(historyRef, {
        'gameId': gameId,
        'gameTitle': title,
        'date': date,
        'score': score,
        'rank': rank,
        'totalParticipants': sorted.length,
        'timestamp': FieldValue.serverTimestamp(),
      });
    }
    await batch.commit();
  }

  Future<void> archiveGame(String gameId) async {
      await _db.collection('games').doc(gameId).update({
          'status': 'archived'
      });
      // Ensure report is triggered if not already
      _triggerN8nReport(gameId);
  }

  Future<void> voteForPlayer(String gameId, String targetUserId, [String? voterId]) async {
      final user = _auth.currentUser;
      if (user == null) return;
      
      final uid = voterId ?? user.uid;
      
      // 1. Mark who the voter voted for (to display on host dashboard & count totals)
      final voterRef = _db.collection('games').doc(gameId).collection('participants').doc(uid);
      await voterRef.update({
          'votedFor': targetUserId
      });
  }

  Future<void> clearVote(String gameId, [String? voterId]) async {
      final user = _auth.currentUser;
      if (user == null) return;
      
      final uid = voterId ?? user.uid;
      
      final voterRef = _db.collection('games').doc(gameId).collection('participants').doc(uid);
      
      await voterRef.update({
          'votedFor': FieldValue.delete()
      });
  }

  Future<void> removeParticipant(String gameId, String userId) async {
    try {
      // Remove from sub-collection
      await _db
          .collection('games')
          .doc(gameId)
          .collection('participants')
          .doc(userId)
          .delete();
    } catch (e) {
      debugPrint("Error removing participant: $e");
      rethrow;
    }
  }

  Stream<DocumentSnapshot<Map<String, dynamic>>> getGameStream(String gameId) {
      return _db.collection('games').doc(gameId).snapshots();
  }

  Future<String> createGame({
      required String title, 
      required DateTime date, 
      String? zoomId, 
      String? zoomPassword,
      String? situationPackId,
      List<String>? situationCategories,
      bool? isTestGame,
      String gameType = 'territory',
      bool isOffline = false,
      int maxPlayers = 10,
  }) async {
    final user = _auth.currentUser;
    if (user == null) throw Exception("User not logged in");
    
    // Check constraints (Admin only)
    final userDoc = await _db.collection('users').doc(user.uid).get();
    final role = userDoc.data()?['role'];
    final pgmd = userDoc.data()?['pgmd'];
    
    // Attempt to get name from multiple sources
    String userName = userDoc.data()?['first_name'] ?? "";
    if (userName.isEmpty) {
       final gameProfile = userDoc.data()?['gameProfile'];
       if (gameProfile != null && gameProfile['name'] != null) {
          userName = gameProfile['name'];
       }
    }
    if (userName.isEmpty) userName = 'Ведущий';
    
    // Level 10 (Diagnost-Host) and above can create games
    if (role != 'admin' && (pgmd == null || pgmd < 10)) {
      throw Exception("Unauthorized");
    }

    final docRef = await _db.collection('games').add({
      'hostId': user.uid,
      'hostName': userName,
      'title': title,
      'gameType': gameType, // Storing game type
      'maxPlayers': maxPlayers,
      'scheduledAt': date.toIso8601String(),
      'zoomId': zoomId,
      'zoomPassword': zoomPassword,
      'situationPackId': situationPackId,
      'situationCategories': situationCategories,
      'isTestGame': isTestGame,
      'isOffline': isOffline,
      'status': 'scheduled',
      'stage': 'selection', // Default stage
      'createdAt': FieldValue.serverTimestamp(),
      if (gameType == 'mafia')
        'mafiaState': {
           'phase': 'lobby',
           'turn': 0,
           'isDay': true,
           'roles': {}, // UID -> Role
           'alivePlayers': [], // List of UIDs
        }
    });
    
    return docRef.id;
  }
  
  Future<void> updateGame(String gameId, {
      required String title, 
      required DateTime date, 
      String? zoomId, 
      String? zoomPassword,
      String? situationPackId,
      List<String>? situationCategories,
      bool? isTestGame,
      String? gameType,
      bool? isOffline,
      int? maxPlayers,
  }) async {
    final Map<String, dynamic> data = {
      'title': title,
      'scheduledAt': date.toIso8601String(),
      'zoomId': zoomId,
      'zoomPassword': zoomPassword,
    };
    if (maxPlayers != null) data['maxPlayers'] = maxPlayers;

    if (gameType != null) data['gameType'] = gameType;

    if (situationPackId != null) data['situationPackId'] = situationPackId;
    if (situationCategories != null) data['situationCategories'] = situationCategories;
    if (isTestGame != null) data['isTestGame'] = isTestGame;
    if (isOffline != null) data['isOffline'] = isOffline;
    
    await _db.collection('games').doc(gameId).update(data);
  }
  
  Future<void> deleteGame(String gameId) async {
    await _db.collection('games').doc(gameId).delete();
  }

  Stream<QuerySnapshot<Map<String, dynamic>>> getGamesStream() {
    return _db.collection('games')
        .where('status', whereIn: ['scheduled', 'active'])
        .snapshots();
  }
  
  Future<QueryDocumentSnapshot<Map<String, dynamic>>?> getNearestGame() async {
    final snapshot = await _db.collection('games')
        .where('status', whereIn: ['scheduled', 'active'])
        .get();
        
    if (snapshot.docs.isNotEmpty) {
      final docs = snapshot.docs;
      docs.sort((a,b) {
         final dA = a.data()['scheduledAt'] ?? '';
         final dB = b.data()['scheduledAt'] ?? '';
         return dA.compareTo(dB);
      });
      return docs.first;
    }
        
    if (snapshot.docs.isNotEmpty) {
      return snapshot.docs.first;
    }
    return null;
  }

  // --- Situation Management ---

  Future<void> updateSituation(String gameId, Map<String, dynamic> data) async {
      final updateData = data.map((key, value) => MapEntry('situation.$key', value));
      await _db.collection('games').doc(gameId).update(updateData);
  }

  Future<void> setSituationVisible(String gameId, bool isVisible) async {
      await _db.collection('games').doc(gameId).update({
          'situation.isVisible': isVisible
      });
  }
  
  Future<void> setSituationText(String gameId, String text) async {
      await _db.collection('games').doc(gameId).update({
          'situation.text': text
      });
  }

  Future<void> setSituationController(String gameId, String? userId) async {
      // null userId means only Host controls
      await _db.collection('games').doc(gameId).update({
          'situation.controllerId': userId
      });
  }

  // --- SITUATION PACKS & MIGRATION ---

  Future<void> createSituationPack(String title, String description, List<Map<String, dynamic>> situations) async {
    await _db.collection('situation_packs').add({
      'title': title,
      'description': description,
      'situations': situations, // [{text: "...", category: "...", id: 1}]
      'createdAt': FieldValue.serverTimestamp(),
      'isPublic': true,
    });
  }

  Future<List<QueryDocumentSnapshot<Map<String, dynamic>>>> getSituationPacks() async {
    // Fetch all and sort in memory to avoid Index requirements
    final snapshot = await _db.collection('situation_packs').get();
    
    // Fetch all for admin/host visibility
    // final docs = snapshot.docs.where((d) => d.data()['isPublic'] == true).toList();
    final docs = snapshot.docs;
    
    docs.sort((a, b) {
       final tA = (a.data()['createdAt'] as Timestamp?)?.toDate() ?? DateTime(2000);
       final tB = (b.data()['createdAt'] as Timestamp?)?.toDate() ?? DateTime(2000);
       return tB.compareTo(tA); // Descending
    });
    
    return docs;
  }

  Future<DocumentSnapshot<Map<String, dynamic>>> getSituationPack(String packId) async {
    return await _db.collection('situation_packs').doc(packId).get();
  }
  
  // Method to parse the specific text format and upload
  Future<void> parseAndUploadSituations2026(String rawText) async {
    final List<String> lines = rawText.split('\n');
    List<Map<String, dynamic>> situations = [];
    String currentCategory = "General";
    
    for (String line in lines) {
      line = line.trim();
      if (line.isEmpty) continue;
      
      if (line.startsWith("Категория:")) {
         currentCategory = line.replaceAll("Категория:", "").trim();
      } else if (RegExp(r'^\d+\.').hasMatch(line)) {
         // "1. Text..."
         final parts = line.split('.'); // Split by first dot
         if (parts.length > 1) {
            int? id = int.tryParse(parts[0]);
            String text = parts.sublist(1).join('.').trim(); // Rejoin rest
            if (id != null) {
               situations.add({
                  'id': id,
                  'text': text,
                  'category': currentCategory
               });
            }
         }
      }
    }
    
    if (situations.isNotEmpty) {
       await createSituationPack("Ситуации 2026", "Базовый набор ситуаций для онлайн игр.", situations);
    }
  }

  // --- Game Participation & Roles ---
  
  Future<void> joinGameRequest({
      required String gameId, 
      required String gameTitle, 
      required String gameDate, 
      required String userName, 
      String? telegram, 
      String? email, 
      required List<int> numbers
  }) async {
     final user = _auth.currentUser;
     if (user == null) return;
     
     await _db.collection('games').doc(gameId).collection('participants').doc(user.uid).set({
       'userId': user.uid,
       'name': userName,
       'telegram': telegram,
       'email': email, // Save Email
       'numbers': numbers, // Save Diagnostic numbers
       'status': 'pending', // pending, approved
       'playerNumber': null, // 1-8
       'selectedRole': null,
       'updatedAt': FieldValue.serverTimestamp(),
       'votes': [],
     }, SetOptions(merge: true));

     // Notify Admin via N8n
     await N8nService().sendGameApplication(
       gameTitle: gameTitle,
       clientName: userName,
       contact: telegram ?? email ?? "Не указан",
       time: gameDate,
     );
  }

  Future<void> updateParticipantAnswer(String gameId, String answer) async {
     final user = _auth.currentUser;
     if (user == null) return;
     await _db.collection('games').doc(gameId).collection('participants').doc(user.uid).update({
        'currentAnswer': answer
     });
  }

  Future<void> approveParticipant(String gameId, String userId) async {
    await _db.collection('games').doc(gameId).collection('participants').doc(userId).update({
      'status': 'approved'
    });
  }

  Future<void> rejectParticipant(String gameId, String userId) async {
    await _db.collection('games').doc(gameId).collection('participants').doc(userId).update({
      'status': 'rejected'
    });
  }

  // --- Promo Codes ---

  Stream<List<PromoCode>> getPromoCodesStream() {
    return _db.collection('promo_codes').snapshots().map((snapshot) {
      return snapshot.docs.map((doc) {
        return PromoCode.fromMap(doc.data(), doc.id);
      }).toList();
    });
  }

  Future<void> savePromoCode(PromoCode promo) async {
    if (promo.id != null) {
      await _db.collection('promo_codes').doc(promo.id).update(promo.toMap());
    } else {
      await _db.collection('promo_codes').add(promo.toMap());
    }
  }

  Future<void> deletePromoCode(String id) async {
    await _db.collection('promo_codes').doc(id).delete();
  }

  Future<List<PromoCode>> getValidPromoCodes(String code) async {
    // Check if user is logged in, if not try anonymous auth
    if (_auth.currentUser == null) {
       try {
          debugPrint("User not logged in, attempting anonymous auth for promo check...");
          await _auth.signInAnonymously();
       } catch (e) {
          debugPrint("Anonymous auth failed: $e");
          // Continue anyway, maybe rules are public
       }
    }

    final query = await _db.collection('promo_codes')
      .where('code', isEqualTo: code)
      .get();
      
    return query.docs
        .map((doc) => PromoCode.fromMap(doc.data(), doc.id))
        .where((p) => p.isActive)
        .toList();
  }
  
  Future<void> setPlayerNumber(String gameId, int number) async {
     final user = _auth.currentUser;
     if (user == null) return;
     
     // Optional: Check if number is taken logic could be here or UI side.
     // For now just set it.
     await _db.collection('games').doc(gameId).collection('participants').doc(user.uid).update({
         'playerNumber': number
     });
  }
  
  Future<void> saveFestivalApplication({
    required String name,
    required String phone,
    required String promo,
    required String type,
    num? finalPrice,
    num? discount,
  }) async {
    final user = _auth.currentUser;
    await _db.collection('festival_applications').add({
      'userId': user?.uid, // nullable
      'name': name,
      'phone': phone,
      'promo': promo,
      'type': type,
      'finalPrice': finalPrice,
      'discount': discount,
      'createdAt': FieldValue.serverTimestamp(),
      'status': 'new',
    });
    
    // N8n trigger
    try {
      await N8nService().sendFestivalApplication(
        name: name,
        phone: phone,
        promo: promo,
        type: type,
      );
    } catch (e) {
      debugPrint("N8n Festival Error: $e");
    }
  }



  // --- Festival Admin ---

  Stream<QuerySnapshot<Map<String, dynamic>>> getFestivalApplicationsStream() {
    // Only fetch if admin (checked by specific UI or rules, but for client side simplicity we just return stream)
    // Security rules should enforce read access.
    return _db.collection('festival_applications')
        .orderBy('createdAt', descending: true)
        .snapshots();
  }

  Future<void> updateApplicationStatus(String docId, String newStatus) async {
    await _db.collection('festival_applications').doc(docId).update({
      'status': newStatus,
      'updatedAt': FieldValue.serverTimestamp(),
    });
  }

  Future<void> addVirtualParticipant(String gameId, String name, List<int> numbers, int? playerNumber) async {
      // Use a timestamp-based ID to avoid collisions and allow easy identification
      final String virtId = 'virt_${DateTime.now().millisecondsSinceEpoch}';

      await _db.collection('games').doc(gameId).collection('participants').doc(virtId).set({
        'userId': virtId,
        'name': name,
        'telegram': null, // Virtual players don't have telegram
        'numbers': numbers,
        'status': 'approved', // Virtual players are auto-approved
        'playerNumber': playerNumber,
        'selectedRole': null,
        'updatedAt': FieldValue.serverTimestamp(),
        'votes': [],
        'isVirtual': true, // Flag to identify virtual players
      });
  }


  



  
  Future<void> updateParticipantRole(String gameId, int? roleId, [String? targetUserId]) async {
    final user = _auth.currentUser;
    if (user == null) return;
    
    final uid = targetUserId ?? user.uid;

    if (roleId == null) {
        await _db.collection('games').doc(gameId).collection('participants').doc(uid).update({
          'selectedRole': FieldValue.delete(),
        });
    } else {
        await _db.collection('games').doc(gameId).collection('participants').doc(uid).update({
          'selectedRole': roleId,
        });
    }
  }

  Stream<QuerySnapshot<Map<String, dynamic>>> getGameParticipantsStream(String gameId) {
    return _db.collection('games').doc(gameId).collection('participants').snapshots();
  }

  // Deprecated/Legacy Answer logic (can keep if needed or remove)
  Future<void> submitGameAnswer({required String gameId, required int roleId, required String roleName, required String answer}) async {
    final user = _auth.currentUser;
    if (user == null) return;

    final userDoc = await _db.collection('users').doc(user.uid).get();
    final userName = userDoc.data()?['first_name'] ?? 'Unknown';

    await _db.collection('games').doc(gameId).collection('answers').add({
      'userId': user.uid,
      'userName': userName,
      'roleId': roleId,
      'roleName': roleName,
      'answer': answer,
      'timestamp': FieldValue.serverTimestamp(),
    });
  }
  
  Stream<QuerySnapshot<Map<String, dynamic>>> getGameAnswersStream(String gameId) {
    // Only allow admin/host ideally, but for MVP strict rules can remain in security rules
    return _db.collection('games').doc(gameId).collection('answers')
        .orderBy('timestamp', descending: true)
        .snapshots();
  }

  Stream<QuerySnapshot<Map<String, dynamic>>> getGameHistoryStream() {
    final user = _auth.currentUser;
    if (user == null) return const Stream.empty();
    return _db.collection('users').doc(user.uid).collection('game_history')
        .orderBy('timestamp', descending: true)
        .snapshots();
  }

  Stream<List<Map<String, dynamic>>> getHostGamesStream() {
    final user = _auth.currentUser;
    if (user == null) return const Stream.empty();
    
    // Fetch ALL games for this host (simpler query, no index needed)
    return _db.collection('games')
        .where('hostId', isEqualTo: user.uid)
        .snapshots()
        .map((snapshot) {
           final docs = snapshot.docs.map((d) {
              final data = d.data();
              data['id'] = d.id;
              return data;
           }).where((data) {
              final status = data['status'];
              return status == 'finished' || status == 'archived';
           }).toList();
           
           // Sort client-side
           docs.sort((a, b) {
              final tA = a['scheduledAt'] ?? '';
              final tB = b['scheduledAt'] ?? '';
              return tB.compareTo(tA); // Descending
           });
           
           return docs;
        });
  }

  // --- Training Game Mode ---

  Future<int> getDailyTrainingCount() async {
      final user = _auth.currentUser;
      if (user == null) return 2; // Fail safe

      final now = DateTime.now();
      final dateKey = "${now.year}-${now.month}-${now.day}";

      final doc = await _db.collection('users').doc(user.uid).collection('training_stats').doc(dateKey).get();
      if (!doc.exists) return 0;
      return doc.data()?['count'] ?? 0;
  }

  Future<void> saveTrainingResult(String situationText, int role, String packId, String situationId, {bool bypassLimit = false}) async {
      final user = _auth.currentUser;
      if (user == null) return;

      final now = DateTime.now();
      final dateKey = "${now.year}-${now.month}-${now.day}"; // YYYY-M-D

      // Transaction to ensure atomicity of count increment
      await _db.runTransaction((transaction) async {
          final statsRef = _db.collection('users').doc(user.uid).collection('training_stats').doc(dateKey);
          final histRef = _db.collection('users').doc(user.uid).collection('game_history').doc(); // Auto-ID

          final statsDoc = await transaction.get(statsRef);
          int currentCount = 0;
          if (statsDoc.exists) {
              currentCount = statsDoc.data()?['count'] ?? 0;
          }

          if (currentCount >= 2 && !bypassLimit) {
             throw Exception("Daily limit reached");
          }

          // 1. Increment Count
          transaction.set(statsRef, {'count': currentCount + 1, 'updatedAt': FieldValue.serverTimestamp()}, SetOptions(merge: true));

          // 2. Save History Entry
          transaction.set(histRef, {
             'gameId': 'training_$dateKey',
             'gameTitle': 'Тренировочная игра ($dateKey)',
             'date': FieldValue.serverTimestamp(),
             'hostName': 'Тренер (Бот)',
             'role': role, // 1-21
             'situation': situationText,
             'situationId': situationId,
             'isTraining': true,
             'votes': 0, // No votes in single player
             'timestamp': FieldValue.serverTimestamp(),
          });
      });
  }



  // --- Festival Games ---

  Future<void> createFestivalGame(FestivalGame game) async {
    final user = _auth.currentUser;
    if (user == null) throw Exception("User not logged in");
    
    // Check admin or master role
    final userDoc = await _db.collection('users').doc(user.uid).get();
    final role = userDoc.data()?['role'];
    
    // Allow 'admin' or 'master' (or custom check)
    if (role != 'admin' && role != 'master') {
      throw Exception("Unauthorized");
    }

    await _db.collection('festival_games').add(game.toMap());
  }

  Stream<List<FestivalGame>> getFestivalGamesStream() {
    return _db.collection('festival_games')
      .orderBy('startTime')
      .snapshots()
      .map((snapshot) => snapshot.docs
        .map((doc) => FestivalGame.fromMap(doc.data(), doc.id))
        .toList());
  }

  Future<List<FestivalGame>> getFestivalGamesOnce() async {
    final snapshot = await _db.collection('festival_games').orderBy('startTime').get();
    return snapshot.docs.map((doc) => FestivalGame.fromMap(doc.data(), doc.id)).toList();
  }

  Future<List<Map<String, dynamic>>> getFestivalMasters() async {
    final snapshot = await _db.collection('users').where('isMaster', isEqualTo: true).get();
    return snapshot.docs.map((doc) {
       final data = doc.data();
       return {
          'uid': doc.id,
          'name': "${data['first_name'] ?? ''} ${data['last_name'] ?? ''}".trim(),
          'photo': data['photo_url']
       };
    }).toList();
  }



  Future<List<Map<String, dynamic>>> getFestivalActivities() async {
    final snapshot = await _db.collection('festival_activities').get();
    return snapshot.docs.map((doc) {
       final data = doc.data();
       return {
         ...data,
         'id': doc.id,
       };
    }).toList();
  }

  Future<void> registerForFestivalGame(String gameId) async {
    final user = _auth.currentUser;
    if (user == null) throw Exception("User not logged in");

    // 1. Get Game Data
    final gameDoc = await _db.collection('festival_games').doc(gameId).get();
    if (!gameDoc.exists) throw Exception("Game not found");
    
    final game = FestivalGame.fromMap(gameDoc.data()!, gameDoc.id);

    // 2. Check if full
    if (game.placesLeft <= 0) {
      throw Exception("Мест нет");
    }

    // 3. Check if already registered
    if (game.isUserRegistered(user.uid)) {
      throw Exception("Вы уже записаны на эту игру");
    }

    // 4. Check for time overlap
    // Get all games user is registered for
    final allGamesSnapshot = await _db.collection('festival_games').get();
    final allGames = allGamesSnapshot.docs.map((d) => FestivalGame.fromMap(d.data(), d.id)).toList();
    
    for (var g in allGames) {
      if (g.isUserRegistered(user.uid)) {
         // Check overlap
         // Overlap if (StartA < EndB) and (EndA > StartB)
         if (game.startTime.isBefore(g.endTime) && game.endTime.isAfter(g.startTime)) {
            throw Exception("Пересечение по времени с игрой '${g.title}'");
         }
      }
    }

    // 5. Register
    final userDoc = await _db.collection('users').doc(user.uid).get();
    final userName = userDoc.data()?['first_name'] ?? 'Unknown';

    final participant = {
      'userId': user.uid,
      'userName': userName,
      'registeredAt': Timestamp.now(),
    };

    await _db.collection('festival_games').doc(gameId).update({
      'participants': FieldValue.arrayUnion([participant])
    });
  }

  Future<void> updateFestivalGame(FestivalGame game) async {
    final user = _auth.currentUser;
    if (user == null) throw Exception("User not logged in");
    
    // Check admin or master role
    final userDoc = await _db.collection('users').doc(user.uid).get();
    final role = userDoc.data()?['role'];
    
    if (role != 'admin' && role != 'master') {
      throw Exception("Unauthorized");
    }

    await _db.collection('festival_games').doc(game.id).update(game.toMap());
  }

  Future<void> deleteFestivalGame(String gameId) async {
    final user = _auth.currentUser;
    if (user == null) throw Exception("User not logged in");
    
    final userDoc = await _db.collection('users').doc(user.uid).get();
    final role = userDoc.data()?['role'];
    
    if (role != 'admin' && role != 'master') {
      throw Exception("Unauthorized");
    }
    
    await _db.collection('festival_games').doc(gameId).delete();
  }

  Stream<List<FestivalGame>> getFestivalMasterGames() {
     final user = _auth.currentUser;
     if (user == null) return Stream.value([]);

     return _db.collection('festival_games')
        .where('masterId', isEqualTo: user.uid)
        .orderBy('startTime')
        .snapshots()
        .map((snapshot) => snapshot.docs
          .map((doc) => FestivalGame.fromMap(doc.data(), doc.id))
          .toList());
  }




  // --- Festival Specifics ---

  Future<void> logFestivalAction({
    required String action,
    required String gameId,
    required String masterId,
    required Map<String, dynamic> details,
  }) async {
     final user = _auth.currentUser;
     await _db.collection('festival_logs').add({
        'action': action, // 'signup', 'cancel'
        'gameId': gameId,
        'masterId': masterId,
        'userId': user?.uid ?? 'anonymous',
        'details': details,
        'timestamp': FieldValue.serverTimestamp(),
        'processed': false, // For bot to pick up
     });
  }

  Future<void> joinFestivalGame({
    required FestivalGame game,
    required String userName,
    required String contact,
    String? ticket,
    DateTime? birthDate, // New
  }) async {
     final user = _auth.currentUser;
     if (user == null) throw Exception("User not logged in");

     // 1. Add to participants sub-collection
     await _db.collection('festival_games').doc(game.id).collection('participants').doc(user.uid).set({
        'userId': user.uid,
        'name': userName,
        'contact': contact,
        'ticket': ticket,
        if (birthDate != null) 'birthDate': Timestamp.fromDate(birthDate), // Save separate field
        'joinedAt': FieldValue.serverTimestamp(),
        'status': 'confirmed'
     });

     // 2. Update Main Document (Sync for UI)
     // Note: We might want to keep `participants` array lightweight or include birthDate there too?
     // The array is used for logs and maybe counting, but full details are in subcollection.
     // However, `ParticipantListDialog` uses `getFestivalGameParticipants` which queries the subcollection.
     // So saving in subcollection is enough for the export feature.
     // But let's add to array just in case we need it elsewhere without extra query.
     await _db.collection('festival_games').doc(game.id).update({
        'participants': FieldValue.arrayUnion([
           {'userId': user.uid, 'name': userName, 'contact': contact, 'ticket': ticket} // Array remains lightweight for now
        ])
     });

     // 3. Log Action (Triggers Notification)
     await logFestivalAction(
        action: 'signup', 
        gameId: game.id, 
        masterId: game.masterId, 
        details: {
           'gameTitle': game.title,
           'userName': userName,
           'contact': contact,
           'startTime': game.startTime.toIso8601String(),
        }
     );
  }

  Future<void> cancelFestivalRegistration(FestivalGame game, [String? ticket]) async {
     final user = _auth.currentUser;
     if (user == null) return;

     // 1. Remove from participants sub-collection
     await _db.collection('festival_games').doc(game.id).collection('participants').doc(user.uid).delete();

     // 2. Update Main Document (Sync for UI)
     await _db.runTransaction((transaction) async {
        final docRef = _db.collection('festival_games').doc(game.id);
        final snapshot = await transaction.get(docRef);
        if (!snapshot.exists) return;
        
        List<dynamic> participants = List.from(snapshot.data()?['participants'] ?? []);
        participants.removeWhere((p) => p['userId'] == user.uid || (ticket != null && p['ticket'] == ticket));
        
        transaction.update(docRef, {'participants': participants});
     });

     // 3. Log Action (Triggers Notification)
     await logFestivalAction(
        action: 'cancel', 
        gameId: game.id, 
        masterId: game.masterId, 
        details: {
           'gameTitle': game.title,
           'startTime': game.startTime.toIso8601String(),
        }
     );
  }

  Future<List<Map<String, dynamic>>> getFestivalGameParticipants(String gameId) async {
     final snapshot = await _db.collection('festival_games').doc(gameId).collection('participants').orderBy('joinedAt').get();
     return snapshot.docs.map((d) => d.data()).toList();
  }
}
