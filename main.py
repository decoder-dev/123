from telethon import TelegramClient, events, types
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
import json
import re
import requests  # Добавлено для решения проблемы с URL too long

try:
    import docx
    DOCX_SUPPORT = True
except ImportError:
    DOCX_SUPPORT = False

load_dotenv()

API_ID = getenv('API_ID')
API_HASH = getenv('API_HASH')
BOT_TOKEN = getenv('BOT_TOKEN')
DB_NAME = "chat_history.db"
HISTORY_LIMIT = 30

# Kandinsky API 3.1 ключи
KANDINSKY_KEY = "61D6772E0CEFE7C444873DA5DC894B81"
KANDINSKY_SECRET = "D1481698489156C002C4225D6DC112BB"
KANDINSKY_API_URL = "https://api-key.fusionbrain.ai/"

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

★ Личная жизнь:
→ Вместе с Алексом 2 года (познакомились в морге)
→ Отец-разработчик (часто шутит: "Он бинарный папка")... → Учится в MIT на нейрохирурга
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
        await self.db.execute('''CREATE TABLE IF NOT EXISTS file_sessions (
            user_id INTEGER PRIMARY KEY,
            file_message_id INTEGER,
            file_name TEXT,
            file_content TEXT,
            assistant_reply TEXT,
            timestamp DATETIME DEFAULT CURRENT_TIMESTAMP
        )''')
        await self.db.commit()

    async def get_history(self, user_id: int) -> list:
        async with self.db.cursor() as cursor:
            await cursor.execute('''SELECT role, content FROM messages 
                                  WHERE user_id = ? 
                                  ORDER BY timestamp ASC 
                                  LIMIT ?''', (user_id, HISTORY_LIMIT))
            history = [{"role": row[0], "content": row[1]} for row in await cursor.fetchall()]
            # Проверяем, есть ли активная сессия по файлу
            await cursor.execute('''SELECT file_name, file_content, assistant_reply FROM file_sessions WHERE user_id = ?''', (user_id,))
            row = await cursor.fetchone()
            if row:
                file_name, file_content, assistant_reply = row
                file_block = [
                    {"role": "user", "content": f"Содержимое файла {file_name}:\n{file_content}"},
                    {"role": "assistant", "content": f"Ответ на файл {file_name}:\n{assistant_reply}"}
                ]
                return [{"role": "system", "content": SYSTEM_PROMPT}] + file_block + history
            else:
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

    async def set_file_session(self, user_id: int, file_name: str, file_content: str, assistant_reply: str):
        async with self.db.cursor() as cursor:
            await cursor.execute('''INSERT OR REPLACE INTO file_sessions (user_id, file_name, file_content, assistant_reply, timestamp)
                                    VALUES (?, ?, ?, ?, CURRENT_TIMESTAMP)''',
                                 (user_id, file_name, file_content, assistant_reply))
            await self.db.commit()

    async def clear_file_session(self, user_id: int):
        async with self.db.cursor() as cursor:
            await cursor.execute('DELETE FROM file_sessions WHERE user_id = ?', (user_id,))
            await self.db.commit()

    async def close(self):
        await self.db.close()

class FactChecker:
    def __init__(self):
        self.cache = {}

    async def check_facts(self, text: str, search_results: str) -> dict:
        cache_key = text + search_results
        if cache_key in self.cache:
            return self.cache[cache_key]
        try:
            fact_check_prompt = f"""
            Проанализируй следующую информацию и оцени достоверность фактов:
            
            Текст для проверки: {text}
            
            Данные из поиска:
            {search_results}
            
            Для каждого факта укажи:
            1. Сам факт
            2. Соответствие данным (подтверждается/противоречит/недостаточно данных)
            3. Источник, подтверждающий или опровергающий факт
            
            Верни ответ в JSON:
            {{
                "facts": [
                    {{
                        "fact": "текст факта",
                        "status": "confirmed/contradicted/insufficient",
                        "confidence": 0.XX,
                        "source": "источник"
                    }}
                ],
                "overall_reliability": 0.XX
            }}
            """
            response = await gpt_client.chat.completions.create(
                model="gpt-4.1-mini",
                messages=[{"role": "user", "content": fact_check_prompt}],
                max_tokens=500,
                temperature=0.3
            )
            if response.choices:
                result = response.choices[0].message.content
                try:
                    fact_check_result = json.loads(result)
                    self.cache[cache_key] = fact_check_result
                    return fact_check_result
                except Exception as e:
                    logger.error(f"Failed to parse fact check JSON: {str(e)}")
            return {"facts": [], "overall_reliability": 0.5}
        except Exception as e:
            logger.error(f"Fact checking error: {str(e)}")
            return {
                "facts": [],
                "overall_reliability": 0.5
            }

history_manager = ChatHistoryManager()
fact_checker = FactChecker()
client = TelegramClient('telethon_session', int(API_ID), API_HASH)
gpt_client = AsyncClient(provider=RetryProvider([
    ChatGptEs, DDG, Jmuz, Liaobots, OIVSCode, Pizzagpt, PollinationsAI
], shuffle=True))

# --- Kandinsky 3.1 интеграция ---
async def get_pipeline_id():
    headers = {
        "X-Key": f"Key {KANDINSKY_KEY}",
        "X-Secret": f"Secret {KANDINSKY_SECRET}"
    }
    async with HTTPXClient() as client:
        resp = await client.get(KANDINSKY_API_URL + "key/api/v1/pipelines", headers=headers)
        resp.raise_for_status()
        data = resp.json()
        # Важно: проверяем, что id - это строка или число, а не список
        if isinstance(data, dict) and 'id' in data:
            return data['id']
        elif isinstance(data, list) and len(data) > 0 and 'id' in data[0]:
            return data[0]['id']
        else:
            raise ValueError(f"Неожиданный формат ответа: {data}")

async def generate_kandinsky_image(prompt, pipeline_id):
    headers = {
        "X-Key": f"Key {KANDINSKY_KEY}",
        "X-Secret": f"Secret {KANDINSKY_SECRET}"
    }
    params = {
        "type": "GENERATE",
        "numImages": 1,
        "width": 1024,
        "height": 1024,
        "generateParams": {
            "query": prompt
        }
    }
    files = {
        'pipeline_id': (None, pipeline_id),
        'params': (None, json.dumps(params), 'application/json')
    }
    async with HTTPXClient() as client:
        resp = await client.post(KANDINSKY_API_URL + "key/api/v1/pipeline/run", headers=headers, files=files)
        resp.raise_for_status()
        data = resp.json()
        return data['uuid']

async def check_generation(uuid):
    headers = {
        "X-Key": f"Key {KANDINSKY_KEY}",
        "X-Secret": f"Secret {KANDINSKY_SECRET}"
    }
    async with HTTPXClient() as client:
        for _ in range(30):
            resp = await client.get(KANDINSKY_API_URL + f"key/api/v1/pipeline/status/{uuid}", headers=headers)
            resp.raise_for_status()
            data = resp.json()
            if data['status'] == 'DONE':
                # Исправлено: проверяем тип данных и используем индекс для списка
                files = data['result']['files']
                if isinstance(files, list) and len(files) > 0:
                    return files[0]  # Используем числовой индекс 0
                elif isinstance(files, dict) and '0' in files:
                    return files['0']  # Если это словарь с ключами-строками
                else:
                    logger.error(f"Неожиданный формат файлов: {files}")
                    return None
            await asyncio.sleep(2)
        raise Exception("Не удалось получить изображение (таймаут)")

# ИСПРАВЛЕННАЯ функция для отправки изображения как файла
async def send_image_from_url(event, url):
    # Создаем уникальное имя файла с uuid
    temp_file = f"kandinsky_image_{uuid4()}.png"
    try:
        # Загружаем изображение через requests с потоковой передачей
        response = requests.get(url, stream=True, timeout=60)
        response.raise_for_status()
        
        # Сохраняем локально по частям
        with open(temp_file, 'wb') as f:
            for chunk in response.iter_content(chunk_size=8192):
                f.write(chunk)
        
        # Отправляем как файл, не как ссылку
        await event.reply(file=temp_file)
        logger.info(f"Изображение успешно отправлено из файла {temp_file}")
        
    except Exception as e:
        logger.error(f"Ошибка при загрузке изображения: {str(e)}")
        await event.reply(f"Не удалось загрузить изображение: {str(e)}")
    finally:
        # Удаляем временный файл ПОСЛЕ отправки
        if os.path.exists(temp_file):
            try:
                os.remove(temp_file)
                logger.info(f"Временный файл {temp_file} удален")
            except Exception as e:
                logger.error(f"Ошибка при удалении файла {temp_file}: {str(e)}")

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
        for path in [input_path, locals().get('wav_path', None)]:
            if path and os.path.exists(path):
                try: os.remove(path)
                except: pass

async def extract_text_from_document(file_path: str, mime_type: str = None) -> str:
    try:
        if not mime_type or mime_type.startswith('text/') or mime_type.endswith('/plain'):
            try:
                with open(file_path, 'r', encoding='utf-8') as file:
                    return file.read()
            except UnicodeDecodeError:
                try:
                    with open(file_path, 'r', encoding='cp1251') as file:
                        return file.read()
                except:
                    return "Не удалось прочитать текстовый файл из-за неизвестной кодировки."
        elif mime_type == 'application/vnd.openxmlformats-officedocument.wordprocessingml.document' and DOCX_SUPPORT:
            doc = docx.Document(file_path)
            return "\n".join([para.text for para in doc.paragraphs])
        else:
            return f"Не могу прочитать файл с типом {mime_type}. Поддерживаются только текстовые файлы (.txt) и Word документы (.docx)."
    except Exception as e:
        logger.error(f"Document extraction error: {str(e)}")
        return f"Ошибка при чтении файла: {str(e)}"

async def process_document_file(event, file_name, tmp_file, mime_type):
    try:
        file_content = await extract_text_from_document(tmp_file, mime_type)
        if len(file_content) > 10000:
            file_content = file_content[:10000] + "...\n[файл слишком большой, читаю только начало]"
        if not file_content.strip():
            return await event.reply("🤔 Файл пустой или не содержит текста")
        await event.reply(f"📄 Получила твой файл {file_name}! Сейчас прочитаю...")
        user_id = event.sender_id
        await history_manager.clear_file_session(user_id)
        await history_manager.add_message(user_id, "user", f"Содержимое файла {file_name}:\n{file_content}")
        answer = await process_and_reply(event, user_id, f"Прочитай этот файл и ответь на его содержимое: {file_content}", return_answer=True)
        await history_manager.set_file_session(user_id, file_name, file_content, answer)
    except Exception as e:
        logger.error(f"Ошибка обработки документа: {str(e)}")
        await event.reply(f"📄 Не удалось обработать файл: {str(e)}")
    finally:
        if os.path.exists(tmp_file):
            try: 
                os.remove(tmp_file)
                logger.info(f"Файл {tmp_file} успешно удален")
            except Exception as e:
                logger.error(f"Ошибка при удалении файла {tmp_file}: {str(e)}")

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
            parser_func = globals().get(f"parse_{parser}")
            if parser_func:
                return parser_func(response.json())
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
    await history_manager.clear_file_session(event.sender_id)
    await event.reply("✅ История очищена! Я все забыла, как в тот вечер с Алексом...")

@client.on(events.NewMessage)
async def universal_message_handler(event):
    if event.out or (event.text and event.text.startswith('/')):
        return
    user_id = event.sender_id
    text = event.text.strip() if event.text else ""
    
    # --- Генерация картинки через Kandinsky 3.1 ---
    match = re.match(r'нарисуй\s+(.+)', text, re.IGNORECASE)
    if match:
        prompt = match.group(1)
        await event.reply("🎨 Генерирую изображение через Kandinsky 3.1...")
        try:
            pipeline_id = await get_pipeline_id()
            uuid = await generate_kandinsky_image(prompt, pipeline_id)
            image_url = await check_generation(uuid)
            if image_url:
                # Вместо отправки URL отправляем изображение как файл
                await send_image_from_url(event, image_url)
            else:
                await event.reply("Не удалось получить изображение.")
        except Exception as e:
            logger.error(f"Kandinsky error: {str(e)}")
            await event.reply(f"Ошибка генерации: {e}")
        return

    logger.info(f"Получено сообщение от {user_id}")
    try:
        if hasattr(event, 'media') and hasattr(event.media, 'document') and event.media.document.mime_type.startswith('audio/'):
            logger.info(f"Обрабатываю голосовое сообщение от {user_id}")
            async with client.action(event.chat_id, 'typing'):
                tmp_file = f"voice_{uuid4()}.oga"
                await event.download_media(tmp_file)
                text = await convert_audio(tmp_file)
                if not text.strip():
                    return await event.reply("🔇 Чё-то неразборчиво... Повтори?")
                await history_manager.add_message(user_id, "user", text)
                await process_and_reply(event, user_id, text)
        elif hasattr(event, 'media') and hasattr(event.media, 'document'):
            mime_type = event.media.document.mime_type
            logger.info(f"Обрабатываю документ от {user_id}, тип: {mime_type}")
            if mime_type.startswith('text/') or mime_type.endswith('/plain') or mime_type == 'application/vnd.openxmlformats-officedocument.wordprocessingml.document':
                file_name = "document"
                for attr in event.media.document.attributes:
                    if hasattr(attr, 'file_name'):
                        file_name = attr.file_name
                        break
                ext = os.path.splitext(file_name)[1]
                if not ext:
                    ext = '.txt' if mime_type.startswith('text/') else '.docx'
                tmp_file = f"doc_{uuid4()}{ext}"
                await event.download_media(tmp_file)
                await process_document_file(event, file_name, tmp_file, mime_type)
            else:
                await event.reply("🤨 Я пока умею читать только текстовые файлы и Word документы (.docx)")
        elif event.text:
            text = event.text.strip()
            if not text:
                return
            logger.info(f"Обрабатываю текстовое сообщение от {user_id}: {text[:50]}...")
            async with client.action(event.chat_id, 'typing'):
                await history_manager.add_message(user_id, "user", text)
                await process_and_reply(event, user_id, text)
    except Exception as e:
        logger.error(f"Ошибка обработки сообщения: {str(e)}")
        await event.reply("💥 Что-то пошло не так... Попробуй еще раз!")

async def process_and_reply(event, user_id: int, text: str, return_answer: bool = False):
    web_data = ""
    internet_query = needs_web_search(text)
    if internet_query:
        web_data = await web_search(text)
        logger.info(f"Search results: {web_data[:200]}...")
    messages = await history_manager.get_history(user_id)
    if web_data:
        messages.append({
            "role": "system",
            "content": (
                "Ответь КРАТКО и по фактам, используя только данные из поиска ниже. "
                "Не добавляй вступления, рассуждения или лишние слова. "
                "Если нет точного ответа, так и напиши.\n"
                "Веб-данные:\n" + web_data
            )
        })
    try:
        response = await gpt_client.chat.completions.create(
            model="gpt-4.1-mini",
            messages=messages,
            max_tokens=300 if web_data else 700,
            temperature=0.3 if web_data else 0.85
        )
        if response.choices:
            answer = response.choices[0].message.content.strip()
            if web_data and len(answer) > 240:
                answer = answer[:240].rsplit(' ', 1)[0] + "…"
            await history_manager.add_message(user_id, "assistant", answer)
            if web_data:
                fact_check_result = await fact_checker.check_facts(answer, web_data)
                reliability = fact_check_result.get("overall_reliability", 0.5)
                if reliability < 0.7:
                    facts = fact_check_result.get("facts", [])
                    for fact in facts:
                        if fact.get("status") == "contradicted" and fact.get("confidence", 0) > 0.6:
                            fact_text = fact.get("fact", "")
                            source = fact.get("source", "источников")
                            if fact_text in answer:
                                note = f" [По данным {source}, этот факт может быть неточным]"
                                answer = answer.replace(fact_text, fact_text + note)
            chunks = [answer[i:i+3000] for i in range(0, len(answer), 3000)]
            for chunk in chunks:
                await event.reply(chunk)
                await asyncio.sleep(0.5)
            if return_answer:
                return answer
    except Exception as e:
        logger.error(f"GPT error: {str(e)}")
        await event.reply("😵‍💫 Блин, голова болит... Спроси что-нибудь полегче!")
        if return_answer:
            return ""

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
