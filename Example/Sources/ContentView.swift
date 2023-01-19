//
//  ContentView.swift
//  Example
//
//  Created by Nikolai Timonin on 17.01.2023.
//

import SwiftUI
import PagingList

extension Int: Identifiable {
    public var id: Int { self }
}

struct ContentView: View {
    @State var items = [Int]()
    private let r = ItemsRepository()
    
    var body: some View {
        PagingList(items: items) { item in
            Text("\(item)")
        } fullscreenEmptyView: {
            FullscreenEmptyStateView()
        } fullscreenLoadingView: {
            FullscreenLoadingStateView()
        } fullscreenErrorView: { error in
            FullscreenErrorStateView(error: error) {
                print("qwe")
            }
        } pagingLoadingView: {
            PagingLoadingStateView()
        } pagingErrorView: { error in
            PagingErrorStateView(error: error) {
            }
        } onPageRequest: { descriptor in
            r.getItems { ints in
                if descriptor.type.isInitial {
                    items = ints
                } else {
                    items.append(contentsOf: ints)
                }
                descriptor.completion(.success(()))
            }
        }
    }
}

struct ContentView_Previews: PreviewProvider {
    static var previews: some View {
        ContentView()
    }
}

class ItemsRepository {
    var page = 0
    let limit = 20
    
    func getItems(completion: @escaping ([Int]) -> Void) {
        getItems(limt: limit, offset: limit * page) { [weak self] items in
            self?.page += 1
            completion(items)
        }
    }
    
    func getItems(limt: Int, offset: Int, completion: @escaping ([Int]) -> Void) {
        DispatchQueue.main.asyncAfter(deadline: .now() + 1) {
            let newItems = Array(offset..<(offset + limt))
            completion(newItems)
        }
    }
}

private struct FullscreenLoadingStateView: View {
    var body: some View {
        ZStack {
            Color.pink
            Text("Loading")
        }
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

private struct PagingIdleStateView: View {
    var body: some View {
        EmptyView()
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
