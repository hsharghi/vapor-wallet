# VaporWallet

<p align="center">
    <a href="https://vapor.codes">
        <img src="http://img.shields.io/badge/Vapor-4-brightgreen.svg" alt="Vapor Logo">
    </a>
    <a href="https://swift.org">
        <img src="http://img.shields.io/badge/Swift-5.2-brightgreen.svg" alt="Swift 5.2 Logo">
    </a>
    <a href="https://raw.githubusercontent.com/lloople/vapor-maker-commands/main/LICENSE">
        <img src="https://img.shields.io/badge/license-MIT-blue.svg" alt="MIT License">
    </a>
</p>

### VaporWallet - Easy to work with virtual wallet for Swift Vapor framework

## Usage guide

In your `Package.swift` file, add the following

~~~~swift
.package(url: "https://github.com/hsharghi/vapor-wallet.git", from: "0.9")

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

### Using wallets repository

~~~~swift

let repo = user.walletsRepository(on: db)

try repo.create()

try repo.deposit(amount: 100)
try repo.withdraw(amount: 20, ["description": "buy some cool feature"])

~~~~

##### Auto create wallet 

If you want a default wallet to be created when a model is saved to database you can use the provided database middleware with the package:

~~~~swift
app.databases.middleware.use(WalletMiddleware<User>())
~~~~

##### Wallet balance

Wallet balance is not automatically refreshed on every transaction by default. You need to refresh balance to get the updated balance of the wallet.

~~~~swift

try repo.create()
try repo.deposit(amount: 100)

repo.default().balance().map { balance in 
    // balance is Double(100)
}

~~~~

It is recommended to add the provided database middleware to auto-refresh wallet balance with each transaction (deposit/withdraw).

~~~~swift
app.databases.middleware.use(WalletTransactionMiddleware())


repo.balance().map { balance in 
    // balance is allways up-to-date 
}

~~~~


##### Confirm deposit

Deposit to a wallet can be unconfirmed. It will not calculated in wallet balance. you can confirm it later by accessing the transaction's `confirm` method.
After confirming transaction(s), wallets balance is automatically refreshed (unless use `autoRefresh: false` parameter). But if you confirm a transaction manually by running fluent queries,   you need to call `refreshBalance()` method to update the wallet's balance.

~~~~swift

repo.deposit(amount: 100, confirmed: false)
// balance is 0

repo.unconfirmedTransactions().map { transactions in
    transactions.map { repo.confirm(transaction: $0 }
}
// balance is 100

// OR

repo.confirmAll(type: .default)
// balance is 100


// manuallty confirm transactions
wallet.$transactions.query(on: db)
.set(\.$confirmed, to: true)
.update()
// balance is 0

repo.refreshBalance()
// now balance is 100
~~~~


#### Multiple wallets

Any model conformed to `HasWallet` can have multiple wallets. 

~~~~swift

let savingsWallet = WalletType(name: "savings")
let myWallet = WalletType(name: "my-wallet")

repo.create(type: myWallet)
repo.create(type: savingsWallet)

repo.deposit(to: myWallet, amount: 100)
repo.deposit(to: savingsWallet, amount: 15)

repo.withdraw(from: myWallet, amount: 25)
repo.balance(type: myWallet)
// balance is 75

~~~~

### Transfering funds between wallets
Funds can be transfered between wallets of same user or different users. Transfering funds between wallets of a single user can be done with wallet types, 


~~~~swift

repo.transfer(from: myWallet, to: savingsWallet, amount: 10)

~~~~

But transfering funds to a wallet of another user requires to get the wallet model first, then transfer the fund to it.

~~~~swift

let repo1 = user1.walletsRepository(on: db)
let repo2 = user2.walletsRepository(on: db)

repo2.default().map { walletUser2 in
    repo1.transfer(from: .default, to: walletUser2, amount: 10)
    // this will transfer 10 from user1's default wallet to user2's default wallet
}

~~~~




#### Working with fractional numbers
All transaction amounts and wallet balances are stored as `Integer` values. But balance is allways returned as `Double`. So if you like you can get wallet balance as a decimal value based on decimal places of the wallet.
Deposit and withdraw amounts can be both `Integer` or `Double`, but at the end both will be stored as `Integer`

~~~~swift

repo.create(type: .default, decimalPlaces: 2)
repo.deposit(amount: 100)
repo.balance().map { balance in 
    // balance is Double(100)
}

repo.deposit(amount: 1.45)
repo.balance().map { balance in 
    // balance is Double(245)   100+145
}

repo.balance(asDecimal: true).map { balance in 
    // Double(2.45)
}

~~~~

All fractional amounts in transactions will be truncated to `decimalPlaces` of the wallet. Default value when creating a wallet is 2.


~~~~swift

repo.create(type: .default, decimalPlaces: 2)
repo.deposit(amount: 1.555)
repo.balance().map { balance in 
    // balance is 155 not 155.5 and not 1555 
}


~~~~


## Known issues

- Using `HasWallet` protocol is limited to models with `UUID` primary key.
- Transfering funds between wallets with different `decimalPlaces` values have unknown result.

