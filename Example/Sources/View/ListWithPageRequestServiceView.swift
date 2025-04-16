//
//  ListWithPageRequestService.swift
//  Example
//
//  Created by Maria Nesterova on 16.04.2025.
//

import SwiftUI
import PagingList

struct ListWithPageRequestServiceView: View {
    private enum Constants {
        static let requestLimit = 10
    }
    
    @State private var loadedPagesCount = 0
    @State private var items = [Int]()
    @State private var pagingState: PagingListState = .items
    
    @ObservedObject private var viewModel = ListWithPageRequestServiceViewModel()
    
    private let repository = PostRepository()
    
    // swiftlint:disable vertical_parameter_alignment_on_call
    var body: some View {
        PagingList(
            state: $viewModel.pageRequestService.pagingState,
            items: viewModel.posts
        ) { post in
            PostView(post: post)
                .listRowSeparator(.hidden)
        } fullscreenEmptyView: {
            FullscreenEmptyStateView()
                .listRowSeparator(.hidden)
        } fullscreenLoadingView: {
            FullscreenLoadingStateView()
                .listRowSeparator(.hidden)
        } fullscreenErrorView: { error in
            FullscreenErrorStateView(error: error) {
                pagingState = .fullscreenLoading
                viewModel.requestPosts(isFirst: true)
            }
            .listRowSeparator(.hidden)
        } pagingDisabledView: {
            PagingDisabledStateView()
                .listRowSeparator(.hidden)
        } pagingLoadingView: {
            if viewModel.pageRequestService.canLoadMore {
                PagingLoadingStateView()
                    .listRowSeparator(.hidden)
            }
        } pagingErrorView: { error in
            PagingErrorStateView(error: error) {
                viewModel.requestPosts(isFirst: false)
            }
            .listRowSeparator(.hidden)
        } onPageRequest: { isFirst in
            viewModel.requestPosts(isFirst: isFirst)
        } onRefreshRequest: {
            viewModel.requestPosts(isFirst: true)
        }
        .listStyle(.plain)
        .onAppear {
            if viewModel.pageRequestService.canLoadMore && viewModel.pageRequestService.pagingState == .fullscreenLoading {
                viewModel.requestPosts(isFirst: true)
            }
        }
    }
    // swiftlint:enable vertical_parameter_alignment_on_call
}

private struct PostView: View {
    let post: Post
    
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(post.title)
                .font(.title)
            if let imageUrl = post.imageUrl, let image = downloadImage(url: imageUrl) {
                Image(uiImage: image)
            }
            Text(post.description)
                .font(.caption)
        }
    }
    
    private func downloadImage(url: URL) -> UIImage? {
        var data: Data?
        
        Task {
            let data = try? await URLSession.shared.data(from: url, delegate: nil).0
        }
        
        guard let data, let image = UIImage(data: data) else {
            return nil
        }
        
        return image
    }
}

struct ListWithPageRequestServiceView_Previews: PreviewProvider {
    static var previews: some View {
        ListWithPageRequestServiceView()
    }
}
