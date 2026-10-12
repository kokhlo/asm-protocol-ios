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

Требуется macOS 15+, Xcode 16+ и [xcodegen](https://github.com/yonaskolb/XcodeGen):

```bash
xcodegen generate     # ASMProtocol.xcodeproj не в git — генерируется из project.yml
open ASMProtocol.xcodeproj
# Scheme: ASMProtocol, destination: iPhone 16 (iOS 18.5) simulator, Run
```

Юнит-тесты:

```bash
xcodebuild test \
  -project ASMProtocol.xcodeproj -scheme ASMProtocol \
  -destination 'platform=iOS Simulator,name=iPhone 16,OS=18.5' \
  CODE_SIGNING_ALLOWED=NO
```

CI (`.github/workflows/ios.yml`): каждый пуш → macOS-раннер → `xcodegen` →
`xcodebuild build` + `xcodebuild test` на симуляторе iPhone 16 / iOS 18.5.
Сгенерированный `.xcodeproj` в git не хранится — единственный источник истины `project.yml`.

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
- [ ] TestFlight — после покупки Apple Developer-аккаунта (решение владельца)
- [ ] TLS на стенде + включение ATS по умолчанию

## Лицензия

MIT — см. [LICENSE](LICENSE).
