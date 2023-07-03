//
//  IntsRepository.swift
//  Example
//
//  Created by Nikolai Timonin on 20.01.2023.
//

import Foundation

enum IntsRepositoryError: Swift.Error {
    case undefined
}

extension IntsRepositoryError: LocalizedError {
    var errorDescription: String? {
        switch self {
        case .undefined:
            return "Ooops:("
        }
    }
}

class IntsRepository {
    private enum Constants {
        static let delay: TimeInterval = 1
    }
    
    func getItems(limit: Int, offset: Int, completion: @escaping (Result<[Int], Error>) -> Void) {
        DispatchQueue.main.asyncAfter(deadline: .now() + Constants.delay) {
            if Bool.random() {
                let items = offset < 40 ? Array(offset..<(offset + limit)) : []
                completion(.success(items))
            } else {
                completion(.failure(IntsRepositoryError.undefined))
            }
        }
    }
}

extension Int: Identifiable {
    public var id: Int { self }
}
