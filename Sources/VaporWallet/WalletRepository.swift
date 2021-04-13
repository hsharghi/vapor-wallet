//
//  File.swift
//  
//
//  Created by Hadi Sharghi on 4/11/21.
//

import Vapor
import Fluent

/// This calss gives access to wallet methods for a `HasWallet` model.
/// Creating multiple wallets, accessing them and getting balance of each wallet,
/// deposit, withdrawal and transfering funds to/from and between wallets
/// can be done through this class methods.
public class WalletsRepository<M:HasWallet> {
    internal init(db: Database, idKey: M.ID<UUID>) {
        guard let id = idKey.value else {
            fatalError("Unsaved models can't have wallets")
        }
        self.db = db
        self.id = id
    }

    private var db: Database
    private var id: M.ID<UUID>.Value
}

///
/// Creating and getting wallets and their balance
///
extension WalletsRepository {
    
    public func create(type name: WalletType = .default, decimalPlaces: UInt8 = 2) -> EventLoopFuture<Void> {
        let wallet: Wallet = Wallet(ownerID: self.id, name: name.value, decimalPlaces: decimalPlaces)
        return wallet.save(on: db)
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
                        return asDecimal ? Double(intBalance).toDecimal(with: wallet.decimalPlaces) : Double(intBalance)
                    }
            }
        }
        return get(type: name).map { wallet in
            return asDecimal ? Double(wallet.balance).toDecimal(with: wallet.decimalPlaces) : Double(wallet.balance)
        }
    }
    
    public func refreshBalance(of walletType: WalletType = .default) -> EventLoopFuture<Double> {
        return get(type: walletType).flatMap { wallet -> EventLoopFuture<Double> in
            wallet.refreshBalance(on: self.db)
        }
    }
    
}


///
/// Withdraw, deposit and transfer funds to, from and between wallets
///
extension WalletsRepository {
    
    public func canWithdraw(from: WalletType = .default, amount: Int) -> EventLoopFuture<Bool> {
        get(type: from).flatMap { self._canWithdraw(from: $0, amount: amount) }
    }
    
    public func withdraw(from: WalletType = .default, amount: Double, meta: [String: String]? = nil) -> EventLoopFuture<Void> {
        get(type: from).flatMap { wallet -> EventLoopFuture<Void> in
            let intAmount = Int(amount * pow(10, Double(wallet.decimalPlaces)))
            return self._withdraw(on: self.db, from: wallet, amount: intAmount, meta: meta)
        }
    }

    public func withdraw(from: WalletType = .default, amount: Int, meta: [String: String]? = nil) -> EventLoopFuture<Void> {
        
        canWithdraw(from: from, amount: amount)
            .guard({ $0 == true }, else: WalletError.insufficientBalance)
            .flatMap { _ in
                self.get(type: from).flatMap { wallet -> EventLoopFuture<Void> in
                    self._withdraw(on: self.db, from: wallet, amount: amount, meta: meta)
                }
            }
    }
 
    public func deposit(to: WalletType = .default, amount: Double, confirmed: Bool = true, meta: [String: String]? = nil) -> EventLoopFuture<Void> {
        get(type: to).flatMap { wallet -> EventLoopFuture<Void> in
            let intAmount = Int(amount * pow(10, Double(wallet.decimalPlaces)))
            return self._deposit(on: self.db, to: wallet, amount: intAmount, confirmed: confirmed, meta: meta)
        }
    }
    
    public func deposit(to: WalletType = .default, amount: Int, confirmed: Bool = true, meta: [String: String]? = nil) -> EventLoopFuture<Void> {
        get(type: to).flatMap { wallet -> EventLoopFuture<Void> in
            self._deposit(on: self.db, to: wallet, amount: amount, confirmed: confirmed, meta: meta)
        }
    }
    
    public func transafer(from: Wallet, to: Wallet, amount: Int, meta: [String: String]? = nil) -> EventLoopFuture<Void> {
        return _canWithdraw(from: from, amount: amount)
            .guard({ $0 == true }, else: WalletError.insufficientBalance)
            .flatMap { _ in
                self._transfer(from: from, to: to, amount: amount, meta: meta)
            }
    }
    
    public func transfer(from: WalletType, to: Wallet, amount: Int, meta: [String: String]? = nil) -> EventLoopFuture<Void> {
        return get(type: from).flatMap { fromWallet -> EventLoopFuture<Void> in
            self._canWithdraw(from: fromWallet, amount: amount)
                .guard({ $0 == true }, else: WalletError.insufficientBalance)
                .flatMap { _ in
                    return self._transfer(from: fromWallet, to: to, amount: amount, meta: meta)
                }
        }
    }
    
    public func transafer(from: WalletType, to: WalletType, amount: Int, meta: [String: String]? = nil) -> EventLoopFuture<Void> {
        return get(type: to).flatMap { toWallet -> EventLoopFuture<Void> in
            self.transfer(from: from, to: toWallet, amount: amount, meta: meta)
        }
    }

}


///
/// Accessing transactions of a wallet and confirming transactions
///
extension WalletsRepository {
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
    
}

///
/// Private methdos
///
extension WalletsRepository {
    private func _canWithdraw(from: Wallet, amount: Int) -> EventLoopFuture<Bool> {
        from.refreshBalance(on: self.db).map { $0 >= Double(amount) }
    }
    
    private func _deposit(on db: Database, to: Wallet, amount: Int, confirmed: Bool = true, meta: [String: String]? = nil) -> EventLoopFuture<Void> {
        return db.transaction { database -> EventLoopFuture<Void> in
            do {
                return WalletTransaction(walletID: try to.requireID(), type: .deposit, amount: amount, confirmed: confirmed, meta: meta)
                    .save(on: database)
            } catch {
                return self.db.eventLoop.makeFailedFuture(WalletError.walletNotFound(name: to.name))
            }
        }
    }
    
    private func _withdraw(on db: Database, from: Wallet, amount: Int, meta: [String: String]? = nil) -> EventLoopFuture<Void> {
        return db.transaction { database -> EventLoopFuture<Void> in
            do {
                return WalletTransaction(walletID: try from.requireID(), type: .withdraw, amount: -1 * amount, meta: meta)
                    .save(on: database)
            } catch {
                return database.eventLoop.makeFailedFuture(WalletError.walletNotFound(name: from.name))
            }
        }
    }

    private func _transfer(from: Wallet, to: Wallet, amount: Int, meta: [String: String]? = nil) -> EventLoopFuture<Void> {
        return self.db.transaction { (database) -> EventLoopFuture<Void> in
            return self._withdraw(on: database, from: from, amount: amount, meta: meta).flatMap { _ ->  EventLoopFuture<Void> in
                self._deposit(on: database, to: to, amount: amount, meta: meta).flatMap { _ ->  EventLoopFuture<Void> in
                    let refreshFrom = from.refreshBalance(on: database)
                    let refreshTo = to.refreshBalance(on: database)
                    return refreshFrom.and(refreshTo).flatMap { (_, _) -> EventLoopFuture<Void> in
                        database.eventLoop.makeSucceededFuture(())
                    }
                }
            }
        }
    }
    
}
    
