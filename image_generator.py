import json
import time
import requests
import os
import logging
from uuid import uuid4
from os import getenv
import base64
import re
import asyncio
from PIL import Image
import tempfile
import atexit
import shutil

# Настройка логирования
logging.basicConfig(level=logging.INFO)
logger = logging.getLogger('FusionBrain_Generator')

class ImageGenerator:
    def __init__(self, api_key=None, secret_key=None):
        """
        Инициализирует генератор изображений на основе Kandinsky 3.1.
        
        Args:
            api_key: API ключ FusionBrain. Если не указан, берется из переменной окружения
            secret_key: Secret ключ FusionBrain. Если не указан, берется из переменной окружения
        """
        self.URL = 'https://api-key.fusionbrain.ai/'
        self.api_key = api_key or getenv('FUSIONBRAIN_API_KEY')
        self.secret_key = secret_key or getenv('FUSIONBRAIN_SECRET_KEY')
        
        if not self.api_key or not self.secret_key:
            logger.warning("⚠️ FUSIONBRAIN_API_KEY или FUSIONBRAIN_SECRET_KEY не заданы! Генерация будет недоступна.")
        
        self.AUTH_HEADERS = {
            'X-Key': f'Key {self.api_key}',
            'X-Secret': f'Secret {self.secret_key}'
        }
        
        # ID модели Kandinsky 3.1
        self.pipeline_id = None
        
        # Доступные стили (для совместимости с интерфейсом)
        self.models = {
            "kandinsky": "Kandinsky 3.1",
            "anime": "Kandinsky 3.1 (стиль ANIME)",
            "pointillism": "Kandinsky 3.1 (стиль POINTILLISM)",
            "oil": "Kandinsky 3.1 (стиль OIL)"
        }
        
        # Модель по умолчанию
        self.default_model = "kandinsky"
        
        # Создаем временную директорию для изображений
        self.temp_dir = tempfile.TemporaryDirectory(prefix='kandinsky_images_')
        logger.info(f"Создана временная директория для изображений: {self.temp_dir.name}")
        
        # Регистрируем функцию очистки при завершении программы
        atexit.register(self.cleanup_temp_files)
        
    def cleanup_temp_files(self):
        """Очищает временную директорию при завершении работы."""
        if hasattr(self, 'temp_dir') and self.temp_dir:
            try:
                logger.info(f"Очистка временной директории: {self.temp_dir.name}")
                self.temp_dir.cleanup()
                logger.info("Временная директория успешно очищена")
            except Exception as e:
                logger.error(f"Ошибка при очистке временной директории: {str(e)}")
            
    async def initialize(self):
        """Асинхронно инициализирует модель при первом запуске."""
        if not self.pipeline_id:
            self.pipeline_id = await self._get_pipeline()
            
    async def _get_pipeline(self):
        """Получает pipeline_id для Kandinsky 3.1."""
        try:
            response = requests.get(self.URL + 'key/api/v1/pipelines', headers=self.AUTH_HEADERS)
            if response.status_code == 200:
                data = response.json()
                if isinstance(data, list) and data:
                    # Берем первую доступную модель (Kandinsky 3.1)
                    pipeline_id = data[0]['id']
                    logger.info(f'Pipeline ID получен: {pipeline_id}')
                    return pipeline_id
                else:
                    logger.error(f'Ошибка формата ответа: {data}')
            else:
                logger.error(f'Ошибка при получении pipeline_id: {response.status_code} {response.text}')
            return None
        except Exception as e:
            logger.error(f'Исключение при получении pipeline_id: {str(e)}')
            return None
            
    async def enhance_prompt(self, base_prompt, client):
        """
        Улучшает промт с помощью GPT для лучших результатов генерации.
        
        Args:
            base_prompt (str): Исходный промт пользователя
            client: Клиент для вызова GPT API
            
        Returns:
            str: Улучшенный промт
        """
        try:
            # Kandinsky хорошо работает с русскими промтами, поэтому перевод не требуется
            enhance_prompt = f"""
            Улучши этот промт для генерации изображения, добавив художественные детали, 
            стиль, освещение, общую атмосферу. Сохрани основную идею, но сделай описание 
            более визуальным и подробным. Не превышай 100 слов в ответе.
            
            Оригинальный промт: {base_prompt}
            
            Улучшенный промт (только текст промта, без пояснений):
            """
            
            response = await client.chat.completions.create(
                model="gpt-4.1-mini",
                messages=[{"role": "user", "content": enhance_prompt}],
                max_tokens=200,
                temperature=0.7
            )
            
            enhanced_prompt = response.choices[0].message.content.strip()
            logger.info(f"Промт улучшен: '{enhanced_prompt[:50]}...'")
            return enhanced_prompt
        except Exception as e:
            logger.error(f"Ошибка при улучшении промта: {str(e)}")
            return base_prompt  # Возвращаем исходный промт в случае ошибки
            
    async def generate_image(self, prompt, model_key=None):
        """
        Генерирует изображение через FusionBrain API (Kandinsky 3.1).
        
        Args:
            prompt (str): Промт для генерации изображения
            model_key (str, optional): Ключ модели/стиля. По умолчанию используется self.default_model.
            
        Returns:
            tuple: (путь к сгенерированному изображению или None, сообщение об ошибке или None)
        """
        # Проверяем наличие ключей API
        if not self.api_key or not self.secret_key:
            logger.error("API и Secret ключи FusionBrain не настроены!")
            return None, "Ошибка: ключи FusionBrain API не настроены."
            
        # Инициализируем pipeline_id при необходимости
        if not self.pipeline_id:
            await self.initialize()
            if not self.pipeline_id:
                return None, "Ошибка: не удалось получить pipeline_id."
                
        # Определяем стиль в зависимости от выбранной модели
        style = None
        if model_key == "anime":
            style = "ANIME"
        elif model_key == "pointillism":
            style = "POINTILLISM"
        elif model_key == "oil":
            style = "OIL"
            
        # Настройки генерации
        params = {
            "type": "GENERATE",
            "numImages": 1,
            "width": 1024,
            "height": 1024,
            "generateParams": {
                "query": prompt
            }
        }
        
        # Добавляем стиль, если выбран
        if style:
            params["style"] = style
        
        # Негативный промпт для улучшения качества
        params["negativePromptDecoder"] = "низкое качество, размытие, искажения, деформация, плохие пропорции"
        
        data = {
            'pipeline_id': (None, self.pipeline_id),
            'params': (None, json.dumps(params), 'application/json')
        }
        
        try:
            # Отправляем запрос на генерацию
            logger.info(f"Отправляю запрос на генерацию с промтом: '{prompt[:50]}...'")
            response = requests.post(
                self.URL + 'key/api/v1/pipeline/run', 
                headers=self.AUTH_HEADERS, 
                files=data
            )
            
            if response.status_code in [200, 201]:  # Оба кода означают успешный запрос
                data = response.json()
                uuid = data.get('uuid')
                
                if not uuid:
                    logger.error(f"Ошибка: отсутствует UUID в ответе: {data}")
                    return None, "Ошибка: не получен UUID задания."
                    
                logger.info(f"Запрос на генерацию отправлен, UUID: {uuid}")
                
                # Получаем результат генерации
                image_files = await self._check_generation(uuid)
                
                if not image_files:
                    return None, "Ошибка: не удалось получить результат генерации."
                    
                # Сохраняем изображение во временную директорию
                temp_image_name = f"generated_image_{uuid4()}.png"
                temp_image_path = os.path.join(self.temp_dir.name, temp_image_name)
                
                # В ответе может быть URL или base64
                if image_files[0].startswith("http"):
                    # Скачиваем изображение по URL
                    img_response = requests.get(image_files[0])
                    if img_response.status_code == 200:
                        with open(temp_image_path, "wb") as img_file:
                            img_file.write(img_response.content)
                else:
                    # Декодируем base64
                    try:
                        # Удаляем префикс data:image/... если есть
                        base64_data = image_files[0]
                        if "base64," in base64_data:
                            base64_data = base64_data.split("base64,")[1]
                            
                        image_data = base64.b64decode(base64_data)
                        with open(temp_image_path, "wb") as img_file:
                            img_file.write(image_data)
                    except Exception as e:
                        logger.error(f"Ошибка декодирования base64: {str(e)}")
                        return None, f"Ошибка декодирования изображения: {str(e)}"
                
                # Проверяем, что файл действительно является изображением
                try:
                    with Image.open(temp_image_path) as img:
                        img_width, img_height = img.size
                        logger.info(f"Изображение успешно сгенерировано: {temp_image_path} ({img_width}x{img_height})")
                except Exception as img_err:
                    logger.error(f"Файл не является изображением: {str(img_err)}")
                    if os.path.exists(temp_image_path):
                        os.remove(temp_image_path)
                    return None, "Получены данные, но они не являются корректным изображением."
                
                return temp_image_path, None
            else:
                error_text = response.text
                logger.error(f"Ошибка генерации изображения: {response.status_code}, {error_text}")
                return None, f"Ошибка генерации: {response.status_code}, {error_text[:100]}"
                
        except Exception as e:
            logger.error(f"Исключение при генерации изображения: {str(e)}")
            return None, f"Ошибка соединения: {str(e)}"
    
    async def _check_generation(self, request_id, attempts=15, delay=2):
        """
        Проверяет статус генерации и возвращает результат.
        
        Args:
            request_id (str): UUID задания
            attempts (int): Количество попыток проверки
            delay (int): Задержка между попытками в секундах
            
        Returns:
            list: Список файлов с результатами или None при ошибке
        """
        logger.info(f"Ожидание результата для задания {request_id}")
        
        for attempt in range(attempts):
            try:
                response = requests.get(
                    self.URL + f'key/api/v1/pipeline/status/{request_id}', 
                    headers=self.AUTH_HEADERS
                )
                
                if response.status_code == 200:
                    data = response.json()
                    status = data.get('status')
                    
                    if status == 'DONE':
                        files = data.get('result', {}).get('files', [])
                        logger.info(f"Генерация завершена, получены файлы: {len(files)} шт.")
                        return files
                    elif status == 'ERROR':
                        error_desc = data.get('errorDescription', 'Неизвестная ошибка')
                        logger.error(f"Ошибка генерации: {error_desc}")
                        return None
                    else:
                        logger.info(f"Статус генерации: {status}, попытка {attempt+1}/{attempts}")
                else:
                    logger.error(f"Ошибка при проверке статуса: {response.status_code} {response.text}")
                    
            except Exception as e:
                logger.error(f"Исключение при проверке статуса: {str(e)}")
                
            # Задержка перед следующей попыткой
            await asyncio.sleep(delay)
            
        logger.error(f"Превышено количество попыток проверки статуса для {request_id}")
        return None
        
    async def generate_with_fallback(self, prompt):
        """
        Генерация с автоматическим переключением моделей при ошибках.
        Для API FusionBrain используется только одна модель, но можно
        пробовать разные стили.
        
        Args:
            prompt (str): Промт для генерации изображения
            
        Returns:
            tuple: (путь к сгенерированному изображению или None, сообщение об ошибке или None)
        """
        # Пробуем с моделью по умолчанию
        image_path, error = await self.generate_image(prompt, self.default_model)
        if image_path:
            return image_path, None
            
        # Если не получилось, пробуем другие стили
        logger.warning(f"Модель {self.default_model} вернула ошибку: {error}. Пробуем другие стили.")
        
        for model_key in ["anime", "pointillism", "oil"]:
            if model_key != self.default_model:
                logger.info(f"Пробуем стиль: {model_key}")
                image_path, error = await self.generate_image(prompt, model_key)
                if image_path:
                    return image_path, None
                    
        return None, "Все доступные стили вернули ошибку. Сервис временно недоступен."
        
    def get_models_info(self):
        """
        Возвращает информацию о доступных моделях (для совместимости с интерфейсом).
        
        Returns:
            list: Список словарей с информацией о моделях
        """
        return [
            {"key": "kandinsky", "name": "Kandinsky 3.1", "desc": "Стандартный стиль"},
            {"key": "anime", "name": "Kandinsky Anime", "desc": "Аниме-стиль"},
            {"key": "pointillism", "name": "Kandinsky Pointillism", "desc": "Пуантилизм"},
            {"key": "oil", "name": "Kandinsky Oil", "desc": "Масляная живопись"}
        ]
    
    def handle_b64_image(self, b64_string):
        """
        Обрабатывает изображение в формате base64.
        
        Args:
            b64_string (str): Строка base64
            
        Returns:
            str: Путь к сохраненному изображению
        """
        try:
            image_data = base64.b64decode(b64_string)
            temp_image_name = f"generated_image_{uuid4()}.png"
            temp_image_path = os.path.join(self.temp_dir.name, temp_image_name)
            
            # Сохраняем декодированное изображение
            with open(temp_image_path, "wb") as img_file:
                img_file.write(image_data)
            
            return temp_image_path
        except Exception as e:
            logger.error(f"Ошибка обработки base64 изображения: {str(e)}")
            return None

    def cleanup_old_images(self, max_age_minutes=30):
        """
        Очищает старые изображения из временной директории.
        
        Args:
            max_age_minutes (int): Максимальный возраст файла в минутах
        """
        try:
            now = time.time()
            count = 0
            for filename in os.listdir(self.temp_dir.name):
                file_path = os.path.join(self.temp_dir.name, filename)
                if os.path.isfile(file_path) and filename.startswith("generated_image_"):
                    # Проверяем возраст файла
                    file_age_minutes = (now - os.path.getmtime(file_path)) / 60
                    if file_age_minutes > max_age_minutes:
                        os.remove(file_path)
                        count += 1
            if count > 0:
                logger.info(f"Очищено {count} старых изображений")
        except Exception as e:
            logger.error(f"Ошибка при очистке старых изображений: {str(e)}")
