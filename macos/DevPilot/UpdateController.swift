import AppKit
import Foundation
import Sparkle

final class UpdateController {
    static let shared = UpdateController()

    private let updaterController: SPUStandardUpdaterController?

    private init() {
        guard Self.hasValidConfiguration else {
            updaterController = nil
            return
        }

        updaterController = SPUStandardUpdaterController(
            startingUpdater: true,
            updaterDelegate: nil,
            userDriverDelegate: nil
        )
    }

    func checkForUpdates() {
        guard let updaterController else {
            showMissingConfigurationAlert()
            return
        }

        updaterController.checkForUpdates(nil)
    }

    private static var hasValidConfiguration: Bool {
        let bundle = Bundle.main
        let feedURL = bundle.object(forInfoDictionaryKey: "SUFeedURL") as? String
        let publicKey = bundle.object(forInfoDictionaryKey: "SUPublicEDKey") as? String

        return feedURL?.isEmpty == false && publicKey?.isEmpty == false
    }

    private func showMissingConfigurationAlert() {
        let alert = NSAlert()
        alert.messageText = "更新尚未配置"
        alert.informativeText = "发布版本需要配置 Sparkle 公钥和 appcast 地址后才能检查更新。"
        alert.alertStyle = .informational
        alert.addButton(withTitle: "好")
        alert.runModal()
    }
}
