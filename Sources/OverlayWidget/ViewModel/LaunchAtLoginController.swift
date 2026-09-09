//
//  LaunchAtLoginController.swift
//  OverlayWidget
//
//  Created by Iv Lugantsov on 09.09.2026.
//

import Foundation
import ServiceManagement

/// SMAppService.mainApp регистрирует именно текущий бандл — по-настоящему заработает
/// только когда приложение запущено из установленного .app (не из голого swift build).
final class LaunchAtLoginController: ObservableObject {
    @Published private(set) var isEnabled: Bool

    init() {
        isEnabled = SMAppService.mainApp.status == .enabled
    }

    func setEnabled(_ enabled: Bool) {
        do {
            if enabled {
                try SMAppService.mainApp.register()
            } else {
                try SMAppService.mainApp.unregister()
            }
        } catch {
            FileHandle.standardError.write(Data("LaunchAtLoginController: \(error)\n".utf8))
        }
        isEnabled = SMAppService.mainApp.status == .enabled
    }
}
