# VaporWallet

![Swift](http://img.shields.io/badge/swift-5.2-brightgreen.svg)
![Vapor](http://img.shields.io/badge/vapor-4.0-brightgreen.svg)


### vapor-wallet - Easy to work with virtual wallet for Swift Vapor framework
This package is inspired by ![laravel-wallet](https://github.com/bavix/laravel-wallet)

## Usage guide

In your `Package.swift` file, add the following

~~~~swift
.package(url: "https://github.com/hsharghi/vapor-wallet.git", from: "0.6")

.target(name: "App", dependencies: [
    .product(name: "Vapor", package: "vapor"),
    .product(name: "VaporWallet", package: "vapor-wallet")
])
~~~~

### Setup model

Simply conform any `Model` to HasWallet protocol and now you model has a virtual wallet.

~~~~swift

final class User: Model {
    static let schema = "users"
    
    @ID(key: .id)
    var id: UUID?
    
    ...
}

extension User: HasWallet {
    static let idKey = \User.$id
}
~~~~

### Configure

In configure add migrations 

~~~~swift
import VaporWallet

public func configure(_ app: Application) throws {
...

app.migrations.add(CreateWallet<User>())
app.migrations.add(CreateWalletTransaction())

...
~~~~

Now `User` instances can have access to a wallet.

~~~~swift

try user.createWallet(on: db, type: .default)

try user.deposit(on: db, to: .default, amount: 100)

try user.withdraw(on: db, from: .default, amount: 20, ["description": "buy some cool feature"])
    
~~~~

##### Auto create wallet 

If you want a default wallet to be created when a model is saved to database you can use the provided database middleware with the package:

~~~~swift
app.databases.middleware.use(WalletMiddleware<User>(), on: .psql)
~~~~

##### Wallet balance

Wallet balance is not automatically refreshed on every transaction by default. You need to refresh balance to get the updated balance of the wallet.

~~~~swift
user.wallet(on: db, type: .default).map { wallet in
    wallet.refreshBalance(on: db).map { balance in
        // balance is a Double
    }
}
~~~~

It is recommended to add the provided database middleware to auto-refresh wallet balance with each transaction (deposit/withdraw).

~~~~swift
app.databases.middleware.use(WalletTransactionMiddleware(), on: .psql)


user.walletBalance(on: db).map { balance in 
    // balance is allways up-to-date 
}

~~~~


##### Confirm deposit

Deposit to a wallet can be unconfirmed. It will not calculated in wallet balance. you can confirm it later by accessing the transaction's `confirm` method.

~~~~swift

user.deposit(on: db, amount: 100, confirmed: false)
// balance is 0

user.unconfirmedTransactions(on: db).map { transactions in
    transactions.map { $0.confirm(on: db) }
}

user.defaultWallet(on: db).refereshBalance(on: db)

// balance is 100
~~~~


