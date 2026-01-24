import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../services/firestore_service.dart';
import 'package:intl/intl.dart';

class FestivalApplicationsScreen extends StatefulWidget {
  const FestivalApplicationsScreen({super.key});

  @override
  State<FestivalApplicationsScreen> createState() => _FestivalApplicationsScreenState();
}

class _FestivalApplicationsScreenState extends State<FestivalApplicationsScreen> {
  final FirestoreService _firestoreService = FirestoreService();

  // Status mapping
  final Map<String, String> _statusLabels = {
    'new': 'Новая',
    'called': 'Позвонил',
    'accepted': 'Принял',
    'paid': 'Оплатил',
    'rejected': 'Отклонена',
  };

  final Map<String, Color> _statusColors = {
    'new': Colors.blue,
    'called': Colors.orange,
    'accepted': Colors.purple,
    'paid': Colors.green,
    'rejected': Colors.red,
  };

  void _updateStatus(String docId, String? newStatus) {
    if (newStatus != null) {
      _firestoreService.updateApplicationStatus(docId, newStatus);
    }
  }

  void _copyToClipboard(String text) {
    Clipboard.setData(ClipboardData(text: text));
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('Скопировано: $text'), duration: const Duration(seconds: 1)),
    );
  }

  void _exportToClipboard(List<QueryDocumentSnapshot<Map<String, dynamic>>> docs) {
    StringBuffer sb = StringBuffer();
    sb.writeln("Дата;Имя;Телефон;Тип;Статус;Промокод");

    for (var doc in docs) {
      final data = doc.data();
      final date = (data['createdAt'] as Timestamp?)?.toDate().toString() ?? '';
      final name = data['name'] ?? '';
      final phone = data['phone'] ?? '';
      final type = data['type'] ?? '';
      final status = _statusLabels[data['status']] ?? data['status'] ?? '';
      final promo = data['promo'] ?? '';
      
      sb.writeln("$date;$name;$phone;$type;$status;$promo");
    }

    Clipboard.setData(ClipboardData(text: sb.toString()));
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Все заявки скопированы в буфер (CSV формат)'), backgroundColor: Colors.green),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Заявки на Фестиваль'),
        actions: [
          StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
             stream: _firestoreService.getFestivalApplicationsStream(),
             builder: (context, snapshot) {
                 if (!snapshot.hasData || snapshot.data!.docs.isEmpty) return const SizedBox.shrink();
                 return IconButton(
                    icon: const Icon(Icons.copy_all),
                    tooltip: 'Экспорт всех заявок',
                    onPressed: () => _exportToClipboard(snapshot.data!.docs)
                 );
             }
          )
        ],
      ),
      body: StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
        stream: _firestoreService.getFestivalApplicationsStream(),
        builder: (context, snapshot) {
          if (snapshot.hasError) return Center(child: Text('Ошибка: ${snapshot.error}'));
          if (snapshot.connectionState == ConnectionState.waiting) return const Center(child: CircularProgressIndicator());

          final docs = snapshot.data!.docs;
          if (docs.isEmpty) return const Center(child: Text('Заявок пока нет'));

          return ListView.builder(
            padding: const EdgeInsets.all(16),
            itemCount: docs.length,
            itemBuilder: (context, index) {
              final doc = docs[index];
              final data = doc.data();
              final date = (data['createdAt'] as Timestamp?)?.toDate();
              final dateStr = date != null ? DateFormat('dd.MM.yyyy HH:mm').format(date) : 'Нет даты';
              
              final name = data['name'] ?? 'Без имени';
              final phone = data['phone'] ?? 'Нет телефона';
              final type = data['type'] ?? 'Не указан';
              final status = data['status'] ?? 'new';
              final promo = data['promo'];

              return Card(
                margin: const EdgeInsets.only(bottom: 12),
                child: Padding(
                  padding: const EdgeInsets.all(12),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Header: Date + Status Dropdown
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text(dateStr, style: const TextStyle(fontSize: 12, color: Colors.grey)),
                          Container(
                             padding: const EdgeInsets.symmetric(horizontal: 8),
                             decoration: BoxDecoration(
                               color: (_statusColors[status] ?? Colors.grey).withOpacity(0.1),
                               borderRadius: BorderRadius.circular(4),
                               border: Border.all(color: (_statusColors[status] ?? Colors.grey).withOpacity(0.5))
                             ),
                             child: DropdownButtonHideUnderline(
                               child: DropdownButton<String>(
                                 value: _statusLabels.containsKey(status) ? status : 'new',
                                 isDense: true,
                                 style: TextStyle(
                                    color: _statusColors[status] ?? Colors.black, 
                                    fontWeight: FontWeight.bold,
                                    fontSize: 13
                                 ),
                                 items: _statusLabels.entries.map((e) {
                                   return DropdownMenuItem(
                                      value: e.key,
                                      child: Text(e.value, style: TextStyle(color: _statusColors[e.key])),
                                   );
                                 }).toList(),
                                 onChanged: (val) => _updateStatus(doc.id, val),
                               ),
                             ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 8),
                      
                      // Name & Type
                      Text("$name ($type)", style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
                      if (promo != null && promo.toString().isNotEmpty)
                         Text("Промокод: $promo", style: const TextStyle(color: Colors.purple, fontSize: 13)),
                      
                      const SizedBox(height: 8),
                      
                      // Phone Row
                      Row(
                        children: [
                          const Icon(Icons.phone, size: 16, color: Colors.grey),
                          const SizedBox(width: 4),
                          SelectableText(phone, style: const TextStyle(fontSize: 15)),
                          IconButton(
                            icon: const Icon(Icons.copy, size: 16, color: Colors.blue),
                            onPressed: () => _copyToClipboard(phone),
                            tooltip: 'Скопировать номер',
                            constraints: const BoxConstraints(), // Compact
                            padding: const EdgeInsets.symmetric(horizontal: 8),
                          )
                        ],
                      )
                    ],
                  ),
                ),
              );
            },
          );
        },
      ),
    );
  }
}
