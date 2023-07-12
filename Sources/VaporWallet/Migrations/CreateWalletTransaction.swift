import Fluent


public struct CreateWalletTransaction: AsyncMigration {
    public init() { }
    
    public func prepare(on database: Database) async throws {
        
        let transactionType = try await database.enum("transaction_type")
            .case("deposit")
            .case("withdraw")
            .create()
        
        try await database.schema(WalletTransaction.schema)
            .id()
            .field("wallet_id", .uuid, .required, .references(Wallet.schema, "id", onDelete: .cascade))
            .field("transaction_type", transactionType, .required)
            .field("amount", .int, .required)
            .field("confirmed", .bool, .required)
            .field("meta", .json)
            .field("created_at", .datetime, .required)
            .field("updated_at", .datetime, .required)
            .create()
    }
    
    
    public func revert(on database: Database) async throws {
        try await database.enum("transaction_type").delete()
        try await database.schema(WalletTransaction.schema).delete()
    }
    
}
