@bot.callback_query_handler(func=lambda call: call.data.startswith('text_format_'))
def show_saved_text_format(call):
    try:
        calc_id = int(call.data.split('_')[2])
        
        conn = sqlite3.connect(DB_PATH)
        cursor = conn.cursor()
        
        cursor.execute('''
            SELECT dr.num1, dr.num2, dr.num3, dr.num4, dr.num5, dr.num6, dr.num7, dr.num8,
                   dr.num9, dr.num10, dr.num11, dr.num12, dr.num13, dr.num14,
                   dl.birth_date, dl.name, dl.gender
            FROM diagnostic_results dr
            JOIN diagnostic_logs dl ON dr.log_id = dl.id
            WHERE dr.log_id = ?
        ''', (calc_id,))
        
        data = cursor.fetchone()

        if data:
            # Форматируем значения с названиями зон и глубокими ссылками на числа
            formatted_values = [get_zone_name_with_links(num) for num in data[:14]]

        elif not data:
            bot.answer_callback_query(call.id, "❌ Расчет не найден")
            return

        # Списки категорий
        CATEGORIES = {
            "Антагонисты": [0, 1, 3, 4, 5, 7, 13, 15, 16],
            "Союзники": [2, 3, 6, 8, 10, 12, 14, 20, 21],
            "Нейтральные (усилители)": [9, 11, 17, 18, 19],
            "Мужские зоны": [4, 5, 6, 8, 10],
            "Женские зоны": [2, 3, 9, 12, 21],
            "Детские": [1,2,3,4,5,6,7,8,9,10],
            "Подростковые": [11,12,13,14,15,16,17],
            "Старшие": [18,19,20,21,0],
            "Пространственные": [1,2,3,4,6,8,10,11,12,14,18,21,0],
            "Временные": [5,7,9,11,13,17,16,18,19,20,0]
        }

        # Собираем уникальные зоны из результатов
        all_zones = set(data[:14])

        # Считаем частоту встречаемости чисел
        frequency = {}
        for num in data[:14]:
            frequency[num] = frequency.get(num, 0) + 1

        # Формируем новые категории с глубокими ссылками на числа
        accents = [get_zone_link_number(num) for num in [k for k, v in frequency.items() if v == 2]]
        dominants = [get_zone_link_number(num) for num in [k for k, v in frequency.items() if v == 3]]
        neurosis = [get_zone_link_number(num) for num in [k for k, v in frequency.items() if v >= 4]]

        category_description = "\n🔍 Особые зоны в вашей диагностике:\n"
        if accents:
            category_description += f"▫️ *Акценты (2 раза):* {', '.join(accents)}\n"

        if dominants:
            category_description += f"▫️ *Доминанты (3 раза):* {', '.join(dominants)}\n"

        if neurosis:
            category_description += f"▫️ *Невроз (4+ раз):* {', '.join(neurosis)}\n"
        
        for category, numbers in CATEGORIES.items():
            found = [get_zone_link_number(z) for z in all_zones if z in numbers]
            if found:
                category_description += f"▫️ *{category}:* {', '.join(found)}\n"
        
        # Расчет невроза социальной динамики
        birth_date = data[14]
        name = data[15]
        gender = data[16]
        x = data[3] + data[10]
        x += data[5] if gender == 'Ж' else data[6]
        y = x + data[12]
        
        # Корректировка значения
        if x > 22:
            x = x - 22
            if x > 22:
                x = x - 22
        elif x == 22:
            x = 0

        if y > 22:
            y = y - 22
            if y > 22:
                y = y - 22
                if y > 22:
                    y = y - 22
        elif y == 22:
            y = 0

        formatted_x = get_zone_name_with_links(x)
        formatted_y = get_zone_name_with_links(y)

        # НОВЫЙ ФОРМАТ ДЛЯ БЛОКА ИНЬ/ЯН БАЛАНСА С ССЫЛКАМИ
        # Получаем данные для дуальностей
        female_inner = data[5]
        female_outer = data[4]
        male_inner = data[6]
        male_outer = data[7]
        
        # Формируем строки для женской и мужской дуальностей с ссылками
        female_duality_text = (
            f"♀️ Женская дуальность (межличностные отношения): {get_aspect_link(female_inner, female_outer)}\n"
            f"Внутренняя суть в отношениях:  {get_zone_name_with_links(female_inner)}\n"
            f"Внешнее проявление в отношениях: {get_zone_name_with_links(female_outer)}"
        )
        
        male_duality_text = (
            f"♂️ Мужская дуальность (реализация в социуме): {get_aspect_link(male_inner, male_outer)}\n"
            f"Внутренняя суть реализации:  {get_zone_name_with_links(male_inner)}\n"
            f"Внешнее проявление реализации: {get_zone_name_with_links(male_outer)}"
        )

        # Формируем расширенное текстовое описание с новым форматом дуальностей
        base_description = f"""
*{name} ({birth_date})*
*Текстовая версия:*

I – Третичная фаза (непроявленное)
▫️ 0-30 лет:     {formatted_values[0]}
▫️ 30-60 лет:    {formatted_values[1]}
▫️ 60-90 лет:    {formatted_values[2]}
🔹 Точка входа:     {formatted_values[3]}

II – Инь/Ян баланс
{female_duality_text}

{male_duality_text}

III – Ядро мотивации
🎯 Основной мотив:  {formatted_values[8]}

IV – Реализация в социуме
🛠 Способ действия:  {formatted_values[9]}
🌐 Сфера реализации:     {formatted_values[10]}

V – Точка гармонии
🚪 Точка выхода:     {formatted_values[12]}
💭 Внутренний мир, страхи:  {formatted_values[11]}
⚖️ Баланс внешнего/внутреннего:  {formatted_values[13]}

🧠 Поведение в стрессе: {formatted_x}
⚖️ Баланс в стрессе: {formatted_y}
        """
        
        full_description = base_description + category_description
        
        # Кнопки управления
        markup = types.InlineKeyboardMarkup()
        markup.add(
            types.InlineKeyboardButton("📋 Подробнее (20 кр)", callback_data=f'detailed_desc_{calc_id}'),
            types.InlineKeyboardButton("❌ Закрыть", callback_data='delete_history_msg')
        )
        
        bot.send_message(
            call.message.chat.id,
            full_description,
            parse_mode="Markdown",
            reply_markup=markup,
            disable_web_page_preview=True
        )
    except IndexError:
        bot.answer_callback_query(call.id, "❌ Ошибка формата запроса")
    except Exception as e:
        bot.send_message(call.message.chat.id, f"⛔ Ошибка: {str(e)}")
    finally:
        conn.close()

def get_zone_role_name(number: int) -> str:
    """Получает только название роли по номеру зоны"""
    adjusted_number = 22 if number == 0 else number
    zone = ZONES.get(adjusted_number, {})
    return zone.get('role_name', '???')

# Функция для получения названия зоны со ссылкой только на число
def get_zone_name_with_links(number: int) -> str:
    adjusted_number = 22 if number == 0 else number
    zone = ZONES.get(adjusted_number, {})
    
    zone_name = zone.get('role_name', '???')
    deep_link = f"https://t.me/id_potential_bot?start=role_{number}"
    
    # Ссылка только на число, название без ссылки
    return f"[{number} ({zone_name})]({deep_link})"

# Функция для получения только номера зоны с глубокой ссылкой (для списков)
def get_zone_link_number(number: int) -> str:
    deep_link = f"https://t.me/id_potential_bot?start=role_{number}"
    return f"[{number}]({deep_link})"

# Функция для создания ссылки на аспект для дуальностей
def get_aspect_link(num1: int, num2: int) -> str:
    aspect_key = f"{num1}-{num2}"
    deep_link = f"https://t.me/id_potential_bot?start=aspect_{aspect_key}"
    return f"[{num1} → {num2}]({deep_link})"
