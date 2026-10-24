import XCTest
@testable import ASMProtocol

/// Дефекты экрана урока и главного экрана (аудит 05 §1.5, D1–D4).
@MainActor
final class LessonScreenDefectsTests: XCTestCase {

    private final class StubAPI: ProgressAPI, @unchecked Sendable {
        func progress(key: String) async throws -> ProgressDocument? { nil }
        func putProgress(key: String, body: PutProgressBody) async throws -> PutProgressResponse {
            PutProgressResponse(acceptedRevision: body.clientRevision, serverRevision: body.clientRevision)
        }
        func deleteProgress(key: String) async throws {}
    }

    private func makeProgress() -> ProgressStore {
        let name = "test-\(UUID().uuidString)"
        let defaults = UserDefaults(suiteName: name)!
        defaults.removePersistentDomain(forName: name)
        return ProgressStore(api: StubAPI(), userKey: "test-key", defaults: defaults)
    }

    private func exercise(_ type: String, items: [LocalizedText]? = nil, accepted: [String]? = nil,
                          options: [LocalizedText]? = nil, answerIndex: Int? = nil) -> Exercise {
        Exercise(type: type, prompt: LocalizedText("вопрос"), intro: nil, options: options,
                 answerIndex: answerIndex, codeLines: nil, items: items, accepted: accepted,
                 expectedPatterns: nil, forbiddenPatterns: nil, hint: nil, explanation: nil)
    }

    private func module(_ lessons: [Lesson]) -> Module {
        Module(id: "mod16_types", module: 16, tier: "ada", title: LocalizedText("t"),
               description: LocalizedText("d"), storyIntro: nil, prerequisites: nil, lessons: lessons)
    }

    private func twoModeLesson(_ id: String) -> Lesson {
        Lesson(lessonID: id,
               modes: ["script_kiddie": exercise("choose", options: [LocalizedText("a"), LocalizedText("b")],
                                                 answerIndex: 1),
                       "console_cowboy": exercise("fill", accepted: ["x"])],
               skills: nil)
    }

    // MARK: D1 — метка «✓ решено» у каждой кнопки режима своя

    func testSolvedMarkIsPerModeNotForActiveMode() async {
        let progress = makeProgress()
        let store = LessonStore(module: module([twoModeLesson("mod16_lesson1")]), progress: progress)
        store.selectMode("script_kiddie")
        store.setAnswer(.choice(1))
        await store.submit()

        XCTAssertTrue(store.isSolved(mode: "script_kiddie"))
        XCTAssertFalse(store.isSolved(mode: "console_cowboy"),
                       "решён только активный режим — у второй кнопки метки быть не должно")
        XCTAssertTrue(store.isSolved)
    }

    // MARK: D2 — смена режима сбрасывает ввод и пересоздаёт вью упражнения

    func testModeSwitchResetsAllInputAndChangesIdentity() {
        let store = LessonStore(module: module([twoModeLesson("mod16_lesson1")]), progress: makeProgress())
        store.selectMode("console_cowboy")
        store.setAnswer(.text("старый ввод"))
        XCTAssertEqual(store.textAnswer, "старый ввод")
        let before = store.exerciseIdentity

        store.selectMode("script_kiddie")

        XCTAssertNotEqual(store.exerciseIdentity, before)
        XCTAssertEqual(store.textAnswer, "")
        XCTAssertNil(store.selectedOption)
        XCTAssertEqual(store.orderPicks, [])
        XCTAssertNil(store.check)
    }

    func testChoiceHighlightIsDerivedFromAnswerAndClearedOnModeSwitch() {
        let store = LessonStore(module: module([twoModeLesson("mod16_lesson1")]), progress: makeProgress())
        store.selectMode("script_kiddie")
        store.setAnswer(.choice(1))
        XCTAssertEqual(store.selectedOption, 1)

        store.selectMode("console_cowboy")
        store.selectMode("script_kiddie")
        XCTAssertNil(store.selectedOption, "подсветка не должна пережить смену режима")
    }

    func testLessonSwitchChangesIdentity() {
        let store = LessonStore(module: module([twoModeLesson("mod16_lesson1"), twoModeLesson("mod16_lesson2")]),
                                progress: makeProgress())
        let before = store.exerciseIdentity
        store.selectLesson("mod16_lesson2")
        XCTAssertNotEqual(store.exerciseIdentity, before)
    }

    // MARK: D4 — пул order перемешан «колесом», как в вебе, id по индексу

    func testInitialOrderMatchesWebWheel() {
        XCTAssertEqual(ExerciseChecker.initialOrder(0), [])
        XCTAssertEqual(ExerciseChecker.initialOrder(1), [0])
        XCTAssertEqual(ExerciseChecker.initialOrder(2), [1, 0])
        XCTAssertEqual(ExerciseChecker.initialOrder(4), [2, 3, 0, 1])
        XCTAssertEqual(ExerciseChecker.initialOrder(5), [2, 3, 4, 0, 1])
    }

    func testInitialOrderIsPermutationWithoutFixedPoints() {
        for n in 2...12 {
            let order = ExerciseChecker.initialOrder(n)
            XCTAssertEqual(order.sorted(), Array(0..<n))
            for (position, item) in order.enumerated() {
                XCTAssertNotEqual(position, item, "n=\(n): шаг \(item) стоит на своём месте")
            }
        }
    }

    func testOrderPoolIsNotAuthorOrderAndTappingTopToBottomIsWrong() {
        let items = ["a", "b", "c", "d"].map { LocalizedText($0) }
        let lesson = Lesson(lessonID: "mod1_lesson1", modes: ["script_kiddie": exercise("order", items: items)],
                            skills: nil)
        let store = LessonStore(module: module([lesson]), progress: makeProgress())

        XCTAssertNotEqual(store.orderPool, [0, 1, 2, 3])
        for index in store.orderPool { store.toggleOrderPick(index) }
        XCTAssertFalse(ExerciseChecker.check(store.exercise!, answer: store.answer).isCorrect,
                       "«тапни сверху вниз» больше не решает задачу")
    }

    func testOrderPoolHandlesDuplicateTextsAndPicksToggle() {
        let items = ["mov", "mov", "ret"].map { LocalizedText($0) }
        let lesson = Lesson(lessonID: "mod1_lesson1", modes: ["script_kiddie": exercise("order", items: items)],
                            skills: nil)
        let store = LessonStore(module: module([lesson]), progress: makeProgress())

        XCTAssertEqual(Set(store.orderPool).count, 3, "одинаковые тексты не должны схлопывать пул")

        store.toggleOrderPick(1)
        store.toggleOrderPick(0)
        XCTAssertEqual(store.orderPicks, [1, 0])
        store.toggleOrderPick(1)
        XCTAssertEqual(store.orderPicks, [0])

        store.toggleOrderPick(1)
        store.toggleOrderPick(2)
        XCTAssertTrue(ExerciseChecker.check(store.exercise!, answer: store.answer).isCorrect)
    }

    // MARK: D3 — неизвестный tier не пропадает

    private func summary(_ id: String, _ number: Int, _ tier: String) -> ModuleSummary {
        ModuleSummary(id: id, module: number, tier: tier, title: LocalizedText(id),
                      description: LocalizedText(""), icon: nil, lessonsCount: 5)
    }

    func testUnknownTierGoesToTailSection() {
        let modules = [
            summary("mod24_go", 24, "go"),
            summary("mod19_syscalls", 19, "sys"),
            summary("mod16_types", 16, "ada"),
            summary("mod1", 1, "asm"),
            summary("mod30_zig", 30, "zig"),
        ]
        let sections = ModulesStore.sections(for: modules)

        XCTAssertEqual(sections.map(\.id), ["asm", "ada", "sys", "go", "zig"])
        XCTAssertEqual(sections.last?.title, "ZIG")
        XCTAssertEqual(sections.flatMap(\.modules).count, modules.count, "ни один модуль не потерян")
    }

    func testKnownTracksKeepCanonicalOrderAndModuleSorting() {
        let modules = [summary("m3", 3, "asm"), summary("m0", 0, "prologue"), summary("m2", 2, "asm")]
        let sections = ModulesStore.sections(for: modules)

        XCTAssertEqual(sections.map(\.id), ["prologue", "asm"])
        XCTAssertEqual(sections[1].modules.map(\.module), [2, 3])
        XCTAssertEqual(sections[1].title, Track.asm.title)
        XCTAssertEqual(sections[1].subtitle, Track.asm.subtitle)
    }
}
