//
//  ListWithPageRequestServiceViewModel.swift
//  Example
//
//  Created by Maria Nesterova on 16.04.2025.
//

import Foundation
import PagingList

final class ListWithPageRequestServiceViewModel: ObservableObject {
    @Published var isLoading: Bool = false
    @Published var posts: [Post] = []
    
    var pageRequestService = PageRequestService<PostExampleModel, Post>()
    
    private let postRepository = PostRepository()
    private var workItem: DispatchWorkItem?
    
    func requestPosts(isFirst: Bool) {
        pageRequestService.request(
            pageSize: 10,
            isFirst: isFirst
        ) { [weak self] requestModel in
            self?.postRepository.getPosts(
                page: requestModel.page,
                pageSize: requestModel.pageSize,
                completion: requestModel.completion
            )
        } resultHandler: { [weak self] in
            switch $0 {
            case .success(let posts):
                self?.posts = posts
            case .failure(let error):
                print(error.localizedDescription)
            }
        }
    }
    
    private func reloadHistory(group: DispatchGroup? = nil, isNeedShowLoading: Bool) {
        let group = group ?? DispatchGroup()
        isLoading = isNeedShowLoading
        
        pageRequestService.reload(group: group)
        
        group.notify(queue: .main) { [weak self] in
            self?.isLoading = false
        }
    }
}
