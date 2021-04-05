import Vapor
import XCTest
import XCTVapor
import Fluent
import FluentSQLiteDriver
@testable import VaporWallet

class VaporWalletTests: XCTestCase {
    
    private var app: Application!
    
    override func setUp() {
        super.setUp()
        
        app = try! makeApplication()
        app.databases.use(.sqlite(.memory), as: .sqlite)
    }
    
    private func makeApplication() throws -> Application {

        
        return Application(.testing)
        

    }
}
