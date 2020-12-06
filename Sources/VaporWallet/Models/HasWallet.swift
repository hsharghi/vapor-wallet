//
//  File.swift
//  
//
//  Created by Hadi Sharghi on 12/5/20.
//


import Vapor
import Fluent

public protocol HasWallet: FluentKit.Model {
    associatedtype Owner: FluentKit.Model

    static var usernameKey: KeyPath<Self, Self.Field<String>> { get }
    
    func deposit(on db: Database, to: WalletType, amount: Double, confirmed: Bool, meta: [String: String]?) throws -> EventLoopFuture<Void>
    func withdraw(on db: Database, from: WalletType, amount: Double, meta: [String: String]?) -> EventLoopFuture<Void>
    func canWithdraw(on db: Database, from: WalletType, amount: Double) -> EventLoopFuture<Bool>
//    func wallets(on db: Database) -> EventLoopFuture<[Wallet]>
//    func defaultWallet(on db: Database) -> EventLoopFuture<Wallet>
    
}

extension HasWallet {
    var _$username: Field<String> {
        self[keyPath: Self.usernameKey]
    }
}



extension HasWallet {
    
    public func create(on database: Database, for owner: Owner, name: WalletType) -> EventLoopFuture<Void> {
        database.eventLoop.future()
    }
    
    public func createDefaultWallet(on db: Database) throws -> EventLoopFuture<Void> {
        let wallet: Wallet = Wallet(ownerID: self._$username.value!)
        return wallet.save(on: db)
    }
    
    func canWithdraw(on db: Database, from: WalletType, amount: Double) -> EventLoopFuture<Bool> {
        return self.wallet(on: db, with: from).flatMap { $0.refreshBalance(on: db).map { $0 > amount } }
    }
    
    public func deposit(on db: Database, to: WalletType = .default, amount: Double, confirmed: Bool, meta: [String: String]? = nil) throws -> EventLoopFuture<Void> {
        return self.wallet(on: db, with: to).flatMap { wallet -> EventLoopFuture<Void> in
            return db.transaction { database -> EventLoopFuture<Void> in
                do {
                    return WalletTransaction(walletID: try wallet.requireID(), type: .deposit, amount: amount, confirmed: confirmed, meta: meta)
                        .save(on: database)
                } catch {
                    return database.eventLoop.makeFailedFuture(WalletError.walletNotFound(name: to.string))
                }
            }
        }
    }
    
    public func withdraw(on db: Database, from: WalletType = .default, amount: Double, meta: [String: String]? = nil) -> EventLoopFuture<Void> {
        
        canWithdraw(on: db, from: from, amount: amount)
            .guard({ $0 == true }, else: WalletError.insufficientBalance)
            .flatMap { _ in
                self.wallet(on: db, with: from).flatMap { wallet -> EventLoopFuture<Void> in
                    return db.transaction { database -> EventLoopFuture<Void> in
                        do {
                            return WalletTransaction(walletID: try wallet.requireID(), type: .withdraw, amount: amount, meta: meta)
                                .save(on: db)
                        } catch {
                            return db.eventLoop.makeFailedFuture(WalletError.walletNotFound(name: from.string))
                        }
                    }
                }
            }
    }

    func wallets(on db: Database) -> EventLoopFuture<[Wallet]> {
        Wallet.query(on: db).filter(\.$name == WalletType.default.string).all()
    }

    func wallet(on db: Database, with name: WalletType) -> EventLoopFuture<Wallet> {
        Wallet.query(on: db).filter(\.$name == name.string)
            .first()
            .unwrap(or: WalletError.walletNotFound(name: name.string))
    }
    
    func defaultWallet(on db: Database) -> EventLoopFuture<Wallet> {
        wallet(on: db, with: .default)
    }
    
}


extension Wallet {
    public func refreshBalance(on db: Database) -> EventLoopFuture<Double> {
        self.$transactions
            .query(on: db)
            .sum(\.$amount)
            .unwrap(orReplace: 0)
            .flatMap { (balance) -> EventLoopFuture<Double> in
                self.balance = balance
                return self.update(on: db).map {
                    return balance
                }
            }
    }
}
