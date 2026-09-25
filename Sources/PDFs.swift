import SwiftUI
import Charts

/// Printable sheets, drawn as SwiftUI pages and written to a US Letter PDF.
enum PDFs {
    @MainActor
    static func write(_ name: String, _ pages: [AnyView]) -> URL? {
        let url = FileManager.default.temporaryDirectory.appending(path: name)
        var box = CGRect(x: 0, y: 0, width: 612, height: 792)
        guard let ctx = CGContext(url as CFURL, mediaBox: &box, nil) else { return nil }
        for p in pages {
            let r = ImageRenderer(content: p.frame(width: 612, height: 792).background(Color.white).environment(\.colorScheme, .light))
            r.proposedSize = ProposedViewSize(width: 612, height: 792)
            r.render { _, draw in ctx.beginPDFPage(nil); draw(ctx); ctx.endPDFPage() }
        }
        ctx.closePDF()
        return url
    }

    @MainActor
    static func sitterPages(_ s: Store) -> [AnyView] {
        let pets = s.db.pets.filter { s.db.sitter.petIDs.contains($0.id) }
        var pages: [AnyView] = [AnyView(SitterCover(s: s, pets: pets))]
        for p in pets { pages.append(AnyView(PetSheet(s: s, pet: p))) }
        let days = tripDays(s)
        var i = 0
        while i < days.count { pages.append(AnyView(TickSheet(s: s, pets: pets, days: Array(days[i..<min(days.count, i + 7)])))); i += 7 }
        return pages
    }

    static func tripDays(_ s: Store) -> [Date] {
        let a = D.start(s.db.sitter.from), b = D.start(max(s.db.sitter.to, s.db.sitter.from))
        let n = min(28, D.days(a, b))
        return (0...n).map { D.add($0, a) }
    }

    @MainActor
    static func sitter(_ s: Store) -> URL? {
        write("Sitter sheet\(s.db.sitter.name.isEmpty ? "" : " for \(s.db.sitter.name)").pdf", sitterPages(s))
    }

    @MainActor
    static func vetSummary(_ s: Store, _ p: Pet) -> URL? {
        write("\(p.name) vet visit summary.pdf", [AnyView(VetSheet(s: s, pet: p))])
    }
}

// MARK: - Page parts

private let pInk = Color(hex: 0x2E2019)
private let pDim = Color(hex: 0x2E2019, alpha: 0.55)
private let pLine = Color(hex: 0x2E2019, alpha: 0.14)
private let pAccent = Color(hex: 0xE2663B)

struct PaperPage<Content: View>: View {
    let kicker: String
    let title: String
    var sub: String = ""
    @ViewBuilder var content: Content
    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack(alignment: .firstTextBaseline) {
                Text(kicker.uppercased()).font(.system(size: 8.5, weight: .heavy, design: .rounded)).tracking(1.4).foregroundStyle(pAccent)
                Spacer()
                HStack(spacing: 4) {
                    Image(systemName: "pawprint.fill").font(.system(size: 8))
                    Text("Pawprint").font(.system(size: 8.5, weight: .bold, design: .rounded))
                }.foregroundStyle(pDim)
            }
            VStack(alignment: .leading, spacing: 3) {
                Text(title).font(.system(size: 26, weight: .bold, design: .serif)).foregroundStyle(pInk)
                if !sub.isEmpty { Text(sub).font(.system(size: 11, weight: .medium, design: .rounded)).foregroundStyle(pDim) }
            }
            Rectangle().fill(pInk).frame(height: 1.5)
            content
            Spacer(minLength: 0)
        }
        .padding(.horizontal, 44).padding(.vertical, 40)
        .frame(width: 612, height: 792, alignment: .topLeading)
        .background(Color.white)
    }
}

struct PBox<Content: View>: View {
    let title: String
    var tint: Color = pInk
    @ViewBuilder var content: Content
    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(title.uppercased()).font(.system(size: 8, weight: .heavy, design: .rounded)).tracking(1.2).foregroundStyle(tint)
            content
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(12)
        .background(RoundedRectangle(cornerRadius: 10).strokeBorder(tint == pInk ? pLine : tint.opacity(0.5), lineWidth: 1))
    }
}

struct PLine: View {
    let text: String
    var size: CGFloat = 10.5
    var weight: Font.Weight = .regular
    var color: Color = pInk
    var body: some View { Text(text).font(.system(size: size, weight: weight)).foregroundStyle(color).fixedSize(horizontal: false, vertical: true) }
}

// MARK: - Sitter pages

struct SitterCover: View {
    let s: Store
    let pets: [Pet]
    var body: some View {
        let st = s.db.sitter
        let names = pets.map(\.name)
        let who = names.count <= 1 ? (names.first ?? "the pets") : names.dropLast().joined(separator: ", ") + " & " + names.last!
        PaperPage(kicker: "Sitter sheet", title: "Looking after \(who)", sub: "\(D.fmt(st.from, "EEEMMMd")) to \(D.fmt(st.to, "EEEMMMd"))\(st.name.isEmpty ? "" : " · for \(st.name)")") {
            HStack(spacing: 14) {
                ForEach(pets) { p in
                    VStack(spacing: 4) {
                        PetAvatar(pet: p, size: 64)
                        Text(p.name).font(.system(size: 11, weight: .bold, design: .rounded)).foregroundStyle(pInk)
                    }
                }
            }
            HStack(alignment: .top, spacing: 12) {
                PBox(title: "Our vet") {
                    PLine(text: s.db.vet.name.isEmpty ? "Not set" : s.db.vet.name, size: 11.5, weight: .bold)
                    if !s.db.vet.who.isEmpty { PLine(text: s.db.vet.who) }
                    if !s.db.vet.phone.isEmpty { PLine(text: s.db.vet.phone, size: 13, weight: .heavy) }
                    if !s.db.vet.address.isEmpty { PLine(text: s.db.vet.address, color: pDim) }
                }
                PBox(title: "Emergency vet, 24 hours", tint: Color(hex: 0xC43E4A)) {
                    PLine(text: s.db.er.name.isEmpty ? "Not set" : s.db.er.name, size: 11.5, weight: .bold)
                    if !s.db.er.phone.isEmpty { PLine(text: s.db.er.phone, size: 13, weight: .heavy) }
                    if !s.db.er.address.isEmpty { PLine(text: s.db.er.address, color: pDim) }
                }
            }
            PBox(title: "Reach us") {
                ForEach(s.db.people) { p in
                    HStack {
                        PLine(text: p.name, size: 11, weight: .bold)
                        Spacer()
                        PLine(text: p.phone.isEmpty ? "" : p.phone, size: 11)
                    }
                }
            }
            if !s.db.house.isEmpty {
                PBox(title: "The house") {
                    ForEach(s.db.house.split(separator: "\n").map(String.init), id: \.self) { l in PLine(text: "•  " + l) }
                }
            }
            if !st.extra.isEmpty {
                PBox(title: "Please remember") { PLine(text: st.extra) }
            }
            PLine(text: "Each pet has its own page with food, medicines and quirks. The last page is a tick sheet: tick each dose when it's done.", size: 9.5, color: pDim)
        }
    }
}

struct PetSheet: View {
    let s: Store
    let pet: Pet
    var body: some View {
        let doses = s.doses(for: pet.id).filter { !$0.paused }
        PaperPage(kicker: "About \(pet.name)", title: pet.name, sub: [pet.breed.isEmpty ? pet.species.label : pet.breed, s.age(pet) ?? "", pet.sex].filter { !$0.isEmpty }.joined(separator: " · ")) {
            HStack(alignment: .top, spacing: 16) {
                PetAvatar(pet: pet, size: 96)
                VStack(alignment: .leading, spacing: 8) {
                    if !pet.food.isEmpty { PBox(title: "Food") { PLine(text: pet.food) } }
                    if !pet.chip.isEmpty { PLine(text: "Microchip  \(pet.chip)", size: 10, weight: .semibold, color: pDim) }
                }
            }
            PBox(title: "Meals and medicines") {
                ForEach(doses) { d in
                    HStack(alignment: .top, spacing: 10) {
                        PLine(text: d.times.sorted { D.mins($0) < D.mins($1) }.map(D.time).joined(separator: ", "), size: 10.5, weight: .heavy).frame(width: 96, alignment: .leading)
                        VStack(alignment: .leading, spacing: 1) {
                            PLine(text: d.name, size: 11, weight: .bold)
                            PLine(text: [d.amount, d.note].filter { !$0.isEmpty }.joined(separator: ". "), size: 10, color: pDim)
                        }
                        Spacer(minLength: 0)
                        PLine(text: d.freq == .daily ? "Every day" : s.scheduleText(d).components(separatedBy: " · ").first ?? "", size: 9.5, weight: .semibold, color: pAccent)
                    }
                    .padding(.vertical, 3)
                }
            }
            if !pet.quirks.isEmpty {
                PBox(title: "Good to know") {
                    ForEach(pet.quirks.split(separator: "\n").map(String.init), id: \.self) { l in PLine(text: "•  " + l) }
                }
            }
            if !pet.health.isEmpty { PBox(title: "Health", tint: Color(hex: 0xC43E4A)) { PLine(text: pet.health) } }
        }
    }
}

struct TickSheet: View {
    let s: Store
    let pets: [Pet]
    let days: [Date]
    var body: some View {
        let doses = pets.flatMap { s.doses(for: $0.id).filter { !$0.paused } }
        let rows: [(Dose, String)] = doses.flatMap { d in d.times.map { (d, $0) } }.sorted { D.mins($0.1) < D.mins($1.1) }
        PaperPage(kicker: "Tick sheet", title: "Tick it when it's done", sub: "\(D.fmt(days.first ?? Date(), "MMMd")) to \(D.fmt(days.last ?? Date(), "MMMd")). A grey box means that dose isn't due that day.") {
            VStack(spacing: 0) {
                HStack(spacing: 0) {
                    Text("").frame(width: 200, alignment: .leading)
                    ForEach(days, id: \.self) { d in
                        VStack(spacing: 0) {
                            Text(D.fmt(d, "EEE").uppercased()).font(.system(size: 7.5, weight: .heavy, design: .rounded)).foregroundStyle(pDim)
                            Text(D.fmt(d, "d")).font(.system(size: 12, weight: .bold, design: .rounded)).foregroundStyle(pInk)
                        }.frame(maxWidth: .infinity)
                    }
                }
                .padding(.bottom, 6)
                ForEach(Array(rows.prefix(24).enumerated()), id: \.offset) { i, r in
                    HStack(spacing: 0) {
                        VStack(alignment: .leading, spacing: 0) {
                            Text("\(D.time(r.1))  \(s.pet(r.0.petID)?.name ?? "")").font(.system(size: 8, weight: .heavy, design: .rounded)).foregroundStyle(pAccent)
                            Text(r.0.name).font(.system(size: 10, weight: .semibold)).foregroundStyle(pInk).lineLimit(1)
                        }
                        .frame(width: 200, alignment: .leading)
                        ForEach(days, id: \.self) { d in
                            let due = s.isDue(r.0, on: d)
                            RoundedRectangle(cornerRadius: 3).strokeBorder(due ? pInk.opacity(0.55) : .clear, lineWidth: 1)
                                .background(RoundedRectangle(cornerRadius: 3).fill(due ? Color.white : pLine))
                                .frame(width: 18, height: 18).frame(maxWidth: .infinity)
                        }
                    }
                    .padding(.vertical, 4)
                    .background(i % 2 == 0 ? pLine.opacity(0.35) : .clear)
                }
            }
        }
    }
}

// MARK: - Vet summary

struct VetSheet: View {
    let s: Store
    let pet: Pet
    var body: some View {
        let doses = s.doses(for: pet.id).filter { $0.kind != .meal && !$0.paused }
        let vax = s.db.vaccines.filter { $0.petID == pet.id }.sorted { s.daysTo($0) < s.daysTo($1) }
        let lastVisit = s.db.appts.filter { $0.petID == pet.id && $0.done }.map(\.date).max() ?? D.add(-180, s.today)
        let notes = s.notes(pet.id).filter { $0.date >= lastVisit }
        let ws = Array(s.weights(pet.id).suffix(8))
        PaperPage(kicker: "Vet visit summary", title: pet.name, sub: [pet.breed.isEmpty ? pet.species.label : pet.breed, s.age(pet) ?? "", pet.sex, "printed \(D.long(s.now))"].filter { !$0.isEmpty }.joined(separator: " · ")) {
            PBox(title: "Current medicines, last 30 days") {
                if doses.isEmpty { PLine(text: "None", color: pDim) }
                ForEach(doses) { d in
                    let m = s.missed(d)
                    HStack {
                        PLine(text: d.name, size: 11, weight: .bold)
                        PLine(text: "· \(d.amount) · \(s.scheduleText(d))", size: 10, color: pDim)
                        Spacer()
                        PLine(text: m == 0 ? "no missed doses" : "\(m) missed", size: 10, weight: .bold, color: m == 0 ? Color(hex: 0x4F8A62) : Color(hex: 0xC43E4A))
                    }
                }
            }
            HStack(alignment: .top, spacing: 12) {
                PBox(title: "Weight") {
                    if let l = ws.last {
                        PLine(text: s.wt(l.value), size: 18, weight: .heavy)
                        if let ch = s.change(pet.id) { PLine(text: String(format: "%+.1f %@ in 3 months", ch, s.db.unit.rawValue), size: 10, color: pDim) }
                        if let a = pet.targetMin, let b = pet.targetMax { PLine(text: "Target \(String(format: "%.1f", a))–\(String(format: "%.1f", b)) \(s.db.unit.rawValue)", size: 10, color: pDim) }
                        if ws.count > 1 {
                            Chart(ws) { w in
                                LineMark(x: .value("d", w.date), y: .value("w", w.value)).foregroundStyle(pAccent).interpolationMethod(.catmullRom)
                                PointMark(x: .value("d", w.date), y: .value("w", w.value)).foregroundStyle(pAccent).symbolSize(14)
                            }
                            .chartYScale(domain: (ws.map(\.value).min()! - 0.5)...(ws.map(\.value).max()! + 0.5))
                            .chartXAxis(.hidden)
                            .frame(height: 70)
                        }
                    } else { PLine(text: "No weigh-ins", color: pDim) }
                }
                PBox(title: "Vaccines") {
                    ForEach(vax) { v in
                        let n = s.daysTo(v)
                        HStack {
                            PLine(text: v.name, size: 10.5, weight: .bold)
                            Spacer()
                            PLine(text: n < 0 ? "overdue \(-n) d" : "due \(D.short(s.due(v)))", size: 10, weight: .semibold, color: n < 0 ? Color(hex: 0xC43E4A) : pDim)
                        }
                    }
                }
            }
            PBox(title: "Notes since the last visit") {
                if notes.isEmpty { PLine(text: "Nothing noted.", color: pDim) }
                ForEach(notes.prefix(9)) { n in
                    HStack(alignment: .top, spacing: 8) {
                        PLine(text: D.short(n.date), size: 10, weight: .bold).frame(width: 46, alignment: .leading)
                        PLine(text: "\(n.tag.label): \(n.text)", size: 10)
                    }
                }
            }
            PBox(title: "Our questions", tint: pAccent) {
                let qs = pet.questions.split(separator: "\n").map(String.init)
                if qs.isEmpty {
                    PLine(text: " ", size: 10)
                    PLine(text: " ", size: 10)
                }
                ForEach(qs, id: \.self) { q in PLine(text: "?  " + q, size: 11, weight: .semibold) }
            }
            if !pet.health.isEmpty { PBox(title: "Health history") { PLine(text: pet.health) } }
        }
    }
}
