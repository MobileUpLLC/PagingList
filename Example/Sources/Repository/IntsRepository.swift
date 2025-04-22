//
//  IntsRepository.swift
//  Example
//
//  Created by Nikolai Timonin on 20.01.2023.
//

import Foundation

final class IntsRepository: Sendable {
    private enum Constants {
        static let delayInNanoseconds: UInt64 = 3_000_000_000
    }
    
    func getItems(limit: Int, offset: Int) async throws -> [Int] {
        await Task {
            try? await Task.sleep(nanoseconds: Constants.delayInNanoseconds)
        }.value
        
        if Bool.random() {
            let items = offset < 65 ? Array(offset..<(offset + limit)) : []
            return items
        } else {
            throw IntsRepositoryError.undefined
        }
    }
}

extension Int: @retroactive Identifiable {
    public var id: Int { self }
}
