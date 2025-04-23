//
//  PostExampleModel.swift
//  Example
//
//  Created by Maria Nesterova on 16.04.2025.
//

import Foundation
import PagingList

struct PostExampleModel: PaginatedResponse {
    let items: [PostModel]
    // swiftlint:disable:next discouraged_optional_boolean
    let hasMore: Bool?
    var totalPages: Int?
    var currentPage: Int?
    
    enum CodingKeys: String, CodingKey {
        case items = "posts"
        case hasMore, totalPages, currentPage
    }
}
