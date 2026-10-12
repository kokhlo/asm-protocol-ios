import XCTest
@testable import ASMProtocol

/// Контракт progress-API: тело PUT должно содержать ровно три ключа верхнего уровня,
/// включая position при null (сервер отвечает 400, если ключ пропал).
final class PutProgressBodyEncodingTests: XCTestCase {

    func testPositionNilStillEncodesKey() throws {
        let body = PutProgressBody(done: ["l1": ["script_kiddie"]], position: nil, clientRevision: 3)
        let json = try JSONEncoder().encode(body)
        let dict = try XCTUnwrap(JSONSerialization.jsonObject(with: json) as? [String: Any])
        XCTAssertEqual(Set(dict.keys), ["done", "position", "client_revision"])
        XCTAssertTrue(dict["position"] is NSNull)
    }

    func testPositionValueEncodes() throws {
        let body = PutProgressBody(done: [:],
                                   position: ProgressPosition(moduleId: "mod0_prologue", lesson: 2),
                                   clientRevision: 1)
        let json = try JSONEncoder().encode(body)
        let dict = try XCTUnwrap(JSONSerialization.jsonObject(with: json) as? [String: Any])
        let pos = try XCTUnwrap(dict["position"] as? [String: Any])
        XCTAssertEqual(pos["moduleId"] as? String, "mod0_prologue")
        XCTAssertEqual(pos["lesson"] as? Int, 2)
    }
}
