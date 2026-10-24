# ASM://PROTOCOL — iOS

Мобильный клиент образовательного портала [asm-protocol](https://github.com/kokhlo/asm-protocol):
низкоуровневое программирование от ассемблера до Ada, без геймификации.
Русский язык — базовый, эстетика киберпанк-терминала.

## Что внутри

- **Треки и модули.** Список модулей группируется по трекам (ПРОЛОГ → ASM → C → C++ → ADA),
  данные — из живого curriculum-API стенда.
- **Урок с режимами.** У каждого урока два уровня абстракции: `script_kiddie` (концепты) и
  `console_cowboy` (bare metal). Переключатель режима — на экране урока.
- **Шесть типов упражнений.** `choose`, `predict`, `translate` (выбор варианта),
  `order` (сборка последовательности), `fill`, `trace` (текстовый ответ). Ответ проверяется
  **локально** по `answer_index` / порядку `items` / списку `accepted` — эталоны приходят
  вместе с контентом, на сервер ничего лишнего не отправляется.
- **Прогресс через progress-API.** User-key (`ios-<uuid>`) генерируется один раз и живёт
  в Keychain. Каждое решение → `client_revision + 1` → `PUT /api/v1/progress/{key}`.
  Конфликт ревизий (409) разрешается повтором с серверной ревизией; офлайн-решения
  накапливаются локально и синхронизируются при появлении сети.
- **Терминальная эстетика.** Тёмная тема, моноширинный шрифт, зелёный на чёрном.
  Никаких XP, бейджей и стриков. Ошибка — красный блок с машинным текстом
  (`ERR 0x01: ОТВЕТ ОТКЛОНЁН`), успех — зелёный блок с инженерным разбором.

## Скриншоты

| Главный экран (треки/модули) | Урок: predict + код | Урок: order | Ошибка |
|---|---|---|---|
| ![Главный экран](docs/screenshots/modules.png) | ![Predict](docs/screenshots/lesson-predict.png) | ![Order](docs/screenshots/lesson-order.png) | ![Ошибка](docs/screenshots/error.png) |

> Скриншоты-плейсхолдеры: будут заменены реальными после первого запуска на симуляторе.

## Сборка

Требуется Xcode 26+ и [xcodegen](https://github.com/yonaskolb/XcodeGen):

```bash
xcodegen generate     # ASMProtocol.xcodeproj не в git — генерируется из project.yml
open ASMProtocol.xcodeproj
# Scheme: ASMProtocol, destination: любой iPhone-симулятор, Run
```

Юнит-тесты:

```bash
xcodebuild test \
  -project ASMProtocol.xcodeproj -scheme ASMProtocol \
  -destination 'platform=iOS Simulator,name=iPhone 17' \
  -only-testing:ASMProtocolTests CODE_SIGNING_ALLOWED=NO
```

Сгенерированный `.xcodeproj` в git не хранится — единственный источник истины `project.yml`.
Версия приложения — build setting `MARKETING_VERSION` в `project.yml`, номер билда —
`CURRENT_PROJECT_VERSION` (в Info.plist только подстановки `$(...)`).

## CI и TestFlight

Один workflow [`.github/workflows/ios.yml`](.github/workflows/ios.yml), по схеме Kosherno
(`kokhlo/kosher-gpt`), runner `macos-26` / Xcode 26 (App Store Connect с 28.04.2026
принимает только сборки на iOS 26 SDK):

- **PR в `main`** — `xcodegen` → юнит-тесты (`ASMProtocolTests`) на самом свежем
  iPhone-симуляторе образа. Ничего не выгружается.
- **Push в `main`** — те же тесты, и **только если они зелёные** — Release-архив
  (без подписи) → экспорт с подписью облачным Apple Distribution-сертификатом команды →
  выгрузка в App Store Connect. Номер билда: `200000 + run_number × 100 + run_attempt`.
- **Ручной запуск** (Actions → ios → Run workflow) выгружает только из `main`.

Без секретов job выгрузки падает на первом шаге с ошибкой `Нет секрета <ИМЯ>`; тесты от
секретов не зависят.

### Что нужно один раз (Apple + GitHub)

Значения те же, что в `kokhlo/kosher-gpt` (команда Apple Ивана, Team ID `7LP48D3553`
в `ci/ExportOptions.plist` и в workflow):

1. **developer.apple.com → Identifiers**: App ID `expert.softsys.asm-protocol`
   (Explicit, без дополнительных capabilities).
2. **App Store Connect → Apps → +**: приложение с bundle ID `expert.softsys.asm-protocol`,
   имя `ASM://PROTOCOL` (если занято — `ASM Protocol`), основной язык Russian, SKU любой.
3. **Users and Access → Integrations → App Store Connect API**: командный ключ с правом
   выгружать билды и управлять сертификатами/профилями (роль Admin — как у ключа Kosherno;
   можно взять тот же ключ). `.p8` скачивается один раз.
4. Ключ в base64 без переносов: `base64 -i AuthKey_<KEY_ID>.p8 | tr -d '\n'`.
5. **Settings → Secrets and variables → Actions** этого репо, три секрета:

   | Секрет | Откуда |
   |---|---|
   | `APP_STORE_CONNECT_KEY_ID` | Key ID ключа на странице Integrations |
   | `APP_STORE_CONNECT_ISSUER_ID` | Issuer ID на той же странице |
   | `APP_STORE_CONNECT_PRIVATE_KEY_BASE64` | вывод команды из шага 4 |

Ключ декодируется только во временный каталог раннера и удаляется в конце job.
Билд появляется в TestFlight после обработки Apple (несколько минут); внутренних
тестировщиков добавляют в App Store Connect → TestFlight.

## Технические рамки

- iOS 17+, SwiftUI, `@Observable`; сеть — `URLSession` + `Codable`.
- **Ноль сторонних зависимостей.** SPM-манифест отсутствует намеренно.
- Локализация: русский базовый, `asm-protocol-ios/Localizable.xcstrings`.
- API стенда: `http://202.71.13.244` — curriculum (`/api/v1/curriculum/*`) и progress
  (`/api/v1/progress/{user-key}`) сервисы. Оба живут за одним Caddy на хостинге.
  > HTTP (не HTTPS) → работает только при выключенном ATS. Для App Store понадобится
  > TLS-терминация на Caddy — см. roadmap.

## Roadmap

- [ ] Реальные скриншоты (симулятор + `xcrun simctl io booted screenshot`)
- [ ] Тесты против живого API (curriculum-контракт: `answer_index`, `items`, `accepted`)
- [ ] Экран навыков (`/api/v1/curriculum/skills`, 66 записей) и связка навык↔урок
- [ ] Отправка кода в песочницу (`POST /api/v1/execute`)
- `position` в progress-API (продолжить с места) — сервер ждёт `{moduleId, lesson:int}`,
  формат `lesson` (int vs lesson_id) уточняется с бэкендом
- [ ] Первый билд в TestFlight — после шагов из раздела «CI и TestFlight»
- [ ] TLS на стенде + включение ATS по умолчанию

## Лицензия

MIT — см. [LICENSE](LICENSE).
