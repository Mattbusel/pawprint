import SwiftUI

extension Color {
    init(hex: UInt32, alpha: Double = 1) {
        self.init(.sRGB, red: Double((hex >> 16) & 0xFF) / 255, green: Double((hex >> 8) & 0xFF) / 255, blue: Double(hex & 0xFF) / 255, opacity: alpha)
    }
}

/// Oat: warm oatmeal paper, cocoa ink, one persimmon accent, sage for "done".
enum Oat {
    static let bg = Color(hex: 0xFBF4EA)
    static let bg2 = Color(hex: 0xF3E8D8)
    static let card = Color(hex: 0xFFFCF7)
    static let ink = Color(hex: 0x2E2019)
    static let ink2 = Color(hex: 0x2E2019, alpha: 0.70)
    static let dim = Color(hex: 0x2E2019, alpha: 0.46)
    static let faint = Color(hex: 0x2E2019, alpha: 0.28)
    static let line = Color(hex: 0x2E2019, alpha: 0.08)
    static let line2 = Color(hex: 0x2E2019, alpha: 0.15)
    static let accent = Color(hex: 0xE2663B)
    static let accentSoft = Color(hex: 0xE2663B, alpha: 0.13)
    static let sage = Color(hex: 0x4F8A62)
    static let sageSoft = Color(hex: 0x4F8A62, alpha: 0.13)
    static let honey = Color(hex: 0xC98A1C)
    static let honeySoft = Color(hex: 0xE9A93B, alpha: 0.18)
    static let berry = Color(hex: 0xC43E4A)
    static let berrySoft = Color(hex: 0xC43E4A, alpha: 0.11)
    static let sky = Color(hex: 0x4F7FA8)
    static let skySoft = Color(hex: 0x4F7FA8, alpha: 0.13)
    static let people: [Color] = [Color(hex: 0xE2663B), Color(hex: 0x4F8A62), Color(hex: 0x4F7FA8), Color(hex: 0xC98A1C), Color(hex: 0x8A5A8C), Color(hex: 0x3E8A86)]
}

/// Each pet gets a coat. Drives the illustrated face and the tint behind it.
struct Coat {
    let bg: Color, fur: Color, dark: Color, light: Color, inner: Color, eye: Color
    static let all: [Coat] = [
        Coat(bg: Color(hex: 0xF6DCC3), fur: Color(hex: 0xC98B4F), dark: Color(hex: 0x6E4326), light: Color(hex: 0xFFF6EC), inner: Color(hex: 0xE8A69A), eye: Color(hex: 0x2E2019)),
        Coat(bg: Color(hex: 0xD9E4EE), fur: Color(hex: 0x8E8F99), dark: Color(hex: 0x55565F), light: Color(hex: 0xF3F2F5), inner: Color(hex: 0xEBA9A5), eye: Color(hex: 0x9CBB5A)),
        Coat(bg: Color(hex: 0xE2EBD6), fur: Color(hex: 0xEADAC0), dark: Color(hex: 0xC4A077), light: Color(hex: 0xFFFBF3), inner: Color(hex: 0xF0B7B0), eye: Color(hex: 0x2E2019)),
        Coat(bg: Color(hex: 0xF4DADB), fur: Color(hex: 0x3A3130), dark: Color(hex: 0x1E1817), light: Color(hex: 0x9C8C86), inner: Color(hex: 0xD98E8E), eye: Color(hex: 0xE3B341)),
        Coat(bg: Color(hex: 0xF6E8BC), fur: Color(hex: 0xD9AE62), dark: Color(hex: 0xA2742F), light: Color(hex: 0xFFF5DC), inner: Color(hex: 0xE9A08F), eye: Color(hex: 0x2E2019)),
        Coat(bg: Color(hex: 0xE4DEF0), fur: Color(hex: 0xF7F3EC), dark: Color(hex: 0xCDBFAF), light: Color(hex: 0xFFFFFF), inner: Color(hex: 0xF0AFB0), eye: Color(hex: 0x4F7FA8)),
    ]
    static func of(_ i: Int) -> Coat { all[((i % all.count) + all.count) % all.count] }
}

extension Font {
    static func display(_ s: CGFloat, _ w: Font.Weight = .bold) -> Font { .system(size: s, weight: w, design: .serif) }
    static func round(_ s: CGFloat, _ w: Font.Weight = .semibold) -> Font { .system(size: s, weight: w, design: .rounded) }
    static func num(_ s: CGFloat, _ w: Font.Weight = .bold) -> Font { .system(size: s, weight: w, design: .rounded).monospacedDigit() }
    static func text(_ s: CGFloat = 15, _ w: Font.Weight = .regular) -> Font { .system(size: s, weight: w) }
    static func eyebrow(_ s: CGFloat = 11) -> Font { .system(size: s, weight: .heavy, design: .rounded) }
}

struct Eyebrow: View {
    let text: String
    var color: Color = Oat.dim
    init(_ t: String, color: Color = Oat.dim) { text = t; self.color = color }
    var body: some View { Text(text.uppercased()).font(.eyebrow()).tracking(1.4).foregroundStyle(color) }
}

extension View {
    /// A soft card on the oat paper.
    func card(_ pad: CGFloat = 16, radius: CGFloat = 24, fill: Color = Oat.card) -> some View {
        padding(pad)
            .background(RoundedRectangle(cornerRadius: radius, style: .continuous).fill(fill).shadow(color: Oat.ink.opacity(0.06), radius: 14, y: 6))
            .overlay(RoundedRectangle(cornerRadius: radius, style: .continuous).strokeBorder(Oat.line, lineWidth: 1))
    }
    /// A pressable surface that squashes a little.
    func pressable() -> some View { buttonStyle(Squish()) }
}

struct Squish: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label.scaleEffect(configuration.isPressed ? 0.96 : 1).animation(.spring(response: 0.25, dampingFraction: 0.6), value: configuration.isPressed)
    }
}

/// Oat paper with a trail of faint paw prints wandering across the top.
struct OatBackground: View {
    var body: some View {
        ZStack {
            Oat.bg
            RadialGradient(colors: [Color(hex: 0xFCE3CF).opacity(0.9), .clear], center: .topTrailing, startRadius: 10, endRadius: 420)
            PawTrail(count: 7, color: Oat.ink.opacity(0.045)).frame(height: 300).frame(maxHeight: .infinity, alignment: .top)
        }.ignoresSafeArea()
    }
}

struct PawTrail: View {
    var count = 7
    var color: Color
    var body: some View {
        Canvas { ctx, size in
            guard let paw = ctx.resolveSymbol(id: 0) else { return }
            for i in 0..<count {
                let t = CGFloat(i) / CGFloat(max(1, count - 1))
                let x = size.width * (1.02 - t * 0.62)
                let y = 36 + t * size.height * 0.62 + (i % 2 == 0 ? -14 : 14)
                var c = ctx
                c.translateBy(x: x, y: y)
                c.rotate(by: .degrees(-128 + Double(i % 2) * 8))
                c.draw(paw, at: .zero)
            }
        } symbols: {
            Image(systemName: "pawprint.fill").font(.system(size: 26)).foregroundStyle(color).tag(0)
        }
        .allowsHitTesting(false)
    }
}

struct Chip: View {
    let text: String
    var icon: String? = nil
    var on = false
    var tint: Color = Oat.ink
    var body: some View {
        HStack(spacing: 5) {
            if let icon { Image(systemName: icon).font(.system(size: 11, weight: .bold)) }
            Text(text).font(.round(13, .semibold))
        }
        .foregroundStyle(on ? Oat.card : Oat.ink2)
        .padding(.horizontal, 12).padding(.vertical, 8)
        .background(Capsule().fill(on ? tint : Oat.card))
        .overlay(Capsule().strokeBorder(on ? Color.clear : Oat.line2))
    }
}

struct Pill: View {
    let text: String
    var fg: Color = Oat.ink2
    var bg: Color = Oat.line
    var icon: String? = nil
    var body: some View {
        HStack(spacing: 4) {
            if let icon { Image(systemName: icon).font(.system(size: 9.5, weight: .heavy)) }
            Text(text).font(.round(11.5, .bold))
        }
        .foregroundStyle(fg).padding(.horizontal, 8).padding(.vertical, 4).background(Capsule().fill(bg))
    }
}

struct BigButton: View {
    let title: String
    var icon: String? = nil
    var tint: Color = Oat.accent
    var action: () -> Void
    var body: some View {
        Button(action: action) {
            HStack(spacing: 8) {
                if let icon { Image(systemName: icon).font(.system(size: 15, weight: .bold)) }
                Text(title).font(.round(16, .bold))
            }
            .foregroundStyle(.white).frame(maxWidth: .infinity).padding(.vertical, 16)
            .background(Capsule().fill(tint).shadow(color: tint.opacity(0.35), radius: 12, y: 6))
        }.pressable()
    }
}

struct SoftButton: View {
    let title: String
    var icon: String? = nil
    var action: () -> Void
    var body: some View {
        Button(action: action) {
            HStack(spacing: 6) {
                if let icon { Image(systemName: icon).font(.system(size: 12, weight: .bold)) }
                Text(title).font(.round(13.5, .bold))
            }
            .foregroundStyle(Oat.ink).padding(.horizontal, 14).padding(.vertical, 10)
            .background(Capsule().fill(Oat.card)).overlay(Capsule().strokeBorder(Oat.line2))
        }.pressable()
    }
}

struct SectionTitle: View {
    let title: String
    var trailing: String? = nil
    var action: (() -> Void)? = nil
    var body: some View {
        HStack(alignment: .firstTextBaseline) {
            Text(title).font(.display(21)).foregroundStyle(Oat.ink)
            Spacer()
            if let trailing, let action {
                Button(action: action) { Text(trailing).font(.round(13.5, .bold)).foregroundStyle(Oat.accent) }
            }
        }.padding(.top, 6)
    }
}

/// A thin capsule meter.
struct Meter: View {
    let fraction: Double
    var color: Color
    var height: CGFloat = 6
    var body: some View {
        GeometryReader { g in
            ZStack(alignment: .leading) {
                Capsule().fill(Oat.line)
                Capsule().fill(color).frame(width: max(height, g.size.width * min(1, max(0, fraction))))
            }
        }.frame(height: height)
    }
}

struct PersonDot: View {
    let person: Person?
    var size: CGFloat = 24
    var body: some View {
        Text(String((person?.name ?? "?").prefix(1)).uppercased())
            .font(.round(size * 0.46, .heavy)).foregroundStyle(.white)
            .frame(width: size, height: size)
            .background(Circle().fill(Oat.people[(person?.hue ?? 0) % Oat.people.count]))
    }
}

/// A field on the oat paper, used by every editor.
struct Field<Content: View>: View {
    let label: String
    @ViewBuilder var content: Content
    var body: some View {
        VStack(alignment: .leading, spacing: 7) {
            Eyebrow(label)
            content
                .font(.text(16))
                .padding(.horizontal, 14).padding(.vertical, 12)
                .background(RoundedRectangle(cornerRadius: 14, style: .continuous).fill(Oat.bg2.opacity(0.6)))
                .overlay(RoundedRectangle(cornerRadius: 14, style: .continuous).strokeBorder(Oat.line))
        }
    }
}

/// Paw prints that fly out of a tick, once per change of `trigger`.
struct PawBurst: View {
    var trigger: Int
    var color: Color
    @State private var p: CGFloat = 1
    var body: some View {
        ZStack {
            ForEach(0..<7, id: \.self) { i in
                let a = Double(i) / 7 * 2 * .pi - .pi / 2
                Image(systemName: "pawprint.fill").font(.system(size: 9, weight: .bold)).foregroundStyle(color)
                    .rotationEffect(.radians(a + .pi / 2))
                    .offset(x: cos(a) * (12 + 24 * p), y: sin(a) * (12 + 24 * p))
                    .scaleEffect(0.5 + 0.7 * p)
                    .opacity(p >= 1 ? 0 : Double(1 - p))
            }
        }
        .allowsHitTesting(false)
        .onChange(of: trigger) { _, _ in
            var t = Transaction(); t.disablesAnimations = true
            withTransaction(t) { p = 0 }
            DispatchQueue.main.async { withAnimation(.easeOut(duration: 0.75)) { p = 1 } }
        }
    }
}
