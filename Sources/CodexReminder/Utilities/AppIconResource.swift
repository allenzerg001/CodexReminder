import AppKit

enum AppIconResource {
    static let imageName = "touch_bar"
    static let fileName = "touch_bar.png"

    static func image() -> NSImage? {
        for url in imageURLs() {
            if let image = NSImage(contentsOf: url) {
                return image
            }
        }

        return NSImage(named: imageName)
    }

    private static func imageURLs() -> [URL] {
        var urls: [URL] = []

        if let bundleURL = Bundle.main.url(forResource: imageName, withExtension: "png") {
            urls.append(bundleURL)
        }

        if let resourceURL = Bundle.main.resourceURL {
            urls.append(resourceURL.appendingPathComponent(fileName))
        }

        urls.append(
            URL(fileURLWithPath: FileManager.default.currentDirectoryPath)
                .appendingPathComponent("Resources")
                .appendingPathComponent(fileName)
        )

        return urls
    }
}
