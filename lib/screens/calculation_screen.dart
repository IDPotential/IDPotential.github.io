import 'package:flutter/material.dart';
import '../services/calculator_service.dart';
import '../services/database_service.dart';
import 'result_screen.dart';
import 'history_screen.dart';
import '../models/calculation.dart';
import '../services/firestore_service.dart';

class CalculationScreen extends StatefulWidget {
  final Calculation? existingCalculation; // Optional parameter for editing

  const CalculationScreen({super.key, this.existingCalculation});

  @override
  State<CalculationScreen> createState() => _CalculationScreenState();
}


class _CalculationScreenState extends State<CalculationScreen> {
  final _formKey = GlobalKey<FormState>();
  final _nameController = TextEditingController();
  final _dateController = TextEditingController();
  String _gender = 'М';
  String _selectedSystem = 'idp'; // 'idp' or 'classic'
  bool _isCalculating = false;
  final FirestoreService _firestoreService = FirestoreService();
  
  @override
  void initState() {
    super.initState();
    if (widget.existingCalculation != null) {
      _nameController.text = widget.existingCalculation!.name;
      _dateController.text = widget.existingCalculation!.birthDate;
      _gender = widget.existingCalculation!.gender;
      _selectedSystem = widget.existingCalculation!.type; // Load existing type
    }
  }
  
  @override
  void dispose() {
    _nameController.dispose();
    _dateController.dispose();
    super.dispose();
  }
  
  Future<void> _calculate() async {
    if (!_formKey.currentState!.validate()) return;
    
    setState(() {
      _isCalculating = true;
    });
    
    try {
      List<int> numbers = [];
      Map<String, dynamic>? extraData;

      if (_selectedSystem == 'classic') {
        final result = CalculatorService.calculateClassic(_dateController.text);
        // Store working numbers in 'numbers' for convenience if desired
        if (result['pythagoras'] != null && result['pythagoras']['workingNumbers'] != null) {
           numbers = (result['pythagoras']['workingNumbers'] as List).cast<int>();
        }
        extraData = result;
      } else {
        // IDP
        numbers = CalculatorService.calculateDiagnostic(
          _dateController.text,
          _nameController.text,
          _gender,
        );
      }
      
      // Создание объекта расчета
      final calculation = Calculation(
        name: _nameController.text,
        birthDate: _dateController.text,
        gender: _gender,
        numbers: numbers,
        createdAt: widget.existingCalculation?.createdAt ?? DateTime.now(), // Keep original date if editing
        group: widget.existingCalculation?.group, // Keep original group
        decryption: widget.existingCalculation?.decryption ?? 0, // Keep paid status
        type: _selectedSystem,
        extraData: extraData,
      );
      
      String id;
      if (widget.existingCalculation != null && widget.existingCalculation!.firebaseId != null) {
        // UPDATE (No charge)
        id = widget.existingCalculation!.firebaseId!;
        await _firestoreService.updateCalculation(id, calculation);
      } else {
        // CREATE (Charge 5 credits)
        final bool success = await _firestoreService.consumeCredit(5);
        if (!success) {
           throw Exception("Недостаточно кредитов! Требуется 5 кр.");
        }
        id = await _firestoreService.saveCalculation(calculation);
      }

      final savedCalculation = calculation.copyWith(firebaseId: id);
      
      // Переход к результатам
      if (!mounted) return;
      
      Navigator.pushReplacement(
        context,
        MaterialPageRoute(
          builder: (context) => ResultScreen(
            calculation: savedCalculation,
          ),
        ),
      );
      
    } catch (e, stackTrace) {
      debugPrint('Error caught: $e');
      debugPrint('Stack trace: $stackTrace');
      
      if (!mounted) return;
      
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Ошибка расчета: $e'),
          backgroundColor: Colors.red,
        ),
      );
    } finally {
      if (mounted) {
        setState(() {
          _isCalculating = false;
        });
      }
    }
  }
  
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(widget.existingCalculation != null ? 'Редактирование' : 'Новый расчет'),
        actions: [
          IconButton(
            icon: const Icon(Icons.history),
            onPressed: () {
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (context) => const HistoryScreen(),
                ),
              );
            },
            tooltip: 'История',
          ),
        ],
      ),
      body: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 800),
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(16.0),
        child: Form(
          key: _formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Информация
              Card(
                child: Padding(
                  padding: const EdgeInsets.all(16.0),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Введите данные для расчета',
                        style: Theme.of(context).textTheme.titleMedium,
                      ),
                      const SizedBox(height: 8),
                      Text(
                        'Формат даты: ДД.ММ.ГГГГ\nПример: 25.05.1990',
                        style: Theme.of(context).textTheme.bodySmall,
                      ),
                    ],
                  ),
                ),
              ),
              
              const SizedBox(height: 20),
              
              // Поле для имени
              TextFormField(
                controller: _nameController,
                decoration: const InputDecoration(
                  labelText: 'Имя',
                  prefixIcon: Icon(Icons.person),
                  border: OutlineInputBorder(),
                ),
                validator: (value) {
                  if (value == null || value.isEmpty) {
                    return 'Введите имя';
                  }
                  return null;
                },
              ),
              
              const SizedBox(height: 16),
              
              // Поле для даты
              TextFormField(
                controller: _dateController,
                decoration: const InputDecoration(
                  labelText: 'Дата рождения',
                  hintText: 'ДД.ММ.ГГГГ',
                  prefixIcon: Icon(Icons.calendar_today),
                  border: OutlineInputBorder(),
                ),
                onChanged: (value) {
                  String text = value;
                  
                  // 1. Replace common separators with dots
                  text = text.replaceAll(RegExp(r'[\/,\-\s]'), '.');

                  // 2. Remove any non-allowed characters (keep digits and dots)
                  text = text.replaceAll(RegExp(r'[^\d.]'), '');

                  // 3. Auto-insert dots Logic
                  // if user is deleting, do not auto-insert (simple check: length decreased?)
                  // We need previous value to know if deleting. but standard onChanged doesn't give previous.
                  // for simple "forward" typing:
                  if (text.length > value.length) { 
                     // implied paste or insert
                  }
                  
                  // Clean text to just digits for re-formatting logic
                  String digitsOnly = text.replaceAll('.', '');
                  
                  // If we have exactly 8 digits and no dots, assume full fast input/paste (01012000)
                  if (digitsOnly.length == 8 && !text.contains('.')) {
                     text = '${digitsOnly.substring(0, 2)}.${digitsOnly.substring(2, 4)}.${digitsOnly.substring(4)}';
                  } 
                  // If typing normally (e.g. 01 -> 01.), check standard positions
                  else if (text.length == 2 && !text.contains('.')) {
                      text += '.';
                  } else if (text.length == 5 && text[2] == '.' && !text.substring(3).contains('.')) {
                      text += '.';
                  }

                  // Update controller if text changed
                  if (text != value) {
                    _dateController.value = TextEditingValue(
                      text: text,
                      selection: TextSelection.collapsed(offset: text.length),
                    );
                  }
                },
                keyboardType: TextInputType.datetime,
                validator: (value) {
                  if (value == null || value.isEmpty) {
                    return 'Введите дату рождения';
                  }
                  
                  // Проверка формата даты
                  final regex = RegExp(r'^\d{2}\.\d{2}\.\d{4}$');
                  if (!regex.hasMatch(value)) {
                    return 'Используйте формат ДД.ММ.ГГГГ';
                  }
                  
                  return null;
                },
              ),
              
              const SizedBox(height: 16),
              
               // Система расчета
              Card(
                child: Padding( 
                  padding: const EdgeInsets.all(16.0),
                  child: Column( 
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                       Text(
                        'Система расчета',
                        style: Theme.of(context).textTheme.titleSmall,
                      ),
                      const SizedBox(height: 8),
                      // Using Segmented Button for System Choice
                      SizedBox(
                        width: double.infinity,
                        child: SegmentedButton<String>(
                          segments: const [
                            ButtonSegment<String>(
                              value: 'idp',
                              label: Text('ИДП'),
                              icon: Icon(Icons.psychology),
                            ),
                            ButtonSegment<String>(
                              value: 'classic',
                              label: Text('Классика'),
                              icon: Icon(Icons.star), // or 'layers'
                            ),
                          ],
                          selected: {_selectedSystem},
                          onSelectionChanged: (Set<String> newSelection) {
                            setState(() {
                              _selectedSystem = newSelection.first;
                            });
                          },
                        ),
                      ),
                      const SizedBox(height: 4),
                       Text(
                        _selectedSystem == 'idp' 
                            ? 'Индивидуальная Диагностика Потенциала' 
                            : 'Таро + Квадрат Пифагора',
                        style: Theme.of(context).textTheme.bodySmall,
                      ),
                    ],
                  ),
                ),
              ),

              const SizedBox(height: 16),
              
              // Выбор пола
              Card(
                child: Padding(
                  padding: const EdgeInsets.all(16.0),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Пол',
                        style: Theme.of(context).textTheme.titleSmall,
                      ),
                      const SizedBox(height: 8),
                      SegmentedButton<String>(
                        segments: const [
                          ButtonSegment<String>(
                            value: 'М',
                            label: Text('Мужской'),
                            icon: Icon(Icons.male),
                          ),
                          ButtonSegment<String>(
                            value: 'Ж',
                            label: Text('Женский'),
                            icon: Icon(Icons.female),
                          ),
                        ],
                        selected: {_gender},
                        onSelectionChanged: (Set<String> newSelection) {
                          setState(() {
                            _gender = newSelection.first;
                          });
                        },
                      ),
                    ],
                  ),
                ),
              ),
              
              const SizedBox(height: 24),
              
              // Кнопка расчета
              SizedBox(
                width: double.infinity,
                height: 50,
                child: ElevatedButton(
                  onPressed: _isCalculating ? null : _calculate,
                  style: ElevatedButton.styleFrom(
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                  child: _isCalculating
                      ? const CircularProgressIndicator(color: Colors.white)
                      : Text(
                          widget.existingCalculation != null ? 'Сохранить изменения' : 'Рассчитать',
                          style: const TextStyle(fontSize: 18),
                        ),
                ),
              ),
              if (widget.existingCalculation == null)
                const Padding(
                  padding: EdgeInsets.only(top: 8.0),
                  child: Center(
                    child: Text(
                      'Стоимость расчета: 5 кредитов',
                      style: TextStyle(color: Colors.grey, fontSize: 12),
                    ),
                  ),
                ),
            ],
          ),
          ),
        ),
      ),
      ),
    );
  }
}