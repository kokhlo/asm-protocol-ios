# AGENTS.md — asm-protocol-ios

SwiftUI-клиент ASM://PROTOCOL. Публичный репозиторий, ноль сторонних зависимостей.

- Проект описан в `project.yml` (xcodegen); `ASMProtocol.xcodeproj` не в git.
  `asm-protocol-ios/Info.plist` генерируется xcodegen из блока `info:` — правь `project.yml`,
  потом `xcodegen generate`, и коммить оба файла.
- Версия — `MARKETING_VERSION`, номер билда — `CURRENT_PROJECT_VERSION` (build settings
  в `project.yml`). Литералы в Info.plist не ставить: номер билда из CI до ipa не дойдёт.
- Локальной сборки может не быть (нет Xcode) — гейт это CI: `.github/workflows/ios.yml`,
  `macos-26` / Xcode 26, юнит-тесты `ASMProtocolTests` на самом свежем iPhone-симуляторе.
- Push в `main` после зелёных тестов выгружает билд в TestFlight (схема Kosherno,
  `kokhlo/kosher-gpt`). Ручной запуск выгружает только из `main`. Секреты:
  `APP_STORE_CONNECT_KEY_ID`, `APP_STORE_CONNECT_ISSUER_ID`,
  `APP_STORE_CONNECT_PRIVATE_KEY_BASE64`; Team ID `7LP48D3553` — в workflow и
  `ci/ExportOptions.plist`. Подробности и ручные шаги Apple — README, раздел «CI и TestFlight».
- Секреты не печатать и не коммитить. Архив в CI собирается без подписи; подписывает
  экспорт облачным Apple Distribution-сертификатом — не добавлять подпись в archive.
- Ветки от `origin/main`, PR в `main`, коммиты `type(scope): описание` по-русски.
