import XCTVapor
import Fluent
import FluentSQLiteDriver
import Vapor

@testable import VaporWallet
@testable import App


final class VaporWalletTests: XCTestCase {
    var app: Application!
    
    func testExample() {
        // This is an example of a functional test case.
        // Use XCTAssert and related functions to verify your tests produce the correct
        // results.
        XCTAssert(true)
    }
    
    override func setUpWithError() throws {
        app = try Application.testable()
    }
    
    override func tearDownWithError() throws {
        app.shutdown()
    }
    
    
    func setup() {
//        var env = try Environment.detect()
//        try LoggingSystem.bootstrap(from: &env)
        let app = Application(.testing)
        defer { app.shutdown() }
        try configure(app)
        try app.run()
        
        
    }
    
    static var allTests = [
        ("testExample", testExample),
    ]
}

