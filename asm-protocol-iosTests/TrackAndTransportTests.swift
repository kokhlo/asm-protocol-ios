import XCTest
@testable import ASMProtocol

/// Жалоба «в треке Ada про регистры»: секция SYS без подписи читалась как продолжение ADA,
/// а подпись поля ввода говорила «без учёта регистра». Плюс клиент ходил по http на IP.
final class TrackAndTransportTests: XCTestCase {

    // MARK: - Треки

    func testSysTrackIsNamedSystemsNotSys() {
        XCTAssertEqual(Track.sys.title, "СИСТЕМЫ")
        XCTAssertEqual(Track.ada.title, "ADA")
    }

    func testEveryTrackHasDistinctNonEmptySubtitle() {
        let subtitles = Track.allCases.map(\.subtitle)
        XCTAssertFalse(subtitles.contains(where: \.isEmpty))
        XCTAssertEqual(Set(subtitles).count, Track.allCases.count)
    }

    func testSystemsSubtitleSaysItSitsOnTopOfAsmAndC() {
        XCTAssertTrue(Track.sys.subtitle.contains("ASM/C"))
        XCTAssertFalse(Track.sys.subtitle.lowercased().contains("ada"))
    }

    func testAdaHeaderAndSubtitleNeverMentionRegisters() {
        XCTAssertFalse(Track.ada.title.lowercased().contains("регистр"))
        XCTAssertFalse(Track.ada.subtitle.lowercased().contains("регистр"))
    }

    // MARK: - Подпись под полем ввода

    func testTextInputCaptionsNeverSayRegister() {
        for kind in [Exercise.Kind.fill, .trace, .write] {
            XCTAssertFalse(kind.textInputCaption.lowercased().contains("регистр"),
                           "\(kind): \(kind.textInputCaption)")
        }
    }

    func testWriteCaptionDescribesPatternCheckNotStringMatch() {
        XCTAssertTrue(Exercise.Kind.write.textInputCaption.contains("шаблонам"))
        XCTAssertNotEqual(Exercise.Kind.write.textInputCaption, Exercise.Kind.fill.textInputCaption)
        XCTAssertEqual(Exercise.Kind.fill.textInputCaption, Exercise.Kind.trace.textInputCaption)
    }

    /// Подпись fill/trace обещает: пробелы и регистр букв не важны — так и нормализует чекер.
    func testFillCaptionMatchesCheckerNormalization() {
        XCTAssertEqual(ExerciseChecker.normalize("  MOV  Rax, 1 "), ExerciseChecker.normalize("movrax,1"))
    }

    // MARK: - Транспорт

    func testInfoPlistApiBaseUrlIsHttpsProduction() {
        let raw = Bundle.main.object(forInfoDictionaryKey: "ASM_API_BASE_URL") as? String
        XCTAssertEqual(raw, "https://asm-protocol.tech")
    }

    func testDefaultClientUsesHttps() {
        let url = APIClient().baseURL
        XCTAssertEqual(url.scheme, "https")
        XCTAssertEqual(url.host, "asm-protocol.tech")
    }

    func testAppTransportSecurityHasNoExceptions() {
        XCTAssertNil(Bundle.main.object(forInfoDictionaryKey: "NSAppTransportSecurity"))
    }
}
