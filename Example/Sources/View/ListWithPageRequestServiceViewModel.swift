//
//  ListWithPageRequestServiceViewModel.swift
//  Example
//
//  Created by Maria Nesterova on 16.04.2025.
//

import Foundation
import PagingList

final class ListWithPageRequestServiceViewModel: ObservableObject {
    private enum Constants {
        static let requestLimit = 10
    }
    
    @Published var posts: [Post] = []
    @Published var state: PagingListState = .fullscreenLoading
    @Published var canLoadMore: Bool = true
    
    var pageRequestService: PageRequestService<PostExampleModel, Post>
    
    private let postRepository = PostRepository()
    private var workItem: DispatchWorkItem?
    
    init() {
        pageRequestService = PageRequestService(startPage: 1, fetchPage: postRepository.getPosts(page:pageSize:))
        pageRequestService.$items
            .receive(on: DispatchQueue.main) // Ensure updates on main thread
            .assign(to: &$posts) // Assign directly to @Published property
        
        // Subscribe to pagingState publisher
        pageRequestService.$pagingState
            .receive(on: DispatchQueue.main) // Ensure updates on main thread
            .assign(to: &$state)
    }
    
    func requestPosts(isFirst: Bool) {
        Task {
            do {
                try await pageRequestService.request(pageSize: 10, isFirst: isFirst)
                let canLoadMore = await pageRequestService.getCanLoadMore()
                await MainActor.run {
                    self.posts = self.pageRequestService.items
                    self.canLoadMore = canLoadMore
                }
            } catch {
                let canLoadMore = await pageRequestService.getCanLoadMore()
                self.canLoadMore = canLoadMore
            }
        }
    }
    
    //    func requestPosts(isFirst: Bool) {
    //        pageRequestService.request(
    //            pageSize: 10,
    //            isFirst: isFirst
    //        ) { [weak self] requestModel in
    //            self?.postRepository.getPosts(
    //                page: requestModel.page,
    //                pageSize: requestModel.pageSize,
    //                completion: requestModel.completion
    //            )
    //        } resultHandler: { [weak self] in
    //            switch $0 {
    //            case .success(let posts):
    //                self?.posts += posts
    //            case .failure(let error):
    //                print(error.localizedDescription)
    //            }
    //        }
    //    }
    func reload() {
        Task {
            do {
                try await pageRequestService.reload(pageSize: 10)
                let canLoadMore = await pageRequestService.getCanLoadMore()
                await MainActor.run {
                    self.posts = self.pageRequestService.items
                    self.canLoadMore = canLoadMore
                }
            } catch {
                let canLoadMore = await pageRequestService.getCanLoadMore()
                await MainActor.run {
                    self.canLoadMore = canLoadMore
                }
            }
        }
    }
    //    private func reloadHistory(group: DispatchGroup? = nil, isNeedShowLoading: Bool) {
    //        let group = group ?? DispatchGroup()
    //        isLoading = isNeedShowLoading
    //
    //        pageRequestService.reload(group: group)
    //
    //        group.notify(queue: .main) { [weak self] in
    //            self?.isLoading = false
    //        }
    //    }
}
