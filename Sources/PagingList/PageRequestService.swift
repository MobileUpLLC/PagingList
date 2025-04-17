import Foundation

actor PageRequestState<DataModel: Codable> {
    let startPage: Int
    let maxPrefetchPages: Int
    var prefetchedPages: Int = 0
    
    private(set) var currentPage: Int
    private(set) var canLoadMore: Bool = true

    
    private var isRequestInProcess: Bool = false
    
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
    
    func getCanPrefetchMore() -> Bool {
        return prefetchedPages < maxPrefetchPages
    }
}

// Модель используется для ответов от сервера, которые возвращают данные по страницам
public protocol PaginatedResponse: Codable {
    associatedtype T: Codable
    var items: [T] { get }
    var hasMore: Bool? { get } // Опционально для API с метаданными
    var totalPages: Int? { get }
    var currentPage: Int? { get }
}

// Модель используется в билдере запросов, наследующих PaginatedResponse
public struct PageRequestModel<T> {
    public let page: Int
    public let pageSize: Int
    public let completion: (Result<T, Error>) -> Void
}

// При использовании сервиса необходимо чтоб тип items в PaginatedResponse соответствовал
// типу DataModel
public final class PageRequestService<ResponseModel: PaginatedResponse, DataModel: Codable & Sendable>: ObservableObject {
    @Published public var pagingState: PagingListState = .fullscreenLoading
    @Published public var items: [DataModel] = []
    
    private let state: PageRequestState<DataModel>
    private var prefetchTask: Task<Void, Never>?
    private let maxPrefetchPages: Int = 2
    private let fetchPage: (Int, Int) async throws -> ResponseModel

    public init(
        startPage: Int = 1,
        fetchPage: @escaping (Int, Int) async throws -> ResponseModel
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
            
            await MainActor.run {
                if isFirst {
                    self.items = modelItems
                } else {
                    self.items.append(contentsOf: modelItems)
                }
                self.pagingState = .items
                self.objectWillChange.send()
            }

            await updateCanLoadMore(items: modelItems, pageSize: pageSize, model: model)
            
            let canPrefetchMore = await state.getCanPrefetchMore()
            
            if !isFirst && canPrefetchMore {
                await prefetchNextPages(pageSize: pageSize)
            }
        } catch {
            await MainActor.run {
                self.pagingState = isFirst ? .fullscreenError(error) : .pagingError(error)
            }
            throw error
        }
    }

    public func reload(pageSize: Int) async throws {
        await state.resetPrefetchedPages()
        try await request(pageSize: pageSize, isFirst: true)
    }
    
    public func stopPrefetching() {
        prefetchTask?.cancel()
        prefetchTask = nil
        Task { await state.endRequest() }
    }
    
    public func getCanLoadMore() async -> Bool {
        await state.canLoadMore
    }

    private func prefetchNextPages(pageSize: Int) async {
        prefetchTask?.cancel()
        prefetchTask = Task { [weak self] in
            guard let self else { return }
            guard await state.prefetchedPages < maxPrefetchPages else { return }
            do {
                let newItems = try await performPrefetch(pageSize: pageSize)
                await MainActor.run {
                    self.items.append(contentsOf: newItems)
                    self.objectWillChange.send()
                }
                await state.incrementPrefetchedPages()
                await updateCanLoadMore(items: newItems, pageSize: pageSize)
            } catch {
                print("Ошибка предварительной загрузки: \(error)")
            }
        }
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
        if let hasMore = model?.hasMore {
            await state.setCanLoadMore(hasMore)
        } else if let totalPages = model?.totalPages, let currentPage = model?.currentPage {
            await state.setCanLoadMore(currentPage < totalPages)
        } else {
            await state.setCanLoadMore(items.count == pageSize)
        }
    }
}

enum PagingError: Error {
    case requestInProgress
    case invalidResponse
}
