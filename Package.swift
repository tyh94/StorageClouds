// swift-tools-version: 6.3
// The swift-tools-version declares the minimum version of Swift required to build this package.

import PackageDescription

let package = Package(
    name: "StorageClouds",
    defaultLocalization: "en",
    platforms: [.iOS(.v17)],
    products: [
        .library(
            name: "StorageClouds",
            targets: ["StorageClouds"]
        ),
    ],
    dependencies: [
        .package(url: "https://github.com/tyh94/Storage.git", from: "1.0.1"),
        .package(url: "https://github.com/yandexmobile/yandex-login-sdk-ios.git", from: "3.1.0"),
        .package(url: "https://github.com/weichsel/ZIPFoundation.git", from: "0.9.20"),
        .package(url: "https://github.com/google/GoogleSignIn-iOS.git", from: "9.1.0"),
        .package(url: "https://github.com/tyh94/MKVNetwork.git", from: "1.0.0"),
    ],
    targets: [
        .target(
            name: "StorageClouds",
            dependencies: [
                .product(name: "YandexLoginSDK", package: "yandex-login-sdk-ios"),
                .product(name: "ZIPFoundation", package: "ZIPFoundation"),
                .product(name: "MKVNetwork", package: "MKVNetwork"),
                .product(name: "GoogleSignIn", package: "GoogleSignIn-iOS"),
                .product(name: "Storage", package: "Storage"),
            ],
        ),
        .testTarget(
            name: "StorageCloudsTests",
            dependencies: ["StorageClouds"]
        ),
    ],
    swiftLanguageModes: [.v6]
)
