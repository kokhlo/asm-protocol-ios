import XCTest
@testable import ASMProtocol

/// Проверки локальной логики ответов против эталонов живого контракта.
final class ExerciseCheckerTests: XCTestCase {

    private func makeExercise(type: String,
                              options: [LocalizedText]? = nil,
                              answerIndex: Int? = nil,
                              items: [LocalizedText]? = nil,
                              accepted: [String]? = nil) -> Exercise {
        Exercise(type: type,
                 prompt: LocalizedText("вопрос"),
                 intro: nil,
                 options: options,
                 answerIndex: answerIndex,
                 codeLines: nil,
                 items: items,
                 accepted: accepted,
                 hint: nil,
               explanation: nil)
    }

    // MARK: choose / predict / translate

    func testChooseCorrect() {
        let e = makeExercise(type: "choose", options: [LocalizedText("a"), LocalizedText("b")], answerIndex: 1)
        XCTAssertEqual(ExerciseChecker.check(e, answer: .choice(1)), .correct)
    }

    func testChooseWrong() {
        let e = makeExercise(type: "choose", options: [LocalizedText("a"), LocalizedText("b")], answerIndex: 1)
        if case .wrong(let msg) = ExerciseChecker.check(e, answer: .choice(0)) {
            XCTAssertTrue(msg.contains("ОТВЕТ ОТКЛОНЁН"))
        } else {
            XCTFail("ожидали ошибку")
        }
    }

    func testChooseEmptySelection() {
        let e = makeExercise(type: "choose", options: [LocalizedText("a")], answerIndex: 0)
        if case .wrong(let msg) = ExerciseChecker.check(e, answer: .choice(nil)) {
            XCTAssertTrue(msg.contains("ПУСТОЙ ОТВЕТ"))
        } else {
            XCTFail("ожидали ошибку")
        }
    }

    // MARK: order

    func testOrderCorrect() {
        let items = [LocalizedText("шаг1"), LocalizedText("шаг2"), LocalizedText("шаг3")]
        let e = makeExercise(type: "order", items: items)
        XCTAssertEqual(ExerciseChecker.check(e, answer: .order([0, 1, 2])), .correct)
    }

    func testOrderWrong() {
        let items = [LocalizedText("шаг1"), LocalizedText("шаг2"), LocalizedText("шаг3")]
        let e = makeExercise(type: "order", items: items)
        if case .wrong(let msg) = ExerciseChecker.check(e, answer: .order([2, 1, 0])) {
            XCTAssertTrue(msg.contains("ПОРЯДОК НАРУШЕН"))
        } else {
            XCTFail("ожидали ошибку")
        }
    }

    func testOrderIncomplete() {
        let items = [LocalizedText("шаг1"), LocalizedText("шаг2"), LocalizedText("шаг3")]
        let e = makeExercise(type: "order", items: items)
        if case .wrong(let msg) = ExerciseChecker.check(e, answer: .order([0])) {
            XCTAssertTrue(msg.contains("НЕПОЛНА"))
        } else {
            XCTFail("ожидали ошибку")
        }
    }

    // MARK: fill / trace

    func testFillCorrectIgnoresCaseAndSpaces() {
        let e = makeExercise(type: "fill", accepted: ["mov", "MOV"])
        XCTAssertEqual(ExerciseChecker.check(e, answer: .text("  MOV ")), .correct)
    }

    func testFillWrong() {
        let e = makeExercise(type: "fill", accepted: ["mov", "MOV"])
        if case .wrong(let msg) = ExerciseChecker.check(e, answer: .text("push")) {
            XCTAssertTrue(msg.contains("НЕ ПРИНЯТ"))
        } else {
            XCTFail("ожидали ошибку")
        }
    }

    func testTraceCorrect() {
        let e = makeExercise(type: "trace", accepted: ["10"])
        XCTAssertEqual(ExerciseChecker.check(e, answer: .text("10")), .correct)
    }

    // MARK: защита от битого контента

    func testBrokenContent() {
        let e = makeExercise(type: "choose", options: nil, answerIndex: nil)
        if case .wrong(let msg) = ExerciseChecker.check(e, answer: .choice(0)) {
            XCTAssertTrue(msg.contains("БИТЫЙ КОНТЕНТ"))
        } else {
            XCTFail("ожидали ошибку")
        }
    }
}
