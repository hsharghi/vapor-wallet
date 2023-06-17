import Fluent
import SQLKit


public struct CreateWallet: AsyncMigration {
    private var idKey: String
    public init(foreignKeyColumnName idKey: String = "id") {
        self.idKey = idKey
    }

    public func prepare(on database: Database) async throws {
        try await database.schema(Wallet.schema)
            .id()
            .field("name", .string, .required)
            .field("owner_type", .string, .required)
            .field("owner_id", .uuid, .required)
            .field("min_allowed_balance", .int, .required)
            .field("balance", .int, .required)
            .field("decimal_places", .uint8, .required)
            .field("created_at", .datetime, .required)
            .field("updated_at", .datetime, .required)
            .field("deleted_at", .datetime)
            .create()
        let sqlDB = (database as! SQLDatabase)
        try await sqlDB
            .create(index: "type_idx")
            .on(Wallet.schema)
            .column("owner_type")
            .run()
    }


    public func revert(on database: Database) async throws {
        try await database.schema(Wallet.schema).delete()
    }
}
