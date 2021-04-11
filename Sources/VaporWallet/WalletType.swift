//
//  File.swift
//  
//
//  Created by Hadi Sharghi on 12/5/20.
//


import Foundation

public struct WalletType: Hashable, Codable {
    private let string: String
    public init(name: String) {
        self.string = name
    }
}

extension WalletType {
    public static var `default`: WalletType {
        return .init(name: "default")
    }
    
    public var value: String {
        return self.string
    }
}
