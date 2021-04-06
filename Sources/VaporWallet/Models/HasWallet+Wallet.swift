//
//  File.swift
//  
//
//  Created by Hadi Sharghi on 4/6/21.
//

import Vapor
import Fluent


extension HasWallet {
    
    public func createWallet(on db: Database, type name: WalletType) -> EventLoopFuture<Void> {
        let wallet: Wallet = Wallet(ownerID: self._$idKey.value!, name: name.string)
        return wallet.save(on: db)
    }
    
    public func createDefaultWallet(on db: Database) throws -> EventLoopFuture<Void> {
        let wallet: Wallet = Wallet(ownerID: self._$idKey.value!)
        return wallet.save(on: db)
    }
    
    public func wallets(on db: Database) -> EventLoopFuture<[Wallet]> {
        Wallet.query(on: db).filter(\.$owner == self._$idKey.value!).all()
    }
    
    public func wallet(on db: Database, type name: WalletType) -> EventLoopFuture<Wallet> {
        Wallet.query(on: db)
            .filter(\.$owner == self._$idKey.value!)
            .filter(\.$name == name.string)
            .first()
            .unwrap(or: WalletError.walletNotFound(name: name.string))
    }
    
    public func defaultWallet(on db: Database) -> EventLoopFuture<Wallet> {
        wallet(on: db, type: .default)
    }
    
}
