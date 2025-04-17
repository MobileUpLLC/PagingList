import Foundation

actor PageRequestState<DataModel: Codable & Sendable> {
    let startPage: Int
    let maxPrefetchPages: Int
    var prefetchedPages: Int = 0
    
    private(set) var currentPage: Int
    private(set) var canLoadMore: Bool = true
    private(set) var items: [DataModel] = []
    private(set) var pagingState: PagingListState = .fullscreenLoading
    
    private var isRequestInProcess: Bool = false
    private var prefetchTask: Task<Void, Never>?
    
    init(startPage: Int, maxPrefetchPages: Int) {
        self.startPage = startPage
        self.currentPage = startPage
        self.maxPrefetchPages = maxPrefetchPages
    }
    
    func startRequest() -> Bool {
        guard !isRequestInProcess else { return false }
        isRequestInProcess = true
        return true
    }
    
    func endRequest() {
        isRequestInProcess = false
    }
    
    func incrementPrefetchedPages() {
        prefetchedPages += 1
    }
    
    func resetPrefetchedPages() {
        prefetchedPages = 0
    }
    
    func incrementPage() {
        currentPage += 1
    }
    
    func setCanLoadMore(_ value: Bool) {
        canLoadMore = value
    }
    
    func setItems(_ newItems: [DataModel], isFirst: Bool) {
        if isFirst {
            items = newItems
        } else {
            items.append(contentsOf: newItems)
        }
    }
    
    func setPagingState(_ state: PagingListState) {
        pagingState = state
    }
    
    func getCanPrefetchMore() -> Bool {
        return prefetchedPages < maxPrefetchPages
    }
    
    func setPrefetchTask(_ task: Task<Void, Never>?) {
        prefetchTask = task
    }
    
    func cancelPrefetchTask() {
        prefetchTask?.cancel()
        prefetchTask = nil
    }
}

public protocol PaginatedResponse: Codable, Sendable {
    associatedtype T: Codable, Sendable
    var items: [T] { get }
    var hasMore: Bool? { get }
    var totalPages: Int? { get }
    var currentPage: Int? { get }
}

public final class PageRequestService<ResponseModel: PaginatedResponse, DataModel: Codable & Sendable>: Sendable {
    private let state: PageRequestState<DataModel>
    private let fetchPage: @Sendable (Int, Int) async throws -> ResponseModel

    public init(
        startPage: Int = 1,
        fetchPage: @escaping @Sendable (Int, Int) async throws -> ResponseModel
    ) {
        self.state = PageRequestState(startPage: startPage, maxPrefetchPages: 2)
        self.fetchPage = fetchPage
    }

    public func request(pageSize: Int, isFirst: Bool) async throws {
        guard await state.startRequest() else { throw PagingError.requestInProgress }
        defer { Task { await state.endRequest() } }

        let page = isFirst ? state.startPage : await state.currentPage
        do {
            let model = try await fetchPage(page, pageSize)
            guard let modelItems = model.items as? [DataModel] else {
                throw PagingError.invalidResponse
            }

            await state.incrementPage()
            await state.setItems(modelItems, isFirst: isFirst)
            await state.setPagingState(.items)
            await updateCanLoadMore(items: modelItems, pageSize: pageSize, model: model)
            
            let canPrefetchMore = await state.getCanPrefetchMore()
            if !isFirst && canPrefetchMore {
                await prefetchNextPages(pageSize: pageSize)
            }
        } catch {
            await state.setPagingState(isFirst ? .fullscreenError(error) : .pagingError(error))
            throw error
        }
    }

    public func reload(pageSize: Int) async throws {
        await state.resetPrefetchedPages()
        try await request(pageSize: pageSize, isFirst: true)
    }

    private func prefetchNextPages(pageSize: Int) async {
        await state.cancelPrefetchTask()
        let task = Task { [weak self] in
            guard let self else { return }
            guard await state.getCanPrefetchMore() else { return }
            do {
                let newItems = try await performPrefetch(pageSize: pageSize)
                await state.setItems(newItems, isFirst: false)
                await state.incrementPrefetchedPages()
                await updateCanLoadMore(items: newItems, pageSize: pageSize)
            } catch {
                print("Ошибка предварительной загрузки: \(error)")
            }
        }
        await state.setPrefetchTask(task)
    }

    private func performPrefetch(pageSize: Int) async throws -> [DataModel] {
        guard await state.startRequest() else { throw PagingError.requestInProgress }
        defer { Task { await state.endRequest() } }

        let model = try await fetchPage(await state.currentPage, pageSize)
        guard let modelItems = model.items as? [DataModel] else {
            throw PagingError.invalidResponse
        }
        await state.incrementPage()
        return modelItems
    }

    private func updateCanLoadMore(items: [DataModel], pageSize: Int, model: ResponseModel? = nil) async {
        let canLoadMore: Bool
        if let hasMore = model?.hasMore {
            canLoadMore = hasMore
        } else if let totalPages = model?.totalPages, let currentPage = model?.currentPage {
            canLoadMore = currentPage < totalPages
        } else {
            canLoadMore = items.count == pageSize
        }
        await state.setCanLoadMore(canLoadMore)
    }

    public func stopPrefetching() {
        Task { await state.cancelPrefetchTask() }
        Task { await state.endRequest() }
    }
    
    public func getCanLoadMore() async -> Bool {
        await state.canLoadMore
    }
    
    public func getItems() async -> [DataModel] {
        await state.items
    }
    
    public func getPagingState() async -> PagingListState {
        await state.pagingState
    }
}

enum PagingError: Error {
    case requestInProgress
    case invalidResponse
}
