#!/bin/bash
###########################################
#ПОЛЬЗОВАТЕЛЬСКИЕ НАСТРОЙКИ
###########################################

# Базовые пути
source_dir="/u01/CM/cm-data/attachments"
dest_directory="/u01/CM/cm-2025"
god="2025"

# Дополнительные настройки
TEMP_DIR="/u01/CM/tmp_manager"              # Директория для временных файлов
LOCK_FILE="/u01/CM/tmp_lock.lock"           # Файл блокировки
LOG_FILE="/u01/CM/script.log"               # Файл для логирования
LOG_RETENTION_DAYS=30                       # Срок хранения логов в днях
MIGRATE_MODE=false                          # Режим миграции по умолчанию выключен

# Цвета для консольного вывода
NOCOLOR='\033[0m'
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
GRAY='\033[0;90m'

# Функция вывода помощи
show_help() {
    echo -e "${BLUE}Использование: $0 [-m|--migrate] [-h|--help]"
    echo "Опции:"
    echo "  -m, --migrate    Включить режим миграции (перенос существующих файлов)"
    echo -e "  -h, --help       Показать эту справку${NOCOLOR}"
    exit 0
}

# Обработка параметров командной строки
while [[ $# -gt 0 ]]; do
    case $1 in
        -m|--migrate)
            MIGRATE_MODE=true
            shift
            ;;
        -h|--help)
            show_help
            ;;
        *)
            echo -e "${RED}Неизвестный параметр: $1${NOCOLOR}"
            show_help
            ;;
    esac
done

# Функция логирования
log() {
    local level=$1
    local message=$2
    local timestamp=$(date '+%Y-%m-%d %H:%M:%S')
    local log_message="[$timestamp] [$level] $message"

    # Запись в файл (без цветов)
    echo "$log_message" >> "$LOG_FILE"

    # Вывод в консоль с цветами
    case $level in
        "ERROR")
            echo -e "${RED}$log_message${NOCOLOR}"
            ;;
        "WARNING")
            echo -e "${YELLOW}$log_message${NOCOLOR}"
            ;;
        "INFO")
            echo -e "${GREEN}$log_message${NOCOLOR}"
            ;;
        "DEBUG")
            echo -e "${GRAY}$log_message${NOCOLOR}"
            ;;
        *)
            echo -e "${BLUE}$log_message${NOCOLOR}"
            ;;
    esac
}

# Ротация логов
rotate_logs() {
    if [ -f "$LOG_FILE" ]; then
        local file_size=$(du -m "$LOG_FILE" | cut -f1)
        if [ "$file_size" -gt 100 ]; then
            local backup_name="${LOG_FILE}.$(date '+%Y%m%d-%H%M%S')"
            mv "$LOG_FILE" "$backup_name"
            gzip "$backup_name"
            log "INFO" "Лог-файл ротирован: $backup_name.gz"
            touch "$LOG_FILE"
            log "INFO" "Создан новый лог-файл"
        fi
    fi

    # Удаление старых логов
    local deleted_count=0
    while IFS= read -r file; do
        rm "$file"
        ((deleted_count++))
    done < <(find "$(dirname "$LOG_FILE")" -name "$(basename "$LOG_FILE")*" -type f -mtime +$LOG_RETENTION_DAYS)

    if [ $deleted_count -gt 0 ]; then
        log "INFO" "Удалено старых лог-файлов: $deleted_count"
    fi
}

set_lock() {
    if [ -f "$LOCK_FILE" ]; then
        local pid=$(cat "$LOCK_FILE")
        if kill -0 "$pid" 2>/dev/null; then
            log "ERROR" "Скрипт уже запущен (PID: $pid)"
            exit 1
        fi
    fi
    echo $$ > "$LOCK_FILE"
    log "INFO" "Установлена блокировка (PID: $$)"
}

remove_lock() {
    rm -f "$LOCK_FILE"
    log "INFO" "Блокировка снята"
}

cleanup() {
    log "INFO" "Начало очистки временных файлов"
    remove_lock
    if [ -d "$TEMP_DIR" ]; then
        rm -rf "$TEMP_DIR"/*
        log "INFO" "Временная директория очищена"
    fi
    if [ -n "$TEMP_FILE" ] && [ -f "$TEMP_FILE" ]; then
        rm -f "$TEMP_FILE"
        log "INFO" "Временный файл удален"
    fi
}

# Функция для миграции существующих данных
migrate_existing_data() {
    local key=$1
    local old_dir="$dest_directory/$key/$god"
    local backup_dir="$dest_directory/$key/${god}_OLD_$(date '+%Y%m%d_%H%M%S')"

    if [ -d "$old_dir" ]; then
        log "INFO" "Начало миграции данных для $key/$god"

        # Создаем бэкап с сохранением всех прав и атрибутов
        if cp -a "$old_dir" "$backup_dir"; then
            log "INFO" "Создан бэкап директории: $backup_dir"

            # Очищаем старую директорию
            rm -rf "$old_dir"
            mkdir -p "$old_dir"

            # Копируем все содержимое с сохранением структуры и прав
            if cp -a "$backup_dir"/* "$old_dir/" 2>/dev/null; then
                log "INFO" "Файлы успешно перенесены из $backup_dir в $old_dir"

                # Проверяем и обновляем символическую ссылку
                if [ -L "$source_dir/$key/$god" ]; then
                    rm -f "$source_dir/$key/$god"
                fi
                ln -sf "$old_dir" "$source_dir/$key/$god"

                # Проверяем успешность копирования
                local src_count=$(find "$backup_dir" -type f | wc -l)
                local dst_count=$(find "$old_dir" -type f | wc -l)

                if [ "$src_count" -eq "$dst_count" ]; then
                    log "INFO" "Проверка успешна: скопировано $src_count файлов"
                    return 0
                else
                    log "ERROR" "Количество файлов не совпадает: исходных - $src_count, скопированных - $dst_count"
                    # Восстанавливаем из бэкапа в случае ошибки
                    rm -rf "$old_dir"
                    mv "$backup_dir" "$old_dir"
                    return 1
                fi
            else
                log "ERROR" "Ошибка при копировании файлов из $backup_dir"
                # Восстанавливаем из бэкапа в случае ошибки
                rm -rf "$old_dir"
                mv "$backup_dir" "$old_dir"
                return 1
            fi
        else
            log "ERROR" "Не удалось создать бэкап директории $old_dir"
            return 1
        fi
    fi
    return 0
}

copy_att() {
    log "INFO" "Начало копирования списка директорий"
    local count=0
    ls -la "$source_dir" | awk {'print $9'} | grep -v 20 | sed 's/ //g' | sed 's/\./ /g; s/>/ /g' | sed '/^[[:space:]]*$/d' > "$TEMP_DIR/source_dir.temp"
    count=$(wc -l < "$TEMP_DIR/source_dir.temp")
    log "INFO" "Найдено $count директорий для обработки"
}

mk_att() {
    log "INFO" "Начало создания структуры директорий"
    local success_count=0
    local error_count=0
    local migration_count=0

    while IFS='=' read -r key; do
        local process_directory=true

        if $MIGRATE_MODE; then
            if [ -d "$dest_directory/$key/$god" ]; then
                if migrate_existing_data "$key"; then
                    ((migration_count++))
                else
                    ((error_count++))
                    process_directory=false
                fi
            fi
        fi

        if $process_directory; then
            if mkdir -p "$dest_directory/$key/$god" 2>/dev/null; then
                if ln -sf "$dest_directory/$key/$god" "$source_dir/$key/$god" 2>/dev/null; then
                    ((success_count++))
                    log "DEBUG" "Создана директория и символическая ссылка для $key/$god"
                else
                    ((error_count++))
                    log "ERROR" "Ошибка создания символической ссылки для $key/$god"
                fi
            else
                ((error_count++))
                log "ERROR" "Ошибка создания директории для $key/$god"
            fi
        fi
    done < "$TEMP_DIR/source_dir.temp"

    log "INFO" "Обработка завершена. Успешно: $success_count, Миграций: $migration_count, Ошибок: $error_count"
}

check_dirs() {
    log "INFO" "Проверка необходимых директорий"
    local error=0

    if [ ! -d "$source_dir" ]; then
        log "ERROR" "Исходная директория $source_dir не существует"
        error=1
    fi

    if [ ! -d "$dest_directory" ]; then
        log "ERROR" "Целевая директория $dest_directory не существует"
        error=1
    fi

    if [ ! -d "$TEMP_DIR" ]; then
        if mkdir -p "$TEMP_DIR" 2>/dev/null; then
            log "INFO" "Создана временная директория $TEMP_DIR"
        else
            log "ERROR" "Не удалось создать временную директорию $TEMP_DIR"
            error=1
        fi
    fi

    if [ $error -eq 1 ]; then
        exit 1
    fi
}

show_banner() {
    echo -e "${BLUE}"
    echo "╔════════════════════════════════════════╗"
    echo "║       Управление каталогами CM         ║"
    echo "║        $(date '+%Y-%m-%d %H:%M:%S')        ║"
    if $MIGRATE_MODE; then
        echo "║           Режим: МИГРАЦИЯ             ║"
    else
        echo "║           Режим: СОЗДАНИЕ             ║"
    fi
    echo "╚════════════════════════════════════════╝"
    echo -e "${NOCOLOR}"
}

main() {
    show_banner
    log "INFO" "Начало выполнения скрипта"
    if $MIGRATE_MODE; then
        log "INFO" "Запущен в режиме миграции"
    fi

    rotate_logs
    set_lock
    trap cleanup EXIT

    log "INFO" "Проверка наличия необходимых утилит"
    for cmd in awk sed grep mkdir ln mv cp; do
        if ! command -v $cmd &> /dev/null; then
            log "ERROR" "Требуемая утилита $cmd не найдена"
            exit 1
        fi
    done

    check_dirs
    copy_att
    mk_att

    echo -e "\n${BLUE}╔════════════════════════════════════════╗"
    echo "║            ИТОГИ ВЫПОЛНЕНИЯ           ║"
    echo "╚════════════════════════════════════════╝${NOCOLOR}"

    log "INFO" "Скрипт успешно завершен"
}

# Запуск скрипта
main
