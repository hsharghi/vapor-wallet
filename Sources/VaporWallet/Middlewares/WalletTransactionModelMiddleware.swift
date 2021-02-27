//
//  File.swift
//  
//
//  Created by Hadi Sharghi on 12/5/20.
//

import Vapor
import Fluent



public struct WalletTransactionMiddleware: ModelMiddleware {
    
    public func create(model: WalletTransaction, on db: Database, next: AnyModelResponder) -> EventLoopFuture<Void> {
        // The model can be altered here before it is created.
        
        return next.create(model, on: db).flatMap {
            return model
                .wallet
                .refreshBalance(on: db)
                .transform(to: db.eventLoop.future(()))
        }
    }
    
}
