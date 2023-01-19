//
//  SwiftUIView.swift
//  
//
//  Created by Nikolai Timonin on 17.01.2023.
//

import SwiftUI
import AdvancedList

public enum PagingListState {
    case items
    
    case fullscreenLoading
    case fullscreenError(Error)
    
    case pagingLoading
    case pagingError(Error)
    case pagingEmpty
}

extension PagingListState: Equatable {
    public static func == (lhs: PagingListState, rhs: PagingListState) -> Bool {
        switch (lhs, rhs) {
        case (.items, .items):
            return true
        case (.fullscreenLoading, .fullscreenLoading):
            return true
        case (.pagingLoading, .pagingLoading):
            return true
        case (.pagingError, .pagingError):
            return true
        case (.pagingEmpty, .pagingEmpty):
            return true
        default:
            return false
        }
    }
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
    public typealias PageRequestClosure = (Bool) -> Void
    
    private var listState: ListState {
        switch state {
        case .items, .pagingLoading, .pagingError, .pagingEmpty:
            return .items
        case .fullscreenLoading:
            return .loading
        case .fullscreenError(let error):
            return .error(error as NSError)
        }
    }
    
    @Binding private var state: PagingListState
    
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
                switch state {
                case .items, .fullscreenLoading, .fullscreenError, .pagingEmpty:
                    EmptyView()
                case .pagingLoading:
                    pagingLoadingViewBuilder()
                case .pagingError(let error):
                    pagingErrorViewBuilder(error)
                }
            }
        )
        .refreshable(action: requestOnRefresh)
        .onAppear {
            requestFirstPage()
        }
    }
    
    public init(
        state: Binding<PagingListState>,
        items: Items,
        @ViewBuilder rowContent: @escaping (Items.Element) -> RowContent,
        @ViewBuilder fullscreenEmptyView: @escaping () -> FullscreenEmptyView,
        @ViewBuilder fullscreenLoadingView: @escaping () -> FullscreenLoadingView,
        @ViewBuilder fullscreenErrorView: @escaping (Error) -> FullscreenErrorView,
        @ViewBuilder pagingLoadingView: @escaping () -> PagingLoadingView,
        @ViewBuilder pagingErrorView: @escaping (Error) -> PagingErrorView,
        onPageRequest: @escaping PageRequestClosure
    ) {
        self._state = state
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
        state = .fullscreenLoading
        onPageRequest(true)
    }
    
    private func requestNextPage() {
        if state == .pagingLoading {
            return
        }
        
        state = .pagingLoading
        onPageRequest(false)
    }
    
    @Sendable private func requestOnRefresh() async {
        return await withCheckedContinuation { (continuation: CheckedContinuation<Void, Never>) in
            state = .items
            onPageRequest(true)
            continuation.resume(returning: ())
        }
    }
}
