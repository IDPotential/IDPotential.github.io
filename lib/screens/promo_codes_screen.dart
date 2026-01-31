
import 'package:flutter/material.dart';
import '../models/promo_code.dart';
import '../services/firestore_service.dart';

class PromoCodesScreen extends StatefulWidget {
  const PromoCodesScreen({super.key});

  @override
  State<PromoCodesScreen> createState() => _PromoCodesScreenState();
}

class _PromoCodesScreenState extends State<PromoCodesScreen> {
  final FirestoreService _firestoreService = FirestoreService();

  void _showEditParams(PromoCode? promo) {
     final _codeCtrl = TextEditingController(text: promo?.code ?? '');
     final _valCtrl = TextEditingController(text: promo?.discountValue.toString() ?? '0');
     String _type = promo?.discountType ?? 'fixed';
     bool _active = promo?.isActive ?? true;
     List<String> _cats = promo?.applicableTypes ?? ['Посетитель', 'Мастер', 'Маэстро', 'Партнер'];
     
     showDialog(
       context: context, 
       builder: (ctx) => StatefulBuilder(
         builder: (context, setState) {
           return AlertDialog(
             title: Text(promo == null ? 'Новый промокод' : 'Редактировать'),
             content: SingleChildScrollView(
               child: Column(
                 mainAxisSize: MainAxisSize.min,
                 children: [
                   TextField(
                     controller: _codeCtrl,
                     decoration: const InputDecoration(labelText: 'Код'),
                   ),
                   const SizedBox(height: 10),
                   Row(
                     children: [
                       Expanded(
                         child: DropdownButtonFormField<String>(
                           value: _type,
                           items: const [
                             DropdownMenuItem(value: 'fixed', child: Text('Сумма (руб)')),
                             DropdownMenuItem(value: 'percent', child: Text('Процент (%)')),
                           ], 
                           onChanged: (v) => setState(() => _type = v!),
                           decoration: const InputDecoration(labelText: 'Тип'),
                         ),
                       ),
                       const SizedBox(width: 10),
                       Expanded(
                         child: TextField(
                           controller: _valCtrl,
                           keyboardType: TextInputType.number,
                           decoration: const InputDecoration(labelText: 'Значение'),
                         ),
                       ),
                     ],
                   ),
                   const SizedBox(height: 10),
                   SwitchListTile(
                     title: const Text('Активен'),
                     value: _active, 
                     onChanged: (v) => setState(() => _active = v)
                   ),
                   const Divider(),
                   const Text("Категории:"),
                   ...['Посетитель', 'Мастер', 'Маэстро', 'Партнер'].map((c) {
                      return CheckboxListTile(
                        title: Text(c),
                        value: _cats.contains(c), 
                        onChanged: (val) {
                           setState(() {
                              if (val == true) _cats.add(c);
                              else _cats.remove(c);
                           });
                        },
                        dense: true,
                        contentPadding: EdgeInsets.zero,
                      );
                   }).toList()
                 ],
               ),
             ),
             actions: [
               TextButton(onPressed: () => Navigator.pop(context), child: const Text('Отмена')),
               ElevatedButton(
                 onPressed: () {
                    final val = int.tryParse(_valCtrl.text) ?? 0;
                    if (_codeCtrl.text.isEmpty) return;
                    
                    final newPromo = PromoCode(
                       id: promo?.id,
                       code: _codeCtrl.text.trim(), 
                       discountType: _type, 
                       discountValue: val, 
                       applicableTypes: _cats,
                       isActive: _active
                    );
                    _firestoreService.savePromoCode(newPromo);
                    Navigator.pop(context);
                 }, 
                 child: const Text('Сохранить')
               )
             ],
           );
         }
       )
     );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Управление промокодами')),
      floatingActionButton: FloatingActionButton(
        onPressed: () => _showEditParams(null),
        child: const Icon(Icons.add),
      ),
      body: StreamBuilder<List<PromoCode>>(
        stream: _firestoreService.getPromoCodesStream(),
        builder: (context, snapshot) {
          if (snapshot.hasError) return Center(child: Text('Error: ${snapshot.error}'));
          if (!snapshot.hasData) return const Center(child: CircularProgressIndicator());
          
          final list = snapshot.data!;
          if (list.isEmpty) return const Center(child: Text('Нет промокодов'));
          
          return ListView.builder(
            itemCount: list.length,
            itemBuilder: (context, index) {
              final p = list[index];
              return Card(
                color: p.isActive ? Colors.white : Colors.grey[200],
                margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                child: ListTile(
                  title: Text(p.code, style: const TextStyle(fontWeight: FontWeight.bold)),
                  subtitle: Text("${p.discountType == 'percent' ? '${p.discountValue}%' : '${p.discountValue} руб.'}\n${p.applicableTypes.join(', ')}"),
                  trailing: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                       IconButton(icon: const Icon(Icons.edit, color: Colors.blue), onPressed: () => _showEditParams(p)),
                       IconButton(icon: const Icon(Icons.delete, color: Colors.red), onPressed: () => _firestoreService.deletePromoCode(p.id!)),
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
