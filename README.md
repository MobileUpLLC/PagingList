# PagingList

<p align="left">
    <a href="https://developer.apple.com/swift"><img src="https://img.shields.io/badge/language-Swift_5-green" alt="Swift5" /></a>
 <img src="https://img.shields.io/badge/platform-iOS-blue.svg?style=flat" alt="Platform iOS" />
 <a href="https://github.com/MobileUpLLC/Utils/blob/main/LICENSE"><img src="https://img.shields.io/badge/license-MIT-green" alt="License: MIT" /></a>
<img src="https://img.shields.io/badge/SPM-compatible-green" alt="SPM Compatible">
</p>

List view with pull-to-refresh and paging.

## Usage

1. Discuss with designers appearance of page loading/error view. This views appear **in front** of cells, not under the last cell, during loading next page or error.
2. Prepare fullscreen loading/error/empty views.
3. Prepare next page loading/error/disabled views. All of these views must know their height and be the same height.
4. Prepare object, that handles initial request, next page request, all items and loaded pages count.
    

##### PagingList Layout Example
```swift
@State private var pagingState: PagingListState = .items

PagingList(
    state: $pagingState,
    items: myItems
) { item in
    Text("\(item)")
} fullscreenEmptyView: {
    FullscreenEmptyStateView()
} fullscreenLoadingView: {
    FullscreenLoadingStateView()
} fullscreenErrorView: { error in
    FullscreenErrorStateView(error: error)
} pagingDisabledView: {
    PagingDisabledStateView()
} pagingLoadingView: {
    PagingLoadingStateView()
} pagingErrorView: { error in
    PagingErrorStateView(error: error)
} onPageRequest: { isFirst in
    // Request items.
    // Update paging list state.
}
```  

##### Request Items Example 
```swift
@State private var items = [Int]()
@State private var loadedPagesCount = 0
@State private var pagingState: PagingListState = .items
    
private func requestItems(isFirst: Bool) {
    // Reset loaded pages counter when loading the first page.
    if isFirst {
        loadedPagesCount = 0
    }
    
    repository.getItems(
        limt: Constants.requestLimit,
        offset: loadedPagesCount * Constants.requestLimit
    ) { result in
        switch result {
        case .success(let newItems):
            if isFirst {
                // Rewrite all items after the first page is loaded.
                items = newItems
            } else {
                // Add new items after the every next page is loaded.
                items += newItems
            }
            // Increment loaded pages counter after the page is loaded.
            loadedPagesCount += 1

            // Set the list paging state to display the items or disable pagination if there are no items remaining.
            pagingState = newItems.count < Constants.requestLimit ? .disabled : .items

        case .failure(let error):
            if isFirst {
                // Display a full screen error in case of the first page loading error.
                pagingState = .fullscreenError(error)
            } else {
                // Display a paging error in case of the next page loading error.
                pagingState = .pagingError(error)
            }
        }
    }
}
```
##### Notes
* It's necessary to turn off the pagination if there are no items remaining.
* In case of the next page loading error it's necessary to tap on the "Retry" button. The request will not be automatically reissued when scrolling

## Requirements

- Swift 5.0
- iOS 15.0

## Installation

PagingList has no external dependencies.

### Manual

Download and drag files from Source folder into your Xcode project.

### SPM

```swift
dependencies: [
    .package(url: "https://gitlab.com/mobileup/mobileup/development-ios/paging-list", .upToNextMajor(from: "2.0.0"))
]
```

## License

PagingList is distributed under the [MIT License](https://gitlab.com/mobileup/mobileup/development-ios/paging-list/-/blob/main/LICENSE).
