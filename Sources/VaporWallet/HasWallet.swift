//
//  File.swift
//  
//
//  Created by Hadi Sharghi on 12/5/20.
//


import Vapor
import Fluent

public protocol HasWallet: FluentKit.Model {    
    static var idKey: KeyPath<Self, Self.ID<UUID>> { get }
    func walletsRepository(on db: Database) -> WalletsRepository<Self>
        
}

extension HasWallet {
    var _$idKey: ID<UUID> {
        self[keyPath: Self.idKey]
    }
    
    func walletsRepository(on db: Database) -> WalletsRepository<Self> {
        return WalletsRepository(db: db, idKey: self._$idKey)
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
                    return Double(balance)
                }
            }
    }
}

