//
//  ContentView.swift
//  Example
//
//  Created by Nikolai Timonin on 17.01.2023.
//

import SwiftUI
import PagingList

struct ContentView: View {
    private enum Constants {
        static let requestLimit = 20
    }
    
    @State private var loadedPagesCount = 0
    @State private var items = [Int]()
    @State private var pagingState: PagingListState = .items
   
    private let repository = IntsRepository()
    
    // swiftlint:disable vertical_parameter_alignment_on_call
    var body: some View {
        PagingList(
            state: $pagingState,
            items: items
        ) { item in
            Text("\(item)")
        } fullscreenEmptyView: {
            FullscreenEmptyStateView()
        } fullscreenLoadingView: {
            FullscreenLoadingStateView()
        } fullscreenErrorView: { error in
            FullscreenErrorStateView(error: error) {
                // Show fullscreen loading on retry action.
                pagingState = .fullscreenLoading
                // Retrye first page request.
                requestItems(isFirst: true)
            }
        } pagingDisabledView: {
            PagingDisabledStateView()
                .listRowSeparator(.hidden)
        } pagingLoadingView: {
            PagingLoadingStateView()
                .listRowSeparator(.hidden)
        } pagingErrorView: { error in
            PagingErrorStateView(error: error) {
                // Show next page loading on next page retry action.
                pagingState = .pagingLoading
                // Retry next page request.
                requestItems(isFirst: false)
            }
                .listRowSeparator(.hidden)
        } onPageRequest: { isFirst in
            requestItems(isFirst: isFirst)
        } onRefreshRequest: {
            await refreshItems()
        }
        .listStyle(.plain)
        .onAppear {
            pagingState = .fullscreenLoading
            requestItems(isFirst: true)
        }
    }
    // swiftlint:enable vertical_parameter_alignment_on_call
    
    // Sync method for first loading and pagination loading content.
    private func requestItems(isFirst: Bool) {
        Task {
            await requestItems(isFirst: isFirst)
        }
    }
    
    // Async method for loading and refreshing content.
    private func refreshItems() async {
        await requestItems(isFirst: true)
    }
    
    // Async method for loading content.
    private func requestItems(isFirst: Bool) async {
        if isFirst, items.isEmpty == false {
            // Refresh content.
            pagingState = .refresh
            loadedPagesCount = 0
        } else if isFirst {
            // Reset loaded pages counter when loading the first page.
            pagingState = .fullscreenLoading
            loadedPagesCount = 0
        } else {
            // Loading pagination pages.
            pagingState = .pagingLoading
        }
        
        do {
            let newItems = try await repository.getItems(
                limit: Constants.requestLimit,
                offset: loadedPagesCount * Constants.requestLimit
            )
            
            if isFirst {
                // Rewrite all items after the first page is loaded.
                items = newItems
            } else {
                // Add new items after the every next page is loaded.
                items += newItems
            }
            // Increment loaded pages counter after the page is loaded.
            loadedPagesCount += 1
            
            // Set the list paging state to display the items or disable pagination if there are no items remaining.
            pagingState = newItems.count < Constants.requestLimit ? .disabled : .items
        } catch let error {
            if isFirst {
                // Сlearing items for correct operation of the state loader when call pull to refresh.
                if pagingState == .refresh {
                    items = []
                }
                
                // Display a full screen error in case of the first page loading error.
                pagingState = .fullscreenError(error)
            } else {
                // Display a paging error in case of the next page loading error.
                pagingState = .pagingError(error)
            }
        }
    }
}

private struct FullscreenLoadingStateView: View {
    var body: some View {
        ZStack {
            Color.pink
            Text("Loading")
        }
        .ignoresSafeArea(edges: .all)
    }
}

private struct FullscreenErrorStateView: View {
    var error: Swift.Error
    var onRetryAction: () -> Void
    
    var body: some View {
        ZStack {
            Color.red
            VStack {
                Text(error.localizedDescription)
                Button(action: onRetryAction) {
                    Text("Retry")
                }
            }
        }
        .ignoresSafeArea(edges: .all)
    }
}

private struct FullscreenEmptyStateView: View {
    var body: some View {
        ZStack {
            Color.green
            Text("Empty here")
        }
    }
}

private struct PagingLoadingStateView: View {
    var body: some View {
        ZStack {
            Color.gray
            Text("Loading next page")
        }
        .frame(height: 50)
    }
}

private struct PagingDisabledStateView: View {
    var body: some View {
        Color.clear
            .frame(height: 50)
    }
}

private struct PagingErrorStateView: View {
    var error: Swift.Error
    var onRetryAction: () -> Void
    
    var body: some View {
        ZStack {
            Color.red
            VStack {
                Text(error.localizedDescription)
                Button(action: onRetryAction) {
                    Text("Retry")
                }
            }
        }
        .frame(height: 50)
    }
}

struct ContentView_Previews: PreviewProvider {
    static var previews: some View {
        ContentView()
    }
}
