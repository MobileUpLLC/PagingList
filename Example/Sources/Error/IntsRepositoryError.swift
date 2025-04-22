//
//  IntsRepositoryError.swift
//  Example
//
//  Created by Maria Nesterova on 22.04.2025.
//

import Foundation

enum IntsRepositoryError: Swift.Error {
    case undefined
}

extension IntsRepositoryError: LocalizedError {
    var errorDescription: String? {
        switch self {
        case .undefined:
            return "Undefined error"
        }
    }
}
