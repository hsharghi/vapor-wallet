//
//  File.swift
//  
//
//  Created by Hadi Sharghi on 11/28/20.
//

import Vapor
import Fluent

public final class Wallet: Model, Content {
    
    public static let schema = "wallets"
    
    @ID(key: .id)
    public var id: UUID?
   
    @Field(key: "owner_id")
    var owner: UUID

    @Field(key: "owner_type")
    var ownerType: String
    
    @Field(key: "name")
    var name: String
    
    @Field(key: "min_allowed_balance")
    var minAllowedBalance: Int

    @Field(key: "balance")
    var balance: Int
    
    @Field(key: "decimal_places")
    var decimalPlaces: UInt8
    
    @Timestamp(key: "created_at", on: .create)
    var createdAt: Date?
    
    @Timestamp(key: "updated_at", on: .update)
    var updatedAt: Date?

    @Timestamp(key: "deleted_at", on: .delete)
    var deletedAt: Date?
    
    @Children(for: \.$wallet)
    var transactions: [WalletTransaction]

    public init() {}
    
    init(
        id: UUID? = nil,
        ownerType: String,
        ownerID: UUID,
        name: String = WalletType.default.value,
        minAllowedBalance: Int = 0,
        balance: Int = 0,
        decimalPlaces: UInt8 = 2,
        createdAt: Date? = nil,
        updatedAt: Date? = nil,
        deletedAt: Date? = nil
    ) {
        self.id = id
        self.ownerType = ownerType
        self.owner = ownerID
        self.name = name
        self.minAllowedBalance = minAllowedBalance
        self.balance = balance
        self.decimalPlaces = decimalPlaces
        self.createdAt = createdAt
        self.updatedAt = updatedAt
        self.createdAt = createdAt
    }

}

