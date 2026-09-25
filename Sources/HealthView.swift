import SwiftUI
import Charts

struct HealthView: View {
    @Environment(Store.self) private var store
    @Environment(Router.self) private var router
    @State private var tag: NoteTag? = nil
    @State private var share: URL? = nil
    var body: some View {
        let pid = router.healthPet ?? store.db.pets.first?.id
        ScrollView(showsIndicators: false) {
            VStack(alignment: .leading, spacing: 20) {
                VStack(alignment: .leading, spacing: 4) {
                    Eyebrow("Health")
                    Text("Weight & notes").font(.display(34)).foregroundStyle(Oat.ink)
                }
                picker(pid)
                if let pid, let pet = store.pet(pid) {
                    WeightCard(pet: pet)
                    notes(pet)
                    Button {
                        share = PDFs.vetSummary(store, pet)
                    } label: {
                        HStack(spacing: 12) {
                            Image(systemName: "doc.richtext.fill").font(.system(size: 18, weight: .bold)).foregroundStyle(Oat.sky)
                                .frame(width: 46, height: 46).background(Circle().fill(Oat.skySoft))
                            VStack(alignment: .leading, spacing: 2) {
                                Text("Vet visit summary").font(.round(16, .bold)).foregroundStyle(Oat.ink)
                                Text("One page for \(pet.name)'s next check-up: meds, missed doses, vaccines, weight, notes and your questions.").font(.round(12.5, .medium)).foregroundStyle(Oat.dim).multilineTextAlignment(.leading)
                            }
                            Spacer(minLength: 0)
                            Image(systemName: "square.and.arrow.up").font(.system(size: 15, weight: .bold)).foregroundStyle(Oat.accent)
                        }
                        .card(14, radius: 22)
                    }.pressable()
                }
            }
            .padding(.horizontal, 20).padding(.top, 8).padding(.bottom, 130)
        }
        .sheet(item: Binding(get: { share.map(ShareItem.init) }, set: { if $0 == nil { share = nil } })) { s in ActivitySheet(items: [s.url]).ignoresSafeArea() }
    }

    func picker(_ pid: UUID?) -> some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 8) {
                ForEach(store.db.pets) { p in
                    let on = p.id == pid
                    Button { withAnimation(.spring(response: 0.35, dampingFraction: 0.8)) { router.healthPet = p.id } } label: {
                        HStack(spacing: 8) {
                            PetAvatar(pet: p, size: 30)
                            Text(p.name).font(.round(14.5, .bold)).foregroundStyle(on ? .white : Oat.ink)
                        }
                        .padding(.leading, 5).padding(.trailing, 14).padding(.vertical, 5)
                        .background(Capsule().fill(on ? Oat.ink : Oat.card))
                        .overlay(Capsule().strokeBorder(on ? .clear : Oat.line2))
                    }.buttonStyle(.plain)
                }
            }
            .padding(.horizontal, 20)
        }
        .padding(.horizontal, -20)
    }

    func notes(_ pet: Pet) -> some View {
        let all = store.notes(pet.id)
        let list = all.filter { tag == nil || $0.tag == tag }
        return VStack(alignment: .leading, spacing: 12) {
            SectionTitle(title: "Notes", trailing: "Write", action: { router.newNote(store, pet: pet.id) })
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 7) {
                    Button { withAnimation { tag = nil } } label: { Chip(text: "All \(all.count)", on: tag == nil) }.buttonStyle(.plain)
                    ForEach(NoteTag.allCases) { t in
                        let n = all.filter { $0.tag == t }.count
                        if n > 0 { Button { withAnimation { tag = t } } label: { Chip(text: "\(t.label) \(n)", on: tag == t, tint: t.color) }.buttonStyle(.plain) }
                    }
                }
                .padding(.horizontal, 20)
            }
            .padding(.horizontal, -20)
            if list.isEmpty {
                Text("Symptoms, vet visits, food changes: anything you'll want to remember at the vet.").font(.round(14, .medium)).foregroundStyle(Oat.dim)
            }
            VStack(spacing: 10) {
                ForEach(list) { n in
                    Button { router.sheet = .note(n, false) } label: { NoteRow(note: n) }.buttonStyle(.plain)
                }
            }
        }
    }
}

struct WeightCard: View {
    @Environment(Store.self) private var store
    @Environment(Router.self) private var router
    let pet: Pet
    var body: some View {
        let ws = store.weights(pet.id)
        let unit = store.db.unit.rawValue
        VStack(alignment: .leading, spacing: 14) {
            HStack(alignment: .top) {
                VStack(alignment: .leading, spacing: 4) {
                    Eyebrow("\(pet.name) weighs")
                    if let w = ws.last {
                        HStack(alignment: .firstTextBaseline, spacing: 4) {
                            Text(String(format: "%.1f", w.value)).font(.num(42, .heavy)).foregroundStyle(Oat.ink)
                            Text(unit).font(.round(17, .bold)).foregroundStyle(Oat.dim)
                        }
                        Text("Weighed \(D.long(w.date))").font(.round(12.5, .medium)).foregroundStyle(Oat.dim)
                    } else {
                        Text("No weigh-ins yet").font(.display(24)).foregroundStyle(Oat.ink)
                    }
                }
                Spacer()
                Button { router.newWeight(store, pet: pet.id) } label: {
                    HStack(spacing: 6) {
                        Image(systemName: "plus").font(.system(size: 12, weight: .heavy))
                        Text("Weigh").font(.round(14, .bold))
                    }
                        .foregroundStyle(.white).padding(.horizontal, 14).padding(.vertical, 10).background(Capsule().fill(Oat.accent))
                }.pressable()
            }
            if let ch = store.change(pet.id) {
                HStack(spacing: 8) {
                    Pill(text: String(format: "%+.1f %@ in 3 months", ch, unit), fg: ch < 0 ? Oat.sky : Oat.honey, bg: ch < 0 ? Oat.skySoft : Oat.honeySoft, icon: ch < 0 ? "arrow.down.right" : "arrow.up.right")
                    if let lo = pet.targetMin, let hi = pet.targetMax, let w = ws.last {
                        let inside = w.value >= lo && w.value <= hi
                        Pill(text: inside ? "In the target range" : w.value < lo ? "Below target" : "Above target", fg: inside ? Oat.sage : Oat.berry, bg: inside ? Oat.sageSoft : Oat.berrySoft, icon: inside ? "checkmark" : "exclamationmark")
                    }
                }
            }
            if ws.count >= 2 { chart(ws) }
        }
        .card(18, radius: 26)
    }

    func chart(_ ws: [Weigh]) -> some View {
        let vals = ws.map(\.value) + [pet.targetMin, pet.targetMax].compactMap { $0 }
        let lo = (vals.min() ?? 0), hi = (vals.max() ?? 1)
        let pad = max(0.3, (hi - lo) * 0.18)
        let first = ws.first!.date, last = ws.last!.date
        return Chart {
            if let a = pet.targetMin, let b = pet.targetMax {
                RectangleMark(xStart: .value("From", first), xEnd: .value("To", last), yStart: .value("Low", a), yEnd: .value("High", b))
                    .foregroundStyle(Oat.sage.opacity(0.12))
            }
            ForEach(ws) { w in
                AreaMark(x: .value("Date", w.date), yStart: .value("Base", lo - pad), yEnd: .value("Weight", w.value))
                    .interpolationMethod(.catmullRom)
                    .foregroundStyle(LinearGradient(colors: [Oat.accent.opacity(0.22), Oat.accent.opacity(0)], startPoint: .top, endPoint: .bottom))
                LineMark(x: .value("Date", w.date), y: .value("Weight", w.value))
                    .interpolationMethod(.catmullRom)
                    .foregroundStyle(Oat.accent).lineStyle(StrokeStyle(lineWidth: 3, lineCap: .round))
            }
            if let l = ws.last {
                PointMark(x: .value("Date", l.date), y: .value("Weight", l.value))
                    .symbolSize(120).foregroundStyle(Oat.accent)
                PointMark(x: .value("Date", l.date), y: .value("Weight", l.value))
                    .symbolSize(36).foregroundStyle(.white)
            }
        }
        .chartYScale(domain: (lo - pad)...(hi + pad))
        .chartXAxis {
            AxisMarks(values: .stride(by: .month, count: max(1, D.cal.dateComponents([.month], from: first, to: last).month ?? 6) > 8 ? 3 : 2)) { _ in
                AxisValueLabel(format: .dateTime.month(.abbreviated)).font(.round(10.5, .semibold)).foregroundStyle(Oat.dim)
            }
        }
        .chartYAxis {
            AxisMarks(position: .trailing, values: .automatic(desiredCount: 4)) { _ in
                AxisGridLine(stroke: StrokeStyle(lineWidth: 0.6, dash: [3, 3])).foregroundStyle(Oat.line2)
                AxisValueLabel().font(.round(10.5, .semibold)).foregroundStyle(Oat.dim)
            }
        }
        .frame(height: 190)
    }
}

struct NoteRow: View {
    let note: PetNote
    var body: some View {
        HStack(alignment: .top, spacing: 12) {
            VStack(spacing: 0) {
                Text(D.fmt(note.date, "d")).font(.num(19, .heavy)).foregroundStyle(Oat.ink)
                Text(D.fmt(note.date, "MMM").uppercased()).font(.eyebrow(9.5)).foregroundStyle(Oat.dim)
            }
            .frame(width: 40)
            VStack(alignment: .leading, spacing: 6) {
                Pill(text: note.tag.label, fg: note.tag.color, bg: note.tag.color.opacity(0.12))
                Text(note.text).font(.text(14.5)).foregroundStyle(Oat.ink2).multilineTextAlignment(.leading).fixedSize(horizontal: false, vertical: true)
            }
            Spacer(minLength: 0)
        }
        .card(14, radius: 20)
    }
}

struct ShareItem: Identifiable { let url: URL; var id: String { url.absoluteString } }

struct ActivitySheet: UIViewControllerRepresentable {
    let items: [Any]
    func makeUIViewController(context: Context) -> UIActivityViewController { UIActivityViewController(activityItems: items, applicationActivities: nil) }
    func updateUIViewController(_ vc: UIActivityViewController, context: Context) {}
}
