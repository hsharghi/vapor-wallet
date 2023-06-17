import Vapor
import XCTest
import Fluent
import FluentSQLiteDriver
import FluentMySQLDriver
import FluentPostgresDriver

@testable import VaporWallet

class VaporWalletTests: XCTestCase {
    
    private var app: Application!
    
    override func setUp() {
        super.setUp()
        
        app = Application(.testing)
        app.logger.logLevel = .debug
        
        //        app.databases.use(.postgres(
        //            hostname: "localhost",
        //            port: 5432,
        //            username: "catgpt",
        //            password: "catgpt",
        //            database: "catgpt"
        //        ), as: .psql)
        //                app.databases.use(.mysql(hostname: "127.0.0.1", port: 3306, username: "vapor", password: "vapor", database: "vp-test"), as: .mysql)
        app.databases.use(.sqlite(.memory), as: .sqlite)
        
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
    
    
    func testAddUser() async throws {
        let user = try await User.create(username: "user1", on: app.db)
        XCTAssert(user.username == "user1")
    }
    
    func testAddGame() async throws {
        let game = try await Game.create(name: "new_game", on: app.db)
        XCTAssert(game.name == "new_game")
    }
    
    func testUserHasNoDefaultWallet() async throws {
        let userWithNoWallet = try await User.create(on: app.db)
        await XCTAssertThrowsError(try await userWithNoWallet.walletsRepository(on: app.db).defaultAsync(), "expected throw") { (error) in
            XCTAssertEqual(error as! WalletError, WalletError.walletNotFound(name: WalletType.default.value))
        }
    }
    
    func testUserHasDefaultWallet() async throws {
        app.databases.middleware.use(AsyncWalletMiddleware<User>())
        let userWithDefaultWallet = try await User.create(on: app.db)
        let defaultWallet = try await userWithDefaultWallet.walletsRepository(on: app.db).defaultAsync()
        
        XCTAssertEqual(defaultWallet.name, WalletType.default.value)
    }
    
    func testCreateWallet() async throws {
        let (_, wallets) = try await setupUserAndWalletsRepo(on: app.db)
        try await wallets.createAsync(type: .init(name: "savings"))
        
        let userWallets = try await wallets.allAsync()
        XCTAssertEqual(userWallets.count, 1)
        XCTAssertEqual(userWallets.first?.name, "savings")
        
    }
    
    func testWalletDeposit() async throws {
        app.databases.middleware.use(AsyncWalletMiddleware<User>())
        let (_, wallets) = try await setupUserAndWalletsRepo(on: app.db)
        
        
        try! await wallets.depositAsync(amount: 10)
        let balance = try await wallets.balanceAsync()
        
        XCTAssertEqual(balance, 0)
        
        let refreshedBalance = try await wallets.refreshBalanceAsync()
        XCTAssertEqual(refreshedBalance, 10)
        
    }
    
    func testWalletTransactionMiddleware() async throws {
        app.databases.middleware.use(AsyncWalletMiddleware<User>())
        app.databases.middleware.use(AsyncWalletTransactionMiddleware())
        
        let user = try await User.create(on: app.db)
        let walletsRepoWithMiddleware = user.walletsRepository(on: app.db)
        
        try! await walletsRepoWithMiddleware.depositAsync(amount: 40)
        
        let balance = try await walletsRepoWithMiddleware.balanceAsync()
        
        XCTAssertEqual(balance, 40)
        
    }
    
    func testWalletWithdraw() async throws {
        app.databases.middleware.use(AsyncWalletMiddleware<User>())
        app.databases.middleware.use(AsyncWalletTransactionMiddleware())
        
        let (_, wallets) = try await setupUserAndWalletsRepo(on: app.db)
        
        try await wallets.depositAsync(amount: 100)
        
        var balance = try await wallets.balanceAsync()
        
        XCTAssertEqual(balance, 100)
        
        await XCTAssertThrowsError(try await wallets.withdrawAsync(amount: 200), "expected throw") { (error) in
            XCTAssertEqual(error as! WalletError, WalletError.insufficientBalance)
        }
        
        try! await wallets.withdrawAsync(amount: 50)
        
        balance = try await wallets.balanceAsync()
        
        XCTAssertEqual(balance, 50)
        
    }
    
    
    func testWalletCanWithdraw() async throws {
        app.databases.middleware.use(AsyncWalletMiddleware<User>())
        app.databases.middleware.use(AsyncWalletTransactionMiddleware())
        
        let (_, wallets) = try await setupUserAndWalletsRepo(on: app.db)
        
        try await wallets.depositAsync(amount: 100)
        
        var can = try! await wallets.canWithdrawAsync(amount: 100)
        XCTAssertTrue(can)
        can = try! await wallets.canWithdrawAsync(amount: 200)
        XCTAssertFalse(can)
        
    }
    
    func testWalletCanWithdrawWithMinAllowedBalance() async throws {
        app.databases.middleware.use(AsyncWalletMiddleware<User>())
        app.databases.middleware.use(AsyncWalletTransactionMiddleware())
        
        let (_, wallets) = try await setupUserAndWalletsRepo(on: app.db)
        try await wallets.createAsync(type: .init(name: "magical"), minAllowedBalance: -50)
        
        try await wallets.depositAsync(to: .init(name: "magical"), amount: 100)
        var can = try await wallets.canWithdrawAsync(from: .default, amount: 130)
        XCTAssertFalse(can)
        
        can = try await wallets.canWithdrawAsync(from: .init(name: "magical"), amount: 130)
        XCTAssertTrue(can)
    }
    
    func testMultiWallet() async throws {
        app.databases.middleware.use(AsyncWalletTransactionMiddleware())
        app.databases.middleware.use(AsyncWalletTransactionMiddleware())
        
        let (_, wallets) = try await setupUserAndWalletsRepo(on: app.db)
        
        let savingsWallet = WalletType(name: "savings")
        let myWallet = WalletType(name: "my-wallet")
        let notExistsWallet = WalletType(name: "not-exists")
        
        try await wallets.createAsync(type: myWallet)
        try await wallets.createAsync(type: savingsWallet)
        
        try await wallets.depositAsync(to: myWallet, amount: 100)
        try await wallets.depositAsync(to: savingsWallet, amount: 200)
        
        do {
            try await wallets.depositAsync(to: notExistsWallet, amount: 1000)
        } catch {
            XCTAssertEqual(error as! WalletError, WalletError.walletNotFound(name: "not-exists"))
        }
        
        let balance1 = try await wallets.balanceAsync(type: myWallet)
        let balance2 = try await wallets.balanceAsync(type: savingsWallet)
        
        XCTAssertEqual(balance1, 100)
        XCTAssertEqual(balance2, 200)
        
    }
    
    
    func testTransactionMetadata() async throws {
        app.databases.middleware.use(AsyncWalletMiddleware<User>())
        
        let (_, wallets) = try await setupUserAndWalletsRepo(on: app.db)
        
        try await wallets.depositAsync(amount: 100, meta: ["description": "tax payments"])
        
        let transaction = try await wallets.defaultAsync()
            .$transactions.get(on: app.db)
            .first!
        
        XCTAssertEqual(transaction.meta!["description"] , "tax payments")
    }
    
    func testWalletDecimalBalance() async throws {
        app.databases.middleware.use(AsyncWalletTransactionMiddleware())
        
        let user = try await User.create(on: app.db)
        let wallets = user.walletsRepository(on: app.db)
        try await wallets.createAsync(type: .default, decimalPlaces: 2)
        
        try await wallets.depositAsync(amount: 100)
        
        var balance = try await wallets.balanceAsync()
        XCTAssertEqual(balance, 100)
        
        try await wallets.depositAsync(amount: 1.45)
        balance = try await wallets.balanceAsync()
        XCTAssertEqual(balance, 245)
        
        balance = try await wallets.balanceAsync(asDecimal: true)
        XCTAssertEqual(balance, 2.45)
        
        
        // decmial values will be truncated to wallet's decimalPlace value
        try await wallets.depositAsync(amount: 1.555)
        balance = try await wallets.balanceAsync()
        XCTAssertEqual(balance, 400)
        
    }
    
    
    func testConfirmTransaction() async throws {
        app.databases.middleware.use(AsyncWalletMiddleware<User>())
        app.databases.middleware.use(AsyncWalletTransactionMiddleware())
        
        let (_, wallets) = try await setupUserAndWalletsRepo(on: app.db)
        
        try await wallets.depositAsync(amount: 10, confirmed: true)
        sleep(1)
        try await wallets.depositAsync(amount: 40, confirmed: false)
        
        var balance = try await wallets.balanceAsync()
        let unconfirmedBalance = try await wallets.balanceAsync(withUnconfirmed: true)
        XCTAssertEqual(balance, 10)
        XCTAssertEqual(unconfirmedBalance, 50)
        
        let transaction = try await wallets
            .unconfirmedTransactionsAsync()
            .items
            .first!
        
        balance = try await wallets.confirmAsync(transaction: transaction)
        
        XCTAssertEqual(balance, 50)
        
    }
    
    func testConfirmAllTransactionsOfWallet() async throws {
        app.databases.middleware.use(AsyncWalletMiddleware<User>())
        app.databases.middleware.use(AsyncWalletTransactionMiddleware())
        
        let (_, wallets) = try await setupUserAndWalletsRepo(on: app.db)
        
        try await wallets.depositAsync(amount: 10, confirmed: false)
        try await wallets.depositAsync(amount: 40, confirmed: false)
        
        var balance = try await wallets.balanceAsync()
        XCTAssertEqual(balance, 0)
        
        balance = try await wallets.confirmAllAsync()
        
        XCTAssertEqual(balance, 50)
    }
    
    
    func testTransferBetweenAUsersWallets() async throws {
        app.databases.middleware.use(AsyncWalletMiddleware<User>())
        app.databases.middleware.use(AsyncWalletTransactionMiddleware())
        
        let (_, wallets) = try await setupUserAndWalletsRepo(on: app.db)
        
        let wallet1 = WalletType(name: "wallet1")
        let wallet2 = WalletType(name: "wallet2")
        
        try await wallets.createAsync(type: wallet1)
        try await wallets.createAsync(type: wallet2)
        
        
        try await wallets.depositAsync(to: wallet1, amount: 100)
        
        try await wallets.transferAsync(from: wallet1, to: wallet2, amount: 20)
        
        let balance1 = try await wallets.balanceAsync(type: wallet1)
        let balance2 = try await wallets.balanceAsync(type: wallet2)
        
        XCTAssertEqual(balance1, 80)
        XCTAssertEqual(balance2, 20)
        
    }
    
    func testTransferBetweenTwoUsersWallets() async throws {
        app.databases.middleware.use(AsyncWalletMiddleware<User>())
        app.databases.middleware.use(AsyncWalletTransactionMiddleware())
        
        let user1 = try await User.create(username: "user1", on: app.db)
        let user2 = try await User.create(username: "user2", on: app.db)
        
        let repo1 = user1.walletsRepository(on: app.db)
        let repo2 = user2.walletsRepository(on: app.db)
        
        try await repo1.depositAsync(amount: 100)
        
        try await repo1.transferAsync(from: try await repo1.defaultAsync(), to: try await repo2.defaultAsync(), amount: 20)
        
        var balance1 = try await repo1.balanceAsync()
        var balance2 = try await repo2.balanceAsync()
        
        XCTAssertEqual(balance1, 80)
        XCTAssertEqual(balance2, 20)
        
        try await repo1.transferAsync(from: .default, to: try await repo2.defaultAsync(), amount: 20)
        
        balance1 = try await repo1.balanceAsync()
        balance2 = try await repo2.balanceAsync()
        
        XCTAssertEqual(balance1, 60)
        XCTAssertEqual(balance2, 40)
        
        let savings = WalletType(name: "savings")
        try await repo1.createAsync(type: savings)
        
        try await repo1.transferAsync(from: .default, to: savings, amount: 20)
        
        balance1 = try await repo1.balanceAsync()
        balance2 = try await repo1.balanceAsync(type: savings)
        
        XCTAssertEqual(balance1, 40)
        XCTAssertEqual(balance2, 20)
        
    }
    
    
    func testMultiModelWallet() async throws {
        app.databases.middleware.use(AsyncWalletMiddleware<User>())
        app.databases.middleware.use(AsyncWalletMiddleware<Game>())
        app.databases.middleware.use(AsyncWalletTransactionMiddleware())
        
        let user = try await User.create(username: "user1", on: app.db)
        let game = Game(id: user.id, name: "game1")
        try await game.save(on: app.db)
        
        let repo1 = user.walletsRepository(on: app.db)
        let repo2 = game.walletsRepository(on: app.db)
        
        try await repo1.depositAsync(amount: 100)
        try await repo2.depositAsync(amount: 500)
        
        let balance1 = try await repo1.balanceAsync()
        let balance2 = try await repo2.balanceAsync()
        
        XCTAssertEqual(balance1, 100)
        XCTAssertEqual(balance2, 500)
        
    }
    
    func testMultiModelWalletTransfer() async throws {
        app.databases.middleware.use(AsyncWalletMiddleware<User>())
        app.databases.middleware.use(AsyncWalletMiddleware<Game>())
        app.databases.middleware.use(AsyncWalletTransactionMiddleware())
        
        let user = try await User.create(username: "user1", on: app.db)
        let game = Game(id: user.id, name: "game1")
        try await game.save(on: app.db)
        
        let repo1 = user.walletsRepository(on: app.db)
        let repo2 = game.walletsRepository(on: app.db)
        
        try await repo1.depositAsync(amount: 100)
        try await repo2.depositAsync(amount: 500)
        
        let userWallet = try await repo1.defaultAsync()
        let gameWallet = try await repo2.defaultAsync()
        
        try await repo1.transferAsync(from: gameWallet, to: userWallet, amount: 100)
        
        let balance1 = try await repo1.balanceAsync()
        let balance2 = try await repo2.balanceAsync()
        
        XCTAssertEqual(balance1, 200)
        XCTAssertEqual(balance2, 400)
    }
    
    
    
    
    private func setupUserAndWalletsRepo(on: Database) async throws -> (User, WalletsRepository<User>)  {
        let user = try! await User.create(on: app.db)
        let wallets = user.walletsRepository(on: app.db)
        
        return (user, wallets)
    }
    
    private func migrations(_ app: Application) throws {
        // Initial Migrations
        app.migrations.add(CreateUser())
        app.migrations.add(CreateGame())
        app.migrations.add(CreateWalletAsync())
        app.migrations.add(CreateWalletTransactionAsync())
    }
}

extension WalletError: Equatable {
    public static func == (lhs: WalletError, rhs: WalletError) -> Bool {
        return lhs.errorDescription == rhs.errorDescription
    }
    
}
