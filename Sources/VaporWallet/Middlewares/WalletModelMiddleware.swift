//
//  File.swift
//
//
//  Created by Hadi Sharghi on 12/5/20.
//


import Vapor
import Fluent


public struct WalletMiddleware<M:HasWallet>: AsyncModelMiddleware {
    
    public init() {}

    public func create(model: M, on db: Database, next: AnyAsyncModelResponder) async throws {
        try await next.create(model, on: db)
        db.logger.log(level: .info, "default wallet for user \(model.id!) has been created")
        let repo = model.walletsRepository(on: db)
        try await repo.create()
    }
}
