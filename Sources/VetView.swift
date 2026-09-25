import SwiftUI

struct VetView: View {
    @Environment(Store.self) private var store
    @Environment(Router.self) private var router
    var body: some View {
        ScrollView(showsIndicators: false) {
            VStack(alignment: .leading, spacing: 20) {
                VStack(alignment: .leading, spacing: 4) {
                    Eyebrow("Vet & vaccines")
                    Text("Shots and visits").font(.display(34)).foregroundStyle(Oat.ink)
                }
                dueStrip
                appointments
                records
                contacts
            }
            .padding(.horizontal, 20).padding(.top, 8).padding(.bottom, 130)
        }
    }

    // MARK: due strip
    var dueStrip: some View {
        let urgent = store.vaxByUrgency.filter { store.state($0) != .ok }
        return Group {
            if urgent.isEmpty {
                HStack(spacing: 12) {
                    Image(systemName: "checkmark.seal.fill").font(.system(size: 22)).foregroundStyle(Oat.sage)
                    Text("Every vaccine is up to date.").font(.round(15.5, .bold)).foregroundStyle(Oat.ink)
                    Spacer()
                }.card(16, radius: 22)
            } else {
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 12) {
                        ForEach(urgent) { v in
                            Button { router.sheet = .vaccine(v, false) } label: { DueCard(vax: v) }.pressable()
                        }
                    }
                    .padding(.horizontal, 20).padding(.vertical, 6)
                }
                .padding(.horizontal, -20)
            }
        }
    }

    // MARK: appointments
    var appointments: some View {
        let list = store.upcomingAppts
        return VStack(alignment: .leading, spacing: 12) {
            SectionTitle(title: "Coming up", trailing: "Book", action: { router.newAppt(store) })
            if list.isEmpty {
                Text("No vet visits booked.").font(.round(14.5, .medium)).foregroundStyle(Oat.dim)
            } else {
                VStack(spacing: 10) {
                    ForEach(list) { a in
                        Button { router.sheet = .appt(a, false) } label: { ApptRow(appt: a) }.pressable()
                    }
                }
            }
        }
    }

    // MARK: records
    var records: some View {
        VStack(alignment: .leading, spacing: 12) {
            SectionTitle(title: "Vaccine records", trailing: "Add", action: { router.newVaccine(store) })
            ForEach(store.db.pets) { p in
                let vs = store.db.vaccines.filter { $0.petID == p.id }.sorted { store.daysTo($0) < store.daysTo($1) }
                if !vs.isEmpty {
                    VStack(alignment: .leading, spacing: 0) {
                        HStack(spacing: 10) {
                            PetAvatar(pet: p, size: 34)
                            Text(p.name).font(.round(16, .bold)).foregroundStyle(Oat.ink)
                            Spacer()
                            Text("\(vs.count) on record").font(.round(12, .semibold)).foregroundStyle(Oat.dim)
                        }
                        .padding(.bottom, 8)
                        ForEach(vs) { v in
                            Button { router.sheet = .vaccine(v, false) } label: { VaxRow(vax: v) }.buttonStyle(.plain)
                        }
                    }
                    .card(14, radius: 22)
                }
            }
        }
    }

    // MARK: contacts
    var contacts: some View {
        VStack(alignment: .leading, spacing: 12) {
            SectionTitle(title: "Who to call", trailing: "Edit", action: { router.sheet = .household })
            ContactCard(title: "Your vet", c: store.db.vet, tint: Oat.sky, icon: "stethoscope")
            ContactCard(title: "Emergency vet, open 24 hours", c: store.db.er, tint: Oat.berry, icon: "cross.fill")
        }
    }
}

struct DueCard: View {
    @Environment(Store.self) private var store
    let vax: Vaccine
    var body: some View {
        let n = store.daysTo(vax), over = n < 0
        let tint = over ? Oat.berry : Oat.honey
        VStack(alignment: .leading, spacing: 10) {
            HStack {
                if let p = store.pet(vax.petID) { PetAvatar(pet: p, size: 38) }
                Spacer()
                Pill(text: over ? "Overdue" : "Due soon", fg: .white, bg: tint)
            }
            VStack(alignment: .leading, spacing: 2) {
                Text(vax.name).font(.round(17, .heavy)).foregroundStyle(Oat.ink).lineLimit(1)
                Text(store.pet(vax.petID)?.name ?? "").font(.round(13, .semibold)).foregroundStyle(Oat.dim)
            }
            HStack(alignment: .firstTextBaseline, spacing: 4) {
                Text("\(abs(n))").font(.num(30, .heavy)).foregroundStyle(tint)
                Text(over ? "days late" : n == 1 ? "day to go" : "days to go").font(.round(12.5, .bold)).foregroundStyle(tint)
            }
        }
        .frame(width: 168, alignment: .leading)
        .card(14, radius: 24, fill: over ? Color(hex: 0xFFF3F2) : Color(hex: 0xFFF8EA))
    }
}

struct ApptRow: View {
    @Environment(Store.self) private var store
    let appt: Appt
    var body: some View {
        HStack(spacing: 14) {
            VStack(spacing: 0) {
                Text(D.fmt(appt.date, "MMM").uppercased()).font(.eyebrow(10.5)).foregroundStyle(.white).frame(maxWidth: .infinity).padding(.vertical, 3).background(Oat.accent)
                Text(D.fmt(appt.date, "d")).font(.num(24, .heavy)).foregroundStyle(Oat.ink).frame(maxHeight: .infinity)
            }
            .frame(width: 54, height: 60).background(Oat.card)
            .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
            .overlay(RoundedRectangle(cornerRadius: 14, style: .continuous).strokeBorder(Oat.line2))
            VStack(alignment: .leading, spacing: 3) {
                Text(appt.what).font(.round(15, .bold)).foregroundStyle(Oat.ink).lineLimit(2).multilineTextAlignment(.leading)
                HStack(spacing: 6) {
                    if let p = store.pet(appt.petID) {
                        PetAvatar(pet: p, size: 18)
                        Text(p.name).font(.round(12.5, .bold)).foregroundStyle(Oat.ink2)
                    }
                    Text("· \(D.fmt(appt.date, "EEE")), \(D.clock(appt.date))").font(.round(12.5, .medium)).foregroundStyle(Oat.dim)
                }
                Text(D.rel(D.days(store.today, appt.date)).capitalized).font(.round(11.5, .heavy)).foregroundStyle(Oat.accent)
            }
            Spacer(minLength: 0)
            if appt.remind { Image(systemName: "bell.fill").font(.system(size: 12, weight: .bold)).foregroundStyle(Oat.accent) }
        }
        .card(12, radius: 22)
    }
}

struct VaxRow: View {
    @Environment(Store.self) private var store
    let vax: Vaccine
    var body: some View {
        let n = store.daysTo(vax)
        let total = max(1, D.days(vax.given, store.due(vax)))
        let frac = Double(max(0, n)) / Double(total)
        let tint: Color = n < 0 ? Oat.berry : n <= 30 ? Oat.honey : Oat.sage
        VStack(alignment: .leading, spacing: 7) {
            HStack(alignment: .firstTextBaseline) {
                Text(vax.name).font(.round(15, .bold)).foregroundStyle(Oat.ink)
                Spacer()
                Text(n < 0 ? "\(-n) days overdue" : "due \(D.long(store.due(vax)))").font(.round(12.5, .bold)).foregroundStyle(n < 0 ? Oat.berry : n <= 30 ? Oat.honey : Oat.dim)
            }
            Meter(fraction: n < 0 ? 1 : frac, color: tint, height: 6)
            Text("Given \(D.long(vax.given)) · lasts \(vax.months % 12 == 0 ? "\(vax.months / 12) year\(vax.months == 12 ? "" : "s")" : "\(vax.months) months")").font(.round(11.5, .medium)).foregroundStyle(Oat.dim)
        }
        .padding(.vertical, 10)
        .overlay(alignment: .top) { Rectangle().fill(Oat.line).frame(height: 1) }
        .contentShape(Rectangle())
    }
}

struct ContactCard: View {
    let title: String
    let c: Contact
    let tint: Color
    let icon: String
    var body: some View {
        HStack(spacing: 14) {
            Image(systemName: icon).font(.system(size: 16, weight: .bold)).foregroundStyle(tint)
                .frame(width: 44, height: 44).background(Circle().fill(tint.opacity(0.13)))
            VStack(alignment: .leading, spacing: 2) {
                Eyebrow(title)
                Text(c.name.isEmpty ? "Not set yet" : c.name).font(.round(15.5, .bold)).foregroundStyle(c.name.isEmpty ? Oat.dim : Oat.ink).lineLimit(1)
                if !c.who.isEmpty || !c.address.isEmpty {
                    Text([c.who, c.address].filter { !$0.isEmpty }.joined(separator: " · ")).font(.round(12.5, .medium)).foregroundStyle(Oat.dim).lineLimit(1)
                }
            }
            Spacer(minLength: 0)
            if !c.phone.isEmpty, let url = URL(string: "tel:" + c.phone.filter { $0.isNumber || $0 == "+" }) {
                Link(destination: url) {
                    Image(systemName: "phone.fill").font(.system(size: 15, weight: .bold)).foregroundStyle(.white)
                        .frame(width: 42, height: 42).background(Circle().fill(tint))
                }
            }
        }
        .card(14, radius: 22)
    }
}
