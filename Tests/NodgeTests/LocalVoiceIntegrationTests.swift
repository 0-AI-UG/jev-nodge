import XCTest
import MOSSTTSKit

final class LocalVoiceIntegrationTests: XCTestCase {
    func testRealLocalSynthesis() async throws {
        guard ProcessInfo.processInfo.environment["NODGE_TEST_LOCAL_VOICE"] == "1" else {
            throw XCTSkip("Set NODGE_TEST_LOCAL_VOICE=1 to download and exercise the real voice model")
        }
        let model = try await MOSSTTSKit()
        let result = try await model.speak(text: "Hello. The local voice is ready.")
        XCTAssertGreaterThan(result.duration, 0.5)
        XCTAssertTrue(result.audioSamples.allSatisfy { $0.isFinite })
        XCTAssertGreaterThan(result.audioSamples.map { abs($0) }.max() ?? 0, 0.001)
        print("Local voice generated \(result.duration) seconds at \(result.sampleRate) Hz")
    }
}
