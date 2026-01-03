# Обработчик команды /history
@bot.message_handler(commands=['history'])
def history_command(message):
    user_id = message.from_user.id
    conn = sqlite3.connect(DB_PATH)
    
    try:
        cursor = conn.cursor()
        
        # Получаем список уникальных групп
        cursor.execute('''
            SELECT DISTINCT user_group
            FROM diagnostic_logs 
            WHERE user_id = ? AND user_group IS NOT NULL
            ORDER BY user_group
        ''', (user_id,))
        groups = [row[0] for row in cursor.fetchall()]

        # Получаем записи без группы
        cursor.execute('''
            SELECT id, birth_date, name 
            FROM diagnostic_logs 
            WHERE user_id = ? AND user_group IS NULL
            ORDER BY calculation_date DESC 
            LIMIT 60
        ''', (user_id,))
        entries = cursor.fetchall()

        markup = types.InlineKeyboardMarkup()

        # Добавляем кнопки групп
        for group in groups:
            markup.add(types.InlineKeyboardButton(
                f"📁 {group}", 
                callback_data=f'group_{group}'
            ))

        # Добавляем отдельные записи без группы
        for entry in entries:
            entry_id, birth_date, name = entry
            markup.add(types.InlineKeyboardButton(
                f"{birth_date} - {name}", 
                callback_data=f'view_calc_{entry_id}'
            ))

        markup.row(
            types.InlineKeyboardButton("◀️ Назад", callback_data='back_to_pgmd'),
            types.InlineKeyboardButton("❌ Закрыть", callback_data='delete_history_msg')
        )

        bot.send_message(
            message.chat.id,
            "📂 История расчетов:",
            reply_markup=markup
        )

    except Exception as e:
        print(f"Error: {e}")
        bot.send_message(message.chat.id, "⛔ Ошибка загрузки истории")
    finally:
        conn.close()

