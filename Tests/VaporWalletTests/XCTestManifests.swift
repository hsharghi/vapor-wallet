import XCTest

extension VaporWalletTests {
    static let allTests = [
        ("testAddUser", testAddUser),
        ("testAddGame", testAddGame),
        ("testUserHasNoDefaultWallet", testUserHasNoDefaultWallet),
        ("testUserHasDefaultWallet", testUserHasDefaultWallet),
        ("testCreateWallet", testCreateWallet),
        ("testWalletDeposit", testWalletDeposit),
        ("testWalletTransactionMiddleware", testWalletTransactionMiddleware),
        ("testWalletWithdraw", testWalletWithdraw),
        ("testWalletCanWithdraw", testWalletCanWithdraw),
        ("testWalletCanWithdrawWithMinAllowedBalance", testWalletCanWithdrawWithMinAllowedBalance),
        ("testMultiWallet", testMultiWallet),
        ("testTransactionMetadata", testTransactionMetadata),
        ("testWalletDecimalBalance", testWalletDecimalBalance),
        ("testConfirmTransaction", testConfirmTransaction),
        ("testConfirmAllTransactionsOfWallet", testConfirmAllTransactionsOfWallet),
        ("testTransferBetweenAUsersWallets", testTransferBetweenAUsersWallets),
        ("testTransferBetweenTwoUsersWallets", testTransferBetweenTwoUsersWallets),
        ("testMultiModelWallet", testMultiModelWallet),
        ("testMultiModelWalletTransfer", testMultiModelWalletTransfer),
    ]
}

#if !canImport(ObjectiveC)
public func allTests() -> [XCTestCaseEntry] {
        return [
            testCase(VaporWalletTests.allTests),
        ]
}
#endif
