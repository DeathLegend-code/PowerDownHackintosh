# Power Down Hackintosh!

**[Русский](#ru)** · **[English](#en)**

---

<a id="ru"></a>

## Русский

Лёгкая нативная утилита для macOS / Hackintosh (написана на Objective-C, без сторонних зависимостей). Она позволяет выключить компьютер **одним нажатием физической кнопки питания на корпусе** — без удержания кнопки и без всплывающего системного окна «Перезагрузить / Режим сна / Выключить».

### Как это работает

1. Установщик отключает переход в сон по короткому нажатию кнопки питания (`PowerButtonSleepsSystem = no`).
2. Лёгкая фоновая программа (`LaunchAgent`) перехватывает системное событие `NX_POWER_KEY` через `CGEventTap` и сразу запускает штатное завершение работы macOS.

### Требования

* macOS (проверено на Sonoma 14.8.9)
* Для сборки из исходного кода — Xcode Command Line Tools: `xcode-select --install`
* Права администратора (пароль будет запрошен через `sudo`)

### Быстрая установка

```bash
git clone https://github.com/DeathLegend-code/PowerDownHackintosh
cd PowerDownHackintosh
chmod +x install.sh
./install.sh
```

Установщик задаст язык (English / Русский), коротко объяснит, что будет сделано и что потребуется от Вас, и проведёт по всем шагам. Перезагрузка не требуется.

> **Пожалуйста, не запускайте `install.sh` через `sudo`.** Пароль скрипт запросит сам, когда он понадобится. Запуск от имени root не позволит корректно подключить LaunchAgent в Вашей сессии.

### Какой файл PowerOff выбрать: собрать самому или готовый

Установщик предлагает три источника программы `PowerOff`, а также возможность оставить уже установленную.

**Рекомендуем собирать из исходного кода самостоятельно** (пункт 2 в меню или `./install.sh rebuild`). Причины:

* **Это быстро.** Исходник — один небольшой файл `PowerOff.m`; сборка обычно занимает несколько секунд.
* **Это безопаснее.** Программе выдаётся разрешение «Универсальный доступ», то есть она получает доступ к системным событиям ввода. Исходный код можно прочитать и убедиться, что он делает ровно то, что заявлено, — а в готовый файл заглянуть нельзя.
* **Это надёжнее.** Файл собирается под Ваш Mac и Вашу версию системы.

**Готовые сборки** существуют для удобства — для тех, кто не хочет устанавливать Xcode Command Line Tools или просто не желает заморачиваться. Они публикуются отдельно (см. раздел Releases репозитория). Если Вы используете готовый файл:

* Скачивайте его только из официального репозитория.
* Если рядом лежит файл `PowerOff.sha256`, установщик автоматически сверит контрольную сумму и откажется ставить файл при несовпадении. Обратите внимание: контрольная сумма подтверждает, что файл не повреждён при загрузке, но не заменяет проверку исходного кода.

#### Как подключить готовый файл

Положите файл `PowerOff` рядом с `install.sh` (или в папку `bin/`) и запустите `./install.sh` — установщик найдёт его сам и предложит как вариант по умолчанию. Либо укажите путь явно:

```bash
./install.sh --bin=/путь/к/PowerOff
```

Установщик проверит, что это исполняемый файл macOS (Mach-O), предупредит о несоответствии архитектуры и снимет карантинную метку скачанного файла с установленной копии. Сам файл при этом не изменяется.

### Команды и флаги установщика

| Команда | Что делает |
|---|---|
| `./install.sh` | Установка в интерактивном режиме (с подсказками) |
| `./install.sh rebuild` | Установка со сборкой из `PowerOff.m` (без вопроса об источнике) |
| `./install.sh --bin=/путь/к/файлу` | Установка Вашего готового файла `PowerOff` |
| `./install.sh status` | Показать, работает ли программа, и последние строки журнала |
| `./install.sh uninstall` | Полное удаление (см. ниже) |
| `./install.sh help` (`-h`, `--help`) | Краткая справка |
| `ru` или `--lang=ru` | Русский язык, без вопроса о языке |
| `en` или `--lang=en` | English, без вопроса о языке |

Флаги можно сочетать, например: `./install.sh rebuild ru` или `./install.sh --bin=/путь/PowerOff en`.

### Обязательный шаг: разрешение «Универсальный доступ»

Без него macOS не позволит программе перехватывать кнопку питания. Установщик сам откроет нужное окно и скопирует путь в буфер обмена. Вам нужно:

1. Открыть **Системные настройки → Конфиденциальность и безопасность → Универсальный доступ**.
2. Нажать **+**, затем `Cmd + Shift + G`, вставить `/usr/local/bin/PowerOff` (путь уже в буфере обмена) и нажать «Открыть».
3. Убедиться, что переключатель напротив **PowerOff** включён.
4. Вернуться в Терминал и нажать Enter — установщик проверит, что программа запустилась.

Если Вы пропустили проверку, ничего страшного: программа запустится автоматически в течение нескольких секунд после выдачи разрешения.

### Что устанавливается

| Объект | Расположение |
|---|---|
| Программа | `/usr/local/bin/PowerOff` |
| Автозапуск (LaunchAgent) | `~/Library/LaunchAgents/com.user.poweroff.plist` |
| Журнал | `~/Library/Logs/PowerOff.log` |
| Системная настройка | `PowerButtonSleepsSystem = no` (`com.apple.loginwindow`) |

### Если что-то не работает

* **Проверьте состояние:** `./install.sh status` или `launchctl list | grep poweroff` (наличие PID означает, что программа работает).
* **Программа не запускается.** Скорее всего, не выдано разрешение «Универсальный доступ». Подробности — в журнале `~/Library/Logs/PowerOff.log`.
* **Кнопка нажимается, но выключения нет.** Для выключения используется `System Events`. Откройте **Конфиденциальность и безопасность → Автоматизация → PowerOff** и включите **System Events**. При первом нажатии macOS может сам предложить это разрешить.
* **`clang` не найден.** Выполните `xcode-select --install` и запустите установщик ещё раз.
* **Предупреждение об архитектуре готового файла.** Файл собран для другой архитектуры; соберите программу из исходного кода.

### Удаление

```bash
./install.sh uninstall
```

Перед удалением установщик покажет полный список и попросит подтверждение. Будут удалены: фоновая программа и её процессы, LaunchAgent, файл `PowerOff`, журнал и системная настройка (кнопка питания вернётся к поведению по умолчанию). В конце скрипт проверит, что ничего не осталось, и предложит удалить папку проекта.

Одно действие macOS не позволяет выполнить из скрипта: запись **PowerOff** в разделах «Универсальный доступ» (и «Автоматизация», если она там есть) нужно убрать вручную — выберите её и нажмите «−».

---

<a id="en"></a>

## English

A lightweight native utility for macOS / Hackintosh (written in Objective-C, no third-party dependencies) that lets you shut the computer down with **a single press of the physical power button** — no long press and no system dialog asking to Restart / Sleep / Shut Down.

### How it works

1. The installer stops the short power-button press from putting the Mac to sleep (`PowerButtonSleepsSystem = no`).
2. A small background program (a `LaunchAgent`) intercepts the `NX_POWER_KEY` system event via `CGEventTap` and immediately starts the standard macOS shutdown.

### Requirements

* macOS (tested on Sonoma 14.8.9)
* To compile from source: Xcode Command Line Tools — `xcode-select --install`
* Administrator rights (you will be asked for your password via `sudo`)

### Quick start

```bash
git clone https://github.com/DeathLegend-code/PowerDownHackintosh
cd PowerDownHackintosh
chmod +x install.sh
./install.sh
```

The installer asks for a language (English / Русский), briefly explains what it is about to do and what is required from you, and guides you through every step. No restart is needed.

> **Please do not run `install.sh` with `sudo`.** The script asks for your password itself when needed. Running it as root prevents the LaunchAgent from being loaded into your own session.

### Which PowerOff binary to use: compile it yourself or use a ready-made one

The installer offers three sources for the `PowerOff` program, plus the option to keep one that is already installed.

**We recommend compiling it yourself** (option 2 in the menu, or `./install.sh rebuild`), because:

* **It is fast.** The source is a single small file, `PowerOff.m`; compiling usually takes a few seconds.
* **It is safer.** The program is granted the Accessibility permission, meaning it can observe system input events. You can read the source and confirm it does exactly what is described — you cannot do that with a ready-made binary.
* **It is more reliable.** The binary is built for your Mac and your version of macOS.

**Ready-made binaries** are provided for convenience, for those who prefer not to install the Xcode Command Line Tools or simply do not want the hassle. They are published separately (see the repository's Releases section). If you use one:

* Download it only from the official repository.
* If a `PowerOff.sha256` file sits next to it, the installer verifies the checksum automatically and refuses to install the file on a mismatch. Please note that a checksum only confirms the file was not corrupted in transit; it does not replace reviewing the source code.

#### Using a ready-made binary

Place the `PowerOff` file next to `install.sh` (or into the `bin/` folder) and run `./install.sh` — the installer finds it and offers it as the default. Alternatively, pass the path explicitly:

```bash
./install.sh --bin=/path/to/PowerOff
```

The installer checks that the file is a macOS executable (Mach-O), warns about an architecture mismatch, and removes the download quarantine flag from the installed copy. The file itself is never modified.

### Commands and flags

| Command | What it does |
|---|---|
| `./install.sh` | Guided, interactive installation |
| `./install.sh rebuild` | Install and compile from `PowerOff.m` (skips the source question) |
| `./install.sh --bin=/path/to/file` | Install your own ready-made `PowerOff` binary |
| `./install.sh status` | Show whether the program is running, plus the last log lines |
| `./install.sh uninstall` | Full removal (see below) |
| `./install.sh help` (`-h`, `--help`) | Short usage help |
| `ru` or `--lang=ru` | Russian, skips the language question |
| `en` or `--lang=en` | English, skips the language question |

Flags can be combined, for example: `./install.sh rebuild en` or `./install.sh --bin=/path/PowerOff ru`.

### Required step: the Accessibility permission

Without it, macOS will not let the program intercept the power button. The installer opens the right System Settings page and copies the path to your clipboard. You will need to:

1. Open **System Settings → Privacy & Security → Accessibility**.
2. Click **+**, press `Cmd + Shift + G`, paste `/usr/local/bin/PowerOff` (it is already on your clipboard) and click Open.
3. Make sure the toggle next to **PowerOff** is switched on.
4. Return to Terminal and press Enter — the installer will confirm that the program is running.

If you skip the check, that is fine: the program starts automatically within a few seconds after the permission is granted.

### What gets installed

| Item | Location |
|---|---|
| Program | `/usr/local/bin/PowerOff` |
| Autostart (LaunchAgent) | `~/Library/LaunchAgents/com.user.poweroff.plist` |
| Log file | `~/Library/Logs/PowerOff.log` |
| System setting | `PowerButtonSleepsSystem = no` (`com.apple.loginwindow`) |

### Troubleshooting

* **Check the state:** `./install.sh status` or `launchctl list | grep poweroff` (a PID means the program is running).
* **The program does not start.** Most likely the Accessibility permission has not been granted yet. See `~/Library/Logs/PowerOff.log` for details.
* **The button is detected but nothing shuts down.** Shutdown goes through `System Events`. Open **Privacy & Security → Automation → PowerOff** and enable **System Events**. macOS may also offer to allow this on the first press.
* **`clang` not found.** Run `xcode-select --install` and start the installer again.
* **Architecture warning for a ready-made binary.** The file was built for a different architecture; please compile from source instead.

### Uninstall

```bash
./install.sh uninstall
```

Before removing anything, the installer shows the full list and asks for confirmation. It removes the background program and its processes, the LaunchAgent, the `PowerOff` binary, the log file and the system setting (the power button returns to its default behaviour). At the end it verifies that nothing is left and offers to delete the project folder.

There is one thing macOS does not let scripts do: the **PowerOff** entry in Accessibility (and in Automation, if one is listed) has to be removed manually — select it and click “−”.

---

## Credits & Inspiration

* The idea and concept are inspired by [antimodular/direct_shutdown](https://github.com/antimodular/direct_shutdown) and by the `NX_POWER_KEY` interception snippet from Akira-Hayasaka.
* This implementation is written in plain Objective-C without third-party frameworks and adapted for automatic background deployment on modern versions of macOS / Hackintosh.
