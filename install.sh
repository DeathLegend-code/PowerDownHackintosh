#!/bin/bash
# ─────────────────────────────────────────────────────────────
#  Power Down Hackintosh!  —  installer / uninstaller
#
#  ./install.sh                  install (interactive)
#  ./install.sh rebuild          install + compile PowerOff.m
#  ./install.sh --bin=/path/bin  install your own ready-made binary
#  ./install.sh status           show daemon state
#  ./install.sh uninstall        remove EVERYTHING this script created
#  ./install.sh ... ru|en        skip the language question
#
#  Ready-made binary: put a Mach-O file named  PowerOff  next to
#  this script (or into ./bin/). Optional: PowerOff.sha256 beside
#  it — the checksum is verified before installing.
# ─────────────────────────────────────────────────────────────
set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
LABEL="com.user.poweroff"
PLIST_PATH="$HOME/Library/LaunchAgents/$LABEL.plist"
BIN_PATH="/usr/local/bin/PowerOff"
LOG_PATH="$HOME/Library/Logs/PowerOff.log"
DOMAIN="gui/$(id -u)"
AX_URL="x-apple.systempreferences:com.apple.preference.security?Privacy_Accessibility"

# ── colors (only when output is a terminal) ──────────────────
if [ -t 1 ]; then
    B=$'\033[1m'; D=$'\033[2m'; R=$'\033[31m'; G=$'\033[32m'
    Y=$'\033[33m'; C=$'\033[36m'; N=$'\033[0m'
else
    B=""; D=""; R=""; G=""; Y=""; C=""; N=""
fi

# ── args ─────────────────────────────────────────────────────
ACTION="install"; REBUILD=0; L=""; CUSTOM_BIN=""
for a in "$@"; do
    case "$a" in
        install)          ACTION="install" ;;
        rebuild)          ACTION="install"; REBUILD=1 ;;
        uninstall)        ACTION="uninstall" ;;
        status)           ACTION="status" ;;
        --bin=*)          ACTION="install"; CUSTOM_BIN="${a#--bin=}" ;;
        ru|--lang=ru)     L="ru" ;;
        en|--lang=en)     L="en" ;;
        help|-h|--help)   ACTION="help" ;;
    esac
done

# ── translations ─────────────────────────────────────────────
t() {
    case "$L:$1" in
    en:tagline)    echo "Power button = instant shutdown (no sleep, no dialog)" ;;
    ru:tagline)    echo "Кнопка питания — мгновенное выключение (без сна и без диалогового окна)" ;;

    en:lang_q)     echo "Language / Язык" ;;
    ru:lang_q)     echo "Language / Язык" ;;

    en:no_root)    echo "Please do not run this script with sudo. Simply run ./install.sh — it will ask for your password when needed." ;;
    ru:no_root)    echo "Пожалуйста, не запускайте скрипт через sudo. Достаточно команды ./install.sh — пароль скрипт запросит сам, когда он понадобится." ;;

    en:i_title)    echo "What will be done" ;;
    ru:i_title)    echo "Что будет сделано" ;;
    en:i_1)        echo "A short press of the power button will no longer put your Mac to sleep" ;;
    ru:i_1)        echo "Короткое нажатие кнопки питания больше не будет переводить Mac в сон" ;;
    en:i_2)        echo "The PowerOff program will be installed to /usr/local/bin (ready-made, compiled from source, or your own)" ;;
    ru:i_2)        echo "Программа PowerOff будет установлена в /usr/local/bin (готовая, собранная из исходника или Ваша собственная)" ;;
    en:i_3)        echo "A LaunchAgent will start it automatically at every login" ;;
    ru:i_3)        echo "LaunchAgent будет запускать её автоматически при каждом входе в систему" ;;
    en:need_title) echo "What you will need to do" ;;
    ru:need_title) echo "Что потребуется от Вас" ;;
    en:need_1)     echo "Choose where the PowerOff binary comes from (pressing Enter selects a sensible default)" ;;
    ru:need_1)     echo "Выбрать, откуда взять файл PowerOff (можно просто нажать Enter — будет предложен подходящий вариант)" ;;
    en:need_2)     echo "Enter your Mac password when prompted (required for sudo)" ;;
    ru:need_2)     echo "Ввести пароль от Mac, когда система его запросит (он нужен для sudo)" ;;
    en:need_3)     echo "Switch on one toggle in System Settings (the script opens the right page and guides you)" ;;
    ru:need_3)     echo "Включить один переключатель в Системных настройках (скрипт откроет нужное окно и подскажет, что делать)" ;;
    en:need_4)     echo "No restart is required" ;;
    ru:need_4)     echo "Перезагрузка не потребуется" ;;
    en:go)         echo "Press Enter to begin, or Ctrl+C to cancel" ;;
    ru:go)         echo "Нажмите Enter, чтобы начать, или Ctrl+C, чтобы отменить" ;;

    en:s1)         echo "Turning off sleep on power button press" ;;
    ru:s1)         echo "Отключаем переход в сон по кнопке питания" ;;
    en:s2)         echo "Preparing the PowerOff binary" ;;
    ru:s2)         echo "Подготавливаем файл PowerOff" ;;
    en:s3)         echo "Creating the LaunchAgent (autostart)" ;;
    ru:s3)         echo "Создаём LaunchAgent (автозапуск)" ;;
    en:s4)         echo "Starting the background program" ;;
    ru:s4)         echo "Запускаем фоновую программу" ;;
    en:s5)         echo "Accessibility permission" ;;
    ru:s5)         echo "Разрешение «Универсальный доступ»" ;;

    en:bin_q)      echo "Where should the PowerOff binary come from?" ;;
    ru:bin_q)      echo "Откуда взять файл PowerOff?" ;;
    en:bin_o1)     echo "Ready-made file from this folder" ;;
    ru:bin_o1)     echo "Готовый файл из этой папки" ;;
    en:bin_n1)     echo "not found (please place a file named PowerOff next to install.sh)" ;;
    ru:bin_n1)     echo "не найден (положите файл PowerOff рядом с install.sh)" ;;
    en:bin_o2)     echo "Compile from PowerOff.m  (requires Xcode Command Line Tools)" ;;
    ru:bin_o2)     echo "Собрать из исходного кода PowerOff.m  (потребуются Xcode Command Line Tools)" ;;
    en:bin_o3)     echo "Keep the binary that is already installed" ;;
    ru:bin_o3)     echo "Оставить уже установленный файл" ;;
    en:bin_n3)     echo "nothing is installed yet" ;;
    ru:bin_n3)     echo "пока ничего не установлено" ;;
    en:bin_o4)     echo "Use my own file  (type the path or drag the file into this window)" ;;
    ru:bin_o4)     echo "Указать свой файл  (введите путь или перетащите файл в это окно)" ;;
    en:bin_choice) echo "Your choice" ;;
    ru:bin_choice) echo "Ваш выбор" ;;
    en:bin_bad)    echo "Please enter 1, 2, 3 or 4" ;;
    ru:bin_bad)    echo "Пожалуйста, введите 1, 2, 3 или 4" ;;
    en:bin_path)   echo "Path to the file (leave empty to go back to the menu): " ;;
    ru:bin_path)   echo "Путь к файлу (пустая строка — вернуться в меню): " ;;
    en:bin_nofile) echo "File not found" ;;
    ru:bin_nofile) echo "Файл не найден" ;;
    en:bin_nomacho) echo "This is not a macOS executable (Mach-O)" ;;
    ru:bin_nomacho) echo "Это не исполняемый файл macOS (Mach-O)" ;;
    en:bin_arch)   echo "The file's architecture may not match this Mac" ;;
    ru:bin_arch)   echo "Архитектура файла может не подходить для этого Mac" ;;
    en:bin_sha_ok) echo "Checksum matches PowerOff.sha256" ;;
    ru:bin_sha_ok) echo "Контрольная сумма совпала с PowerOff.sha256" ;;
    en:bin_sha_bad) echo "Checksum does not match the .sha256 file — installation of this file was cancelled" ;;
    ru:bin_sha_bad) echo "Контрольная сумма не совпадает с указанной в .sha256 — установка этого файла отменена" ;;
    en:bin_quar)   echo "Download quarantine flag removed" ;;
    ru:bin_quar)   echo "Карантинная метка скачанного файла снята" ;;
    en:bin_keep)   echo "The installed binary was left unchanged" ;;
    ru:bin_keep)   echo "Установленный файл оставлен без изменений" ;;
    en:bin_built)  echo "Compiled from PowerOff.m" ;;
    ru:bin_built)  echo "Файл собран из PowerOff.m" ;;
    en:bin_put)    echo "Installed" ;;
    ru:bin_put)    echo "Установлен" ;;
    en:no_clang)   echo "clang was not found. Please run: xcode-select --install — then start the script again." ;;
    ru:no_clang)   echo "Компилятор clang не найден. Пожалуйста, выполните в Терминале: xcode-select --install — и запустите скрипт ещё раз." ;;
    en:no_src)     echo "PowerOff.m was not found next to install.sh" ;;
    ru:no_src)     echo "Рядом с install.sh не найден файл PowerOff.m" ;;
    en:checking)   echo "Checking…" ;;
    ru:checking)   echo "Проверяем работу…" ;;

    en:plist_ok)   echo "Autostart settings written and validated" ;;
    ru:plist_ok)   echo "Настройки автозапуска записаны и проверены" ;;
    en:running)    echo "The program is running" ;;
    ru:running)    echo "Программа запущена и работает" ;;
    en:not_running) echo "The program is not running yet (this is normal until the permission is granted)" ;;
    ru:not_running) echo "Программа пока не запущена (это нормально, пока не выдано разрешение)" ;;
    en:perm_ok)    echo "The permission is already granted — nothing to do" ;;
    ru:perm_ok)    echo "Разрешение уже выдано — ничего делать не нужно" ;;

    en:perm_h)     echo "Please do the following in the window that has just opened" ;;
    ru:perm_h)     echo "Пожалуйста, выполните следующее в открывшемся окне" ;;
    en:perm_p0)    echo "Privacy & Security → Accessibility" ;;
    ru:perm_p0)    echo "Конфиденциальность и безопасность → Универсальный доступ" ;;
    en:perm_p1)    echo "Click the + button (enter your password if asked)" ;;
    ru:perm_p1)    echo "Нажмите кнопку «+» (при запросе введите пароль)" ;;
    en:perm_p2)    echo "Press Cmd+Shift+G, paste the path with Cmd+V (it is already on your clipboard), press Enter, then click Open" ;;
    ru:perm_p2)    echo "Нажмите Cmd+Shift+G, вставьте путь через Cmd+V (он уже скопирован в буфер обмена), нажмите Enter, затем «Открыть»" ;;
    en:perm_p3)    echo "Make sure the toggle next to PowerOff is switched on" ;;
    ru:perm_p3)    echo "Убедитесь, что переключатель рядом с PowerOff включён" ;;
    en:perm_ask)   echo "When you are finished, press Enter to check  [s = skip]: " ;;
    ru:perm_ask)   echo "Когда закончите, нажмите Enter для проверки  [s — пропустить]: " ;;
    en:perm_retry) echo "The program is not running yet. Please make sure the toggle is on and try again." ;;
    ru:perm_retry) echo "Программа пока не запущена. Пожалуйста, убедитесь, что переключатель включён, и повторите попытку." ;;
    en:perm_skip)  echo "Skipped. The program will start automatically within 5 seconds after you grant the permission." ;;
    ru:perm_skip)  echo "Шаг пропущен. Программа запустится автоматически в течение 5 секунд после выдачи разрешения." ;;

    en:done)       echo "DONE — the power button now shuts the Mac down instantly" ;;
    ru:done)       echo "ГОТОВО — теперь кнопка питания сразу выключает Mac" ;;
    en:test_h)     echo "Please test it: press the power button" ;;
    ru:test_h)     echo "Пожалуйста, проверьте работу: нажмите кнопку питания" ;;
    en:test_1)     echo "The first time, macOS may ask: \"PowerOff wants to control System Events\" — please choose Allow" ;;
    ru:test_1)     echo "При первом нажатии macOS может спросить: «PowerOff хочет управлять System Events» — нажмите «Разрешить»" ;;
    en:test_2)     echo "If the button does nothing: Privacy & Security → Automation → PowerOff → switch on System Events" ;;
    ru:test_2)     echo "Если кнопка ничего не делает: Конфиденциальность и безопасность → Автоматизация → PowerOff → включите System Events" ;;
    en:test_3)     echo "You can check the current state at any time with ./install.sh status" ;;
    ru:test_3)     echo "Узнать текущее состояние можно в любой момент командой ./install.sh status" ;;

    en:st_title)   echo "Status" ;;
    ru:st_title)   echo "Состояние" ;;
    en:st_daemon)  echo "Background program" ;;
    ru:st_daemon)  echo "Фоновая программа" ;;
    en:st_bin)     echo "Binary" ;;
    ru:st_bin)     echo "Файл PowerOff" ;;
    en:st_plist)   echo "LaunchAgent" ;;
    ru:st_plist)   echo "LaunchAgent" ;;
    en:st_log)     echo "Last log lines" ;;
    ru:st_log)     echo "Последние строки журнала" ;;
    en:st_run)     echo "running" ;;
    ru:st_run)     echo "работает" ;;
    en:st_stop)    echo "NOT running" ;;
    ru:st_stop)    echo "не работает" ;;
    en:st_yes)     echo "present" ;;
    ru:st_yes)     echo "есть" ;;
    en:st_no)      echo "missing" ;;
    ru:st_no)      echo "отсутствует" ;;

    en:u_title)    echo "FULL UNINSTALL" ;;
    ru:u_title)    echo "ПОЛНОЕ УДАЛЕНИЕ" ;;
    en:u_warn)     echo "Everything created by the installer will be removed" ;;
    ru:u_warn)     echo "Будет удалено всё, что создал установщик" ;;
    en:u_1)        echo "Stop the background program and end any leftover processes" ;;
    ru:u_1)        echo "Остановка фоновой программы и завершение оставшихся процессов" ;;
    en:u_2)        echo "LaunchAgent config  ($PLIST_PATH)" ;;
    ru:u_2)        echo "Файл автозапуска LaunchAgent  ($PLIST_PATH)" ;;
    en:u_3)        echo "Binary  ($BIN_PATH)" ;;
    ru:u_3)        echo "Файл PowerOff  ($BIN_PATH)" ;;
    en:u_4)        echo "Log file  ($LOG_PATH)" ;;
    ru:u_4)        echo "Файл журнала  ($LOG_PATH)" ;;
    en:u_5)        echo "The power button setting will be restored to the system default (sleep)" ;;
    ru:u_5)        echo "Настройка кнопки питания будет возвращена к системной (сон)" ;;
    en:u_confirm)  echo "Are you sure you want to remove everything? [y/N]: " ;;
    ru:u_confirm)  echo "Вы уверены, что хотите удалить всё? [д/Н]: " ;;
    en:u_cancel)   echo "Cancelled — nothing was changed." ;;
    ru:u_cancel)   echo "Операция отменена, изменений не внесено." ;;
    en:u_s1)       echo "Stopping the background program" ;;
    ru:u_s1)       echo "Останавливаем фоновую программу" ;;
    en:u_s2)       echo "Removing files" ;;
    ru:u_s2)       echo "Удаляем файлы" ;;
    en:u_s3)       echo "Restoring the power button setting" ;;
    ru:u_s3)       echo "Возвращаем настройку кнопки питания" ;;
    en:u_s4)       echo "Verifying that nothing is left" ;;
    ru:u_s4)       echo "Проверяем, что ничего не осталось" ;;
    en:u_gone)     echo "removed" ;;
    ru:u_gone)     echo "удалено" ;;
    en:u_left)     echo "STILL EXISTS" ;;
    ru:u_left)     echo "ВСЁ ЕЩЁ СУЩЕСТВУЕТ" ;;
    en:u_manual_h) echo "macOS does not allow scripts to do one thing — please do it manually" ;;
    ru:u_manual_h) echo "Одно действие macOS не позволяет выполнить из скрипта — пожалуйста, сделайте его вручную" ;;
    en:u_manual_1) echo "Privacy & Security → Accessibility → select PowerOff → click −" ;;
    ru:u_manual_1) echo "Конфиденциальность и безопасность → Универсальный доступ → выберите PowerOff → нажмите «−»" ;;
    en:u_manual_2) echo "Do the same under Automation if a PowerOff entry is listed there" ;;
    ru:u_manual_2) echo "То же самое в разделе «Автоматизация», если там есть запись PowerOff" ;;
    en:u_folder)   echo "Also delete this project folder? [y/N]: " ;;
    ru:u_folder)   echo "Удалить также папку этого проекта? [д/Н]: " ;;
    en:u_folder_ok) echo "Project folder deleted" ;;
    ru:u_folder_ok) echo "Папка проекта удалена" ;;
    en:u_done)     echo "All done. No trace of PowerOff is left on the system." ;;
    ru:u_done)     echo "Готово. Следов PowerOff в системе не осталось." ;;

    en:h_usage)    echo "Usage" ;;
    ru:h_usage)    echo "Использование" ;;
    en:h_install)  echo "install (guided)" ;;
    ru:h_install)  echo "установка (с подсказками)" ;;
    en:h_rebuild)  echo "install and compile PowerOff.m" ;;
    ru:h_rebuild)  echo "установка со сборкой из PowerOff.m" ;;
    en:h_bin)      echo "install your own ready-made binary" ;;
    ru:h_bin)      echo "установка Вашего готового файла" ;;
    en:h_status)   echo "show the current state" ;;
    ru:h_status)   echo "показать текущее состояние" ;;
    en:h_uninst)   echo "remove everything" ;;
    ru:h_uninst)   echo "полное удаление" ;;
    en:h_lang)     echo "add ru or en to skip the language question" ;;
    ru:h_lang)     echo "добавьте ru или en, чтобы не выбирать язык" ;;
    esac
}

# ── UI helpers ───────────────────────────────────────────────
rule() { local i; for ((i=0; i<$1; i++)); do printf '━'; done; }

banner() {
    local title="P O W E R   D O W N   H A C K I N T O S H !"
    local w=$(( ${#title} + 6 ))
    echo ""
    printf "  ${B}${C}┏"; rule "$w"; printf "┓${N}\n"
    printf "  ${B}${C}┃${N}   ${B}%s${N}   ${B}${C}┃${N}\n" "$title"
    printf "  ${B}${C}┗"; rule "$w"; printf "┛${N}\n"
    echo "     ${D}$(t tagline)${N}"
    echo ""
}

bar() {  # bar DONE TOTAL  →  ●●●○○
    local i s=""
    for ((i=1; i<=$2; i++)); do
        if [ "$i" -le "$1" ]; then s="${s}●"; else s="${s}○"; fi
    done
    printf '%s' "$s"
}

step()  { echo ""; echo "  ${B}${C}$(bar "$1" "$2")${N}  ${D}$1/$2${N}  ${B}$3${N}"; }
ok()    { echo "     ${G}✔${N} $1"; }
warn()  { echo "     ${Y}!${N} $1"; }
fail()  { echo "     ${R}✘${N} $1"; }
bullet(){ echo "     ${D}•${N} $1"; }

# colored left-bar boxes:  box_open TITLE COLOR / box_line COLOR TEXT / box_close COLOR
box_open()  { echo "  ${2}╭─${N} ${B}${2}$1${N}"; }
box_line()  { echo "  ${1}│${N}  $2"; }
box_close() { echo "  ${1}╰─${N}"; }

EOF_HIT=0
ask()   { printf "%s" "$1"; if ! read -r REPLY; then REPLY=""; EOF_HIT=1; fi; }
is_yes(){ case "$1" in y|Y|yes|YES|Yes|д|Д|да|Да|ДА) return 0 ;; *) return 1 ;; esac; }

spin() {  # spin "text" seconds
    local i=0 n=$(( $2 * 10 ))
    local frames=("⠋" "⠙" "⠹" "⠸" "⠼" "⠴" "⠦" "⠧" "⠇" "⠏")
    if [ -t 1 ]; then
        while [ "$i" -lt "$n" ]; do
            printf "\r     ${C}%s${N} %s " "${frames[$((i % 10))]}" "$1"
            sleep 0.1
            i=$((i + 1))
        done
        printf "\r\033[K"
    else
        sleep "$2"
    fi
}

# ── language ─────────────────────────────────────────────────
if [ -z "$L" ] && [ "$ACTION" != "help" ]; then
    DEF=1
    if defaults read -g AppleLanguages 2>/dev/null | grep -q '"ru'; then DEF=2; fi
    L="en"
    echo ""
    echo "  ${B}Language / Язык${N}"
    echo "     ${B}1${N}  English"
    echo "     ${B}2${N}  Русский"
    ask "  [${DEF}]: "
    if [ -z "$REPLY" ]; then REPLY="$DEF"; fi
    case "$REPLY" in 2|ru|RU|р|Р) L="ru" ;; *) L="en" ;; esac
fi

# ── system helpers ───────────────────────────────────────────
is_running() { launchctl list "$LABEL" 2>/dev/null | grep -q '"PID"'; }
get_pid()    { launchctl list "$LABEL" 2>/dev/null | awk -F' = ' '/"PID"/{gsub(/;/,"",$2); print $2}'; }
file_sha()   { shasum -a 256 "$1" 2>/dev/null | awk '{print $1}'; }

agent_stop() {
    launchctl bootout "$DOMAIN/$LABEL" 2>/dev/null || launchctl unload "$PLIST_PATH" 2>/dev/null || true
    sleep 1
}
agent_start() {
    if ! launchctl bootstrap "$DOMAIN" "$PLIST_PATH" 2>/dev/null; then
        launchctl load -w "$PLIST_PATH" 2>/dev/null || true
    fi
    launchctl kickstart -k "$DOMAIN/$LABEL" 2>/dev/null || true
}
# true only if the process survives ~3 seconds (a crash-looping one does not)
check_running() {
    spin "$(t checking)" 2
    if is_running; then
        spin "$(t checking)" 1
        if is_running; then return 0; fi
    fi
    return 1
}

need_user_session() {
    if [ "$EUID" -eq 0 ]; then
        fail "$(t no_root)"
        exit 1
    fi
}

# ── binary source helpers ────────────────────────────────────
find_ready_bin() {
    local c
    for c in "$SCRIPT_DIR/PowerOff" "$SCRIPT_DIR/bin/PowerOff"; do
        if [ -f "$c" ] && file -b "$c" 2>/dev/null | grep -q "Mach-O"; then
            echo "$c"; return 0
        fi
    done
    return 1
}

# validate_bin FILE  →  0 ok / 1 rejected (prints why)
validate_bin() {
    local src="$1" desc want got
    if [ ! -f "$src" ]; then fail "$(t bin_nofile): $src"; return 1; fi
    desc="$(file -b "$src" 2>/dev/null)"
    case "$desc" in
        *Mach-O*) ;;
        *) fail "$(t bin_nomacho)"; return 1 ;;
    esac
    case "$desc" in
        *universal*) ;;
        *"$(uname -m)"*) ;;
        *) warn "$(t bin_arch)  [$desc]" ;;
    esac
    if [ -f "$src.sha256" ]; then
        want="$(awk '{print $1; exit}' "$src.sha256")"
        got="$(file_sha "$src")"
        if [ "$want" = "$got" ]; then
            ok "$(t bin_sha_ok)"
        else
            fail "$(t bin_sha_bad)"
            return 1
        fi
    fi
    return 0
}

# drag&drop in Terminal pastes  '/path/with\ spaces'  — clean it up
clean_path() {
    local p="$1"
    p="${p#\'}"; p="${p%\'}"
    p="${p#\"}"; p="${p%\"}"
    p="${p//\\ / }"
    case "$p" in "~"*) p="$HOME${p#\~}" ;; esac
    printf '%s' "$p"
}

# put SRC into /usr/local/bin (fresh inode, daemon stopped first)
install_bin_from() {
    local src="$1" had_quar=0 sha
    if xattr "$src" 2>/dev/null | grep -q "com.apple.quarantine"; then had_quar=1; fi
    agent_stop
    sudo mkdir -p /usr/local/bin
    sudo rm -f "$BIN_PATH"
    sudo cp "$src" "$BIN_PATH"
    sudo chmod 755 "$BIN_PATH"
    if [ "$had_quar" -eq 1 ]; then
        sudo xattr -d com.apple.quarantine "$BIN_PATH" 2>/dev/null || true
        ok "$(t bin_quar)"
    fi
    sha="$(file_sha "$BIN_PATH")"
    ok "$(t bin_put): $BIN_PATH  ${D}sha256 ${sha:0:16}…${N}"
}

compile_bin() {
    if ! command -v clang >/dev/null 2>&1; then fail "$(t no_clang)"; exit 1; fi
    if [ ! -f "$SCRIPT_DIR/PowerOff.m" ]; then fail "$(t no_src)"; exit 1; fi
    agent_stop
    sudo mkdir -p /usr/local/bin
    sudo rm -f "$BIN_PATH"
    sudo clang -framework Cocoa "$SCRIPT_DIR/PowerOff.m" -o "$BIN_PATH"
    ok "$(t bin_built)"
}

# ask for a custom path; sets PICKED; returns 1 if user backs out
pick_custom_bin() {
    PICKED=""
    while true; do
        ask "     ${B}$(t bin_path)${N}"
        if [ -z "$REPLY" ]; then return 1; fi
        local p
        p="$(clean_path "$REPLY")"
        if validate_bin "$p"; then PICKED="$p"; return 0; fi
    done
}

# the whole "step 2" decision
prepare_binary() {
    local READY INSTALLED=0 DEFAULT MODE="" sha

    # non-interactive shortcuts
    if [ -n "$CUSTOM_BIN" ]; then
        local p; p="$(clean_path "$CUSTOM_BIN")"
        if validate_bin "$p"; then install_bin_from "$p"; return 0; fi
        exit 1
    fi
    if [ "$REBUILD" -eq 1 ]; then compile_bin; return 0; fi

    READY="$(find_ready_bin || true)"
    if [ -x "$BIN_PATH" ]; then INSTALLED=1; fi

    if [ "$INSTALLED" -eq 1 ]; then DEFAULT=3
    elif [ -n "$READY" ]; then DEFAULT=1
    else DEFAULT=2; fi

    echo ""
    echo "     ${B}$(t bin_q)${N}"
    echo ""
    if [ -n "$READY" ]; then
        sha="$(file_sha "$READY")"
        echo "       ${B}${C}1${N}  $(t bin_o1)"
        echo "          ${D}${READY#$SCRIPT_DIR/}  ·  sha256 ${sha:0:12}…${N}"
    else
        echo "       ${D}1  $(t bin_o1) — $(t bin_n1)${N}"
    fi
    echo "       ${B}${C}2${N}  $(t bin_o2)"
    if [ "$INSTALLED" -eq 1 ]; then
        echo "       ${B}${C}3${N}  $(t bin_o3)"
    else
        echo "       ${D}3  $(t bin_o3) — $(t bin_n3)${N}"
    fi
    echo "       ${B}${C}4${N}  $(t bin_o4)"
    echo ""

    while true; do
        ask "     ${B}$(t bin_choice)${N} [${DEFAULT}]: "
        if [ -z "$REPLY" ]; then REPLY="$DEFAULT"; fi
        case "$REPLY" in
            1) if [ -n "$READY" ]; then MODE="ready"; else warn "$(t bin_n1)"; fi ;;
            2) MODE="compile" ;;
            3) if [ "$INSTALLED" -eq 1 ]; then MODE="keep"; else warn "$(t bin_n3)"; fi ;;
            4) if pick_custom_bin; then MODE="custom"; fi ;;
            *) warn "$(t bin_bad)" ;;
        esac
        if [ -n "$MODE" ]; then break; fi
    done

    echo ""
    case "$MODE" in
        ready)
            if validate_bin "$READY"; then install_bin_from "$READY"; else exit 1; fi ;;
        compile) compile_bin ;;
        keep)    ok "$(t bin_keep)" ;;
        custom)  install_bin_from "$PICKED" ;;
    esac
}

# ═════════════════════════════════════════════════════════════
#  HELP
# ═════════════════════════════════════════════════════════════
do_help() {
    if [ -z "$L" ]; then L="en"; fi
    banner
    echo "  ${B}$(t h_usage)${N}"
    echo "     ./install.sh                   $(t h_install)"
    echo "     ./install.sh rebuild           $(t h_rebuild)"
    echo "     ./install.sh --bin=/path/file  $(t h_bin)"
    echo "     ./install.sh status            $(t h_status)"
    echo "     ./install.sh uninstall         $(t h_uninst)"
    echo "     ${D}$(t h_lang)${N}"
    echo ""
}

# ═════════════════════════════════════════════════════════════
#  STATUS
# ═════════════════════════════════════════════════════════════
do_status() {
    need_user_session
    banner
    echo "  ${B}$(t st_title)${N}"
    echo ""
    if is_running; then
        ok "$(t st_daemon): ${G}$(t st_run)${N}  (PID $(get_pid))"
    else
        fail "$(t st_daemon): ${R}$(t st_stop)${N}"
    fi
    if [ -x "$BIN_PATH" ]; then
        ok "$(t st_bin): $(t st_yes)  ${D}$BIN_PATH  ·  sha256 $(file_sha "$BIN_PATH" | cut -c1-12)…${N}"
    else
        fail "$(t st_bin): $(t st_no)"
    fi
    if [ -f "$PLIST_PATH" ]; then ok "$(t st_plist): $(t st_yes)"; else fail "$(t st_plist): $(t st_no)"; fi
    if [ -s "$LOG_PATH" ]; then
        echo ""
        echo "  ${D}$(t st_log):${N}"
        tail -n 5 "$LOG_PATH" | sed 's/^/     /'
    fi
    echo ""
}

# ═════════════════════════════════════════════════════════════
#  INSTALL
# ═════════════════════════════════════════════════════════════
do_install() {
    need_user_session
    banner

    box_open "$(t i_title)" "$C"
    box_line "$C" "$(t i_1)"
    box_line "$C" "$(t i_2)"
    box_line "$C" "$(t i_3)"
    box_close "$C"
    echo ""
    box_open "$(t need_title)" "$Y"
    box_line "$Y" "${Y}1.${N} $(t need_1)"
    box_line "$Y" "${Y}2.${N} $(t need_2)"
    box_line "$Y" "${Y}3.${N} $(t need_3)"
    box_line "$Y" "${Y}4.${N} $(t need_4)"
    box_close "$Y"
    echo ""
    ask "  ${D}$(t go)${N} "

    sudo -v

    # 1 ───────────────────────────────────────────────────────
    step 1 5 "$(t s1)"
    sudo defaults write com.apple.loginwindow PowerButtonSleepsSystem -bool no
    ok "PowerButtonSleepsSystem = no"

    # 2 ───────────────────────────────────────────────────────
    step 2 5 "$(t s2)"
    prepare_binary

    # 3 ───────────────────────────────────────────────────────
    step 3 5 "$(t s3)"
    mkdir -p "$HOME/Library/LaunchAgents" "$HOME/Library/Logs"
    cat << EOF > "$PLIST_PATH"
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
    <key>Label</key>
    <string>$LABEL</string>
    <key>ProgramArguments</key>
    <array>
        <string>$BIN_PATH</string>
    </array>
    <key>RunAtLoad</key>
    <true/>
    <key>KeepAlive</key>
    <dict>
        <key>SuccessfulExit</key>
        <false/>
    </dict>
    <key>ThrottleInterval</key>
    <integer>5</integer>
    <key>LimitLoadToSessionType</key>
    <string>Aqua</string>
    <key>ProcessType</key>
    <string>Interactive</string>
    <key>StandardOutPath</key>
    <string>$LOG_PATH</string>
    <key>StandardErrorPath</key>
    <string>$LOG_PATH</string>
</dict>
</plist>
EOF
    plutil -lint "$PLIST_PATH" >/dev/null
    ok "$(t plist_ok)"

    # 4 ───────────────────────────────────────────────────────
    step 4 5 "$(t s4)"
    agent_stop
    agent_start
    if check_running; then
        ok "$(t running)  (PID $(get_pid))"
        ALREADY_OK=1
    else
        warn "$(t not_running)"
        ALREADY_OK=0
    fi

    # 5 ───────────────────────────────────────────────────────
    step 5 5 "$(t s5)"
    if [ "$ALREADY_OK" -eq 1 ]; then
        ok "$(t perm_ok)"
    else
        printf "%s" "$BIN_PATH" | pbcopy 2>/dev/null || true
        open "$AX_URL" 2>/dev/null || true
        echo ""
        box_open "$(t perm_h)" "$Y"
        box_line "$Y" "${B}$(t perm_p0)${N}"
        box_line "$Y" "${Y}1.${N} $(t perm_p1)"
        box_line "$Y" "${Y}2.${N} $(t perm_p2)"
        box_line "$Y" "     ${C}$BIN_PATH${N}"
        box_line "$Y" "${Y}3.${N} $(t perm_p3)"
        box_close "$Y"
        echo ""
        while true; do
            ask "     ${B}$(t perm_ask)${N}"
            case "$REPLY" in s|S|ы|Ы) warn "$(t perm_skip)"; break ;; esac
            if [ "$EOF_HIT" -eq 1 ]; then warn "$(t perm_skip)"; break; fi
            launchctl kickstart -k "$DOMAIN/$LABEL" 2>/dev/null || agent_start
            if check_running; then
                ok "$(t running)  (PID $(get_pid))"
                break
            else
                fail "$(t perm_retry)"
            fi
        done
    fi

    echo ""
    echo "  ${B}${G}$(rule 60)${N}"
    echo "  ${B}${G}  ✅  $(t done)${N}"
    echo "  ${B}${G}$(rule 60)${N}"
    echo ""
    box_open "$(t test_h)" "$G"
    box_line "$G" "$(t test_1)"
    box_line "$G" "$(t test_2)"
    box_line "$G" "$(t test_3)"
    box_close "$G"
    echo ""
}

# ═════════════════════════════════════════════════════════════
#  UNINSTALL  (nuclear)
# ═════════════════════════════════════════════════════════════
do_uninstall() {
    need_user_session
    banner
    box_open "☢  $(t u_title)" "$R"
    box_line "$R" "${B}$(t u_warn)${N}"
    box_line "$R" "${D}•${N} $(t u_1)"
    box_line "$R" "${D}•${N} $(t u_2)"
    box_line "$R" "${D}•${N} $(t u_3)"
    box_line "$R" "${D}•${N} $(t u_4)"
    box_line "$R" "${D}•${N} $(t u_5)"
    box_close "$R"
    echo ""
    ask "  ${B}$(t u_confirm)${N}"
    if ! is_yes "$REPLY"; then
        echo ""
        echo "  $(t u_cancel)"
        echo ""
        exit 0
    fi
    sudo -v

    step 1 4 "$(t u_s1)"
    agent_stop
    pkill -f "$BIN_PATH" 2>/dev/null || true
    sudo pkill -f "$BIN_PATH" 2>/dev/null || true
    sleep 1
    ok "bootout + pkill"

    step 2 4 "$(t u_s2)"
    rm -f "$PLIST_PATH"
    rm -f "$LOG_PATH"
    sudo rm -f "$BIN_PATH"
    ok "plist, log, binary"

    step 3 4 "$(t u_s3)"
    sudo defaults delete com.apple.loginwindow PowerButtonSleepsSystem 2>/dev/null || true
    defaults delete com.apple.loginwindow PowerButtonSleepsSystem 2>/dev/null || true
    ok "PowerButtonSleepsSystem"

    step 4 4 "$(t u_s4)"
    LEFT=0
    if [ -e "$PLIST_PATH" ]; then fail "$PLIST_PATH — ${R}$(t u_left)${N}"; LEFT=1; else ok "$PLIST_PATH — $(t u_gone)"; fi
    if [ -e "$BIN_PATH" ];   then fail "$BIN_PATH — ${R}$(t u_left)${N}";   LEFT=1; else ok "$BIN_PATH — $(t u_gone)"; fi
    if [ -e "$LOG_PATH" ];   then fail "$LOG_PATH — ${R}$(t u_left)${N}";   LEFT=1; else ok "$LOG_PATH — $(t u_gone)"; fi
    if is_running || pgrep -f "$BIN_PATH" >/dev/null 2>&1; then
        fail "$(t st_daemon) — ${R}$(t u_left)${N}"; LEFT=1
    else
        ok "$(t st_daemon) — $(t u_gone)"
    fi

    echo ""
    box_open "$(t u_manual_h)" "$Y"
    box_line "$Y" "$(t u_manual_1)"
    box_line "$Y" "$(t u_manual_2)"
    box_close "$Y"
    open "$AX_URL" 2>/dev/null || true
    echo ""

    if [ "$LEFT" -eq 0 ]; then
        echo "  ${B}${G}$(rule 60)${N}"
        echo "  ${B}${G}  ✅  $(t u_done)${N}"
        echo "  ${B}${G}$(rule 60)${N}"
    fi
    echo ""

    # optionally delete the project folder itself (last step)
    if [ -f "$SCRIPT_DIR/PowerOff.m" ] && [ -f "$SCRIPT_DIR/install.sh" ]; then
        ask "  ${B}$(t u_folder)${N}"
        if is_yes "$REPLY"; then
            cd "$HOME"
            rm -rf "$SCRIPT_DIR"
            echo ""
            ok "$(t u_folder_ok)"
            echo ""
        fi
    fi
}

# ── dispatch ─────────────────────────────────────────────────
case "$ACTION" in
    help)      do_help ;;
    status)    do_status ;;
    uninstall) do_uninstall ;;
    install)   do_install ;;
esac
exit 0
