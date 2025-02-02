# Скрипт управления каталогами CM
## Описание
- Скрипт предназначен для автоматизированного управления структурой каталогов системы CM. Он поддерживает два режима работы:

### Создание новой структуры каталогов
### Миграция существующих данных с сохранением структуры
## Требования
- Bash (версия 4.0 или выше)
- Стандартные утилиты Unix: awk, sed, grep, mkdir, ln, mv, cp
- Достаточно прав для создания и модификации директорий в указанных путях
- Структура каталогов
``` /u01/CM/
├── cm-data/
│   └── attachments/       # Исходная директория
├── cm-2025/              # Целевая директория
├── tmp_manager/          # Временные файлы
├── script.log            # Лог выполнения
└── tmp_lock.lock         # Файл блокировки
```
## Установка
- Скопируйте скрипт в необходимую директорию
- Установите права на выполнение:
``` bash

chmod +x script.sh
```

## Использование
- Базовый запуск (создание новой структуры)
```bash

./script.sh
Запуск в режиме миграции
bash

./script.sh -m
или

bash

./script.sh --migrate
Показать справку
bash

./script.sh -h
или

bash

./script.sh --help
```

## Конфигурация
# Основные настройки находятся в начале скрипта:

``` bash

# Базовые пути
source_dir="/u01/CM/cm-data/attachments"
dest_directory="/u01/CM/cm-2025"
god="2025"
```
```
# Дополнительные настройки
TEMP_DIR="/u01/CM/tmp_manager"
LOCK_FILE="/u01/CM/tmp_lock.lock"
LOG_FILE="/u01/CM/script.log"
LOG_RETENTION_DAYS=30
```
## Функциональность
# Основные возможности
- Создание структуры каталогов для нового года
- Создание символических ссылок
- Миграция существующих данных с бэкапом
- Ротация логов
- Блокировка параллельного запуска
- Очистка временных файлов
- Режим  миграции
### В режиме миграции скрипт:

- Создает резервную копию существующих данных
- Переносит все файлы с сохранением структуры подкаталогов
- Обновляет символические ссылки
- Проверяет целостность перенесенных данных
- В случае ошибки восстанавливает данные из резервной копии
### Логирование
- Все действия записываются в лог-файл
- Автоматическая ротация логов при достижении 100MB
- Настраиваемый период хранения логов
- Цветной вывод в консоль для удобства отслеживания
- Обработка ошибок
- Проверка наличия необходимых утилит
- Проверка существования требуемых директорий
- Защита от параллельного запуска
- Автоматическое восстановление в случае ошибок миграции
- Очистка временных файлов при завершении
### Безопасность
- Блокировка параллельного запуска
- Создание резервных копий перед миграцией
- Проверка прав доступа
- Валидация количества перенесенных файлов
### Устранение неполадок
- Скрипт не запускается
- Проверьте права на выполнение
- Убедитесь в наличии всех необходимых утилит
- Проверьте наличие файла блокировки
### Ошибки миграции
- Проверьте права доступа к директориям
- Убедитесь в наличии свободного места
- Проверьте лог-файл для деталей ошибки
- Очистка блокировки
### Если скрипт аварийно завершился:

```bash

rm -f /u01/CM/tmp_lock.lock
```
### Поддержка
- При возникновении проблем:

- Проверьте лог-файл
- Убедитесь в корректности настроек путей
- Проверьте права доступа к директориям
