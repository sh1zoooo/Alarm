# DanceAlarm 🕺🚽

Будильник для iOS, который нельзя выключить обычным способом — нужно выполнить
случайное задание: потанцевать, показать унитаз камерой, потрясти телефон,
решить примеры, отсканировать QR, пройти шаги, повторить Simon Says или
напечатать фразу без ошибок.

## Структура проекта

```
DanceAlarm/
  DanceAlarmApp.swift        — точка входа, разрешения на уведомления
  ContentView.swift          — список будильников, экран добавления
  AlarmModel.swift           — модель Alarm + AlarmManager
  AlarmScheduler.swift       — планирование UNNotification
  AlarmSoundPlayer.swift     — громкий звук + фоновый keeper
  AlarmRingingView.swift     — роутинг на экран нужного задания
  Challenges/
    Challenge.swift              — enum ChallengeType со всеми заданиями
    DanceChallengeView.swift     — танец (CoreMotion, акселерометр)
    ToiletCameraChallengeView.swift — унитаз (Vision VNClassifyImageRequest)
    ShakeChallengeView.swift     — тряска телефона
    MathChallengeView.swift      — примеры
    QRScanChallengeView.swift    — скан QR-кода
    StepsChallengeView.swift     — шаги (CMPedometer)
    SimonSaysChallengeView.swift — повтори последовательность
    TypingChallengeView.swift    — напечатай фразу
  Info.plist
project.yml                  — конфиг XcodeGen (генерирует .xcodeproj)
.github/workflows/build.yml  — CI: сборка на macOS-раннере GitHub Actions
```

## Локальная сборка (на Mac)

1. Установи XcodeGen: `brew install xcodegen`
2. В корне репозитория: `xcodegen generate` — создаст `DanceAlarm.xcodeproj`
3. Открой `DanceAlarm.xcodeproj` в Xcode
4. Добавь звуковые файлы `alarm_sound.caf` и `silence.caf` в таргет (для громкого будильника и фонового keeper) — своих ещё нет в репо
5. В Signing & Capabilities выбери свою команду (можно бесплатный Apple ID для установки на личное устройство)
6. Product → Archive → Distribute App → Development — получишь подписанный `.ipa`

## Сборка через GitHub Actions

Workflow `.github/workflows/build.yml` запускается на push в `main` или вручную
(`workflow_dispatch`). Он:
- ставит XcodeGen и генерирует проект
- собирает для симулятора (проверка, что всё компилируется)
- собирает неподписанный `.xcarchive`/`.ipa` для устройства и кладёт в Artifacts

Важно: неподписанный `.ipa` из CI нельзя установить на реальный iPhone —
Apple требует подпись сертификатом разработчика. Чтобы CI собирал сразу
подписанный `.ipa`, нужно добавить в GitHub Secrets `.p12` сертификат и
`.mobileprovision` профиль и обновить workflow — отдельная задача, скажи если нужно.

## Известные ограничения

- Задание "унитаз" использует общую модель классификации изображений Apple
  (не обучена специально на унитазах) — иногда может не распознать с первого раза,
  в коде есть защита от случайного срабатывания (2 подтверждения подряд).
- Нужно добавить свои `.caf` файлы звука будильника и тишины (их нет в репозитории).
