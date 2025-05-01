// swift-tools-version: 6.0
// The swift-tools-version declares the minimum version of Swift required to build this package.

import PackageDescription

let package = Package(
    name: "AppStorys-iOS",
    platforms: [.iOS(.v16)],
    products: [
        .library(
            name: "AppStorys-iOS",
            targets: ["AppStorys-iOS"]),
    ],
    dependencies: [
        .package(url: "https://github.com/SDWebImage/SDWebImageSwiftUI.git", from: "3.0.0"),
        .package(url: "https://github.com/airbnb/lottie-ios.git", from: "4.3.0")
    ],
    targets: [
        .target(
            name: "AppStorys-iOS",
            dependencies: [
                .product(name: "SDWebImageSwiftUI", package: "SDWebImageSwiftUI"),
                .product(name: "Lottie", package: "lottie-ios")
            ]
        )
    ]
)
