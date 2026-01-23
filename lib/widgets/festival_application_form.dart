
import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';
import '../services/firestore_service.dart';

class FestivalApplicationForm extends StatefulWidget {
  final String initialType; // 'Посетитель', 'Мастер', 'Маэстро', 'Партнер'
  
  const FestivalApplicationForm({
    super.key, 
    this.initialType = 'Посетитель'
  });

  @override
  State<FestivalApplicationForm> createState() => _FestivalApplicationFormState();
}

class _FestivalApplicationFormState extends State<FestivalApplicationForm> {
  final _formKey = GlobalKey<FormState>();
  final _nameController = TextEditingController();
  final _phoneController = TextEditingController();
  final _promoController = TextEditingController();
  
  late String _selectedType;
  bool _consentGiven = false;
  bool _isLoading = false;

  final List<String> _types = [
    'Посетитель',
    'Мастер',
    'Маэстро',
    'Партнер'
  ];

  @override
  void initState() {
    super.initState();
    _selectedType = widget.initialType;
    // Normalize if passed type matches one of our options
    if (!_types.contains(_selectedType)) {
       // If it's "Uchastnik", map to 'Посетитель'
       if (_selectedType == 'Uchastnik') _selectedType = 'Посетитель';
       else _selectedType = 'Посетитель';
    }
  }

  @override
  Widget build(BuildContext context) {
    return Dialog(
      backgroundColor: Colors.white,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      insetPadding: const EdgeInsets.all(20),
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 400),
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24),
          child: Form(
            key: _formKey,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Text(
                  "Заявка",
                  style: TextStyle(
                    fontSize: 24,
                    fontWeight: FontWeight.bold,
                    color: Color(0xFF2E0249),
                  ),
                ),
                const SizedBox(height: 8),
                const Text(
                  "На участие в фестивале 21 февраля",
                  style: TextStyle(fontSize: 14, color: Colors.grey),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 24),
                
                // Name
                TextFormField(
                  controller: _nameController,
                  decoration: _inputDecoration("Имя"),
                  validator: (v) => v == null || v.isEmpty ? "Введите имя" : null,
                  style: const TextStyle(color: Colors.black87),
                ),
                const SizedBox(height: 16),
                
                // Phone
                TextFormField(
                  controller: _phoneController,
                  decoration: _inputDecoration("Телефон"),
                  keyboardType: TextInputType.phone,
                  validator: (v) => v == null || v.isEmpty ? "Введите телефон" : null,
                  style: const TextStyle(color: Colors.black87),
                ),
                const SizedBox(height: 16),
                
                // Promocode
                TextFormField(
                  controller: _promoController,
                  decoration: _inputDecoration("Промокод"),
                  style: const TextStyle(color: Colors.black87),
                ),
                const SizedBox(height: 16),
                
                // Dropdown Type
                Align(
                  alignment: Alignment.centerLeft,
                  child: Text("Вид участия", style: TextStyle(color: Colors.blueGrey[700], fontSize: 14)),
                ),
                const SizedBox(height: 8),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12),
                  decoration: BoxDecoration(
                    border: Border.all(color: Colors.grey.shade300),
                    borderRadius: BorderRadius.circular(4),
                  ),
                  child: DropdownButtonHideUnderline(
                    child: DropdownButton<String>(
                      value: _selectedType,
                      isExpanded: true,
                      items: _types.map((t) => DropdownMenuItem(
                        value: t,
                        child: Text(t, style: const TextStyle(color: Colors.black87)),
                      )).toList(),
                      onChanged: (val) {
                        if (val != null) setState(() => _selectedType = val);
                      },
                    ),
                  ),
                ),
                
                const SizedBox(height: 24),
                
                // Consent
                GestureDetector(
                  onTap: () => setState(() => _consentGiven = !_consentGiven),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Padding(
                        padding: const EdgeInsets.only(top: 2),
                        child: Icon(
                           _consentGiven ? Icons.check_box : Icons.check_box_outline_blank,
                           color: Colors.black87,
                           size: 24,
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: RichText(
                          text: TextSpan(
                            style: const TextStyle(fontSize: 12, color: Colors.grey),
                            children: [
                              const TextSpan(text: "Я соглашаюсь с "),
                              WidgetSpan(
                                child: GestureDetector(
                                  // Open real policy if link exists
                                  onTap: () {},
                                  child: const Text("политикой конфиденциальности и обработки персональных данных", style: TextStyle(color: Colors.brown, decoration: TextDecoration.underline)),
                                ),
                              ),
                              const TextSpan(text: " (152-ФЗ)"),
                            ]
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                
                const SizedBox(height: 24),
                
                // Submit
                SizedBox(
                  width: double.infinity,
                  height: 48,
                  child: ElevatedButton(
                    onPressed: (_isLoading || !_consentGiven) ? null : _submit,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.black,
                      foregroundColor: Colors.white,
                      disabledBackgroundColor: Colors.grey,
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(4)),
                    ),
                    child: _isLoading 
                       ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
                       : const Text("Отправить", style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                  ),
                ),
                const SizedBox(height: 16),
                TextButton(
                  onPressed: () => Navigator.pop(context),
                  child: const Text("Закрыть", style: TextStyle(color: Colors.grey)),
                )
              ],
            ),
          ),
        ),
      ),
    );
  }

  InputDecoration _inputDecoration(String label) {
    return InputDecoration(
      hintText: label,
      hintStyle: const TextStyle(color: Colors.grey),
      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(4),
        borderSide: BorderSide(color: Colors.grey.shade300),
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(4),
        borderSide: BorderSide(color: Colors.grey.shade300),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(4),
        borderSide: const BorderSide(color: Colors.black87),
      ),
      fillColor: Colors.white,
      filled: true,
    );
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;
    
    setState(() => _isLoading = true);
    
    try {
      await FirestoreService().saveFestivalApplication(
         name: _nameController.text.trim(),
         phone: _phoneController.text.trim(),
         promo: _promoController.text.trim(),
         type: _selectedType,
      );
      
      if (mounted) {
         Navigator.pop(context); // Close dialog
         showDialog(
            context: context, 
            builder: (_) => AlertDialog(
               title: const Text("Успешно!"),
               content: const Text("Ваша заявка отправлена. Мы свяжемся с вами в ближайшее время."),
               actions: [
                  TextButton(onPressed: () => Navigator.pop(context), child: const Text("ОК"))
               ],
            )
         );
      }
    } catch (e) {
      if (mounted) {
         ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text("Ошибка отправки: $e"), backgroundColor: Colors.red)
         );
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }
}
