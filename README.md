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

This package is inspired by  <a href="https://github.com/bavix/laravel-wallet">Laravel-Wallet</a>   

## Usage guide

In your `Package.swift` file, add the following

~~~~swift
.package(url: "https://github.com/hsharghi/vapor-wallet.git", from: "1.0")

.target(name: "App", dependencies: [
    .product(name: "Vapor", package: "vapor"),
    .product(name: "VaporWallet", package: "vapor-wallet")
])
~~~~

### Setup model

Simply conform any `Model` to HasWallet protocol and now your model has a virtual wallet.

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

app.migrations.add(CreateWallet())
app.migrations.add(CreateWalletTransaction())

...
~~~~

Now `User` instances can have access to a wallet.

### Using wallets repository

~~~~swift

let repo = user.walletsRepository(on: db)

try await repo.create()

try await repo.deposit(amount: 100)
try await repo.withdraw(amount: 20, ["description": "paid for some cool stuff"])

~~~~

##### Auto create wallet 

If you want a default wallet to be automatically created when a model is saved to database you can use the provided database middleware with the package:

~~~~swift
app.databases.middleware.use(WalletMiddleware<User>())
~~~~
Now for every `User` model saved to database, a `default` wallet will be created.
 
##### Wallet balance

Wallet balance is not automatically refreshed on every transaction by default. You need to refresh balance to get the updated balance of the wallet.

~~~~swift

try await repo.create()
try await repo.deposit(amount: 100)

let balance = try await repo.balance() 
// balance is Double(0)

let refreshedBalance = try await repo.refreshBalance()
// refreshedBalance is Double(100)

~~~~

It is recommended to add the provided database middleware to auto-refresh wallet balance with each transaction (deposit/withdraw).

~~~~swift
app.databases.middleware.use(WalletTransactionMiddleware())

try await repo.deposit(amount: 100)
let balance = try await repo.balance()
// balance is allways up-to-date 

~~~~


##### Confirm deposit

Deposit to a wallet can be unconfirmed. It will not calculated in wallet balance. you can confirm it later by accessing the transaction's `confirm` method.
After confirming transaction(s), wallets balance is automatically refreshed (unless use `autoRefresh: false` parameter). But if you confirm a transaction manually by running fluent queries,   you need to call `refreshBalance()` method to update the wallet's balance.

~~~~swift

try await repo.deposit(amount: 100, confirmed: false)
// balance is 0

let unconfirmedBalance = try await wallets.balance(withUnconfirmed: true)
// unconfirmedBalance is 100

// OR

try await repo.confirmAll()
// now balance is 100


// manuallty confirm transactions
try await wallet.$transactions
    .query(on: db)
    .set(\.$confirmed, to: true)
    .update()
// balance still is 0

try await repo.refreshBalance()
// now balance is 100
~~~~


#### Multiple wallets

Any model conformed to `HasWallet` can have multiple wallets. 

~~~~swift

let savingsWallet = WalletType(name: "savings")
let myWallet = WalletType(name: "my-wallet")

try await repo.create(type: myWallet)
try await repo.create(type: savingsWallet)

try await repo.deposit(to: myWallet, amount: 100)
try await repo.deposit(to: savingsWallet, amount: 15)

try await repo.withdraw(from: myWallet, amount: 25)
try await repo.balance(type: myWallet)
// balance is 75

~~~~

### Transfering funds between wallets
Funds can be transfered between wallets of same user or different users. Transfering funds between wallets of a single user can be done with wallet types, 


~~~~swift

try await repo.transfer(from: myWallet, to: savingsWallet, amount: 10)

~~~~

But transfering funds to a wallet of another user requires to get the wallet model first, then transfer the fund to it.

~~~~swift

let repo1 = try await user1.walletsRepository(on: db)
let repo2 = try await user2.walletsRepository(on: db)

let walletUser2 = try await repo2.default()
try await repo1.transfer(from: .default, to: walletUser2, amount: 10)
// this will transfer 10 from user1's default wallet to user2's default wallet

~~~~




#### Working with fractional numbers
All transaction amounts and wallet balances are stored as `Integer` values. But balance is allways returned as `Double`. So if you like you can get wallet balance as a decimal value based on decimal places of the wallet.
Deposit and withdraw amounts can be both `Integer` or `Double`, but at the end both will be stored as `Integer`

~~~~swift

try await repo.create(type: .default, decimalPlaces: 2)
try await repo.deposit(amount: 100)
let balance = try await repo.balance() 
// balance is Double(100)


try await repo.deposit(amount: 1.45)
let balance = try await repo.balance() 
// balance is Double(245)   100+145


let decimalBalance = try await repo.balance(asDecimal: true) 
// Double(2.45)


~~~~

All fractional amounts in transactions will be truncated to `decimalPlaces` of the wallet. Default value when creating a wallet is 2.


~~~~swift

try await repo.create(type: .default, decimalPlaces: 2)
try await repo.deposit(amount: 1.555)
let balance = try await repo.balance() 
// balance is 155 not 155.5 and not 1555 


~~~~

### Minimum allowed balance and negative wallet balance
When creating a wallet, default minimum allowed balance is set to 0, so the wallet balance can not be negative.
Any positive or negative value can be set as minimum allowed balance, so you can force a wallet to allways have a minumum balance or even let the wallet to have negative balance.   

~~~~swift

try await repo.create(minAllowedBalance: -50) 
try await repo.deposite(amount: 100)
try await repo.withdraw(amount: 130)
let balance = try await repo.balance()
// balance is -20

~~~~

### Empty a wallet 
You can empty a wallet to zero or minimum allowed balance value which has been set when creating the wallet.

~~~~swift

try await repo.create(minAllowedBalance: -50) 
try await repo.deposite(amount: 100)
try await repo.empty(strategy: .toZero)
// balance is 0
try await repo.empty(strategy: .toMinAllowed)
// balance is -50

~~~~




## Known issues

- Using `HasWallet` protocol is limited to models with `UUID` primary key.
- Transfering funds between wallets with different `decimalPlaces` values have unknown result.

