//
//  ContentView.swift
//  Example
//
//  Created by Nikolai Timonin on 17.01.2023.
//

import SwiftUI
import PagingList

struct ContentView: View {
    private enum Constants {
        static let requestLimit = 20
    }
    
    private let repository = IntsRepository()
    
    @State private var loadedPagesCount = 0
    @State private var items = [Int]()
    @State private var pagingState: PagingListState = .items
   
    // swiftlint:disable vertical_parameter_alignment_on_call
    var body: some View {
        PagingList(
            state: $pagingState,
            items: items
        ) { item in
            Text("\(item)")
        } fullscreenEmptyView: {
            FullscreenEmptyStateView()
        } fullscreenLoadingView: {
            FullscreenLoadingStateView()
        } fullscreenErrorView: { error in
            FullscreenErrorStateView(error: error) {
                // Показываем полноэкранную загрузку.
                pagingState = .fullscreenLoading
                // Заново запрашиваем первый пейдж.
                requestItems(isFirst: true)
            }
        } pagingDisabledView: {
            PagingDisabledStateView()
                .listRowSeparator(.hidden)
        } pagingLoadingView: {
            PagingLoadingStateView()
                .listRowSeparator(.hidden)
        } pagingErrorView: { error in
            PagingErrorStateView(error: error) {
                // Показываем загрузку пейджа.
                pagingState = .pagingLoading
                // Заново запрашиваем следующий пейдж
                requestItems(isFirst: false)
            }
                .listRowSeparator(.hidden)
        } onPageRequest: { isFirst in
            requestItems(isFirst: isFirst)
        }
        .listStyle(.plain)
        .onAppear {
            pagingState = .fullscreenLoading
            requestItems(isFirst: true)
        }
    }
    
    private func requestItems(isFirst: Bool) {
        // Сбрасываем счетчик уже загруженных страниц при загрузке первой.
        if isFirst {
            loadedPagesCount = 0
        }
        
        repository.getItems(
            limit: Constants.requestLimit,
            offset: loadedPagesCount * Constants.requestLimit
        ) { result in
            switch result {
            case .success(let newItems):
                if isFirst {
                    // Перезаписываем айтемы целиком после загрузки первого пейджа.
                    items = newItems
                } else {
                    // Добавляем айтемы после загрузки каждого следующего пейджа.
                    items += newItems
                }
                // После загрузки пейджа инкрементируем кол-во загруженных страниц.
                loadedPagesCount += 1
                // Выставляем состояние листа для показа айтемов либо выключаем пагинацию, если айтемы кончились.
                pagingState = newItems.count < Constants.requestLimit ? .disabled : .items
                
            case .failure(let error):
                if isFirst {
                    // При ошибке на первоначальной загрузке показываем полноэкранную ошибку.
                    pagingState = .fullscreenError(error)
                } else {
                    // При ошибке на загрузке следующего пейджа показываем ошибку загрузки пейджа.
                    pagingState = .pagingError(error)
                }
            }
        }
    }
}

private struct FullscreenLoadingStateView: View {
    var body: some View {
        ZStack {
            Color.pink
            Text("Loading")
        }
        .ignoresSafeArea(edges: .all)
    }
}

private struct FullscreenErrorStateView: View {
    var error: Swift.Error
    var onRetryAction: () -> Void
    
    var body: some View {
        ZStack {
            Color.red
            VStack {
                Text(error.localizedDescription)
                Button(action: onRetryAction) {
                    Text("Retry")
                }
            }
        }
        .ignoresSafeArea(edges: .all)
    }
}

private struct FullscreenEmptyStateView: View {
    var body: some View {
        ZStack {
            Color.green
            Text("Empty here")
        }
    }
}

private struct PagingLoadingStateView: View {
    var body: some View {
        ZStack {
            Color.gray
            Text("Loading next page")
        }
        .frame(height: 50)
    }
}

private struct PagingDisabledStateView: View {
    var body: some View {
        Color.clear
            .frame(height: 50)
    }
}

private struct PagingErrorStateView: View {
    var error: Swift.Error
    var onRetryAction: () -> Void
    
    var body: some View {
        ZStack {
            Color.red
            VStack {
                Text(error.localizedDescription)
                Button(action: onRetryAction) {
                    Text("Retry")
                }
            }
        }
        .frame(height: 50)
    }
}

struct ContentView_Previews: PreviewProvider {
    static var previews: some View {
        ContentView()
    }
}
