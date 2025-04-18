import Foundation

enum PagingError: Error {
    case requestInProgress
    case invalidResponse
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
    private let fetchPage: @Sendable (_ page: Int, _ pageSize: Int) async throws -> ResponseModel

    public init(
        startPage: Int = 1,
        fetchPage: @escaping @Sendable (_ page: Int, _ pageSize: Int) async throws -> ResponseModel
    ) {
        self.state = PageRequestState(startPage: startPage, prefetchTreshold: 2)
        self.fetchPage = fetchPage
        
        // Подписываемся на уведомление для остановки префетчинга при закрытии экрана с PagingList
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
    
    public func request(pageSize: Int, isFirst: Bool) async throws {
        guard await state.startRequest() else {
            throw PagingError.requestInProgress
        }
        
        defer { Task { await state.endRequest() } }

        let currentPage = await state.currentPage
        let page = isFirst ? state.startPage : currentPage
        
        do {
            let modelItems: [DataModel]
            
            if
                isFirst == false,
                let prefetchedResponse = await state.getPrefetchedResponse(for: page),
                let items = prefetchedResponse.items as? [DataModel]
            {
                // Используем префетч-данные, если они есть для текущей страницы
                modelItems = items
                await updateCanLoadMore(items: items, pageSize: pageSize, model: prefetchedResponse)
            } else {
                // Выполняем запрос, если префетч-данных нет
                if isFirst {
                    await state.resetPrefetchedPages()
                }
                
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
            
            await prefetchIfNeeded(pageSize: pageSize)
        } catch {
            await state.setPagingState(isFirst ? .fullscreenError(error) : .pagingError(error))
            throw error
        }
    }
    
    public func stopPrefetching() {
        Task {
            await state.cancelPrefetchTask()
            await state.endRequest()
            await state.setPrefetchPending(false)
        }
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
            guard let self else { return }
            
            guard await state.canPrefetchMore else {
                await state.setPrefetchPending(false)
                return
            }
            
            guard await state.isPrefetchPending else { return }
            
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
