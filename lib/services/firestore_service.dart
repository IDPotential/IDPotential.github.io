import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../models/calculation.dart';

class FirestoreService {
  final FirebaseFirestore _db = FirebaseFirestore.instance;
  final FirebaseAuth _auth = FirebaseAuth.instance;

  // Helper to get current user ID
  String? get _userId => _auth.currentUser?.uid;

  // --- Calculations ---

  // Save new calculation (Auto-ID)
  // Maps fields exactly to Python Bot's fb_add_log schema
  Future<String> saveCalculation(Calculation calculation) async {
    final uid = _userId;
    if (uid == null) throw Exception("User not logged in");

    final docRef = _db.collection('users').doc(uid).collection('calculations').doc();
    
    // Convert to Map but ensure schema matches Bot:
    // Bot expects: name, birthDate, gender, numbers (List<int>), createdAt (ISO), type='diagnostic'
    // Our Calculation.toMap provides most, but we fine tune keys
    final data = {
      'name': calculation.name,
      'birthDate': calculation.birthDate,
      'gender': calculation.gender,
      'numbers': calculation.numbers,
      'createdAt': calculation.createdAt.toIso8601String(),
      'type': 'diagnostic', // Tag used by bot
      'decryption': calculation.decryption, // Paid status
      'group': calculation.group, // Folder name, optional
      'notes': calculation.notes,
    };

    await docRef.set(data);
    return docRef.id;
  }

  // Get Calculations Stream (History)
  Stream<List<Calculation>> getCalculationsStream() {
    final uid = _userId;
    if (uid == null) return const Stream.empty();

    return _db
        .collection('users')
        .doc(uid)
        .collection('calculations')
        .orderBy('createdAt', descending: true)
        .snapshots()
        .map((snapshot) {
      return snapshot.docs.map((doc) {
        final data = doc.data();
        // Since ID is in document ID, we inject it?
        // Flutter logic often keeps ID separate or inside model.
        // Calculation model stores ID as int? but Firestore ID is String.
        // Needs handling. For now, we might need a transient String ID in model.
        // But Calculation.id is int (for Hive).
        // ADAPTER: We need to modify Calculation model to support String ID or handle mapping.
        // QUICK FIX: Since we are migrating fully to Firestore, we should update Calculation model to include String id or firebaseId.
        // FOR NOW: We map keys safely.
        
        return Calculation.fromMap(data).copyWith(
          // We can't put String ID into int id field.
          // Need to update model or ignore ID for a moment?
          // Let's rely on data content.
          // Ideally: Update Calculation model to have String? firebaseId
        ); 
      }).toList();
    });
  }
  
  // Actually fetching with document IDs is crucial for updates/deletes.
  // We need to update Calculation model first to support String IDs.
  // Proceeding to update this service assuming we WILL update the model next.

  Future<List<Map<String, dynamic>>> getCalculationsRaw() async {
    final uid = _userId;
    if (uid == null) return [];

    final snapshot = await _db
        .collection('users')
        .doc(uid)
        .collection('calculations')
        .orderBy('createdAt', descending: true)
        .get();

    return snapshot.docs.map((doc) {
        final data = doc.data();
        data['id'] = doc.id; // Inject ID
        return data;
    }).toList();
  }

  // Delete
  Future<void> deleteCalculation(String logId) async {
    final uid = _userId;
    if (uid == null) return;
    await _db.collection('users').doc(uid).collection('calculations').doc(logId).delete();
  }

  // Update Group (Folder)
  Future<void> updateGroup(String logId, String? groupName) async {
    final uid = _userId;
    if (uid == null) return;
    
    final ref = _db.collection('users').doc(uid).collection('calculations').doc(logId);
    if (groupName == null || groupName.isEmpty) {
      await ref.update({'group': FieldValue.delete()});
    } else {
      await ref.update({'group': groupName});
    }
  }

  // Update Calculation Details (Name, Date, Gender)
  Future<void> updateCalculation(String logId, Calculation updatedCalc) async {
    final uid = _userId;
    if (uid == null) return;
    
    final ref = _db.collection('users').doc(uid).collection('calculations').doc(logId);
    
    // Only update editable fields + re-calculated numbers if date/gender changed
    await ref.update({
      'name': updatedCalc.name,
      'birthDate': updatedCalc.birthDate,
      'gender': updatedCalc.gender,
      'numbers': updatedCalc.numbers, // Recalculated numbers
      // Do NOT update createdAt, group, type, etc. unless needed
    });
  }

  // Update Calculation Name only
  Future<void> updateCalculationName(String logId, String newName) async {
    final uid = _userId;
    if (uid == null) return;
    await _db.collection('users').doc(uid).collection('calculations').doc(logId).update({'name': newName});
  }

  // Set Calculation as Paid (Decrypted)
  Future<void> setCalculationPaid(String logId) async {
    final uid = _userId;
    if (uid == null) return;
    await _db.collection('users').doc(uid).collection('calculations').doc(logId).update({'decryption': 1});
  }

  // --- User Data ---

  // Get user document stream (Credits, Role)
  Stream<DocumentSnapshot<Map<String, dynamic>>> getUserData() {
    final uid = _userId;
    if (uid == null) return const Stream.empty();
    return _db.collection('users').doc(uid).snapshots();
  }

  // Consume credits (Transaction)
  Future<bool> consumeCredit(int amount) async {
    final uid = _userId;
    if (uid == null) return false;
    
    final userRef = _db.collection('users').doc(uid);

    try {
      return await _db.runTransaction((transaction) async {
        final snapshot = await transaction.get(userRef);

        if (!snapshot.exists) {
          throw Exception("User does not exist!");
        }

        final int currentCredits = snapshot.data()?['credits'] ?? 0;
        final String role = snapshot.data()?['role'] ?? 'user';

        // Admins might have infinite credits, or just check count
        if (role == 'admin') {
           return true; // Free pass
        }

        if (currentCredits >= amount) {
          transaction.update(userRef, {'credits': currentCredits - amount});
          return true;
        } else {
          return false; // Not enough credits
        }
      });
    } catch (e) {
      print("Transaction failed: $e");
      return false;
    }
  } // End consumeCredit

  // --- Game Profile (Territory of Self) ---
  
  // Get Game Profile
  Future<Calculation?> getGameProfile() async {
    final uid = _userId;
    if (uid == null) return null;

    final doc = await _db.collection('users').doc(uid).collection('game_profile').doc('main').get();
    if (doc.exists) {
      final data = doc.data()!;
      data['id'] = 'main'; // Dummy ID
      return Calculation.fromMap(data);
    }
    return null;
  }

  // Save Game Profile
  Future<void> saveGameProfile(Calculation calculation) async {
    final uid = _userId;
    if (uid == null) throw Exception("User not logged in");

    final docRef = _db.collection('users').doc(uid).collection('game_profile').doc('main');
    
    final data = {
      'name': calculation.name,
      'birthDate': calculation.birthDate,
      'gender': calculation.gender,
      'numbers': calculation.numbers,
      'createdAt': calculation.createdAt.toIso8601String(),
      'updatedAt': FieldValue.serverTimestamp(),
    };

    await docRef.set(data, SetOptions(merge: true));
  }
  // --- Game Sessions (Host Features) ---

  // Create a new Game Session
  Future<String> createGame({required String title, required DateTime date}) async {
    final uid = _userId;
    if (uid == null) throw Exception("User not logged in");

    // Check if admin/diagnost
    final userDoc = await _db.collection('users').doc(uid).get();
    final role = userDoc.data()?['role'];
    final pgmd = userDoc.data()?['pgmd'];
    if (role != 'admin' && role != 'diagnost' && pgmd != 100) {
      throw Exception("Unauthorized");
    }

    final docRef = _db.collection('games').doc();
    await docRef.set({
      'hostId': uid,
      'title': title,
      'scheduledAt': date.toIso8601String(),
      'status': 'scheduled', // scheduled, active, completed
      'createdAt': FieldValue.serverTimestamp(),
    });

    return docRef.id;
  }

  // Get Stream of Upcoming/Active Games
  Stream<QuerySnapshot<Map<String, dynamic>>> getGamesStream() {
    return _db.collection('games')
        .where('status', whereIn: ['scheduled', 'active'])
        .orderBy('scheduledAt', descending: false)
        .snapshots();
  }

  // Submit Answer (Player)
  Future<void> submitGameAnswer({
    required String gameId,
    required int roleId,
    required String roleName,
    required String answer
  }) async {
    final uid = _userId;
    if (uid == null) throw Exception("User not logged in");
    if (gameId.isEmpty) return; 

    final userDoc = await _db.collection('users').doc(uid).get();
    final userName = userDoc.data()?['first_name'] ?? 'Игрок';

    await _db.collection('games').doc(gameId).collection('answers').add({
      'userId': uid,
      'userName': userName,
      'roleId': roleId,
      'roleName': roleName,
      'answer': answer,
      'timestamp': FieldValue.serverTimestamp(),
    });
  }

  // Get Answers Stream (Host)
  Stream<QuerySnapshot<Map<String, dynamic>>> getGameAnswersStream(String gameId) {
    if (gameId.isEmpty) return const Stream.empty();
    // Security rules should enforce host access
    return _db.collection('games').doc(gameId).collection('answers')
        .orderBy('timestamp', descending: true)
        .snapshots();
  }

  // --- Requests (Personal Account) ---

  // Create a new request (Top-up, Question, Upgrade)
  Future<void> createRequest({
    required String type, // 'credits', 'question', 'upgrade', 'deposit'
    String? text,
    int? value,
    String? contactInfo, // optional username or link
  }) async {
    final uid = _userId;
    if (uid == null) throw Exception("User not logged in");

    // Fetch current user data to attach username/name
    final userDoc = await _db.collection('users').doc(uid).get();
    final userData = userDoc.data();
    final name = userData?['first_name'] ?? 'User';
    final username = userData?['username'] ?? '';

    await _db.collection('requests').add({
      'userId': uid,
      'type': type,
      'text': text,
      'value': value,
      'status': 'pending',
      'createdAt': FieldValue.serverTimestamp(),
      'userName': name,
      'userContact': username.isNotEmpty ? username : contactInfo,
      'is_answered': 0, // Compatibility with bot logic if migrated
    });
  }

  // --- Admin Panel ---

  // Get Pending Requests Stream
  Stream<QuerySnapshot<Map<String, dynamic>>> getPendingRequests() {
    return _db
        .collection('requests')
        .where('status', isEqualTo: 'pending')
        .orderBy('createdAt', descending: true)
        .snapshots();
  }

  // Process Request (Admin Action)
  Future<void> processRequest(String requestId, String userId, String type, int? value) async {
    final uid = _userId;
    if (uid == null) return;
    
    // Check if current user is admin (security rule should also enforce this)
    final currentUserDoc = await _db.collection('users').doc(uid).get();
    final role = currentUserDoc.data()?['role'];
    final pgmd = currentUserDoc.data()?['pgmd'];
    
    // Allow if role is admin OR pgmd level is 100
    if (role != 'admin' && pgmd != 100) {
      throw Exception("Unauthorized");
    }

    final userRef = _db.collection('users').doc(userId);
    final requestRef = _db.collection('requests').doc(requestId);

    await _db.runTransaction((transaction) async {
      final requestDoc = await transaction.get(requestRef);
      if (!requestDoc.exists) throw Exception("Request not found");
      
      if (requestDoc.data()?['status'] == 'completed') {
         throw Exception("Request already processed");
      }

      // Perform action based on type
      if (type == 'credits' || type == 'deposit' || type == 'subscription' || type == 'bonus') {
        if (value != null && value > 0) {
           transaction.update(userRef, {'credits': FieldValue.increment(value)});
           
           // Add notification message to the request itself
           transaction.update(requestRef, {
             'status': 'completed',
             'processedBy': uid,
             'processedAt': FieldValue.serverTimestamp(),
             'answer': 'Баланс пополнен на $value кр.', // System notification
             'is_answered': 1,
           });
           return; // Return early as we did the update above
        }
      } else if (type == 'upgrade') {
         transaction.update(userRef, {'pgmd': 2}); // Set to Researcher
         transaction.update(userRef, {'credits': FieldValue.increment(20)});
         
         transaction.update(requestRef, {
             'status': 'completed',
             'processedBy': uid,
             'processedAt': FieldValue.serverTimestamp(),
             'answer': 'Статус повышен до "Исследователь". Начислено 20 кр.',
             'is_answered': 1,
         });
         return;
      }

      // Default completion for other types or if value was 0
      transaction.update(requestRef, {
        'status': 'completed',
        'processedBy': uid,
        'processedAt': FieldValue.serverTimestamp(),
      });
    });
  }
  // Answer Request (Admin Action for Questions)
  Future<void> answerRequest(String requestId, String answerText) async {
    final uid = _userId;
    if (uid == null) return;
    
    // Check admin permissions (simplified)
    final currentUserDoc = await _db.collection('users').doc(uid).get();
    final role = currentUserDoc.data()?['role'];
    final pgmd = currentUserDoc.data()?['pgmd'];
    if (role != 'admin' && pgmd != 100) throw Exception("Unauthorized");

    final requestRef = _db.collection('requests').doc(requestId);
    
    await requestRef.update({
      'status': 'answered',
      'answer': answerText,
      'answeredBy': uid,
      'answeredAt': FieldValue.serverTimestamp(),
      'is_answered': 1,
    });
  }

  // Get User's Requests Stream (for Micro-Chat)
  Stream<QuerySnapshot<Map<String, dynamic>>> getUserRequests() {
    final uid = _userId;
    if (uid == null) return const Stream.empty();
    
    return _db
        .collection('requests')
        .where('userId', isEqualTo: uid)
        // .where('type', isEqualTo: 'question') // REMOVED filter to show all history (Deposits, Bonuses, etc.)
        .orderBy('createdAt', descending: true)
        .snapshots();
  }
}
