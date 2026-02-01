# calculations/pythagoras_calculator.py
import numpy as np
from typing import List, Dict, Any

class PythagorasCalculator:
    """Калькулятор психоматрицы Пифагора"""
    
    QUALITY_MEANINGS = {
        1: {"name": "Характер", "description": "Сила воли, целеустремленность"},
        2: {"name": "Энергия", "description": "Жизненная сила, харизма"},
        3: {"name": "Интерес", "description": "Познание, технические наклонности"},
        4: {"name": "Здоровье", "description": "Физическое состояние, потенциал"},
        5: {"name": "Логика", "description": "Аналитические способности"},
        6: {"name": "Труд", "description": "Склонность к физическому труду"},
        7: {"name": "Удача", "description": "Везение, успех"},
        8: {"name": "Долг", "description": "Чувство ответственности"},
        9: {"name": "Память", "description": "Интеллект, память, ум"}
    }
    
    def __init__(self):
        self.matrix = np.zeros((3, 3), dtype=int)
    
    def _get_working_numbers(self, birth_date: str) -> List[int]:
        """Расчет рабочих чисел"""
        # Убираем точки и пробелы
        clean_date = ''.join(c for c in birth_date if c.isdigit())
        
        # Первое число - сумма всех цифр
        first = sum(int(d) for d in clean_date)
        
        # Второе число - сумма цифр первого
        second = sum(int(d) for d in str(first))
        
        # Третье число
        day_digits = [int(d) for d in clean_date[:2]]
        first_digit_day = day_digits[0] if day_digits[0] != 0 else day_digits[1]
        third = first - (2 * first_digit_day)
        
        # Четвертое число - сумма цифр третьего
        fourth = sum(int(d) for d in str(third))
        
        return [first, second, third, fourth]
    
    def calculate_matrix(self, birth_date: str) -> np.ndarray:
        """Расчет и заполнение матрицы"""
        day, month, year = birth_date.split('.')
        
        # Все цифры для подсчета
        all_digits = []
        
        # Цифры даты
        all_digits.extend([int(d) for d in day])
        all_digits.extend([int(d) for d in month])
        all_digits.extend([int(d) for d in year])
        
        # Цифры рабочих чисел
        working_nums = self._get_working_numbers(birth_date)
        for num in working_nums:
            all_digits.extend([int(d) for d in str(num)])
        
        # Подсчет количества каждой цифры (1-9)
        for digit in range(1, 10):
            count = all_digits.count(digit)
            # Позиция в матрице
            row = (digit - 1) // 3
            col = (digit - 1) % 3
            self.matrix[row][col] = count
        
        return self.matrix
    
    def analyze_energy(self) -> Dict[str, Any]:
        """Анализ энергетики матрицы"""
        analysis = {}
        
        # Количественный анализ
        for digit in range(1, 10):
            count = self.matrix[(digit-1)//3][(digit-1)%3]
            meaning = self.QUALITY_MEANINGS.get(digit)
            
            # Определение силы качества
            if count == 0:
                strength = "отсутствует"
            elif count == 1:
                strength = "слабое"
            elif count == 2:
                strength = "нормальное"
            elif count == 3:
                strength = "сильное"
            else:
                strength = "избыточное"
            
            analysis[str(digit)] = {
                "count": count,
                "strength": strength,
                "meaning": meaning
            }
        
        return analysis
    
    def calculate_all(self, birth_date: str) -> Dict[str, Any]:
        """Полный расчет матрицы"""
        matrix = self.calculate_matrix(birth_date)
        
        return {
            "matrix": matrix.tolist(),
            "working_numbers": self._get_working_numbers(birth_date),
            "analysis": self.analyze_energy(),
            "visualization": {
                "type": "3x3_grid",
                "labels": ["Характер", "Энергия", "Интерес",
                          "Здоровье", "Логика", "Труд",
                          "Удача", "Долг", "Память"]
            }
        }