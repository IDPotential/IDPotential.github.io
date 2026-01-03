import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
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

  Future<void> voteForPlayer(String gameId, String targetUserId) async {
      final user = _auth.currentUser;
      if (user == null) return;
      
      // Store vote in a subcollection or on the participant doc?
      // Simple way: Add 'votes' list to target participant
      final targetRef = _db.collection('games').doc(gameId).collection('participants').doc(targetUserId);
      
      await targetRef.update({
          'votes': FieldValue.arrayUnion([user.uid])
      });
  }

  Stream<DocumentSnapshot<Map<String, dynamic>>> getGameStream(String gameId) {
      return _db.collection('games').doc(gameId).snapshots();
  }

  Future<String> createGame({required String title, required DateTime date}) async {
    final user = _auth.currentUser;
    if (user == null) throw Exception("User not logged in");
    
    // Check constraints (Admin only)
    final userDoc = await _db.collection('users').doc(user.uid).get();
    final role = userDoc.data()?['role'];
    final pgmd = userDoc.data()?['pgmd'];
    
    if (role != 'admin' && role != 'diagnost' && pgmd != 100) {
      throw Exception("Unauthorized");
    }

    final docRef = await _db.collection('games').add({
      'hostId': user.uid,
      'title': title,
      'scheduledAt': date.toIso8601String(),
      'status': 'scheduled',
      'stage': 'selection', // Default stage
      'createdAt': FieldValue.serverTimestamp(),
    });
    
    return docRef.id;
  }

  Stream<QuerySnapshot<Map<String, dynamic>>> getGamesStream() {
    return _db.collection('games')
        .where('status', whereIn: ['scheduled', 'active'])
        .orderBy('scheduledAt')
        .snapshots();
  }
  
  // --- Game Participation & Roles ---
  
  Future<void> joinGameRequest(String gameId, String userName, String? telegram) async {
     final user = _auth.currentUser;
     if (user == null) return;
     
     await _db.collection('games').doc(gameId).collection('participants').doc(user.uid).set({
       'userId': user.uid,
       'name': userName,
       'telegram': telegram,
       'status': 'pending', // pending, approved
       'selectedRole': null,
       'updatedAt': FieldValue.serverTimestamp(),
     }, SetOptions(merge: true));
  }
  
  Future<void> approveParticipant(String gameId, String userId) async {
    await _db.collection('games').doc(gameId).collection('participants').doc(userId).update({
      'status': 'approved',
    });
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
}
