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
    
    public static func create(username: String = "user1", on database: Database) throws -> User {
        let user = User(username: username)
        try user.save(on: database).wait()
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


