#!/bin/bash
set -e

PLIST_PATH="$HOME/Library/LaunchAgents/com.user.poweroff.plist"
BIN_PATH="/usr/local/bin/PowerOff"

if [ "$1" == "uninstall" ]; then
    echo "Удаление Hackintosh Direct PowerOff..."
    launchctl unload "$PLIST_PATH" 2>/dev/null || true
    rm -f "$PLIST_PATH"
    sudo rm -f "$BIN_PATH"
    sudo defaults delete com.apple.loginwindow PowerButtonSleepsSystem 2>/dev/null || true
    echo "Готово! Полностью удалено."
    exit 0
fi

echo "1. Отключаем уход в сон по короткому нажатию кнопки питания..."
sudo defaults write com.apple.loginwindow PowerButtonSleepsSystem -bool no

echo "2. Компилируем PowerOff..."
sudo mkdir -p /usr/local/bin
sudo clang -framework Cocoa PowerOff.m -o "$BIN_PATH"

echo "3. Настраиваем фоновый автозапуск (LaunchAgent)..."
mkdir -p "$HOME/Library/LaunchAgents"
cat << EOF > "$PLIST_PATH"
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://apple.com">
<plist version="1.0">
<dict>
    <key>Label</key>
    <string>com.user.poweroff</string>
    <key>ProgramArguments</key>
    <array>
        <string>$BIN_PATH</string>
    </array>
    <key>RunAtLoad</key>
    <true/>
    <key>KeepAlive</key>
    <true/>
</dict>
</plist>
EOF

launchctl unload "$PLIST_PATH" 2>/dev/null || true
launchctl load "$PLIST_PATH"

echo ""
echo "✅ Установка завершена!"
echo "👉 ВАЖНО: Открой 'Системные настройки -> Конфиденциальность и безопасность -> Универсальный доступ',"
echo "   нажми '+', нажми Cmd+Shift+G, введи /usr/local/bin/PowerOff и включи тумблер."
echo "👉 После этого один раз перезагрузи Mac."
