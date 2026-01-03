import matplotlib
matplotlib.use('Agg') 
import matplotlib.pyplot as plt
import json
import os
from urllib.parse import quote
import telebot
import sqlite3
import pandas as pd
import seaborn as sns
from sklearn.preprocessing import StandardScaler
from sklearn.cluster import KMeans
from sklearn.manifold import TSNE
from telebot import types
import time
from datetime import datetime
from PIL import Image, ImageDraw, ImageFont
import io  
import tempfile

from data_libraries import VIDEOS, ZONES, ASPECTS, ASPECTS_ROLE # pyright: ignore[reportMissingImports]

deposit_requests = {}
broadcast_data = {}

# --- FIREBASE ADAPTER ---
from firebase_adapter import init_firebase, fb_get_user, fb_register_user, fb_check_access, fb_get_credits, fb_deduct_credits, fb_add_log, fb_get_history, fb_create_custom_token, fb_get_log, fb_mark_log_paid, fb_delete_log, fb_update_log_group, get_db

init_firebase()
# ------------------------

# Указываем абсолютный путь (LEGACY - оставлено для совместимости старых функций, если они есть)
DB_PATH = os.path.abspath("D:\BOT\ID_DB.sqlite")
DB_PATH2 = os.path.abspath("D:\BOT\PGMD.sqlite") 
print(f"[DEBUG] Путь к базе: {DB_PATH}")

# Проверяем существование файла
if not os.path.exists(DB_PATH):
    raise FileNotFoundError(f"Файл базы данных {DB_PATH} не найден!")

# Инициализация бота
# id_potential_bot
TOKEN = '7733163279:AAEQLGDiAP8LZlmUMjIdlTojikBm4TtN_Pg'
# test
# TOKEN = '8290935990:AAGzVW2U-Kb5M4DFbIsP5-VUGT-7l117vfc'
bot = telebot.TeleBot(TOKEN)
ADMIN_ID = 196473271

# Создание таблиц в базе данных
def create_tables():
    conn = sqlite3.connect(DB_PATH)
    cursor = conn.cursor()
        
        # Добавляем log_id в diagnostic_results
    cursor.execute('''
        CREATE TABLE IF NOT EXISTS diagnostic_results (
            id INTEGER PRIMARY KEY AUTOINCREMENT,
            log_id INTEGER,
            num1 INTEGER, num2 INTEGER, num3 INTEGER, num4 INTEGER,
            num5 INTEGER, num6 INTEGER, num7 INTEGER, num8 INTEGER,
            num9 INTEGER, num10 INTEGER, num11 INTEGER, num12 INTEGER,
            num13 INTEGER, num14 INTEGER,
            calculation_date DATETIME DEFAULT CURRENT_TIMESTAMP
        )
    ''')
    
    # Добавляем недостающие колонки если нужно
    try:
        cursor.execute("ALTER TABLE diagnostic_results ADD COLUMN log_id INTEGER")
    except sqlite3.OperationalError:
        pass  
    
    # Создаем индекс для связи по дате
    cursor.execute('''
        CREATE INDEX IF NOT EXISTS idx_results_date 
        ON diagnostic_results(calculation_date)
    ''')

    # Таблица Partn
    cursor.execute('''
        CREATE TABLE IF NOT EXISTS Partn (
            id INTEGER PRIMARY KEY AUTOINCREMENT,
            user_id INTEGER UNIQUE,
            user_name TEXT,
            user_surname TEXT,
            username TEXT,
            perf_id INTEGER,
            name TEXT,
            bill INTEGER,
            phone TEXT,
            pgmd INTEGER DEFAULT 0
        )
    ''')
    
    # Таблица course
    cursor.execute('''
        CREATE TABLE IF NOT EXISTS course (
            id INTEGER PRIMARY KEY AUTOINCREMENT,
            user_id INTEGER UNIQUE,
            user_name TEXT,
            quest INTEGER DEFAULT 0,
            snv INTEGER DEFAULT 0,
            snv2 INTEGER DEFAULT 0,
            snv_asist INTEGER DEFAULT 0,
            snv2_asist INTEGER DEFAULT 0,
            sbs INTEGER DEFAULT 0,
            sbs_asist INTEGER DEFAULT 0,
            stud INTEGER DEFAULT 0,
            stud_pract INTEGER DEFAULT 0,
            golden INTEGER DEFAULT 0,
            xplay INTEGER DEFAULT 0,
            xplay_asist INTEGER DEFAULT 0
        )
    ''')
    
    # Таблица diagnostic_results
    cursor.execute('''
        CREATE TABLE IF NOT EXISTS diagnostic_results (
            id INTEGER PRIMARY KEY AUTOINCREMENT,
            user_id INTEGER NOT NULL,
            log_id INTEGER NOT NULL,
            num1 INTEGER, num2 INTEGER, num3 INTEGER, num4 INTEGER,
            num5 INTEGER, num6 INTEGER, num7 INTEGER, num8 INTEGER,
            num9 INTEGER, num10 INTEGER, num11 INTEGER, num12 INTEGER,
            num13 INTEGER, num14 INTEGER,
            FOREIGN KEY (log_id) REFERENCES diagnostic_logs(id)
        )
    ''')
    
    
    conn.commit()
    conn.close()

# Создание таблиц при запуске
create_tables()

def migrate_data():
    conn = sqlite3.connect(DB_PATH)
    cursor = conn.cursor()
    
    # Используем явное соединение по временной метке
    cursor.execute('''
        UPDATE diagnostic_results 
        SET log_id = (
            SELECT id 
            FROM diagnostic_logs 
            WHERE diagnostic_logs.user_id = diagnostic_results.user_id 
            AND DATE(diagnostic_logs.calculation_date) = DATE(diagnostic_results.calculation_date)
        )
        WHERE log_id IS NULL
    ''')

    
    conn.commit()
    conn.close()

@bot.message_handler(commands=['role'])
def role_command(message):
    user_id = message.from_user.id
    conn = sqlite3.connect(DB_PATH, check_same_thread=False)
    cursor = conn.cursor()
    
    try:
        cursor.execute('SELECT pgmd FROM Partn WHERE user_id = ?', (user_id,))
        result = cursor.fetchone()
        
        if not result or result[0] < 1:
            bot.send_message(message.chat.id, "❌ Доступ к разделу запрещен. Пройдите регистрацию через /start!")
            return
        
        # Показываем меню ролей (аналогично существующей функции)
        text = "🧠 Роль подсознания\nВыберите интересующий вас номер:"
        markup = types.InlineKeyboardMarkup(row_width=5)
        
        buttons = [types.InlineKeyboardButton(str(i), callback_data=f'video_{i}') for i in range(1, 22)]
        buttons.append(types.InlineKeyboardButton("22 (0)", callback_data='video_0'))
        
        for i in range(0, len(buttons), 5):
            markup.row(*buttons[i:i+5])
        
        markup.add(types.InlineKeyboardButton("❌ Закрыть", callback_data='delete_history_msg'))
        
        bot.send_message(message.chat.id, text, reply_markup=markup)
        
    finally:
        conn.close()

# Обработчик команды /history
# Обработчик команды /history
# Duplicate history_command removed (Legacy)



# Обработчик команды /calc
@bot.message_handler(commands=['calc'])
def calc_command(message):
    # Создаем fake call объект
    class FakeCall:
        def __init__(self, message):
            self.message = message
            self.from_user = message.from_user
            self.data = 'diagnostic_calc'
            self.id = message.message_id
    
    fake_call = FakeCall(message)
    start_diagnostic(fake_call)

# Обработчик команды /info
@bot.message_handler(commands=['info'])
def info_command(message):
    # Используем существующую функцию handle_balance
    handle_balance(message)

# Обработчик команды /menu (альтернатива /start)
@bot.message_handler(commands=['menu'])
def menu_command(message):
    main_menu(message)


@bot.message_handler(commands=['start'])
def start(message):
    # Создаем клавиатуру
    markup = types.ReplyKeyboardMarkup(resize_keyboard=True)
    markup.add(types.KeyboardButton('Открыть меню'))
    
    # Регистрируем пользователя
    db_table_val(
        user_id=message.from_user.id,
        user_name=message.from_user.first_name,
        user_surname=message.from_user.last_name,
        username=message.from_user.username,
        markup=markup,
        message=message
    )
    
    # Обработка глубоких ссылок ДО отправки приветствия
    if len(message.text.split()) > 1:
        param = message.text.split()[1]
        
        if param.startswith('aspect_'):
            try:
                aspect_key = param.split('_')[1]
                show_aspect_by_key(message.chat.id, aspect_key)
                return  # Прерываем выполнение после показа аспекта
            except (IndexError, ValueError):
                pass
                
        if param.startswith('role_'):
            try:
                role_number = int(param.split('_')[1])
                show_role_by_number(message.chat.id, role_number)
                return  # Прерываем выполнение после показа роли
            except (IndexError, ValueError):
                pass

    # Стандартное приветствие показывается ТОЛЬКО если нет параметров или они не распознаны
    welcome_text = (
        f'Привет, {message.from_user.first_name}!\n\n'
        '🤖 Я - бот для диагностики потенциала личности.\n\n'
        '📋 Доступные команды:\n'
        '• /start - начало работы\n'
        '• /role - роли подсознания\n' 
        '• /history - история расчетов\n'
        '• /calc - расчет диагностики\n'
        '• /info - личный кабинет\n'
        '• /menu - открыть меню\n\n'
        'Для навигации также используйте кнопку "Открыть меню" ниже 👇'
    )

    bot.send_message(message.chat.id, welcome_text, reply_markup=markup)

# Новая функция для показа аспекта по ключу (формат "x-y")
def show_aspect_by_key(chat_id, aspect_key):
    aspect_data = ASPECTS_ROLE.get(aspect_key, {})
    
    if not aspect_data:
        bot.send_message(chat_id, "Описание для этого аспекта не найдено!")
        return
        
    # Формируем описание аспекта
    caption = (
        f"**Аспект {aspect_data.get('aspect_display', 'x → x')}: {aspect_data.get('aspect_name', 'Название')}**\n\n"
        f"**🧠 Ключевое качество:**\n"
        f"{aspect_data.get('aspect_strength', 'Описание отсутствует')}\n\n"
        f"**⚡ Вызов (опасность):**\n"
        f"{aspect_data.get('aspect_challenge', 'Описание отсутствует')}\n\n"
        f"**🌍 Проявление в жизни:**\n"
        f"{aspect_data.get('aspect_inlife', 'Описание отсутствует')}\n\n"
        f"**💥 Эмоциональный посыл:**\n"
        f"{aspect_data.get('aspect_emotion', 'Описание отсутствует')}\n\n"
        f"**🎭 Как выглядит:**\n"
        f"{aspect_data.get('aspect_manifestation', 'Описание отсутствует')}\n\n"
        f"**❓ Вопрос для рефлексии:**\n"
        f"*{aspect_data.get('aspect_question', 'Вопрос отсутствует')}*"
    )

    sent_msg = bot.send_message(
        chat_id=chat_id,
        text=caption,
        parse_mode="Markdown"
    )

    # Добавляем кнопку закрытия
    markup = types.InlineKeyboardMarkup()
    markup.add(types.InlineKeyboardButton(
        "Просмотрено ✅", 
        callback_data=f'delete_{sent_msg.message_id}'
    ))
    
    bot.edit_message_reply_markup(
        chat_id=chat_id,
        message_id=sent_msg.message_id,
        reply_markup=markup
    )

def check_access(user_id, required_level=1):
    try:
        return fb_check_access(user_id, required_level)
    except:
        return False

# Также обновите функцию show_aspect_by_number (переименуйте ее для ясности)
def show_aspect_by_display_number(chat_id, display_number):
    # Ищем аспект по display_number (если нужно)
    aspect_data = None
    for key, value in ASPECTS_ROLE.items():
        if value.get('aspect_display', '').startswith(str(display_number)):
            aspect_data = value
            break
    
    if not aspect_data:
        bot.send_message(chat_id, "Описание для этого аспекта не найдено!")
        return
        
    # Формируем описание аспекта
    caption = (
        f"**Аспект {aspect_data.get('aspect_display', 'x → x')}: {aspect_data.get('aspect_name', 'Название')}**\n\n"
        f"**🧠 Ключевое качество:**\n"
        f"{aspect_data.get('aspect_strength', 'Описание отсутствует')}\n\n"
        f"**⚡ Вызов (опасность):**\n"
        f"{aspect_data.get('aspect_challenge', 'Описание отсутствует')}\n\n"
        f"**🌍 Проявление в жизни:**\n"
        f"{aspect_data.get('aspect_inlife', 'Описание отсутствует')}\n\n"
        f"**💥 Эмоциональный посыл:**\n"
        f"{aspect_data.get('aspect_emotion', 'Описание отсутствует')}\n\n"
        f"**🎭 Как выглядит:**\n"
        f"{aspect_data.get('aspect_manifestation', 'Описание отсутствует')}\n\n"
        f"**❓ Вопрос для рефлексии:**\n"
        f"*{aspect_data.get('aspect_question', 'Вопрос отсутствует')}*"
    )

    sent_msg = bot.send_message(
        chat_id=chat_id,
        text=caption,
        parse_mode="Markdown"
    )

    # Добавляем кнопку закрытия
    markup = types.InlineKeyboardMarkup()
    markup.add(types.InlineKeyboardButton(
        "Просмотрено ✅", 
        callback_data=f'delete_{sent_msg.message_id}'
    ))
    
    bot.edit_message_reply_markup(
        chat_id=chat_id,
        message_id=sent_msg.message_id,
        reply_markup=markup
    )    

def show_role_by_number(chat_id, role_number):
    display_num = role_number if role_number != 0 else 22
    zone_data = ZONES.get(display_num, {})
    
    if not zone_data:
        bot.send_message(chat_id, "Описание для этой роли не найдено!")
        return

    caption = (
        f"**Роль подсознания {display_num}: {zone_data.get('role_name', 'Название')}**\n\n"
        f"**🧠 Ключевое качество:**\n"
        f"{zone_data.get('role_key', 'Описание отсутствует')}\n\n"
        f"**💪 Сильная сторона:**\n"
        f"{zone_data.get('role_strength', 'Описание отсутствует')}\n\n"
        f"**⚡ Вызов (опасность):**\n"
        f"{zone_data.get('role_challenge', 'Описание отсутствует')}\n\n"
        f"**🌍 Проявление в жизни:**\n"
        f"{zone_data.get('role_inlife', 'Описание отсутствует')}\n\n"
        f"**💥 Эмоциональный посыл:**\n"
        f"{zone_data.get('emotion', 'Описание отсутствует')}\n\n"
        f"**🎭 Как выглядит:**\n"
        f"{zone_data.get('manifestation', 'Описание отсутствует')}\n\n"
        f"**❓ Вопрос для рефлексии:**\n"
        f"*{zone_data.get('role_question', 'Вопрос отсутствует')}*"
    )

    video_file_id = VIDEOS.get(role_number)
    if video_file_id:
        sent_msg = bot.send_video(
            chat_id=chat_id,
            video=video_file_id,
            caption=caption,
            parse_mode="Markdown"
        )
    else:
        sent_msg = bot.send_message(
            chat_id=chat_id,
            text=caption,
            parse_mode="Markdown"
        )

    # Добавляем кнопку закрытия
    markup = types.InlineKeyboardMarkup()
    markup.add(types.InlineKeyboardButton(
        "Просмотрено ✅", 
        callback_data=f'delete_{sent_msg.message_id}'
    ))
    
    bot.edit_message_reply_markup(
        chat_id=chat_id,
        message_id=sent_msg.message_id,
        reply_markup=markup
    )
# Глобальный словарь для хранения активных меню по ID чата { chat_id: [message_ids] }
active_menus = {}
@bot.message_handler(commands=['стоп'])
def close_menu(message):
    chat_id = message.chat.id
    #bot.edit_message_reply_markup(chat_id, reply_markup=None)
    if chat_id in active_menus:
        for msg_id in active_menus[chat_id]:
            try:
                bot.delete_message(chat_id, msg_id)
            except:
                pass
        active_menus[chat_id] = []
        bot.reply_to(message, "Все меню закрыты ✅")
    else:
        bot.reply_to(message, "Нет активных меню ❌")
# Обработчик команды /стоп
@bot.message_handler(commands= ['stop'])
def close_menu(message):
    chat_id = message.chat.id
    if chat_id in active_menus and active_menus[chat_id]:
        try:
            # Удаляем последнее сообщение с меню
            last_message_id = active_menus[chat_id].pop()
            bot.delete_message(chat_id, last_message_id)
            bot.reply_to(message, "Меню закрыто ✅")
        except Exception as e:
            bot.reply_to(message, f"Ошибка: {str(e)}")
    else:
        bot.reply_to(message, "Нет активных меню ❌")

# Функция для отправки меню с сохранением ID
def send_menu(chat_id, text, markup):
    msg = bot.send_message(chat_id, text, reply_markup=markup)
    if chat_id not in active_menus:
        active_menus[chat_id] = []
    active_menus[chat_id].append(msg.message_id)
    return msg

@bot.message_handler(commands=['myid'])
def show_user_id(message):
    user_id = message.from_user.id
    bot.send_message(message.chat.id, f"Ваш user_id: `{user_id}`", parse_mode="Markdown")

@bot.message_handler(commands=['login_app'])
def login_app(message):
    user_id = message.from_user.id
    token = fb_create_custom_token(user_id)
    if token:
        bot.send_message(
            message.chat.id, 
            f"🔑 *Ваш ключ для входа в приложение:*\n\n`{token}`\n\n(Нажмите на ключ, чтобы скопировать. Он действует 1 час)", 
            parse_mode="Markdown"
        )
    else:
        bot.send_message(message.chat.id, "❌ Ошибка генерации ключа. Обратитесь к админу.")

@bot.message_handler(func=lambda message: message.text == 'Открыть меню')
def main_menu(message):
    markup = types.ReplyKeyboardMarkup(resize_keyboard=True)
    markup.row(types.KeyboardButton('🧠 Диагностика'), types.KeyboardButton('🏢 Мой кабинет'))
    bot.send_message(message.chat.id, 'Главное меню:', reply_markup=markup)

@bot.callback_query_handler(func=lambda call: call.data == 'admin_broadcast')
def handle_admin_broadcast(call):
    """Меню рассылки сообщений для администратора"""
    user_id = call.from_user.id
    conn = sqlite3.connect(DB_PATH, check_same_thread=False)
    cursor = conn.cursor()
    
    try:
        cursor.execute('SELECT pgmd FROM Partn WHERE user_id = ?', (user_id,))
        result = cursor.fetchone()
        
        if not result or result[0] != 100:
            bot.answer_callback_query(call.id, "❌ Доступ запрещен!")
            return
        
        markup = types.InlineKeyboardMarkup(row_width=2)
        markup.add(
            types.InlineKeyboardButton("📢 Всем пользователям", callback_data='broadcast_all'),
            types.InlineKeyboardButton("🎯 Точечная рассылка", callback_data='broadcast_select'),
            types.InlineKeyboardButton("📊 Статистика", callback_data='broadcast_stats'),
            types.InlineKeyboardButton("◀️ Назад", callback_data='back_to_admin_menu'),
            types.InlineKeyboardButton("❌ Закрыть", callback_data='delete_history_msg')
        )
        
        bot.edit_message_text(
            chat_id=call.message.chat.id,
            message_id=call.message.message_id,
            text="📨 *Панель рассылки сообщений*\n\nВыберите тип рассылки:",
            parse_mode="Markdown",
            reply_markup=markup
        )
        
    finally:
        conn.close()

@bot.callback_query_handler(func=lambda call: call.data == 'broadcast_all')
def handle_broadcast_all(call):
    """Запрос текста для рассылки всем пользователям"""
    user_id = call.from_user.id
    broadcast_data[user_id] = {'type': 'all', 'stage': 'text'}
    
    msg = bot.send_message(
        call.message.chat.id,
        "📝 *Введите текст сообщения для рассылки всем пользователям:*\n\n"
        "❕ Для отмены введите /стоп\n"
        "❕ Поддерживается Markdown форматирование",
        parse_mode="Markdown"
    )
    
    bot.register_next_step_handler(msg, process_broadcast_text)

@bot.callback_query_handler(func=lambda call: call.data == 'broadcast_select')
def handle_broadcast_select(call):
    """Выбор пользователя для точечной рассылки"""
    user_id = call.from_user.id
    
    conn = sqlite3.connect(DB_PATH, check_same_thread=False)
    cursor = conn.cursor()
    
    try:
        # Получаем список пользователей
        cursor.execute(
            'SELECT user_id, user_name, username FROM Partn ORDER BY user_name'
        )
        users = cursor.fetchall()
        
        if not users:
            bot.answer_callback_query(call.id, "❌ Пользователи не найдены")
            return
        
        broadcast_data[user_id] = {
            'type': 'select', 
            'stage': 'user_selection',
            'users': users
        }
        
        # Показываем первую страницу пользователей
        show_user_selection_page(call.message.chat.id, call.message.message_id, user_id, page=0)
        
    finally:
        conn.close()

def show_user_selection_page(chat_id, message_id, admin_id, page=0, search_query=None):
    """Показать страницу с пользователями для выбора"""
    if admin_id not in broadcast_data:
        return
    
    users = broadcast_data[admin_id]['users']
    users_per_page = 10
    start_idx = page * users_per_page
    end_idx = start_idx + users_per_page
    
    # Фильтрация по поисковому запросу
    if search_query:
        filtered_users = []
        for user in users:
            user_id, user_name, username = user
            search_text = f"{user_name} {username or ''}".lower()
            if search_query.lower() in search_text:
                filtered_users.append(user)
        users_to_show = filtered_users
    else:
        users_to_show = users
    
    total_pages = (len(users_to_show) - 1) // users_per_page + 1
    current_page_users = users_to_show[start_idx:end_idx]
    
    markup = types.InlineKeyboardMarkup(row_width=2)
    
    # Кнопки пользователей
    for user in current_page_users:
        user_id, user_name, username = user
        display_name = f"{user_name}"
        if username:
            display_name += f" (@{username})"
        
        # Обрезаем длинные имена
        if len(display_name) > 30:
            display_name = display_name[:27] + "..."
        
        markup.add(types.InlineKeyboardButton(
            display_name, 
            callback_data=f'broadcast_to_{user_id}'
        ))
    
    # Кнопки навигации
    nav_buttons = []
    if page > 0:
        nav_buttons.append(types.InlineKeyboardButton(
            "◀️ Назад", 
            callback_data=f'user_page_{page-1}'
        ))
    
    if end_idx < len(users_to_show):
        nav_buttons.append(types.InlineKeyboardButton(
            "Вперед ▶️", 
            callback_data=f'user_page_{page+1}'
        ))
    
    if nav_buttons:
        markup.row(*nav_buttons)
    
    # Кнопка поиска
    markup.add(types.InlineKeyboardButton(
        "🔍 Поиск пользователя", 
        callback_data='search_user'
    ))
    
    markup.add(
        types.InlineKeyboardButton("◀️ Назад", callback_data='admin_broadcast'),
        types.InlineKeyboardButton("❌ Закрыть", callback_data='delete_history_msg')
    )
    
    page_text = f"Страница {page + 1} из {total_pages}" if total_pages > 1 else ""
    text = f"👥 *Выберите пользователя для рассылки:*\n\n{page_text}\n\nВсего пользователей: {len(users_to_show)}"
    
    bot.edit_message_text(
        chat_id=chat_id,
        message_id=message_id,
        text=text,
        parse_mode="Markdown",
        reply_markup=markup
    )
    
    # Сохраняем текущую страницу
    broadcast_data[admin_id]['current_page'] = page
    broadcast_data[admin_id]['filtered_users'] = users_to_show

@bot.callback_query_handler(func=lambda call: call.data.startswith('user_page_'))
def handle_user_page_change(call):
    """Обработчик переключения страниц пользователей"""
    admin_id = call.from_user.id
    page = int(call.data.split('_')[2])
    
    if admin_id in broadcast_data:
        show_user_selection_page(
            call.message.chat.id, 
            call.message.message_id, 
            admin_id, 
            page
        )

@bot.callback_query_handler(func=lambda call: call.data == 'search_user')
def handle_search_user(call):
    """Запрос поиска пользователя"""
    admin_id = call.from_user.id
    
    msg = bot.send_message(
        call.message.chat.id,
        "🔍 *Введите имя или username пользователя для поиска:*\n\n"
        "❕ Для отмены введите /стоп",
        parse_mode="Markdown"
    )
    
    broadcast_data[admin_id]['stage'] = 'search'
    bot.register_next_step_handler(msg, process_user_search)

def process_user_search(message):
    """Обработка поискового запроса с фильтрацией недоступных пользователей"""
    admin_id = message.from_user.id
    
    if message.text == '/стоп':
        if admin_id in broadcast_data:
            broadcast_data[admin_id]['stage'] = 'user_selection'
            show_user_selection_page(
                message.chat.id, 
                message.message_id - 1,  # ID предыдущего сообщения
                admin_id, 
                page=0
            )
        return
    
    search_query = message.text.strip()
    
    if admin_id in broadcast_data:
        broadcast_data[admin_id]['stage'] = 'user_selection'
        # Фильтруем пользователей по поисковому запросу
        show_user_selection_page(
            message.chat.id,
            message.message_id - 1,
            admin_id,
            page=0,
            search_query=search_query
        )

@bot.callback_query_handler(func=lambda call: call.data.startswith('broadcast_to_'))
def handle_user_selection(call):
    """Выбор конкретного пользователя для рассылки"""
    admin_id = call.from_user.id
    target_user_id = int(call.data.split('_')[2])
    
    # Получаем информацию о пользователе
    conn = sqlite3.connect(DB_PATH, check_same_thread=False)
    cursor = conn.cursor()
    
    try:
        cursor.execute(
            'SELECT user_name, username FROM Partn WHERE user_id = ?', 
            (target_user_id,)
        )
        user_info = cursor.fetchone()
        
        if user_info:
            user_name, username = user_info
            broadcast_data[admin_id].update({
                'stage': 'text',
                'target_user_id': target_user_id,
                'target_user_name': user_name,
                'target_username': username
            })
            
            msg = bot.send_message(
                call.message.chat.id,
                f"📝 *Введите текст сообщения для пользователя {user_name} (@{username or 'нет username'}):*\n\n"
                "❕ Для отмены введите /стоп\n"
                "❕ Поддерживается Markdown форматирование",
                parse_mode="Markdown"
            )
            
            bot.register_next_step_handler(msg, process_broadcast_text)
            
    finally:
        conn.close()

def process_broadcast_text(message):
    """Обработка текста сообщения для рассылки"""
    admin_id = message.from_user.id
    
    if message.text.strip() in ['/стоп', '/stop', 'отмена', 'Отмена']:
        if admin_id in broadcast_data:
            del broadcast_data[admin_id]
        bot.send_message(message.chat.id, "❌ Рассылка отменена")
        return
    
    text = message.text.strip()
    
    if not text:
        bot.send_message(message.chat.id, "❌ Текст сообщения не может быть пустым")
        return
    
    if admin_id in broadcast_data:
        broadcast_data[admin_id]['text'] = text
        broadcast_data[admin_id]['stage'] = 'confirmation'
        
        # Показываем предпросмотр
        show_broadcast_preview(message.chat.id, admin_id)

def show_broadcast_preview(chat_id, admin_id):
    """Показать предпросмотр сообщения и кнопку подтверждения"""
    if admin_id not in broadcast_data:
        return
    
    data = broadcast_data[admin_id]
    
    if data['type'] == 'all':
        recipient_info = "👥 *Всем пользователям*"
    else:
        recipient_info = f"👤 *Пользователю:* {escape_markdown(data['target_user_name'])}"
        if data['target_username']:
            recipient_info += f"\n@{escape_markdown(data['target_username'])}"
    
    # Экранируем текст для безопасного отображения в Markdown
    safe_text = escape_markdown(data['text'])
    
    preview_text = (
        f"📨 *Предпросмотр сообщения*\n\n"
        f"{recipient_info}\n\n"
        f"*Текст сообщения:*\n"
        f"```\n{safe_text}\n```\n\n"
        f"ℹ️ Отправить это сообщение?"
    )
    
    markup = types.InlineKeyboardMarkup(row_width=2)
    markup.add(
        types.InlineKeyboardButton("✅ Отправить", callback_data='confirm_broadcast'),
        types.InlineKeyboardButton("✏️ Редактировать", callback_data='edit_broadcast'),
        types.InlineKeyboardButton("❌ Отмена", callback_data='cancel_broadcast')
    )
    
    try:
        bot.send_message(
            chat_id,
            preview_text,
            parse_mode="Markdown",
            reply_markup=markup
        )
    except Exception as e:
        # Если возникает ошибка с Markdown, отправляем без форматирования
        preview_text_fallback = (
            f"📨 Предпросмотр сообщения\n\n"
            f"{recipient_info.replace('*', '')}\n\n"
            f"Текст сообщения:\n"
            f"{data['text']}\n\n"
            f"ℹ️ Отправить это сообщение?"
        )
        
        bot.send_message(
            chat_id,
            preview_text_fallback,
            reply_markup=markup
        )
# Функция для экранирования Markdown символов
def escape_markdown(text):
    """Экранирует специальные символы Markdown"""
    if not text:
        return text
    
    # Список символов, которые нужно экранировать в Markdown
    escape_chars = ['_', '*', '[', ']', '(', ')', '~', '`', '>', '#', '+', '-', '=', '|', '{', '}', '.', '!']
    
    for char in escape_chars:
        text = text.replace(char, '\\' + char)
    
    return text

@bot.callback_query_handler(func=lambda call: call.data == 'confirm_broadcast')
def handle_confirm_broadcast(call):
    """Подтверждение и отправка рассылки с проверкой доступности"""
    admin_id = call.from_user.id
    
    if admin_id not in broadcast_data:
        bot.answer_callback_query(call.id, "❌ Данные рассылки не найдены")
        return
    
    data = broadcast_data[admin_id]
    text = data['text']
    
    # Показываем статус отправки
    status_msg = bot.send_message(call.message.chat.id, "⏳ Начинаю проверку доступности пользователей...")
    
    success_count = 0
    failed_count = 0
    failed_details = []
    
    try:
        conn = sqlite3.connect(DB_PATH, check_same_thread=False)
        cursor = conn.cursor()
        
        if data['type'] == 'all':
            # Рассылка всем пользователям, исключая администратора
            cursor.execute('SELECT user_id FROM Partn WHERE user_id != ?', (admin_id,))
            all_users = cursor.fetchall()
            
            total_users = len(all_users)
            processed_count = 0
            
            for user in all_users:
                user_id = user[0]
                processed_count += 1
                
                # Обновляем статус каждые 10 пользователей
                if processed_count % 10 == 0:
                    try:
                        bot.edit_message_text(
                            chat_id=call.message.chat.id,
                            message_id=status_msg.message_id,
                            text=f"⏳ Проверка пользователей... {processed_count}/{total_users}"
                        )
                    except:
                        pass
                
                # Проверяем доступность пользователя
                if not is_user_accessible(user_id):
                    failed_count += 1
                    failed_details.append(f"{user_id}: недоступен")
                    continue
                
                try:
                    # Пытаемся отправить с Markdown
                    try:
                        bot.send_message(user_id, text, parse_mode="Markdown")
                    except Exception:
                        # Если не получается с Markdown, отправляем без форматирования
                        bot.send_message(user_id, text)
                    success_count += 1
                    time.sleep(0.1)  # Задержка чтобы не превысить лимиты Telegram
                    
                except Exception as e:
                    error_msg = str(e)
                    failed_count += 1
                    if "bot was blocked" in error_msg:
                        failed_details.append(f"{user_id}: заблокирован")
                    elif "chat not found" in error_msg:
                        failed_details.append(f"{user_id}: чат не найден")
                    elif "user is deactivated" in error_msg:
                        failed_details.append(f"{user_id}: деактивирован")
                    else:
                        failed_details.append(f"{user_id}: {error_msg[:50]}...")
        
        else:
            # Точечная рассылка
            user_id = data['target_user_id']
            
            # Проверяем доступность пользователя
            if not is_user_accessible(user_id):
                failed_count += 1
                error_msg = f"Пользователь {user_id} недоступен для получения сообщений"
                failed_details.append(error_msg)
            else:
                try:
                    # Пытаемся отправить с Markdown
                    try:
                        bot.send_message(user_id, text, parse_mode="Markdown")
                    except Exception:
                        # Если не получается с Markdown, отправляем без форматирования
                        bot.send_message(user_id, text)
                    success_count += 1
                except Exception as e:
                    failed_count += 1
                    failed_details.append(f"{user_id}: {str(e)[:50]}...")
        
        conn.close()
        
        # Логируем результаты рассылки
        broadcast_type = "Всем" if data['type'] == 'all' else "Точечная"
        log_broadcast_result(
            admin_id=admin_id,
            broadcast_type=broadcast_type,
            total_sent=success_count,
            total_failed=failed_count,
            details="; ".join(failed_details[:10])  # Первые 10 ошибок
        )
        
        # Отчет об отправке
        report_text = (
            f"📊 *Отчет о рассылке*\n\n"
            f"✅ Успешно отправлено: {success_count}\n"
            f"❌ Не удалось отправить: {failed_count}\n"
            f"📈 Процент доставки: {(success_count/(success_count+failed_count)*100):.1f}%"
        )
        
        if failed_details:
            # Показываем первые 5 ошибок
            error_sample = "\n".join(failed_details[:5])
            if len(failed_details) > 5:
                error_sample += f"\n...и еще {len(failed_details) - 5} ошибок"
            report_text += f"\n\n⚠️ Примеры ошибок:\n{error_sample}"
        
        try:
            bot.edit_message_text(
                chat_id=call.message.chat.id,
                message_id=status_msg.message_id,
                text=report_text,
                parse_mode="Markdown"
            )
        except:
            bot.edit_message_text(
                chat_id=call.message.chat.id,
                message_id=status_msg.message_id,
                text=report_text
            )
        
        # Очищаем данные рассылки
        if admin_id in broadcast_data:
            del broadcast_data[admin_id]
        
        # Предлагаем скачать полный лог
        markup = types.InlineKeyboardMarkup()
        markup.add(
            types.InlineKeyboardButton("📥 Скачать лог рассылки", callback_data='download_broadcast_log')
        )
        
        bot.send_message(
            call.message.chat.id,
            "📋 Результаты рассылки сохранены в лог-файл",
            reply_markup=markup
        )
        
        bot.answer_callback_query(call.id, "✅ Рассылка завершена")
        
    except Exception as e:
        bot.edit_message_text(
            chat_id=call.message.chat.id,
            message_id=status_msg.message_id,
            text=f"❌ Ошибка при отправке: {str(e)}"
        )


@bot.callback_query_handler(func=lambda call: call.data == 'download_broadcast_log')
def handle_download_log(call):
    """Отправляет файл с логами рассылок"""
    try:
        log_file = "broadcast_log.csv"
        
        if not os.path.exists(log_file):
            bot.answer_callback_query(call.id, "❌ Файл лога не найден")
            return
        
        # Читаем последние 100 записей
        with open(log_file, 'r', encoding='utf-8') as f:
            lines = f.readlines()
            if len(lines) > 101:  # 1 заголовок + 100 записей
                lines = lines[:101]
        
        # Создаем временный файл
        temp_file = "last_broadcasts.csv"
        with open(temp_file, 'w', encoding='utf-8', newline='') as f:
            f.writelines(lines)
        
        # Отправляем файл
        with open(temp_file, 'rb') as f:
            bot.send_document(
                call.message.chat.id,
                f,
                caption="📊 Последние 100 рассылок"
            )
        
        # Удаляем временный файл
        os.remove(temp_file)
        
        bot.answer_callback_query(call.id, "✅ Лог отправлен")
        
    except Exception as e:
        bot.answer_callback_query(call.id, f"❌ Ошибка: {str(e)}")
@bot.callback_query_handler(func=lambda call: call.data == 'broadcast_stats')
def handle_broadcast_stats(call):
    """Показывает статистику рассылок"""
    try:
        log_file = "broadcast_log.csv"
        
        if not os.path.exists(log_file):
            bot.send_message(call.message.chat.id, "📭 Лог рассылок пуст")
            return
        
        with open(log_file, 'r', encoding='utf-8') as f:
            reader = csv.reader(f, delimiter=';')
            next(reader)  # Пропускаем заголовок
            
            total_broadcasts = 0
            total_sent = 0
            total_failed = 0
            recent_broadcasts = []
            
            for row in reader:
                if len(row) >= 6:
                    total_broadcasts += 1
                    total_sent += int(row[4])
                    total_failed += int(row[5])
                    
                    # Сохраняем последние 5 рассылок
                    if len(recent_broadcasts) < 5:
                        recent_broadcasts.append(row)
        
        if total_broadcasts == 0:
            bot.send_message(call.message.chat.id, "📭 Лог рассылок пуст")
            return
        
        # Формируем отчет
        report = (
            f"📈 *Статистика рассылок*\n\n"
            f"📊 Всего рассылок: {total_broadcasts}\n"
            f"✅ Всего отправлено: {total_sent}\n"
            f"❌ Всего ошибок: {total_failed}\n"
            f"📈 Средняя доставка: {(total_sent/(total_sent+total_failed)*100):.1f}%\n\n"
            f"📋 *Последние 5 рассылок:*\n"
        )
        
        for i, broadcast in enumerate(recent_broadcasts, 1):
            report += f"\n{i}. {broadcast[0]} - {broadcast[2]}\n"
            report += f"   Успешно: {broadcast[4]}, Ошибок: {broadcast[5]}\n"
        
        markup = types.InlineKeyboardMarkup()
        markup.add(
            types.InlineKeyboardButton("📥 Скачать полный лог", callback_data='download_broadcast_log'),
            types.InlineKeyboardButton("❌ Закрыть", callback_data='delete_history_msg')
        )
        
        bot.send_message(
            call.message.chat.id,
            report,
            parse_mode="Markdown",
            reply_markup=markup
        )
        
    except Exception as e:
        bot.send_message(call.message.chat.id, f"❌ Ошибка при загрузке статистики: {str(e)}")


@bot.callback_query_handler(func=lambda call: call.data == 'edit_broadcast')
def handle_edit_broadcast(call):
    """Редактирование текста рассылки"""
    admin_id = call.from_user.id
    
    if admin_id in broadcast_data:
        broadcast_data[admin_id]['stage'] = 'text'
        
        msg = bot.send_message(
            call.message.chat.id,
            "✏️ *Введите новый текст сообщения:*\n\n"
            "❕ Для отмены введите /стоп\n"
            "❕ Поддерживается Markdown форматирование",
            parse_mode="Markdown"
        )
        
        bot.register_next_step_handler(msg, process_broadcast_text)
        
        # Удаляем сообщение с предпросмотром
        bot.delete_message(call.message.chat.id, call.message.message_id)

@bot.callback_query_handler(func=lambda call: call.data == 'cancel_broadcast')
def handle_cancel_broadcast(call):
    """Отмена рассылки"""
    admin_id = call.from_user.id
    
    if admin_id in broadcast_data:
        del broadcast_data[admin_id]
    
    bot.delete_message(call.message.chat.id, call.message.message_id)
    bot.send_message(call.message.chat.id, "❌ Рассылка отменена")

@bot.callback_query_handler(func=lambda call: call.data == 'back_to_admin_menu')
def back_to_admin_menu(call):
    """Возврат в меню администратора"""
    user_id = call.from_user.id
    
    # Очищаем данные рассылки если есть
    if user_id in broadcast_data:
        del broadcast_data[user_id]
    
    # Показываем меню администратора
    conn = sqlite3.connect(DB_PATH, check_same_thread=False)
    cursor = conn.cursor()
    
    try:
        cursor.execute('SELECT pgmd FROM Partn WHERE user_id = ?', (user_id,))
        result = cursor.fetchone()
        
        if result and result[0] == 100:
            markup = types.InlineKeyboardMarkup(row_width=2)
            markup.add(
                types.InlineKeyboardButton("📨 Рассылка", callback_data='admin_broadcast'),
                types.InlineKeyboardButton("📊 Анализ", callback_data='diagnostic_analysis'),
                types.InlineKeyboardButton("📈 Управление", callback_data='admin_management'),
                types.InlineKeyboardButton("◀️ В главное меню", callback_data='back_to_main')
            )
            
            bot.edit_message_text(
                chat_id=call.message.chat.id,
                message_id=call.message.message_id,
                text="🛠 *Панель администратора*\n\nВыберите действие:",
                parse_mode="Markdown",
                reply_markup=markup
            )
            
    finally:
        conn.close()
# Добавляем кнопку в меню анализа

@bot.callback_query_handler(func=lambda call: call.data == 'diagnostic_analysis')
def diagnostic_analysis(call):
    user_id = call.from_user.id
    conn = sqlite3.connect(DB_PATH)
    try:
        cursor = conn.cursor()
        cursor.execute('SELECT pgmd FROM Partn WHERE user_id = ?', (user_id,))
        pgmd_level = cursor.fetchone()[0]
        
        if pgmd_level == 100:
            markup = types.InlineKeyboardMarkup()
            markup.row(
                types.InlineKeyboardButton("📥 Ввод данных", callback_data='input_data'),
                types.InlineKeyboardButton("📊 Просмотр данных", callback_data='view_pgmd_data'),
            )
            markup.add(types.InlineKeyboardButton("⬅️ Назад", callback_data='back_to_pgmd'))
            
            bot.edit_message_text(
                chat_id=call.message.chat.id,
                message_id=call.message.message_id,
                text="🔍 Админ-панель анализа:",
                reply_markup=markup
            )
    finally:
        conn.close()

def universal_analysis(social_role=None, achievement_keyword=None):
    try:
        conn_pgmd = sqlite3.connect(DB_PATH2)
        conn_perf = sqlite3.connect(DB_PATH)
        
        # Формируем SQL-запрос
        query = '''
            SELECT m.* 
            FROM user_metrics m
            JOIN users u ON m.user_id = u.id
            WHERE 1=1
        '''
        params = []
        
        if social_role:
            query += ' AND u.social_role = ?'
            params.append(social_role)
            
        if achievement_keyword:
            query += ' AND u.achievements LIKE ?'
            params.append(f'%{achievement_keyword}%')

        df = pd.read_sql(query, conn_pgmd, params=params)

        if df.empty:
            return {"error": "Нет данных по выбранным критериям"}

        # Анализ данных
        analysis = {
            'total': len(df),
            'frequent_metrics': df.iloc[:, 1:].apply(pd.Series.value_counts).mean().sort_values(ascending=False).head(5).to_dict(),
            'correlations': df.corr().stack().reset_index(),
            'cluster_profile': cluster_analysis(df)
        }

        # Генерация графиков
        generate_visualizations(df, social_role, achievement_keyword)
        
        return analysis

    except Exception as e:
        return {"error": str(e)}
    finally:
        conn_pgmd.close()
        conn_perf.close()

def cluster_analysis(df):
    try:
        scaler = StandardScaler()
        scaled = scaler.fit_transform(df.iloc[:, 1:])
        
        kmeans = KMeans(n_clusters=3, random_state=42)
        clusters = kmeans.fit_predict(scaled)
        
        tsne = TSNE(n_components=2, random_state=42)
        tsne_results = tsne.fit_transform(scaled)
        
        return {
            'cluster_distribution': pd.Series(clusters).value_counts().to_dict(),
            'tsne_data': tsne_results.tolist(),
            'error': None
        }
    except Exception as e:
        return {
            'cluster_distribution': {},
            'tsne_data': [],
            'error': str(e)
        }

def generate_visualizations(df, social_role, achievement):
    plt.figure(figsize=(18, 12))
    
    # Тепловая карта корреляций
    plt.subplot(2, 2, 1)
    sns.heatmap(df.corr(), annot=True, cmap='coolwarm')
    plt.title('Матрица корреляций')
    
    # Распределение показателей
    plt.subplot(2, 2, 2)
    df.iloc[:, 1:].hist(bins=22, layout=(4,4))
    plt.suptitle('Распределение показателей')
    
    # Кластеры
    plt.subplot(2, 2, 3)
    cluster_data = cluster_analysis(df)
    if cluster_data['tsne_data']:
        plt.scatter(*zip(*cluster_data['tsne_data']))
        plt.title('Визуализация кластеров (t-SNE)')
    else:
        plt.text(0.5, 0.5, 'Данные недоступны', ha='center', va='center')
    
    # Топ-5 показателей
    plt.subplot(2, 2, 4)
    df.iloc[:, 1:].mean().sort_values(ascending=False).head(5).plot(kind='bar')
    plt.title('Средние значения топ-5 показателей')
    
    filename = f"analysis_{social_role or 'all'}_{achievement or 'all'}.png"
    plt.savefig(filename)
    plt.close()

# Обработчики бота
@bot.callback_query_handler(func=lambda call: call.data == 'universal_analysis')
def start_universal_analysis(call):
    markup = types.InlineKeyboardMarkup()
    markup.row(
        types.InlineKeyboardButton("🔫 Убийцы", callback_data='analysis_killers'),
        types.InlineKeyboardButton("🎭 Актеры", callback_data='analysis_actors')
    )
    markup.row(
        types.InlineKeyboardButton("👑 Топ-менеджеры", callback_data='analysis_managers'),
        types.InlineKeyboardButton("📊 Все данные", callback_data='analysis_all')
    )
    
    bot.edit_message_text(
        chat_id=call.message.chat.id,
        message_id=call.message.message_id,
        text="🔍 Выберите категорию для анализа:",
        reply_markup=markup
    )

@bot.callback_query_handler(func=lambda call: call.data.startswith('analysis_'))
def handle_analysis_category(call):
    try:
        category = call.data.split('_')[1]
        filters = {
            'killers': {'social_role': 'Преступник', 'achievement_keyword': 'Убийца'},
            'actors': {'social_role': 'Актер', 'achievement_keyword': 'Оскар'},
            'managers': {'social_role': 'Руководитель', 'achievement_keyword': None},
            'all': {}
        }
        
        result = universal_analysis(**filters.get(category, {}))
        
        if 'error' in result:
            bot.send_message(call.message.chat.id, f"❌ Ошибка: {result['error']}")
            return
        
        # Формирование текста отчёта
        cluster_info = result['cluster_profile'].get('cluster_distribution', {})
        text = f"""
📊 *Анализ категории {category.capitalize()}*:
• Всего записей: {result['total']}
• Топ-5 показателей: {json.dumps(result['frequent_metrics'], indent=2)}
• Распределение кластеров: {json.dumps(cluster_info, indent=2)}
        """
        
        # Отправка графиков
        filename = f"analysis_{category}.png"
        with open(filename, 'rb') as f:
            bot.send_photo(call.message.chat.id, f, caption=text, parse_mode='Markdown')
        
        # Отправка CSV с корреляциями
        result['correlations'].to_csv('correlations.csv', index=False)
        bot.send_document(call.message.chat.id, open('correlations.csv', 'rb'))

    except Exception as e:
        bot.send_message(call.message.chat.id, f"⛔ Критическая ошибка: {str(e)}")

def analyze_oscar_winners():

    try:
        # Подключаемся к базам
        plt.switch_backend('agg') 
        conn_pgmd = sqlite3.connect(DB_PATH2)
        conn_perf = sqlite3.connect(DB_PATH)

        # 1. Получаем данные обладателей Оскара
        query = '''
            SELECT m.* 
            FROM user_metrics m
            JOIN users u ON m.user_id = u.id
            WHERE 
                u.achievements LIKE '%Оскар%'
                AND u.social_role = 'Актер'
        '''
        df = pd.read_sql(query, conn_pgmd)

        if df.empty:
            return "Не найдено данных об обладателях Оскар"

        # 2. Анализ частотности показателей
        freq_analysis = pd.DataFrame()
        for col in df.columns[1:]:  # Пропускаем user_id
            freq_analysis[col] = df[col].value_counts(normalize=True)

        # 3. Поиск кластеров
        kmeans = KMeans(n_clusters=3, random_state=42)
        clusters = kmeans.fit_predict(df.iloc[:, 1:])
        
        # 4. Корреляционный анализ
        corr_matrix = df.corr()

        # 5. Визуализация
        tsne = TSNE(n_components=2, random_state=42) 
        vis_data = tsne.fit_transform(df.iloc[:, 1:])
        plt.figure(figsize=(20, 15))
        
        # Тепловая карта корреляций
        plt.subplot(2, 2, 1)
        sns.heatmap(corr_matrix, annot=True, cmap='coolwarm')
        plt.title('Матрица корреляций')

        # Распределение показателей
        plt.subplot(2, 2, 2)
        df.iloc[:, 1:].hist(bins=22, layout=(4,4), figsize=(15,10))
        plt.suptitle('Распределение показателей')

        # Кластерный анализ
        plt.subplot(2, 2, 3)
        tsne = TSNE(n_components=2)
        vis_data = tsne.fit_transform(df.iloc[:, 1:])
        plt.scatter(vis_data[:,0], vis_data[:,1], c=clusters)
        plt.title('Визуализация кластеров (t-SNE)')

        # Топ-5 частых значений
        plt.subplot(2, 2, 4)
        freq_analysis.mean().sort_values(ascending=False)[:5].plot(kind='bar')
        plt.title('Самые частые показатели')

        plt.tight_layout()
        plt.savefig('oscar_analysis.png')
        plt.close()

        # 6. Формируем отчет
        report = {
            'total_winners': len(df),
            'top_metrics': freq_analysis.mean().sort_values(ascending=False).head(5).to_dict(),
            'strong_correlations': corr_matrix[(corr_matrix > 0.7) | (corr_matrix < -0.7)].stack().reset_index(),
            'clusters': pd.Series(clusters).value_counts().to_dict()
        }
        corr_matrix.to_csv('correlations.csv', index=False) 

        return report

    except Exception as e:
        return f"Ошибка анализа: {str(e)}"
    finally:
        plt.close('all') 
        conn_pgmd.close()
        conn_perf.close()

# Пример использования
@bot.callback_query_handler(func=lambda call: call.data == 'run_oscar_analysis')
def handle_analysis(call):
    result = analyze_oscar_winners()
    
    if isinstance(result, dict):
        text = f"""
📊 *Анализ обладателей Оскар*:

• Всего записей: {result['total_winners']}
• Топ-5 показателей: {json.dumps(result['top_metrics'], indent=2)}
• Кластеры: {json.dumps(result['clusters'], indent=2)}
        """
        
        # with open('oscar_analysis.png', 'rb') as f:
        #    bot.send_photo(call.message.chat.id, f, caption=text, parse_mode='Markdown')
        bot.send_message(call.message.chat.id, text, parse_mode='Markdown')

# --- History Logic with Folders ---

# --- History Logic with Folders ---

def send_history_menu(chat_id, user_id, message_id=None):
    entries = fb_get_history(user_id, limit=300)
    
    if not entries:
        text = "📭 История расчетов пуста."
        if message_id:
            bot.edit_message_text(chat_id=chat_id, message_id=message_id, text=text)
        else:
            bot.send_message(chat_id, text)
        return

    # Split into Folders and Ungrouped
    groups = set()
    ungrouped = []
    
    for e in entries:
        g = e.get('group')
        # print(f"DEBUG: Entry {e.get('id')} group='{g}'") # Uncomment if needed
        if g and isinstance(g, str) and g.strip():
            groups.add(g.strip())
        else:
            ungrouped.append(e)
            
    print(f"📂 History: {len(entries)} entries. Groups: {groups}. Ungrouped: {len(ungrouped)}")
            
    markup = types.InlineKeyboardMarkup()
    
    # 1. Folders
    if groups:
        for group in sorted(list(groups)):
            markup.add(types.InlineKeyboardButton(f"📁 {group}", callback_data=f'view_group_{group}'))
            
    # 2. Ungrouped Items (Limit to 60 as per legacy logic)
    for entry in ungrouped[:60]:
        date_str = entry.get('birthDate', '??.??.????')
        name = entry.get('name', 'Без имени')
        log_id = entry.get('id')
        
        btn_text = f"{date_str} - {name}"
        markup.add(types.InlineKeyboardButton(btn_text, callback_data=f'view_calc_{log_id}'))
        
    # Footer
    markup.row(
        types.InlineKeyboardButton("❌ Закрыть", callback_data='delete_history_msg')
    )
            
    text = "📂 <b>История расчетов:</b>"
    
    if message_id:
        bot.edit_message_text(chat_id=chat_id, message_id=message_id, text=text, reply_markup=markup, parse_mode='HTML')
    else:
        bot.send_message(chat_id, text, reply_markup=markup, parse_mode='HTML')


@bot.message_handler(commands=['history'])
def history_command(message):
    send_history_menu(message.chat.id, message.from_user.id)

@bot.callback_query_handler(func=lambda call: call.data == 'diagnostic_history')
def show_diagnostic_history(call):
    send_history_menu(call.message.chat.id, call.from_user.id, call.message.message_id)

@bot.callback_query_handler(func=lambda call: call.data == 'view_all_history')
def view_all_history(call):
    user_id = call.from_user.id
    entries = fb_get_history(user_id, limit=50) # Limit for list view
    
    if not entries:
         bot.answer_callback_query(call.id, "📭 Пусто")
         return
         
    markup = types.InlineKeyboardMarkup()
    for entry in entries:
        date_str = entry.get('birthDate', '??.??.????')
        name = entry.get('name', 'Без имени')
        log_id = entry.get('id')
        markup.add(types.InlineKeyboardButton(f"{date_str} - {name}", callback_data=f'view_calc_{log_id}'))
        
    markup.add(types.InlineKeyboardButton("◀️ Назад к папкам", callback_data='diagnostic_history'))
    
    bot.edit_message_text(
        chat_id=call.message.chat.id, 
        message_id=call.message.message_id, 
        text="📂 <b>Все расчеты:</b>", 
        reply_markup=markup,
        parse_mode='HTML'
    )

@bot.callback_query_handler(func=lambda call: call.data.startswith('view_group_'))
def view_group(call):
    user_id = call.from_user.id
    group_name = call.data.split('_', 2)[2]
    
    entries = fb_get_history(user_id, limit=300)
    # Filter by group
    filtered = [e for e in entries if e.get('group') == group_name]
    
    markup = types.InlineKeyboardMarkup()
    for entry in filtered:
        date_str = entry.get('birthDate', '??.??.????')
        name = entry.get('name', 'Без имени')
        log_id = entry.get('id')
        markup.add(types.InlineKeyboardButton(f"{date_str} - {name}", callback_data=f'view_calc_{log_id}'))
        
    markup.add(types.InlineKeyboardButton("◀️ Назад", callback_data='diagnostic_history'))
    
    bot.edit_message_text(
        chat_id=call.message.chat.id, 
        message_id=call.message.message_id, 
        text=f"📁 Папка: <b>{group_name}</b>", 
        reply_markup=markup, 
        parse_mode='HTML'
    )

@bot.callback_query_handler(func=lambda call: call.data == 'delete_history_msg')
def delete_history(call):
    try:
        bot.delete_message(call.message.chat.id, call.message.message_id)
    except Exception:
        pass

@bot.callback_query_handler(func=lambda call: call.data.startswith('view_calc_'))
def show_saved_calculation(call):
    try:
        parts = call.data.split('_')
        calc_id = parts[2]
        viewer_id = call.from_user.id
        # If view_calc has owner_id, use it, otherwise assume viewer is owner
        owner_id = parts[3] if len(parts) > 3 else viewer_id
        
        # Fetch directly from owner's collection
        data = fb_get_log(calc_id, owner_id)

        if not data:
            bot.answer_callback_query(call.id, "❌ Запись не найдена")
            return

        # Разделяем данные
        birth_date = data.get('birthDate')
        name = data.get('name')
        gender = data.get('gender')
        group = data.get('user_group')
        
        numbers = data.get('numbers', [])
        
        # Fallback: Если numbers нет
        if not numbers and birth_date:
            try:
                numbers = calculate_numbers(birth_date, gender)
            except Exception as e:
                print(f"Fallback Error: {e}")

        if not numbers:
             bot.answer_callback_query(call.id, "❌ Данные повреждены")
             return

        # Формируем текст (используем format_scheme или аналогичную логику)
        # Note: format_scheme is defined elsewhere. Assuming it exists.
        scheme_text = format_scheme(*numbers, birth_date, name, gender)
        group_text = f"\n\n📁 Группа: {group}" if group else ""
        
        markup = types.InlineKeyboardMarkup(row_width=2)
        markup.add(
            types.InlineKeyboardButton("🗑 Удалить", callback_data=f'delete_entry_{calc_id}_{owner_id}'),
            types.InlineKeyboardButton("📁 Группа", callback_data=f'manage_group_{calc_id}'),
            types.InlineKeyboardButton("📋 Текст", callback_data=f'show_text_{calc_id}_{owner_id}'),
            types.InlineKeyboardButton("🖼 Изображение", callback_data=f'image_format_{calc_id}_{owner_id}'),
            types.InlineKeyboardButton("📋 Подробнее", callback_data=f'detailed_desc_{calc_id}_{owner_id}')
        )
        markup.row(types.InlineKeyboardButton("◀️ Назад", callback_data='diagnostic_history'))

        bot.edit_message_text(
            chat_id=call.message.chat.id,
            message_id=call.message.message_id,
            text=f"🔍 Запись #{calc_id}\n{scheme_text}{group_text}",
            reply_markup=markup,
            parse_mode='Markdown' # format_scheme returns Markdown usually?
        )

    except Exception as e:
        print(f"show_saved_calculation error: {e}")
        bot.send_message(call.message.chat.id, f"⛔ Ошибка: {str(e)}")

# Also text format alias if needed
# --- RESTORED HANDLERS ---

@bot.callback_query_handler(func=lambda call: call.data.startswith('delete_entry_'))
def delete_entry(call):
    try:
        parts = call.data.split('_')
        log_id = parts[2]
        viewer_id = call.from_user.id
        owner_id = parts[3] if len(parts) > 3 else viewer_id
        
        # Security check
        is_admin = fb_check_access(viewer_id, 100)
        if str(viewer_id) != str(owner_id) and not is_admin:
            bot.answer_callback_query(call.id, "❌ Вы не можете удалить чужую запись")
            return

        # Use adapter function
        print(f"🗑 Requesting delete: Log {log_id} Owner {owner_id} Viewer {viewer_id}")
        success = fb_delete_log(owner_id, log_id)
        
        if success:
            bot.answer_callback_query(call.id, "✅ Запись удалена")
            try:
                bot.delete_message(call.message.chat.id, call.message.message_id)
            except:
                pass
        else:
            bot.answer_callback_query(call.id, "❌ Не удалось удалить")
        
    except Exception as e:
        bot.answer_callback_query(call.id, f"⛔ Ошибка: {str(e)}")
        print(f"Delete Handler Error: {e}")

@bot.callback_query_handler(func=lambda call: call.data.startswith('manage_group_'))
def manage_group(call):
    try:
        parts = call.data.split('_')
        log_id = parts[2]
        viewer_id = call.from_user.id
        owner_id = parts[3] if len(parts) > 3 else viewer_id
        
        # 1. Get Log Data
        log_data = fb_get_log(log_id, owner_id)
        if not log_data:
            bot.answer_callback_query(call.id, "❌ Запись не найдена")
            return
            
        current_group = log_data.get('group')
        
        # 2. Get All History for groups
        all_logs = fb_get_history(owner_id, limit=300)
        groups = set()
        for log in all_logs:
            g = log.get('group')
            if g and isinstance(g, str) and g.strip():
                groups.add(g.strip())
                
        markup = types.InlineKeyboardMarkup()
        
        if current_group:
            markup.add(types.InlineKeyboardButton(f"❌ Удалить из '{current_group}'", callback_data=f'remove_group_{log_id}_{owner_id}'))
            
        for group in sorted(list(groups)):
            if group != current_group:
                 markup.add(types.InlineKeyboardButton(f"➡️ {group}", callback_data=f'set_group_{log_id}_{group}'))
                 
        markup.add(types.InlineKeyboardButton("➕ Новая группа", callback_data=f'new_group_{log_id}_{owner_id}'))
        markup.add(types.InlineKeyboardButton("◀️ Назад", callback_data=f'view_calc_{log_id}_{owner_id}'))
        
        bot.edit_message_text(
            chat_id=call.message.chat.id,
            message_id=call.message.message_id,
            text=f"📁 Управление группами (Запись #{log_id}):",
            reply_markup=markup
        )
    except Exception as e:
        bot.answer_callback_query(call.id, f"Ошибка: {e}")

@bot.callback_query_handler(func=lambda call: call.data.startswith('set_group_'))
def set_group_handler(call):
    try:
        parts = call.data.split('_', 3)
        log_id = parts[2]
        group_name = parts[3]
        owner_id = call.from_user.id 
        
        if fb_update_log_group(owner_id, log_id, group_name):
            bot.answer_callback_query(call.id, f"✅ Перемещено в '{group_name}'")
            # Return to view via simple message edit or call function if possible
            # Simplified: just notification
            call.data = f"view_calc_{log_id}_{owner_id}"
            show_saved_calculation(call)
        else:
            bot.answer_callback_query(call.id, "❌ Ошибка")
    except Exception as e:
        print(f"set_group error: {e}")

@bot.callback_query_handler(func=lambda call: call.data.startswith('remove_group_'))
def remove_group_handler(call):
    try:
        parts = call.data.split('_')
        log_id = parts[2]
        owner_id = parts[3] if len(parts) > 3 else call.from_user.id
        
        if fb_update_log_group(owner_id, log_id, None):
             bot.answer_callback_query(call.id, "✅ Удалено из группы")
             call.data = f"view_calc_{log_id}_{owner_id}"
             show_saved_calculation(call)
        else:
             bot.answer_callback_query(call.id, "❌ Ошибка")
    except Exception as e:
        print(f"remove_group error: {e}")

@bot.callback_query_handler(func=lambda call: call.data.startswith('new_group_'))
def new_group_handler(call):
    parts = call.data.split('_')
    log_id = parts[2]
    msg = bot.send_message(
        call.message.chat.id,
        "📝 Введите название новой папки:",
        reply_markup=types.ForceReply()
    )
    bot.register_next_step_handler(msg, lambda m: save_new_group_firebase(m, log_id))

def save_new_group_firebase(message, log_id):
    group_name = message.text.strip()
    owner_id = message.from_user.id
    if fb_update_log_group(owner_id, log_id, group_name):
        bot.send_message(message.chat.id, f"✅ Папка '{group_name}' создана!")
    else:
        bot.send_message(message.chat.id, "❌ Ошибка создания папки")

# -------------------------



# Обработчик просмотра данных
@bot.callback_query_handler(func=lambda call: call.data == 'view_pgmd_data')
def show_pgmd_data(call):
    conn_pgmd = sqlite3.connect(DB_PATH2)
    try:
        # Получаем уникальные социальные роли
        cursor = conn_pgmd.cursor()
        cursor.execute('SELECT DISTINCT social_role FROM users WHERE social_role IS NOT NULL')
        roles = [row[0] for row in cursor.fetchall()]
        
        markup = types.InlineKeyboardMarkup()
        for role in roles:
            markup.add(types.InlineKeyboardButton(role, callback_data=f'filter_role_{role}'))
        
        markup.row(
            types.InlineKeyboardButton("◀️ Назад", callback_data='diagnostic_analysis'),
            types.InlineKeyboardButton("❌ Закрыть", callback_data='delete_history_msg')
        )
        
        bot.edit_message_text(
            chat_id=call.message.chat.id,
            message_id=call.message.message_id,
            text="📂 Выберите социальную роль:",
            reply_markup=markup
        )
        
    except Exception as e:
        bot.answer_callback_query(call.id, f"⛔ Ошибка: {str(e)}")
    finally:
        conn_pgmd.close()

@bot.callback_query_handler(func=lambda call: call.data.startswith('filter_role_'))
def filter_by_role(call):
    role = call.data.split('_')[2]
    conn_pgmd = sqlite3.connect(DB_PATH2)
    try:
        # Получаем уникальные достижения для выбранной роли
        cursor = conn_pgmd.cursor()
        cursor.execute('''SELECT DISTINCT achievements FROM users 
                       WHERE social_role = ? AND achievements IS NOT NULL''', (role,))
        achievements = [row[0] for row in cursor.fetchall()]

        markup = types.InlineKeyboardMarkup()
        for ach in achievements:
            if ach:  # Пропускаем пустые значения
                markup.add(types.InlineKeyboardButton(ach, callback_data=f'filter_ach_{ach}'))

        markup.row(
            types.InlineKeyboardButton("◀️ Назад", callback_data='view_pgmd_data'),
            types.InlineKeyboardButton("❌ Закрыть", callback_data='delete_history_msg'),
            types.InlineKeyboardButton("Все достижения", callback_data=f'filter_ach_all')
        )
        
        bot.edit_message_text(
            chat_id=call.message.chat.id,
            message_id=call.message.message_id,
            text=f"📂 Выберите достижение для роли {role}:",
            reply_markup=markup
        )
        
        # Сохраняем выбранную роль в данных пользователя
        bot.add_data(call.from_user.id, selected_role=role)

    except Exception as e:
        bot.answer_callback_query(call.id, f"⛔ Ошибка: {str(e)}")
    finally:
        conn_pgmd.close()

@bot.callback_query_handler(func=lambda call: call.data.startswith('filter_ach_'))
def show_filtered_data(call):
    achievement = call.data.split('_')[2]
    user_data = bot.retrieve_data(call.from_user.id)
    role = user_data['selected_role']

    try:
        conn_pgmd = sqlite3.connect(DB_PATH2)
        cursor = conn_pgmd.cursor()
        
        # Формируем запрос с фильтрами
        query = '''
            SELECT m.* 
            FROM user_metrics m
            JOIN users u ON m.user_id = u.id
            WHERE u.social_role = ?
        '''
        params = [role]
        
        if achievement != 'all':
            query += ' AND u.achievements LIKE ?'
            params.append(f'%{achievement}%')

        cursor.execute(query, params)
        records = cursor.fetchall()

        # Далее существующая логика отображения записей...
        
        if not records:
            bot.answer_callback_query(call.id, "📭 База данных PGMD пуста")
            return

        markup = types.InlineKeyboardMarkup()
        for row in records:
            record_id = row[0]
            btn_text = f"{row[2]} | {row[1]} ({row[3]})"
            markup.add(types.InlineKeyboardButton(btn_text, callback_data=f'pgmd_detail_{record_id}'))
        
        markup.row(
            types.InlineKeyboardButton("◀️ Назад", callback_data='diagnostic_analysis'),
            types.InlineKeyboardButton("❌ Закрыть", callback_data='delete_history_msg')
        )
        
        bot.edit_message_text(
            chat_id=call.message.chat.id,
            message_id=call.message.message_id,
            text="📂 Последние записи в PGMD:",
            reply_markup=markup
        )

    

    except Exception as e:
        bot.answer_callback_query(call.id, f"⛔ Ошибка: {str(e)}")
    finally:
        conn_pgmd.close()

# Обработчик детализации записи
@bot.callback_query_handler(func=lambda call: call.data.startswith('pgmd_detail_'))
def show_pgmd_detail(call):
    try:
        record_id = int(call.data.split('_')[2])
        conn = sqlite3.connect(DB_PATH2)
        cursor = conn.cursor()
        
        cursor.execute('''
            SELECT 
                u.name, u.birthdate, u.gender, u.social_role, u.achievements,
                m.num1, m.num2, m.num3, m.num4, m.num5, m.num6, m.num7, m.num8,
                m.num9, m.num10, m.num11, m.num12, m.num13, m.num14
            FROM users u
            JOIN user_metrics m ON u.id = m.user_id
            WHERE u.id = ?
        ''', (record_id,))
        
        data = cursor.fetchone()
        
        if not data:
            bot.answer_callback_query(call.id, "❌ Запись не найдена")
            return

        response = f"""
📄 *Детали записи PGMD*:

👤 Имя: {data[0]}
📅 Дата рождения: {data[1]}
🚻 Пол: {data[2]}
💼 Роль: {data[3]}
🏆 Достижения: {data[4]}

🔢 *Показатели*:
1-4: {data[5]} | {data[6]} | {data[7]} | {data[8]}
5-8: {data[9]} | {data[10]} | {data[11]} | {data[12]}
9-12: {data[13]} | {data[14]} | {data[15]} | {data[16]}
13-14: {data[17]} | {data[18]}
        """
        
        markup = types.InlineKeyboardMarkup()
        markup.row(
            types.InlineKeyboardButton("📋 Полная схема", callback_data=f'pgmd_scheme_{record_id}'),
            types.InlineKeyboardButton("❌ Закрыть", callback_data='delete_history_msg')
        )
        
        msg = bot.send_message(
            call.message.chat.id,
            response,
            parse_mode="Markdown",
            reply_markup=markup
        )
        
        # Сохраняем данные для последующего использования
        bot.add_data(call.from_user.id, record_id=record_id, pgmd_data=data)

    except Exception as e:
        bot.send_message(call.message.chat.id, f"⛔ Ошибка: {str(e)}")
    finally:
        conn.close()

@bot.callback_query_handler(func=lambda call: call.data.startswith('pgmd_scheme_'))
def show_pgmd_scheme(call):
    try:
        record_id = int(call.data.split('_')[2])
        user_data = bot.retrieve_data(call.from_user.id)
        data = user_data['pgmd_data']
        
        scheme = format_scheme(
            data[5], data[6], data[7], data[8], data[9], data[10], data[11],
            data[12], data[13], data[14], data[15], data[16], data[17], data[18],
            data[0], data[1], data[2]
        )
        
        markup = types.InlineKeyboardMarkup()
        markup.row(
            types.InlineKeyboardButton("📋 Текст", callback_data=f'pgmd_text_{record_id}'), 
            types.InlineKeyboardButton("🖼 Изображение", callback_data=f'pgmd_image_{record_id}'),
            types.InlineKeyboardButton("❌ Закрыть", callback_data='delete_history_msg')
        )
        
        bot.send_message(
            call.message.chat.id,
            f"*Диагностика для {data[0]}*:\n```\n{scheme}\n```",
            parse_mode="Markdown",
            reply_markup=markup
        )
        
    except Exception as e:
        bot.send_message(call.message.chat.id, f"⛔ Ошибка: {str(e)}")

@bot.callback_query_handler(func=lambda call: call.data.startswith('pgmd_text_'))
def handle_pgmd_text(call):
    try:
        record_id = int(call.data.split('_')[2])
        user_data = bot.retrieve_data(call.from_user.id)
        data = user_data['pgmd_data']
        
        # Формируем текстовое описание (аналогично истории)
        text_description = generate_text_description(data)
        
        markup = types.InlineKeyboardMarkup()
        markup.add(
            types.InlineKeyboardButton("📋 Подробнее (20 кр)", callback_data=f'detailed_desc_{record_id}'),
            types.InlineKeyboardButton("❌ Закрыть", callback_data='delete_history_msg')
        )
        
        bot.send_message(
            call.message.chat.id,
            text_description,
            parse_mode="Markdown",
            reply_markup=markup
        )
        
    except Exception as e:
        bot.send_message(call.message.chat.id, f"⛔ Ошибка: {str(e)}")

@bot.callback_query_handler(func=lambda call: call.data.startswith('pgmd_image_'))
def handle_pgmd_image(call):
    try:
        record_id = int(call.data.split('_')[2])
        user_data = bot.retrieve_data(call.from_user.id)
        data = user_data['pgmd_data']
        
        # Генерация изображения
        nums = [data[5], data[6], data[7], data[8], data[9], data[10], data[11],
                data[12], data[13], data[14], data[15], data[16], data[17], data[18]]
        
        img_bytes = generate_diagnostic_image(
            nums=nums,
            name=data[0],
            date_str=data[1],
            gender=data[2],
            template_path="D:\BOT\IDPGMD092025.png"
        )
        
        if img_bytes:
            sent_msg = bot.send_photo(
                call.message.chat.id,
                photo=img_bytes,
                caption=f"Диагностика для {data[0]}\nБаза данных PGMD"
            )
            
            markup = types.InlineKeyboardMarkup()
            markup.add(types.InlineKeyboardButton(
                "❌ Закрыть", 
                callback_data=f'delete_image_{sent_msg.message_id}'
            ))
            
            bot.edit_message_reply_markup(
                chat_id=call.message.chat.id,
                message_id=sent_msg.message_id,
                reply_markup=markup
            )

    except Exception as e:
        bot.send_message(call.message.chat.id, f"⛔ Ошибка: {str(e)}")

# Duplicate generate_text_description removed

# Модифицируем обработчик ввода данных
def process_character_data(message):
    try:
        data = [x.strip() for x in message.text.split(',')]
        if len(data) != 5:
            raise ValueError("Неверный формат данных")

        birthdate, name, gender, social_role, achievements = data
        day, month, year = map(int, birthdate.split('.'))
        
        # Проверка корректности даты
        datetime(year=year, month=month, day=day)  # Теперь работает
        
        # Рассчитываем метрики
        scheme_result, nums = calculate_diagnostic(birthdate, name, gender)
        
        # Сохраняем во вторую базу
        conn = sqlite3.connect(DB_PATH2)
        cursor = conn.cursor()
        
        cursor.execute('''
            INSERT INTO users 
            (birthdate, name, gender, social_role, achievements)
            VALUES (?, ?, ?, ?, ?)
        ''', (
            f"{year}-{month:02}-{day:02}",
            name,
            gender.upper(),
            social_role,
            achievements
        ))
        
        user_id = cursor.lastrowid
        
        cursor.execute('''
            INSERT INTO user_metrics 
            (user_id, num1, num2, num3, num4, num5, num6, num7, 
             num8, num9, num10, num11, num12, num13, num14)
            VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?)
        ''', (user_id, *nums))
        
        conn.commit()
        
        bot.send_message(
            message.chat.id,
            f"✅ Персонаж успешно добавлен!\n"
            f"Имя: {name}\nРоль: {social_role}\nДостижения: {achievements}\n"
            f"Результаты:\n```\n{scheme_result}\n```",
            parse_mode='Markdown'
        )
        
    except Exception as e:
        bot.send_message(
            message.chat.id,
            f"❌ Ошибка: {str(e)}\nПравильный формат:\n"
            "ДД.ММ.ГГГГ, Имя, Пол(М/Ж), Соц.роль, Достижения\n"
            "Пример: 25.05.1990, Иван Иванов, М, Руководитель, Высокие продажи"
        )
    finally:
        if conn:
            conn.close()

# Обработчик ввода данных
@bot.callback_query_handler(func=lambda call: call.data == 'input_data')
def start_input_data(call):
    text = (
        "📥 Введите данные персонажей через ';'\n"
        "<b>Формат каждой записи:</b>\n"
        "ДД.ММ.ГГГГ, Имя, Пол(М/Ж), Соц.роль, Достижения\n\n"
        "Пример:\n"
        "<code>25.05.1990, Иван Иванов, М, Руководитель, Высокие продажи;"
        "25.07.1993, Петр Петров, М, Руководитель, Высокие продажи</code>"
    )
    
    bot.send_message(
        call.message.chat.id,
        text,
        parse_mode='HTML'
    )
    bot.register_next_step_handler(call.message, process_batch_data)

def process_batch_data(message):
    try:
        batch = message.text.split(';')
        total = len(batch)
        success = 0
        errors = []
        
        conn = sqlite3.connect(DB_PATH2)
        cursor = conn.cursor()
        
        for i, record in enumerate(batch, 1):
            record = record.strip()
            if not record:
                continue
                
            try:
                data = [x.strip() for x in record.split(',')]
                if len(data) != 5:
                    raise ValueError(f"Неверное количество полей в записи {i}")

                birthdate, name, gender, social_role, achievements = data
                day, month, year = map(int, birthdate.split('.'))
                datetime(year=year, month=month, day=day)
                
                # Расчет метрик
                scheme_result, nums = calculate_diagnostic(birthdate, name, gender)
                
                # Добавление в базу
                cursor.execute('''
                    INSERT INTO users 
                    (birthdate, name, gender, social_role, achievements)
                    VALUES (?, ?, ?, ?, ?)
                ''', (
                    f"{year}-{month:02}-{day:02}",
                    name,
                    gender.upper(),
                    social_role,
                    achievements
                ))
                
                user_id = cursor.lastrowid
                
                cursor.execute('''
                    INSERT INTO user_metrics 
                    (user_id, num1, num2, num3, num4, num5, num6, num7, 
                     num8, num9, num10, num11, num12, num13, num14)
                    VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?)
                ''', (user_id, *nums))
                
                success += 1
                
            except Exception as e:
                errors.append(f"Запись {i}: {str(e)}")
                conn.rollback()  # Откатываем транзакцию для текущей записи
                continue
                
        conn.commit()
        
        report = [
            f"📊 Итоговый отчет:",
            f"• Успешно добавлено: {success}/{total}",
            f"• Ошибки: {len(errors)}"
        ]
        
        if errors:
            report.append("\n🔧 Детали ошибок:")
            report.extend(errors[:5])  # Показываем первые 5 ошибок
            
        bot.send_message(
            message.chat.id,
            "\n".join(report),
            parse_mode='Markdown'
        )
        
    except Exception as e:
        bot.send_message(
            message.chat.id,
            f"❌ Критическая ошибка: {str(e)}"
        )
    finally:
        if conn:
            conn.close()


#__________________________________


# Главное меню Диагностика

@bot.message_handler(func=lambda message: message.text == '🧠 Диагностика')
def pgmd_main_menu(message):
    user_id = message.from_user.id
    conn = sqlite3.connect(DB_PATH, check_same_thread=False)
    cursor = conn.cursor()
    try:
        cursor.execute('SELECT pgmd FROM Partn WHERE user_id = ?', (user_id,))
        pgmd_level = cursor.fetchone()[0]
        
        if pgmd_level == 100:
            text = "🧬 Индивидуальная диагностика потенциала\nВыберите раздел:"
            markup = types.InlineKeyboardMarkup()
            btn1 = types.InlineKeyboardButton("🔍 Расчет", callback_data='diagnostic_calc')
            btn2 = types.InlineKeyboardButton("📜 История", callback_data='diagnostic_history') 
            btn3 = types.InlineKeyboardButton("🧠 Роль", callback_data='podkorkovye_zony')
            btn4 = types.InlineKeyboardButton("🔀 Аспекты", callback_data='aspects_menu')
            btn5 = types.InlineKeyboardButton("🛠 Анализ", callback_data='diagnostic_analysis')
            btn6 = types.InlineKeyboardButton("📖 Расшифровка", callback_data='decryption_info')
            btn7 = types.InlineKeyboardButton("❌ Закрыть", callback_data='delete_history_msg')
            markup.add(btn1, btn2)
            markup.add(btn3, btn4)
            markup.add(btn5, btn6)
            markup.add(btn7)
            bot.send_message(message.chat.id, text, reply_markup=markup)

        elif pgmd_level and pgmd_level >= 3:
            text = "🧬 Индивидуальная диагностика потенциала\nВыберите раздел:"
            markup = types.InlineKeyboardMarkup()
            btn1 = types.InlineKeyboardButton("🔍 Расчет", callback_data='diagnostic_calc')
            btn2 = types.InlineKeyboardButton("📜 История", callback_data='diagnostic_history') 
            btn3 = types.InlineKeyboardButton("🧠 Роль", callback_data='podkorkovye_zony')
            btn4 = types.InlineKeyboardButton("🔀 Аспекты", callback_data='aspects_menu')
            btn5 = types.InlineKeyboardButton("📖 Расшифровка", callback_data='decryption_info')
            btn6 = types.InlineKeyboardButton("❌ Закрыть", callback_data='delete_history_msg')
            markup.add(btn1, btn2)
            markup.add(btn3, btn4)
            markup.add(btn5, btn6)
            bot.send_message(message.chat.id, text, reply_markup=markup)
            
        elif pgmd_level and pgmd_level >= 1:
            text = "🧬 Индивидуальная диагностика потенциала\nВыберите раздел:"
            markup = types.InlineKeyboardMarkup()
            btn1 = types.InlineKeyboardButton("🔍 Расчет", callback_data='diagnostic_calc')
            btn2 = types.InlineKeyboardButton("📜 История", callback_data='diagnostic_history') 
            btn3 = types.InlineKeyboardButton("🧠 Роль", callback_data='podkorkovye_zony')
            btn4 = types.InlineKeyboardButton("📖 Расшифровка", callback_data='decryption_info')
            btn5 = types.InlineKeyboardButton("❌ Закрыть", callback_data='delete_history_msg')
            markup.add(btn1, btn2, btn3)
            markup.add(btn4, btn5)
            bot.send_message(message.chat.id, text, reply_markup=markup)
        else:
            bot.send_message(
                message.chat.id,
                "❌ Доступ к разделу Диагностика закрыт.\n"
                "Для получения доступа необходимо зарегистрироваться через команду /start."
            )
    finally:
        conn.close()


@bot.callback_query_handler(func=lambda call: call.data == 'decryption_info')
def handle_decryption_info(call):
    text = "Подробную информацию и Расшифровку диагностики заказывайте на сайте https://infocards.club/id_potential"
    markup = types.InlineKeyboardMarkup()
    markup.add(types.InlineKeyboardButton("❌ Закрыть", callback_data='delete_history_msg'))
    
    bot.send_message(
        call.message.chat.id,
        text,
        reply_markup=markup
    )

@bot.message_handler(func=lambda message: message.text == '📖 Расшифровка')
def handle_decryption_text(message):
    text = "Подробную информацию и Расшифровку диагностики заказывайте на сайте https://infocards.club/id_potential"
    markup = types.ReplyKeyboardMarkup(resize_keyboard=True)
    markup.row(types.KeyboardButton('🧠 Диагностика'), types.KeyboardButton('🏢 Мой кабинет'))
    
    bot.send_message(
        message.chat.id,
        text,
        reply_markup=markup
    )

@bot.callback_query_handler(func=lambda call: call.data == 'aspects_menu')
def aspects_menu_handler(call):
    text = "🔀 Аспекты личности\nВыберите аспект для просмотра:"
    markup = types.InlineKeyboardMarkup(row_width=3)
    
    # Создаем кнопки для аспектов из словаря ASPECTS_ROLE
    buttons = []
    for aspect_key, aspect_data in ASPECTS_ROLE.items():
        btn_text = f"{aspect_key}"
        buttons.append(types.InlineKeyboardButton(btn_text, callback_data=f'aspect_{aspect_key}'))
    
    # Разбиваем на ряды по 3 кнопки
    for i in range(0, len(buttons), 3):
        markup.row(*buttons[i:i+3])
    
    # Добавляем кнопку "Назад"
    back_btn = types.InlineKeyboardButton("◀️ Назад", callback_data='back_to_pgmd')
    markup.add(back_btn)
    
    bot.edit_message_text(
        chat_id=call.message.chat.id,
        message_id=call.message.message_id,
        text=text,
        reply_markup=markup
    )

@bot.callback_query_handler(func=lambda call: call.data.startswith('aspect_'))
def send_aspect_description(call):
    try:
        aspect_key = call.data.split('_', 1)[1]
        aspect_data = ASPECTS_ROLE.get(aspect_key)
        
        if not aspect_data:
            bot.answer_callback_query(call.id, "Аспект не найден!")
            return

        # Формируем описание аспекта аналогично ролям
        caption = (
            f"**Аспект {aspect_data.get('aspect_display', 'x → x')}: {aspect_data.get('aspect_name', 'Название')}**\n\n"
            f"**🧠 Ключевое качество:**\n"
            f"{aspect_data.get('aspect_strength', 'Описание отсутствует')}\n\n"
            f"**⚡ Вызов (опасность):**\n"
            f"{aspect_data.get('aspect_challenge', 'Описание отсутствует')}\n\n"
            f"**🌍 Проявление в жизни:**\n"
            f"{aspect_data.get('aspect_inlife', 'Описание отсутствует')}\n\n"
            f"**💥 Эмоциональный посыл:**\n"
            f"{aspect_data.get('aspect_emotion', 'Описание отсутствует')}\n\n"
            f"**🎭 Как выглядит:**\n"
            f"{aspect_data.get('aspect_manifestation', 'Описание отсутствует')}\n\n"
            f"**❓ Вопрос для рефлексии:**\n"
            f"*{aspect_data.get('aspect_question', 'Вопрос отсутствует')}*"
        )

        # Отправляем описание аспекта
        sent_msg = bot.send_message(
            chat_id=call.message.chat.id,
            text=caption,
            parse_mode="Markdown"
        )

        # Добавляем кнопку закрытия
        markup = types.InlineKeyboardMarkup()
        markup.add(types.InlineKeyboardButton(
            "Просмотрено ✅", 
            callback_data=f'delete_{sent_msg.message_id}'
        ))
        
        bot.edit_message_reply_markup(
            chat_id=call.message.chat.id,
            message_id=sent_msg.message_id,
            reply_markup=markup
        )
        
    except Exception as e:
        bot.send_message(call.message.chat.id, f"Ошибка: {e}")
# Обработчик для кнопки "Назад" в меню аспектов
@bot.callback_query_handler(func=lambda call: call.data == 'back_to_pgmd')
def back_to_pgmd_from_history(call):
    user_id = call.from_user.id
    conn = sqlite3.connect(DB_PATH, check_same_thread=False)
    cursor = conn.cursor()
    
    try:
        cursor.execute('SELECT pgmd FROM Partn WHERE user_id = ?', (user_id,))
        pgmd_level = cursor.fetchone()[0]
        
        if pgmd_level == 100:
            text = "🧬 Индивидуальная диагностика потенциала\nВыберите раздел:"
            markup = types.InlineKeyboardMarkup()
            btn1 = types.InlineKeyboardButton("🔍 Расчет", callback_data='diagnostic_calc')
            btn2 = types.InlineKeyboardButton("📜 История", callback_data='diagnostic_history') 
            btn3 = types.InlineKeyboardButton("🧠 Роль", callback_data='podkorkovye_zony')
            btn4 = types.InlineKeyboardButton("🔀 Аспекты", callback_data='aspects_menu')
            btn5 = types.InlineKeyboardButton("🛠 Анализ", callback_data='diagnostic_analysis')
            btn6 = types.InlineKeyboardButton("📨 Рассылка", callback_data='admin_broadcast')
            btn7 = types.InlineKeyboardButton("📖 Расшифровка", callback_data='decryption_info')
            btn8 = types.InlineKeyboardButton("❌ Закрыть", callback_data='delete_history_msg')
            markup.add(btn1, btn2)
            markup.add(btn3, btn4)
            markup.add(btn5, btn6)
            markup.add(btn7, btn8)
            
        elif pgmd_level >= 3:
            text = "🧬 Индивидуальная диагностика потенциала\nВыберите раздел:"
            markup = types.InlineKeyboardMarkup()
            btn1 = types.InlineKeyboardButton("🔍 Расчет", callback_data='diagnostic_calc')
            btn2 = types.InlineKeyboardButton("📜 История", callback_data='diagnostic_history') 
            btn3 = types.InlineKeyboardButton("🧠 Роль", callback_data='podkorkovye_zony')
            btn4 = types.InlineKeyboardButton("🔀 Аспекты", callback_data='aspects_menu')
            btn5 = types.InlineKeyboardButton("📖 Расшифровка", callback_data='decryption_info')
            btn6 = types.InlineKeyboardButton("❌ Закрыть", callback_data='delete_history_msg')
            markup.add(btn1, btn2)
            markup.add(btn3, btn4)
            markup.add(btn5, btn6)
        else:
            text = "🧬 Индивидуальная диагностика потенциала\nВыберите раздел:"
            markup = types.InlineKeyboardMarkup()
            btn1 = types.InlineKeyboardButton("🔍 Расчет", callback_data='diagnostic_calc')
            btn2 = types.InlineKeyboardButton("📜 История", callback_data='diagnostic_history') 
            btn3 = types.InlineKeyboardButton("🧠 Роль", callback_data='podkorkovye_zony')
            btn4 = types.InlineKeyboardButton("📖 Расшифровка", callback_data='decryption_info')
            btn5 = types.InlineKeyboardButton("❌ Закрыть", callback_data='delete_history_msg')
            markup.add(btn1, btn2, btn3)
            markup.add(btn4, btn5)
        
        bot.edit_message_text(
            chat_id=call.message.chat.id,
            message_id=call.message.message_id,
            text=text,
            reply_markup=markup
        )
        
    finally:
        conn.close()

# Обработчик для расчета диагностики
@bot.callback_query_handler(func=lambda call: call.data == 'diagnostic_calc')
def start_diagnostic(call):
    text = (
        "📅 Для расчета диагностики введите данные в формате:\n"
        "<b>ДД.ММ.ГГГГ, Имя, Пол (М/Ж)</b>\n\n"
        "Пример:\n"
        "<code>29.03.1988, Олег, М</code>\n\n"
        "❕ Нажмите 'Отмена' чтобы прервать ввод\n\n"
        "Стоимость одного расчета 5 кредитов"
    )
    markup = types.InlineKeyboardMarkup()
    markup.add(types.InlineKeyboardButton("❌ Отмена", callback_data='cancel_diagnostic'))
    
    bot.send_message(
        call.message.chat.id,
        text,
        parse_mode='HTML',
        reply_markup=markup
    )
    bot.register_next_step_handler(call.message, process_diagnostic_data)

# обработчик для отмены диагностики
@bot.callback_query_handler(func=lambda call: call.data == 'cancel_diagnostic')
def cancel_diagnostic(call):
    try:
        bot.delete_message(call.message.chat.id, call.message.message_id)
        # Очищаем ожидание следующего шага
        bot.clear_step_handler(call.message)
    except Exception as e:
        print(f"Ошибка: {e}")
    
    back_to_main_menu(call.message)


def back_to_main_menu(message_or_call):
    if isinstance(message_or_call, types.CallbackQuery):
        message = message_or_call.message
    else:
        message = message_or_call
        
    markup = types.ReplyKeyboardMarkup(resize_keyboard=True)
    markup.row(types.KeyboardButton('🧠 Диагностика'), types.KeyboardButton('🏢 Мой кабинет'))
    
    bot.send_message(
        message.chat.id,
        "Главное меню:",
        reply_markup=markup 
    )
       


# обработчик process_diagnostic_data
def display_diagnostic_result(message, scheme_result, nums, log_id, name, date_str):
    user_id = message.from_user.id
    markup = types.InlineKeyboardMarkup()
    markup.row(
        types.InlineKeyboardButton("📋 Текст", callback_data=f'text_format_{log_id}_{user_id}'),
        types.InlineKeyboardButton("📋 Подробнее (20 кр)", callback_data=f'detailed_desc_{log_id}_{user_id}'),
        types.InlineKeyboardButton("🖼 Изображение", callback_data=f'image_format_{log_id}_{user_id}')
    )
    markup.row(
        types.InlineKeyboardButton("📁 В группу", callback_data=f'manage_group_{log_id}'),
        types.InlineKeyboardButton("🔄 Новый расчет", callback_data='new_calculation')
    )
    markup.row(types.InlineKeyboardButton("❌ Закрыть", callback_data='delete_history_msg'))
    
    bot.send_message(
        message.chat.id, 
        f"*Результат для {name}:*\n```\n{scheme_result}\n```", 
        parse_mode='Markdown', 
        reply_markup=markup
    )
    
    bot.send_message(message.chat.id, f"✅ Расчет выполнен успешно и сохранен в облаке!")

def process_diagnostic_data(message):
    user_id = message.from_user.id
    
    if not fb_check_access(user_id, 1):
        bot.send_message(message.chat.id, "❌ Доступ к расчету запрещен. Пройдите регистрацию (/start)!")
        return

    is_admin = fb_check_access(user_id, 100)
    current_credits = fb_get_credits(user_id)
    
    if not is_admin and current_credits < 5:
        markup = types.InlineKeyboardMarkup()
        markup.add(types.InlineKeyboardButton( "📨 Отправить заявку администратору", callback_data=f"request_credits_{user_id}" ))
        bot.send_message(message.chat.id, f"❌ Недостаточно кредитов (нужно 5, у вас {current_credits}).", reply_markup=markup)
        return

    if message.text.strip() == '❌ Отмена':
        cancel_diagnostic(message)
        return

    try:
        data = [x.strip() for x in message.text.split(',')]
        if len(data) != 3:
            raise ValueError("Неверный формат данных. Используйте: ДД.ММ.ГГГГ, Имя, Пол (М/Ж)")

        date_str, name, gender = data
        day, month, year = map(int, date_str.split('.'))
        clean_date = f"{day:02}.{month:02}.{year}"
        gender = gender.upper()
        if gender not in ('М', 'Ж'):
            raise ValueError("Некорректное значение пола. Используйте М или Ж")

        scheme_result, nums = calculate_diagnostic(date_str=clean_date, name=name.strip(), gender=gender)
        
        if not nums or len(nums) != 14:
            raise ValueError("Ошибка расчета параметров")

        if not is_admin:
            if not fb_deduct_credits(user_id, 5):
                bot.send_message(message.chat.id, "❌ Ошибка списания кредитов. Попробуйте снова.")
                return
        
        log_id = fb_add_log(user_id, name.strip(), clean_date, gender, nums)
        
        display_diagnostic_result(message, scheme_result, nums, log_id, name.strip(), clean_date)

    except ValueError as e:
        bot.send_message(message.chat.id, f"⚠️ Ошибка: {e}")
    except Exception as e:
        print(f"Global Error: {e}")
        bot.send_message(message.chat.id, "⛔ Произошла ошибка сервера")
#_____________________
def is_user_accessible(user_id):
    """Проверяет, доступен ли пользователь для получения сообщений"""
    try:
        # Пытаемся получить информацию о чате
        chat = bot.get_chat(user_id)
        return True
    except Exception as e:
        error_msg = str(e)
        # Проверяем тип ошибки
        if "chat not found" in error_msg:
            return False  # Чат не найден
        elif "bot was blocked by the user" in error_msg:
            return False  # Бот заблокирован
        elif "user is deactivated" in error_msg:
            return False  # Пользователь деактивирован
        return False  # Другие ошибки
    
import csv
from datetime import datetime

def log_broadcast_result(admin_id, broadcast_type, total_sent, total_failed, details=None):
    """Логирует результаты рассылки в CSV файл"""
    try:
        log_file = "broadcast_log.csv"
        file_exists = os.path.isfile(log_file)
        
        with open(log_file, 'a', newline='', encoding='utf-8') as f:
            writer = csv.writer(f, delimiter=';')
            
            # Записываем заголовок, если файл новый
            if not file_exists:
                writer.writerow([
                    'Дата и время', 'ID администратора', 'Тип рассылки',
                    'Всего отправлено', 'Не удалось отправить', 'Успешно', 
                    'Процент успеха', 'Детали'
                ])
            
            # Рассчитываем процент успеха
            success_rate = (total_sent / (total_sent + total_failed)) * 100 if (total_sent + total_failed) > 0 else 0
            
            # Записываем данные
            writer.writerow([
                datetime.now().strftime("%Y-%m-%d %H:%M:%S"),
                admin_id,
                broadcast_type,
                total_sent + total_failed,
                total_failed,
                total_sent,
                f"{success_rate:.1f}%",
                details or ""
            ])
            
    except Exception as e:
        print(f"Ошибка при записи лога: {e}")

# Функция экспорта данных
def export_calculations_data(user_id):
    """Экспортирует историю расчетов пользователя в JSON формат"""
    conn = sqlite3.connect(DB_PATH)
    cursor = conn.cursor()
    
    try:
        # Получаем все расчеты пользователя
        cursor.execute('''
            SELECT 
                dl.id as log_id,
                dl.birth_date,
                dl.name,
                dl.gender,
                dl.calculation_date,
                dl.user_group,
                dl.decryption,
                dr.num1, dr.num2, dr.num3, dr.num4, dr.num5, dr.num6, dr.num7, dr.num8,
                dr.num9, dr.num10, dr.num11, dr.num12, dr.num13, dr.num14
            FROM diagnostic_logs dl
            LEFT JOIN diagnostic_results dr ON dl.id = dr.log_id
            WHERE dl.user_id = ?
            ORDER BY dl.calculation_date DESC
        ''', (user_id,))
        
        calculations = []
        seen_entries = set()  # Для проверки дубликатов при экспорте
        
        for row in cursor.fetchall():
            # Формируем уникальный ключ для проверки дубликатов
            entry_key = (row[1], row[2], row[3])  # birth_date, name, gender
            
            if entry_key in seen_entries:
                continue  # Пропускаем дубликаты
                
            seen_entries.add(entry_key)
            
            calculation_data = {
                'log_id': row[0],
                'birth_date': row[1],
                'name': row[2],
                'gender': row[3],
                'calculation_date': row[4],
                'user_group': row[5],
                'decryption': row[6],
                'numbers': list(row[7:21])  # 14 чисел
            }
            calculations.append(calculation_data)
        
        # Получаем список уникальных групп пользователя
        cursor.execute('''
            SELECT DISTINCT user_group 
            FROM diagnostic_logs 
            WHERE user_id = ? AND user_group IS NOT NULL AND user_group != ''
            ORDER BY user_group
        ''', (user_id,))
        
        folders = [row[0] for row in cursor.fetchall()]
        
        # Формируем итоговый объект данных
        export_data = {
            'version': 1.0,
            'export_date': datetime.now().isoformat(),
            'total_calculations': len(calculations),
            'total_folders': len(folders),
            'calculations': calculations,
            'folders': folders
        }
        
        return json.dumps(export_data, ensure_ascii=False, indent=2)
        
    finally:
        conn.close()

# Функция импорта данных
def import_calculations_data(user_id, json_data):
    """Импортирует данные из JSON в базу данных"""
    conn = sqlite3.connect(DB_PATH)
    cursor = conn.cursor()
    
    try:
        data = json.loads(json_data)
        
        if 'calculations' not in data:
            return {"success": False, "message": "❌ Неверный формат файла: отсутствуют данные расчетов"}
        
        imported_count = 0
        skipped_count = 0
        errors = []
        
        # Импорт папок (создаем только если их нет)
        if 'folders' in data:
            for folder in data['folders']:
                if folder and folder.strip():
                    # Проверяем, есть ли уже такая группа у пользователя
                    cursor.execute('''
                        SELECT COUNT(*) FROM diagnostic_logs 
                        WHERE user_id = ? AND user_group = ?
                    ''', (user_id, folder.strip()))
                    if cursor.fetchone()[0] == 0:
                        # Можно запомнить, что группа существует, но расчетов пока нет
                        # В нашем случае группы создаются автоматически при добавлении расчета
                        pass
        
        # Импорт расчетов
        for idx, calc in enumerate(data['calculations']):
            try:
                # Проверяем обязательные поля
                required_fields = ['birth_date', 'name', 'gender', 'numbers']
                for field in required_fields:
                    if field not in calc:
                        errors.append(f"Запись {idx+1}: отсутствует поле '{field}'")
                        continue
                
                # Проверяем формат даты
                try:
                    day, month, year = map(int, calc['birth_date'].split('.'))
                    clean_date = f"{day:02}.{month:02}.{year}"
                except:
                    errors.append(f"Запись {idx+1}: неверный формат даты '{calc['birth_date']}'")
                    continue
                
                # Проверяем пол
                gender = calc['gender'].upper()
                if gender not in ('М', 'Ж'):
                    errors.append(f"Запись {idx+1}: неверное значение пола '{gender}'")
                    continue
                
                # Проверяем числа
                numbers = calc['numbers']
                if not isinstance(numbers, list) or len(numbers) != 14:
                    errors.append(f"Запись {idx+1}: неверный формат чисел (нужно 14 значений)")
                    continue
                
                # Проверяем, существует ли уже такой расчет
                cursor.execute('''
                    SELECT id FROM diagnostic_logs 
                    WHERE user_id = ? AND birth_date = ? AND name = ? AND gender = ?
                ''', (user_id, clean_date, calc['name'].strip(), gender))
                
                if cursor.fetchone() is not None:
                    skipped_count += 1
                    continue  # Пропускаем дубликат
                
                # Получаем дату расчета из импортируемых данных или используем текущую
                if 'calculation_date' in calc and calc['calculation_date']:
                    try:
                        # Пробуем разные форматы даты
                        if 'T' in calc['calculation_date']:
                            calculation_date = calc['calculation_date'].replace('T', ' ')
                        else:
                            calculation_date = calc['calculation_date']
                    except:
                        calculation_date = datetime.now().strftime("%Y-%m-%d %H:%M:%S")
                else:
                    calculation_date = datetime.now().strftime("%Y-%m-%d %H:%M:%S")
                
                # Получаем группу (если есть)
                user_group = calc.get('user_group')
                if user_group:
                    user_group = user_group.strip()
                    if not user_group:
                        user_group = None
                
                # Получаем статус расшифровки
                decryption = calc.get('decryption', 0)
                
                # Вставляем запись в diagnostic_logs
                cursor.execute('''
                    INSERT INTO diagnostic_logs 
                    (user_id, birth_date, name, gender, calculation_date, user_group, decryption)
                    VALUES (?, ?, ?, ?, ?, ?, ?)
                ''', (user_id, clean_date, calc['name'].strip(), gender, 
                     calculation_date, user_group, decryption))
                
                log_id = cursor.lastrowid
                
                # Вставляем числа в diagnostic_results
                cursor.execute('''
                    INSERT INTO diagnostic_results 
                    (user_id, log_id, calculation_date, num1, num2, num3, num4, 
                     num5, num6, num7, num8, num9, num10, num11, num12, num13, num14)
                    VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?)
                ''', (user_id, log_id, calculation_date, *numbers))
                
                imported_count += 1
                
            except Exception as e:
                errors.append(f"Запись {idx+1}: ошибка обработки - {str(e)}")
                continue
        
        conn.commit()
        
        result = {
            "success": True,
            "message": f"✅ Импорт завершен!\n\n📊 Статистика:\n• Импортировано: {imported_count} записей\n• Пропущено (дубликаты): {skipped_count}\n• Ошибок: {len(errors)}",
            "stats": {
                "imported": imported_count,
                "skipped": skipped_count,
                "errors": len(errors)
            }
        }
        
        if errors:
            result["error_details"] = errors[:10]  # Первые 10 ошибок
        
        return result
        
    except json.JSONDecodeError:
        return {"success": False, "message": "❌ Ошибка: неверный JSON формат файла"}
    except Exception as e:
        return {"success": False, "message": f"❌ Ошибка импорта: {str(e)}"}
    finally:
        conn.close()

# Duplicate history handler removed


# Обработчик экспорта
@bot.callback_query_handler(func=lambda call: call.data == 'export_calculations')
def handle_export(call):
    user_id = call.from_user.id
    
    try:
        # Генерируем JSON данные
        json_data = export_calculations_data(user_id)
        
        # Создаем временный файл
        with tempfile.NamedTemporaryFile(mode='w', suffix='.json', 
                                        encoding='utf-8', delete=False) as f:
            f.write(json_data)
            temp_file = f.name
        
        # Отправляем файл пользователю
        with open(temp_file, 'rb') as file:
            bot.send_document(
                call.message.chat.id,
                file,
                caption=f"📤 Экспорт истории расчетов\n\n"
                       f"Формат: JSON\n"
                       f"Дата: {datetime.now().strftime('%d.%m.%Y %H:%M')}\n\n"
                       f"*Для импорта используйте кнопку '📥 Импорт'*",
                parse_mode="Markdown"
            )
        
        # Удаляем временный файл
        os.unlink(temp_file)
        
        bot.answer_callback_query(call.id, "✅ Экспорт завершен!")
        
    except Exception as e:
        bot.answer_callback_query(call.id, f"❌ Ошибка экспорта: {str(e)[:50]}")

# Обработчик импорта
@bot.callback_query_handler(func=lambda call: call.data == 'import_calculations')
def handle_import(call):
    markup = types.InlineKeyboardMarkup()
    markup.row(
        types.InlineKeyboardButton("📋 Инструкция", callback_data='import_instructions'),
        types.InlineKeyboardButton("◀️ Назад", callback_data='diagnostic_history')
    )
    
    bot.edit_message_text(
        chat_id=call.message.chat.id,
        message_id=call.message.message_id,
        text=(
            "📥 *Импорт истории расчетов*\n\n"
            "1. Отправьте мне JSON файл, полученный при экспорте\n"
            "2. Файл должен быть в формате .json\n"
            "3. Поддерживается импорт:\n"
            "   • Всех расчетов\n"
            "   • Групп (папок)\n"
            "   • Статуса расшифровок\n\n"
            "⚠️ *Внимание:* Дубликаты расчетов будут автоматически пропущены!"
        ),
        parse_mode="Markdown",
        reply_markup=markup
    )

# Обработчик инструкций по импорту
@bot.callback_query_handler(func=lambda call: call.data == 'import_instructions')
def show_import_instructions(call):
    instructions = (
        "📋 *Инструкция по импорту*\n\n"
        "1. *Получите файл экспорта:*\n"
        "   • Используйте кнопку '📤 Экспорт'\n"
        "   • Сохраните полученный JSON файл\n\n"
        "2. *Подготовка файла:*\n"
        "   • Файл должен быть в формате .json\n"
        "   • Не изменяйте структуру файла\n"
        "   • Можно удалить ненужные записи\n\n"
        "3. *Импорт:*\n"
        "   • Нажмите '📥 Импорт'\n"
        "   • Отправьте JSON файл как документ\n\n"
        "4. *Особенности:*\n"
        "   • Дубликаты пропускаются\n"
        "   • Группы создаются автоматически\n"
        "   • Сохраняются даты расчетов\n\n"
        "📄 *Формат файла:*\n"
        "```json\n"
        "{\n"
        "  \"version\": 1.0,\n"
        "  \"calculations\": [\n"
        "    {\n"
        "      \"birth_date\": \"01.01.1990\",\n"
        "      \"name\": \"Иван\",\n"
        "      \"gender\": \"М\",\n"
        "      \"numbers\": [1, 2, 3, ...]\n"
        "    }\n"
        "  ]\n"
        "}\n"
        "```"
    )
    
    markup = types.InlineKeyboardMarkup()
    markup.add(
        types.InlineKeyboardButton("◀️ Назад", callback_data='import_calculations')
    )
    
    bot.edit_message_text(
        chat_id=call.message.chat.id,
        message_id=call.message.message_id,
        text=instructions,
        parse_mode="Markdown",
        reply_markup=markup
    )

# Обработчик документов (для импорта JSON)
@bot.message_handler(content_types=['document'])
def handle_document(message):
    # Проверяем, что это JSON файл
    if not message.document.file_name.endswith('.json'):
        return
    
    user_id = message.from_user.id
    
    # Сообщаем о начале обработки
    processing_msg = bot.send_message(
        message.chat.id,
        "⏳ Обрабатываю файл импорта..."
    )
    
    try:
        # Скачиваем файл
        file_info = bot.get_file(message.document.file_id)
        downloaded_file = bot.download_file(file_info.file_path)
        
        # Декодируем содержимое
        json_data = downloaded_file.decode('utf-8')
        
        # Импортируем данные
        result = import_calculations_data(user_id, json_data)
        
        # Отправляем результат
        response_text = result['message']
        
        if result.get('success'):
            # Добавляем статистику
            stats = result.get('stats', {})
            if stats:
                response_text += f"\n\n📈 *Детальная статистика:*\n"
                response_text += f"• Успешно импортировано: {stats.get('imported', 0)}\n"
                response_text += f"• Пропущено (дубликаты): {stats.get('skipped', 0)}\n"
                response_text += f"• Ошибок при обработке: {stats.get('errors', 0)}"
            
            # Показываем детали ошибок (первые 5)
            if 'error_details' in result and result['error_details']:
                response_text += "\n\n⚠️ *Первые 5 ошибок:*\n"
                for error in result['error_details'][:5]:
                    response_text += f"• {error}\n"
                
                if len(result['error_details']) > 5:
                    response_text += f"\n... и еще {len(result['error_details']) - 5} ошибок"
        
        # Кнопка для просмотра истории
        markup = types.InlineKeyboardMarkup()
        markup.add(
            types.InlineKeyboardButton("📂 Перейти в историю", callback_data='diagnostic_history')
        )
        
        bot.edit_message_text(
            chat_id=message.chat.id,
            message_id=processing_msg.message_id,
            text=response_text,
            parse_mode="Markdown",
            reply_markup=markup
        )
        
    except UnicodeDecodeError:
        bot.edit_message_text(
            chat_id=message.chat.id,
            message_id=processing_msg.message_id,
            text="❌ Ошибка: неверная кодировка файла. Используйте UTF-8."
        )
    except Exception as e:
        bot.edit_message_text(
            chat_id=message.chat.id,
            message_id=processing_msg.message_id,
            text=f"❌ Ошибка обработки файла: {str(e)[:100]}"
        )

@bot.callback_query_handler(func=lambda call: call.data.startswith('group_'))
def show_group_entries(call):
    group_name = call.data.split('_', 1)[1]
    user_id = call.from_user.id
    
    conn = sqlite3.connect(DB_PATH)
    try:
        cursor = conn.cursor()
        cursor.execute('''
            SELECT id, birth_date, name 
            FROM diagnostic_logs 
            WHERE user_id = ? AND user_group = ?
            ORDER BY calculation_date DESC
        ''', (user_id, group_name))
        
        entries = cursor.fetchall()
        
        markup = types.InlineKeyboardMarkup()
        for entry in entries:
            entry_id, date, name = entry
            markup.add(types.InlineKeyboardButton(
                f"{date} - {name}", 
                callback_data=f'view_calc_{entry_id}'
            ))
        
        markup.row(
            types.InlineKeyboardButton("◀️ Назад", callback_data='diagnostic_history'),
            types.InlineKeyboardButton("❌ Закрыть", callback_data='delete_history_msg')
        )
        
        bot.edit_message_text(
            chat_id=call.message.chat.id,
            message_id=call.message.message_id,
            text=f"📁 Группа: {group_name}",
            reply_markup=markup
        )
    finally:
        conn.close()

# Duplicate Group Management Block Removed


# Функция для получения названия зоны
def get_zone_name(number: int) -> str:

    adjusted_number = 22 if number == 0 else number
    zone = ZONES.get(adjusted_number, {})
    
    return f"{number} ({zone.get('role_name', '???')})" if zone else str(number)


# Duplicate send_text_format removed



@bot.callback_query_handler(func=lambda call: call.data.startswith('text_format_') or call.data.startswith('show_text_'))
def show_saved_text_format(call):
    try:
        # Normalize prefix: treat 'show_text_' as 'text_format_'
        data = call.data
        if data.startswith('show_text_'):
            data = data.replace('show_text_', 'text_format_')
            
        parts = data.split('_')
        log_id = parts[2]
        viewer_id = call.from_user.id
        owner_id = parts[3] if len(parts) > 3 else viewer_id
        
        # 1. Получаем данные из Firebase
        log_data = fb_get_log(log_id, owner_id)
        if not log_data:
            bot.answer_callback_query(call.id, "❌ Расчет не найден")
            return

        nums = log_data.get('numbers', [])
        # Reconstruct data list: 
        # Original: num1..num14, birth, name, gender
        if not nums:
            bot.answer_callback_query(call.id, "❌ Ошибка данных")
            return

        data = [*nums, log_data.get('birthDate'), log_data.get('name'), log_data.get('gender')]
        
        # Original logic below:
        
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
            types.InlineKeyboardButton("📋 Подробнее (20 кр)", callback_data=f'detailed_desc_{log_id}_{owner_id}'),
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


@bot.callback_query_handler(func=lambda call: call.data == 'new_calculation')
def new_calculation(call):
    start_diagnostic(call)


#____________________
#____________________
def calculate_numbers(date_str, gender):
    try:
        day, month, year = map(int, date_str.split('.'))
    except ValueError:
        # Fallback if separator is different?
        # Maybe iso format YYYY-MM-DD?
        if '-' in date_str:
             parts = date_str.split('-')
             if len(parts[0]) == 4: # YYYY-MM-DD
                 day, month, year = int(parts[2]), int(parts[1]), int(parts[0])
             else:
                 day, month, year = int(parts[0]), int(parts[1]), int(parts[2])
        else:
            return []

    def reduce(num):
        while num > 22:
            num -= 22
        return 0 if num == 22 else num

    num1 = reduce(day)
    num2 = month
    num3 = reduce(sum(int(d) for d in str(year)))
    num4 = reduce(num1 + num2 + num3)
    num6 = reduce(num1 + num2)
    num5 = reduce(22 - num6)
    num7 = reduce(num2 + num3)
    num8 = reduce(22 - num7)
    num9 = reduce(num6 + num7)
    num10 = reduce(abs(num6 - num7) + num9)
    num11 = reduce(num9 + num10)
    num12 = reduce(num4 + (num8 if gender == 'М' else num5) + num11)
    num13 = reduce(num1 + num3 + num10)
    num14 = reduce(num12 + num13)
    
    return [num1, num2, num3, num4, num5, num6, num7, num8, num9, num10, num11, num12, num13, num14]

def calculate_diagnostic(date_str, name, gender, nums=None):
    if nums:
        # Legacy: Return string only when nums provided
        return format_scheme(*nums, name, date_str, gender)
    
    # Логика для нового расчета
    nums = calculate_numbers(date_str, gender)
    if not nums:
        return ("Ошибка формата даты", [])

    return (
        format_scheme(*nums, name, date_str, gender),
        nums
    )

# def format_scheme(num1, num2, num3, num4, num5, num6, num7, num8, num9, num10, num11, num12, num13, num14, name, date_str, gender):
def format_scheme(num1, num2, num3, num4, num5, num6, num7, num8, 
                 num9, num10, num11, num12, num13, num14, 
                 date_str, name, gender):
    header = f"Имя: {name}\nДата: {date_str}\n"
    if gender == 'М':
        return f"""{header}
            {num1} -  {num2} - {num3}  |   {num4}
        {num5} <- {num6}    {num7} -> {num8}
                 {num9}
                  |> {num11}
                 {num10}        {num12}
                  |    {num14}
                  {num13}
        """.strip()
    else:
        return f"""{header}
            {num1} -  {num2} - {num3}  |   {num4}
         {num5} <- {num6}      {num7} -> {num8}
                  {num9}
                  |> {num11}
       {num12}         {num10}   
            {num14}    |    
                 {num13}
        """.strip()

#____________________
@bot.callback_query_handler(func=lambda call: call.data == 'generate_diagnostic_image')
def handle_image_generation(call):
    try:
        user_id = call.from_user.id
        conn = sqlite3.connect(DB_PATH)
        cursor = conn.cursor()
        
        # Получаем последние данные расчета
        cursor.execute('''
            SELECT dl.birth_date, dl.name, dl.gender, dr.num1, dr.num2, dr.num3, dr.num4,
                   dr.num5, dr.num6, dr.num7, dr.num8, dr.num9, dr.num10, dr.num11, dr.num12, dr.num13, dr.num14
            FROM diagnostic_logs dl
            JOIN diagnostic_results dr ON dl.id = dr.log_id
            WHERE dl.user_id = ?
            ORDER BY dr.calculation_date DESC
            LIMIT 1
        ''', (user_id,))
        
        data = cursor.fetchone()
        if not data:
            bot.answer_callback_query(call.id, "❌ Нет данных для генерации изображения")
            return
        
        birth_date, name, gender = data[0], data[1], data[2]
        nums = data[3:17]
        
        # Генерация изображения
        img_bytes = generate_diagnostic_image(
            nums=nums,
            name=name,
            date_str=birth_date,
            gender=gender,
            template_path="D:\BOT\IDPGMD092025.png"
        )
        if img_bytes:
            # Отправляем изображение и сохраняем объект сообщения
            sent_message = bot.send_photo(
                call.message.chat.id,
                photo=img_bytes,
                caption=f"Диагностика для {name}\nРассчитана с помощью бота @id_potential_bot"
            )
            
            # Добавляем кнопку "Закрыть" с message_id
            markup = types.InlineKeyboardMarkup()
            markup.add(
                types.InlineKeyboardButton(
                    "❌ Закрыть", 
                    callback_data=f'delete_image_{sent_message.message_id}'
                )
            )
            # Редактируем сообщение, чтобы добавить клавиатуру
            bot.edit_message_reply_markup(
                chat_id=call.message.chat.id,
                message_id=sent_message.message_id,
                reply_markup=markup
            )
        else:
            bot.answer_callback_query(call.id, "❌ Ошибка генерации изображения")
            
    except Exception as e:
        bot.send_message(call.message.chat.id, f"⛔ Ошибка: {str(e)}")
    finally:
        conn.close()





@bot.callback_query_handler(func=lambda call: call.data.startswith('image_format_'))
def handle_saved_image(call):
    try:
        parts = call.data.split('_')
        log_id = parts[2]
        viewer_id = call.from_user.id
        owner_id = parts[3] if len(parts) > 3 else viewer_id
        
        # 1. Получаем данные из Firebase
        log_data = fb_get_log(log_id, owner_id)
        if not log_data:
            bot.answer_callback_query(call.id, "❌ Данные расчета не найдены")
            return

        nums = log_data.get('numbers', [])
        if not nums:
            bot.answer_callback_query(call.id, "❌ Ошибка данных")
            return

        birth_date = log_data.get('birthDate')
        name = log_data.get('name')
        gender = log_data.get('gender')

        # Генерация изображения
        img_bytes = generate_diagnostic_image(
            nums=nums,
            name=name,
            date_str=birth_date,
            gender=gender,
            template_path="D:\BOT\IDPGMD092025.png"
        )
        if img_bytes:
            # Отправляем изображение и сохраняем объект сообщения
            sent_message = bot.send_photo(
                call.message.chat.id,
                photo=img_bytes,
                caption=f"Диагностика для {name}\nРассчитана с помощью бота @id_potential_bot"
            )
            
            # Добавляем кнопку "Закрыть" с message_id
            markup = types.InlineKeyboardMarkup()
            markup.add(
                types.InlineKeyboardButton(
                    "❌ Закрыть", 
                    callback_data=f'delete_image_{sent_message.message_id}'
                )
            )
            
            # Редактируем сообщение, чтобы добавить клавиатуру
            bot.edit_message_reply_markup(
                chat_id=call.message.chat.id,
                message_id=sent_message.message_id,
                reply_markup=markup
            )
        else:
            bot.answer_callback_query(call.id, "❌ Ошибка генерации изображения")

    except Exception as e:
        bot.send_message(call.message.chat.id, f"⛔ Ошибка: {str(e)}")
        
@bot.callback_query_handler(func=lambda call: call.data.startswith('delete_image_'))
def delete_image(call):
    try:
        # Извлекаем ID сообщения из callback_data
        message_id = int(call.data.split('_')[2])
        
        # Удаляем сообщение с изображением
        bot.delete_message(
            chat_id=call.message.chat.id,
            message_id=message_id
        )
        
        # Уведомляем пользователя
        bot.answer_callback_query(call.id, "Изображение закрыто ✅")

    except Exception as e:
        bot.answer_callback_query(call.id, f"Ошибка: {str(e)}")

#______________________





#_________________
def generate_diagnostic_image(nums, name, date_str, gender, template_path="D:\BOT\IDPGMD092025.png"):
    """Генерирует изображение схемы с учетом пола"""
    try:
        # Загрузка шаблона
        img = Image.open(template_path)
        draw = ImageDraw.Draw(img)
        
        # Настройки шрифта
        try:
            font_path = os.path.join("fonts", "DINPro-Bold.otf")
            font = ImageFont.truetype(font_path, 50)
            caption_font = ImageFont.truetype(font_path, 45)
        except Exception as e:
            font = ImageFont.load_default()
            caption_font = ImageFont.load_default()
            caption_font.size = 45
        # Координаты для М и Ж (настройте под ваш шаблон!)

        positions = {
            'М': {
                'num1': (335, 220), 
                'num2': (538, 220),
                'num3': (740, 220),
                'num4': (975, 220),
                'num5': (230, 375),
                'num6': (435, 375),
                'num7': (637, 375),
                'num8': (840, 375),
                'num9': (538, 505),
                'num10': (538, 680),
                'num11': (680, 590),
                'num12': (970, 540),
                'num13': (539, 855),
                'num14': (800, 732),
                'dash1': (100, 540),   
                'dash2': (275, 732) 
            },
            'Ж': {
                'num1': (335, 220), 
                'num2': (538, 220),
                'num3': (740, 220),
                'num4': (975, 220),
                'num5': (230, 375),
                'num6': (435, 375),
                'num7': (637, 375),
                'num8': (840, 375),
                'num9': (538, 505),
                'num10': (538, 680),
                'num11': (680, 590),
                'num12': (100, 540),
                'num13': (539, 855),
                'num14': (275, 732),
                'dash1': (970, 540), 
                'dash2': (800, 732)
            }
        }

        # Выбираем координаты по полу
        gender_positions = positions.get(gender, positions['М'])  # По умолчанию мужские

        # Нанесение чисел на изображение

        for i, num in enumerate(nums, 1):
            key = f'num{i}'
            x, y = gender_positions[key]
            draw.text(
                (x, y), 
                str(num), 
                fill="black", 
                font=font,
                anchor="mm"
            )
        dash_positions = ['dash1', 'dash2']
        for dash_key in dash_positions:
            x, y = gender_positions[dash_key]
            draw.text(
                (x, y), 
                "--", 
                fill="black", 
                font=font,
                anchor="mm"
            )
        # Координаты для левого края (x=50, y=900)
        text_x = 50
        text_y = 50

        # Рисуем текст с выравниванием по левому краю (anchor="lt" - left-top)
        draw.text(
            (text_x, text_y),
            f"{name} ({date_str})",
            fill="white",
            font=caption_font,
            anchor="lt"  # Выравнивание по левому верхнему углу
        )
        
        # Конвертация в bytes
        img_byte_arr = io.BytesIO()
        img.save(img_byte_arr, format='PNG')
        img_byte_arr.seek(0)
        
        return img_byte_arr

    except Exception as e:
        print(f"Ошибка генерации изображения: {e}")
        return None




# Обработчик подкорковых зон
@bot.callback_query_handler(func=lambda call: call.data == 'podkorkovye_zony')
def podkorkovye_zony_handler(call):
    text = "🧠 Роль подсознания\nВыберите интересующий вас номер:"
    markup = types.InlineKeyboardMarkup(row_width=5)
    
    # Создаем кнопки от 1 до 21
    buttons = [types.InlineKeyboardButton(str(i), callback_data=f'video_{i}') for i in range(1, 22)]
    
    # Добавляем специальную кнопку для 22 (0)
    buttons.append(types.InlineKeyboardButton("22 (0)", callback_data='video_0'))
    
    # Добавляем кнопку "Назад"
    back_btn = types.InlineKeyboardButton("❌ Закрыть", callback_data='delete_history_msg')
    
    # Разбиваем на ряды по 5 кнопок
    for i in range(0, len(buttons), 5):
        markup.row(*buttons[i:i+5])
    
    markup.add(back_btn)
    
    bot.edit_message_text(
        chat_id=call.message.chat.id,
        message_id=call.message.message_id,
        text=text,
        reply_markup=markup
    )

@bot.callback_query_handler(func=lambda call: call.data.startswith('video_'))
def send_pgmd_video(call):
    try:
        video_num = int(call.data.split('_')[1])
        display_num = video_num if video_num != 0 else 22

        zone_data = ZONES.get(display_num, {})
        if not zone_data:
            bot.answer_callback_query(call.id, "Описание зоны не найдено!")
            return

        # Новый формат вывода
        caption = (
            f"**Роль подсознания {display_num}: {zone_data.get('role_name', 'Название')}**\n\n"
            f"**🧠 Ключевое качество:**\n"
            f"{zone_data.get('role_key', 'Описание отсутствует')}\n\n"
            f"**💪 Сильная сторона:**\n"
            f"{zone_data.get('role_strength', 'Описание отсутствует')}\n\n"
            f"**⚡ Вызов (опасность):**\n"
            f"{zone_data.get('role_challenge', 'Описание отсутствует')}\n\n"
            f"**🌍 Проявление в жизни:**\n"
            f"{zone_data.get('role_inlife', 'Описание отсутствует')}\n\n"
            f"**💥 Эмоциональный посыл:**\n"
            f"{zone_data.get('emotion', 'Описание отсутствует')}\n\n"
            f"**🎭 Как выглядит:**\n"
            f"{zone_data.get('manifestation', 'Описание отсутствует')}\n\n"
            f"**❓ Вопрос для рефлексии:**\n"
            f"*{zone_data.get('role_question', 'Вопрос отсутствует')}*"
        )

        video_file_id = VIDEOS.get(video_num)
        if not video_file_id:
            bot.answer_callback_query(call.id, "Видео не найдено!")
            return

        sent_msg = bot.send_video(
            chat_id=call.message.chat.id,
            video=video_file_id,
            caption=caption,
            parse_mode="Markdown"
        )

        markup = types.InlineKeyboardMarkup()
        markup.add(types.InlineKeyboardButton("Просмотрено ✅", callback_data=f'delete_{sent_msg.message_id}'))
        
        bot.edit_message_reply_markup(
            chat_id=call.message.chat.id,
            message_id=sent_msg.message_id,
            reply_markup=markup
        )
        
    except Exception as e:
        bot.send_message(call.message.chat.id, f"Ошибка: {e}")

# Обработчик для кнопки удаления
@bot.callback_query_handler(func=lambda call: call.data.startswith('delete_'))
def delete_video_handler(call):
    try:
        message_id = call.data.split('_')[1]
        bot.delete_message(
            chat_id=call.message.chat.id,
            message_id=message_id
        )
        bot.answer_callback_query(call.id, "Видео удалено ✅")
    except Exception as e:
        bot.answer_callback_query(call.id, f"Ошибка удаления: {e}")

# Новый обработчик для кнопки Назад
@bot.callback_query_handler(func=lambda call: call.data == 'back_to_main')
def back_handler(call):
    # Удаляем инлайн-меню
    bot.delete_message(
        chat_id=call.message.chat.id,
        message_id=call.message.message_id
    )
    
    # Отправляем обновленное текстовое меню
    markup = types.ReplyKeyboardMarkup(resize_keyboard=True)
    # markup.row('🌐 Сайт', '📅 Обучение')
    # markup.row('🏢 Кабинет', '📢 Новости')
    markup.row(types.KeyboardButton('🧠 Диагностика'), types.KeyboardButton('🏢 Мой кабинет'))
  
    bot.send_message(
        call.message.chat.id,
        "Главное меню:",
        reply_markup=markup
    )

# Обновленный обработчик для кнопки "Назад" в личном кабинете
@bot.message_handler(func=lambda message: message.text == '⬅️ Назад')
def back_to_main_menu(message):
    markup = types.ReplyKeyboardMarkup(resize_keyboard=True)
    # markup.row('🌐 Сайт', '📅 Обучение')
    # markup.row('🏢 Кабинет', '📢 Новости')
    markup.row(types.KeyboardButton('🧠 Диагностика'), types.KeyboardButton('🏢 Мой кабинет'))
    bot.send_message(message.chat.id, 'Главное меню:', reply_markup=markup)

# личный кабинет


def create_personal_account_markup():
    """Создает Reply-клавиатуру для меню личного кабинета"""
    markup = types.ReplyKeyboardMarkup(resize_keyboard=True, row_width=2)
    buttons = [
        types.KeyboardButton('📝 Моя история'),
        types.KeyboardButton('📰 Моя визитка'), 
        types.KeyboardButton('🏢 Мой кабинет'),
        types.KeyboardButton('⬅️ Назад')
    ]
    markup.add(*buttons)
    return markup

def db_table_val(user_id, user_name, user_surname, username, markup, message):
    try:
        fb_register_user(user_id, user_name, user_surname, username)
    except Exception as e:
        print(f"Ошибка в db_table_val (Firebase): {e}")

@bot.message_handler(func=lambda message: message.text == '🏢 Мой кабинет')
def handle_balance(message):
    user_id = message.from_user.id
    
    try:
        user_data = fb_get_user(user_id)

        if user_data:
            name = user_data.get('first_name') or "Пользователь"
            bill = user_data.get('credits', 0)
            pgmd_level = user_data.get('pgmd', 1)
            
            level_names = {
                1: "Гость",
                2: "Исследователь", 
                3: "Опытный", 
                5: "Диагност", 
                100: "Администратор"
            }
            
            level_name = level_names.get(pgmd_level, f"Уровень {pgmd_level}")
            
            response = (f"{name}\n"
                       f"💳 Баланс: {bill} кредитов (Cloud)\n"
                       f"🎯 Уровень доступа: {level_name}")
            
            # Добавляем информацию о стоимости услуг
            if pgmd_level < 2:
                response += "\n\n💡 Для доступа к расшифровке необходим уровень 'Исследователь'"
                
            # Создаем инлайн-кнопки
            markup = types.InlineKeyboardMarkup(row_width=1)
            
            # Добавляем кнопку Расшифровка
            markup.add(types.InlineKeyboardButton(
                "📖 Расшифровка", 
                callback_data="decryption_info"
            ))
            
            # Кнопка Login App
            markup.add(types.InlineKeyboardButton(
                "📱 Вход в Приложение", 
                callback_data="login_app_btn"
            ))
            
            # ДОБАВЛЕНО: Кнопка админ-панели для администратора
            if pgmd_level == 100:
                markup.add(types.InlineKeyboardButton(
                    "🛠 Админ-панель", 
                    callback_data="admin_broadcast"
                ))
            
            if pgmd_level < 2:
                markup.add(types.InlineKeyboardButton(
                    "📈 Повысить уровень", 
                    callback_data=f"request_upgrade_{user_id}"
                ))
            if bill < 5000:
                markup.add(types.InlineKeyboardButton(
                    "📨 Пополнить баланс", 
                    callback_data=f"request_credits_{user_id}"
                ))
            markup.add(types.InlineKeyboardButton(
                "💬 Задать вопрос", 
                callback_data=f"ask_question_{user_id}"
            ))
            # Добавляем кнопку "Закрыть"
            markup.add(types.InlineKeyboardButton(
                "❌ Закрыть", 
                callback_data="delete_history_msg"
            ))

            bot.send_message(message.chat.id, response, reply_markup=markup)
        else:
            bot.send_message(message.chat.id, "🔐 Пользователь не найден. Нажмите /start")

    except Exception as e:
        print(f"Error handle_balance: {e}")
        bot.send_message(message.chat.id, f"⛔ Ошибка: {str(e)}")

@bot.callback_query_handler(func=lambda call: call.data == 'login_app_btn')
def callback_login_app(call):
    token = fb_create_custom_token(call.from_user.id)
    if token:
        bot.send_message(
            call.message.chat.id, 
            f"🔑 *Ваш ключ для входа:* `{token}`", 
            parse_mode="Markdown"
        )
    else:
        bot.answer_callback_query(call.id, "Error generating token")

@bot.callback_query_handler(func=lambda call: call.data.startswith('ask_question_'))
def handle_ask_question(call):
    try:
        user_id = int(call.data.split('_')[2])
        
        # Отправляем сообщение с запросом текста вопроса
        msg = bot.send_message(
            call.message.chat.id,
            "✍️ Пожалуйста, напишите ваш вопрос:",
            reply_markup=types.ForceReply()
        )
        
        # Используем замыкание для передачи user_id
        bot.register_next_step_handler(msg, lambda message: process_question_text(message, user_id))
        
        bot.answer_callback_query(call.id, "Введите ваш вопрос")
        
    except Exception as e:
        print(f"Error in handle_ask_question: {e}")

def process_question_text(message, user_id):
    try:
        question_text = message.text
        
        # Сохраняем вопрос в базу данных
        conn = sqlite3.connect(DB_PATH)
        cursor = conn.cursor()
        
        cursor.execute('''
            INSERT INTO requests (user_id, request_type, request_text)
            VALUES (?, ?, ?)
        ''', (user_id, 'question', question_text))
        
        conn.commit()
        conn.close()
        
        # Уведомляем пользователя
        bot.send_message(
            message.chat.id,
            "✅ Ваш вопрос отправлен администратору. Ответ придет в течение 24 часов."
        )
        
        # Уведомляем администратора
        admin_msg = (f"❓ Новый вопрос от пользователя\n"
                    f"ID: {user_id}\n"
                    f"Username: @{message.from_user.username}\n"
                    f"Текст вопроса:\n{question_text}")
        
        markup = types.InlineKeyboardMarkup()
        markup.add(types.InlineKeyboardButton(
            "✏️ Ответить на вопрос", 
            callback_data=f"answer_question_{user_id}"
        ))
        
        bot.send_message(ADMIN_ID, admin_msg, reply_markup=markup)
        
    except Exception as e:
        bot.send_message(message.chat.id, "❌ Произошла ошибка при отправке вопроса")
        print(f"Error in process_question_text: {e}")

@bot.callback_query_handler(func=lambda call: call.data.startswith('answer_question_'))
def handle_answer_question(call):
    try:
        user_id = int(call.data.split('_')[2])
        
        # Запрашиваем текст ответа у администратора
        msg = bot.send_message(
            call.message.chat.id,
            "✍️ Введите текст ответа для пользователя:",
            reply_markup=types.ForceReply()
        )
        
        # Используем замыкание для передачи user_id
        bot.register_next_step_handler(msg, lambda message: process_answer_text(message, user_id))
        
        bot.answer_callback_query(call.id, "Введите ответ")
        
    except Exception as e:
        bot.answer_callback_query(call.id, "❌ Ошибка при обработке запроса")
        print(f"Error in handle_answer_question: {e}")

def process_answer_text(message, user_id):
    try:
        answer_text = message.text
        
        # Обновляем запись в базе данных
        conn = sqlite3.connect(DB_PATH)
        cursor = conn.cursor()
        
        # Сначала находим ID последнего неотвеченного вопроса
        cursor.execute('''
            SELECT id FROM requests 
            WHERE user_id = ? AND request_type = 'question' AND is_answered = 0
            ORDER BY request_date DESC 
            LIMIT 1
        ''', (user_id,))
        
        result = cursor.fetchone()
        if not result:
            bot.send_message(message.chat.id, "❌ Не найден неотвеченный вопрос")
            conn.close()
            return
            
        request_id = result[0]
        
        # Затем обновляем найденную запись
        cursor.execute('''
            UPDATE requests 
            SET is_answered = 1, answer_text = ?, answer_date = CURRENT_TIMESTAMP
            WHERE id = ?
        ''', (answer_text, request_id))
        
        conn.commit()
        conn.close()
        
        # Отправляем ответ пользователю
        bot.send_message(
            user_id,
            f"📩 Ответ от администратора:\n\n{answer_text}"
        )
        
        # Уведомляем администратора
        bot.send_message(
            message.chat.id,
            "✅ Ответ успешно отправлен пользователю."
        )
        
    except Exception as e:
        bot.send_message(message.chat.id, "❌ Произошла ошибка при отправке ответа")
        print(f"Error in process_answer_text: {e}")


@bot.message_handler(content_types=['video'])
def handle_video(message):
    # Получаем file_id видео
    video_id = message.video.file_id
    
    # Отправляем пользователю file_id
    bot.reply_to(
        message, 
        f"File ID этого видео: `{video_id}`\n\n"
        "Скопируйте его и вставьте в константу VIDEO_FILE_ID.", 
        parse_mode="Markdown"
    )

@bot.callback_query_handler(func=lambda call: call.data.startswith('request_upgrade_'))
def handle_upgrade_request(call):
    try:
        user_id = call.data.split('_')[2]
        
        # Логируем запрос в базу
        conn = sqlite3.connect(DB_PATH)
        cursor = conn.cursor()
        
        cursor.execute('''
            INSERT INTO requests (user_id, request_type)
            VALUES (?, ?)
        ''', (user_id, 'upgrade'))
        
        conn.commit()
        conn.close()
        
        # Создаем клавиатуру с кнопкой для админа
        markup = types.InlineKeyboardMarkup()
        markup.add(types.InlineKeyboardButton(
            "✅ Повысить уровень", 
            callback_data=f"approve_upgrade_{user_id}"
        ))
        
        admin_text = (f"📈 Заявка на повышение уровня\n"
                     f"User ID: {user_id}\n"
                     f"Username: @{call.from_user.username}\n"
                     f"Имя: {call.from_user.first_name}")
        
        bot.send_message(ADMIN_ID, admin_text, reply_markup=markup)
        
        bot.answer_callback_query(
            call.id, 
            "✅ Заявка отправлена администратору. Ожидайте решения.",
            show_alert=True
        )
        
    except Exception as e:
        bot.answer_callback_query(call.id, "❌ Ошибка при отправке заявки")

@bot.callback_query_handler(func=lambda call: call.data.startswith('detailed_desc_'))
def handle_detailed_desc(call):
    try:
        parts = call.data.split('_')
        log_id = parts[2] # Firebase ID string
        
        viewer_id = call.from_user.id
        # Attempt to parse owner_id from callback, fallback to viewer_id for backward compatibility
        owner_id = parts[3] if len(parts) > 3 else viewer_id
        
        # 1. Получаем данные расчета из Firebase (используем ID владельца лога)
        log_data = fb_get_log(log_id, owner_id)
        
        if not log_data:
            bot.answer_callback_query(call.id, "❌ Данные расчета не найдены")
            return

        # 2. Проверка прав и оплаты (проверяем права СМОТРЯЩЕГО)
        pgmd_level = 1
        balance = 0
        viewer_data = fb_get_user(viewer_id)
        if viewer_data:
            pgmd_level = viewer_data.get('pgmd', 1)
            balance = viewer_data.get('credits', 0)

        already_paid = log_data.get('decryption', 0) == 1
        
        if not already_paid:
            # Проверка уровня
            if pgmd_level < 2:
                markup = types.InlineKeyboardMarkup()
                markup.add(types.InlineKeyboardButton("📈 Повысить уровень", callback_data=f"request_upgrade_{viewer_id}")) # Use viewer_id
                bot.send_message(call.message.chat.id, f"❌ Нужен уровень 'Исследователь' (2). Ваш: {pgmd_level}.", reply_markup=markup)
                return

            if pgmd_level != 100 and balance < 20:
                markup = types.InlineKeyboardMarkup()
                markup.add(types.InlineKeyboardButton("📨 Отправить заявку", callback_data=f"request_credits_{viewer_id}"))
                bot.send_message(call.message.chat.id, f"❌ Недостаточно кредитов (нужно 20, у вас {balance}).", reply_markup=markup)
                return

            # Списание (со счета СМОТРЯЩЕГО)
            if pgmd_level != 100:
                if not fb_deduct_credits(viewer_id, 20):
                     bot.send_message(call.message.chat.id, "❌ Ошибка транзакции. Попробуйте снова.")
                     return
            
            # Помечаем лог как оплаченный (в базе ВЛАДЕЛЬЦА)
            fb_mark_log_paid(owner_id, log_id)

        # 3. Генерация текста
        nums = log_data.get('numbers', [])
        if not nums:
            bot.send_message(call.message.chat.id, "❌ Ошибка данных в расчете")
            return
            
        data_tuple = (*nums, log_data.get('birthDate'), log_data.get('name'), log_data.get('gender'))
        
        detailed_text = generate_detailed_description(data_tuple)
        
        markup = types.InlineKeyboardMarkup()
        markup.add(types.InlineKeyboardButton("❌ Закрыть", callback_data='delete_history_msg'))
        
        bot.send_message(call.message.chat.id, detailed_text, parse_mode="Markdown", reply_markup=markup)
        
        if not already_paid and pgmd_level != 100:
            bot.send_message(call.message.chat.id, f"С вашего счета списано 20 кредитов.")

    except Exception as e:
        print(f"Error detailed_desc: {e}")
        bot.send_message(call.message.chat.id, f"⛔ Ошибка: {str(e)}")

# Duplicate format_decryption_text removed

# Функция для показа меню пополнения баланса с условиями
# Duplicate show_deposit_menu removed

# Обработчик для кнопки "Пополнить баланс" - теперь показывает меню с условиями
@bot.callback_query_handler(func=lambda call: call.data.startswith('request_credits_'))
def handle_credit_request(call):
    """Обработчик для кнопки пополнения баланса"""
    try:
        user_id = call.data.split('_')[2]
        
        # Сохраняем user_id в глобальном словаре для этого конкретного меню
        key = f"{call.message.chat.id}_{call.message.message_id}"
        deposit_requests[key] = user_id
        
        # Показываем меню с условиями пополнения
        show_deposit_menu(call, user_id)
        
    except Exception as e:
        bot.answer_callback_query(call.id, "❌ Ошибка при открытии меню пополнения")
        print(f"Error in handle_credit_request: {e}")
# Обновленная функция show_deposit_menu с передачей user_id
def show_deposit_menu(call, user_id):
    """Показать меню пополнения баланса с условиями и кнопками"""
    deposit_text = (
        "<b>💰 Условия пополнения баланса:</b>\n\n"
        "<b>💎 Варианты пополнения:</b>\n"
        "• Подписка 3000₽ в месяц - 500 кредитов (6₽/кр.)\n"
        "• Разовая покупка по 10₽/кредит\n"
        "  - 500₽ → 50 кредитов\n"
        "  - 1000₽ → 100 кредитов\n\n"
        "<b>🎁 Бонусы:</b>\n"
        "Запросите бонусы за игру \"Территория себя\"\n\n"
        "<b>💳 Стоимость услуг:</b>\n"
        "• Один расчет: 5 кредитов\n"
        "• Подробная текстовая версия: 20 кредитов\n\n"
        "📚 Также у нас большой выбор расшифровок индивидуальных диагностик и совместимостей\n"
        "Подробнее: https://t.me/id_territory/37"
    )
    
    markup = types.InlineKeyboardMarkup(row_width=1)
    
    markup.add(
        types.InlineKeyboardButton("🎁 Запросить бонус", callback_data=f'request_bonus_{user_id}'),
        types.InlineKeyboardButton("💎 Заявка на подписку", callback_data=f'request_subscription_{user_id}'),
        types.InlineKeyboardButton("💳 Разовое пополнение 500₽", callback_data=f'request_deposit_500_{user_id}'),
        types.InlineKeyboardButton("💳 Разовое пополнение 1000₽", callback_data=f'request_deposit_1000_{user_id}'),
        types.InlineKeyboardButton("⬅️ Назад", callback_data=f'back_to_balance_{user_id}'),
        types.InlineKeyboardButton("❌ Закрыть", callback_data='delete_history_msg')
    )
    
    # Используем HTML вместо Markdown
    bot.edit_message_text(
        chat_id=call.message.chat.id,
        message_id=call.message.message_id,
        text=deposit_text,
        parse_mode="HTML",
        reply_markup=markup,
        disable_web_page_preview=True
    )

# Обновленный обработчик для кнопки "Назад"
@bot.callback_query_handler(func=lambda call: call.data.startswith('back_to_balance_'))
def back_to_balance(call):
    """Возврат к меню баланса"""
    try:
        user_id = call.data.split('_')[3]
        
        # Получаем данные пользователя
        user_data = fb_get_user(user_id)

        if user_data:
            name = user_data.get('first_name') or "Пользователь"
            bill = user_data.get('credits', 0)
            pgmd_level = user_data.get('pgmd', 1)
            
            level_names = {
                1: "Гость",
                2: "Исследователь", 
                3: "Опытный", 
                5: "Диагност", 
                100: "Администратор"
            }
            
            level_name = level_names.get(pgmd_level, f"Уровень {pgmd_level}")
            
            response = (f"{name}\n"
                       f"💳 Баланс: {bill} кредитов (Cloud)\n"
                       f"🎯 Уровень доступа: {level_name}")
                       
            if pgmd_level < 2:
                response += "\n\n💡 Для доступа к расшифровке необходим уровень 'Исследователь'"
                
            markup = types.InlineKeyboardMarkup(row_width=1)
            markup.add(types.InlineKeyboardButton(
                "📖 Расшифровка", 
                callback_data="decryption_info"
            ))
            
            markup.add(types.InlineKeyboardButton(
                "📱 Вход в Приложение", 
                callback_data="login_app_btn"
            ))
            
            if pgmd_level < 2:
                markup.add(types.InlineKeyboardButton(
                    "📈 Повысить уровень", 
                    callback_data=f"request_upgrade_{user_id}"
                ))
            if bill < 5000:
                markup.add(types.InlineKeyboardButton(
                    "💰 Пополнить баланс", 
                    callback_data=f"request_credits_{user_id}"
                ))
            markup.add(types.InlineKeyboardButton(
                "💬 Задать вопрос", 
                callback_data=f"ask_question_{user_id}"
            ))
            markup.add(types.InlineKeyboardButton(
                "❌ Закрыть", 
                callback_data="delete_history_msg"
            ))

            bot.edit_message_text(
                chat_id=call.message.chat.id,
                message_id=call.message.message_id,
                text=response,
                reply_markup=markup
            )
        
        
    except Exception as e:
        print(f"Error back_to_balance: {e}")
        bot.answer_callback_query(call.id, "❌ Ошибка")
# Обработчик для кнопки "Запросить бонус"
@bot.callback_query_handler(func=lambda call: call.data.startswith('request_bonus_'))
def handle_bonus_request(call):
    """Обработчик запроса бонусов за игру"""
    try:
        user_id = call.data.split('_')[2]
        
        # Логируем запрос в базу
        conn = sqlite3.connect(DB_PATH)
        cursor = conn.cursor()
        
        cursor.execute('''
            INSERT INTO requests (user_id, request_type, request_text)
            VALUES (?, ?, ?)
        ''', (user_id, 'bonus', 'Запрос бонусов за игру "Территория себя"'))
        
        conn.commit()
        conn.close()
        
        # Создаем клавиатуру с кнопкой для админа
        markup = types.InlineKeyboardMarkup()
        markup.add(types.InlineKeyboardButton(
            "🎁 Обработать запрос бонусов", 
            callback_data=f"process_deposit_{user_id}"
            # callback_data=f"process_bonus_{user_id}"
        ))
        
        admin_text = (f"🎁 Запрос на получение бонусов\n"
                     f"User ID: {user_id}\n"
                     f"Username: @{call.from_user.username}\n"
                     f"Имя: {call.from_user.first_name}\n"
                     f"Тип: Бонусы за игру \"Территория себя\"")
        
        bot.send_message(ADMIN_ID, admin_text, reply_markup=markup)
        
        bot.answer_callback_query(
            call.id, 
            "✅ Запрос на бонусы отправлен администратору. Ожидайте решения.",
            show_alert=True
        )
        
    except Exception as e:
        bot.answer_callback_query(call.id, "❌ Ошибка при отправке запроса")
        print(f"Error in handle_bonus_request: {e}")

# Обработчик для кнопки "Заявка на подписку"
@bot.callback_query_handler(func=lambda call: call.data.startswith('request_subscription_'))
def handle_subscription_request(call):
    """Обработчик заявки на подписку"""
    try:
        user_id = call.data.split('_')[2]
        
        # Логируем запрос в базу
        conn = sqlite3.connect(DB_PATH)
        cursor = conn.cursor()
        
        cursor.execute('''
            INSERT INTO requests (user_id, request_type, request_text)
            VALUES (?, ?, ?)
        ''', (user_id, 'subscription', 'Заявка на подписку 3000₽/месяц (500 кредитов)'))
        
        conn.commit()
        conn.close()
        
        # Создаем клавиатуру с кнопкой для админа
        markup = types.InlineKeyboardMarkup()
        markup.add(types.InlineKeyboardButton(
            "💎 Оформить подписку", 
            callback_data=f"process_subscription_{user_id}"
        ))
        
        admin_text = (f"💎 Заявка на оформление подписки\n"
                     f"User ID: {user_id}\n"
                     f"Username: @{call.from_user.username}\n"
                     f"Имя: {call.from_user.first_name}\n"
                     f"Тип подписки: 3000₽ в месяц (500 кредитов)")
        
        bot.send_message(ADMIN_ID, admin_text, reply_markup=markup)
        
        bot.answer_callback_query(
            call.id, 
            "✅ Заявка на подписку отправлена администратору. С вами свяжутся для оформления.",
            show_alert=True
        )
        
    except Exception as e:
        bot.answer_callback_query(call.id, "❌ Ошибка при отправке заявки")
        print(f"Error in handle_subscription_request: {e}")

# Обработчик для кнопки "Разовое пополнение 500₽"
@bot.callback_query_handler(func=lambda call: call.data.startswith('request_deposit_500_'))
def handle_deposit_500_request(call):
    """Обработчик заявки на разовое пополнение 500₽"""
    try:
        user_id = call.data.split('_')[3]  # Извлекаем user_id из формата request_deposit_500_{user_id}
        
        # Логируем запрос в базу
        conn = sqlite3.connect(DB_PATH)
        cursor = conn.cursor()
        
        cursor.execute('''
            INSERT INTO requests (user_id, request_type, request_text)
            VALUES (?, ?, ?)
        ''', (user_id, 'deposit', 'Заявка на разовое пополнение 500₽ (50 кредитов)'))
        
        conn.commit()
        conn.close()
        
        # Создаем клавиатуру с кнопкой для админа
        markup = types.InlineKeyboardMarkup()
        markup.add(types.InlineKeyboardButton(
            "💳 Пополнить 500₽", 
            callback_data=f"process_deposit_{user_id}_500"
        ))
        
        admin_text = (f"💳 Заявка на разовое пополнение\n"
                     f"User ID: {user_id}\n"
                     f"Username: @{call.from_user.username}\n"
                     f"Имя: {call.from_user.first_name}\n"
                     f"Сумма: 500₽ (50 кредитов)")
        
        bot.send_message(ADMIN_ID, admin_text, reply_markup=markup)
        
        bot.answer_callback_query(
            call.id, 
            "✅ Заявка на пополнение 500₽ отправлена администратору. С вами свяжутся для оплаты.",
            show_alert=True
        )
        
    except Exception as e:
        bot.answer_callback_query(call.id, "❌ Ошибка при отправке заявки")
        print(f"Error in handle_deposit_500_request: {e}")

# Обработчик для кнопки "Разовое пополнение 1000₽"
@bot.callback_query_handler(func=lambda call: call.data.startswith('request_deposit_1000_'))
def handle_deposit_1000_request(call):
    """Обработчик заявки на разовое пополнение 1000₽"""
    try:
        user_id = call.data.split('_')[3]  # Извлекаем user_id из формата request_deposit_1000_{user_id}
        
        # Логируем запрос в базу
        conn = sqlite3.connect(DB_PATH)
        cursor = conn.cursor()
        
        cursor.execute('''
            INSERT INTO requests (user_id, request_type, request_text)
            VALUES (?, ?, ?)
        ''', (user_id, 'deposit', 'Заявка на разовое пополнение 1000₽ (100 кредитов)'))
        
        conn.commit()
        conn.close()
        
        # Создаем клавиатуру с кнопкой для админа
        markup = types.InlineKeyboardMarkup()
        markup.add(types.InlineKeyboardButton(
            "💳 Пополнить 1000₽", 
            callback_data=f"process_deposit_{user_id}_1000"
        ))
        
        admin_text = (f"💳 Заявка на разовое пополнение\n"
                     f"User ID: {user_id}\n"
                     f"Username: @{call.from_user.username}\n"
                     f"Имя: {call.from_user.first_name}\n"
                     f"Сумма: 1000₽ (100 кредитов)")
        
        bot.send_message(ADMIN_ID, admin_text, reply_markup=markup)
        
        bot.answer_callback_query(
            call.id, 
            "✅ Заявка на пополнение 1000₽ отправлена администратору. С вами свяжутся для оплаты.",
            show_alert=True
        )
        
    except Exception as e:
        bot.answer_callback_query(call.id, "❌ Ошибка при отправке заявки")
        print(f"Error in handle_deposit_1000_request: {e}")
                
@bot.callback_query_handler(func=lambda call: call.data.startswith('approve_upgrade_'))
def handle_approve_upgrade(call):
    try:
        user_id = call.data.split('_')[2]
        
        # Обновляем уровень и баланс пользователя (Firebase)
        from firebase_adapter import fb_update_user, fb_add_credits
        
        # 1. Повышаем уровень
        fb_update_user(user_id, {'pgmd': 2})
        
        # 2. Начисляем 20 кредитов
        fb_add_credits(user_id, 20)
        
        # Legacy SQLite Update (чтобы не ломать совместимость, если она нужна)
        try:
            conn = sqlite3.connect(DB_PATH)
            cursor = conn.cursor()
            cursor.execute('UPDATE Partn SET pgmd = 2, bill = bill + 20 WHERE user_id = ?', (user_id,))
            conn.commit()
            conn.close()
        except:
            pass
        
        # Уведомляем пользователя
        bot.send_message(
            user_id,
            "🎉 Ваш уровень повышен до 'Исследователь'!\n"
            "💰 Вам начислено 20 кредитов для старта."
        )
        
        # Уведомляем администратора
        bot.answer_callback_query(
            call.id,
            "✅ Уровень пользователя повышен и начислены кредиты (Firebase compatible)",
            show_alert=True
        )
        
        # Удаляем кнопку из сообщения
        bot.edit_message_reply_markup(
            chat_id=call.message.chat.id,
            message_id=call.message.message_id,
            reply_markup=None
        )
        
    except Exception as e:
        bot.answer_callback_query(call.id, "❌ Ошибка при обработке запроса")
        print(f"Error in handle_approve_upgrade: {e}")

@bot.callback_query_handler(func=lambda call: call.data.startswith('process_subscription_'))
def handle_process_subscription(call):
    """Обработчик для администратора - оформление подписки"""
    try:
        user_id = call.data.split('_')[2]
        
        # Обновляем баланс пользователя (начисляем 500 кредитов за подписку) - Firebase
        from firebase_adapter import fb_add_credits
        fb_add_credits(user_id, 500)
        
        # Legacy SQLite
        try:
            conn = sqlite3.connect(DB_PATH)
            cursor = conn.cursor()
            cursor.execute('UPDATE Partn SET bill = bill + 500 WHERE user_id = ?', (user_id,))
            conn.commit()
            conn.close()
        except: pass
        
        # Уведомляем пользователя
        bot.send_message(
            user_id,
            "💎 Ваша подписка оформлена!\n"
            "💰 Вам начислено 500 кредитов на месяц.\n"
            "💳 Текущий баланс: 500 кредитов.\n\n"
            "📅 Подписка активна до конца текущего месяца."
        )
        
        # Уведомляем администратора
        bot.answer_callback_query(
            call.id,
            "✅ Подписка оформлена, пользователю начислено 500 кредитов (FB)",
            show_alert=True
        )
        
        # Обновляем запрос в базе данных
        conn = sqlite3.connect(DB_PATH)
        cursor = conn.cursor()
        cursor.execute('''
            UPDATE requests 
            SET is_answered = 1, answer_text = ?, answer_date = CURRENT_TIMESTAMP
            WHERE user_id = ? AND request_type = 'subscription' AND is_answered = 0
            ORDER BY request_date DESC LIMIT 1
        ''', ("Подписка оформлена, начислено 500 кредитов", user_id))
        conn.commit()
        conn.close()
        
        # Удаляем кнопку из сообщения
        bot.edit_message_reply_markup(
            chat_id=call.message.chat.id,
            message_id=call.message.message_id,
            reply_markup=None
        )
        
        # Отправляем подтверждение администратору
        bot.send_message(
            call.message.chat.id,
            f"✅ Подписка для пользователя {user_id} успешно оформлена."
        )
        
    except Exception as e:
        bot.answer_callback_query(call.id, "❌ Ошибка при оформлении подписки")
        print(f"Error in handle_process_subscription: {e}")

# Обновленный обработчик для пополнения баланса (для разовых пополнений)
@bot.callback_query_handler(func=lambda call: call.data.startswith('process_deposit_') and ('_500' in call.data or '_1000' in call.data))
def handle_process_deposit_with_amount(call):
    """Обработчик для администратора - пополнение баланса на фиксированную сумму"""
    try:
        # Извлекаем user_id и сумму из callback_data
        parts = call.data.split('_')
        user_id = parts[2]
        amount_type = parts[3]  # '500' или '1000'
        
        # Определяем сумму пополнения и количество кредитов
        if amount_type == '500':
            deposit_amount = 500
            credit_amount = 50
        else:  # '1000'
            deposit_amount = 1000
            credit_amount = 100
        
        # Обновляем баланс пользователя - Firebase
        from firebase_adapter import fb_add_credits, fb_get_credits
        fb_add_credits(user_id, credit_amount)

        # Legacy SQLite
        try:
            conn = sqlite3.connect(DB_PATH)
            cursor = conn.cursor()
            cursor.execute('UPDATE Partn SET bill = bill + ? WHERE user_id = ?', (credit_amount, user_id))
            conn.commit()
            conn.close()
        except: pass
        
        # Уведомляем пользователя
        bot.send_message(
            user_id,
            f"💳 Ваш баланс пополнен!\n"
            f"💰 Начислено {credit_amount} кредитов.\n"
            f"💳 Текущий баланс: {fb_get_credits(user_id)} кредитов."
        )
        
        # Уведомляем администратора
        bot.answer_callback_query(
            call.id,
            f"✅ Баланс пополнен на {credit_amount} кредитов (FB)",
            show_alert=True
        )
        
        # Обновляем запрос в базе данных
        conn = sqlite3.connect(DB_PATH)
        cursor = conn.cursor()
        cursor.execute('''
            UPDATE requests 
            SET is_answered = 1, answer_text = ?, answer_date = CURRENT_TIMESTAMP
            WHERE user_id = ? AND request_type = 'deposit' AND is_answered = 0
            ORDER BY request_date DESC LIMIT 1
        ''', (f"Пополнено на {credit_amount} кредитов", user_id))
        conn.commit()
        conn.close()
        
        # Удаляем кнопку из сообщения
        bot.edit_message_reply_markup(
            chat_id=call.message.chat.id,
            message_id=call.message.message_id,
            reply_markup=None
        )
        
        # Отправляем подтверждение администратору
        bot.send_message(
            call.message.chat.id,
            f"✅ Баланс пользователя {user_id} пополнен на {credit_amount} кредитов."
        )
        
    except Exception as e:
        bot.answer_callback_query(call.id, "❌ Ошибка при пополнении баланса")
        print(f"Error in handle_process_deposit_with_amount: {e}")


# Обработчик для кнопки пополнения баланса
@bot.callback_query_handler(func=lambda call: call.data.startswith('process_deposit_'))
def handle_process_deposit(call):
    try:
        user_id = call.data.split('_')[2]
        
        # Сохраняем запрос во временное хранилище
        deposit_requests[call.from_user.id] = user_id
        
        # Запрашиваем сумму у администратора
        msg = bot.send_message(
            call.message.chat.id,
            "💵 Введите сумму для пополнения баланса:"
        )
        
        # Регистрируем следующий шаг - обработку введенной суммы
        bot.register_next_step_handler(msg, process_deposit_amount)
        
        bot.answer_callback_query(call.id, "Введите сумму пополнения")
        
    except Exception as e:
        bot.answer_callback_query(call.id, "❌ Ошибка при обработке запроса")

# Обработчик ввода суммы пополнения
def process_deposit_amount(message):
    try:
        admin_id = message.from_user.id
        user_id = deposit_requests.get(admin_id)
        
        if not user_id:
            bot.send_message(admin_id, "❌ Ошибка: запрос не найден")
            return
            
        amount = int(message.text)
        
        # Обновляем баланс пользователя - Firebase
        from firebase_adapter import fb_add_credits, fb_get_credits
        fb_add_credits(user_id, amount)

        # Legacy SQLite
        try:
            conn = sqlite3.connect(DB_PATH)
            cursor = conn.cursor()
            cursor.execute('UPDATE Partn SET bill = bill + ? WHERE user_id = ?', (amount, user_id))
            conn.commit()
            conn.close()
        except: pass
        
        # Уведомляем пользователя
        bot.send_message(
            user_id,
            f"💰 Ваш баланс пополнен на {amount} кредитов.\n"
            f"💳 Текущий баланс: {fb_get_credits(user_id)} кредитов."
        )
        
        # Уведомляем администратора
        bot.send_message(
            admin_id,
            f"✅ Баланс пользователя {user_id} пополнен на {amount} кредитов (FB)."
        )
        
        # Удаляем запрос из временного хранилища
        if admin_id in deposit_requests:
            del deposit_requests[admin_id]
            
    except ValueError:
        bot.send_message(admin_id, "❌ Ошибка: введите числовое значение")
    except Exception as e:
        bot.send_message(admin_id, f"❌ Ошибка при пополнении баланса: {str(e)}")

# @bot.callback_query_handler(func=lambda call: call.data.startswith('process_custom_deposit_'))
# def handle_custom_deposit(call):
#     """Обработчик для произвольного пополнения"""
#     try:
#         user_id = call.data.split('_')[3]
        
#         # Сохраняем запрос во временное хранилище
#         deposit_requests[call.from_user.id] = user_id
        
#         # Запрашиваем сумму у администратора
#         msg = bot.send_message(
#             call.message.chat.id,
#             "💵 Введите сумму для пополнения баланса:"
#         )
        
#         # Регистрируем следующий шаг - обработку введенной суммы
#         bot.register_next_step_handler(msg, process_deposit_amount)
        
#         bot.answer_callback_query(call.id, "Введите сумму пополнения")
        
#     except Exception as e:
#         bot.answer_callback_query(call.id, "❌ Ошибка при обработке запроса")
#         print(f"Error in handle_custom_deposit: {e}")


# Вспомогательная функция для получения баланса пользователя
def get_user_balance(user_id):
    conn = sqlite3.connect(DB_PATH)
    cursor = conn.cursor()
    cursor.execute('SELECT bill FROM Partn WHERE user_id = ?', (user_id,))
    balance = cursor.fetchone()[0] or 0
    conn.close()
    return balance


def adjust_zone_number(num):
    """Корректирует номер зоны к диапазону 0-22"""
    while num > 22:
        num -= 22
    return 0 if num == 22 else num

# Функция для генерации подробного описания

def generate_detailed_description(data):
    nums = data[:14]
    birth_date, name, gender = data[14], data[15], data[16]
    
    # Расчет X и Y для стресса
    x = nums[3] + nums[10]
    x += nums[5] if gender == 'Ж' else nums[6]
    x = adjust_zone_number(x)
    y = x + nums[12]
    y = adjust_zone_number(y)
    
    # Корректировка значений
    def adjust_value(val):
        if val > 22:
            val -= 22
            if val > 22:
                val -= 22
        return 0 if val == 22 else val
    
    x = adjust_value(x)
    y = adjust_value(y)
    
    # Получаем описания зон
    def get_zone_description(num):
        zone_num = 22 if num == 0 else num
        zone = ZONES.get(zone_num, {})
        return zone
    
    # Формируем текст
    description = f"*{name} ({birth_date})*\n*Подробная версия диагностики*\n\n"
    
    # Третичные фазы
    phases = [
        ("первой трети жизни (0-30 лет)", nums[0]),
        ("второй трети жизни (30-60 лет)", nums[1]),
        ("третьей трети жизни (60-90 лет)", nums[2])
    ]
    
    for phase_name, zone_num in phases:
        zone = get_zone_description(zone_num)
        description += f"▫️ В {phase_name} проявляется {zone_num} Роль подсознания ({zone.get('role_name', 'Название')}): \n{zone.get('third', 'Описание отсутствует')}\n\n"
    
    # Точка входа
    zone4 = get_zone_description(nums[3])
    description += f"🔹 Точка \"входа\" - то с чем человек уже пришел сюда, заложенный устойчивый опыт - выражается через {nums[3]} роль: \n({zone4.get('role_name', 'Название')}): {zone4.get('enter', 'Описание отсутствует')}\n\n"
    
    # Дуальности
    female_aspect = f"{nums[5]}-{nums[4]}"
    male_aspect = f"{nums[6]}-{nums[7]}"
    
    # Получаем данные аспектов
    female_aspect_data = ASPECTS_ROLE.get(female_aspect, {})
    male_aspect_data = ASPECTS_ROLE.get(male_aspect, {})
    
    description += f"♀️ Женская дуальность личности (межличностные отношения) проявляется через аспект {nums[5]} - {nums[4]}:\n"
    if female_aspect_data:
        description += (
            f"*{female_aspect_data.get('aspect_name', 'Название')} "
            f"({female_aspect_data.get('aspect_key', 'Роли')})*\n\n"
            f"**🧠 Ключевое качество:**\n {female_aspect_data.get('aspect_strength', 'Описание отсутствует')}\n"
            f"**⚡ Вызов (опасность):**\n {female_aspect_data.get('aspect_challenge', 'Описание отсутствует')}\n"
            f"**🌍 Проявление в жизни:**\n {female_aspect_data.get('aspect_inlife', 'Описание отсутствует')}\n"
            f"**❓ Вопрос для рефлексии:**\n {female_aspect_data.get('aspect_question', 'Вопрос отсутствует')}\n\n"
        )
    else:
        description += f"{ASPECTS.get(female_aspect, 'Описание аспекта отсутствует')}\n\n"
    
    description += f"♂️ Мужская дуальность личности (реализация в социуме) проявляется через аспект {nums[6]} - {nums[7]}:\n"
    if male_aspect_data:
        description += (
            f"*{male_aspect_data.get('aspect_name', 'Название')} "
            f"({male_aspect_data.get('aspect_key', 'Роли')})*\n\n"
            f"**🧠 Ключевое качество:**\n {male_aspect_data.get('aspect_strength', 'Описание отсутствует')}\n"
            f"**⚡ Вызов (опасность):**\n {male_aspect_data.get('aspect_challenge', 'Описание отсутствует')}\n"
            f"**🌍 Проявление в жизни:**\n {male_aspect_data.get('aspect_inlife', 'Описание отсутствует')}\n"
            f"**❓ Вопрос для рефлексии:** {male_aspect_data.get('aspect_question', 'Вопрос отсутствует')}\n\n"
        )
    else:
        description += f"{ASPECTS.get(male_aspect, 'Описание аспекта отсутствует')}\n\n"
    
    # Основной мотив
    zone9 = get_zone_description(nums[8])
    description += f"🎯 Основной мотив личности проявляется через {nums[8]} Роль подсознания ({zone9.get('role_name', 'Название')}):\n{zone9.get('motive', 'Описание отсутствует')}\n\n"
    
    # Способ действия
    zone10 = get_zone_description(nums[9])
    description += f"🛠 Основной способ действия обусловлен {nums[9]} Ролью подсознания ({zone10.get('role_name', 'Название')}):\n{zone10.get('action', 'Описание отсутствует')}\n\n"
    
    # Сфера реализации
    zone11 = get_zone_description(nums[10])
    description += f"🌐 Подходящая сфера реализации обусловлена {nums[10]} Ролью подсознания ({zone11.get('role_name', 'Название')}):\n{zone11.get('field', 'Описание отсутствует')}\n\n"
    
    # Точка выхода
    zone13 = get_zone_description(nums[12])
    description += f"🚪 Точка выхода обусловлена {nums[12]} Ролью подсознания ({zone13.get('role_name', 'Название')}):\n{zone13.get('out', 'Описание отсутствует')}\n\n"
    
    # Внутренний мир
    zone12 = get_zone_description(nums[11])
    description += f"💭 \"Внутренний мир\" личности проявляется через {nums[11]} Роль подсознания ({zone12.get('role_name', 'Название')}):\n{zone12.get('fear', 'Описание отсутствует')}\n\n"
    
    # Баланс
    zone14 = get_zone_description(nums[13])
    description += f"⚖️ Баланс внешнего/внутреннего проявляется через {nums[13]} Роль подсознания ({zone14.get('role_name', 'Название')}):\n{zone14.get('out', 'Описание отсутствует')}\n\n"
    
    # Стресс
    zone_x = get_zone_description(x)
    zone_y = get_zone_description(y)
    
    description += f"🧠 В стрессе личность проявляется через {x} Роль подсознания ({zone_x.get('role_name', 'Название')}):\n{zone_x.get('fear', 'Описание отсутствует')}\n\n"
    description += f"⚖️ Сбалансировать состояние в стрессе можно через проявление {y} Роли подсознания ({zone_y.get('role_name', 'Название')}):\n{zone_y.get('description', 'Описание отсутствует')}"
    
    return description


# Запуск бота
while True:
    try:
        bot.polling(none_stop=True)
    except Exception as e:
        print(f"Ошибка: {e}")
        time.sleep(15)