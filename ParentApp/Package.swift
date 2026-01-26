// swift-tools-version: 5.9
import PackageDescription

let package = Package(
    name: "ParentApp",
    platforms: [
        .iOS(.v17),
        .macOS(.v14)
    ],
    products: [
        .executable(name: "ParentApp", targets: ["ParentApp"])
    ],
    targets: [
        .executableTarget(
            name: "ParentApp",
            path: "ParentApp"
        )
    ]
)
