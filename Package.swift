// swift-tools-version:5.9
import PackageDescription

let package = Package(
    name: "YandexOverlay",
    platforms: [.macOS(.v13)],
    targets: [
        .executableTarget(
            name: "YandexOverlay",
            exclude: [
                // Иконка приложения копируется напрямую в .app при упаковке (Scripts/build_app.sh),
                // не через Bundle.module — не нужна как SPM-ресурс.
                "Resources/AppIcon.icns"
            ],
            resources: [
                .copy("Resources/mediaremote-adapter.pl"),
                .copy("Resources/MediaRemoteAdapter.framework"),
                .copy("Resources/MediaRemoteAdapterTestClient"),
                .copy("Resources/LICENSE-mediaremote-adapter.txt")
            ]
        )
    ]
)
