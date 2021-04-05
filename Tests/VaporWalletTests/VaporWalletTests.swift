import Vapor
import XCTest
import Fluent
import FluentSQLiteDriver
import FluentMySQLDriver
@testable import VaporWallet

class VaporWalletTests: XCTestCase {
    
    private var app: Application!
    
    override func setUp() {
        super.setUp()
        
        app = Application(.testing)
        app.databases.use(.mysql(hostname: "127.0.0.1", port: 3306, username: "root", password: "hadi2400", database: "vp-test", tlsConfiguration: .none), as: .mysql)
//                app.databases.use(.sqlite(.memory), as: .sqlite)
        
        try! migrations(app)
        try! app.autoRevert().wait()
        try! app.autoMigrate().wait()
//        try! resetDB()
        
    }
    
    func resetDB() throws {
            let db = (app.db as! SQLDatabase)
            let query = db.raw("""
                SELECT Concat('DELETE FROM ', TABLE_NAME, ';')  as truncate_query FROM INFORMATION_SCHEMA.TABLES where `TABLE_SCHEMA` = 'vp-test' and `TABLE_NAME`  not like '_fluent_%';
            """)
            
            return try query.all().flatMap { results in
                return results.compactMap { row in
                    try? row.decode(column: "truncate_query", as: String.self)
                }.map { query in
                    return (db as! MySQLDatabase).simpleQuery(query).transform(to: ())
                }.flatten(on: self.app.db.eventLoop)
            }.wait()
        }

    
    override func tearDown() {
        try! app.autoRevert().wait()
        app.shutdown()

    }
    
    
    func testAddUser() throws {
        let user = try User.create(username: "user1", on: app.db)
        XCTAssert(user.username == "user1")
    }
    
    func testUserHasNoDefaultWallet() throws {
        let userWithNoWallet = try User.create(on: app.db)
        XCTAssertThrowsError(try userWithNoWallet.defaultWallet(on: app.db).wait(), "expected throw") { (error) in
            XCTAssertEqual(error as! WalletError, WalletError.walletNotFound(name: WalletType.default.string))
        }
    }
    
    
    func testUserHasDefaultWallet() throws {
        app.databases.middleware.use(WalletMiddleware<User>())
        let userWithDefaultWallet = try User.create(on: app.db)
        let defaultWallet = try userWithDefaultWallet.defaultWallet(on: app.db).wait()
        
        XCTAssertEqual(defaultWallet.name, WalletType.default.string)
    }
    
    func testCreateWallet() throws {
        let user = try User.create(on: app.db)
        try user.createWallet(on: app.db, type: .init(string: "savings")).wait()
        
        let userWallets = try user.wallets(on: app.db).wait()
        XCTAssertEqual(userWallets.count, 1)
        XCTAssertEqual(userWallets.first?.name, "savings")
        
    }
    
    func testWalletDeposit() throws {
        app.databases.middleware.use(WalletMiddleware<User>())
        let user = try User.create(on: app.db)
        
        try! user.deposit(on: app.db, amount: 10, confirmed: true).wait()
        
        var balance = try user.walletBalance(on: app.db).wait()
        
        XCTAssertEqual(balance, 0)

        let wallet = try! user.defaultWallet(on: app.db).wait()
        let refreshedBalance = try! wallet.refreshBalance(on: app.db).wait()
        XCTAssertEqual(refreshedBalance, 10)
        
        app.databases.middleware.use(WalletTransactionMiddleware())

        try! user.deposit(on: app.db, amount: 40, confirmed: true).wait()
        
        balance = try user.walletBalance(on: app.db).wait()
        
        XCTAssertEqual(balance, 50)

    }

    func testWalletWithdraw() throws {
        app.databases.middleware.use(WalletMiddleware<User>())
        app.databases.middleware.use(WalletTransactionMiddleware())

        let user = try User.create(on: app.db)
        
        try! user.deposit(on: app.db, amount: 100, confirmed: true).wait()
        
        var balance = try user.walletBalance(on: app.db).wait()
        
        XCTAssertEqual(balance, 100)
        
        XCTAssertThrowsError(try user.withdraw(on: app.db, amount: 200).wait(), "expected throw") { (error) in
            XCTAssertEqual(error as! WalletError, WalletError.insufficientBalance)
        }

        try! user.withdraw(on: app.db, amount: 50).wait()
        
        balance = try user.walletBalance(on: app.db).wait()

        XCTAssertEqual(balance, 50)
        
    }

    
    func testWalletCanWithdraw() throws {
        app.databases.middleware.use(WalletMiddleware<User>())
        app.databases.middleware.use(WalletTransactionMiddleware())

        let user = try User.create(on: app.db)
        
        try! user.deposit(on: app.db, amount: 100, confirmed: true).wait()
        
        XCTAssertTrue(try! user.canWithdraw(on: app.db, amount: 100).wait())
        XCTAssertFalse(try! user.canWithdraw(on: app.db, amount: 200).wait())
        
    }
    
    func testMultiWallet() throws {
        app.databases.middleware.use(WalletTransactionMiddleware())

        let user = try User.create(on: app.db)
        
        try user.createWallet(on: app.db, type: .init(string: "my-wallet")).wait()
        try user.createWallet(on: app.db, type: .init(string: "savings")).wait()
        
        try user.deposit(on: app.db, to: .init(string: "my-wallet"), amount: 100, confirmed: true).wait()
        try user.deposit(on: app.db, to: .init(string: "savings"), amount: 200, confirmed: true).wait()
        
        do {
            try user.deposit(on: app.db, to: .init(string: "not-exists"), amount: 1000, confirmed: true).wait()
        } catch {
            XCTAssertEqual(error as! WalletError, WalletError.walletNotFound(name: "not-exists"))
        }

        let balance1 = try user.walletBalance(on: app.db, type: .init(string: "my-wallet")).wait()
        let balance2 = try user.walletBalance(on: app.db, type: .init(string: "savings")).wait()
        
        XCTAssertEqual(balance1, 100)
        XCTAssertEqual(balance2, 200)

    }

    
    
    
    
    private func migrations(_ app: Application) throws {
        // Initial Migrations
        app.migrations.add(CreateUser())
        app.migrations.add(CreateWallet<User>())
        app.migrations.add(CreateWalletTransaction())
    }
}

extension WalletError: Equatable {
    public static func == (lhs: WalletError, rhs: WalletError) -> Bool {
        return lhs.errorDescription == rhs.errorDescription
    }

}
