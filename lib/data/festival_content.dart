import 'package:flutter/material.dart';

// Rich Content for Festival Masters/Activities
// title -> formatted description, image, links, color
final Map<String, FestivalActivityContent> festivalContent = {
  // 1. Ксения Варакина
  "МАГИЯ ЛИЧНОСТИ": FestivalActivityContent(
    masterName: "Ксения Варакина",
    title: "МАГИЯ ЛИЧНОСТИ",
    description: "«Магия личности» — игра, после которой вы определите 1 стратегическое решение, меняющее вашу траекторию.\n\nЭто сочетание коучинговой глубины, психологической точности и игрового формата, который позволяет увидеть свои слепые зоны быстрее, чем за месяцы самокопания.\n\nЧто даёт игра?\nЭто не «ещё одно упражнение». Это формат, в котором:\n➡️ Заметны привычные, но уже неработающие стратегии,\n➡️ Легко найти решение, даже если откладывали его несколько месяцев или лет,\n➡️ За пару шагов можно увидеть то, что сдерживает и не даёт шагнуть вперёд.\n\nПосле игры вы:\n⚡️ Поймёте, какой шаг сделать в ближайшие 72 часа\n⚡️ Уйдёте с 3 чёткими решениями\n⚡️ Получите заряд энергии на конкретные действия\n\nНе просто веду игру, а помогаю увидеть в вас то, что вы давно перестали замечать.",
    imagePath: "assets/images/ksenia_varakina.jpg",
    color: Colors.orangeAccent,
    role: "Коуч, психолог, бизнес-тренер",
    links: [
      {'icon': Icons.send, 'url': 'https://t.me/ksvarakina', 'tooltip': 'Написать'},
      {'icon': Icons.language, 'url': 'https://www.ksvarakina.ru', 'tooltip': 'Сайт'},
      {'icon': Icons.campaign, 'url': 'https://t.me/varakina_fm', 'tooltip': 'Канал'},
    ]
  ),

  // 2. Владимир Папушин
  "РЫБАКОВ. ИГРА НА МИЛЛИАРД": FestivalActivityContent(
    masterName: "Владимир Папушин / Ирина Абрамова", // Shared Title in Map Key? 
                                                     // Actually we handle uniqueness by using unique keys or looking up by key.
                                                     // Since two masters have same game title "RYBAKOV...", we might need specific keys or a list.
                                                     // For now, let's allow lookup by approximate title.
    title: "РЫБАКОВ. ИГРА НА МИЛЛИАРД",
    description: "«Рыбаков. Игра на миллиард» — Коммуникация, переговоры, стратегия.\n\nУникальный бизнес-тренажер, развивающий навыки предпринимательского мышления и масштабного видения.\n\nНа игре вы прокачаете:\n🎲 Навыки коммуникации и построения партнерств\n🎲 Стратегическое мышление\n🎲 Умение видеть возможности там, где другие видят проблемы.",
    imagePath: "assets/images/vladimir_papushin.jpg",
    color: Colors.blue,
    role: "Предприниматель, игропрактик",
    links: [
        {'icon': Icons.language, 'url': 'https://cashflowpiter.ru/', 'tooltip': 'Сайт'},
        {'icon': Icons.group, 'url': 'https://vk.com/pro_cashflow_spb', 'tooltip': 'VK'},
    ]
  ),

  // 3. Олег Баранец
  "ТЕРРИТОРИЯ СЕБЯ": FestivalActivityContent(
    masterName: "Олег Баранец",
    title: "ТЕРРИТОРИЯ СЕБЯ",
    description: "«Территория Себя» — Авторская трансформационная игра.\n\nИгра, которая помогает превратить хаос в ясную структуру развития. Это инструмент для глубокой диагностики и нахождения скрытых ресурсов личности.\n\nОлег — эксперт по систематизации жизни и бизнеса, основатель Info Cards Club.\n\n«Преобразую хаос в ясность».",
    imagePath: "assets/images/olegbaranets.jpg",
    color: Colors.lightBlueAccent,
    role: "Психолог, бизнес-аналитик",
    links: [
       {'icon': Icons.send, 'url': 'https://t.me/id_territory', 'tooltip': 'Канал'},
       {'icon': Icons.language, 'url': 'https://infocards.club', 'tooltip': 'Сайт'},
    ]
  ),

  // 4. Тома Стулова
  "НЕТИПИЧНЫЙ НЕТВОРКИНГ": FestivalActivityContent(
    masterName: "Тома Стулова",
    title: "НЕТИПИЧНЫЙ НЕТВОРКИНГ",
    description: "«Нетипичный нетворкинг» — Нетворкинг, без шаблонов, где нет скуки, а есть драйв, игры и настоящие связи!\n\nТебя ждут:\n✔️ Знакомства через игру — никаких заученных презентаций.\n✔️ Импровизация вместо скучных вопросов — прокачаем спонтанность.\n✔️ Формат \"как в жизни\" — общаемся легко, без официоза.\n\nИгры снимают барьеры — вы знакомитесь через эмоции, а не должности.\n— Нетворкинг \"по интересам\" — находите тех, кто вам действительно близок.\n— Уходите не только с контактами, но и с идеями для совместных дел.",
    imagePath: "assets/images/toma.jpg",
    color: Colors.pinkAccent,
    role: "Генератор идей, игропрактик",
    links: [
       {'icon': Icons.send, 'url': 'https://t.me/tomastulova', 'tooltip': 'Telegram'},
       {'icon': Icons.campaign, 'url': 'https://t.me/bla_bla_game', 'tooltip': 'Канал'},
    ]
  ),

  // 5. Ольга Дорошкевич
  "ТЕРРИТОРИЯ ДЕНЕГ": FestivalActivityContent(
    masterName: "Ольга Дорошкевич",
    title: "ТЕРРИТОРИЯ ДЕНЕГ",
    description: "«Территория Денег» — Трансформационная игра.\n\nЭто игра-помощник при переходе на новый денежный уровень. В игре Вы сможете изменить мышление «дефицита» на мышление «изобилия».\n\nИгра помогает:\n📍 Найти причины ограничивающие доход\n📍 Понять какой блок в теме денег\n📍 Выстроить эффективную денежную стратегию\n\nОльга — Ресурсный КОУЧ, автор игр, МАК карт, книги Живые Строки, мастер игровых техник, ченнелер.",
    imagePath: "assets/images/olga.jpg",
    color: Colors.green,
    role: "Ресурсный коуч, игропрактик",
    links: [
       {'icon': Icons.send, 'url': 'https://t.me/olga_doroshkevich', 'tooltip': 'Telegram'},
       {'icon': Icons.campaign, 'url': 'https://t.me/OlgaDoroshkevichVselennya', 'tooltip': 'Канал'},
    ]
  ),
  
  // 6. Вера Майнакская
  "ПУТЬ ЖЕЛАНИЙ": FestivalActivityContent(
    masterName: "Вера Майнакская",
    title: "ПУТЬ ЖЕЛАНИЙ",
    description: "«Путь Желаний» — Большая напольная игра пространство для честного диалога с собой.\n\nЗдесь можно мягко и безопасно заглянуть во внутренний мир, услышать своё сердце и дать голос своим настоящим мечтам.\n\nИгра помогает увидеть:\n✨ что мешает исполнению желаемого\n✨ какие страхи стоят на пути к цели\n✨ какая сфера жизни сейчас может стать точкой ресурса\n\nЭто не гадание — это структурная работа с запросом.",
    imagePath: "assets/images/vera.jpg",
    color: Colors.cyanAccent,
    role: "Игропрактик, эксперт по желаниям",
    links: [
       {'icon': Icons.send, 'url': 'https://t.me/Vera_Maynakskaya', 'tooltip': 'Telegram'},
       {'icon': Icons.campaign, 'url': 'https://t.me/VeraMaynakskaya', 'tooltip': 'Канал'},
    ]
  ),

  // 7. Ирина Визнюк
  "АРТ-ТЕРАПЕВТИЧЕСКАЯ ПРАКТИКА": FestivalActivityContent(
    masterName: "Ирина Визнюк",
    title: "АРТ-ТЕРАПЕВТИЧЕСКАЯ ПРАКТИКА",
    description: "«Арт-терапевтическая практика» — Практика помогает вынести страх в образ, снизить его влияние и открыть движение к целям.\n\nЧто происходит в процессе:\n— ты выносишь свой страх из головы во внешний образ\n— мозг перестаёт воспринимать его как угрозу\n— напряжение снижается, появляется ясность\n— открывается движение туда, где раньше было «не могу»\n\nСтрах перестаёт управлять. Он становится видимым, конечным и… не таким страшным.",
    imagePath: "assets/images/irina_viznyuk.jpg",
    color: Colors.purple,
    role: "Предприниматель, художник",
    links: [
       {'icon': Icons.send, 'url': 'https://t.me/IV_digitalart', 'tooltip': 'Telegram'},
       {'icon': Icons.campaign, 'url': 'https://t.me/irinaviznuk', 'tooltip': 'Канал'},
    ]
  ),

  // 8. Светлана Гурина
  "ОЧЕРЕДЬ ИЗ ДЕНЕГ": FestivalActivityContent(
    masterName: "Светлана Гурина",
    title: "ОЧЕРЕДЬ ИЗ ДЕНЕГ",
    description: "«Очередь из денег» — Трансформационная игра про отношения с деньгами через состояние, внутренние роли и выборы.\n\nВ процессе становится видно:\n— из какого внутреннего места человек заходит в деньги,\n— где он себя ограничивает,\n— какие ресурсы уже есть, но не используются,\n— что мешает двигаться дальше.\n\nИгра помогает не искать «волшебные схемы», а глубже понять себя и выстроить более устойчивые отношения с деньгами.",
    imagePath: "assets/images/svetlana_gurina.jpg",
    color: Colors.deepPurpleAccent,
    role: "Женский коуч, мастер МАК",
    links: [
       {'icon': Icons.send, 'url': 'https://t.me/svetlana_gurina_aroma_candles', 'tooltip': 'Telegram'},
       {'icon': Icons.campaign, 'url': 'https://t.me/tvoe_sostoyanie_sveta', 'tooltip': 'Канал'},
    ]
  ),
  
  // 9. Екатерина Волкова
  "ЛИЛА": FestivalActivityContent(
    masterName: "Екатерина Волкова",
    title: "ЛИЛА",
    description: "«Лила» — это глубокая психологическая игра-практика, которая помогает исследовать важные жизненные темы, отношения с собой и найти ответы, уже живущие внутри.\n\nЗачем играть?\n— Исследовать свой внутренний мир и ситуации.\n— Выйти из замкнутого круга мыслей.\n— Услышать свою интуицию.\n\nКакой результат?\n— Ясность в ситуации.\n— Опора и контакт с собой.\n— Инсайт и энергия для следующего шага.",
    imagePath: "assets/images/ekaterina_volkova.jpg",
    color: Colors.indigo,
    role: "Психолог, расстановщик",
    links: [
       {'icon': Icons.send, 'url': 'https://t.me/ekaterinavteta', 'tooltip': 'Личные сообщения'},
       {'icon': Icons.campaign, 'url': 'https://t.me/lilaprotebja', 'tooltip': 'Канал'},
    ]
  ),
  
  // 10. Ирина Абрамова
  "ИГРА НА МИЛЛИАРД (Абрамова)": FestivalActivityContent(
     masterName: "Ирина Абрамова",
     title: "РЫБАКОВ. ИГРА НА МИЛЛИАРД",
     description: "Для меня «Игра на миллиард» — это диагностика:\n- ваших навыков коммуникации;\n- умения оценивать стоимость ваших ресурсов;\n- ваших способностей доносить ценность сотрудничества с вами.\n\nЕсли:\n➡️ вас не слышат,\n▶️ вам сложно договариваться,\n➡️ кажется, что вас не понимают,\n\nтогда я иду к вам!",
     imagePath: "assets/images/irina_abramova.jpg",
     color: Colors.teal,
     role: "Переговорщик, медиатор",
     links: [
       {'icon': Icons.send, 'url': 'https://t.me/Irina_mediator', 'tooltip': 'Написать'},
       {'icon': Icons.campaign, 'url': 'https://t.me/razvitiebussnes', 'tooltip': 'Канал'},
     ]
  ),

  // 11. Надежда Ланская / Тома Стулова
  "Недостатки vs SuperСпособности": FestivalActivityContent(
    masterName: "Надежда Ланская",
    title: "Недостатки vs SuperСпособности",
    description: "⭐️Недостатки vs SuperСпособности Коммуникативная игра со смыслом ⭐️\n\nТы когда-нибудь задумывался, что твои недостатки могут оказаться суперспособностями?\n\nМы, Надя и Тома, маркетолог и игропрактик, приглашаем тебя на необычное мероприятие, где в игровом формате ты сможешь проработать свои недостатки и сильные стороны.\n\nЧто будет:\n✨ Увидишь, как то, что ты считал минусом, может стать твоим главным козырем.\n✨ Научишься «продавать» и использовать любую свою черту характера.",
    imagePath: "assets/images/nadezhda_lanskaya.jpg",
    color: Colors.orange,
    role: "Маркетолог для экспертов",
    links: [
       {'icon': Icons.send, 'url': 'https://t.me/landusha', 'tooltip': 'Написать'},
       {'icon': Icons.campaign, 'url': 'https://t.me/landusha_thinks', 'tooltip': 'Канал'},
    ],
    secondaryImagePath: "assets/images/nadya_toma_game.jpg"
  ),

  // 12. Екатерина Курчавина
  "ТЕРРИТОРИЯ СЕБЯ (Специальный сет)": FestivalActivityContent(
    masterName: "Екатерина Курчавина",
    title: "ТЕРРИТОРИЯ СЕБЯ (Специальный сет)",
    description: "Екатерина — уникальный специалист, объединяющий точность и творчество. Преподаватель ментальной арифметики и английского языка, педагог и сертифицированный диагност.\n\nВ то время как автор игры Олег Баранец дает структуру и стратегию, Екатерина предлагает альтернативное прочтение методики — творческое и игривое.\n\nЧто вас ждет за столом Екатерины:\n🎲 Работа с 22 ролями-архетипами через призму творчества.\n🎲 Расширение границ.\n🎲 Безопасное пространство.",
    imagePath: "assets/images/ekaterina_kurchavina.jpg",
    color: Colors.deepOrangeAccent,
    role: "Психолог, педагог",
    links: [
       {'icon': Icons.send, 'url': 'https://t.me/Katya_psySoul', 'tooltip': 'Telegram'},
    ]
  ),

  // 13. Анна Торпан
  "ПРАКТИКА ГВОЗДЕСТОЯНИЯ": FestivalActivityContent(
    masterName: "Анна Торпан",
    title: "ПРАКТИКА ГВОЗДЕСТОЯНИЯ",
    description: "«Найди точку опоры внутри себя»\n\nПриглашаем вас на глубокую практику Стояния на гвоздях Садху — мощный инструмент для возвращения к себе.\n\nЭто путешествие, в котором вы:\n· Остановите бесконечный поток мыслей.\n· Освободите тело от накопленного напряжения.\n· Осознаете и отпустите убеждения, блокирующие ваш финансовый рост.\n· Наполнитесь чувством энергии и лёгкости.",
    imagePath: "assets/images/Anya_Torpan.jpg",
    color: Colors.redAccent,
    role: "Эксперт телесной терапии",
    links: [
       {'icon': Icons.send, 'url': 'https://t.me/aniitorpan', 'tooltip': 'Написать'},
       {'icon': Icons.campaign, 'url': 'https://t.me/aniitorpan_I', 'tooltip': 'Канал'},
    ]
  ),
  
  // 14. ВарВара Ардель
  "КАГОМЭ-КАГОМЭ": FestivalActivityContent(
    masterName: "ВарВара Ардель",
    title: "КАГОМЭ-КАГОМЭ",
    description: "ВарВара — уникальный проводник, работающий на стыке психологии и телесности.\n\nИгра-переход. Инструмент для тех, кто готов к качественным изменениям в жизни.\n\nЧто вас ждет:\n🕊 Сила стихий: осознание и активация силы природных стихий.\n🕊 Новый уровень мышления: ресурсы для перехода на новый этаж сознания.\n🕊 Поддержка на пути: мифическая птичка Кагомэ поддержит в трансформации.",
    imagePath: "assets/images/varvara_ardel.jpg",
    color: Colors.lime,
    role: "Квантовый психолог, игропрактик",
    links: [
       {'icon': Icons.send, 'url': 'https://t.me/apelsin44', 'tooltip': 'Telegram'},
       {'icon': Icons.campaign, 'url': 'https://t.me/VarVara_VEdOM', 'tooltip': 'Канал'},
    ]
  ),
};


class FestivalActivityContent {
  final String masterName;
  final String title;
  final String description;
  final String imagePath;
  final Color color;
  final String role;
  final List<Map<String, dynamic>> links;
  final String? secondaryImagePath;

  const FestivalActivityContent({
    required this.masterName,
    required this.title,
    required this.description,
    required this.imagePath,
    required this.color,
    required this.role,
    this.links = const [],
    this.secondaryImagePath,
  });
}
