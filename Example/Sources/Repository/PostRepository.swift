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

class PostRepository {
    private enum Constants {
        static let delayInNanoseconds: UInt64 = 3_000_000_000
    }
    
    func getPosts(
        page: Int,
        pageSize: Int,
        completion: @escaping (Result<PostExampleModel, Error>) -> Void
    ) {
        Task {
            await Task {
                try? await Task.sleep(nanoseconds: Constants.delayInNanoseconds)
            }.value
            
            if let postExampleModel = getPostExampleData(pageIndex: page, pageSize: pageSize) {
                completion(.success(postExampleModel))
            } else {
                completion(.failure(PostRepositoryError.undefined))
            }
        }
    }
    
    private func getPostExampleData(pageIndex: Int, pageSize: Int) -> PostExampleModel? {
        var mockFileName = "MockPostExampleModel"
        let mockExtension = "json"

        mockFileName = "\(mockFileName)&PI=\(pageIndex)&PS=\(pageSize)"
        
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
