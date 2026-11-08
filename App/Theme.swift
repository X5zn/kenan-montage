import SwiftUI
import UIKit
import CoreText

enum Gold {
    static let light = Color(red: 247/255, green: 215/255, blue: 116/255)   // #f7d774
    static let deep  = Color(red: 200/255, green: 150/255, blue: 46/255)    // #c8962e
    static let gradient = LinearGradient(colors: [light, deep], startPoint: .topLeading, endPoint: .bottomTrailing)
    static let gradientSoft = LinearGradient(colors: [light.opacity(0.8), deep.opacity(0.8)], startPoint: .topLeading, endPoint: .bottomTrailing)
    static let bg = Color(red: 0.035, green: 0.031, blue: 0.027)
    static let card = Color.white.opacity(0.055)
    static let stroke = light.opacity(0.25)
    static let text = Color(red: 0.96, green: 0.93, blue: 0.86)
    static let dim = Color(red: 0.96, green: 0.93, blue: 0.86).opacity(0.55)
}

enum AppFont {
    /// Cairo is a variable font; weight is set through its wght axis.
    static func cairo(_ size: CGFloat, _ weight: CGFloat = 500) -> Font {
        let wght = 0x77676874 // 'wght'
        let key = UIFontDescriptor.AttributeName(rawValue: kCTFontVariationAttribute as String)
        let desc = UIFontDescriptor(fontAttributes: [.name: "Cairo-Regular", key: [wght: weight]])
        return Font(UIFont(descriptor: desc, size: size))
    }
    static func amiri(_ size: CGFloat) -> Font { Font.custom("Amiri-Bold", size: size) }
}

enum Haptic {
    static func tap() { UIImpactFeedbackGenerator(style: .medium).impactOccurred() }
    static func soft() { UIImpactFeedbackGenerator(style: .soft).impactOccurred() }
    static func success() { UINotificationFeedbackGenerator().notificationOccurred(.success) }
    static func warn() { UINotificationFeedbackGenerator().notificationOccurred(.warning) }
}

/// Arabic-Indic digits, like the web version.
func ar(_ s: String) -> String {
    let digits = Array("٠١٢٣٤٥٦٧٨٩")
    return String(s.map { (c: Character) -> Character in
        if c.isASCII, let v = c.wholeNumberValue { return digits[v] }
        return c
    })
}
func ar(_ n: Int) -> String { ar(String(n)) }
func arTime(_ seconds: Double) -> String {
    let s = max(0, Int(seconds.rounded()))
    return "\u{2066}" + ar(String(format: "%d:%02d", s / 60, s % 60)) + "\u{2069}"
}

struct GoldButtonStyle: ButtonStyle {
    var filled = true
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(AppFont.cairo(16, 700))
            .foregroundStyle(filled ? Color.black : Gold.light)
            .padding(.vertical, 13).frame(maxWidth: .infinity)
            .background {
                if filled { RoundedRectangle(cornerRadius: 16).fill(Gold.gradient) }
                else { RoundedRectangle(cornerRadius: 16).stroke(Gold.stroke, lineWidth: 1).background(RoundedRectangle(cornerRadius: 16).fill(Gold.card)) }
            }
            .scaleEffect(configuration.isPressed ? 0.97 : 1)
            .animation(.easeOut(duration: 0.15), value: configuration.isPressed)
    }
}

struct GlassCard: ViewModifier {
    func body(content: Content) -> some View {
        content
            .background(RoundedRectangle(cornerRadius: 20).fill(Gold.card))
            .overlay(RoundedRectangle(cornerRadius: 20).stroke(Gold.stroke, lineWidth: 0.8))
    }
}
extension View { func glassCard() -> some View { modifier(GlassCard()) } }
