import SwiftUI
import AdvancedList

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
    
    public var body: some View {
        switch state {
        case .disabled, .items, .pagingLoading, .pagingError:
            if items.isEmpty {
                fullscreenEmptyViewBuilder()
            } else {
                getList()
            }
        case .fullscreenLoading:
            fullscreenLoadingViewBuilder()
        case .fullscreenError(let error):
            fullscreenErrorViewBuilder(error)
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
        onPageRequest: @escaping PageRequestClosure
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
    }
    
    private func requestNextPage() {
        if state == .pagingLoading {
            return
        }
        
        if state == .disabled {
            return
        }
        
        state = .pagingLoading
        onPageRequest(false)
    }
    
    private func getList() -> some View {
        List {
            ForEach(items) { item in
                rowContentBuilder(item)
            }
            switch state {
            case .fullscreenLoading, .fullscreenError:
                EmptyView()
            case .disabled:
                pagingDisabledViewBuilder()
            case .items, .pagingLoading:
                pagingLoadingViewBuilder()
                    .onAppear {
                        requestNextPage()
                    }
            case .pagingError(let error):
                pagingErrorViewBuilder(error)
            }
        }
        .refreshable(action: requestOnRefresh)
    }
    
    @Sendable private func requestOnRefresh() async {
        return await withCheckedContinuation { (continuation: CheckedContinuation<Void, Never>) in
            DispatchQueue.main.async {
                onPageRequest(true)
                continuation.resume(returning: ())
            }
        }
    }
}
