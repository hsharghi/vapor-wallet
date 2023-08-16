//
//  File.swift
//  
//
//  Created by Hadi Sharghi on 11/28/20.
//

import Vapor
import Fluent


public enum TransactionType: String, Content {
    case deposit, withdraw
}

public final class WalletTransaction: Model {
    
    public static let schema = "wallet_transactions"

    
    @ID(key: .id)
    public var id: UUID?
    
    @Parent(key: "wallet_id")
    public var wallet: Wallet
    
    @Enum(key: "transaction_type")
    public var transactionType: TransactionType
    
    @Field(key: "amount")
    public var amount: Int
    
    @Field(key: "confirmed")
    public var confirmed: Bool

    @Field(key: "meta")
    public var meta: [String: String]?
    
    @Timestamp(key: "created_at", on: .create)
    public var createdAt: Date?
    
    @Timestamp(key: "updated_at", on: .update)
    public var updatedAt: Date?

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
    
    public func confirm(on db: Database) async throws {
        self.confirmed = true
        try await self.update(on: db)
    }
    
    public var metaData: [String: String]? {
        self.meta
    }
    
    public var type: TransactionType {
        self.transactionType
    }
    
    public var transactionAmout: Int {
        return self.amount
    }

}
