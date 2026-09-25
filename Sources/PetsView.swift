import SwiftUI
import PhotosUI

struct PetsNav: View {
    @Environment(Store.self) private var store
    @Environment(Router.self) private var router
    var body: some View {
        @Bindable var router = router
        NavigationStack(path: $router.petPath) {
            PetsList()
                .navigationDestination(for: UUID.self) { id in PetDetail(id: id) }
                .toolbar(.hidden, for: .navigationBar)
        }
    }
}

struct PetsList: View {
    @Environment(Store.self) private var store
    @Environment(Router.self) private var router
    var body: some View {
        ZStack {
            OatBackground()
            ScrollView(showsIndicators: false) {
                VStack(alignment: .leading, spacing: 18) {
                    VStack(alignment: .leading, spacing: 4) {
                        Eyebrow("\(store.db.pets.count) in the family")
                        Text("Your pets").font(.display(34)).foregroundStyle(Oat.ink)
                    }
                    ForEach(store.db.pets) { p in
                        Button { router.petPath = [p.id] } label: { PetCard(pet: p) }.pressable()
                    }
                    Button { router.newPet() } label: {
                        HStack(spacing: 10) {
                            Image(systemName: "plus").font(.system(size: 15, weight: .heavy))
                            Text("Add a pet").font(.round(16, .bold))
                        }
                        .foregroundStyle(Oat.ink2).frame(maxWidth: .infinity).padding(.vertical, 26)
                        .background(RoundedRectangle(cornerRadius: 26, style: .continuous).strokeBorder(Oat.line2, style: StrokeStyle(lineWidth: 1.5, dash: [6, 5])))
                    }.pressable()
                }
                .padding(.horizontal, 20).padding(.top, 8).padding(.bottom, 130)
            }
        }
    }
}

struct PetCard: View {
    @Environment(Store.self) private var store
    let pet: Pet
    var body: some View {
        let today = store.slots(on: store.today, pet: pet.id)
        let done = today.filter { store.given($0) != nil }.count
        VStack(spacing: 0) {
            PetPortrait(pet: pet, faceSize: 170).frame(height: 190)
                .overlay(alignment: .topTrailing) {
                    if !today.isEmpty {
                        Pill(text: done == today.count ? "All done today" : "\(done) of \(today.count) today", fg: done == today.count ? .white : Oat.ink, bg: done == today.count ? Oat.sage : Oat.card.opacity(0.92), icon: done == today.count ? "checkmark" : "pawprint.fill").padding(14)
                    }
                }
            HStack(alignment: .center) {
                VStack(alignment: .leading, spacing: 3) {
                    Text(pet.name).font(.display(26)).foregroundStyle(Oat.ink)
                    Text([pet.breed.isEmpty ? pet.species.label : pet.breed, store.age(pet) ?? ""].filter { !$0.isEmpty }.joined(separator: " · ")).font(.round(13.5, .medium)).foregroundStyle(Oat.dim)
                }
                Spacer()
                if let w = store.latest(pet.id) {
                    VStack(alignment: .trailing, spacing: 2) {
                        Text(store.wt(w.value)).font(.num(17)).foregroundStyle(Oat.ink)
                        Eyebrow("weight")
                    }
                }
                Image(systemName: "chevron.right").font(.system(size: 13, weight: .heavy)).foregroundStyle(Oat.faint).padding(.leading, 8)
            }
            .padding(.horizontal, 18).padding(.vertical, 14)
        }
        .background(Oat.card)
        .clipShape(RoundedRectangle(cornerRadius: 26, style: .continuous))
        .overlay(RoundedRectangle(cornerRadius: 26, style: .continuous).strokeBorder(Oat.line))
        .shadow(color: Oat.ink.opacity(0.08), radius: 16, y: 8)
    }
}

struct PetDetail: View {
    @Environment(Store.self) private var store
    @Environment(Router.self) private var router
    @Environment(\.dismiss) private var dismiss
    let id: UUID
    @State private var photo: PhotosPickerItem? = nil
    var body: some View {
        if let pet = store.pet(id) {
            ZStack(alignment: .top) {
                OatBackground()
                ScrollView(showsIndicators: false) {
                    VStack(alignment: .leading, spacing: 0) {
                        hero(pet)
                        VStack(alignment: .leading, spacing: 18) {
                            VStack(alignment: .leading, spacing: 4) {
                                Text(pet.name).font(.display(42)).foregroundStyle(Oat.ink)
                                Text([pet.breed.isEmpty ? pet.species.label : pet.breed, pet.sex].filter { !$0.isEmpty }.joined(separator: " · "))
                                    .font(.round(15, .semibold)).foregroundStyle(Oat.ink2)
                            }
                            stats(pet)
                            care(pet)
                            if !pet.food.isEmpty { InfoCard(title: "Food", icon: "fork.knife", tint: Oat.honey, text: pet.food) }
                            if !pet.quirks.isEmpty { InfoCard(title: "Good to know", icon: "sparkles", tint: Color(hex: 0x8A5A8C), text: pet.quirks, bullets: true) }
                            if !pet.health.isEmpty { InfoCard(title: "Health", icon: "heart.fill", tint: Oat.berry, text: pet.health) }
                            if !pet.chip.isEmpty { InfoCard(title: "Microchip", icon: "wave.3.right", tint: Oat.sky, text: pet.chip, mono: true) }
                        }
                        .padding(.horizontal, 20).padding(.top, 18).padding(.bottom, 130)
                    }
                }
                .ignoresSafeArea(edges: .top)
                topBar(pet)
            }
            .toolbar(.hidden, for: .navigationBar)
            .onChange(of: photo) { _, item in
                guard let item else { return }
                Task {
                    if let data = try? await item.loadTransferable(type: Data.self), let img = UIImage(data: data) {
                        await MainActor.run {
                            Photos.save(img, pet.id)
                            var p = pet; p.hasPhoto = true; store.upsert(p)
                        }
                    }
                    photo = nil
                }
            }
        }
    }

    func hero(_ pet: Pet) -> some View {
        PetPortrait(pet: pet, faceSize: 280)
            .frame(height: 400)
            .clipShape(UnevenRoundedRectangle(bottomLeadingRadius: 40, bottomTrailingRadius: 40, style: .continuous))
            .overlay(alignment: .bottomTrailing) {
                PhotosPicker(selection: $photo, matching: .images) {
                    Image(systemName: "camera.fill").font(.system(size: 15, weight: .bold)).foregroundStyle(Oat.ink)
                        .frame(width: 44, height: 44).background(Circle().fill(Oat.card.opacity(0.95))).shadow(color: Oat.ink.opacity(0.15), radius: 8, y: 4)
                }
                .padding(.trailing, 22).padding(.bottom, 26)
            }
    }

    func topBar(_ pet: Pet) -> some View {
        HStack {
            Button { router.petPath = [] } label: { circleIcon("chevron.left") }.pressable()
            Spacer()
            Button { router.sheet = .pet(pet, false) } label: { circleIcon("pencil") }.pressable()
        }
        .padding(.horizontal, 18).padding(.top, 4)
    }

    func circleIcon(_ name: String) -> some View {
        Image(systemName: name).font(.system(size: 15, weight: .bold)).foregroundStyle(Oat.ink)
            .frame(width: 42, height: 42).background(Circle().fill(Oat.card.opacity(0.92))).shadow(color: Oat.ink.opacity(0.12), radius: 8, y: 3)
    }

    func stats(_ pet: Pet) -> some View {
        let today = store.slots(on: store.today, pet: pet.id)
        let done = today.filter { store.given($0) != nil }.count
        return HStack(spacing: 10) {
            StatTile(value: store.age(pet) ?? "?", label: "Age", tint: Oat.ink)
            if let w = store.latest(pet.id) {
                let ch = store.change(pet.id)
                StatTile(value: store.wt(w.value), label: ch.map { String(format: "%+.1f", $0) + " \(store.db.unit.rawValue) in 3 mo" } ?? "Weight", tint: Oat.ink)
            }
            StatTile(value: "\(done)/\(today.count)", label: "Done today", tint: done == today.count ? Oat.sage : Oat.accent)
        }
    }

    func care(_ pet: Pet) -> some View {
        let list = store.doses(for: pet.id)
        return VStack(alignment: .leading, spacing: 12) {
            SectionTitle(title: "Daily care", trailing: "Add", action: { router.newDose(store, pet: pet.id) })
            if list.isEmpty {
                Text("No meals or medicines yet.").font(.round(14.5, .medium)).foregroundStyle(Oat.dim)
            }
            VStack(spacing: 0) {
                ForEach(Array(list.enumerated()), id: \.element.id) { i, d in
                    Button { router.sheet = .dose(d, false) } label: { CareRow(dose: d) }.buttonStyle(.plain)
                    if i < list.count - 1 { Rectangle().fill(Oat.line).frame(height: 1).padding(.leading, 56) }
                }
            }
            .card(6, radius: 22)
            .opacity(list.isEmpty ? 0 : 1)
        }
    }
}

struct StatTile: View {
    let value: String
    let label: String
    var tint: Color
    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(value).font(.num(18)).foregroundStyle(tint).lineLimit(1).minimumScaleFactor(0.7)
            Text(label).font(.round(11.5, .semibold)).foregroundStyle(Oat.dim).lineLimit(1).minimumScaleFactor(0.8)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .card(14, radius: 20)
    }
}

struct CareRow: View {
    @Environment(Store.self) private var store
    let dose: Dose
    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: dose.kind.icon).font(.system(size: 14, weight: .bold)).foregroundStyle(dose.kind.color)
                .frame(width: 38, height: 38).background(Circle().fill(dose.kind.color.opacity(0.13)))
            VStack(alignment: .leading, spacing: 3) {
                HStack(spacing: 6) {
                    Text(dose.name).font(.round(15, .bold)).foregroundStyle(Oat.ink).lineLimit(1)
                    if dose.remind { Image(systemName: "bell.fill").font(.system(size: 10, weight: .bold)).foregroundStyle(Oat.accent) }
                }
                Text(store.scheduleText(dose)).font(.round(12.5, .medium)).foregroundStyle(Oat.dim).lineLimit(1)
                if let st = dose.stock, let left = store.daysLeft(dose) {
                    HStack(spacing: 8) {
                        Meter(fraction: min(1, Double(left) / 45), color: left <= 7 ? Oat.berry : left <= 14 ? Oat.honey : Oat.sage, height: 5).frame(width: 80)
                        Text("\(st) \(dose.unit) · \(left) days").font(.round(11.5, .bold)).foregroundStyle(left <= 14 ? Oat.honey : Oat.dim)
                    }.padding(.top, 2)
                }
            }
            Spacer(minLength: 0)
            Image(systemName: "chevron.right").font(.system(size: 11, weight: .heavy)).foregroundStyle(Oat.faint)
        }
        .padding(.horizontal, 10).padding(.vertical, 10)
        .contentShape(Rectangle())
    }
}

struct InfoCard: View {
    let title: String
    let icon: String
    let tint: Color
    let text: String
    var bullets = false
    var mono = false
    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(spacing: 8) {
                Image(systemName: icon).font(.system(size: 12, weight: .bold)).foregroundStyle(tint)
                    .frame(width: 26, height: 26).background(Circle().fill(tint.opacity(0.13)))
                Text(title).font(.round(15.5, .bold)).foregroundStyle(Oat.ink)
            }
            if bullets {
                VStack(alignment: .leading, spacing: 8) {
                    ForEach(text.split(separator: "\n").map(String.init), id: \.self) { line in
                        HStack(alignment: .firstTextBaseline, spacing: 9) {
                            Image(systemName: "pawprint.fill").font(.system(size: 9)).foregroundStyle(tint.opacity(0.7))
                            Text(line).font(.text(15)).foregroundStyle(Oat.ink2).fixedSize(horizontal: false, vertical: true)
                        }
                    }
                }
            } else {
                Text(text).font(mono ? .system(size: 16, weight: .semibold, design: .monospaced) : .text(15)).foregroundStyle(Oat.ink2).fixedSize(horizontal: false, vertical: true).textSelection(.enabled)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .card(16, radius: 22)
    }
}
