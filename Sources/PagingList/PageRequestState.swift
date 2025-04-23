/// A thread-safe actor that manages state of paginated requests, including current page, items, and prefetching logic.
actor PageRequestState<ResponseModel: PaginatedResponse, DataModel: Codable & Sendable> {
    let startPage: Int
    
    /// The maximum page number that has been prefetched, if any.
    var maxPrefetchedPage: Int?
    
    /// Indicates whether more pages can be prefetched based on the prefetch threshold.
    var canPrefetchMore: Bool { return prefetchedPages < prefetchTreshold }
    
    private(set) var currentPage: Int
    
    /// Indicates whether more pages can be loaded, related to current page on the screen for requests to continue.
    private(set) var canLoadMore: Bool = true
    
    /// Indicates whether more pages can be loaded, related to already prefetched pages.
    private(set) var canLoadMorePrefetch: Bool = true
    
    /// The list of items loaded so far.
    private(set) var items: [DataModel] = []
    
    /// The current UI state of the paginated list (e.g., loading, error, items).
    private(set) var pagingState: PagingListState = .fullscreenLoading
    
    /// Indicates whether a page request is currently in progress.
    private(set) var isRequestInProcess: Bool = false
    
    /// Indicates whether a prefetch operation is pending.
    private(set) var isPrefetchPending: Bool = false
    
    private var prefetchedPages: Int = 0
    private var prefetchedResponse: [Int: ResponseModel] = [:]
    private var prefetchTask: Task<Void, Never>?
    private let prefetchTreshold: Int
    
    /// Initializes the state with a starting page and prefetch threshold.
    /// - Parameters:
    ///   - startPage: The initial page number.
    ///   - prefetchTreshold: The maximum number of pages to prefetch ahead.
    init(startPage: Int, prefetchTreshold: Int) {
        self.startPage = startPage
        self.currentPage = startPage
        self.prefetchTreshold = prefetchTreshold
    }
    
    /// Starts a new page request, preventing concurrent requests.
    /// - Returns: `true` if the request was started, `false` if a request is already in progress.
    func startRequest(isFirst: Bool) -> Bool {
        guard isRequestInProcess == false else {
            return false
        }
        
        if isFirst {
            currentPage = startPage
            cancelPrefetchTask()
            resetPrefetchedPages()
        }
        
        isRequestInProcess = true
        
        return isRequestInProcess
    }
    
    /// Ends the current page request, allowing new requests to start.
    func endRequest() {
        isRequestInProcess = false
    }
    
    /// Increments the count of prefetched pages.
    func incrementPrefetchedPages() {
        prefetchedPages += 1
    }
    
    /// Resets the prefetching state, clearing prefetched pages and responses.
    func resetPrefetchedPages() {
        prefetchedPages = 0
        prefetchedResponse = [:]
        isPrefetchPending = false
    }
    
    /// Increments the current page number.
    func incrementPage() {
        currentPage += 1
    }
    
    /// Sets whether more pages can be loaded, related to current page on the screen for requests to continue., .
    /// - Parameter value: `true` if more pages are available, `false` otherwise.
    func setCanLoadMore(_ value: Bool) {
        canLoadMore = value
    }
    
    /// Sets whether more pages can be prefetched, related to already prefetched pages.
    /// - Parameter value: `true` if prefetching is allowed, `false` otherwise.
    func setCanLoadMorePrefetch(_ value: Bool) {
        canLoadMorePrefetch = value
    }
    
    /// Updates the list of items, either appending or replacing based on whether it's the first page.
    /// - Parameters:
    ///   - newItems: The new items to add.
    ///   - isFirst: If `true`, clears existing items before adding new ones.
    func setItems(_ newItems: [DataModel], isFirst: Bool) {
        if isFirst {
            items.removeAll()
        }
        
        items.append(contentsOf: newItems)
    }
    
    /// Sets the current UI state of the paginated list.
    /// - Parameter state: The new `PagingListState` to apply.
    func setPagingState(_ state: PagingListState) {
        pagingState = state
    }
    
    /// Sets the maximum prefetched page number.
    /// - Parameter value: The page number to set as the maximum prefetched.
    func setMaxPrefetchedPage(_ value: Int) {
        maxPrefetchedPage = value
    }
    
    /// Sets the task responsible for prefetching pages.
    /// - Parameter task: The `Task` to set, or `nil` to clear.
    func setPrefetchTask(_ task: Task<Void, Never>?) {
        prefetchTask = task
    }
    
    /// Cancels the current prefetch task, if any.
    func cancelPrefetchTask() {
        prefetchTask?.cancel()
        prefetchTask = nil
    }
    
    /// Retrieves and removes the prefetched response for a specific page.
    /// - Parameter page: The page number to retrieve.
    /// - Returns: The prefetched `ResponseModel` if available, or `nil`.
    func getPrefetchedResponse(for page: Int) -> ResponseModel? {
        let result = prefetchedResponse[page]
        
        prefetchedResponse.removeValue(forKey: page)
        prefetchedPages -= 1
        
        return result
    }
    
    /// Stores a prefetched response for a specific page.
    /// - Parameters:
    ///   - items: The `ResponseModel` to store, or `nil` to clear.
    ///   - page: The page number associated with the response.
    func setPrefetchedItems(_ items: ResponseModel?, forPage page: Int) {
        prefetchedResponse[page] = items
    }
    
    /// Sets whether a prefetch operation is pending.
    /// - Parameter value: `true` if prefetching is pending, `false` otherwise.
    func setPrefetchPending(_ value: Bool) {
        isPrefetchPending = value
    }
}
