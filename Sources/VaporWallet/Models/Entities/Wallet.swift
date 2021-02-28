//
//  File.swift
//  
//
//  Created by Hadi Sharghi on 11/28/20.
//

import Vapor
import Fluent

final class Wallet: Model, Content {
    
    static let schema = "wallets"
    
    @ID(key: .id)
    var id: UUID?
    
    @Field(key: "name")
    var name: String
    
    @Field(key: "owner_id")
    var owner: UUID
    
    @Field(key: "balance")
    var balance: Double
    
    @Field(key: "decimal_places")
    var decimalPlaces: UInt8?
    
    @Timestamp(key: "created_at", on: .create)
    var createdAt: Date?
    
    @Timestamp(key: "updated_at", on: .update)
    var updatedAt: Date?

    @Timestamp(key: "deleted_at", on: .delete)
    var deletedAt: Date?
    
    @Children(for: \.$wallet)
    var transactions: [WalletTransaction]

    init() {}
    
    init(
        id: UUID? = nil,
        ownerID: UUID,
        name: String = WalletType.default.string,
        balance: Double = 0,
        decimalPlaces: UInt8 = 2,
        createdAt: Date? = nil,
        updatedAt: Date? = nil,
        deletedAt: Date? = nil
    ) {
        self.id = id
        self.owner = ownerID
        self.name = name
        self.balance = balance
        self.decimalPlaces = decimalPlaces
        self.createdAt = createdAt
        self.updatedAt = updatedAt
        self.createdAt = createdAt
    }

}

