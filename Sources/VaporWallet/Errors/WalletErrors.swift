import Vapor

enum WalletError: DebuggableError {
    case walletNotFound(name: String)
    case duplicateWalletType(name: String)
    case insufficientBalance
    case invalidTransaction(reason: String)
    case transactionFailed(reason: String)
}

extension WalletError: AbortError {
    var status: HTTPResponseStatus {
        switch self {
        case .walletNotFound(_):
            return .notFound
        case .insufficientBalance,
                .transactionFailed(_),
                .duplicateWalletType(_),
                .invalidTransaction(_):
            return .badRequest
        }
    }
    
    var reason: String {
        switch self {
        case .walletNotFound(let name):
            return "no wallet found with name `\(name)`"
        case .insufficientBalance:
            return "Insufficient balance"
        case .transactionFailed(let reason):
            return "Transaction failed. Reason: \(reason)"
        case .duplicateWalletType(let name):
            return "Duplicate wallet type. Wallet type `\(name)` allready exists."
        case .invalidTransaction(reason: let reason):
            return "Transaction failed. Reason: \(reason)"
        }
    }
    
    var identifier: String {
        switch self {
        case .walletNotFound(_):
            return "wallet_not_found"
        case .insufficientBalance:
            return "insufficient_balance"
        case .transactionFailed(_):
            return "transaction_failed"
        case .duplicateWalletType(_):
            return "duplicate_wallet"
        case .invalidTransaction(_):
            return "invalid_transaction"
        }
    }
    
    
}
