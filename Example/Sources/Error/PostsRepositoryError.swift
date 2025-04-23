//
//  PostsRepositoryError.swift
//  Example
//
//  Created by Maria Nesterova on 22.04.2025.
//

import Foundation

enum PostsRepositoryError: Swift.Error {
    case undefined
}

extension PostsRepositoryError: LocalizedError {
    var errorDescription: String? {
        switch self {
        case .undefined:
            return "Undefined error"
        }
    }
}
