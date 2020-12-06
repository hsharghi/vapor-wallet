import Fluent

struct CreateWallet<M:HasWallet>: Migration {
    func prepare(on database: Database) -> EventLoopFuture<Void> {
        return database.schema(Wallet.schema)
            .id()
            .field("name", .string, .required)
            .field("owner_id", .string, .required, .references(M.schema, "username", onDelete: .cascade))
            .field("balance", .double, .required)
            .field("decimal_places", .uint8, .required)
            .field("created_at", .datetime, .required)
            .field("updated_at", .datetime, .required)
            .field("deleted_at", .datetime)
            .create()
    }
    
    func revert(on database: Database) -> EventLoopFuture<Void> {
        return database.schema(Wallet.schema).delete()
    }
}
