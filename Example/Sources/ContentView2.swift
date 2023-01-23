//
//  ContentView.swift
//  Example
//
//  Created by Nikolai Timonin on 17.01.2023.
//

import SwiftUI
import PagingList

struct ContentView2: View {
    private enum Constants {
        static let requestLimit = 20
    }
    
    private let provider = IntsProvider()
    
    @State private var loadedPage = 0
    @State private var items = [Int]()
    @State private var pagingState: PagingListState = .items
    
    var body: some View {
        HPagingList(
            state: $pagingState,
            provider: provider
        ) { item in
            Text("\(item)")
        } fullscreenEmptyView: {
            FullscreenEmptyStateView()
        } fullscreenLoadingView: {
            FullscreenLoadingStateView()
        } fullscreenErrorView: { error in
            FullscreenErrorStateView(error: error) {
                // Заново запрашиваем первый пейдж
                // с показом полноэкранной загрузки
                pagingState = .fullscreenLoading
//                requestItems(isFirst: true)
            }
        } pagingLoadingView: {
            PagingLoadingStateView()
        } pagingErrorView: { error in
            PagingErrorStateView(error: error) {
                // Заново запрашиваем следующий пейдж
                // с показом пейджинговой загрузки
                pagingState = .pagingLoading
//                requestItems(isFirst: false)
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

private struct PagingIdleStateView: View {
    var body: some View {
        EmptyView()
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
