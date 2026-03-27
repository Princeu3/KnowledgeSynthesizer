import Foundation
import SwiftUI

/// Supported knowledge source platforms
enum SourceType: String, Codable, CaseIterable, Identifiable {
    case instagram
    case twitter
    case youtube
    case github
    case website
    case linkedin
    case transcript
    case text

    var id: String { rawValue }

    var displayName: String {
        switch self {
        case .instagram: return "Instagram"
        case .twitter: return "Twitter/X"
        case .youtube: return "YouTube"
        case .github: return "GitHub"
        case .website: return "Website"
        case .linkedin: return "LinkedIn"
        case .transcript: return "Transcript"
        case .text: return "Text"
        }
    }

    var iconName: String {
        switch self {
        case .instagram: return "camera.circle.fill"
        case .twitter: return "bird.fill"
        case .youtube: return "play.rectangle.fill"
        case .github: return "chevron.left.forwardslash.chevron.right"
        case .website: return "globe"
        case .linkedin: return "link.circle.fill"
        case .transcript: return "waveform"
        case .text: return "doc.text.fill"
        }
    }

    var accentColorHex: String {
        switch self {
        case .instagram: return "#E1306C"
        case .twitter: return "#1DA1F2"
        case .youtube: return "#FF0000"
        case .github: return "#333333"
        case .website: return "#4A90D9"
        case .linkedin: return "#0077B5"
        case .transcript: return "#FF6B35"
        case .text: return "#8E8E93"
        }
    }

    /// Pre-computed Color from hex — avoids Scanner allocation per render
    private static let colorCache: [SourceType: Color] = {
        var cache: [SourceType: Color] = [:]
        for source in SourceType.allCases {
            let hex = source.accentColorHex.trimmingCharacters(in: CharacterSet(charactersIn: "#"))
            let scanner = Scanner(string: hex)
            var rgbValue: UInt64 = 0
            scanner.scanHexInt64(&rgbValue)
            cache[source] = Color(
                red: Double((rgbValue & 0xFF0000) >> 16) / 255.0,
                green: Double((rgbValue & 0x00FF00) >> 8) / 255.0,
                blue: Double(rgbValue & 0x0000FF) / 255.0
            )
        }
        return cache
    }()

    var accentColor: Color {
        Self.colorCache[self]!
    }

    /// Detect source type from a URL string
    static func detect(from urlString: String) -> SourceType {
        let lowered = urlString.lowercased()
        if lowered.contains("instagram.com") { return .instagram }
        if lowered.contains("twitter.com") || lowered.contains("x.com") { return .twitter }
        if lowered.contains("youtube.com") || lowered.contains("youtu.be") { return .youtube }
        if lowered.contains("github.com") { return .github }
        if lowered.contains("linkedin.com") { return .linkedin }
        return .website
    }
}
