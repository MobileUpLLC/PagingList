//
//  IntsRepository.swift
//  Example
//
//  Created by Nikolai Timonin on 20.01.2023.
//

import Foundation
import PagingList
import SwiftUI

enum ItemsRepositoryError: Swift.Error {
    case undefind
}

extension ItemsRepositoryError: LocalizedError {
    var errorDescription: String? {
        switch self {
        case .undefind:
            return "Ooops:("
        }
    }
}

class ItemsRepository {
    private enum Constants {
        static let delay: TimeInterval = 1
    }
    
    func getItems(limt: Int, offset: Int, completion: @escaping (Result<[Int], Error>) -> Void) {
        DispatchQueue.main.asyncAfter(deadline: .now() + Constants.delay) {
            if Bool.random() {
                let items = Array(offset..<(offset + limt))
                completion(.success(items))
            } else {
                completion(.failure(ItemsRepositoryError.undefind))
            }
        }
    }
}

extension Int: Identifiable {
    public var id: Int { self }
}

class IntsProvider: LimitOffsetPageProvider {
    @Published var allItems: [Int] = []
    var loadedPagesCount: Int = 0
    
    private let repository = ItemsRepository()
    
    func getItems(offset: Int, limit: Int, compeltion: @escaping (Result<[Int], Error>) -> Void) {
        repository.getItems(limt: limit, offset: offset, completion: compeltion)
    }
}
