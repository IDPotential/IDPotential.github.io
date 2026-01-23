import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../services/firestore_service.dart';
import '../widgets/role_info_dialog.dart';
import 'package:intl/intl.dart';

class TrainingHistoryScreen extends StatelessWidget {
  const TrainingHistoryScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final FirestoreService _firestoreService = FirestoreService();

    return Scaffold(
      appBar: AppBar(
        title: const Text('История тренировок'),
        backgroundColor: const Color(0xFF0F172A),
      ),
      body: Container(
        decoration: const BoxDecoration(
           gradient: LinearGradient(colors: [Color(0xFF0F172A), Color(0xFF1E293B)])
        ),
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 800),
            child: StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
              stream: _firestoreService.getGameHistoryStream(),
              builder: (context, snapshot) {
                 if (snapshot.hasError) return const Center(child: Text('Ошибка загрузки'));
                 if (!snapshot.hasData) return const Center(child: CircularProgressIndicator());
    
                 // Filter locally for 'isTraining' == true
                 final docs = snapshot.data!.docs.where((d) => d.data()['isTraining'] == true).toList();
    
                 if (docs.isEmpty) {
                   return const Center(
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                           Icon(Icons.history_edu, size: 64, color: Colors.grey),
                           SizedBox(height: 16),
                           Text('История тренировок пуста', style: TextStyle(color: Colors.grey)),
                        ],
                      ),
                   );
                 }
    
                 return ListView.builder(
                   padding: const EdgeInsets.all(16),
                   itemCount: docs.length,
                   itemBuilder: (context, index) {
                      final data = docs[index].data();
                      
                      final situation = data['situation'] ?? 'Контекст не сохранен';
                      final role = data['role'] as int?;
                      final dateRaw = data['date'];
                      String dateStr = '';
                      
                      if (dateRaw is Timestamp) {
                         dateStr = DateFormat('dd.MM.yyyy HH:mm').format(dateRaw.toDate());
                      } else if (dateRaw != null) {
                         dateStr = dateRaw.toString();
                      }
    
                      return Card(
                         color: Colors.white10,
                         margin: const EdgeInsets.only(bottom: 12),
                         shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                         child: Padding(
                           padding: const EdgeInsets.all(16.0),
                           child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                 Row(
                                   mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                   children: [
                                      Container(
                                         padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                                         decoration: BoxDecoration(color: Colors.blueAccent.withOpacity(0.2), borderRadius: BorderRadius.circular(8)),
                                         child: Text(dateStr, style: const TextStyle(color: Colors.blueAccent, fontSize: 12)),
                                      ),
                                      if (role != null)
                                        Chip(
                                          label: Text('Роль #$role'),
                                          backgroundColor: Colors.orange,
                                          labelStyle: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
                                          padding: EdgeInsets.zero,
                                          materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
                                        )
                                   ],
                                 ),
                                 const SizedBox(height: 12),
                                 const Text("Ситуация:", style: TextStyle(color: Colors.grey, fontSize: 12)),
                                 const SizedBox(height: 4),
                                 Text(situation, style: const TextStyle(color: Colors.white, fontSize: 15)),
                                 
                                 if (role != null) ...[
                                    const SizedBox(height: 12),
                                    const Divider(color: Colors.white24),
                                    InkWell(
                                       onTap: () {
                                           showDialog(context: context, builder: (c) => RoleInfoDialog(roleNumber: role));
                                       },
                                       child: Padding(
                                         padding: const EdgeInsets.symmetric(vertical: 8.0),
                                         child: Row(
                                            children: [
                                               const Text("Ваш выбор:", style: TextStyle(color: Colors.grey, fontSize: 12)),
                                               const SizedBox(width: 8),
                                               Text("Посмотреть описание роли #$role", style: const TextStyle(color: Colors.orangeAccent, decoration: TextDecoration.underline)),
                                               const Spacer(),
                                               const Icon(Icons.arrow_forward_ios, size: 12, color: Colors.grey)
                                            ],
                                         ),
                                       ),
                                    )
                                 ]
                              ],
                           ),
                         ),
                      );
                   },
                 );
              },
            ),
          ),
        ),
      ),
    );
  }
}
