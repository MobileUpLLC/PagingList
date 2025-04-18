//
//  ListWithPageRequestServiceViewModel.swift
//  Example
//
//  Created by Maria Nesterova on 16.04.2025.
//

import Foundation
import PagingList

@MainActor
final class ListWithPageRequestServiceViewModel: ObservableObject {
    private enum Constants {
        static let requestLimit = 10
    }
    
    @Published var posts: [Post] = []
    @Published var pagingState: PagingListState = .fullscreenLoading
    @Published var canLoadMore: Bool = true
    
    var pageRequestService: PageRequestService<PostExampleModel, Post>
    
    private let postRepository: PostRepository
    
    init(postRepository: PostRepository = PostRepository()) {
        self.postRepository = postRepository
        pageRequestService = PageRequestService(startPage: 1, fetchPage: postRepository.getPosts(page:pageSize:))
    }
    
    func requestPosts(isFirst: Bool) {
        Task {
            do {
                try await pageRequestService.request(pageSize: Constants.requestLimit, isFirst: isFirst)
                let posts = await pageRequestService.getItems()
                let pagingState = await pageRequestService.getPagingState()
                let canLoadMore = await pageRequestService.getCanLoadMore()
                self.posts = posts
                self.pagingState = pagingState
                self.canLoadMore = canLoadMore
            } catch {
                let pagingState = await pageRequestService.getPagingState()
                let canLoadMore = await pageRequestService.getCanLoadMore()
                self.pagingState = pagingState
                self.canLoadMore = canLoadMore
            }
        }
    }
}
