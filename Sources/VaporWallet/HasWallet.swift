//
//  File.swift
//  
//
//  Created by Hadi Sharghi on 12/5/20.
//


import Vapor
import Fluent
import FluentPostgresDriver

public protocol HasWallet: FluentKit.Model {    
    static var idKey: KeyPath<Self, Self.ID<UUID>> { get }
    func walletsRepository(on db: Database) -> WalletsRepository<Self>
    
}

extension HasWallet {
    var _$idKey: ID<UUID> {
        self[keyPath: Self.idKey]
    }
    
    public func walletsRepository(on db: Database) -> WalletsRepository<Self> {
        return WalletsRepository(db: db, idKey: self._$idKey)
    }
}

extension Wallet {
    public func refreshBalance(on db: Database) async throws -> Double {
        
        var balance: Int
        // Temporary workaround for sum and average aggregates on Postgres DB
        if let _ = db as? PostgresDatabase {
            let balanceOptional = try? await self.$transactions
                .query(on: db)
                .filter(\.$confirmed == true)
                .aggregate(.sum, \.$amount, as: Double.self)
            
            balance = balanceOptional == nil ? 0 : Int(balanceOptional!)
        } else {
            let intBalance = try await self.$transactions
                .query(on: db)
                .filter(\.$confirmed == true)
                .sum(\.$amount)
            
            balance = intBalance ?? 0
        }
        
        self.balance = balance
        
        try await self.update(on: db)
        return Double(self.balance)
    }
    
}

