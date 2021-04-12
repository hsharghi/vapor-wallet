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
        app.logger.logLevel = .debug
        app.databases.use(.mysql(hostname: "127.0.0.1", port: 3306, username: "root", password: "hadi2400", database: "vp-test", tlsConfiguration: .none), as: .mysql)
//        app.databases.use(.sqlite(.memory), as: .sqlite)
        
        try! migrations(app)
        try! app.autoRevert().wait()
        try! app.autoMigrate().wait()
        try! resetDB()
        
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
        XCTAssertThrowsError(try userWithNoWallet.walletsRepository(on: app.db).default().wait(), "expected throw") { (error) in
            XCTAssertEqual(error as! WalletError, WalletError.walletNotFound(name: WalletType.default.value))
        }
    }
    

    func testUserHasDefaultWallet() throws {
        app.databases.middleware.use(WalletMiddleware<User>())
        let userWithDefaultWallet = try User.create(on: app.db)
        let defaultWallet = try userWithDefaultWallet.walletsRepository(on: app.db).default().wait()

        XCTAssertEqual(defaultWallet.name, WalletType.default.value)
    }

    func testCreateWallet() throws {
        let (_, wallets) = setupUserAndWalletsRepo(on: app.db)
        try wallets.create(type: .init(name: "savings")).transform(to: ()).wait()

        let userWallets = try wallets.all().wait()
        XCTAssertEqual(userWallets.count, 1)
        XCTAssertEqual(userWallets.first?.name, "savings")

    }

    func testWalletDeposit() throws {
        app.databases.middleware.use(WalletMiddleware<User>())
        let (_, wallets) = setupUserAndWalletsRepo(on: app.db)


        try! wallets.deposit(amount: 10).wait()
        let balance = try wallets.balance().wait()

        XCTAssertEqual(balance, 0)

        let refreshedBalance = try wallets.refreshBalance().wait()
        XCTAssertEqual(refreshedBalance, 10)

    }
    
    func testWalletTransactionMiddleware() throws {
        app.databases.middleware.use(WalletMiddleware<User>())
        app.databases.middleware.use(WalletTransactionMiddleware())
        
        let user = try User.create(on: app.db)
        let walletsRepoWithMiddleware = user.walletsRepository(on: app.db)

        try! walletsRepoWithMiddleware.deposit(amount: 40).wait()

        let balance = try walletsRepoWithMiddleware.balance().wait()

        XCTAssertEqual(balance, 40)

    }

    func testWalletWithdraw() throws {
        app.databases.middleware.use(WalletMiddleware<User>())
        app.databases.middleware.use(WalletTransactionMiddleware())

        let (_, wallets) = setupUserAndWalletsRepo(on: app.db)

        try wallets.deposit(amount: 100).wait()

        var balance = try wallets.balance().wait()

        XCTAssertEqual(balance, 100)

        XCTAssertThrowsError(try wallets.withdraw(amount: 200).wait(), "expected throw") { (error) in
            XCTAssertEqual(error as! WalletError, WalletError.insufficientBalance)
        }

        try! wallets.withdraw(amount: 50).wait()

        balance = try wallets.balance().wait()

        XCTAssertEqual(balance, 50)

    }


    func testWalletCanWithdraw() throws {
        app.databases.middleware.use(WalletMiddleware<User>())
        app.databases.middleware.use(WalletTransactionMiddleware())

        let (_, wallets) = setupUserAndWalletsRepo(on: app.db)

        try wallets.deposit(amount: 100).wait()

        XCTAssertTrue(try! wallets.canWithdraw(amount: 100).wait())
        XCTAssertFalse(try! wallets.canWithdraw(amount: 200).wait())

    }

    func testMultiWallet() throws {
        app.databases.middleware.use(WalletTransactionMiddleware())
        app.databases.middleware.use(WalletTransactionMiddleware())

        let (_, wallets) = setupUserAndWalletsRepo(on: app.db)

        let savingsWallet = WalletType(name: "savings")
        let myWallet = WalletType(name: "my-wallet")
        let notExistsWallet = WalletType(name: "not-exists")

        try wallets.create(type: myWallet).transform(to: ()).wait()
        try wallets.create(type: savingsWallet).transform(to: ()).wait()
        
        try wallets.deposit(to: myWallet, amount: 100).wait()
        try wallets.deposit(to: savingsWallet, amount: 200).wait()

        do {
            try wallets.deposit(to: notExistsWallet, amount: 1000).wait()
        } catch {
            XCTAssertEqual(error as! WalletError, WalletError.walletNotFound(name: "not-exists"))
        }

        let balance1 = try wallets.balance(type: myWallet).wait()
        let balance2 = try wallets.balance(type: savingsWallet).wait()

        XCTAssertEqual(balance1, 100)
        XCTAssertEqual(balance2, 200)

    }


    func testTransactionMetadata() throws {
        app.databases.middleware.use(WalletMiddleware<User>())

        let (_, wallets) = setupUserAndWalletsRepo(on: app.db)

        try wallets.deposit(amount: 100, meta: ["description": "payment of taxes"]).wait()
        
        let transaction = try wallets.default().wait()
            .$transactions.get(on: app.db).wait()
            .first!
        
        XCTAssertEqual(transaction.meta!["description"] , "payment of taxes")
    }

    func testWalletDecimalBalance() throws {
        app.databases.middleware.use(WalletTransactionMiddleware())

        let user = try User.create(on: app.db)
        let wallets = user.walletsRepository(on: app.db)
        try wallets.create(type: .default, decimalPlaces: 2).wait()

        try wallets.deposit(amount: 100).wait()
        
        var balance = try wallets.balance().wait()
        XCTAssertEqual(balance, 100)
        
        try wallets.deposit(amount: 1.45).wait()
        balance = try wallets.balance().wait()
        XCTAssertEqual(balance, 245)
        
        balance = try wallets.balance(asDecimal: true).wait()
        XCTAssertEqual(balance, 2.45)
        
        
        // decmial values will be truncated to wallet's decimalPlace value
        try wallets.deposit(amount: 1.555).wait()
        balance = try wallets.balance().wait()
        XCTAssertEqual(balance, 400)

    }
    
    
    func testConfirmTransaction() throws {
        app.databases.middleware.use(WalletMiddleware<User>())
        app.databases.middleware.use(WalletTransactionMiddleware())

        let (_, wallets) = setupUserAndWalletsRepo(on: app.db)
        
        try wallets.deposit(amount: 10, confirmed: true).wait()
        sleep(1)
        try wallets.deposit(amount: 40, confirmed: false).wait()

        var balance = try wallets.balance().wait()
        let unconfirmedBalance = try wallets.balance(withUnconfirmed: true).wait()
        XCTAssertEqual(balance, 10)
        XCTAssertEqual(unconfirmedBalance, 50)

        let transaction = try wallets.unconfirmedTransactions()
            .wait()
            .items.first!

        balance = try wallets.confirm(transaction: transaction).wait()

        XCTAssertEqual(balance, 50)

    }
    
    func testConfirmAllTransactionsOfWallet() throws {
        app.databases.middleware.use(WalletMiddleware<User>())
        app.databases.middleware.use(WalletTransactionMiddleware())

        let (_, wallets) = setupUserAndWalletsRepo(on: app.db)
        
        try wallets.deposit(amount: 10, confirmed: false).wait()
        try wallets.deposit(amount: 40, confirmed: false).wait()
        
        var balance = try wallets.balance().wait()
        XCTAssertEqual(balance, 0)

        balance = try wallets.confirmAll().wait()

        XCTAssertEqual(balance, 50)


    }
    
    private func setupUserAndWalletsRepo(on: Database) -> (User, WalletsRepository<User>) {
        let user = try! User.create(on: app.db)
        let wallets = user.walletsRepository(on: app.db)

        return (user, wallets)
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
