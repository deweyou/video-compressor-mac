import AppKit
import Foundation

struct ExportPathService {
    @MainActor
    func chooseDirectory(initialURL: URL?) -> URL? {
        let panel = NSOpenPanel()
        panel.canChooseDirectories = true
        panel.canChooseFiles = false
        panel.allowsMultipleSelection = false
        panel.prompt = L10n.tr("button_select_output")
        panel.directoryURL = initialURL
        return panel.runModal() == .OK ? panel.url : nil
    }

    func isWritableDirectory(_ url: URL) -> Bool {
        var isDir: ObjCBool = false
        guard FileManager.default.fileExists(atPath: url.path, isDirectory: &isDir), isDir.boolValue else {
            return false
        }
        return FileManager.default.isWritableFile(atPath: url.path)
    }
}
