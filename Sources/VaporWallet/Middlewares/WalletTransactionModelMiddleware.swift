//
//  File.swift
//  
//
//  Created by Hadi Sharghi on 12/5/20.
//

import Vapor
import Fluent

public struct WalletTransactionMiddleware: AsyncModelMiddleware {
    
    public init() {}

    public func create(model: WalletTransaction, on db: Database, next: AnyAsyncModelResponder) async throws {
        try await next.create(model, on: db)
        let wallet = try await model.$wallet.get(on: db)
        _ = try await wallet.refreshBalance(on: db)
    }
}

