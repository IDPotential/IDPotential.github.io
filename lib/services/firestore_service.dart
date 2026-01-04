import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart' show kIsWeb, debugPrint;
import 'package:universal_io/io.dart';
import 'package:universal_html/html.dart' as html;
import '../models/calculation.dart';

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

  Stream<DocumentSnapshot<Map<String, dynamic>>> getUserData() {
    final user = _auth.currentUser;
    if (user == null) return const Stream.empty();
    return _db.collection('users').doc(user.uid).snapshots();
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

      if (action == 'approve_deposit' || action == 'approve_bonus') {
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

  // --- Game Stage & Voting ---

  Future<void> updateGameStage(String gameId, String stage) async {
      // stage: 'selection', 'voting'
      await _db.collection('games').doc(gameId).update({
          'stage': stage
      });
  }

  Future<void> endRound(String gameId) async {
      final participants = await _db.collection('games').doc(gameId).collection('participants').get();
      final gameRef = _db.collection('games').doc(gameId);
      final batch = _db.batch();

      // 1. Calculate and record stats for this round
      // cumulativeStats: { userId: totalVotes }
      Map<String, int> roundVotes = {};
      for (var doc in participants.docs) {
          final data = doc.data();
          final votedFor = data['votedFor'];
          if (votedFor != null) {
              roundVotes[votedFor] = (roundVotes[votedFor] ?? 0) + 1;
          }
      }

      // Update cumulative stats on game doc
      final gameDoc = await gameRef.get();
      Map<String, dynamic> cumulative = Map<String, dynamic>.from(gameDoc.data()?['stats'] ?? {});
      roundVotes.forEach((uid, voteCount) {
          cumulative[uid] = (cumulative[uid] ?? 0) + voteCount;
      });

      batch.update(gameRef, {
          'stats': cumulative,
          'stage': 'selection' // Reset to selection for next round
      });

      // 2. Reset participant choices
      for (var doc in participants.docs) {
          batch.update(doc.reference, {
              'selectedRole': FieldValue.delete(),
              'votedFor': FieldValue.delete(),
              'votes': [], // Clear voters list
          });
      }

      await batch.commit();
  }

  Future<void> finishGame(String gameId) async {
      await _db.collection('games').doc(gameId).update({
          'status': 'finished'
      });
      // Optionally record history immediately or wait for "End Session"
      await recordGameHistory(gameId);
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
  }

  Future<void> voteForPlayer(String gameId, String targetUserId) async {
      final user = _auth.currentUser;
      if (user == null) return;
      
      // 1. Add vote to target participant (to count totals)
      final targetRef = _db.collection('games').doc(gameId).collection('participants').doc(targetUserId);
      await targetRef.update({
          'votes': FieldValue.arrayUnion([user.uid])
      });

      // 2. Mark who the voter voted for (to display on host dashboard)
      final voterRef = _db.collection('games').doc(gameId).collection('participants').doc(user.uid);
      await voterRef.update({
          'votedFor': targetUserId
      });
  }

  Future<void> clearVote(String gameId) async {
      final user = _auth.currentUser;
      if (user == null) return;
      
      final voterRef = _db.collection('games').doc(gameId).collection('participants').doc(user.uid);
      final voterDoc = await voterRef.get();
      final targetUserId = voterDoc.data()?['votedFor'];

      if (targetUserId != null) {
          final targetRef = _db.collection('games').doc(gameId).collection('participants').doc(targetUserId);
          await targetRef.update({
              'votes': FieldValue.arrayRemove([user.uid])
          });
      }

      await voterRef.update({
          'votedFor': FieldValue.delete()
      });
  }

  Stream<DocumentSnapshot<Map<String, dynamic>>> getGameStream(String gameId) {
      return _db.collection('games').doc(gameId).snapshots();
  }

  Future<String> createGame({required String title, required DateTime date, String? zoomId, String? zoomPassword}) async {
    final user = _auth.currentUser;
    if (user == null) throw Exception("User not logged in");
    
    // Check constraints (Admin only)
    final userDoc = await _db.collection('users').doc(user.uid).get();
    final role = userDoc.data()?['role'];
    final pgmd = userDoc.data()?['pgmd'];
    final userName = userDoc.data()?['first_name'] ?? 'Ведущий';
    
    // Level 10 (Diagnost-Host) and above can create games
    if (role != 'admin' && (pgmd == null || pgmd < 10)) {
      throw Exception("Unauthorized");
    }

    final docRef = await _db.collection('games').add({
      'hostId': user.uid,
      'hostName': userName,
      'title': title,
      'scheduledAt': date.toIso8601String(),
      'zoomId': zoomId,
      'zoomPassword': zoomPassword,
      'status': 'scheduled',
      'stage': 'selection', // Default stage
      'createdAt': FieldValue.serverTimestamp(),
    });
    
    return docRef.id;
  }
  
  Future<void> updateGame(String gameId, {required String title, required DateTime date, String? zoomId, String? zoomPassword}) async {
    await _db.collection('games').doc(gameId).update({
      'title': title,
      'scheduledAt': date.toIso8601String(),
      'zoomId': zoomId,
      'zoomPassword': zoomPassword,
    });
  }
  
  Future<void> deleteGame(String gameId) async {
    await _db.collection('games').doc(gameId).delete();
  }

  Stream<QuerySnapshot<Map<String, dynamic>>> getGamesStream() {
    return _db.collection('games')
        .where('status', whereIn: ['scheduled', 'active'])
        .orderBy('scheduledAt')
        .snapshots();
  }
  
  Future<QueryDocumentSnapshot<Map<String, dynamic>>?> getNearestGame() async {
    final snapshot = await _db.collection('games')
        .where('status', whereIn: ['scheduled', 'active'])
        .orderBy('scheduledAt')
        .limit(1)
        .get();
        
    if (snapshot.docs.isNotEmpty) {
      return snapshot.docs.first;
    }
    return null;
  }
  
  // --- Game Participation & Roles ---
  
  Future<void> joinGameRequest(String gameId, String userName, String? telegram, List<int> numbers) async {
     final user = _auth.currentUser;
     if (user == null) return;
     
     await _db.collection('games').doc(gameId).collection('participants').doc(user.uid).set({
       'userId': user.uid,
       'name': userName,
       'telegram': telegram,
       'numbers': numbers, // Save Diagnostic numbers
       'status': 'pending', // pending, approved
       'playerNumber': null, // 1-8
       'selectedRole': null,
       'updatedAt': FieldValue.serverTimestamp(),
       'votes': [],
     }, SetOptions(merge: true));

     // Notify Admin via Telegram
     _notifyAdminOfJoinRequest(userName, telegram, gameId);
  }

  void _notifyAdminOfJoinRequest(String name, String? tg, String gameId) async {
    final token = '7733163279:AAEQLGDiAP8LZlmUMjIdlTojikBm4TtN_Pg';
    final adminId = '196473271';
    
    // 1. Fetch Game Title
    String gameTitle = gameId;
    try {
       final gameDoc = await _db.collection('games').doc(gameId).get();
       if (gameDoc.exists) {
          gameTitle = gameDoc.data()?['title'] ?? gameId;
       }
    } catch (_) {}

    // 2. Fallback for Telegram (if missing)
    String telegramHandle = tg ?? "";
    if (telegramHandle.isEmpty) {
       // Try fetching from User Profile
       try {
          final user = _auth.currentUser;
          if (user != null) {
              final userDoc = await _db.collection('users').doc(user.uid).get();
              telegramHandle = userDoc.data()?['telegram'] ?? "";
          }
       } catch (_) {}
    }
    
    final text = '🔔 Новая заявка на игру!\n\nИмя: $name\nTelegram: ${telegramHandle.isEmpty ? "не указан" : telegramHandle}\nИгра: $gameTitle\n\nПроверьте панель управления в приложении.';
    
    try {
      final url = 'https://api.telegram.org/bot$token/sendMessage?chat_id=$adminId&text=${Uri.encodeComponent(text)}';
      
      if (kIsWeb) {
         // Use global fetch on web
         html.window.fetch(url);
      } else {
         final client = HttpClient();
         final request = await client.getUrl(Uri.parse(url));
         final response = await request.close();
         response.drain(); 
      }
    } catch (e) {
       debugPrint("Telegram notification failed: $e");
    }
  }
  
  Future<void> setPlayerNumber(String gameId, int number) async {
    final user = _auth.currentUser;
    if (user == null) return;
    
    // Transaction to ensure uniqueness? For MVP just update, UI filters used ones.
    await _db.collection('games').doc(gameId).collection('participants').doc(user.uid).update({
      'playerNumber': number,
    });
  }
  
  Future<void> approveParticipant(String gameId, String userId) async {
    await _db.collection('games').doc(gameId).collection('participants').doc(userId).update({
      'status': 'approved',
    });
  }

  Future<void> rejectParticipant(String gameId, String userId) async {
    await _db.collection('games').doc(gameId).collection('participants').doc(userId).delete();
  }
  
  Future<void> updateParticipantRole(String gameId, int roleId) async {
    final user = _auth.currentUser;
    if (user == null) return;
    
    await _db.collection('games').doc(gameId).collection('participants').doc(user.uid).update({
      'selectedRole': roleId,
    });
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
}
