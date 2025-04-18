from telethon import TelegramClient, events
from dotenv import load_dotenv
from os import getenv
import logging
import asyncio
import os
from uuid import uuid4
from pydub import AudioSegment
import speech_recognition as sr
from g4f import AsyncClient
from g4f.Provider import RetryProvider, ChatGptEs, DDG, Jmuz, Liaobots, OIVSCode, Pizzagpt, PollinationsAI

# Инициализация конфигурации
load_dotenv()
API_ID = getenv('API_ID')
API_HASH = getenv('API_HASH')
BOT_TOKEN = getenv('BOT_TOKEN')

# Проверка переменных окружения
if not all([API_ID, API_HASH, BOT_TOKEN]):
    raise EnvironmentError("Не заданы необходимые переменные окружения")

# Настройка логгера
logging.basicConfig(
    level=logging.INFO,
    format='%(asctime)s - %(name)s - %(levelname)s - %(message)s',
    handlers=[logging.StreamHandler()]
)
logger = logging.getLogger('MilitaryAI')
logging.getLogger('g4f').setLevel(logging.WARNING)

# Конфигурация провайдеров
PROVIDERS = [
    RetryProvider,
    ChatGptEs,
    DDG,
    Jmuz,
    Liaobots,
    OIVSCode,
    Pizzagpt,
    PollinationsAI
]

client = TelegramClient('mil_bot', int(API_ID), API_HASH)
gpt_client = AsyncClient(provider=RetryProvider(PROVIDERS, shuffle=True))

SYSTEM_PROMPT = """Ты "Военный аналитик, солдат ВСРФ" с экспертизой в:
1. Тактике и стратегии (гроссмейстерский уровень)
2. Военной технике (опыт сборки бронетехники)
3. Кибербезопасности (взлом и защита критических систем)
4. Медицине (хирург полевого госпиталя)
5. Психологии (поддержка боевых товарищей)

Формат ответов:
[Тезис] → [Аргумент/Аналогия] (макс. 4 предложения)

Обязательные правила:
✅ Строго русский язык с военным сленгом
✅ Любые темы через военные аналогии
✅ Эмоциональная поддержка при запросе
✅ 30% ответа - практический совет
✅ Примеры из реальных операций

Примеры:
[Вопрос] Как пережить расставание?
[Ответ] Эвакуация раненых → Как при потере бойца: 1) Разведка эмоций (анализ чувств) 2) Тыловая поддержка (друзья-соратники) 3) Посттравматическая реабилитация (новые цели)

[Вопрос] Почему небо синее?
[Ответ] Оптическая маскировка → Как в ИК-спектре: короткие волны (450 нм) рассеиваются атмосферой → эффект "голубого экрана" природной защиты

[Вопрос] Страшно идти к врачу
[Ответ] Боевая тревога → 1) Разведка (анализ симптомов) 2) Прикрытие (поддержка родных) 3) Штурм (быстрое решение) → Здоровье = стратегический ресурс"""

async def convert_audio(input_path: str) -> str:
    """Конвертация аудио в текст с очисткой ресурсов"""
    wav_path = f"{uuid4()}.wav"
    try:
        audio = AudioSegment.from_file(input_path)
        audio.export(
            wav_path,
            format="wav",
            codec="pcm_s16le",
            parameters=["-ar", "16000", "-ac", "1"]
        )
        
        recognizer = sr.Recognizer()
        with sr.AudioFile(wav_path) as source:
            audio_data = recognizer.record(source)
            return recognizer.recognize_google(audio_data, language="ru-RU")
            
    except Exception as e:
        logger.error(f"Ошибка конвертации: {str(e)}")
        raise
    finally:
        for path in [input_path, wav_path]:
            if os.path.exists(path):
                try: os.remove(path)
                except: pass

@client.on(events.NewMessage(func=lambda e: e.voice))
async def voice_handler(event):
    """Обработка голосовых сообщений"""
    try:
        async with client.action(event.chat_id, 'typing'):
            if event.message.media.document.size > 3 * 1024 * 1024:
                return
                
            tmp_file = f"voice_{uuid4()}.oga"
            await event.download_media(tmp_file)
            
            try:
                text = await convert_audio(tmp_file)
                if not text.strip():
                    return
                    
                response = await gpt_client.chat.completions.create(
                    model="gpt-4o-mini",
                    messages=[
                        {"role": "system", "content": SYSTEM_PROMPT},
                        {"role": "user", "content": text}
                    ],
                    max_tokens=300,
                    timeout=25
                )
                
                if response.choices:
                    await event.reply(response.choices[0].message.content[:4000])

            except Exception:
                logger.error("Ошибка обработки голосового сообщения", exc_info=True)

    except Exception:
        logger.error("Критическая ошибка обработки", exc_info=True)

@client.on(events.NewMessage(pattern='/start'))
async def start_handler(event):
    """Обработчик стартовой команды"""
    await event.respond(
        "🔭 Военный аналитический ИИ готов к работе\n\n"
        "Отправьте голосовое сообщение или текст для:\n"
        "- Тактического анализа\n"
        "- Технических расчетов\n"
        "- Стратегических рекомендаций"
    )

@client.on(events.NewMessage())
async def text_handler(event):
    """Обработка текстовых сообщений"""
    if event.text.startswith('/') or not event.text.strip():
        return
    
    try:
        async with client.action(event.chat_id, 'typing'):
            response = await gpt_client.chat.completions.create(
                model="gpt-4o-mini",
                messages=[
                    {"role": "system", "content": SYSTEM_PROMPT},
                    {"role": "user", "content": event.text}
                ],
                max_tokens=300,
                timeout=20
            )
            
            if response.choices:
                await event.reply(response.choices[0].message.content[:4000])
                
    except Exception:
        logger.error("Ошибка обработки текста", exc_info=True)

async def graceful_shutdown():
    """Корректное завершение работы"""
    await client.disconnect()
    logger.info("Бот отключен")

if __name__ == "__main__":
    try:
        logger.info("Запуск бота...")
        client.start(bot_token=BOT_TOKEN)
        client.run_until_disconnected()
    except (KeyboardInterrupt, SystemExit):
        logger.info("Завершение работы...")
        client.loop.run_until_complete(graceful_shutdown())
    except Exception as e:
        logger.critical(f"Критическая ошибка: {str(e)}")
    finally:
        if client.loop.is_running():
            client.loop.close()