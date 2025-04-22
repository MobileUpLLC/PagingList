//
//  ListWithPageRequestService.swift
//  Example
//
//  Created by Maria Nesterova on 16.04.2025.
//

import SwiftUI
import PagingList

struct ListWithPageRequestServiceView: View {
    @StateObject private var viewModel = ListWithPageRequestServiceViewModel()
    
    private let repository = PostsRepository()
    
    // swiftlint:disable vertical_parameter_alignment_on_call
    var body: some View {
        PagingList(
            state: $viewModel.pagingState,
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
                viewModel.pagingState = .fullscreenLoading
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
            viewModel.requestPosts(isFirst: true)
        }
    }
    // swiftlint:enable vertical_parameter_alignment_on_call
}

private struct PostView: View {
    let post: PostModel
    
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(post.title)
                .font(.title)
            Text(post.description)
                .font(.caption)
        }
    }
}

#Preview {
    ListWithPageRequestServiceView()
}
