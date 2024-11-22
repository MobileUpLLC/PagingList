//
//  ContentView.swift
//  Example
//
//  Created by Nikolai Timonin on 17.01.2023.
//

import SwiftUI
import PagingList

enum PagingListType: Equatable, Hashable, Identifiable {
    case listWithSection
    case listWithoutSection
    
    var id: Self { self }
}

struct ContentView: View {
    @State var navigationPath: [PagingListType] = []

    var body: some View {
        NavigationStack(path: $navigationPath) {
            VStack {
                Button {
                    navigationPath.append(.listWithSection)
                } label: {
                    Text("Tap to go list with section")
                        .padding(20)
                }
                .background(.gray)
                .cornerRadius(15)
                
                Button {
                    navigationPath.append(.listWithoutSection)
                } label: {
                    Text("Tap to go list without section")
                        .padding(20)
                }
                .background(.gray)
                .cornerRadius(15)
            }
            .navigationDestination(for: PagingListType.self) { type in
                switch type {
                case .listWithSection:
                    ListWithSectionsView()
                case .listWithoutSection:
                    ListWithoutSectionView()
                }
            }
        }
    }
}

struct ContentView_Previews: PreviewProvider {
    static var previews: some View {
        ContentView()
    }
}
