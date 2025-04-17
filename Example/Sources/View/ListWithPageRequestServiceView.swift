//
//  ListWithPageRequestService.swift
//  Example
//
//  Created by Maria Nesterova on 16.04.2025.
//

import SwiftUI
import PagingList

struct ListWithPageRequestServiceView: View {
    @ObservedObject private var viewModel = ListWithPageRequestServiceViewModel()
    
    private let repository = PostRepository()
    
    // swiftlint:disable vertical_parameter_alignment_on_call
    var body: some View {
        PagingList(
            state: $viewModel.state,
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
                viewModel.state = .fullscreenLoading
                viewModel.requestPosts(isFirst: true)
            }
            .listRowSeparator(.hidden)
        } pagingDisabledView: {
            PagingDisabledStateView()
                .listRowSeparator(.hidden)
        } pagingLoadingView: {
            if viewModel.canLoadMore {
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
            if viewModel.canLoadMore && viewModel.state == .fullscreenLoading {
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
            Text(post.description)
                .font(.caption)
        }
    }
}

struct ListWithPageRequestServiceView_Previews: PreviewProvider {
    static var previews: some View {
        ListWithPageRequestServiceView()
    }
}
