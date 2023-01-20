//
//  File.swift
//  
//
//  Created by Nikolai Timonin on 20.01.2023.
//

import Foundation

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
