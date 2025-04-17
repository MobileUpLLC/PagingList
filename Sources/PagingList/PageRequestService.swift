import Foundation

actor PageRequestState<ResponseModel: PaginatedResponse, DataModel: Codable & Sendable> {
    let startPage: Int
    let prefetchTreshold: Int
    var prefetchedPages: Int = 0
    var maxPrefetchedPage: Int?
    
    private(set) var currentPage: Int
    private(set) var canLoadMore: Bool = true
    private(set) var items: [DataModel] = []
    private(set) var pagingState: PagingListState = .fullscreenLoading
    private var prefetchedItems: [Int: ResponseModel] = [:]
    private var isPrefetchPending: Bool = false // Флаг для ожидания префетча

    private var isRequestInProcess: Bool = false
    private var prefetchTask: Task<Void, Never>?
    
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
        prefetchedItems = [:]
        isPrefetchPending = false
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
        return prefetchedPages < prefetchTreshold
    }
    
    func getPrefetchPages() -> Int {
        return prefetchedPages
    }
    
    func getMaxPrefetchedPage() -> Int? {
        return maxPrefetchedPage
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

    func hasPrefetchedItems(forPage page: Int) -> Bool {
        return prefetchedItems.isEmpty == false && prefetchedItems.keys.contains(page)
    }

    func getPrefetchedItems(for page: Int) -> ResponseModel? {
        let result = prefetchedItems[page]
        prefetchedItems.removeValue(forKey: page)
        prefetchedPages -= 1
        
        return result
    }

    func setPrefetchedItems(_ items: ResponseModel, forPage page: Int) {
        prefetchedItems[page] = items
    }

    func setPrefetchPending(_ value: Bool) {
        isPrefetchPending = value
    }

    func getIsPrefetchPending() -> Bool {
        return isPrefetchPending
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
    private let state: PageRequestState<ResponseModel, DataModel>
    private let fetchPage: @Sendable (Int, Int) async throws -> ResponseModel

    public init(
        startPage: Int = 1,
        fetchPage: @escaping @Sendable (Int, Int) async throws -> ResponseModel
    ) {
        self.state = PageRequestState(startPage: startPage, prefetchTreshold: 2)
        self.fetchPage = fetchPage
    }

    public func request(pageSize: Int, isFirst: Bool) async throws {
        guard await state.startRequest() else { throw PagingError.requestInProgress }
        defer { Task { await state.endRequest() } }

        // Разделяем доступ к startPage (синхронный) и currentPage (асинхронный)
        let page: Int
        if isFirst {
            page = state.startPage
        } else {
            page = await state.currentPage
        }
        
        do {
            let modelItems: [DataModel]
            let hasPrefetchedItems = await state.hasPrefetchedItems(forPage: page)
            if isFirst == false && hasPrefetchedItems {
                // Используем префетч-данные, если они есть для текущей страницы
                if let model = await state.getPrefetchedItems(for: page) {
                    if let items = model.items as? [DataModel] {
                        modelItems = items
                        await updateCanLoadMore(items: items, pageSize: pageSize, model: model)
                    } else {
                        modelItems = []
                    }
                } else {
                    modelItems = []
                }
            } else {
                // Выполняем запрос, если префетч-данных нет
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
            
            // Проверяем, нужен ли префетч
            await prefetchIfNeeded(pageSize: pageSize)
        } catch {
            await state.setPagingState(isFirst ? .fullscreenError(error) : .pagingError(error))
            throw error
        }
    }

    public func reload(pageSize: Int) async throws {
        await state.resetPrefetchedPages()
        try await request(pageSize: pageSize, isFirst: true)
    }
    
    private func prefetchIfNeeded(pageSize: Int) async {
        let canLoadMore = await state.canLoadMore
        let canPrefetchMore = await state.getCanPrefetchMore()
        if canPrefetchMore && canLoadMore {
            await state.setPrefetchPending(true)
            Task {
                await prefetchNextPages(pageSize: pageSize)
            }
        }
    }

    private func prefetchNextPages(pageSize: Int) async {
        await state.cancelPrefetchTask()
        let task = Task { [weak self] in
            guard let self else { return }
            guard await state.getCanPrefetchMore() else {
                await state.setPrefetchPending(false)
                return
            }
            guard await state.getIsPrefetchPending() else { return }
            
            do {
                let nextPage: Int
                if let maxPrefetchedPage = await state.getMaxPrefetchedPage() {
                    nextPage = max(maxPrefetchedPage, await state.currentPage) + 1
                } else {
                    nextPage = await state.currentPage
                }
                let response = try await performPrefetch(pageSize: pageSize, forPage: nextPage)
                await state.setPrefetchedItems(response, forPage: nextPage)
                await state.incrementPrefetchedPages()
                print("Префетч")
                await state.setMaxPrefetchedPage(nextPage)
                await state.setPrefetchPending(false)
                await prefetchIfNeeded(pageSize: pageSize)
            } catch {
                print("Ошибка предварительной загрузки: \(error)")
                await state.setPrefetchPending(false)
            }
        }
        await state.setPrefetchTask(task)
    }

    private func performPrefetch(pageSize: Int, forPage page: Int) async throws -> ResponseModel {
        guard await state.startRequest() else { throw PagingError.requestInProgress }
        defer { Task { await state.endRequest() } }

        return try await fetchPage(page, pageSize)
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
        Task { await state.setPrefetchPending(false) }
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
