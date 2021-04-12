//
//  File.swift
//  
//
//  Created by Hadi Sharghi on 4/12/21.
//

import NIO

extension EventLoopFuture {
    public func throwingFlatMap<NewValue>(_ transform: @escaping (Value) throws -> EventLoopFuture<NewValue>) -> EventLoopFuture<NewValue> {
        flatMap { value in
            do {
                return try transform(value)
            } catch {
                return self.eventLoop.makeFailedFuture(error)
            }
        }
    }
}
