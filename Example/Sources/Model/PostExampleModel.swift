//
//  PostExampleModel.swift
//  Example
//
//  Created by Maria Nesterova on 16.04.2025.
//

import Foundation
import PagingList

struct PostExampleModel: PaginatedResponse {
    let items: [Post]
    let hasMore: Bool?
    
    enum CodingKeys: String, CodingKey {
        case items = "posts"
        case hasMore
    }
}

struct Post: Codable, Identifiable {
    let id: UUID
    let title: String
    let description: String
    let imageUrl: URL?
}
