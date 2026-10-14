import Foundation
import SwiftUI
import CoreText
import UIKit

extension View {
    func concertCard() -> some View {
        self.padding(.vertical)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(Color.btsCard)
            .clipShape(RoundedRectangle(cornerRadius: 20))
    }
    
    func inputCard() -> some View {
        self.padding()
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(Color.btsCard)
            .clipShape(RoundedRectangle(cornerRadius: 20))
    }
}

// MARK: - Шрифты (Unbounded — заголовки/цифры, Onest — основной текст)

enum BTSFonts {
    nonisolated(unsafe) private static var registered = false
    nonisolated private static let lock = NSLock()

    /// Регистрирует TTF из бандла в рантайме (UIAppFonts не нужен).
    nonisolated static func register() {
        lock.lock(); defer { lock.unlock() }
        guard !registered else { return }
        registered = true
        for name in ["Unbounded", "Onest"] {
            if let url = Bundle.main.url(forResource: name, withExtension: "ttf") {
                CTFontManagerRegisterFontsForURL(url as CFURL, .process, nil)
            }
        }
    }

    nonisolated static func suffix(for weight: Font.Weight) -> String {
        switch weight {
        case .ultraLight: return "ExtraLight"
        case .thin: return "Thin"
        case .light: return "Light"
        case .medium: return "Medium"
        case .semibold: return "SemiBold"
        case .bold: return "Bold"
        case .heavy: return "ExtraBold"
        case .black: return "Black"
        default: return "Regular"
        }
    }
}

extension Font {
    static func unbounded(_ size: CGFloat, _ weight: Font.Weight = .bold) -> Font {
        let s = BTSFonts.suffix(for: weight)
        let name = s == "Regular" ? "Unbounded-Regular" : "Unbounded-Regular_\(s)"
        // Именованный инстанс вариативного шрифта (проверено через CoreText: даёт wght 200...900).
        if UIFont(name: name, size: size) != nil { return .custom(name, size: size) }
        // Запасной путь: базовый шрифт + явная ось веса.
        if UIFont(name: "Unbounded-Regular", size: size) != nil {
            return .custom("Unbounded-Regular", size: size).weight(weight)
        }
        return .system(size: size, weight: weight)
    }

    static func onest(_ size: CGFloat, _ weight: Font.Weight = .regular) -> Font {
        let name = "Onest-\(BTSFonts.suffix(for: weight))"
        if UIFont(name: name, size: size) != nil { return .custom(name, size: size) }
        return .system(size: size, weight: weight)
    }
}
