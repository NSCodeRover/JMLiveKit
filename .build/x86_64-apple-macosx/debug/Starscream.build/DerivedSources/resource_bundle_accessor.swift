import class Foundation.Bundle

extension Foundation.Bundle {
    static let module: Bundle = {
        let mainPath = Bundle.main.bundleURL.appendingPathComponent("Starscream_Starscream.bundle").path
        let buildPath = "/Users/onkar.dhanlobhe/JMMediaSoup_iOS/.build/x86_64-apple-macosx/debug/Starscream_Starscream.bundle"

        let preferredBundle = Bundle(path: mainPath)

        guard let bundle = preferredBundle ?? Bundle(path: buildPath) else {
            fatalError("could not load resource bundle: from \(mainPath) or \(buildPath)")
        }

        return bundle
    }()
}