import Fluent

struct CreateWalletTransaction: Migration {
    func prepare(on database: Database) -> EventLoopFuture<Void> {
        return database.enum("type").case("deposit").case("withdraw").create().flatMap { transactionType in
            return database.schema(WalletTransaction.schema)
                .id()
                .field("wallet_id", .uuid, .required, .references(Wallet.schema, "id", onDelete: .cascade))
                .field("type", transactionType, .required)
                .field("amount", .double, .required)
                .field("confirmed", .bool, .required)
                .field("meta", .json)
                .create()
        }
    }
    
    func revert(on database: Database) -> EventLoopFuture<Void> {
        return database.schema(Wallet.schema).delete()
    }
}
