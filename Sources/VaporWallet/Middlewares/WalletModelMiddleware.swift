//
//  File.swift
//
//
//  Created by Hadi Sharghi on 12/5/20.
//


import Vapor
import Fluent

public struct WalletMiddleware<M:HasWallet>: ModelMiddleware {
    
    public init() {}

    public func create(model: M, on db: Database, next: AnyModelResponder) -> EventLoopFuture<Void> {

        // Create `default` wallet when new model is created
        return next.create(model, on: db).flatMap {
            print ("default wallet for user \(model._$username) has been created")
            return try! model.createDefaultWallet(on: db).transform(to: ())
        }
    }
}
