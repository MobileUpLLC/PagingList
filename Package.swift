// swift-tools-version: 5.7
// The swift-tools-version declares the minimum version of Swift required to build this package.

import PackageDescription

let package = Package(
    name: "PagingList",
    platforms: [
        .iOS(.v15)
    ],
    products: [
        // Products define the executables and libraries a package produces, and make them visible to other packages.
        .library(
            name: "PagingList",
            targets: ["PagingList"])
    ],
    dependencies: [
        .package(
            url: "https://github.com/crelies/AdvancedList",
            .upToNextMajor(from: "8.0.0")
        )
    ],
    targets: [
        .target(
            name: "PagingList",
            dependencies: ["AdvancedList"])
    ]
)
