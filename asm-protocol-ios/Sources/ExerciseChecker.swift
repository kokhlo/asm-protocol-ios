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

    // MARK: fill / trace / write — сравнение с accepted (без учёта регистра/пробелов)

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

    static func normalize(_ s: String) -> String {
        let trimmed = s.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        return trimmed.split(whereSeparator: \.isWhitespace).joined(separator: " ")
    }

    /// Единая точка входа: проверка по типу упражнения.
    static func check(_ exercise: Exercise, answer: ExerciseAnswer) -> CheckResult {
        switch exercise.kind {
        case .choose, .predict, .translate:
            if case .choice(let index) = answer { return checkChoice(exercise, selected: index) }
        case .order:
            if case .order(let seq) = answer { return checkOrder(exercise, order: seq) }
        case .fill, .trace, .write:
            if case .text(let t) = answer { return checkText(exercise, answer: t) }
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
