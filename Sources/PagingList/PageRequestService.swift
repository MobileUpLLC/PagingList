import Foundation

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
public final class PageRequestService<ResponseModel: PaginatedResponse, DataModel: Codable>: ObservableObject {
    @Published public var pagingState: PagingListState = .fullscreenLoading
    @Published public var items: [DataModel] = []
    public private(set) var canLoadMore: Bool = true
    public private(set) var prefetchedPages: Int = 0
    
    private var startPage: Int
    private var currentPage: Int
    private var isRequestInProcess = false
    private var prefetchTask: Task<Void, Never>? // Для управления префетчингом
    private let maxPrefetchPages: Int = 2 // Максимум 2 страницы вперед
    
    private var requestBuilder: ((PageRequestModel<ResponseModel>) -> Void)?
    private var resultHandler: ((Result<[DataModel], Error>) -> Void)?
    
    public init(startPage: Int = 1) {
        self.startPage = startPage
        self.currentPage = startPage
    }
    
    public func request(
        pageSize: Int,
        isFirst: Bool,
        group: DispatchGroup? = nil,
        requestBuilder: @escaping (PageRequestModel<ResponseModel>) -> Void,
        resultHandler: @escaping (Result<[DataModel], Error>) -> Void
    ) {
        guard isRequestInProcess == false else {
            return
        }
        
        guard canLoadMore else {
            pagingState = .items
            return
        }
        
        isRequestInProcess = true
        group?.enter()
        
        self.requestBuilder = requestBuilder
        self.resultHandler = resultHandler
        
        let page = isFirst ? 1 : currentPage
        
        let pageRequestModel = PageRequestModel<ResponseModel>(
            page: page,
            pageSize: pageSize
        ) { [weak self] result in
            self?.isRequestInProcess = false
            
            switch result {
            case .success(let model):
                guard let self, let items = model.items as? [DataModel] else {
                    return
                }
                
                currentPage += items.count == .zero ? .zero : 1
                pagingState = .items
                
                if let hasMore = model.hasMore {
                    canLoadMore = hasMore
                } else if let totalPages = model.totalPages, let currentPage = model.currentPage {
                    canLoadMore = currentPage < totalPages
                } else {
                    canLoadMore = items.count == pageSize
                }
                
                if isFirst {
                    self.items = items
                    prefetchedPages = 0
                } else {
                    self.items.append(contentsOf: items)
                }
                
                resultHandler(.success(items))
                
                // Запускаем префетчинг, если возможно
                if canLoadMore && isFirst == false && prefetchedPages < maxPrefetchPages {
                    prefetchNextPages(pageSize: pageSize)
                }
            case .failure(let error):
                if isFirst {
                    self?.pagingState = .fullscreenError(error)
                } else {
                    self?.pagingState = .pagingError(error)
                }
                
                resultHandler(.failure(error))
            }
            
            group?.leave()
        }
        
        requestBuilder(pageRequestModel)
    }
    
    public func reload(group: DispatchGroup? = nil) {
        // NOTE: This property is necessary to receive new elements on reload, if they exist.
        let roundingSize = items.count % 10
        let additionalSize = 10 - (roundingSize == .zero ? 10 : roundingSize)
        let pageSize = items.count + additionalSize
        
        group?.enter()
        
        let pageRequestModel = PageRequestModel<ResponseModel>(
            page: startPage,
            pageSize: pageSize
        ) { [weak self] result in
            switch result {
            case .success(let model):
                guard let self, let items = model.items as? [DataModel] else {
                    return
                }
                
                self.pagingState = .items
                self.items = items
                self.canLoadMore = items.count == pageSize
                
                self.resultHandler?(.success(self.items))
            case .failure(let error):
                self?.pagingState = .fullscreenError(error)
                
                self?.resultHandler?(.failure(error))
            }
            
            group?.leave()
        }
        
        requestBuilder?(pageRequestModel)
    }
    
    private func prefetchNextPages(pageSize: Int) {
        prefetchTask?.cancel() // Отменяем предыдущий префетчинг
        
        prefetchTask = Task { [weak self] in
            guard let self else { return }
            
            var pagesToFetch = self.maxPrefetchPages - self.prefetchedPages
            while pagesToFetch > 0 && self.canLoadMore && !Task.isCancelled {
                try? await performPrefetch(pageSize: pageSize)
                pagesToFetch -= 1
            }
        }
    }
    
    private func performPrefetch(pageSize: Int) async throws {
        guard isRequestInProcess == false, canLoadMore else {
            return
        }
        
        isRequestInProcess = true
        
        let pageRequestModel = PageRequestModel<ResponseModel>(
            page: currentPage,
            pageSize: pageSize
        ) { [weak self] result in
            self?.isRequestInProcess = false
            
            switch result {
            case .success(let model):
                guard let self, let items = model.items as? [DataModel] else {
                    return
                }
                
                self.currentPage += items.count == 0 ? 0 : 1
                self.prefetchedPages += 1
                
                if let hasMore = model.hasMore {
                    self.canLoadMore = hasMore
                } else if let totalPages = model.totalPages, let currentPage = model.currentPage {
                    self.canLoadMore = currentPage < totalPages
                } else {
                    self.canLoadMore = items.count == pageSize
                }
                
                // Синхронное обновление на главном потоке
                DispatchQueue.main.async {
                    self.items.append(contentsOf: items)
                    self.resultHandler?(.success(items))
                }
            case .failure:
                // Игнорируем ошибки префетчинга
                break
            }
        }
        
        requestBuilder?(pageRequestModel)
    }
    
    public func stopPrefetching() {
        prefetchTask?.cancel()
        prefetchTask = nil
        isRequestInProcess = false
    }
}
