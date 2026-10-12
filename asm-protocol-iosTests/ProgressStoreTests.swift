import XCTest
@testable import ASMProtocol

/// Мок progress-API + изолированный UserDefaults: ревизии, 409, merge.
final class ProgressStoreTests: XCTestCase {

    /// Записывает вызовы и возвращает запрограммированные ответы.
    private final class MockAPI: ProgressAPI, @unchecked Sendable {
        struct PutCall { let key: String; let body: PutProgressBody }
        var putCalls: [PutCall] = []
        var progressCalls = 0
        var nextProgress: ProgressDocument?
        var putResult: Result<PutProgressResponse, Error>

        init(putResult: Result<PutProgressResponse, Error> = .success(PutProgressResponse(acceptedRevision: 1, serverRevision: 1))) {
            self.putResult = putResult
        }

        func progress(key: String) async throws -> ProgressDocument? {
            progressCalls += 1
            return nextProgress
        }

        func putProgress(key: String, body: PutProgressBody) async throws -> PutProgressResponse {
            putCalls.append(PutCall(key: key, body: body))
            switch putResult {
            case .success(let resp): return resp
            case .failure(let error): throw error
            }
        }

        func deleteProgress(key: String) async throws {}
    }

    private func makeSuite() -> UserDefaults {
        let name = "test-\(UUID().uuidString)"
        let d = UserDefaults(suiteName: name)!
        d.removePersistentDomain(forName: name)
        return d
    }

    @MainActor
    func testFirstCompletionBumpsRevisionAndPushes() async {
        let api = MockAPI()
        let store = ProgressStore(api: api, userKey: "test-key", defaults: makeSuite())

        await store.recordCompleted(lessonID: "mod0_lesson1", mode: "script_kiddie")

        XCTAssertEqual(store.clientRevision, 1)
        XCTAssertEqual(api.putCalls.count, 1)
        XCTAssertEqual(api.putCalls[0].body.clientRevision, 1)
        XCTAssertEqual(api.putCalls[0].body.done["mod0_lesson1"], ["script_kiddie"])
        XCTAssertTrue(store.isCompleted(lessonID: "mod0_lesson1", mode: "script_kiddie"))
    }

    @MainActor
    func testSecondModeSameLessonAddsEntryWithoutExtraServerCall() async {
        let api = MockAPI()
        let store = ProgressStore(api: api, userKey: "test-key", defaults: makeSuite())

        await store.recordCompleted(lessonID: "mod0_lesson1", mode: "script_kiddie")
        // повтор того же режима — ревизия не растёт, PUT не шлём
        await store.recordCompleted(lessonID: "mod0_lesson1", mode: "script_kiddie")

        XCTAssertEqual(store.clientRevision, 1)
        XCTAssertEqual(api.putCalls.count, 1)
    }

    @MainActor
    func testConflict409RecoversByRetryingWithServerRevision() async {
        let api = MockAPI(putResult: .failure(APIError.conflict(serverRevision: 5)))
        let store = ProgressStore(api: api, userKey: "test-key", defaults: makeSuite())

        await store.recordCompleted(lessonID: "mod0_lesson1", mode: "script_kiddie")

        // первая попытка rev=1 -> 409(server=5) -> ретрай rev=6 (мок всегда 409, лимит 3 попытки)
        XCTAssertGreaterThanOrEqual(api.putCalls.count, 3)
        XCTAssertEqual(api.putCalls[0].body.clientRevision, 1)
        XCTAssertEqual(api.putCalls[1].body.clientRevision, 6)
        // исчерпанные ретраи не молчат: ошибка зафиксирована, локальный прогресс цел
        XCTAssertNotNil(store.lastError)
        XCTAssertTrue(store.isCompleted(lessonID: "mod0_lesson1", mode: "script_kiddie"))
    }

    @MainActor
    func testConflictThenSuccessAcceptsNewRevision() async {
        let api = MockAPI()
        api.putResult = .failure(APIError.conflict(serverRevision: 5))
        let store = ProgressStore(api: api, userKey: "test-key", defaults: makeSuite())

        await store.recordCompleted(lessonID: "mod0_lesson1", mode: "script_kiddie")
        // после серии 409 клиент держит ревизию 6 (5+1); следующий новый режим -> 7
        api.putResult = .success(PutProgressResponse(acceptedRevision: 7, serverRevision: 7))

        await store.recordCompleted(lessonID: "mod0_lesson1", mode: "console_cowboy")

        XCTAssertEqual(store.clientRevision, 7)
        let last = api.putCalls.last!.body
        XCTAssertEqual(last.clientRevision, 7)
        XCTAssertEqual(last.done["mod0_lesson1"]?.sorted(), ["console_cowboy", "script_kiddie"])
    }

    @MainActor
    func testBootstrapMergesRemoteState() async {
        let api = MockAPI()
        api.nextProgress = ProgressDocument(
            done: ["mod1_lesson1": ["script_kiddie"]],
            position: nil,
            serverRevision: 3
        )
        let store = ProgressStore(api: api, userKey: "test-key", defaults: makeSuite())

        await store.bootstrap()

        XCTAssertEqual(store.clientRevision, 3)
        XCTAssertTrue(store.isCompleted(lessonID: "mod1_lesson1", mode: "script_kiddie"))
    }

    @MainActor
    func testTransportFailureKeepsLocalProgress() async {
        let api = MockAPI(putResult: .failure(APIError.transport("offline")))
        let store = ProgressStore(api: api, userKey: "test-key", defaults: makeSuite())

        await store.recordCompleted(lessonID: "mod0_lesson1", mode: "script_kiddie")

        // локально решено, ревизия не потеряна; сбой фиксируется в lastError
        XCTAssertTrue(store.isCompleted(lessonID: "mod0_lesson1", mode: "script_kiddie"))
        XCTAssertEqual(store.clientRevision, 1)
        XCTAssertNotNil(store.lastError)
        XCTAssertTrue(store.lastError!.contains("СИНХРОНИЗАЦИЯ ОТЛОЖЕНА"))
    }
}
