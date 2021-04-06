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
    
    static var idKey: KeyPath<Self, Self.ID<UUID>> { get }
    
    func deposit(on db: Database, to: WalletType, amount: Double, confirmed: Bool, meta: [String: String]?) throws -> EventLoopFuture<Void>
    func withdraw(on db: Database, from: WalletType, amount: Double, meta: [String: String]?) -> EventLoopFuture<Void>
    func canWithdraw(on db: Database, from: WalletType, amount: Double) -> EventLoopFuture<Bool>
    func wallets(on db: Database) -> EventLoopFuture<[Wallet]>
    func wallet(on db: Database, type name: WalletType) -> EventLoopFuture<Wallet>
    func walletBalance(on db: Database, type name: WalletType, withUnconfirmed: Bool) -> EventLoopFuture<Double>
    
}

extension HasWallet {
    var _$idKey: ID<UUID> {
        self[keyPath: Self.idKey]
    }
}

extension Wallet {
    public func refreshBalance(on db: Database) -> EventLoopFuture<Double> {
        self.$transactions
            .query(on: db)
            .filter(\.$confirmed == true)
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

