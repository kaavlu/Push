import XCTest
import Supabase
@testable import Push

private struct SampleNetworkFailure: Error {}

final class PushLogTests: XCTestCase {
    func testSafeDescriptionForPostgrestErrorIncludesOnlyTypeAndCode() {
        let error = PostgrestError(
            detail: "Key (handle)=(alice123) already exists.",
            hint: "hint text mentioning alice123",
            code: "23505",
            message: "duplicate key value violates unique constraint mentioning alice123"
        )

        let description = PushLog.safeDescription(for: error)

        XCTAssertTrue(description.contains("PostgrestError"))
        XCTAssertTrue(description.contains("23505"))
        XCTAssertFalse(description.contains("alice123"))
    }

    func testSafeDescriptionForGenericErrorIsTypeNameOnly() {
        let description = PushLog.safeDescription(for: SampleNetworkFailure())

        XCTAssertTrue(description.contains("SampleNetworkFailure"))
    }

    func testLoggedPassesThroughSuccessValue() async throws {
        let value = try await PushLog.logged("op") { 42 }

        XCTAssertEqual(value, 42)
    }

    func testLoggedRethrowsFailure() async {
        do {
            let _: Int = try await PushLog.logged("op") {
                throw SampleNetworkFailure()
            }
            XCTFail("expected logged(_:) to rethrow")
        } catch is SampleNetworkFailure {
            // expected
        } catch {
            XCTFail("wrong error type: \(error)")
        }
    }
}
