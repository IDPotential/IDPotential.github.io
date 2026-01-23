import 'package:flutter/material.dart';
import '../widgets/role_info_dialog.dart';

class UserMatrixWidget extends StatelessWidget {
  final List<int> matrix;
  final int? selectedRole;
  final Function(int)? onRoleTap;
  final bool isInteractive;

  const UserMatrixWidget({
    super.key,
    required this.matrix,
    this.selectedRole,
    this.onRoleTap,
    this.isInteractive = true,
  });

  @override
  Widget build(BuildContext context) {
    // Logic: Unique, sorted, 0->22
    final Set<int> uniqueNumbers = {};
    for (var n in matrix) {
      if (n > 0 && n <= 22) uniqueNumbers.add(n);
      if (n == 0) uniqueNumbers.add(22);
    }
    
    // Fallback if empty (e.g. invalid calc) - optional, or show empty
    // TrainingGame logic showed 1-22 if empty, but for Profile maybe we want to show nothing or message?
    // Let's keep the TrainingGame logic for consistency if passed empty list, 
    // BUT usually the parent should handle "No Matrix" state.
    // However, the original code had: if (uniqueNumbers.isEmpty) uniqueNumbers.addAll(List.generate(22, (i) => i + 1));
    // We will preserve this behavior if the parent passes an empty list but expects a grid. 
    // Ideally, parent passes non-empty list.
    
    if (uniqueNumbers.isEmpty && isInteractive) {
       // If in game mode (interactive) and empty, maybe show all options?
       // Original code: if (uniqueNumbers.isEmpty) { uniqueNumbers.addAll(List.generate(22, (i) => i + 1)); }
       // We'll trust the parent to pass the correct data, but for safety lets mimic original if strictly needed.
       // Actually, let's just render what is given. If uniqueNumbers is empty, we render nothing.
    }

    final sortedNumbers = uniqueNumbers.toList()..sort();

    if (sortedNumbers.isEmpty) return const SizedBox.shrink();

    return LayoutBuilder(
      builder: (context, constraints) {
        // Responsive grid logic from original
        int crossAxisCount = constraints.maxWidth > 600 ? 7 : 5;
        
        return GridView.builder(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: crossAxisCount,
            childAspectRatio: 0.7,
            crossAxisSpacing: 8,
            mainAxisSpacing: 8,
          ),
          itemCount: sortedNumbers.length,
          itemBuilder: (context, index) {
            final number = sortedNumbers[index];
            final isSelected = selectedRole == number;
            
            return GestureDetector(
              onTap: () {
                if (!isInteractive) return;
                
                if (onRoleTap != null) {
                  onRoleTap!(number);
                } else {
                   // Default behavior: Show Dialog
                   showDialog(
                     context: context,
                     builder: (ctx) => RoleInfoDialog(
                       roleNumber: number,
                       canSelect: false, // In profile we just view
                     ),
                   );
                }
              },
              child: Container(
                decoration: BoxDecoration(
                  border: isSelected ? Border.all(color: Colors.orange, width: 3) : null,
                  borderRadius: BorderRadius.circular(8),
                  boxShadow: isSelected ? [BoxShadow(color: Colors.orange.withValues(alpha: 0.5), blurRadius: 8)] : null,
                ),
                child: Card(
                  clipBehavior: Clip.antiAlias, 
                  margin: EdgeInsets.zero, 
                  elevation: isSelected ? 8 : 2,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      Expanded(
                        child: Image.asset(
                          'assets/images/cards/role_$number.png', 
                          fit: BoxFit.cover, 
                          errorBuilder: (c,e,s)=>const Icon(Icons.image_not_supported)
                        ),
                      ),
                      Container(
                        color: isSelected ? Colors.orange : Colors.black54,
                        padding: const EdgeInsets.symmetric(vertical: 2),
                        child: Text(
                          '$number', 
                          textAlign: TextAlign.center, 
                          style: const TextStyle(fontSize: 12, color: Colors.white, fontWeight: FontWeight.bold)
                        ),
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
}
