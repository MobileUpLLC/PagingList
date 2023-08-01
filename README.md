# PagingList

<p align="left">
    <a href="https://developer.apple.com/swift"><img src="https://img.shields.io/badge/language-Swift_5-green" alt="Swift5" /></a>
 <img src="https://img.shields.io/badge/platform-iOS-blue.svg?style=flat" alt="Platform iOS" />
 <a href="https://github.com/MobileUpLLC/Utils/blob/main/LICENSE"><img src="https://img.shields.io/badge/license-MIT-green" alt="License: MIT" /></a>
<img src="https://img.shields.io/badge/SPM-compatible-green" alt="SPM Compatible">
</p>

Lightweight list view with pull-to-refresh and paging.

## Features
* Initial data request.
* Paging data request.
* Error handling(with retry) for all request types.
* Paging type agnostic. Works with *offset-limit*, *last item* and others paging types. 

## Usage
1. Provide your state views:

1.1 Views for fullscreen loading/error/emtpty data states:
 - `FullscreenEmptyStateView`
 - `FullscreenLoadingStateView`
 - `FullscreenErrorStateView`

1.2 Views(cells) for next page loading/error/disabled states:
 - `PagingLoadingStateView`
 - `PagingErrorStateView`
 - `PagingDisabledStateView`

 **Notes:** All of these cell views must know their height and be the same height in order to disable list glitching on state changes.

2. Layout `PagingList` with state views:
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
    // Request items and update paging state.
    requestItems(isFirst: isFirst)
}
```  

3. Provde items request handler:
```swift
@State private var items = [Int]()
@State private var loadedPagesCount = 0

// Items provider that supports offset-limit requests.
private let repository = IntsRepository()

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

            // Set the list paging state to display the items 
            // or disable pagination if there are no items remaining.
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
**Notes:**
* It's necessary to turn off the pagination if there are no items remaining.
* In case of the next page loading error it's necessary to tap on the "Retry" button. The request will not be automatically reissued when scrolling.

## Implementation details
PagindList doesn't use any external dependencies.

Under the hood `SwiftUI.List` is used, so any list modificators are available for both `PagingList` iteself and item cell view.

## Requirements

- Swift 5.0
- iOS 15.0

## Installation

#### SPM
```swift
dependencies: [
    .package(
        url: "https://gitlab.com/mobileup/mobileup/development-ios/paging-list", 
        .upToNextMajor(from: "2.0.0")
    )
]
```

## License
PagingList is distributed under the [MIT License](https://github.com/MobileUpLLC/PagingList/blob/main/LICENSE).
