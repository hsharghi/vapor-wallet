import Vapor

enum WalletError: DebuggableError {
    case walletNotFound(name: String)
    case insufficientBalance
    case transactionFailed(reason: String)
}

extension WalletError: AbortError {
    var status: HTTPResponseStatus {
        switch self {
        case .walletNotFound(_):
            return .notFound
        case .insufficientBalance:
            return .badRequest
        case .transactionFailed(_):
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
        }
    }
    
    var identifier: String {
        switch self {
        case .walletNotFound(_):
            return "wallet_not_found"
        case .insufficientBalance:
            return "insufficient_balance"
        case .transactionFailed:
            return "transaction_failed"
        }
    }
    
    
}
