//
//  WalletRepository.swift
//  
//
//  Created by Hadi Sharghi on 4/11/21.
//

import Vapor
import Fluent
#if canImport(FluentPostgresDriver)
import FluentPostgresDriver
#endif

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
    
    public enum EmptyStrategy {
        case toZero
        case toMinAllowed
    }
    
    public func create(type name: WalletType = .default, decimalPlaces: UInt8 = 2, minAllowedBalance: Int = 0) async throws {
        let wallet: Wallet = Wallet(ownerType: self.type,
                                    ownerID: self.id,
                                    name: name.value,
                                    minAllowedBalance: minAllowedBalance,
                                    decimalPlaces: decimalPlaces)
        try await wallet.save(on: db)
    }
    
    public func all() async throws -> [Wallet] {
        return try await Wallet
            .query(on: self.db)
            .filter(\.$owner == self.id)
            .all()
    }
    
    public func get(type name: WalletType, withTransactions: Bool = false) async throws -> Wallet {
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
    
    public func `default`(withTransactions: Bool = false) async throws -> Wallet {
        return try await get(type: .default, withTransactions: withTransactions)
    }
 
    public func balance(type name: WalletType = .default, withUnconfirmed: Bool = false, asDecimal: Bool = false) async throws -> Double {
        let wallet = try await get(type: name)
        return try await balance(wallet: wallet, withUnconfirmed: withUnconfirmed, asDecimal: asDecimal)
    }
    
    public func refreshBalance(of walletType: WalletType = .default) async throws -> Double {
        let wallet = try await get(type: walletType)
        return try await wallet.refreshBalance(on: self.db)
    }
    
    private func balance(wallet: Wallet, withUnconfirmed: Bool = false, asDecimal: Bool = false) async throws -> Double {
        if withUnconfirmed {
            // (1) Temporary workaround for sum and average aggregates on PostgresDriver
            var balance: Double
            #if canImport(FluentPostgresDriver)
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
            #else
            let intBalance = try await wallet.$transactions
                .query(on: self.db)
                .sum(\.$amount)
            
            balance = intBalance == nil ? 0.0 : Double(intBalance!)
            #endif
            return asDecimal ? balance.toDecimal(with: wallet.decimalPlaces) : balance
        }
        return asDecimal ? Double(wallet.balance).toDecimal(with: wallet.decimalPlaces) : Double(wallet.balance)
    }
    
}


///
/// Withdraw, deposit and transfer funds to, from and between wallets
///
extension WalletsRepository {
    
    public func canWithdraw(from: WalletType = .default, amount: Int) async throws -> Bool {
        let wallet = try await get(type: from)
        return try await self._canWithdraw(on: self.db, from: wallet, amount: amount)
    }
    
    public func withdraw(from: WalletType = .default, amount: Double, meta: [String: String]? = nil) async throws {
        let wallet = try await get(type: from)
        let intAmount = Int(amount * pow(10, Double(wallet.decimalPlaces)))
        try await withdraw(from: wallet, amount: intAmount, meta: meta)
    }
    
    
    public func withdraw(from: WalletType = .default, amount: Int, meta: [String: String]? = nil) async throws {
        let wallet = try await get(type: from)
        guard try await canWithdraw(from: wallet, amount: amount) else {
            throw WalletError.insufficientBalance
        }
        try await withdraw(from: wallet, amount: amount, meta: meta)
    }
    
    
    public func deposit(to: WalletType = .default, amount: Double, confirmed: Bool = true, expiresAt: Date? = nil, meta: [String: String]? = nil) async throws {
        let wallet = try await get(type: to)
        let intAmount = Int(amount * pow(10, Double(wallet.decimalPlaces)))
        try await deposit(to: wallet, amount: intAmount, confirmed: confirmed, expiresAt: expiresAt, meta: meta)
    }
    
    public func deposit(to: WalletType = .default, amount: Int, confirmed: Bool = true, expiresAt: Date? = nil, meta: [String: String]? = nil) async throws {
        let wallet = try await get(type: to)
        try await deposit(to: wallet, amount: amount, confirmed: confirmed, expiresAt: expiresAt, meta: meta)
    }
    
    public func empty(_ walletType: WalletType = .default, meta: [String: String]? = nil, strategy: EmptyStrategy) async throws {
        let wallet = try await get(type: walletType)
        let balance = try await balance(wallet: wallet, asDecimal: true)
        if balance < 0.0 && strategy == .toZero {
            throw WalletError.invalidTransaction(reason: "Wallet balance is alreasy below zero.")
        }
        let withdrawAmount = strategy == .toZero
        ? balance * pow(10, Double(wallet.decimalPlaces))
        : balance * pow(10, Double(wallet.decimalPlaces)) - Double(wallet.minAllowedBalance)
        try await withdraw(from: wallet, amount: Int(withdrawAmount), meta: meta)
    }
    
    public func transfer(from: Wallet, to: Wallet, amount: Int, meta: [String: String]? = nil) async throws {
        try await self._transfer(from: from, to: to, amount: amount, meta: meta)
    }
    
    public func transfer(from: WalletType, to: Wallet, amount: Int, meta: [String: String]? = nil) async throws {
        let fromWallet = try await get(type: from)
        try await self._transfer(from: fromWallet, to: to, amount: amount, meta: meta)
    }
    
    public func transfer(from: WalletType, to: WalletType, amount: Int, meta: [String: String]? = nil) async throws {
        let fromWallet = try await get(type: from)
        let toWallet = try await get(type: to)
        try await self._transfer(from: fromWallet, to: toWallet, amount: amount, meta: meta)
    }
    
}


///
/// Accessing transactions of a wallet and confirming transactions
///
extension WalletsRepository {
    public func transactions(type name: WalletType = .default,
                             paginationRequest: Request,
                             sortOrder: DatabaseQuery.Sort.Direction = .descending) async throws -> Page<WalletTransaction> {
        let page = try paginationRequest.query.decode(PageRequest.self)
        return try await transactions(type: name, paginate: page, sortOrder: sortOrder)
    }
    
    public func transactions(type name: WalletType = .default,
                                  paginate: PageRequest = .init(page: 1, per: 10),
                                  sortOrder: DatabaseQuery.Sort.Direction = .descending) async throws -> Page<WalletTransaction> {
        let wallet = try await self.get(type: name)
        return try await wallet.$transactions
            .query(on: self.db)
            .sort(\.$createdAt, sortOrder)
            .filter(\.$confirmed == true)
            .paginate(paginate)
    }
    
    public func unconfirmedTransactions(type name: WalletType = .default,
                                             paginate: PageRequest = .init(page: 1, per: 10),
                                             sortOrder: DatabaseQuery.Sort.Direction = .descending) async throws -> Page<WalletTransaction> {
        let wallet = try await self.get(type: name, withTransactions: true)
        return try await wallet.$transactions
            .query(on: self.db)
            .sort(\.$createdAt, sortOrder)
            .filter(\.$confirmed == false)
            .paginate(paginate)
    }
    
    
    public func confirmAll(type name: WalletType = .default) async throws -> Double {
        let wallet = try await self.get(type: name, withTransactions: true)
        return try await self.db.transaction { database in
            try await wallet.$transactions
                .query(on: database)
                .set(\.$confirmed, to: true)
                .update()
            return try await wallet.refreshBalance(on: database)
        }
    }
    
    public func confirm(transaction: WalletTransaction, refresh: Bool = true) async throws -> Double {
        transaction.confirmed = true
        return try await self.db.transaction { database in
            try await transaction.update(on: database)
            let wallet = try await transaction.$wallet.get(on: database)
            return try await wallet.refreshBalance(on: database)
        }
    }
    
}

///
/// Private methdos
///
extension WalletsRepository {
    private func canWithdraw(from: Wallet, amount: Int) async throws -> Bool {
        return try await self._canWithdraw(on: self.db, from: from, amount: amount)
    }
    
    private func withdraw(from: Wallet, amount: Int, meta: [String: String]? = nil) async throws {
        guard try await canWithdraw(from: from, amount: amount) else {
            throw WalletError.insufficientBalance
        }
        try await self._withdraw(on: self.db, from: from, amount: amount, meta: meta)
    }

    private func deposit(to: Wallet, amount: Int, confirmed: Bool = true, expiresAt: Date? = nil, meta: [String: String]? = nil) async throws {
        try await self._deposit(on: self.db, to: to, amount: amount, confirmed: confirmed, expiresAt: expiresAt, meta: meta)
    }

    private func _canWithdraw(on db: Database, from: Wallet, amount: Int) async throws -> Bool {
        return try await from.refreshBalance(on: db) - Double(amount) >= Double(from.minAllowedBalance)
    }
    
    private func _deposit(on db: Database, to: Wallet, amount: Int, confirmed: Bool = true, expiresAt: Date? = nil, meta: [String: String]? = nil) async throws {
        try await db.transaction { database in
            var walletTransaction: WalletTransaction
            do {
                walletTransaction = WalletTransaction(walletID: try to.requireID(),
                                                      transactionType: .deposit,
                                                      amount: amount,
                                                      confirmed: confirmed,
                                                      meta: meta,
                                                      expiresAt: expiresAt)
            } catch {
                throw WalletError.walletNotFound(name: to.name)
            }
            _ = try await walletTransaction.save(on: database)
        }
    }
    
    private func _withdraw(on db: Database, from: Wallet, amount: Int, meta: [String: String]? = nil) async throws {
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
    
    private func _transfer(from: Wallet, to: Wallet, amount: Int, meta: [String: String]? = nil) async throws {
        try await self.db.transaction { database in
            guard try await self._canWithdraw(on: database, from: from, amount: amount) else {
                throw WalletError.insufficientBalance
            }
            try await self._withdraw(on: database, from: from, amount: amount, meta: meta)
            try await self._deposit(on: database, to: to, amount: amount, meta: meta)
            _ = try await from.refreshBalance(on: database)
            _ = try await to.refreshBalance(on: database)
        }
    }
    
}

