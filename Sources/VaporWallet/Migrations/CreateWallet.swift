import Fluent

public struct CreateWallet<M:HasWallet>: Migration {
    private var idKey: String
    public init(foreignKeyColumnName idKey: String = "id") {
        self.idKey = idKey
    }
    
    public func prepare(on database: Database) -> EventLoopFuture<Void> {
        return database.schema(Wallet.schema)
            .id()
            .field("name", .string, .required)
            .field("owner_id", .uuid, .required, .references(M.schema, .init(stringLiteral: self.idKey), onDelete: .cascade))
            .field("balance", .double, .required)
            .field("decimal_places", .uint8, .required)
            .field("created_at", .datetime, .required)
            .field("updated_at", .datetime, .required)
            .field("deleted_at", .datetime)
            .create()
    }
    
    public func revert(on database: Database) -> EventLoopFuture<Void> {
        return database.schema(Wallet.schema).delete()
    }
}
