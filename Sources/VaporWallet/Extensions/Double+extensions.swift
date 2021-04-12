//
//  File.swift
//  
//
//  Created by Hadi Sharghi on 4/12/21.
//

import Foundation



extension Double {
    
    func toDecimal(with decimalPlaces: UInt8) -> Double {
        let d = self / pow(10, Double(decimalPlaces))
        return d.rounded(to: decimalPlaces)
    }
    
    func rounded(to decimalPlaces: UInt8) -> Double {
        let rule = pow(10, Double(decimalPlaces))
        var r = self * rule
        r.round(.towardZero)
        return r / rule
    }
}
