import Foundation

public enum PagingListState {
    // Отображаются ячейки. Загрузки не происходит.
    case items
    // Полноэкранная первичная загрузка.
    case fullscreenLoading
    // Полнокранная ошибка.
    case fullscreenError(Error)
    // Загрузка следующего пейджа. Показывается вьюшка загрузки внизу.
    case pagingLoading
    // Ошибка загрузки следующего пейджа. Показывается вьюшка ошибки внизу.
    case pagingError(Error)
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
        default:
            return false
        }
    }
}
