import 'package:flutter/material.dart';

class PythagorasMatrixWidget extends StatelessWidget {
  final List<List<int>> matrix;

  const PythagorasMatrixWidget({super.key, required this.matrix});

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        const Text("Психоматрица Пифагора", style: TextStyle(fontWeight: FontWeight.bold)),
        const SizedBox(height: 8),
        Container(
          width: 200,
          decoration: BoxDecoration(
            border: Border.all(color: Colors.grey),
          ),
          child: Column(
            children: [
              _buildRow(matrix[0], 1), // 1, 4, 7 (Actually rows are rows: [1s, 4s, 7s] wait. 
              // Row 0 of matrix usually means 1, 4, 7? Or standard grid layout?
              // Pythagoras matrix layout:
              // 1 4 7
              // 2 5 8
              // 3 6 9
              // OR
              // 1 2 3
              // 4 5 6
              // 7 8 9
              // Python code: `row = (digit - 1) // 3`, `col = (digit - 1) % 3`.
              // digit 1 -> r0, c0. digit 2 -> r0, c1. digit 3 -> r0, c2.
              // So stored as:
              // [[count1, count2, count3], [count4, count5, count6], [count7, count8, count9]]
              // Standard layout is likely:
              // 1 4 7
              // 2 5 8 
              // 3 6 9
              // Let's verify standard pythagoras square layout. Usually rows are 111 44 77, columns 123 456 789.
              // Wait, standard view:
              // 1 4 7
              // 2 5 8
              // 3 6 9
              // Let's implement that transposition.
              _buildTransposedRow(matrix, 0),
              _buildTransposedRow(matrix, 1),
              _buildTransposedRow(matrix, 2),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildRow(List<int> rowData, int startNum) { // not used if transposing
    return Row(
      children: [
        _buildCell(rowData[0], startNum),
        _buildCell(rowData[1], startNum + 1),
        _buildCell(rowData[2], startNum + 2),
      ],
    );
  }

  Widget _buildTransposedRow(List<List<int>> m, int colIndex) {
    // Show m[0][colIndex] (d1,2,3), m[1][colIndex], m[2][colIndex]
    // Wait. My calculation logic:
    // digit 1 (row 0, col 0), digit 2 (row 0, col 1), digit 3 (row 0, col 2)
    // digit 4 (row 1, col 0)...
    // So stored matrix is:
    // [ [1s, 2s, 3s], [4s, 5s, 6s], [7s, 8s, 9s] ]
    //
    // Display desired:
    // 1s  4s  7s
    // 2s  5s  8s
    // 3s  6s  9s
    
    // So row 1 of display uses: matrix[0][0], matrix[1][0], matrix[2][0] => Digits 1, 4, 7
    // row 2 uses: matrix[0][1], matrix[1][1], matrix[2][1] => Digits 2, 5, 8
    // row 3 uses: matrix[0][2], matrix[1][2], matrix[2][2] => Digits 3, 6, 9
    
    final d1 = (colIndex + 1); // 1, 2, 3
    final d2 = (colIndex + 1) + 3; // 4, 5, 6
    final d3 = (colIndex + 1) + 6; // 7, 8, 9
    
    // cell values
    final c1 = m[0][colIndex];
    final c2 = m[1][colIndex];
    final c3 = m[2][colIndex];
    
    return Row(
      children: [
        _buildCell(c1, d1),
        _buildCell(c2, d2),
        _buildCell(c3, d3),
      ],
    );
  }

  Widget _buildCell(int count, int digit) {
    // Content string: "11" or "4" or "-"
    String text = "";
    if (count == 0) {
      text = "-";
    } else {
      text = "$digit" * count;
    }

    return Expanded(
      child: Container(
        height: 50,
        decoration: BoxDecoration(
          border: Border.all(color: Colors.grey),
        ),
        child: Center(
          child: Text(
            text,
            style: const TextStyle(fontSize: 16),
          ),
        ),
      ),
    );
  }
}
