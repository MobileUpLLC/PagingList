actor PageRequestState<ResponseModel: PaginatedResponse, DataModel: Codable & Sendable> {
    let startPage: Int
    var maxPrefetchedPage: Int?
    var canPrefetchMore: Bool { return prefetchedPages < prefetchTreshold }
    
    private(set) var currentPage: Int
    private(set) var canLoadMore: Bool = true
    private(set) var canLoadMorePrefetch: Bool = true
    private(set) var items: [DataModel] = []
    private(set) var pagingState: PagingListState = .fullscreenLoading
    private(set) var isRequestInProcess: Bool = false
    private(set) var isPrefetchPending: Bool = false
    
    private var prefetchedPages: Int = 0
    private var prefetchedResponse: [Int: ResponseModel] = [:]
    private var prefetchTask: Task<Void, Never>?
    private let prefetchTreshold: Int
    
    init(startPage: Int, prefetchTreshold: Int) {
        self.startPage = startPage
        self.currentPage = startPage
        self.prefetchTreshold = prefetchTreshold
    }
    
    func startRequest() -> Bool {
        guard isRequestInProcess == false else {
            return false
        }
        
        isRequestInProcess = true
        
        return isRequestInProcess
    }
    
    func endRequest() {
        isRequestInProcess = false
    }
    
    func incrementPrefetchedPages() {
        prefetchedPages += 1
    }
    
    func resetPrefetchedPages() {
        prefetchedPages = 0
        prefetchedResponse = [:]
        isPrefetchPending = false
    }
    
    func incrementPage() {
        currentPage += 1
    }
    
    func setCanLoadMore(_ value: Bool) {
        canLoadMore = value
    }
    
    func setCanLoadMorePrefetch(_ value: Bool) {
        canLoadMorePrefetch = value
    }
    
    func setItems(_ newItems: [DataModel], isFirst: Bool) {
        if isFirst {
            items.removeAll()
        }
        
        items.append(contentsOf: newItems)
    }
    
    func setPagingState(_ state: PagingListState) {
        pagingState = state
    }
    
    func setMaxPrefetchedPage(_ value: Int) {
        maxPrefetchedPage = value
    }
    
    func setPrefetchTask(_ task: Task<Void, Never>?) {
        prefetchTask = task
    }
    
    func cancelPrefetchTask() {
        prefetchTask?.cancel()
        prefetchTask = nil
    }

    func getPrefetchedResponse(for page: Int) -> ResponseModel? {
        let result = prefetchedResponse[page]
        prefetchedResponse.removeValue(forKey: page)
        prefetchedPages -= 1
        
        return result
    }

    func setPrefetchedItems(_ items: ResponseModel?, forPage page: Int) {
        prefetchedResponse[page] = items
    }

    func setPrefetchPending(_ value: Bool) {
        isPrefetchPending = value
    }
}
