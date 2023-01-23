//
//  File.swift
//
//
//  Created by Nikolai Timonin on 20.01.2023.
//

import Foundation
import SwiftUI

public protocol PageProvider: ObservableObject {
    associatedtype Items: RangeReplaceableCollection
    
    var allItems: Items { get set }
    
    func getFirstPage(completion: @escaping (Result<Void, Swift.Error>) -> Void)
    func getNextPage(completion: @escaping (Result<Void, Swift.Error>) -> Void)
}

public protocol LimitOffsetPageProvider: PageProvider {
    var limit: Int { get }
    var loadedPagesCount: Int { get set }
    
    func getItems(offset: Int, limit: Int, compeltion: @escaping (Result<Items, Swift.Error>) -> Void)
}

public extension LimitOffsetPageProvider {
    var limit: Int { 20 }
    var requestOffset: Int { loadedPagesCount * limit }
    
    func getFirstPage(completion: @escaping (Result<Void, Swift.Error>) -> Void) {
        loadedPagesCount = 0
        getItems(offset: requestOffset, limit: limit) { [weak self] result in
            switch result {
            case .success(let newItems):
                self?.allItems = newItems
                completion(.success(()))
            case .failure(let error):
                completion(.failure(error))
            }
        }
    }
    
    func getNextPage(completion: @escaping (Result<Void, Error>) -> Void) {
        getItems(offset: requestOffset, limit: limit) { [weak self] result in
            switch result {
            case .success(let newItems):
                self?.allItems += newItems
                self?.loadedPagesCount += 1
                completion(.success(()))
            case .failure(let error):
                completion(.failure(error))
            }
        }
    }
}

public struct HPagingList<
    Items: RandomAccessCollection,
    Provider: PageProvider,
    RowContent: View,
    FullscreenEmptyView: View,
    FullscreenLoadingView: View,
    FullscreenErrorView: View,
    PagingLoadingView: View,
    PagingErrorView: View
>: View where Items.Element: Identifiable, Provider.Items == Items {
    @State private var state: PagingListState = .items
    
    private let rowContentBuilder: (Items.Element) -> RowContent
    
    private let fullscreenEmptyViewBuilder: () -> FullscreenEmptyView
    private let fullscreenErrorViewBuilder: (Error) -> FullscreenErrorView
    private let fullscreenLoadingViewBuilder: () -> FullscreenLoadingView
    
    private let pagingLoadingViewBuilder: () -> PagingLoadingView
    private let pagingErrorViewBuilder: (Error) -> PagingErrorView
    
    @ObservedObject private var provider: Provider
    
    public var body: some View {
        PagingList(
            state: $state,
            items: provider.allItems,
            rowContent: rowContentBuilder,
            fullscreenEmptyView: fullscreenEmptyViewBuilder,
            fullscreenLoadingView: fullscreenLoadingViewBuilder,
            fullscreenErrorView: fullscreenErrorViewBuilder,
            pagingLoadingView: pagingLoadingViewBuilder,
            pagingErrorView: pagingErrorViewBuilder
        ) { isFirst in
            if isFirst {
                provider.getFirstPage { result in
                    switch result {
                    case .success:
                        state = .items
                    case .failure(let error):
                        state = .fullscreenError(error)
                    }
                }
            } else {
                provider.getNextPage { result in
                    switch result {
                    case .success:
                        state = .items
                    case .failure(let error):
                        state = .pagingError(error)
                    }
                }
            }
        }
    }
    
    public init(
        state: Binding<PagingListState>,
        provider: Provider,
        @ViewBuilder rowContent: @escaping (Items.Element) -> RowContent,
        @ViewBuilder fullscreenEmptyView: @escaping () -> FullscreenEmptyView,
        @ViewBuilder fullscreenLoadingView: @escaping () -> FullscreenLoadingView,
        @ViewBuilder fullscreenErrorView: @escaping (Error) -> FullscreenErrorView,
        @ViewBuilder pagingLoadingView: @escaping () -> PagingLoadingView,
        @ViewBuilder pagingErrorView: @escaping (Error) -> PagingErrorView
    ) {
        self.provider = provider
        self.rowContentBuilder = rowContent
        self.fullscreenEmptyViewBuilder = fullscreenEmptyView
        self.fullscreenLoadingViewBuilder = fullscreenLoadingView
        self.fullscreenErrorViewBuilder = fullscreenErrorView
        self.pagingLoadingViewBuilder = pagingLoadingView
        self.pagingErrorViewBuilder = pagingErrorView
    }
}
