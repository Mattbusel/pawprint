import SwiftUI

/// Hand-drawn pet faces for pets without a photo. Drawn in a 100 x 100 box.
struct PetFace: View {
    var species: Species
    var coat: Int
    var body: some View {
        Canvas { ctx, size in
            let k = min(size.width, size.height) / 100
            ctx.translateBy(x: (size.width - 100 * k) / 2, y: (size.height - 100 * k) / 2)
            ctx.scaleBy(x: k, y: k)
            let c = Coat.of(coat)
            switch species {
            case .dog: Face.dog(ctx, c)
            case .cat: Face.cat(ctx, c)
            case .rabbit: Face.rabbit(ctx, c)
            case .other: Face.critter(ctx, c)
            }
        }
    }
}

private enum Face {
    static func E(_ cx: CGFloat, _ cy: CGFloat, _ w: CGFloat, _ h: CGFloat) -> Path { Path(ellipseIn: CGRect(x: cx - w / 2, y: cy - h / 2, width: w, height: h)) }
    static func rot(_ p: Path, _ a: CGFloat, _ x: CGFloat, _ y: CGFloat) -> Path { p.applying(CGAffineTransform(rotationAngle: a).concatenating(CGAffineTransform(translationX: x, y: y))) }
    static let ink = Color(hex: 0x2E2019)

    static func eyes(_ ctx: GraphicsContext, _ c: Coat, y: CGFloat = 49, gap: CGFloat = 12, w: CGFloat = 7.5, h: CGFloat = 8.5) {
        for x in [50 - gap, 50 + gap] {
            ctx.fill(E(x, y, w, h), with: .color(c.eye))
            if c.eye != ink { ctx.fill(E(x, y, w * 0.38, h * 0.9), with: .color(ink)) }
            ctx.fill(E(x + w * 0.2, y - h * 0.2, w * 0.34, w * 0.34), with: .color(.white))
        }
    }
    static func cheeks(_ ctx: GraphicsContext, _ c: Coat, y: CGFloat = 61, gap: CGFloat = 17) {
        for x in [50 - gap, 50 + gap] { ctx.fill(E(x, y, 10, 5.5), with: .color(c.inner.opacity(0.45))) }
    }
    static func smile(_ ctx: GraphicsContext, top: CGFloat, drop: CGFloat = 4, width: CGFloat = 7, color: Color = ink) {
        var p = Path()
        p.move(to: CGPoint(x: 50, y: top)); p.addLine(to: CGPoint(x: 50, y: top + drop))
        p.move(to: CGPoint(x: 50, y: top + drop)); p.addQuadCurve(to: CGPoint(x: 50 - width, y: top + drop + 1), control: CGPoint(x: 50 - width * 0.5, y: top + drop + 4.5))
        p.move(to: CGPoint(x: 50, y: top + drop)); p.addQuadCurve(to: CGPoint(x: 50 + width, y: top + drop + 1), control: CGPoint(x: 50 + width * 0.5, y: top + drop + 4.5))
        ctx.stroke(p, with: .color(color), style: StrokeStyle(lineWidth: 1.7, lineCap: .round, lineJoin: .round))
    }

    static func dog(_ ctx: GraphicsContext, _ c: Coat) {
        let ear = E(0, 0, 25, 48)
        ctx.fill(rot(ear, 0.3, 24, 58), with: .color(c.dark))
        ctx.fill(rot(ear, -0.3, 76, 58), with: .color(c.dark))
        ctx.fill(E(50, 52, 60, 58), with: .color(c.fur))
        // White blaze down the forehead into the muzzle.
        var blaze = Path()
        blaze.move(to: CGPoint(x: 46, y: 26)); blaze.addQuadCurve(to: CGPoint(x: 54, y: 26), control: CGPoint(x: 50, y: 22))
        blaze.addLine(to: CGPoint(x: 57, y: 56)); blaze.addLine(to: CGPoint(x: 43, y: 56)); blaze.closeSubpath()
        ctx.fill(blaze, with: .color(c.light))
        ctx.fill(E(50, 67, 38, 27), with: .color(c.light))
        eyes(ctx, c, y: 47, gap: 13)
        cheeks(ctx, c, y: 62, gap: 20)
        ctx.fill(E(50, 60, 13, 9), with: .color(ink))
        ctx.fill(E(47.5, 58, 4, 2.2), with: .color(.white.opacity(0.6)))
        // A little tongue.
        var tongue = Path(); tongue.addRoundedRect(in: CGRect(x: 46.5, y: 69, width: 7, height: 7.5), cornerSize: CGSize(width: 3.5, height: 3.5))
        ctx.fill(tongue, with: .color(c.inner))
        smile(ctx, top: 64, drop: 4.5, width: 7.5)
    }

    static func cat(_ ctx: GraphicsContext, _ c: Coat) {
        for (s, x) in [(CGFloat(-1), CGFloat(50)), (CGFloat(1), CGFloat(50))] {
            var outer = Path()
            outer.move(to: CGPoint(x: x + s * 29, y: 44)); outer.addLine(to: CGPoint(x: x + s * 24, y: 12)); outer.addQuadCurve(to: CGPoint(x: x + s * 5, y: 30), control: CGPoint(x: x + s * 14, y: 18)); outer.closeSubpath()
            ctx.fill(outer, with: .color(c.fur))
            var inner = Path()
            inner.move(to: CGPoint(x: x + s * 24, y: 38)); inner.addLine(to: CGPoint(x: x + s * 22.5, y: 19)); inner.addQuadCurve(to: CGPoint(x: x + s * 11, y: 31), control: CGPoint(x: x + s * 16, y: 23)); inner.closeSubpath()
            ctx.fill(inner, with: .color(c.inner))
        }
        ctx.fill(E(50, 54, 66, 56), with: .color(c.fur))
        var stripes = Path()
        for (x0, x1) in [(50.0, 50.0), (44.0, 45.0), (56.0, 55.0)] { stripes.move(to: CGPoint(x: x0, y: 29)); stripes.addLine(to: CGPoint(x: x1, y: 37)) }
        ctx.stroke(stripes, with: .color(c.dark), style: StrokeStyle(lineWidth: 2.4, lineCap: .round))
        ctx.fill(E(44.5, 63, 14, 10), with: .color(c.light))
        ctx.fill(E(55.5, 63, 14, 10), with: .color(c.light))
        eyes(ctx, c, y: 50, gap: 13, w: 10, h: 10.5)
        cheeks(ctx, c, y: 60, gap: 22)
        var nose = Path()
        nose.move(to: CGPoint(x: 46.5, y: 57.5)); nose.addLine(to: CGPoint(x: 53.5, y: 57.5)); nose.addLine(to: CGPoint(x: 50, y: 61.5)); nose.closeSubpath()
        ctx.fill(nose, with: .color(c.inner))
        smile(ctx, top: 61.5, drop: 2, width: 5)
        var wh = Path()
        for (dy, ey) in [(CGFloat(-1.5), CGFloat(-5)), (CGFloat(1), CGFloat(1)), (CGFloat(3.5), CGFloat(7))] {
            wh.move(to: CGPoint(x: 38, y: 62 + dy)); wh.addLine(to: CGPoint(x: 17, y: 60 + ey))
            wh.move(to: CGPoint(x: 62, y: 62 + dy)); wh.addLine(to: CGPoint(x: 83, y: 60 + ey))
        }
        ctx.stroke(wh, with: .color(ink.opacity(0.35)), style: StrokeStyle(lineWidth: 0.9, lineCap: .round))
    }

    static func rabbit(_ ctx: GraphicsContext, _ c: Coat) {
        let ear = E(0, 0, 21, 54)
        ctx.fill(rot(ear, 0.2, 25, 62), with: .color(c.dark))
        ctx.fill(rot(ear, -0.2, 75, 62), with: .color(c.dark))
        ctx.fill(rot(E(0, 0, 11, 40), 0.2, 25.5, 64), with: .color(c.inner.opacity(0.55)))
        ctx.fill(rot(E(0, 0, 11, 40), -0.2, 74.5, 64), with: .color(c.inner.opacity(0.55)))
        ctx.fill(E(50, 29, 16, 10), with: .color(c.fur))
        ctx.fill(E(50, 53, 56, 54), with: .color(c.fur))
        ctx.fill(E(42, 64, 17, 13), with: .color(c.light))
        ctx.fill(E(58, 64, 17, 13), with: .color(c.light))
        eyes(ctx, c, y: 48, gap: 12.5, w: 8, h: 9)
        cheeks(ctx, c, y: 58, gap: 18)
        ctx.fill(E(50, 59.5, 7, 5), with: .color(c.inner))
        var y = Path()
        y.move(to: CGPoint(x: 50, y: 62)); y.addLine(to: CGPoint(x: 50, y: 65))
        y.move(to: CGPoint(x: 50, y: 65)); y.addQuadCurve(to: CGPoint(x: 46, y: 67), control: CGPoint(x: 48, y: 67.5))
        y.move(to: CGPoint(x: 50, y: 65)); y.addQuadCurve(to: CGPoint(x: 54, y: 67), control: CGPoint(x: 52, y: 67.5))
        ctx.stroke(y, with: .color(ink), style: StrokeStyle(lineWidth: 1.5, lineCap: .round))
        var teeth = Path(); teeth.addRoundedRect(in: CGRect(x: 47.6, y: 67.2, width: 4.8, height: 4.2), cornerSize: CGSize(width: 1, height: 1))
        ctx.fill(teeth, with: .color(.white))
        ctx.stroke(teeth, with: .color(ink.opacity(0.4)), lineWidth: 0.6)
    }

    static func critter(_ ctx: GraphicsContext, _ c: Coat) {
        for x in [CGFloat(30), CGFloat(70)] {
            ctx.fill(E(x, 31, 17, 17), with: .color(c.fur))
            ctx.fill(E(x, 31, 9, 9), with: .color(c.inner))
        }
        ctx.fill(E(50, 55, 64, 56), with: .color(c.fur))
        ctx.fill(E(50, 64, 34, 22), with: .color(c.light))
        eyes(ctx, c, y: 50, gap: 13)
        cheeks(ctx, c, y: 62, gap: 22)
        ctx.fill(E(50, 59, 8, 5.5), with: .color(c.inner))
        smile(ctx, top: 61.5, drop: 2.5, width: 5)
    }
}

/// Round portrait: the photo if there is one, otherwise the drawn face.
struct PetAvatar: View {
    let pet: Pet
    var size: CGFloat = 44
    var body: some View {
        ZStack {
            Coat.of(pet.coat).bg
            if pet.hasPhoto, let img = Photos.load(pet.id) {
                Image(uiImage: img).resizable().scaledToFill()
            } else {
                PetFace(species: pet.species, coat: pet.coat).frame(width: size * 0.96, height: size * 0.96).offset(y: size * 0.05)
            }
        }
        .frame(width: size, height: size).clipShape(Circle())
    }
}

/// The big picture at the top of a pet page and on the pet cards.
struct PetPortrait: View {
    let pet: Pet
    var faceSize: CGFloat = 250
    var body: some View {
        ZStack(alignment: .bottom) {
            Coat.of(pet.coat).bg
            if pet.hasPhoto, let img = Photos.load(pet.id) {
                Color.clear.overlay(Image(uiImage: img).resizable().scaledToFill()).clipped()
            } else {
                GeometryReader { g in
                    ZStack {
                        PawTrail(count: 6, color: Oat.ink.opacity(0.06)).frame(width: g.size.width, height: g.size.height * 0.8).offset(y: -g.size.height * 0.08)
                        Circle().fill(.white.opacity(0.35)).frame(width: faceSize * 1.25).position(x: g.size.width / 2, y: g.size.height - faceSize * 0.36)
                        PetFace(species: pet.species, coat: pet.coat).frame(width: faceSize, height: faceSize)
                            .position(x: g.size.width / 2, y: g.size.height - faceSize * 0.42)
                    }
                }
            }
        }
        .clipped()
    }
}
