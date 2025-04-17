import SwiftUI

public struct PagingList<
    Items: RandomAccessCollection,
    RowContent: View,
    FullscreenEmptyView: View,
    FullscreenLoadingView: View,
    FullscreenErrorView: View,
    PagingDisabledView: View,
    PagingLoadingView: View,
    PagingErrorView: View
>: View where Items.Element: Identifiable {
    public typealias PageRequestClosure = (Bool) -> Void
    public typealias RefreshClosure = () async -> Void
    
    @Binding private var state: PagingListState
    
    private let items: Items
    private let rowContentBuilder: (Items.Element) -> RowContent
    
    private let fullscreenEmptyViewBuilder: () -> FullscreenEmptyView
    private let fullscreenErrorViewBuilder: (Error) -> FullscreenErrorView
    private let fullscreenLoadingViewBuilder: () -> FullscreenLoadingView
    
    private let pagingDisabledViewBuilder: () -> PagingDisabledView
    private let pagingLoadingViewBuilder: () -> PagingLoadingView
    private let pagingErrorViewBuilder: (Error) -> PagingErrorView
    
    private let onPageRequest: PageRequestClosure
    private let onRefreshRequest: RefreshClosure
    
    public var body: some View {
        List {
            ForEach(items) { item in
                rowContentBuilder(item)
            }
            switch state {
            case .fullscreenLoading, .fullscreenError:
                EmptyView()
            case .disabled:
                pagingDisabledViewBuilder()
            case .items, .pagingLoading, .refresh:
                pagingLoadingViewBuilder()
                    .onAppear {
                        requestNextPage()
                    }
            case .pagingError(let error):
                pagingErrorViewBuilder(error)
            }
        }
        .overlay {
            switch state {
            case .disabled, .items:
                if items.isEmpty {
                    fullscreenEmptyViewBuilder()
                }
            case .fullscreenLoading:
                fullscreenLoadingViewBuilder()
            case .fullscreenError(let error):
                fullscreenErrorViewBuilder(error)
            default:
                EmptyView()
            }
        }
        .refreshable(action: requestOnRefresh)
        .onDisappear {
            // Останавливаем префетчинг при исчезновении списка
            NotificationCenter.default.post(name: .stopPrefetching, object: nil)
        }
    }
    
    public init(
        state: Binding<PagingListState>,
        items: Items,
        rowContent: @escaping (Items.Element) -> RowContent,
        @ViewBuilder fullscreenEmptyView: @escaping () -> FullscreenEmptyView,
        @ViewBuilder fullscreenLoadingView: @escaping () -> FullscreenLoadingView,
        @ViewBuilder fullscreenErrorView: @escaping (Error) -> FullscreenErrorView,
        @ViewBuilder pagingDisabledView: @escaping () -> PagingDisabledView,
        @ViewBuilder pagingLoadingView: @escaping () -> PagingLoadingView,
        @ViewBuilder pagingErrorView: @escaping (Error) -> PagingErrorView,
        onPageRequest: @escaping PageRequestClosure,
        onRefreshRequest: @escaping RefreshClosure
    ) {
        self._state = state
        self.items = items
        self.rowContentBuilder = rowContent
        self.fullscreenEmptyViewBuilder = fullscreenEmptyView
        self.fullscreenLoadingViewBuilder = fullscreenLoadingView
        self.fullscreenErrorViewBuilder = fullscreenErrorView
        self.pagingDisabledViewBuilder = pagingDisabledView
        self.pagingLoadingViewBuilder = pagingLoadingView
        self.pagingErrorViewBuilder = pagingErrorView
        self.onPageRequest = onPageRequest
        self.onRefreshRequest = onRefreshRequest
    }
    
    private func requestNextPage() {
        if state == .pagingLoading || state == .disabled {
            return
        }
        
        state = .pagingLoading
        onPageRequest(false)
    }
    
    @Sendable private func requestOnRefresh() async {
        await onRefreshRequest()
    }
}

// Уведомление для остановки префетчинга
extension Notification.Name {
    static let stopPrefetching = Notification.Name("StopPrefetching")
}
