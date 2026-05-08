// swift-tools-version: 6.1

import PackageDescription

let package = Package(
   name: "SwiftDataKit",
   platforms: [.iOS(.v18)],
   products: [
      .library(
         name: "SwiftDataKit",
         targets: ["SwiftDataKit"]),
   ],
   dependencies: [
      .package(url: "https://github.com/thomasccpereira/tcp-files-kit", from: "1.0.0"),
      .package(url: "https://github.com/thomasccpereira/tcp-core-resources", from: "1.0.1"),
   ],
   targets: [
      .target(
         name: "SwiftDataKit",
         dependencies: [
            .product(name: "FilesKit", package: "tcp-files-kit"),
            .product(name: "CoreResources", package: "tcp-core-resources"),
         ],
         resources: [
            .process("Resources/Localizable.xcstrings")
         ]
      ),
      .testTarget(
         name: "SwiftDataKitTests",
         dependencies: ["SwiftDataKit"],
         resources: [
            .process("Resources/Localizable.xcstrings")
         ]
      ),
   ]
)
