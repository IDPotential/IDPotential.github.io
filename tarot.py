# calculations/tarot_calculator.py
import datetime
from typing import Dict, Any

class TarotCalculator:
    """Калькулятор арканов Таро по дате рождения"""
    
    # Соответствие чисел арканам
    ARCANA_MAP = {
        1: {"name": "Маг", "meaning": "Воля, инициатива, мастерство"},
        2: {"name": "Жрица", "meaning": "Интуиция, тайна, подсознание"},
        3: {"name": "Императрица", "meaning": "Плодородие, изобилие, природа"},
        # ... все 22 аркана
        22: {"name": "Шут", "meaning": "Начало, невинность, спонтанность"}
    }
    
    @staticmethod
    def calculate_life_path_number(birth_date: datetime.date) -> int:
        """Расчет числа жизненного пути"""
        total = sum(int(d) for d in birth_date.strftime("%d%m%Y"))
        while total > 22:
            total = sum(int(d) for d in str(total))
        return total if total != 0 else 22
    
    @staticmethod
    def calculate_personality_card(day: int) -> int:
        """Аркан личности по дню рождения"""
        if day >= 1 and day <= 31:
            card = day
            while card > 22:
                card -= 22
            return card
        return 0
    
    @staticmethod
    def calculate_soul_card(month: int) -> int:
        """Аркан души по месяцу рождения"""
        card = month
        while card > 22:
            card -= 22
        return card
    
    def calculate_all(self, birth_date: datetime.date) -> Dict[str, Any]:
        """Полный расчет Таро"""
        day = birth_date.day
        month = birth_date.month
        
        life_path = self.calculate_life_path_number(birth_date)
        personality = self.calculate_personality_card(day)
        soul = self.calculate_soul_card(month)
        
        return {
            "life_path": {
                "number": life_path,
                "arcana": self.ARCANA_MAP.get(life_path)
            },
            "personality": {
                "number": personality,
                "arcana": self.ARCANA_MAP.get(personality)
            },
            "soul": {
                "number": soul,
                "arcana": self.ARCANA_MAP.get(soul)
            },
            "calculation_date": datetime.datetime.now().isoformat()
        }