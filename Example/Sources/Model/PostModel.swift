//
//  PostModel.swift
//  Example
//
//  Created by Maria Nesterova on 22.04.2025.
//

struct PostModel: Codable, Identifiable, Sendable {
    let id: String
    let title: String
    let description: String
}
