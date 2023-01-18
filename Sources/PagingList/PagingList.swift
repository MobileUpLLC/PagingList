//
//  SwiftUIView.swift
//  
//
//  Created by Nikolai Timonin on 17.01.2023.
//

import SwiftUI
import AdvancedList

public struct PageRequestDescriptor {
    public enum PageType {
        case first // Начальная полноэкранная загрузка или пулл-ту-руфреш
        case anyNext // Любой слудующий пейдж
        
        public var isInitial: Bool { self == .first }
    }
    
    /// Тип запрашиваемого пейджа.
    public let type: PageType
    
    /// Должен быть вызван ПОСЛЕ обновления коллекции Items.
    /// При загрузке первого пейджа или рефреша нужно заменить коллекцию целиком: items = newItems
    /// При загрузке следующего пейджа нужно добавить айтемы: items.apped(contentsOf: newItems)
    ///
    /// В случае успеха .success(())
    /// В случае ошибки .failure(error). Ошибка будет проброшена во вьюшку, которая отвечает за состояние ошибки.
    public let completion: (Result<Void, Swift.Error>) -> Void
}

public struct PagingList<Items: RandomAccessCollection, Content: View>: View where Items.Element: Identifiable {
    public typealias PageRequestClosure = (PageRequestDescriptor) -> Void
    
    @State private var listState: ListState = .items
    @State private var paginationState: AdvancedListPaginationState = .idle
    
    private let items: Items
    private let rowContentBuilder: (Items.Element) -> Content
    private let onPageRequest: PageRequestClosure
    
    public var body: some View {
        AdvancedList(
            items,
            content: rowContentBuilder,
            listState: listState,
            emptyStateView: {
                // Полноэкранное пустое состояние
                // Показывается когда listState = .item и data = [].
                FullscreenEmptyStateView()
            },
            errorStateView: { error in
                // Полноэкранное состояние ошибки
                // Показывается когда listState = .error
                // При нажатии на ретрай показывается FullscreenLoadingStateView
                FullscreenErrorStateView(error: error, onRetryAction: requestFirstPage)
            },
            loadingStateView: {
                // Полноэкранное состояние загрузки
                // Показывается когда lisetState = .loading
                FullscreenLoadingStateView()
            }
        )
        .pagination(
            .init(type: .lastItem, shouldLoadNextPage: requestNextPage) {
                switch paginationState {
                case .error(let error):
                    // Показывается когда при загрузке пейджа пришла ошибка
                    // При нажатии на ретрай показывается PagingLoadingState
                    PagingErrorStateView(error: error, onRetryAction: requestNextPage)
                case .idle:
                    // Показывается когда
                    // не выполняется загрузка пейджа и не состояние ошибки пейджа
                    PagingIdleStateView()
                case .loading:
                    // Показывается когда выполеняется загрузка пейджа
                    PagingLoadingStateView()
                }
            }
        )
        .refreshable(action: requestOnRefresh)
        .onAppear {
            requestFirstPage()
        }
    }
    
    public init(
        items: Items,
        @ViewBuilder rowContent: @escaping (Items.Element) -> Content,
//        @ViewBuilder fullscreenEmptyState: @escaping () -> Content,
//        @ViewBuilder fullscreenLoadingState: @escaping () -> Content,
//        @ViewBuilder fullscreenErrorState: @escaping (Error, ) -> Content,
        onPageRequest: @escaping PageRequestClosure
    ) {
        self.items = items
        self.rowContentBuilder = rowContent
        self.onPageRequest = onPageRequest
    }
    
    private func requestFirstPage() {
        listState = .loading
        
        let descriptor = PageRequestDescriptor(type: .first) { result in
            switch result {
            case .success:
                listState = .items
            case .failure(let error):
                listState = .error(error as NSError)
            }
        }
        onPageRequest(descriptor)
    }
    
    private func requestNextPage() {
        if paginationState == .loading {
            return
        }
        
        paginationState = .loading
        
        let descriptor = PageRequestDescriptor(type: .anyNext) { result in
            switch result {
            case .success:
                paginationState = .idle
            case .failure(let error):
                paginationState = .error(error as NSError)
            }
        }
        onPageRequest(descriptor)
    }
    
    @Sendable private func requestOnRefresh() async {
        return await withCheckedContinuation { (continuation: CheckedContinuation<Void, Never>) in
            listState = .items
            paginationState = .idle
            
            let descriptor = PageRequestDescriptor(type: .first) { result in
                switch result {
                case .success:
                    listState = .items
                case .failure(let error):
                    listState = .error(error as NSError)
                }
                continuation.resume(returning: ())
            }
            onPageRequest(descriptor)
        }
    }
}

private struct FullscreenLoadingStateView: View {
    var body: some View {
        // TODO: Заменить своей реализацией
        ZStack {
            Color.pink
            Text("Loading")
        }
    }
}

private struct FullscreenErrorStateView: View {
    var error: Swift.Error
    var onRetryAction: () -> Void
    
    var body: some View {
        // TODO: Заменить своей реализацией
        ZStack {
            Color.red
            VStack {
                Text(error.localizedDescription)
                Button(action: onRetryAction) {
                    Text("Retry")
                }
            }
        }
    }
}

private struct FullscreenEmptyStateView: View {
    var body: some View {
        // TODO: Заменить своей реализацией
        ZStack {
            Color.green
            Text("Empty here")
        }
    }
}

private struct PagingLoadingStateView: View {
    var body: some View {
        // TODO: Заменить своей реализацией
        ZStack {
            Color.gray
            Text("Loading next page")
        }
        .frame(height: 50)
    }
}

private struct PagingIdleStateView: View {
    var body: some View {
        // TODO: Заменить своей реализацией
        EmptyView()
    }
}

private struct PagingErrorStateView: View {
    var error: Swift.Error
    var onRetryAction: () -> Void
    
    var body: some View {
        // TODO: Заменить своей реализацией
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
