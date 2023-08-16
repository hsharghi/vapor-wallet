//
//  File.swift
//
//
//  Created by Hadi Sharghi on 12/5/20.
//


import Vapor
import Fluent


public struct WalletMiddleware<M:HasWallet>: AsyncModelMiddleware {
    private var walletType: WalletType
    private var decimalPlaces: UInt8
    private var minAllowedBalance: Int
    
    public init(walletType: WalletType = .default, decimalPlaces: UInt8 = 0, minAllowedBalace: Int = 0) {
        self.walletType = walletType
        self.decimalPlaces = decimalPlaces
        self.minAllowedBalance = minAllowedBalace
    }

    public func create(model: M, on db: Database, next: AnyAsyncModelResponder) async throws {
        try await next.create(model, on: db)
        db.logger.log(level: .info, "default wallet for user \(model.id!) has been created")
        let repo = model.walletsRepository(on: db)
        try await repo.create(type: walletType, decimalPlaces: decimalPlaces, minAllowedBalance: minAllowedBalance)
    }
}
