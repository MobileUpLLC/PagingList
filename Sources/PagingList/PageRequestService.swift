import Foundation

actor PageRequestState<DataModel: Codable & Sendable> {
    let startPage: Int
    let maxPrefetchPages: Int
    var prefetchedPages: Int = 0
    
    private(set) var currentPage: Int
    private(set) var canLoadMore: Bool = true
    private(set) var items: [DataModel] = []
    private(set) var pagingState: PagingListState = .fullscreenLoading
    private var prefetchedItems: [DataModel] = []
    private var prefetchedPage: Int? // Номер страницы для префетч-данных
    private var isPrefetchPending: Bool = false // Флаг для ожидания префетча

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
        prefetchedItems = []
        prefetchedPage = nil
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
        return prefetchedPages < maxPrefetchPages
    }
    
    func setPrefetchTask(_ task: Task<Void, Never>?) {
        prefetchTask = task
    }
    
    func cancelPrefetchTask() {
        prefetchTask?.cancel()
        prefetchTask = nil
    }

    func hasPrefetchedItems(forPage page: Int) -> Bool {
        return !prefetchedItems.isEmpty && prefetchedPage == page
    }

    func getPrefetchedItems() -> [DataModel] {
        let result = prefetchedItems
        prefetchedItems = []
        prefetchedPage = nil
        return result
    }

    func setPrefetchedItems(_ items: [DataModel], forPage page: Int) {
        prefetchedItems = items
        prefetchedPage = page
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
                modelItems = await state.getPrefetchedItems()
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
            let canPrefetchMore = await state.getCanPrefetchMore()
            if !isFirst && canPrefetchMore {
                await state.setPrefetchPending(true)
                Task {
                    await prefetchNextPages(pageSize: pageSize)
                }
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
            guard await state.getCanPrefetchMore() else {
                await state.setPrefetchPending(false)
                return
            }
            guard await state.getIsPrefetchPending() else { return }
            
            do {
                let nextPage = await state.currentPage
                let response = try await performPrefetch(pageSize: pageSize, forPage: nextPage)
                let newItems = response.items as? [DataModel]
                await state.setPrefetchedItems(newItems ?? [], forPage: nextPage)
                await state.incrementPrefetchedPages()
                await updateCanLoadMore(items: newItems ?? [], pageSize: pageSize, model: response)
                await state.setPrefetchPending(false)
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
