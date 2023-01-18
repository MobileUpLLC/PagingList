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
