import UIKit

/// Settings → Suggest a feature (#142): an email to the support address on the website, with the version filled in.
/// nutrx has no analytics, so this and App Store reviews are how we learn what people want. Nothing is sent unless
/// they send the mail, and they see everything in it first.
enum FeatureSuggestion {
    /// The address on nutrx.nutrx-labs.com's support and privacy pages.
    static let address = "support@nutrx-labs.com"
    static let subject = "nutrx feature idea"

    /// The draft for this install: the app's version and build, the iOS version and the kind of device.
    static var mailURL: URL {
        mailURL(appVersion: Bundle.main.appVersion, build: Bundle.main.buildNumber,
                systemVersion: UIDevice.current.systemVersion, device: UIDevice.current.model)
    }

    /// Room to write at the top, then the versions under a rule, so a reply can ask about the right build.
    static func mailURL(appVersion: String, build: String, systemVersion: String, device: String) -> URL {
        var components = URLComponents()
        components.scheme = "mailto"
        components.path = address
        components.queryItems = [
            URLQueryItem(name: "subject", value: subject),
            URLQueryItem(name: "body", value: "\n\n\n—\nnutrx \(appVersion) (\(build)) · iOS \(systemVersion) · \(device)"),
        ]
        return components.url!
    }
}
