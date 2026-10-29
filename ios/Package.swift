// swift-tools-version: 6.0
import PackageDescription

let package = Package(
  name: "FORMA",
  platforms: [.iOS(.v17), .macOS(.v14)],
  products: [
    .library(name: "FORMASurfaces", targets: ["FORMASurfaces"]),
    .library(name: "FORMACore", targets: ["FORMACore"]),
    .executable(name: "FORMAContractProbe", targets: ["FORMAContractProbe"]),
  ],
  targets: [
    .target(name: "FORMASurfaces"),
    .testTarget(name: "FORMASurfacesTests", dependencies: ["FORMASurfaces"]),
    .systemLibrary(name: "CSQLite", pkgConfig: "sqlite3", providers: [.apt(["libsqlite3-dev"])]),
    .target(name: "FORMACore", dependencies: ["CSQLite"]),
    .executableTarget(name: "FORMAContractProbe", dependencies: ["FORMACore"]),
    .testTarget(name: "FORMACoreTests", dependencies: ["FORMACore", "CSQLite"]),
  ],
  swiftLanguageModes: [.v6]
)
