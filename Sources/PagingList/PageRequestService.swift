import Foundation

/// Errors that can occur during paginated requests.
public enum PagingError: Error {
    /// A request is already in progress.
    case requestInProgress
    
    /// The response data is invalid or cannot be cast to the expected type.
    case invalidResponse
}

/// A protocol defining the structure of a paginated response, including items and optional pagination metadata.
public protocol PaginatedResponse: Codable, Sendable {
    /// The type of items contained in the response, conforming to Codable and Sendable.
    associatedtype T: Codable, Sendable
    
    /// The list of items for the current page.
    var items: [T] { get }
    
    // swiftlint:disable discouraged_optional_boolean
    /// Indicates whether more pages are available.
    var hasMore: Bool? { get }
    // swiftlint:enable discouraged_optional_boolean
    
    /// The total number of pages, if known.
    var totalPages: Int? { get }
    
    /// The current page number, if known.
    var currentPage: Int? { get }
}

/// A service for managing paginated data requests, including prefetching upcoming pages.
public final class PageRequestService<ResponseModel: PaginatedResponse, DataModel: Codable & Sendable>: Sendable {
    private let state: PageRequestState<ResponseModel, DataModel>
    private let fetchPage: @Sendable (_ page: Int, _ pageSize: Int) async throws -> ResponseModel

    /// Initializes the service with a starting page and a closure for fetching pages.
    /// - Parameters:
    ///   - startPage: The initial page number (default is 1).
    ///   - prefetchTreshold: The maximum number of pages to prefetch ahead (default is 1).
    ///   - fetchPage: A closure that fetches a page of data asynchronously, returning a `PaginatedResponse`.
    public init(
        startPage: Int = 1,
        prefetchTreshold: Int = 1,
        fetchPage: @escaping @Sendable (_ page: Int, _ pageSize: Int) async throws -> ResponseModel
    ) {
        self.state = PageRequestState(startPage: startPage, prefetchTreshold: prefetchTreshold)
        self.fetchPage = fetchPage
        
        // Subscribe to a notification to stop prefetching when the PagingList screen is dismissed.
        NotificationCenter.default.addObserver(
            forName: .stopPrefetching,
            object: nil,
            queue: .main
        ) { [weak self] _ in
            self?.stopPrefetching()
        }
    }
    
    deinit {
        NotificationCenter.default.removeObserver(self)
    }
    
    /// Requests a page of data, either from prefetched data or via a network request.
    /// - Parameters:
    ///   - pageSize: The number of items per page.
    ///   - isFirst: If `true`, requests the first page and resets existing data.
    public func request(pageSize: Int, isFirst: Bool) async throws {
        guard await state.startRequest(isFirst: isFirst) else {
            throw PagingError.requestInProgress
        }
        
        let currentPage = await state.currentPage
        let page = isFirst ? state.startPage : currentPage
        
        do {
            let modelItems: [DataModel]
            
            if
                isFirst == false,
                let prefetchedResponse = await state.getPrefetchedResponse(for: page),
                let items = prefetchedResponse.items as? [DataModel]
            {
                // Use prefetched data if available for the current page.
                modelItems = items
                await updateCanLoadMore(items: items, pageSize: pageSize, model: prefetchedResponse)
            } else {
                // Perform a request if no prefetched data is available.
                let model = try await fetchPage(page, pageSize)
                
                guard let items = model.items as? [DataModel] else {
                    throw PagingError.invalidResponse
                }
                
                modelItems = items
                await updateCanLoadMore(items: modelItems, pageSize: pageSize, model: model)
            }

            await state.setItems(modelItems, isFirst: isFirst)
            await state.setPagingState(.items)
            await state.incrementPage()
            
            await state.endRequest()
            await prefetchIfNeeded(pageSize: pageSize)
        } catch {
            await state.endRequest()
            await state.setPagingState(isFirst ? .fullscreenError(error) : .pagingError(error))
            throw error
        }
    }

    /// Stops ongoing prefetching operations.
    public func stopPrefetching() {
        Task {
            await state.cancelPrefetchTask()
            await state.endRequest()
            await state.setPrefetchPending(false)
        }
    }
    
    /// Retrieves whether more pages can be loaded, related to current page on the screen.
    /// - Returns: `true` if more pages are available, `false` otherwise.
    public func getCanLoadMore() async -> Bool {
        await state.canLoadMore
    }
    
    /// Retrieves the current list of loaded items, excluding prefetched.
    /// - Returns: An array of `DataModel` items.
    public func getItems() async -> [DataModel] {
        await state.items
    }
    
    /// Retrieves the current UI state of the paginated list.
    /// - Returns: The current `PagingListState`.
    public func getPagingState() async -> PagingListState {
        await state.pagingState
    }
    
    /// Sets the UI state of the paginated list.
    /// - Parameter pagingState: The new `PagingListState` to apply.
    public func setPagingState(pagingState: PagingListState) async {
        await state.setPagingState(pagingState)
    }
    
    private func prefetchIfNeeded(pageSize: Int) async {
        guard await state.isRequestInProcess else {
            return
        }
        
        let canLoadMorePrefetch = await state.canLoadMorePrefetch
        let canPrefetchMore = await state.canPrefetchMore
        
        if canPrefetchMore && canLoadMorePrefetch {
            await state.setPrefetchPending(true)
            await prefetchNextPages(pageSize: pageSize)
        }
    }

    private func prefetchNextPages(pageSize: Int) async {
        await state.cancelPrefetchTask()
        
        let task = Task { [weak self] in
            guard let self else {
                return
            }
            
            guard await state.canPrefetchMore else {
                await state.setPrefetchPending(false)
                return
            }
            
            guard await state.isPrefetchPending else {
                return
            }
            
            let nextPage: Int
            
            if let maxPrefetchedPage = await state.maxPrefetchedPage {
                nextPage = max(maxPrefetchedPage + 1, await state.currentPage)
            } else {
                nextPage = await state.currentPage
            }
            
            if let response = try? await fetchPage(nextPage, pageSize) {
                if let items = response.items as? [DataModel] {
                    await updateCanLoadMorePrefetch(items: items, pageSize: pageSize, model: response)
                }
                
                await state.setPrefetchedItems(response, forPage: nextPage)
                await state.incrementPrefetchedPages()
                await state.setMaxPrefetchedPage(nextPage)
            }
            
            await state.setPrefetchPending(false)
            await prefetchIfNeeded(pageSize: pageSize)
        }
        
        await state.setPrefetchTask(task)
    }

    private func updateCanLoadMore(items: [DataModel], pageSize: Int, model: ResponseModel? = nil) async {
        let canLoadMore = getCanLoadMore(items: items, pageSize: pageSize, model: model)
        
        await state.setCanLoadMore(canLoadMore)
        await state.setCanLoadMorePrefetch(canLoadMore)
    }
    
    private func updateCanLoadMorePrefetch(items: [DataModel], pageSize: Int, model: ResponseModel? = nil) async {
        let canLoadMore = getCanLoadMore(items: items, pageSize: pageSize, model: model)
        
        await state.setCanLoadMorePrefetch(canLoadMore)
    }
    
    private func getCanLoadMore(items: [DataModel], pageSize: Int, model: ResponseModel? = nil) -> Bool {
        let canLoadMore: Bool
        
        if let hasMore = model?.hasMore {
            canLoadMore = hasMore
        } else if let totalPages = model?.totalPages, let currentPage = model?.currentPage {
            canLoadMore = currentPage < totalPages
        } else {
            canLoadMore = items.count == pageSize
        }
        
        return canLoadMore
    }
}
