//
//  PostRepository.swift
//  Example
//
//  Created by Maria Nesterova on 16.04.2025.
//

import Foundation

enum PostRepositoryError: Swift.Error {
    case undefined
}

extension PostRepositoryError: LocalizedError {
    var errorDescription: String? {
        switch self {
        case .undefined:
            return "Ooops:("
        }
    }
}

final class PostRepository: Sendable {
    private enum Constants {
        static let delayInNanoseconds: UInt64 = 3_000_000_000
    }
    
    @Sendable
    func getPosts(page: Int, pageSize: Int) async throws -> PostExampleModel {
        try await Task.sleep(nanoseconds: Constants.delayInNanoseconds)
        
        if let postExampleModel = getPostExampleData(page: page, pageSize: pageSize) {
            return postExampleModel
        } else {
            throw PostRepositoryError.undefined
        }
    }
    
    private func getPostExampleData(page: Int, pageSize: Int) -> PostExampleModel? {
        var mockFileName = "MockPostExampleModel"
        let mockExtension = "json"

        mockFileName = "\(mockFileName)&PI=\(page)&PS=\(pageSize)"
        
        guard let mockFileUrl = Bundle.main.url(forResource: mockFileName, withExtension: mockExtension) else {
            return nil
        }

        do {
            let data = try Data(contentsOf: mockFileUrl)
            let posts = try JSONDecoder().decode(PostExampleModel.self, from: data)
            
            return posts
        } catch {
            return nil
        }
    }
}
