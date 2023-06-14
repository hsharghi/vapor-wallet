import Fluent

public struct CreateWalletTransaction: Migration {
    public init() { }
    
    public func prepare(on database: Database) -> EventLoopFuture<Void> {
        return database.enum("type")
            .case("deposit")
            .case("withdraw")
            .create().flatMap { transactionType in
                return database.schema(WalletTransaction.schema)
                    .id()
                    .field("wallet_id", .uuid, .required, .references(Wallet.schema, "id", onDelete: .cascade))
                    .field("type", transactionType, .required)
                    .field("amount", .int, .required)
                    .field("confirmed", .bool, .required)
                    .field("meta", .json)
                    .field("created_at", .datetime, .required)
                    .field("updated_at", .datetime, .required)
                    .create()
            }
    }
    
    public func revert(on database: Database) -> EventLoopFuture<Void> {
        return database.enum("type")
            .deleteCase("deposit")
            .deleteCase("withdraw")
            .update().flatMap { _ in
                return database.schema(WalletTransaction.schema).delete()
            }
        
    }
}

public struct CreateWalletTransactionAsync: AsyncMigration {
    public init() { }
    
    public func prepare(on database: Database) async throws {
        _ = try await database.enum("type")
            .case("deposit")
            .case("withdraw")
            .create()

        let transactionType = try await database.enum("type").read()
        try await database.schema(WalletTransaction.schema)
            .id()
            .field("wallet_id", .uuid, .required, .references(Wallet.schema, "id", onDelete: .cascade))
            .field("type", transactionType, .required)
            .field("amount", .int, .required)
            .field("confirmed", .bool, .required)
            .field("meta", .json)
            .field("created_at", .datetime, .required)
            .field("updated_at", .datetime, .required)
            .create()
    }
    
    
    public func revert(on database: Database) async throws {
        let _ =  try await database.enum("type").delete()
        try await database.schema(WalletTransaction.schema).delete()
    }
    
}
