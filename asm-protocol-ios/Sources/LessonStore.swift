import Foundation
import Observation

/// Экран урока: модуль → выбор урока → активный режим → упражнение.
@Observable
@MainActor
final class LessonStore {
    let module: Module

    private(set) var selectedLessonID: String?
    private(set) var mode: String = "script_kiddie"
    private(set) var answer: ExerciseAnswer = .choice(nil)
    private(set) var check: CheckResult?
    private(set) var hintShown = false
    var loadError: String?

    private let progress: ProgressStore

    init(module: Module, initialLessonID: String? = nil, progress: ProgressStore) {
        self.module = module
        self.selectedLessonID = initialLessonID ?? module.lessons.first?.lessonID
        self.progress = progress
        if let first = module.lessons.first {
            selectedLessonID = initialLessonID ?? first.lessonID
        }
    }

    var lessons: [Lesson] { module.lessons }

    var selectedLesson: Lesson? {
        lessons.first { $0.lessonID == selectedLessonID }
    }

    /// Доступные режимы выбранного урока в стабильном порядке.
    var availableModes: [String] {
        guard let lesson = selectedLesson else { return [] }
        let preferred = ["script_kiddie", "console_cowboy"]
        let known = preferred.filter { lesson.modes[$0] != nil }
        let rest = lesson.modes.keys.filter { !preferred.contains($0) }.sorted()
        return known + rest
    }

    var exercise: Exercise? {
        selectedLesson?.modes[mode]
    }

    var isSolved: Bool { isSolved(mode: mode) }

    /// Решён ли выбранный урок в режиме `m` — метка «✓ решено» у каждой кнопки режима своя.
    func isSolved(mode m: String) -> Bool {
        guard let lesson = selectedLesson else { return false }
        return progress.isCompleted(lessonID: lesson.lessonID, mode: m)
    }

    /// Идентичность упражнения для SwiftUI: смена урока или режима пересоздаёт его вью.
    var exerciseIdentity: String { "\(selectedLessonID ?? "")#\(mode)" }

    // MARK: - Ввод, производный от answer (единственный источник правды)

    var selectedOption: Int? {
        if case .choice(let index) = answer { return index }
        return nil
    }

    var textAnswer: String {
        if case .text(let text) = answer { return text }
        return ""
    }

    var orderPicks: [Int] {
        if case .order(let picks) = answer { return picks }
        return []
    }

    /// Порядок показа пула шагов order: «колесо», как в вебе, а не авторский порядок.
    var orderPool: [Int] {
        ExerciseChecker.initialOrder(exercise?.items?.count ?? 0)
    }

    func toggleOrderPick(_ index: Int) {
        var picks = orderPicks
        if let pos = picks.firstIndex(of: index) {
            picks.remove(at: pos)
        } else {
            picks.append(index)
        }
        answer = .order(picks)
    }

    func selectLesson(_ id: String) {
        selectedLessonID = id
        resetAnswerState()
    }

    func selectMode(_ m: String) {
        mode = m
        resetAnswerState()
    }

    func setAnswer(_ newAnswer: ExerciseAnswer) {
        answer = newAnswer
    }

    func submit() async {
        guard let exercise else { return }
        let result = ExerciseChecker.check(exercise, answer: answer)
        check = result
        if result.isCorrect, let lesson = selectedLesson {
            await progress.recordCompleted(lessonID: lesson.lessonID, mode: mode)
        }
    }

    func showHint() {
        hintShown = true
    }

    func resetAnswerState() {
        answer = .choice(nil)
        check = nil
        hintShown = false
    }
}
