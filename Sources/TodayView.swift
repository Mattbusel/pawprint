import SwiftUI

struct TodayView: View {
    @Environment(Store.self) private var store
    @Environment(Router.self) private var router
    @State private var ask: Ask? = nil
    private let timer = Timer.publish(every: 30, on: .main, in: .common).autoconnect()

    struct Ask: Identifiable {
        let slot: Slot
        let title: String
        let message: String
        let undo: Bool
        var id: String { slot.key + (undo ? "u" : "g") }
    }

    var body: some View {
        let all = store.slots(on: store.today)
        let shown = all.filter { router.todayPet == nil || $0.dose.petID == router.todayPet }
        ScrollView(showsIndicators: false) {
            VStack(alignment: .leading, spacing: 20) {
                header(all)
                if store.db.pets.isEmpty { EmptyToday() } else {
                    PetStrip(slots: all)
                    HeadsUp()
                    Timeline(slots: shown) { tap($0) }
                }
            }
            .padding(.horizontal, 20).padding(.top, 8).padding(.bottom, 130)
        }
        .onReceive(timer) { _ in store.tick() }
        .alert(item: $ask) { a in
            Alert(title: Text(a.title), message: Text(a.message),
                  primaryButton: a.undo ? .destructive(Text("Undo")) { withAnimation(.spring) { store.ungive(a.slot) } } : .default(Text("Mark given")) { withAnimation(.spring(response: 0.4, dampingFraction: 0.6)) { store.give(a.slot, by: store.db.me) } },
                  secondaryButton: .cancel())
        }
    }

    func header(_ all: [Slot]) -> some View {
        let done = all.filter { store.given($0) != nil }.count
        let h = D.cal.component(.hour, from: store.now)
        let hello = h < 12 ? "Good morning" : h < 17 ? "Good afternoon" : "Good evening"
        return VStack(alignment: .leading, spacing: 14) {
            HStack(alignment: .top) {
                VStack(alignment: .leading, spacing: 4) {
                    Eyebrow(D.weekday(store.now))
                    Text(hello).font(.display(34)).foregroundStyle(Oat.ink)
                }
                Spacer()
                Button { router.sheet = .household } label: {
                    Image(systemName: "person.2.fill").font(.system(size: 14, weight: .bold)).foregroundStyle(Oat.ink2)
                        .frame(width: 42, height: 42).background(Circle().fill(Oat.card)).overlay(Circle().strokeBorder(Oat.line2))
                }.pressable()
            }
            if !all.isEmpty {
                DayMeter(slots: all)
                HStack(spacing: 6) {
                    Text("\(done) of \(all.count) done").font(.round(14, .bold)).foregroundStyle(Oat.ink)
                    Text("·").foregroundStyle(Oat.faint)
                    TickingAs()
                }
            }
        }
    }

    func tap(_ s: Slot) {
        let pet = store.pet(s.dose.petID)?.name ?? ""
        if let g = store.given(s) {
            let who = store.person(g.by)?.name ?? "Someone"
            ask = Ask(slot: s, title: "Undo this tick?", message: "\(who) marked \(pet)'s \(s.dose.name) as given at \(D.clock(g.at)).", undo: true)
            return
        }
        if s.dose.kind != .meal, let r = store.recent(s) {
            let g = r.0, other = r.1
            let who = store.person(g.by)?.name ?? "Someone"
            let ago = D.span(Int(store.now.timeIntervalSince(g.at) / 60))
            ask = Ask(slot: s, title: "\(pet) may have had this already", message: "\(who) gave \(s.dose.name) at \(D.clock(g.at)), \(ago) ago (the \(D.time(other.time)) dose). Give another one now?", undo: false)
            return
        }
        let early = Int(s.at.timeIntervalSince(store.now) / 60)
        if early > 120 {
            ask = Ask(slot: s, title: "Not due yet", message: "This dose is for \(D.time(s.time)), \(D.span(early)) from now. Mark it given anyway?", undo: false)
            return
        }
        withAnimation(.spring(response: 0.4, dampingFraction: 0.6)) { store.give(s, by: store.db.me) }
    }
}

/// Who is doing the ticking on this phone. Tap to change.
struct TickingAs: View {
    @Environment(Store.self) private var store
    var body: some View {
        Menu {
            ForEach(store.db.people) { p in
                Button { store.db.me = p.id; store.save() } label: { Label(p.name, systemImage: store.db.me == p.id ? "checkmark" : "person") }
            }
        } label: {
            HStack(spacing: 5) {
                Text("ticking as").font(.round(14, .medium)).foregroundStyle(Oat.dim)
                PersonDot(person: store.me, size: 20)
                Text(store.me?.name ?? "").font(.round(14, .bold)).foregroundStyle(Oat.ink)
                Image(systemName: "chevron.down").font(.system(size: 9, weight: .heavy)).foregroundStyle(Oat.dim)
            }
        }
    }
}

/// One segment per dose today: sage when given, berry when late, empty when still to come.
struct DayMeter: View {
    @Environment(Store.self) private var store
    let slots: [Slot]
    var body: some View {
        HStack(spacing: 4) {
            ForEach(slots) { s in
                Capsule().fill(color(s)).frame(height: 8)
            }
        }
        .animation(.spring(response: 0.4, dampingFraction: 0.7), value: store.db.given.count)
    }
    func color(_ s: Slot) -> Color {
        if store.given(s) != nil { return Oat.sage }
        if s.at < store.now.addingTimeInterval(-30 * 60) { return Oat.berry }
        return Oat.line2
    }
}

/// The pets across the top, each wearing a ring of today's progress.
struct PetStrip: View {
    @Environment(Store.self) private var store
    @Environment(Router.self) private var router
    let slots: [Slot]
    var body: some View {
        ViewThatFits(in: .horizontal) {
            HStack(spacing: 0) {
                ForEach(store.db.pets) { p in badge(p).frame(maxWidth: .infinity) }
            }
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 16) {
                    ForEach(store.db.pets) { p in badge(p) }
                }
                .padding(.horizontal, 20).padding(.vertical, 4)
            }
            .padding(.horizontal, -20)
        }
    }
    func badge(_ p: Pet) -> some View {
        let mine = slots.filter { $0.dose.petID == p.id }
        let done = mine.filter { store.given($0) != nil }.count
        let frac = mine.isEmpty ? 1 : Double(done) / Double(mine.count)
        let on = router.todayPet == p.id
        let left = mine.count - done
        return Button {
            withAnimation(.spring(response: 0.35, dampingFraction: 0.75)) { router.todayPet = on ? nil : p.id }
        } label: {
            VStack(spacing: 8) {
                ZStack {
                    Circle().stroke(Oat.line2, lineWidth: 4)
                    Circle().trim(from: 0, to: frac).stroke(left == 0 ? Oat.sage : Oat.accent, style: StrokeStyle(lineWidth: 4, lineCap: .round)).rotationEffect(.degrees(-90))
                    PetAvatar(pet: p, size: 70)
                    if left == 0 && !mine.isEmpty {
                        Image(systemName: "checkmark").font(.system(size: 11, weight: .heavy)).foregroundStyle(.white)
                            .frame(width: 24, height: 24).background(Circle().fill(Oat.sage)).overlay(Circle().strokeBorder(Oat.bg, lineWidth: 2.5))
                            .offset(x: 30, y: 28)
                    }
                }
                .frame(width: 82, height: 82)
                .scaleEffect(on ? 1.06 : 1)
                VStack(spacing: 1) {
                    Text(p.name).font(.round(14.5, .bold)).foregroundStyle(Oat.ink)
                    Text(mine.isEmpty ? "nothing today" : left == 0 ? "all done" : "\(left) to go").font(.round(12, .medium)).foregroundStyle(left == 0 ? Oat.sage : Oat.dim)
                }
            }
            .padding(.vertical, 8).padding(.horizontal, 6)
            .background(RoundedRectangle(cornerRadius: 22, style: .continuous).fill(on ? Oat.card : .clear))
            .overlay(RoundedRectangle(cornerRadius: 22, style: .continuous).strokeBorder(on ? Oat.accent.opacity(0.5) : .clear, lineWidth: 1.5))
            .animation(.spring(response: 0.4, dampingFraction: 0.7), value: frac)
        }
        .buttonStyle(.plain)
    }
}

/// Supplies running low, overdue vaccines and vet visits in the next few days.
struct HeadsUp: View {
    @Environment(Store.self) private var store
    @Environment(Router.self) private var router
    struct Item: Identifiable { let id: String; let icon: String; let tint: Color; let title: String; let sub: String; let go: () -> Void }
    var items: [Item] {
        var out: [Item] = []
        for d in store.db.doses { if let left = store.daysLeft(d), left <= 14, let p = store.pet(d.petID) {
            out.append(Item(id: "low\(d.id)", icon: "shippingbox.fill", tint: Oat.honey, title: "\(d.name) is running low", sub: "\(d.stock ?? 0) \(d.unit) left, about \(left) days for \(p.name)", go: { router.sheet = .dose(d, false) }))
        } }
        for v in store.vaxByUrgency where store.state(v) == .overdue { if let p = store.pet(v.petID) {
            out.append(Item(id: "vax\(v.id)", icon: "syringe.fill", tint: Oat.berry, title: "\(p.name)'s \(v.name) is overdue", sub: "Was due \(D.rel(store.daysTo(v)))", go: { router.tab = .vet }))
        } }
        for a in store.upcomingAppts where D.days(store.today, a.date) <= 10 { if let p = store.pet(a.petID) {
            out.append(Item(id: "ap\(a.id)", icon: "calendar", tint: Oat.sky, title: "\(p.name) at the vet \(D.rel(D.days(store.today, a.date)))", sub: "\(D.fmt(a.date, "EEEMMMd")), \(D.clock(a.date)) · \(a.what)", go: { router.tab = .vet }))
        } }
        return Array(out.prefix(3))
    }
    var body: some View {
        let list = items
        if !list.isEmpty {
            VStack(spacing: 0) {
                ForEach(Array(list.enumerated()), id: \.element.id) { i, it in
                    Button(action: it.go) {
                        HStack(spacing: 12) {
                            Image(systemName: it.icon).font(.system(size: 13, weight: .bold)).foregroundStyle(it.tint)
                                .frame(width: 34, height: 34).background(Circle().fill(it.tint.opacity(0.14)))
                            VStack(alignment: .leading, spacing: 2) {
                                Text(it.title).font(.round(14.5, .bold)).foregroundStyle(Oat.ink).lineLimit(1)
                                Text(it.sub).font(.round(12.5, .medium)).foregroundStyle(Oat.dim).lineLimit(1)
                            }
                            Spacer(minLength: 4)
                            Image(systemName: "chevron.right").font(.system(size: 11, weight: .heavy)).foregroundStyle(Oat.faint)
                        }
                        .padding(.vertical, 10).padding(.horizontal, 14)
                    }.buttonStyle(.plain)
                    if i < list.count - 1 { Rectangle().fill(Oat.line).frame(height: 1).padding(.leading, 60) }
                }
            }
            .card(4, radius: 22)
        }
    }
}

/// Doses grouped by time down a dotted line.
struct Timeline: View {
    @Environment(Store.self) private var store
    let slots: [Slot]
    var tap: (Slot) -> Void
    @State private var expanded = false
    var body: some View {
        let nowMin = D.cal.component(.hour, from: store.now) * 60 + D.cal.component(.minute, from: store.now)
        let all = Dictionary(grouping: slots, by: \.time).sorted { D.mins($0.key) < D.mins($1.key) }
        // Finished groups from more than 45 minutes ago fold into one line.
        let folded = all.prefix { g in D.mins(g.key) < nowMin - 45 && g.value.allSatisfy { store.given($0) != nil } }
        let groups = expanded ? all : Array(all.dropFirst(folded.count))
        let nextIdx = groups.firstIndex { D.mins($0.key) > nowMin }
        VStack(alignment: .leading, spacing: 0) {
            if !folded.isEmpty {
                DoneEarlier(slots: folded.flatMap(\.value), expanded: expanded) { withAnimation(.spring(response: 0.4, dampingFraction: 0.85)) { expanded.toggle() } }
                    .padding(.bottom, 18)
            }
            ForEach(Array(groups.enumerated()), id: \.element.key) { i, g in
                if i == nextIdx { NowMarker(time: store.now) }
                HStack(alignment: .top, spacing: 12) {
                    VStack(spacing: 6) {
                        Circle().fill(D.mins(g.key) <= nowMin ? Oat.ink : Oat.card).overlay(Circle().strokeBorder(Oat.ink, lineWidth: 2)).frame(width: 11, height: 11).padding(.top, 5)
                        if i < groups.count - 1 {
                            Rectangle().fill(Oat.line2).frame(width: 2).frame(maxHeight: .infinity)
                        }
                    }.frame(width: 14)
                    VStack(alignment: .leading, spacing: 10) {
                        Text(D.time(g.key)).font(.round(14, .heavy)).foregroundStyle(D.mins(g.key) <= nowMin ? Oat.ink : Oat.dim)
                        ForEach(g.value) { s in DoseRow(slot: s) { tap(s) } }
                    }
                    .padding(.bottom, 18)
                }
            }
            if slots.isEmpty {
                Text("Nothing scheduled for today.").font(.round(15, .medium)).foregroundStyle(Oat.dim).frame(maxWidth: .infinity).padding(.vertical, 30)
            }
        }
    }
}

struct NowMarker: View {
    let time: Date
    var body: some View {
        HStack(spacing: 8) {
            Text("NOW \(D.clock(time).uppercased())").font(.eyebrow(10)).tracking(1).foregroundStyle(.white)
                .padding(.horizontal, 8).padding(.vertical, 4).background(Capsule().fill(Oat.accent))
            Rectangle().fill(Oat.accent.opacity(0.5)).frame(height: 1.5)
        }
        .padding(.leading, -2).padding(.bottom, 14)
    }
}

struct DoseRow: View {
    @Environment(Store.self) private var store
    @Environment(Router.self) private var router
    let slot: Slot
    var tap: () -> Void
    @State private var bursts = 0
    var body: some View {
        let g = store.given(slot)
        let pet = store.pet(slot.dose.petID)
        let late = g == nil && slot.at < store.now.addingTimeInterval(-30 * 60)
        HStack(spacing: 12) {
            ZStack(alignment: .bottomTrailing) {
                if let pet { PetAvatar(pet: pet, size: 44) }
                Image(systemName: slot.dose.kind.icon).font(.system(size: 8.5, weight: .heavy)).foregroundStyle(.white)
                    .frame(width: 19, height: 19).background(Circle().fill(slot.dose.kind.color)).overlay(Circle().strokeBorder(Oat.card, lineWidth: 2))
                    .offset(x: 4, y: 3)
            }
            VStack(alignment: .leading, spacing: 3) {
                Text(slot.dose.name).font(.round(15.5, .bold)).foregroundStyle(g == nil ? Oat.ink : Oat.ink2).strikethrough(g != nil, color: Oat.faint).lineLimit(1)
                Text([pet?.name ?? "", slot.dose.amount].filter { !$0.isEmpty }.joined(separator: " · ")).font(.round(12.5, .medium)).foregroundStyle(Oat.dim).lineLimit(1)
                status(g, late)
            }
            Spacer(minLength: 4)
            TickButton(done: g != nil, late: late, trigger: bursts) {
                let was = g != nil
                tap()
                if !was { DispatchQueue.main.async { if store.given(slot) != nil { bursts += 1 } } }
            }
        }
        .padding(12)
        .background(RoundedRectangle(cornerRadius: 20, style: .continuous).fill(g != nil ? Oat.card.opacity(0.55) : Oat.card).shadow(color: Oat.ink.opacity(g != nil ? 0 : 0.05), radius: 10, y: 4))
        .overlay(RoundedRectangle(cornerRadius: 20, style: .continuous).strokeBorder(late ? Oat.berry.opacity(0.45) : Oat.line, lineWidth: late ? 1.5 : 1))
        .contextMenu {
            Button { router.sheet = .dose(slot.dose, false) } label: { Label("Edit \(slot.dose.name)", systemImage: "pencil") }
            if g == nil {
                ForEach(store.db.people) { p in
                    Button { withAnimation(.spring) { store.give(slot, by: p.id) } } label: { Label("Given by \(p.name)", systemImage: "checkmark.circle") }
                }
            }
        }
        .sensoryFeedback(.success, trigger: bursts)
    }

    @ViewBuilder func status(_ g: Given?, _ late: Bool) -> some View {
        if let g {
            HStack(spacing: 5) {
                PersonDot(person: store.person(g.by), size: 15)
                Text("\(store.person(g.by)?.name ?? "Given") · \(D.clock(g.at))").font(.round(12, .bold)).foregroundStyle(Oat.sage)
            }.padding(.top, 1)
        } else if late {
            Pill(text: "Late by \(D.span(Int(store.now.timeIntervalSince(slot.at) / 60)))", fg: Oat.berry, bg: Oat.berrySoft, icon: "exclamationmark").padding(.top, 1)
        } else if let left = store.daysLeft(slot.dose), left <= 14 {
            Pill(text: "\(slot.dose.stock ?? 0) left", fg: Oat.honey, bg: Oat.honeySoft, icon: "shippingbox.fill").padding(.top, 1)
        }
    }
}

/// The satisfying bit: a ring that fills sage and throws paw prints.
struct TickButton: View {
    let done: Bool
    let late: Bool
    let trigger: Int
    var action: () -> Void
    var body: some View {
        Button(action: action) {
            ZStack {
                PawBurst(trigger: trigger, color: Oat.sage)
                Circle().fill(done ? Oat.sage : Oat.bg2.opacity(0.7))
                Circle().strokeBorder(done ? .clear : (late ? Oat.berry.opacity(0.6) : Oat.line2), style: StrokeStyle(lineWidth: 2, dash: done ? [] : [4, 3.2]))
                Image(systemName: done ? "checkmark" : "pawprint.fill")
                    .font(.system(size: done ? 17 : 15, weight: .heavy))
                    .foregroundStyle(done ? .white : Oat.faint)
                    .contentTransition(.symbolEffect(.replace))
            }
            .frame(width: 46, height: 46)
            .scaleEffect(done ? 1 : 0.94)
            .animation(.spring(response: 0.35, dampingFraction: 0.5), value: done)
        }
        .buttonStyle(Squish())
    }
}

struct EmptyToday: View {
    @Environment(Router.self) private var router
    var body: some View {
        VStack(spacing: 16) {
            HStack(spacing: -14) {
                PetFace(species: .dog, coat: 0).frame(width: 96, height: 96).background(Circle().fill(Coat.of(0).bg))
                PetFace(species: .cat, coat: 1).frame(width: 96, height: 96).background(Circle().fill(Coat.of(1).bg))
                PetFace(species: .rabbit, coat: 2).frame(width: 96, height: 96).background(Circle().fill(Coat.of(2).bg))
            }
            Text("Who are we looking after?").font(.display(24)).foregroundStyle(Oat.ink)
            Text("Add your first pet, then their meals and medicines. Everyone in the house can tick doses here, and the phone can remind you.").font(.round(15, .medium)).foregroundStyle(Oat.ink2).multilineTextAlignment(.center)
            BigButton(title: "Add a pet", icon: "plus") { router.newPet() }.padding(.top, 6)
        }
        .padding(.top, 40)
    }
}

/// Everything finished earlier today, folded into one line of little faces.
struct DoneEarlier: View {
    @Environment(Store.self) private var store
    let slots: [Slot]
    let expanded: Bool
    var toggle: () -> Void
    var body: some View {
        Button(action: toggle) {
            HStack(spacing: 12) {
                Image(systemName: "checkmark").font(.system(size: 12, weight: .heavy)).foregroundStyle(.white)
                    .frame(width: 30, height: 30).background(Circle().fill(Oat.sage))
                VStack(alignment: .leading, spacing: 2) {
                    Text("\(slots.count) done earlier").font(.round(15, .bold)).foregroundStyle(Oat.ink)
                    Text(summary).font(.round(12.5, .medium)).foregroundStyle(Oat.dim).lineLimit(1)
                }
                Spacer(minLength: 4)
                HStack(spacing: -10) {
                    ForEach(Array(slots.prefix(5).enumerated()), id: \.offset) { _, s in
                        if let p = store.pet(s.dose.petID) { PetAvatar(pet: p, size: 28).overlay(Circle().strokeBorder(Oat.card, lineWidth: 2)) }
                    }
                }
                Image(systemName: expanded ? "chevron.up" : "chevron.down").font(.system(size: 11, weight: .heavy)).foregroundStyle(Oat.faint)
            }
            .card(12, radius: 20, fill: Oat.sageSoft.opacity(0.5))
        }.buttonStyle(.plain)
    }
    var summary: String {
        let names = slots.map(\.dose.name)
        var seen = Set<String>(); let uniq = names.filter { seen.insert($0).inserted }
        return uniq.joined(separator: ", ")
    }
}
