//
//  File.swift
//  
//
//  Created by Hadi Sharghi on 4/5/21.
//

import Vapor
import Fluent
@testable import VaporWallet

final class User: Model {
    static let schema = "users"
    
    @ID(key: .id)
    var id: UUID?
    
    @Field(key: "username")
    var username: String
    
    init() {}
    
    init(
        id: UUID? = nil,
        username: String
    ) {
        self.id = id
        self.username = username
    }
    
    public static func create(username: String = "user1", on database: Database) async throws -> User {
        let user = User(username: username)
        try await user.save(on: database)
        return user
    }
}

extension User: HasWallet {
    
    static let idKey = \User.$id
    
}


struct CreateUser: Migration {
    func prepare(on database: Database) -> EventLoopFuture<Void> {
        return database.schema(User.schema)
            .id()
            .field("username", .string, .required)
            .create()
    }

    func revert(on database: Database) -> EventLoopFuture<Void> {
        return database.schema(User.schema).delete()
    }
}
//
//struct CreateUserAsync: AsyncMigration {
//    func prepare(on database: Database) async throws {
//        try await database.schema(User.schema)
//            .id()
//            .field("username", .string, .required)
//            .create()
//    }
//
//    func revert(on database: Database) async throws {
//        try await database.schema(User.schema).delete()
//    }
//}



final class Game: Model {
    static let schema = "games"
    
    @ID(key: .id)
    var id: UUID?
    
    @Field(key: "name")
    var name: String
    
    init() {}
    
    init(
        id: UUID? = nil,
        name: String
    ) {
        self.id = id
        self.name = name
    }
    
    public static func create(name: String = "game1", on database: Database) async throws -> Game {
        let game = Game(name: name)
        try await game.save(on: database)
        return game
    }
}

extension Game: HasWallet {
    
    static let idKey = \Game.$id
    
}


struct CreateGame: Migration {
    func prepare(on database: Database) -> EventLoopFuture<Void> {
        return database.schema(Game.schema)
            .id()
            .field("name", .string, .required)
            .create()
    }

    func revert(on database: Database) -> EventLoopFuture<Void> {
        return database.schema(Game.schema).delete()
    }
}

//
//struct CreateGameAsync: AsyncMigration {
//    func prepare(on database: Database) async throws {
//        try await database.schema(Game.schema)
//            .id()
//            .field("name", .string, .required)
//            .create()
//    }
//
//    func revert(on database: Database) async throws {
//        try await database.schema(Game.schema).delete()
//    }
//}
//

