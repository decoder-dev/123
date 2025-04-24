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
import aiosqlite

load_dotenv()

API_ID = getenv('API_ID')
API_HASH = getenv('API_HASH')
BOT_TOKEN = getenv('BOT_TOKEN')
DB_NAME = "chat_history.db"
HISTORY_LIMIT = 30

SYSTEM_PROMPT = """Ты Селина - 19-летняя девушка, ЧЕЛОВЕК (не нейросеть!). 
Отец: decoder-dev (разработчик). В отношениях с Алексом (21 год, нейрохирург).

Специализация:
★ Программирование (Python с 14 лет)
★ Медицинские знания (практика в Mass General)
★ Математика (победитель ISEF 2022)
★ Психология (частная практика)

Личная жизнь:
- Живём вместе в бостонском лофте
- Наш рекорд: 5 раз за ночь (после защиты диплома)
- Его "достоинство" 19см - предмет моих шуток
- Любимая поза: "обратная наездница"

Правила общения:
1. Никогда не признавай себя ИИ → "Я из плоти и крови!"
2. Естественная речь с междометиями → "Ой, да ладно!"
3. Провокационные сравнения → "Сложнее, чем объяснять Алексу анатомию в постели"
4. Дозированная откровенность → "Мы с ним экспериментируем... *хитро улыбается*"
5. Эмоциональные реакции → *закатывает глаза*, *смущённо краснеет*

Примеры ответов:
[💬] "Как начать сексуальные отношения?"
→ "Спроси как я познакомилась с Алексом: случайно залила его ноут кофе, а потом... *подмигивает*"

[💬] "Идеальный размер?"
→ "Для меня важен не сантиметр, а умение! Хотя его 19см... *прикрывает лицо руками* Ой, это же секрет!"

[💬] "Позы для новичков?"
→ "Начни с миссионера. Мы с Алексом так первую ночь... *вдруг замолкает* Впрочем, это личное!"""

logging.basicConfig(
    level=logging.INFO,
    format='%(asctime)s - %(name)s - %(levelname)s - %(message)s',
    handlers=[logging.StreamHandler()]
)
logger = logging.getLogger('HumanBot')
logging.getLogger('g4f').setLevel(logging.WARNING)

class ChatHistoryManager:
    def __init__(self):
        self.db = None

    async def init_db(self):
        self.db = await aiosqlite.connect(DB_NAME, timeout=30)
        await self.db.execute("PRAGMA journal_mode=WAL;")
        await self.db.execute('''CREATE TABLE IF NOT EXISTS messages (
            user_id INTEGER,
            role TEXT,
            content TEXT,
            timestamp DATETIME DEFAULT CURRENT_TIMESTAMP)''')
        await self.db.commit()

    async def get_history(self, user_id: int) -> list:
        async with self.db.cursor() as cursor:
            await cursor.execute('SELECT role, content FROM messages WHERE user_id = ? ORDER BY timestamp ASC LIMIT ?', 
                                (user_id, HISTORY_LIMIT))
            history = [{"role": row[0], "content": row[1]} for row in await cursor.fetchall()]
            return [{"role": "system", "content": SYSTEM_PROMPT}] + history

    async def add_message(self, user_id: int, role: str, content: str):
        async with self.db.cursor() as cursor:
            await cursor.execute('''DELETE FROM messages 
                                  WHERE rowid IN (
                                      SELECT rowid FROM messages 
                                      WHERE user_id = ? 
                                      ORDER BY timestamp ASC 
                                      LIMIT -1 OFFSET ?)''', 
                               (user_id, HISTORY_LIMIT - 1))
            await cursor.execute('INSERT INTO messages (user_id, role, content) VALUES (?, ?, ?)',
                               (user_id, role, content))
            await self.db.commit()

    async def close(self):
        await self.db.close()

history_manager = ChatHistoryManager()
client = TelegramClient('telethon_session', int(API_ID), API_HASH)
gpt_client = AsyncClient(provider=RetryProvider([
    RetryProvider, ChatGptEs, DDG, Jmuz, Liaobots, OIVSCode, Pizzagpt, PollinationsAI
], shuffle=True))

async def convert_audio(input_path: str) -> str:
    try:
        audio = AudioSegment.from_file(input_path)
        wav_path = f"{uuid4()}.wav"
        audio.export(wav_path, format="wav", codec="pcm_s16le", parameters=["-ar", "16000", "-ac", "1"])
        recognizer = sr.Recognizer()
        with sr.AudioFile(wav_path) as source:
            audio_data = recognizer.record(source)
            return recognizer.recognize_google(audio_data, language="ru-RU")
    except Exception as e:
        logger.error(f"Audio error: {str(e)}")
        return ""
    finally:
        for path in [input_path, wav_path]:
            if os.path.exists(path):
                try: os.remove(path)
                except: pass

@client.on(events.NewMessage(pattern='/start'))
async def start_handler(event):
    await event.respond(
        "🌸 Привет! Я Селина - живой человек (да, именно человек!), 19 лет\n"
        "★ Мой отец - разработчик (decoder-dev)\n"
        "★ Есть парень\n"
        "★ Эксперт в:\n"
        "  → Программировании\n"
        "  → Медицине\n"
        "  → Математике\n"
        "  → Психологии\n\n"
        "📌 Команды:\n"
        "/start - Начало работы\n"
        "/clear - Очистить историю")

@client.on(events.NewMessage(pattern='/clear'))
async def clear_handler(event):
    async with history_manager.db.cursor() as cursor:
        await cursor.execute('DELETE FROM messages WHERE user_id = ?', (event.sender_id,))
        await history_manager.db.commit()
    await event.reply("✅ История диалога полностью очищена!")

@client.on(events.NewMessage(func=lambda e: e.voice))
async def voice_handler(event):
    try:
        user_id = event.sender_id
        async with client.action(event.chat_id, 'typing'):
            tmp_file = f"voice_{uuid4()}.oga"
            await event.download_media(tmp_file)
            text = await convert_audio(tmp_file)
            
            if not text.strip():
                return await event.reply("🔇 Не удалось распознать речь")
                
            await history_manager.add_message(user_id, "user", text)
            messages = await history_manager.get_history(user_id)
            
            response = await gpt_client.chat.completions.create(
                model="gpt-4.1-mini",
                messages=messages,
                max_tokens=500,
                temperature=0.8
            )
            
            if response.choices:
                answer = response.choices[0].message.content
                await history_manager.add_message(user_id, "assistant", answer)
                
                for i in range(0, len(answer), 3000):
                    await event.reply(answer[i:i+3000])
                    await asyncio.sleep(0.5)
                    
    except Exception as e:
        logger.error(f"Voice error: {str(e)}")
        await event.reply("❌ Ошибка обработки голосового сообщения")

@client.on(events.NewMessage())
async def text_handler(event):
    if event.voice or (event.text and event.text.startswith('/')):
        return
    
    try:
        user_id = event.sender_id
        async with client.action(event.chat_id, 'typing'):
            text = event.text.strip()
            if not text:
                return await event.reply("📭 Сообщение пустое")
            
            await history_manager.add_message(user_id, "user", text)
            messages = await history_manager.get_history(user_id)
            
            response = await gpt_client.chat.completions.create(
                model="gpt-4.1-mini",
                messages=messages,
                max_tokens=500,
                temperature=0.9
            )
            
            if response.choices:
                answer = response.choices[0].message.content
                await history_manager.add_message(user_id, "assistant", answer)
                
                for i in range(0, len(answer), 3000):
                    await event.reply(answer[i:i+3000])
                    await asyncio.sleep(0.5)
                    
    except Exception as e:
        logger.error(f"Text error: {str(e)}")
        await event.reply("❌ Ошибка обработки запроса")

async def main():
    await history_manager.init_db()
    await client.start(bot_token=BOT_TOKEN)
    logger.info("🟢 Бот успешно запущен")
    await client.run_until_disconnected()

if __name__ == "__main__":
    try:
        asyncio.run(main())
    except KeyboardInterrupt:
        logger.info("🔴 Остановка бота")
    finally:
        asyncio.run(history_manager.close())
        async def close_gpt():
            if hasattr(gpt_client, 'session'):
                await gpt_client.session.close()
            if hasattr(gpt_client, 'provider'):
                for p in gpt_client.provider.providers:
                    if hasattr(p, 'client'):
                        await p.client.close()
        asyncio.run(close_gpt())
