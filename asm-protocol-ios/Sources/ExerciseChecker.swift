import Foundation

/// Локальная проверка ответов. Ответ никогда не отправляется на сервер —
/// эталоны приходят вместе с упражнением (answer_index / порядок items / accepted).
enum CheckResult: Equatable {
    case correct
    case wrong(machineMessage: String)

    var isCorrect: Bool { self == .correct }
}

struct ExerciseChecker {

    // MARK: choose / predict / translate — options + answer_index

    static func checkChoice(_ exercise: Exercise, selected: Int?) -> CheckResult {
        guard exercise.options?.isEmpty == false else {
            return .wrong(machineMessage: "ERR 0x00: БИТЫЙ КОНТЕНТ\nупражнение без options")
        }
        guard exercise.answerIndex != nil else {
            return .wrong(machineMessage: "ERR 0x00: БИТЫЙ КОНТЕНТ\nупражнение без answer_index")
        }
        guard let selected else {
            return .wrong(machineMessage: "ERR 0x01: ПУСТОЙ ОТВЕТ\nвариант не выбран")
        }
        guard selected == exercise.answerIndex else {
            return .wrong(machineMessage: "ERR 0x01: ОТВЕТ ОТКЛОНЁН\nвыбран #\(selected + 1), ожидался #\(exercise.answerIndex! + 1)")
        }
        return .correct
    }

    // MARK: order — правильный порядок совпадает с исходным порядком items

    /// Стартовая перестановка пула, как `initialOrder` в вебе: детерминированное «колесо» —
    /// сдвиг на половину. Для n ≥ 2 ни один шаг не стоит на своём месте.
    static func initialOrder(_ count: Int) -> [Int] {
        guard count > 0 else { return [] }
        let shift = count / 2
        return (0..<count).map { ($0 + shift) % count }
    }

    static func checkOrder(_ exercise: Exercise, order: [Int]) -> CheckResult {
        guard let items = exercise.items, !items.isEmpty else {
            return .wrong(machineMessage: "ERR 0x00: БИТЫЙ КОНТЕНТ\nупражнение без items")
        }
        let expected = Array(items.indices)
        guard order.count == items.count else {
            return .wrong(machineMessage: "ERR 0x02: ПОСЛЕДОВАТЕЛЬНОСТЬ НЕПОЛНА\nсобрано \(order.count) из \(items.count) шагов")
        }
        guard order == expected else {
            let firstWrong = zip(order, expected).first(where: { $0.0 != $0.1 })?.0 ?? -1
            return .wrong(machineMessage: "ERR 0x02: ПОРЯДОК НАРУШЕН\nпервое расхождение в позиции \(firstWrong + 1)")
        }
        return .correct
    }

    // MARK: fill / trace — сравнение с accepted.
    // Нормализация как в веб-клиенте (packages/frontend/src/checks.ts):
    // пробелы вырезаются целиком, регистр приводится к нижнему.

    static func checkText(_ exercise: Exercise, answer: String) -> CheckResult {
        guard let accepted = exercise.accepted, !accepted.isEmpty else {
            return .wrong(machineMessage: "ERR 0x00: БИТЫЙ КОНТЕНТ\nупражнение без accepted")
        }
        let normalized = normalize(answer)
        guard !normalized.isEmpty else {
            return .wrong(machineMessage: "ERR 0x03: ПУСТОЙ ОТВЕТ\nполе ввода не заполнено")
        }
        if accepted.map(normalize).contains(normalized) {
            return .correct
        }
        return .wrong(machineMessage: "ERR 0x03: ОТВЕТ НЕ ПРИНЯТ\nввод не совпал ни с одним эталоном")
    }

    // MARK: write — статический анализ по образцу веб-клиента:
    // все expected_patterns находятся в вводе (регистронезависимо),
    // ни один forbidden_patterns не находится. Паттерны применяются к
    // сырому вводу, без нормализации пробелов.

    static func checkWrite(_ exercise: Exercise, answer: String) -> CheckResult {
        guard let expected = exercise.expectedPatterns, !expected.isEmpty else {
            return .wrong(machineMessage: "ERR 0x00: БИТЫЙ КОНТЕНТ\nwrite без expected_patterns — нужна песочница")
        }
        guard !answer.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
            return .wrong(machineMessage: "ERR 0x03: ПУСТОЙ ОТВЕТ\nполе ввода не заполнено")
        }
        for pattern in expected {
            if !matches(pattern, in: answer) {
                return .wrong(machineMessage: "ERR 0x04: СТАТИЧЕСКИЙ АНАЛИЗ\nне найдено ожидаемое: /\(pattern)/i")
            }
        }
        for pattern in exercise.forbiddenPatterns ?? [] {
            if matches(pattern, in: answer) {
                return .wrong(machineMessage: "ERR 0x04: СТАТИЧЕСКИЙ АНАЛИЗ\nзапрещённый шаблон: /\(pattern)/i")
            }
        }
        return .correct
    }

    private static func matches(_ pattern: String, in text: String) -> Bool {
        guard let regex = try? NSRegularExpression(pattern: pattern, options: [.caseInsensitive]) else { return false }
        return regex.firstMatch(in: text, range: NSRange(text.startIndex..., in: text)) != nil
    }

    static func normalize(_ s: String) -> String {
        s.split(whereSeparator: \.isWhitespace).joined().lowercased()
    }

    /// Единая точка входа: проверка по типу упражнения.
    static func check(_ exercise: Exercise, answer: ExerciseAnswer) -> CheckResult {
        switch exercise.kind {
        case .choose, .predict, .translate:
            if case .choice(let index) = answer { return checkChoice(exercise, selected: index) }
        case .order:
            if case .order(let seq) = answer { return checkOrder(exercise, order: seq) }
        case .fill, .trace:
            if case .text(let t) = answer { return checkText(exercise, answer: t) }
        case .write:
            if case .text(let t) = answer { return checkWrite(exercise, answer: t) }
        case nil:
            return .wrong(machineMessage: "ERR 0x00: БИТЫЙ КОНТЕНТ\nнеизвестный тип упражнения: \(exercise.type)")
        }
        return .wrong(machineMessage: "ERR 0x01: ПУСТОЙ ОТВЕТ\nответ не соответствует типу упражнения")
    }
}

/// Ответ пользователя в любой форме.
enum ExerciseAnswer {
    case choice(Int?)
    case order([Int])
    case text(String)
}
