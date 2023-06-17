//
//  File.swift
//  
//
//  Created by Hadi Sharghi on 11/28/20.
//

import Vapor
import Fluent


enum TransactionType: String, Content {
    case deposit, withdraw
}

public final class WalletTransaction: Model {
    
    public static let schema = "wallet_transactions"

    
    @ID(key: .id)
    public var id: UUID?
    
    @Parent(key: "wallet_id")
    var wallet: Wallet
    
    @Enum(key: "transaction_type")
    var transactionType: TransactionType
    
    @Field(key: "amount")
    var amount: Int
    
    @Field(key: "confirmed")
    var confirmed: Bool

    @Field(key: "meta")
    var meta: [String: String]?
    
    @Timestamp(key: "created_at", on: .create)
    var createdAt: Date?
    
    @Timestamp(key: "updated_at", on: .update)
    var updatedAt: Date?

    public init() {}
    
    init(
        id: UUID? = nil,
        walletID: UUID,
        transactionType: TransactionType,
        amount: Int,
        confirmed: Bool = true,
        meta: [String: String]? = nil,
        createdAt: Date? = nil,
        updatedAt: Date? = nil
    ) {
        self.id = id
        self.$wallet.id = walletID
        self.transactionType = transactionType
        self.amount = amount
        self.meta = meta
        self.confirmed = confirmed
        self.createdAt = createdAt
        self.updatedAt = updatedAt
    }

}


extension WalletTransaction {
    
    public var isConfirmed: Bool {
        return self.confirmed
    }
    
    public func confirm(on db: Database) -> EventLoopFuture<Void> {
        self.confirmed = true
        return self.update(on: db)
    }
    
    public func confirmAsync(on db: Database) async throws {
        self.confirmed = true
        try await self.update(on: db)
    }
    
    
}
