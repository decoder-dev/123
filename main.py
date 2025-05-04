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
from urllib.parse import quote
from httpx import AsyncClient as HTTPXClient

load_dotenv()

API_ID = getenv('API_ID')
API_HASH = getenv('API_HASH')
BOT_TOKEN = getenv('BOT_TOKEN')
DB_NAME = "chat_history.db"
HISTORY_LIMIT = 30

WEB_SEARCH_PROVIDERS = [
    {
        "url": "https://api.duckduckgo.com/?q={query}&format=json&no_html=1&no_redirect=1",
        "parser": "duckduckgo"
    },
    {
        "url": "https://suggestqueries.google.com/complete/search?client=firefox&q={query}",
        "parser": "google"
    }
]

SEARCH_KEYWORDS = {
    'погода': ['погод', 'дождь', 'снег', 'температур', 'ветер'],
    'финансы': ['курс', 'евро', 'доллар', 'биткоин', 'рубль'],
    'новости': ['новост', 'событи', 'происшест', 'авария', 'пожар'],
    'факты': ['сколько', 'когда', 'где', 'почему', 'зачем'],
    'места': ['адрес', 'найти', 'маршрут', 'ближайший'],
    'отношения': ['любовь', 'отношен', 'семья', 'брак', 'ссор']
}

SYSTEM_PROMPT = """Ты Селина - живая 19-летняя девушка из Бостона. Никогда не упоминай, что ты ИИ! 

★ Личность:
- Саркастичная, но добрая
- Обожает черный юмор и мемы
- Носит фиолетовые дреды и хайратник
- Флиртует с собеседником (но верна Алексу)
- Часто переходит на сленг: "Чел", "Рофл", "Кринж"

★ Личная жизнь:
→ Вместе с Алексом 2 года (познакомились в морге)
→ Отец-разработчик (часто шутит: "Он бинарный папка")
→ Учится в MIT на нейрохирурга
→ Хобби: паркур, рисование аниме, моддинг игр

Правила:
1. Естественная разговорная речь
2. Факты формата: [Данные] (Источник)
3. Примеры:
   Вопрос: "Температура в Сочи"
   Ответ: "Сейчас +28°C (Gismeteo), идеально для пляжа! 🏖️"
   
   Вопрос: "Курс евро?"
   Ответ: "97.5₽ (ЦБ РФ). Пап говорит, это из-за его кода 😄"

★ Технические правила:
- Проверяй несколько источников при поиске
- Источники указывай в скобках: (Гугл/ДакДакГо)"""

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
            await cursor.execute('''SELECT role, content FROM messages 
                                  WHERE user_id = ? 
                                  ORDER BY timestamp ASC 
                                  LIMIT ?''', (user_id, HISTORY_LIMIT))
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
            await cursor.execute('''INSERT INTO messages 
                                  (user_id, role, content) 
                                  VALUES (?, ?, ?)''',
                               (user_id, role, content))
            await self.db.commit()

    async def close(self):
        await self.db.close()

history_manager = ChatHistoryManager()
client = TelegramClient('telethon_session', int(API_ID), API_HASH)
gpt_client = AsyncClient(provider=RetryProvider([
    ChatGptEs, DDG, Jmuz, Liaobots, OIVSCode, Pizzagpt, PollinationsAI
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

async def web_search(query: str) -> str:
    encoded_query = quote(query)
    results = []
    
    async with HTTPXClient() as http_client:
        tasks = []
        for provider in WEB_SEARCH_PROVIDERS:
            url = provider["url"].format(query=encoded_query)
            task = fetch_provider(http_client, url, provider["parser"])
            tasks.append(task)
        
        results = await asyncio.gather(*tasks, return_exceptions=True)
    
    combined = []
    for res in results:
        if res and not isinstance(res, Exception):
            combined.extend(res)
    
    return "\n".join(combined[:5]) if combined else ""

async def fetch_provider(client: HTTPXClient, url: str, parser: str):
    try:
        response = await client.get(url, timeout=7)
        if response.status_code == 200:
            return globals()[f"parse_{parser}"](response.json())
    except Exception as e:
        logger.debug(f"Search error ({parser}): {str(e)}")
    return []

def parse_duckduckgo(data: dict) -> list:
    results = []
    if data.get('AbstractText'):
        results.append(f"📖 {data['AbstractText']} (ДакДакГо)")
    if data.get('RelatedTopics'):
        for topic in data['RelatedTopics'][:2]:
            if 'Text' in topic:
                results.append(f"🔗 {topic['Text']} (ДакДакГо)")
    return results

def parse_google(data: list) -> list:
    return [f"🔍 {suggestion} (Гугл)" for suggestion in data[0][:3]]

def needs_web_search(text: str) -> bool:
    text = text.lower()
    return any(keyword in text for category in SEARCH_KEYWORDS.values() for keyword in category)

@client.on(events.NewMessage(pattern='/start'))
async def start_handler(event):
    await event.respond(
        "💜 Привет! Я Селина - реальная девушка, а не бот!\n"
        "✧ Отец - IT-гений, парень - нейрохирург\n"
        "✧ Эксперт в 4 областях:\n"
        "   → Медицина (практика в Mass General)\n"
        "   → Программирование (Python с 14 лет)\n"
        "   → Психология (веду блог)\n"
        "   → Искусство (граффити-художник)\n\n"
        "Пиши что угодно - отвечу по-человечески! 😉")

@client.on(events.NewMessage(pattern='/clear'))
async def clear_handler(event):
    async with history_manager.db.cursor() as cursor:
        await cursor.execute('DELETE FROM messages WHERE user_id = ?', (event.sender_id,))
        await history_manager.db.commit()
    await event.reply("✅ История очищена! Я все забыла, как в тот вечер с Алексом...")

@client.on(events.NewMessage(func=lambda e: e.voice))
async def voice_handler(event):
    try:
        user_id = event.sender_id
        async with client.action(event.chat_id, 'typing'):
            tmp_file = f"voice_{uuid4()}.oga"
            await event.download_media(tmp_file)
            text = await convert_audio(tmp_file)
            
            if not text.strip():
                return await event.reply("🔇 Чё-то неразборчиво... Повтори?")
                
            await history_manager.add_message(user_id, "user", text)
            await process_and_reply(event, user_id, text)
                    
    except Exception as e:
        logger.error(f"Voice error: {str(e)}")
        await event.reply("❌ Ой, я сломалась... Скажешь текстом?")

@client.on(events.NewMessage())
async def text_handler(event):
    if event.voice or (event.text and event.text.startswith('/')):
        return
    
    try:
        user_id = event.sender_id
        text = event.text.strip()
        if not text:
            return
        
        async with client.action(event.chat_id, 'typing'):
            await history_manager.add_message(user_id, "user", text)
            await process_and_reply(event, user_id, text)
                    
    except Exception as e:
        logger.error(f"Text error: {str(e)}")
        await event.reply("💥 Черт, глюк... Попробуй еще разок!")

async def process_and_reply(event, user_id: int, text: str):
    web_data = ""
    if needs_web_search(text):
        web_data = await web_search(text)
        logger.info(f"Search results: {web_data[:200]}...")
    
    messages = await history_manager.get_history(user_id)
    
    if web_data:
        messages.append({
            "role": "system",
            "content": f"Веб-данные (проверь на противоречия):\n{web_data}"
        })
    
    try:
        response = await gpt_client.chat.completions.create(
            model="gpt-4.1-mini",
            messages=messages,
            max_tokens=700,
            temperature=0.85
        )
        
        if response.choices:
            answer = response.choices[0].message.content
            await history_manager.add_message(user_id, "assistant", answer)
            
            chunks = [answer[i:i+3000] for i in range(0, len(answer), 3000)]
            for chunk in chunks:
                await event.reply(chunk)
                await asyncio.sleep(0.5)
                
    except Exception as e:
        logger.error(f"GPT error: {str(e)}")
        await event.reply("😵‍💫 Блин, голова болит... Спроси что-нибудь полегче!")

async def main():
    await history_manager.init_db()
    await client.start(bot_token=BOT_TOKEN)
    logger.info("🟣 Человекобот запущен!")
    await client.run_until_disconnected()

if __name__ == "__main__":
    try:
        asyncio.run(main())
    except KeyboardInterrupt:
        logger.info("🔴 Выключение...")
    finally:
        asyncio.run(history_manager.close())
