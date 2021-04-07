//
//  File.swift
//  
//
//  Created by Hadi Sharghi on 12/5/20.
//


import Foundation

public struct WalletType: Hashable, Codable {
    public let string: String
    public init(string: String) {
        self.string = string
    }
}

extension WalletType {
    public static var `default`: WalletType {
        return .init(string: "default")
    }
}
