import Foundation

public enum PagingListState: Sendable {
    /// Paging disabled.
    case disabled
    
    /// Cells are visible. No loading next items here.
    case items
    
    /// Fullscreen initial data loading(first page).
    case fullscreenLoading
    
    /// Fullscreen error on loading first page.
    case fullscreenError(Error)
    
    /// Loading next page(> 1). Next page loading cell is visible here at the bottom fo the list.
    case pagingLoading
    
    /// Error on next page loading. Next page error cell is visible here at the bottom of the list.
    case pagingError(Error)
    
    /// Updating content with pull to refresh
    case refresh
}

extension PagingListState: Equatable {
    public static func == (lhs: PagingListState, rhs: PagingListState) -> Bool {
        switch (lhs, rhs) {
        case (.disabled, .disabled):
            return true
        case (.items, .items):
            return true
        case (.fullscreenLoading, .fullscreenLoading):
            return true
        case (.pagingLoading, .pagingLoading):
            return true
        case (.pagingError, .pagingError):
            return true
        case (.refresh, .refresh):
            return true
        default:
            return false
        }
    }
}
