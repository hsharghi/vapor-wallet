import XCTest
@testable import VaporWallet

final class VaporWalletTests: XCTestCase {
    func testExample() {
        // This is an example of a functional test case.
        // Use XCTAssert and related functions to verify your tests produce the correct
        // results.
        XCTAssertEqual(VaporWallet().text, "Hello, World!")
    }

    static var allTests = [
        ("testExample", testExample),
    ]
}
