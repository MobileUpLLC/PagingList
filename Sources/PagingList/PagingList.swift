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

public struct PagingList<
        Items: RandomAccessCollection,
        RowContent: View,
        FullscreenEmptyView: View,
        FullscreenLoadingView: View,
        FullscreenErrorView: View,
        PagingLoadingView: View,
        PagingErrorView: View
    >: View where Items.Element: Identifiable {
    public typealias PageRequestClosure = (PageRequestDescriptor) -> Void
    
    public enum PagingListState {
        case items
        case loading
        case error(Error)
        
        case pagingLoading
        case pagingError(Error)
        case pagingEmpty
    }
    
    @State private var listState: ListState = .items
    @State private var paginationState: AdvancedListPaginationState = .idle
    
    private let items: Items
    private let rowContentBuilder: (Items.Element) -> RowContent
    
    private let fullscreenEmptyViewBuilder: () -> FullscreenEmptyView
    private let fullscreenErrorViewBuilder: (Error) -> FullscreenErrorView
    private let fullscreenLoadingViewBuilder: () -> FullscreenLoadingView
    
    private let pagingLoadingViewBuilder: () -> PagingLoadingView
    private let pagingErrorViewBuilder: (Error) -> PagingErrorView
    
    private let onPageRequest: PageRequestClosure
    
    public var body: some View {
        AdvancedList(
            items,
            content: rowContentBuilder,
            listState: listState,
            emptyStateView: {
                // Полноэкранное пустое состояние
                // Показывается когда listState = .item и data = [].
                fullscreenEmptyViewBuilder()
            },
            errorStateView: { error in
                // Полноэкранное состояние ошибки
                // Показывается когда listState = .error
                // При нажатии на ретрай показывается FullscreenLoadingStateView
                fullscreenErrorViewBuilder(error)
            },
            loadingStateView: {
                // Полноэкранное состояние загрузки
                // Показывается когда lisetState = .loading
                fullscreenLoadingViewBuilder()
            }
        )
        .pagination(
            .init(type: .lastItem, shouldLoadNextPage: requestNextPage) {
                switch paginationState {
                case .error(let error):
                    // Показывается когда при загрузке пейджа пришла ошибка
                    // При нажатии на ретрай показывается PagingLoadingState
                    pagingErrorViewBuilder(error)
                case .idle:
                    // Показывается когда
                    // не выполняется загрузка пейджа и не состояние ошибки пейджа
                    EmptyView()
                case .loading:
                    // Показывается когда выполеняется загрузка пейджа
                    pagingLoadingViewBuilder()
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
        @ViewBuilder rowContent: @escaping (Items.Element) -> RowContent,
        @ViewBuilder fullscreenEmptyView: @escaping () -> FullscreenEmptyView,
        @ViewBuilder fullscreenLoadingView: @escaping () -> FullscreenLoadingView,
        @ViewBuilder fullscreenErrorView: @escaping (Error) -> FullscreenErrorView,
        @ViewBuilder pagingLoadingView: @escaping () -> PagingLoadingView,
        @ViewBuilder pagingErrorView: @escaping (Error) -> PagingErrorView,
        onPageRequest: @escaping PageRequestClosure
    ) {
        self.items = items
        self.rowContentBuilder = rowContent
        self.fullscreenEmptyViewBuilder = fullscreenEmptyView
        self.fullscreenLoadingViewBuilder = fullscreenLoadingView
        self.fullscreenErrorViewBuilder = fullscreenErrorView
        self.pagingLoadingViewBuilder = pagingLoadingView
        self.pagingErrorViewBuilder = pagingErrorView
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
