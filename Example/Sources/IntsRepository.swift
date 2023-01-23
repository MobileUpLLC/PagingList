//
//  IntsRepository.swift
//  Example
//
//  Created by Nikolai Timonin on 20.01.2023.
//

import Foundation
import PagingList

enum IntsRepositoryError: Swift.Error {
    case undefind
}

extension IntsRepositoryError: LocalizedError {
    var errorDescription: String? {
        switch self {
        case .undefind:
            return "Ooops:("
        }
    }
}

class IntsRepository {
    private enum Constants {
        static let delay: TimeInterval = 1
    }
    
    func getItems(limt: Int, offset: Int, completion: @escaping (Result<[Int], Error>) -> Void) {
        DispatchQueue.main.asyncAfter(deadline: .now() + Constants.delay) {
            if Bool.random() {
                let items = Array(offset..<(offset + limt))
                completion(.success(items))
            } else {
                completion(.failure(IntsRepositoryError.undefind))
            }
        }
    }
}

extension Int: Identifiable {
    public var id: Int { self }
}
