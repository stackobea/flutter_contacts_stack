// swift-tools-version:5.3
import PackageDescription

let package = Package(
    name: "flutter_contacts_stack",
    platforms: [
        .iOS(.v11)
    ],
    products: [
        .library(
            name: "flutter_contacts_stack",
            targets: ["flutter_contacts_stack"]
        ),
    ],
    targets: [
        .target(
            name: "flutter_contacts_stack",
            path: "Classes",
            publicHeadersPath: "."
        )
    ]
)