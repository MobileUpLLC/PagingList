//
//  ListWithSection.swift
//  Example
//
//  Created by Victor Kostin on 19.11.2024.
//

import SwiftUI
import PagingList

private struct SectionViewItem: Identifiable {
    let id = UUID()
    let title: String
    let items: [Int]
}

struct ListWithSection: View {
    private enum Constants {
        static let requestLimit = 20
    }
    
    @State private var loadedPagesCount = 0
    @State private var sections: [SectionViewItem] = []
    @State private var pagingState: PagingListState = .items
    
    private let repository = IntsRepository()
    
    var body: some View {
        PagingList(
            state: $pagingState,
            items: sections
        ) { item in
            Section(content: {
                ForEach(item.items) { item in
                    Text("\(item)")
                }
            }, header: {
                RunningTitleView(title: item.title)
            }, footer: {
                RunningTitleView(title: "Footer")
                // modifier to setup padding for section
                // footer without padding
                .listRowInsets(EdgeInsets())
            })
        } fullscreenEmptyView: {
            FullscreenEmptyStateView()
        } fullscreenLoadingView: {
            FullscreenLoadingStateView()
        } fullscreenErrorView: { error in
            FullscreenErrorStateView(error: error) {
                // Show fullscreen loading on retry action.
                pagingState = .fullscreenLoading
                // Retrye first page request.
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
                // Show next page loading on next page retry action.
                pagingState = .pagingLoading
                // Retry next page request.
                requestItems(isFirst: false)
            }
            .listRowSeparator(.hidden)
        } onPageRequest: { isFirst in
            requestItems(isFirst: isFirst)
        } onRefreshRequest: {
            await refreshItems()
        }
        // sheet style modifier to customize non-sticky header and footer
        // change to .plain for sticky header
        // change to .inset for sticky header and footer
        .listStyle(.grouped)
        // modifier to hide the system background of the scroll view list
        .scrollContentBackground(.hidden)
        .onAppear {
            pagingState = .fullscreenLoading
            requestItems(isFirst: true)
        }
    }
    // swiftlint:enable vertical_parameter_alignment_on_call
    
    // Sync method for first loading and pagination loading content.
    private func requestItems(isFirst: Bool) {
        Task {
            await requestItems(isFirst: isFirst)
        }
    }
    
    // Async method for loading and refreshing content.
    private func refreshItems() async {
        await requestItems(isFirst: true)
    }
    
    // Async method for loading content.
    private func requestItems(isFirst: Bool) async {
        if isFirst, sections.isEmpty == false {
            // Refresh content.
            pagingState = .refresh
            loadedPagesCount = 0
        } else if isFirst {
            // Reset loaded pages counter when loading the first page.
            pagingState = .fullscreenLoading
            loadedPagesCount = 0
        } else {
            // Loading pagination pages.
            pagingState = .pagingLoading
        }
        
        do {
            let newItems = try await repository.getItems(
                limit: Constants.requestLimit,
                offset: loadedPagesCount * Constants.requestLimit
            )
            
            if isFirst, sections.isEmpty {
                self.sections = []
                self.sections.append(getSectionItem(with: newItems))
            } else if isFirst, sections.isEmpty == false {
                self.sections = []
                self.sections.append(getSectionItem(with: newItems))
            } else {
                self.sections.append(getSectionItem(with: newItems))
            }
            
            // Increment loaded pages counter after the page is loaded.
            loadedPagesCount += 1
            
            // Set the list paging state to display the items or disable pagination if there are no items remaining.
            pagingState = newItems.count < Constants.requestLimit ? .disabled : .items
        } catch let error {
            if isFirst {
                // Display a full screen error in case of the first page loading error.
                pagingState = .fullscreenError(error)
                // Сlearing items for correct operation of the state loader.
                sections = []
            } else {
                // Display a paging error in case of the next page loading error.
                pagingState = .pagingError(error)
            }
        }
    }
    
    private func getSectionItem(with items: [Int]) -> SectionViewItem {
        return SectionViewItem(
            title: "items \(items.first ?? 0)-\(items.last ?? 0)",
            items: items
        )
    }
}

private struct RunningTitleView: View {
    let title: String
    
    var body: some View {
        HStack {
            Spacer()
            Text(title)
                .foregroundStyle(.black)
                .frame(height: 40)
            Spacer()
        }
        .background(.red)
    }
}

struct ListWithSection_Previews: PreviewProvider {
    static var previews: some View {
        ListWithSection()
    }
}
