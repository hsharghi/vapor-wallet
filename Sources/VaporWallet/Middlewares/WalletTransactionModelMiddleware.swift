//
//  File.swift
//  
//
//  Created by Hadi Sharghi on 12/5/20.
//

import Vapor
import Fluent



public struct WalletTransactionMiddleware: ModelMiddleware {
    
    public init() {}

    public func create(model: WalletTransaction, on db: Database, next: AnyModelResponder) -> EventLoopFuture<Void> {
        return next.create(model, on: db).flatMap {
            return model
                .$wallet.get(on: db)
                .map { $0.refreshBalance(on: db) }
                .transform(to: ())
        }
    }
}

public struct AsyncWalletTransactionMiddleware: AsyncModelMiddleware {
    
    public init() {}

    public func create(model: WalletTransaction, on db: Database, next: AnyAsyncModelResponder) async throws {
        try await next.create(model, on: db)
        let wallet = try await model.$wallet.get(on: db)
        _ = try await wallet.refreshBalanceAsync(on: db)
    }
}

