//
//  File.swift
//  
//
//  Created by Hadi Sharghi on 4/6/21.
//

import Vapor
import Fluent


extension HasWallet {
    
    public func walletBalance(on db: Database, type name: WalletType = .default, with unconfirmed: Bool = false) -> EventLoopFuture<Double> {
        if unconfirmed {
            return self.wallet(on: db, type: name).flatMap { wallet  in
                wallet.$transactions
                    .query(on: db)
                    .sum(\.$amount)
                    .unwrap(orReplace: 0)
            }
        }
        return self.wallet(on: db, type: name).map { $0.balance }
    }
    
    public func canWithdraw(on db: Database, from: WalletType = .default, amount: Double) -> EventLoopFuture<Bool> {
        self.wallet(on: db, type: from).flatMap { $0.refreshBalance(on: db).map { $0 >= amount } }
    }
    
    public func deposit(on db: Database, to: WalletType = .default, amount: Double, confirmed: Bool, meta: [String: String]? = nil) throws -> EventLoopFuture<Void> {
        self.wallet(on: db, type: to).flatMap { wallet -> EventLoopFuture<Void> in
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
                self.wallet(on: db, type: from).flatMap { wallet -> EventLoopFuture<Void> in
                    return db.transaction { database -> EventLoopFuture<Void> in
                        do {
                            return WalletTransaction(walletID: try wallet.requireID(), type: .withdraw, amount: -1 * amount, meta: meta)
                                .save(on: database)
                        } catch {
                            return database.eventLoop.makeFailedFuture(WalletError.walletNotFound(name: from.string))
                        }
                    }
                }
            }
    }
    
    
    
}

