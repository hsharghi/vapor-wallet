//
//  File.swift
//  
//
//  Created by Hadi Sharghi on 4/11/21.
//

import Vapor
import Fluent
import FluentPostgresDriver

/// This calss gives access to wallet methods for a `HasWallet` model.
/// Creating multiple wallets, accessing them and getting balance of each wallet,
/// deposit, withdrawal and transfering funds to/from and between wallets
/// can be done through this class methods.
public class WalletsRepository<M:HasWallet> {
    internal init(db: Database, idKey: M.ID<UUID>) {
        guard let id = idKey.value else {
            fatalError("Unsaved models can't have wallets")
        }
        self.db = db
        self.id = id
        self.type = String(describing: M.self)
    }
    
    private var db: Database
    private var id: M.ID<UUID>.Value
    private var type: String
}

///
/// Creating and getting wallets and their balance
///
extension WalletsRepository {
    
    public func createAsync(type name: WalletType = .default, decimalPlaces: UInt8 = 2, minAllowedBalance: Int = 0) async throws {
        let wallet: Wallet = Wallet(ownerType: self.type,
                                    ownerID: self.id,
                                    name: name.value,
                                    minAllowedBalance: minAllowedBalance,
                                    decimalPlaces: decimalPlaces)
        try await wallet.save(on: db)
    }
    
    public func allAsync() async throws -> [Wallet] {
        return try await Wallet
            .query(on: self.db)
            .filter(\.$owner == self.id)
            .all()
    }
    
    public func getAsync(type name: WalletType, withTransactions: Bool = false) async throws -> Wallet {
        var walletQuery = Wallet.query(on: db)
            .filter(\.$owner == self.id)
            .filter(\.$ownerType == self.type)
            .filter(\.$name == name.value)
        
        if (withTransactions) {
            walletQuery = walletQuery.with(\.$transactions)
        }
        let wallet = try await walletQuery.first()
        
        guard let wallet = wallet else {
            throw WalletError.walletNotFound(name: name.value)
        }
        return wallet
    }
    
    public func defaultAsync(withTransactions: Bool = false) async throws -> Wallet {
        return try await getAsync(type: .default, withTransactions: withTransactions)
    }
    
    public func balanceAsync(type name: WalletType = .default, withUnconfirmed: Bool = false, asDecimal: Bool = false) async throws -> Double {
        let wallet = try await getAsync(type: name)
        if withUnconfirmed {
            // (1) Temporary workaround for sum and average aggregates,
            var balance: Double
            if let _ = self.db as? PostgresDatabase {
                let balanceOptional = try? await wallet.$transactions
                    .query(on: self.db)
                    .aggregate(.sum, \.$amount, as: Double.self)
                
                balance = balanceOptional ?? 0.0
            } else {
                let intBalance = try await wallet.$transactions
                    .query(on: self.db)
                    .sum(\.$amount)
                
                balance = intBalance == nil ? 0.0 : Double(intBalance!)
            }
            return asDecimal ? balance.toDecimal(with: wallet.decimalPlaces) : balance
        }
        return asDecimal ? Double(wallet.balance).toDecimal(with: wallet.decimalPlaces) : Double(wallet.balance)
    }
    
    public func refreshBalanceAsync(of walletType: WalletType = .default) async throws -> Double {
        let wallet = try await getAsync(type: walletType)
        return try await wallet.refreshBalanceAsync(on: self.db)
    }
    
    //
    //    public func create(type name: WalletType = .default, decimalPlaces: UInt8 = 2) -> EventLoopFuture<Void> {
    //        let wallet: Wallet = Wallet(ownerType: String(describing: self), ownerID: self.id, name: name.value, decimalPlaces: decimalPlaces)
    //        return wallet.save(on: db)
    //    }
    //
    //    public func all() -> EventLoopFuture<[Wallet]> {
    //        Wallet.query(on: self.db)
    //            .filter(\.$owner == self.id)
    //            .all()
    //    }
    //
    //    public func get(type name: WalletType) -> EventLoopFuture<Wallet> {
    //        Wallet.query(on: db)
    //            .filter(\.$owner == self.id)
    //            .filter(\.$name == name.value)
    //            .first()
    //            .unwrap(or: WalletError.walletNotFound(name: name.value))
    //    }
    //
    //    public func `default`() -> EventLoopFuture<Wallet> {
    //        get(type: .default)
    //    }
    //
    //    public func balance(type name: WalletType = .default, withUnconfirmed: Bool = false, asDecimal: Bool = false) -> EventLoopFuture<Double> {
    //        if withUnconfirmed {
    //            return get(type: name).flatMap { wallet  in
    //                wallet.$transactions
    //                    .query(on: self.db)
    //                    .sum(\.$amount)
    //                    .unwrap(orReplace: 0)
    //                    .map { (intBalance) -> Double in
    //                        return asDecimal ? Double(intBalance).toDecimal(with: wallet.decimalPlaces) : Double(intBalance)
    //                    }
    //            }
    //        }
    //        return get(type: name).map { wallet in
    //            return asDecimal ? Double(wallet.balance).toDecimal(with: wallet.decimalPlaces) : Double(wallet.balance)
    //        }
    //    }
    //
    //    public func refreshBalance(of walletType: WalletType = .default) -> EventLoopFuture<Double> {
    //        return get(type: walletType).flatMap { wallet -> EventLoopFuture<Double> in
    //            wallet.refreshBalance(on: self.db)
    //        }
    //    }
    
}


///
/// Withdraw, deposit and transfer funds to, from and between wallets
///
extension WalletsRepository {
    
    public func canWithdrawAsync(from: WalletType = .default, amount: Int) async throws -> Bool {
        let wallet = try await getAsync(type: from)
        return try await self._canWithdrawAsync(on: self.db, from: wallet, amount: amount)
    }
    
    public func withdrawAsync(from: WalletType = .default, amount: Double, meta: [String: String]? = nil) async throws {
        let wallet = try await getAsync(type: from)
        let intAmount = Int(amount * pow(10, Double(wallet.decimalPlaces)))
        guard try await canWithdrawAsync(from: from, amount: intAmount) else {
            throw WalletError.insufficientBalance
        }
        try await self._withdrawAsync(on: self.db, from: wallet, amount: intAmount, meta: meta)
    }
    
    
    public func withdrawAsync(from: WalletType = .default, amount: Int, meta: [String: String]? = nil) async throws {
        guard try await canWithdrawAsync(from: from, amount: amount) else {
            throw WalletError.insufficientBalance
        }
        let wallet = try await getAsync(type: from)
        try await self._withdrawAsync(on: self.db, from: wallet, amount: amount, meta: meta)
    }
    
    
    public func depositAsync(to: WalletType = .default, amount: Double, confirmed: Bool = true, meta: [String: String]? = nil) async throws {
        let wallet = try await getAsync(type: to)
        let intAmount = Int(amount * pow(10, Double(wallet.decimalPlaces)))
        try await self._depositAsync(on: self.db, to: wallet, amount: intAmount, confirmed: confirmed, meta: meta)
    }
    
    public func depositAsync(to: WalletType = .default, amount: Int, confirmed: Bool = true, meta: [String: String]? = nil) async throws {
        let wallet = try await getAsync(type: to)
        try await self._depositAsync(on: self.db, to: wallet, amount: amount, confirmed: confirmed, meta: meta)
    }
    
    
    public func transferAsync(from: Wallet, to: Wallet, amount: Int, meta: [String: String]? = nil) async throws {
        try await self._transferAsync(from: from, to: to, amount: amount, meta: meta)
    }
    
    public func transferAsync(from: WalletType, to: Wallet, amount: Int, meta: [String: String]? = nil) async throws {
        let fromWallet = try await getAsync(type: from)
        try await self._transferAsync(from: fromWallet, to: to, amount: amount, meta: meta)
    }
    
    public func transferAsync(from: WalletType, to: WalletType, amount: Int, meta: [String: String]? = nil) async throws {
        let fromWallet = try await getAsync(type: from)
        let toWallet = try await getAsync(type: to)
        try await self._transferAsync(from: fromWallet, to: toWallet, amount: amount, meta: meta)
    }
    
    
    //
    //    public func canWithdraw(from: WalletType = .default, amount: Int) -> EventLoopFuture<Bool> {
    //        get(type: from).flatMap { self._canWithdraw(from: $0, amount: amount) }
    //    }
    //
    //    public func withdraw(from: WalletType = .default, amount: Double, meta: [String: String]? = nil) -> EventLoopFuture<Void> {
    //        get(type: from).flatMap { wallet -> EventLoopFuture<Void> in
    //            let intAmount = Int(amount * pow(10, Double(wallet.decimalPlaces)))
    //            return self._withdraw(on: self.db, from: wallet, amount: intAmount, meta: meta)
    //        }
    //    }
    //
    //    public func withdraw(from: WalletType = .default, amount: Int, meta: [String: String]? = nil) -> EventLoopFuture<Void> {
    //
    //        canWithdraw(from: from, amount: amount)
    //            .guard({ $0 == true }, else: WalletError.insufficientBalance)
    //                .flatMap { _ in
    //                    self.get(type: from).flatMap { wallet -> EventLoopFuture<Void> in
    //                        self._withdraw(on: self.db, from: wallet, amount: amount, meta: meta)
    //                    }
    //                }
    //    }
    //
    //    public func deposit(to: WalletType = .default, amount: Double, confirmed: Bool = true, meta: [String: String]? = nil) -> EventLoopFuture<Void> {
    //        get(type: to).flatMap { wallet -> EventLoopFuture<Void> in
    //            let intAmount = Int(amount * pow(10, Double(wallet.decimalPlaces)))
    //            return self._deposit(on: self.db, to: wallet, amount: intAmount, confirmed: confirmed, meta: meta)
    //        }
    //    }
    //
    //    public func deposit(to: WalletType = .default, amount: Int, confirmed: Bool = true, meta: [String: String]? = nil) -> EventLoopFuture<Void> {
    //        get(type: to).flatMap { wallet -> EventLoopFuture<Void> in
    //            self._deposit(on: self.db, to: wallet, amount: amount, confirmed: confirmed, meta: meta)
    //        }
    //    }
    //
    //    public func transafer(from: Wallet, to: Wallet, amount: Int, meta: [String: String]? = nil) -> EventLoopFuture<Void> {
    //        return _canWithdraw(from: from, amount: amount)
    //            .guard({ $0 == true }, else: WalletError.insufficientBalance)
    //                .flatMap { _ in
    //                    self._transfer(from: from, to: to, amount: amount, meta: meta)
    //                }
    //    }
    //
    //    public func transfer(from: WalletType, to: Wallet, amount: Int, meta: [String: String]? = nil) -> EventLoopFuture<Void> {
    //        return get(type: from).flatMap { fromWallet -> EventLoopFuture<Void> in
    //            self._canWithdraw(from: fromWallet, amount: amount)
    //                .guard({ $0 == true }, else: WalletError.insufficientBalance)
    //                    .flatMap { _ in
    //                        return self._transfer(from: fromWallet, to: to, amount: amount, meta: meta)
    //                    }
    //        }
    //    }
    //
    //    public func transafer(from: WalletType, to: WalletType, amount: Int, meta: [String: String]? = nil) -> EventLoopFuture<Void> {
    //        return get(type: to).flatMap { toWallet -> EventLoopFuture<Void> in
    //            self.transfer(from: from, to: toWallet, amount: amount, meta: meta)
    //        }
    //    }
    
}


///
/// Accessing transactions of a wallet and confirming transactions
///
extension WalletsRepository {
    public func transactionsAsync(type name: WalletType = .default,
                                  paginate: PageRequest = .init(page: 1, per: 10),
                                  sortOrder: DatabaseQuery.Sort.Direction = .descending) async throws -> Page<WalletTransaction> {
        let wallet = try await self.getAsync(type: name)
        return try await wallet.$transactions
            .query(on: self.db)
            .sort(\.$createdAt, sortOrder)
            .filter(\.$confirmed == true)
            .paginate(paginate)
    }
    
    public func unconfirmedTransactionsAsync(type name: WalletType = .default,
                                             paginate: PageRequest = .init(page: 1, per: 10),
                                             sortOrder: DatabaseQuery.Sort.Direction = .descending) async throws -> Page<WalletTransaction> {
        let wallet = try await self.getAsync(type: name, withTransactions: true)
        return try await wallet.$transactions
            .query(on: self.db)
            .sort(\.$createdAt, sortOrder)
            .filter(\.$confirmed == false)
            .paginate(paginate)
    }
    
    
    public func confirmAllAsync(type name: WalletType = .default) async throws -> Double {
        let wallet = try await self.getAsync(type: name, withTransactions: true)
        return try await self.db.transaction { database in
            try await wallet.$transactions
                .query(on: database)
                .set(\.$confirmed, to: true)
                .update()
            return try await wallet.refreshBalanceAsync(on: database)
        }
    }
    
    public func confirmAsync(transaction: WalletTransaction, refresh: Bool = true) async throws -> Double {
        transaction.confirmed = true
        return try await self.db.transaction { database in
            try await transaction.update(on: database)
            let wallet = try await transaction.$wallet.get(on: database)
            return try await wallet.refreshBalanceAsync(on: database)
        }
    }
    
    
    //
    //
    //    public func transactions(type name: WalletType = .default,
    //                             paginate: PageRequest = .init(page: 1, per: 10),
    //                             sortOrder: DatabaseQuery.Sort.Direction = .descending) -> EventLoopFuture<Page<WalletTransaction>> {
    //        return self.get(type: name).flatMap {
    //            $0.$transactions
    //                .query(on: self.db)
    //                .sort(\.$createdAt, sortOrder)
    //                .filter(\.$confirmed == true)
    //                .paginate(paginate)
    //        }
    //    }
    //
    //    public func unconfirmedTransactions(type name: WalletType = .default,
    //                                        paginate: PageRequest = .init(page: 1, per: 10),
    //                                        sortOrder: DatabaseQuery.Sort.Direction = .descending) -> EventLoopFuture<Page<WalletTransaction>> {
    //        return self.get(type: name).flatMap {
    //            $0.$transactions
    //                .query(on: self.db)
    //                .sort(\.$createdAt, sortOrder)
    //                .filter(\.$confirmed == false)
    //                .paginate(paginate)
    //        }
    //    }
    //
    //    public func confirmAll(type name: WalletType = .default) -> EventLoopFuture<Double> {
    //        get(type: name).flatMap { (wallet) -> EventLoopFuture<Double> in
    //            self.db.transaction { (database) -> EventLoopFuture<Double> in
    //                wallet.$transactions
    //                    .query(on: database)
    //                    .set(\.$confirmed, to: true)
    //                    .update()
    //                    .flatMap { _ -> EventLoopFuture<Double> in
    //                        wallet.refreshBalance(on: database)
    //                    }
    //            }
    //        }
    //    }
    //
    //
    //    public func confirm(transaction: WalletTransaction, refresh: Bool = true) -> EventLoopFuture<Double> {
    //        transaction.confirmed = true
    //        return self.db.transaction { (database) -> EventLoopFuture<Double> in
    //            transaction.update(on: database).flatMap { () -> EventLoopFuture<Double> in
    //                transaction.$wallet.get(on: database).flatMap { wallet -> EventLoopFuture<Double> in
    //                    wallet.refreshBalance(on: database)
    //                }
    //            }
    //        }
    //    }
    //
}

///
/// Private methdos
///
extension WalletsRepository {
    private func _canWithdrawAsync(on db: Database, from: Wallet, amount: Int) async throws -> Bool {
        return try await from.refreshBalanceAsync(on: db) - Double(amount) >= Double(from.minAllowedBalance)
    }
    
    private func _depositAsync(on db: Database, to: Wallet, amount: Int, confirmed: Bool = true, meta: [String: String]? = nil) async throws {
        try await db.transaction { database in
            var walletTransaction: WalletTransaction
            do {
                walletTransaction = WalletTransaction(walletID: try to.requireID(), transactionType: .deposit, amount: amount, confirmed: confirmed, meta: meta)
            } catch {
                throw WalletError.walletNotFound(name: to.name)
            }
            _ = try await walletTransaction.save(on: database)
        }
    }
    
    private func _withdrawAsync(on db: Database, from: Wallet, amount: Int, meta: [String: String]? = nil) async throws {
        try await db.transaction { database in
            var walletTransaction: WalletTransaction
            do {
                walletTransaction = WalletTransaction(walletID: try from.requireID(), transactionType: .withdraw, amount: -1 * amount, meta: meta)
            } catch {
                throw WalletError.walletNotFound(name: from.name)
            }
            _ = try await walletTransaction.save(on: database)
        }
    }
    
    private func _transferAsync(from: Wallet, to: Wallet, amount: Int, meta: [String: String]? = nil) async throws {
        try await self.db.transaction { database in
            guard try await self._canWithdrawAsync(on: database, from: from, amount: amount) else {
                throw WalletError.insufficientBalance
            }
            try await self._withdrawAsync(on: database, from: from, amount: amount, meta: meta)
            try await self._depositAsync(on: database, to: to, amount: amount, meta: meta)
            _ = try await from.refreshBalanceAsync(on: database)
            _ = try await to.refreshBalanceAsync(on: database)
        }
    }
    //
    //    private func _canWithdraw(from: Wallet, amount: Int) -> EventLoopFuture<Bool> {
    //        from.refreshBalance(on: self.db).map { $0 >= Double(amount) }
    //    }
    //
    //    private func _deposit(on db: Database, to: Wallet, amount: Int, confirmed: Bool = true, meta: [String: String]? = nil) -> EventLoopFuture<Void> {
    //        return db.transaction { database -> EventLoopFuture<Void> in
    //            do {
    //                return WalletTransaction(walletID: try to.requireID(), type: .deposit, amount: amount, confirmed: confirmed, meta: meta)
    //                    .save(on: database)
    //            } catch {
    //                return self.db.eventLoop.makeFailedFuture(WalletError.walletNotFound(name: to.name))
    //            }
    //        }
    //    }
    //
    //    private func _withdraw(on db: Database, from: Wallet, amount: Int, meta: [String: String]? = nil) -> EventLoopFuture<Void> {
    //        return db.transaction { database -> EventLoopFuture<Void> in
    //            do {
    //                return WalletTransaction(walletID: try from.requireID(), type: .withdraw, amount: -1 * amount, meta: meta)
    //                    .save(on: database)
    //            } catch {
    //                return database.eventLoop.makeFailedFuture(WalletError.walletNotFound(name: from.name))
    //            }
    //        }
    //    }
    //
    //    private func _transfer(from: Wallet, to: Wallet, amount: Int, meta: [String: String]? = nil) -> EventLoopFuture<Void> {
    //        return self.db.transaction { (database) -> EventLoopFuture<Void> in
    //            return self._withdraw(on: database, from: from, amount: amount, meta: meta).flatMap { _ ->  EventLoopFuture<Void> in
    //                self._deposit(on: database, to: to, amount: amount, meta: meta).flatMap { _ ->  EventLoopFuture<Void> in
    //                    let refreshFrom = from.refreshBalance(on: database)
    //                    let refreshTo = to.refreshBalance(on: database)
    //                    return refreshFrom.and(refreshTo).flatMap { (_, _) -> EventLoopFuture<Void> in
    //                        database.eventLoop.makeSucceededFuture(())
    //                    }
    //                }
    //            }
    //        }
    //    }
    
}

