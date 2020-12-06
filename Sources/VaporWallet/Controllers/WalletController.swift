//
//  File.swift
//  
//
//  Created by Hadi Sharghi on 12/5/20.
//

import Vapor
import Fluent

struct WalletController: RouteCollection {

    func boot(routes: RoutesBuilder) throws {

        routes.group("wallets") { route in
                route.get("", use: getWallets)
                route.get("", ":name", use: getWallet)
            }

    }
    
    private func getWallets(_ req: Request) throws -> EventLoopFuture<[Wallet]> {
        return req.eventLoop.future([])
    }
    
    private func getWallet(_ req: Request) throws -> EventLoopFuture<Wallet> {
        throw WalletError.walletNotFound(name: "")
    }


}
