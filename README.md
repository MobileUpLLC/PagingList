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
3. Prepare next page loading/error views.
4. Prepare object, that handles initial request, next page request, all items and loaded pages count.
    

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
} pagingLoadingView: {
    PagingLoadingStateView()
} pagingErrorView: { error in
    PagingErrorStateView(error: error)
} onPageRequest: { isFirst in
    // Request items.
    // Update paging list state.
}
```

## Requirements

- Swift 5.0
- iOS 15.0

## Installation

PagingList contains [AdvancedList](https://github.com/crelies/AdvancedList) as external dependency.

### Manual

Download and drag files from Source folder into your Xcode project.

### SPM

```swift
dependencies: [
    .package(url: "https://gitlab.com/mobileup/mobileup/development-ios/paging-list", .upToNextMajor(from: "1.0.0"))
]
```

## License

PagingList is distributed under the [MIT License](https://gitlab.com/mobileup/mobileup/development-ios/paging-list/LICENSE).