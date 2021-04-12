//
//  File.swift
//  
//
//  Created by Hadi Sharghi on 4/11/21.
//

import Vapor
import Fluent


public class WalletsRepository<M:HasWallet> {
    init(db: Database, idKey: M.ID<UUID>) {
        guard let id = idKey.value else {
            fatalError("Unsaved models can't have wallets")
        }
        self.db = db
        self.id = id
    }

    private var db: Database
    private var id: M.ID<UUID>.Value

    public func create(type name: WalletType = .default, decimalPlaces: UInt8 = 2) -> EventLoopFuture<Wallet> {
        let wallet: Wallet = Wallet(ownerID: self.id, name: name.value, decimalPlaces: decimalPlaces)
        return wallet.save(on: db).map { wallet }
    }
    
    public func all() -> EventLoopFuture<[Wallet]> {
        Wallet.query(on: self.db)
            .filter(\.$owner == self.id)
            .all()
    }
    
    public func get(type name: WalletType) -> EventLoopFuture<Wallet> {
        Wallet.query(on: db)
            .filter(\.$owner == self.id)
            .filter(\.$name == name.value)
            .first()
            .unwrap(or: WalletError.walletNotFound(name: name.value))
    }
    
    public func `default`() -> EventLoopFuture<Wallet> {
        get(type: .default)
    }
    
    public func balance(type name: WalletType = .default, withUnconfirmed: Bool = false, asDecimal: Bool = false) -> EventLoopFuture<Double> {
        if withUnconfirmed {
            return get(type: name).flatMap { wallet  in
                wallet.$transactions
                    .query(on: self.db)
                    .sum(\.$amount)
                    .unwrap(orReplace: 0)
                    .map { (intBalance) -> Double in
                        return asDecimal ? Double(intBalance).rounded(to: wallet.decimalPlaces) : Double(intBalance)
                    }
            }
        }
        return get(type: name).map { wallet in
            return asDecimal ? Double(wallet.balance).rounded(to: wallet.decimalPlaces) : Double(wallet.balance)
        }
    }

    public func canWithdraw(from: WalletType = .default, amount: Int) -> EventLoopFuture<Bool> {
        get(type: from).flatMap { $0.refreshBalance(on: self.db).map { $0 >= Double(amount) } }
    }
    
    public func deposit(to: WalletType = .default, amount: Double, confirmed: Bool = true, meta: [String: String]? = nil) throws -> EventLoopFuture<Void> {
        get(type: to).flatMap { wallet -> EventLoopFuture<Void> in
            let intAmount = Int(amount * Double(wallet.decimalPlaces))
            do {
                return try self.deposit(to: to, amount: intAmount, confirmed: confirmed, meta: meta)
            } catch {
                return self.db.eventLoop.makeFailedFuture(WalletError.walletNotFound(name: to.value))
            }
        }
    }
    
    public func deposit(to: WalletType = .default, amount: Int, confirmed: Bool = true, meta: [String: String]? = nil) throws -> EventLoopFuture<Void> {
        get(type: to).flatMap { wallet -> EventLoopFuture<Void> in
            return self.db.transaction { database -> EventLoopFuture<Void> in
                do {
                    return WalletTransaction(walletID: try wallet.requireID(), type: .deposit, amount: amount, confirmed: confirmed, meta: meta)
                        .save(on: database)
                } catch {
                    return self.db.eventLoop.makeFailedFuture(WalletError.walletNotFound(name: to.value))
                }
            }
        }
    }
    

    public func withdraw(from: WalletType = .default, amount: Int, meta: [String: String]? = nil) -> EventLoopFuture<Void> {
        
        canWithdraw(from: from, amount: amount)
            .guard({ $0 == true }, else: WalletError.insufficientBalance)
            .flatMap { _ in
                self.get(type: from).flatMap { wallet -> EventLoopFuture<Void> in
                    return self.db.transaction { database -> EventLoopFuture<Void> in
                        do {
                            return WalletTransaction(walletID: try wallet.requireID(), type: .withdraw, amount: -1 * amount, meta: meta)
                                .save(on: database)
                        } catch {
                            return database.eventLoop.makeFailedFuture(WalletError.walletNotFound(name: from.value))
                        }
                    }
                }
            }
    }
    
    
    public func transactions(type name: WalletType = .default,
                                        paginate: PageRequest = .init(page: 1, per: 10),
                                        sortOrder: DatabaseQuery.Sort.Direction = .descending) -> EventLoopFuture<Page<WalletTransaction>> {
        return self.get(type: name).flatMap {
            $0.$transactions
                .query(on: self.db)
                .sort(\.$createdAt, sortOrder)
                .filter(\.$confirmed == true)
                .paginate(paginate)
        }
    }

    
    public func unconfirmedTransactions(type name: WalletType = .default,
                                        paginate: PageRequest = .init(page: 1, per: 10),
                                        sortOrder: DatabaseQuery.Sort.Direction = .descending) -> EventLoopFuture<Page<WalletTransaction>> {
        return self.get(type: name).flatMap {
            $0.$transactions
                .query(on: self.db)
                .sort(\.$createdAt, sortOrder)
                .filter(\.$confirmed == false)
                .paginate(paginate)
        }
    }

    public func confirmAll(type name: WalletType = .default) -> EventLoopFuture<Double> {
        get(type: name).flatMap { (wallet) -> EventLoopFuture<Double> in
            self.db.transaction { (database) -> EventLoopFuture<Double> in
                wallet.$transactions
                    .query(on: database)
                    .set(\.$confirmed, to: true)
                    .update()
                    .flatMap { _ -> EventLoopFuture<Double> in
                        wallet.refreshBalance(on: database)
                }
            }
        }
    }
    
    
    public func confirm(transaction: WalletTransaction, refresh: Bool = true) -> EventLoopFuture<Double> {
        transaction.confirmed = true
        return self.db.transaction { (database) -> EventLoopFuture<Double> in
            transaction.update(on: database).flatMap { () -> EventLoopFuture<Double> in
                transaction.$wallet.get(on: database).flatMap { wallet -> EventLoopFuture<Double> in
                    wallet.refreshBalance(on: database)
                }
            }
        }
    }
    
    public func refreshBalance(of walletType: WalletType = .default) -> EventLoopFuture<Double> {
        return get(type: walletType).flatMap { wallet -> EventLoopFuture<Double> in
            wallet.refreshBalance(on: self.db)
        }
    }
    
    
}


extension Double {
    func rounded(to decimalPlaces: UInt8) -> Double {
        let rule = pow(10, Double(decimalPlaces))
        var r = self * rule
        r.round(.towardZero)
        return r / rule
    }
}
