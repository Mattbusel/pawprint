import SwiftUI
import PhotosUI
import UserNotifications

/// Shared frame for every editor: title, close, save, and an optional delete at the bottom.
struct EditorShell<Content: View>: View {
    let title: String
    var canSave = true
    var save: () -> Void
    var delete: (() -> Void)? = nil
    @ViewBuilder var content: Content
    @Environment(\.dismiss) private var dismiss
    @State private var confirmDelete = false
    var body: some View {
        VStack(spacing: 0) {
            HStack {
                Button { dismiss() } label: {
                    Image(systemName: "xmark").font(.system(size: 14, weight: .heavy)).foregroundStyle(Oat.ink2)
                        .frame(width: 38, height: 38).background(Circle().fill(Oat.card)).overlay(Circle().strokeBorder(Oat.line2))
                }.pressable()
                Spacer()
                Button { save(); dismiss() } label: {
                    Text("Save").font(.round(15, .bold)).foregroundStyle(.white).padding(.horizontal, 20).padding(.vertical, 10)
                        .background(Capsule().fill(canSave ? Oat.accent : Oat.faint))
                }.disabled(!canSave).pressable()
            }
            .padding(.horizontal, 20).padding(.top, 20).padding(.bottom, 8)
            ScrollView(showsIndicators: false) {
                VStack(alignment: .leading, spacing: 18) {
                    Text(title).font(.display(30)).foregroundStyle(Oat.ink)
                    content
                    if let delete {
                        Button { confirmDelete = true } label: {
                            Text("Delete").font(.round(15, .bold)).foregroundStyle(Oat.berry).frame(maxWidth: .infinity).padding(.vertical, 14)
                                .background(Capsule().fill(Oat.berrySoft))
                        }
                        .pressable().padding(.top, 10)
                        .confirmationDialog("Delete this for good?", isPresented: $confirmDelete, titleVisibility: .visible) {
                            Button("Delete", role: .destructive) { delete(); dismiss() }
                        }
                    }
                }
                .padding(.horizontal, 20).padding(.bottom, 50)
            }
            .scrollDismissesKeyboard(.interactively)
        }
    }
}

/// Faces to choose which pet something is for.
struct PetPicker: View {
    @Environment(Store.self) private var store
    @Binding var selection: UUID
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Eyebrow("For")
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 8) {
                    ForEach(store.db.pets) { p in
                        let on = p.id == selection
                        Button { withAnimation(.spring(response: 0.3, dampingFraction: 0.75)) { selection = p.id } } label: {
                            HStack(spacing: 8) {
                                PetAvatar(pet: p, size: 32)
                                Text(p.name).font(.round(14.5, .bold)).foregroundStyle(on ? .white : Oat.ink)
                            }
                            .padding(.leading, 5).padding(.trailing, 14).padding(.vertical, 5)
                            .background(Capsule().fill(on ? Oat.ink : Oat.card)).overlay(Capsule().strokeBorder(on ? .clear : Oat.line2))
                        }.buttonStyle(.plain)
                    }
                }
            }
        }
    }
}

struct Toggler: View {
    let title: String
    let sub: String
    let icon: String
    @Binding var on: Bool
    var body: some View {
        Toggle(isOn: $on.animation(.spring(response: 0.3, dampingFraction: 0.8))) {
            HStack(spacing: 12) {
                Image(systemName: icon).font(.system(size: 15, weight: .bold)).foregroundStyle(on ? Oat.accent : Oat.dim)
                    .frame(width: 38, height: 38).background(Circle().fill(on ? Oat.accentSoft : Oat.line))
                    .symbolEffect(.bounce, value: on)
                VStack(alignment: .leading, spacing: 2) {
                    Text(title).font(.round(15.5, .bold)).foregroundStyle(Oat.ink)
                    Text(sub).font(.round(12.5, .medium)).foregroundStyle(Oat.dim).fixedSize(horizontal: false, vertical: true)
                }
            }
        }
        .tint(Oat.accent)
        .card(12, radius: 20)
    }
}

// MARK: - Dose

struct DoseEditor: View {
    @Environment(Store.self) private var store
    @State var dose: Dose
    let isNew: Bool
    @State private var denied = false
    @State private var hasEnd = false
    @State private var tracks = false
    init(dose: Dose, isNew: Bool) {
        _dose = State(initialValue: dose); self.isNew = isNew
        _hasEnd = State(initialValue: dose.end != nil); _tracks = State(initialValue: dose.stock != nil)
    }
    var body: some View {
        EditorShell(title: isNew ? "New dose or meal" : dose.name, canSave: !dose.name.trimmingCharacters(in: .whitespaces).isEmpty && !dose.times.isEmpty, save: commit,
                    delete: isNew ? nil : { store.delete(dose: dose.id) }) {
            PetPicker(selection: $dose.petID)
            VStack(alignment: .leading, spacing: 8) {
                Eyebrow("What")
                FlowChips(items: DoseKind.allCases.map { ($0.rawValue, $0.label, $0.icon) }, selected: dose.kind.rawValue, tint: dose.kind.color) { raw in
                    withAnimation(.spring(response: 0.3)) { dose.kind = DoseKind(rawValue: raw) ?? .med }
                }
            }
            Field(label: "Name") { TextField(dose.kind == .meal ? "Breakfast" : "Carprofen 75 mg", text: $dose.name).font(.round(19, .bold)) }
            HStack(spacing: 12) {
                Field(label: "How much") { TextField("1 tablet", text: $dose.amount) }
            }
            Field(label: "Tip for whoever gives it") { TextField("Hide it in a cube of cheese", text: $dose.note) }

            VStack(alignment: .leading, spacing: 12) {
                Eyebrow("When")
                FlowChips(items: Freq.allCases.map { ($0.rawValue, $0.label, nil) }, selected: dose.freq.rawValue, tint: Oat.ink) { raw in
                    withAnimation(.spring(response: 0.3)) { dose.freq = Freq(rawValue: raw) ?? .daily }
                }
                if dose.freq == .every {
                    Stepper(value: $dose.every, in: 2...60) { Text("Every \(dose.every) days").font(.round(15, .bold)).foregroundStyle(Oat.ink) }.card(12, radius: 16)
                }
                TimesEditor(times: $dose.times)
                HStack {
                    Text(dose.freq == .monthly ? "Day of the month" : dose.freq == .weekly ? "Starting on (sets the weekday)" : "Starting").font(.round(14, .semibold)).foregroundStyle(Oat.ink2)
                    Spacer()
                    DatePicker("", selection: $dose.start, displayedComponents: .date).labelsHidden()
                }.card(12, radius: 16)
                Toggle(isOn: $hasEnd.animation()) { Text("Course ends").font(.round(14, .semibold)).foregroundStyle(Oat.ink2) }.tint(Oat.accent).card(12, radius: 16)
                if hasEnd {
                    DatePicker("Last day", selection: Binding(get: { dose.end ?? D.add(7, dose.start) }, set: { dose.end = $0 }), in: dose.start..., displayedComponents: .date)
                        .font(.round(14, .semibold)).card(12, radius: 16)
                }
            }

            Toggler(title: "Remind me", sub: denied ? "Notifications are off for Pawprint. Turn them on in Settings > Pawprint." : "A notification at each time, with Given and Snooze buttons right on it.", icon: dose.remind ? "bell.fill" : "bell.slash.fill", on: Binding(get: { dose.remind }, set: { v in
                dose.remind = v
                if v && !store.demo { Reminders.shared.ask { ok in if !ok { denied = true; dose.remind = false } } }
            }))

            if dose.kind != .meal {
                Toggler(title: "Count what's left", sub: "Each tick takes one off, and you'll hear when it's time to refill.", icon: "shippingbox.fill", on: $tracks)
                if tracks {
                    HStack(spacing: 12) {
                        Field(label: "Left now") { TextField("30", value: Binding(get: { dose.stock ?? 30 }, set: { dose.stock = max(0, $0) }), format: .number).keyboardType(.numberPad) }
                        Field(label: "Called") { TextField("tablets", text: $dose.unit) }
                        Field(label: "Per dose") { Stepper("\(dose.perDose)", value: $dose.perDose, in: 1...10).font(.round(16, .bold)) }
                    }
                    if let left = store.daysLeft(Dose(petID: dose.petID, freq: dose.freq, every: dose.every, times: dose.times, stock: dose.stock ?? 30, perDose: dose.perDose)) {
                        HStack(spacing: 8) {
                            Image(systemName: "calendar").foregroundStyle(Oat.sage)
                            Text("Lasts about \(left) days, until \(D.long(D.add(left, store.today))).").font(.round(13.5, .semibold)).foregroundStyle(Oat.ink2)
                        }
                    }
                }
            }
            if !isNew {
                Toggle(isOn: $dose.paused) { Text("Paused for now").font(.round(14, .semibold)).foregroundStyle(Oat.ink2) }.tint(Oat.accent).card(12, radius: 16)
            }
        }
    }
    func commit() {
        var d = dose
        d.name = d.name.trimmingCharacters(in: .whitespaces)
        if !hasEnd { d.end = nil }
        if !tracks || d.kind == .meal { d.stock = nil } else if d.stock == nil { d.stock = 30 }
        d.times = Array(Set(d.times)).sorted { D.mins($0) < D.mins($1) }
        store.upsert(d)
    }
}

/// Wrapping row of selectable chips.
struct FlowChips: View {
    let items: [(String, String, String?)]
    let selected: String
    var tint: Color
    var pick: (String) -> Void
    var body: some View {
        FlowLayout(spacing: 7) {
            ForEach(items, id: \.0) { it in
                Button { pick(it.0) } label: { Chip(text: it.1, icon: it.2, on: it.0 == selected, tint: tint) }.buttonStyle(.plain)
            }
        }
    }
}

struct FlowLayout: Layout {
    var spacing: CGFloat = 8
    func sizeThatFits(proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) -> CGSize {
        let w = proposal.width ?? 360
        var x: CGFloat = 0, y: CGFloat = 0, row: CGFloat = 0
        for s in subviews {
            let z = s.sizeThatFits(.unspecified)
            if x + z.width > w && x > 0 { x = 0; y += row + spacing; row = 0 }
            x += z.width + spacing; row = max(row, z.height)
        }
        return CGSize(width: w, height: y + row)
    }
    func placeSubviews(in b: CGRect, proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) {
        var x = b.minX, y = b.minY, row: CGFloat = 0
        for s in subviews {
            let z = s.sizeThatFits(.unspecified)
            if x + z.width > b.maxX && x > b.minX { x = b.minX; y += row + spacing; row = 0 }
            s.place(at: CGPoint(x: x, y: y), proposal: ProposedViewSize(z))
            x += z.width + spacing; row = max(row, z.height)
        }
    }
}

struct TimesEditor: View {
    @Binding var times: [String]
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            ForEach(times.indices, id: \.self) { i in
                HStack {
                    Image(systemName: "clock.fill").font(.system(size: 13, weight: .bold)).foregroundStyle(Oat.accent)
                    DatePicker("", selection: Binding(get: { i < times.count ? D.at(times[i], on: Date()) : Date() }, set: { if i < times.count { times[i] = D.hhmm($0) } }), displayedComponents: .hourAndMinute).labelsHidden()
                    Spacer()
                    if times.count > 1 {
                        Button { withAnimation { _ = times.remove(at: i) } } label: { Image(systemName: "minus.circle.fill").font(.system(size: 20)).foregroundStyle(Oat.faint) }.buttonStyle(.plain)
                    }
                }
            }
            Button {
                withAnimation { times.append(times.count == 1 ? String(format: "%02d:00", min(23, D.mins(times[0]) / 60 + 12)) : "12:00") }
            } label: {
                Label("Add a time", systemImage: "plus").font(.round(14, .bold)).foregroundStyle(Oat.accent)
            }.buttonStyle(.plain)
        }
        .card(12, radius: 16)
    }
}

// MARK: - Pet

struct PetEditor: View {
    @Environment(Store.self) private var store
    @Environment(Router.self) private var router
    @State var pet: Pet
    let isNew: Bool
    @State private var photo: PhotosPickerItem? = nil
    @State private var picked: UIImage? = nil
    @State private var hasBirthday = false
    init(pet: Pet, isNew: Bool) { _pet = State(initialValue: pet); self.isNew = isNew; _hasBirthday = State(initialValue: pet.born != nil) }
    var body: some View {
        EditorShell(title: isNew ? "New pet" : "Edit \(pet.name)", canSave: !pet.name.trimmingCharacters(in: .whitespaces).isEmpty, save: commit,
                    delete: isNew ? nil : { router.petPath = []; store.delete(pet: pet.id) }) {
            HStack(spacing: 16) {
                ZStack {
                    if let picked { Image(uiImage: picked).resizable().scaledToFill().frame(width: 96, height: 96).clipShape(Circle()) }
                    else { PetAvatar(pet: pet, size: 96) }
                }
                .animation(.spring(response: 0.35, dampingFraction: 0.7), value: pet.species)
                .animation(.spring(response: 0.35, dampingFraction: 0.7), value: pet.coat)
                VStack(alignment: .leading, spacing: 8) {
                    PhotosPicker(selection: $photo, matching: .images) { Chip(text: pet.hasPhoto || picked != nil ? "Change photo" : "Add a photo", icon: "camera.fill") }
                    if picked == nil && !pet.hasPhoto {
                        HStack(spacing: 6) {
                            ForEach(0..<Coat.all.count, id: \.self) { i in
                                Button { pet.coat = i } label: {
                                    Circle().fill(Coat.of(i).fur).frame(width: 24, height: 24)
                                        .overlay(Circle().strokeBorder(pet.coat == i ? Oat.ink : Oat.line2, lineWidth: pet.coat == i ? 2.5 : 1))
                                }.buttonStyle(.plain)
                            }
                        }
                    }
                }
            }
            Field(label: "Name") { TextField("Biscuit", text: $pet.name).font(.round(19, .bold)) }
            VStack(alignment: .leading, spacing: 8) {
                Eyebrow("Kind")
                FlowChips(items: Species.allCases.map { ($0.rawValue, $0.label, nil) }, selected: pet.species.rawValue, tint: Oat.ink) { pet.species = Species(rawValue: $0) ?? .dog }
            }
            HStack(spacing: 12) {
                Field(label: "Breed") { TextField("Beagle mix", text: $pet.breed) }
                Field(label: "Sex") { TextField("Male, neutered", text: $pet.sex) }
            }
            Toggle(isOn: $hasBirthday.animation()) { Text("Birthday or adoption day").font(.round(14, .semibold)).foregroundStyle(Oat.ink2) }.tint(Oat.accent).card(12, radius: 16)
            if hasBirthday {
                DatePicker("Born", selection: Binding(get: { pet.born ?? D.add(-365, Date()) }, set: { pet.born = $0 }), in: ...Date(), displayedComponents: .date).font(.round(14, .semibold)).card(12, radius: 16)
            }
            HStack(spacing: 12) {
                Field(label: "Healthy weight from") { TextField("28", value: $pet.targetMin, format: .number).keyboardType(.decimalPad) }
                Field(label: "to (\(store.db.unit.rawValue))") { TextField("32", value: $pet.targetMax, format: .number).keyboardType(.decimalPad) }
            }
            Field(label: "Food") { TextField("1 cup senior food per meal", text: $pet.food, axis: .vertical).lineLimit(1...4) }
            Field(label: "Good to know (one per line)") { TextField("Scared of thunder", text: $pet.quirks, axis: .vertical).lineLimit(2...8) }
            Field(label: "Health and allergies") { TextField("Allergic to chicken", text: $pet.health, axis: .vertical).lineLimit(1...5) }
            Field(label: "Questions for the vet (one per line)") { TextField("Is the dose still right?", text: $pet.questions, axis: .vertical).lineLimit(1...5) }
            Field(label: "Microchip number") { TextField("985 112 004 771 203", text: $pet.chip).font(.system(size: 16, design: .monospaced)) }
        }
        .onChange(of: photo) { _, item in
            guard let item else { return }
            Task {
                if let data = try? await item.loadTransferable(type: Data.self), let img = UIImage(data: data) { picked = img }
            }
        }
    }
    func commit() {
        var p = pet
        p.name = p.name.trimmingCharacters(in: .whitespaces)
        if !hasBirthday { p.born = nil }
        if let picked { Photos.save(picked, p.id); p.hasPhoto = true }
        store.upsert(p)
        if isNew && store.db.sitter.petIDs.isEmpty == false { store.db.sitter.petIDs.append(p.id) }
        if isNew && store.db.sitter.petIDs.isEmpty { store.db.sitter.petIDs = store.db.pets.map(\.id) }
        store.save()
    }
}

// MARK: - Vaccine

struct VaccineEditor: View {
    @Environment(Store.self) private var store
    @State var vax: Vaccine
    let isNew: Bool
    init(vax: Vaccine, isNew: Bool) { _vax = State(initialValue: vax); self.isNew = isNew }
    var suggestions: [String] {
        switch store.pet(vax.petID)?.species ?? .dog {
        case .dog: return ["Rabies", "DHPP", "Bordetella", "Leptospirosis", "Lyme", "Canine flu"]
        case .cat: return ["Rabies", "FVRCP", "FeLV"]
        case .rabbit: return ["RHDV2", "Myxomatosis"]
        case .other: return ["Rabies"]
        }
    }
    var body: some View {
        EditorShell(title: isNew ? "Add a vaccine" : vax.name, canSave: !vax.name.isEmpty, save: { store.upsert(vax) }, delete: isNew ? nil : { store.delete(vaccine: vax.id) }) {
            PetPicker(selection: $vax.petID)
            Field(label: "Vaccine") { TextField("Rabies", text: $vax.name).font(.round(19, .bold)) }
            FlowLayout(spacing: 7) {
                ForEach(suggestions, id: \.self) { s in Button { vax.name = s } label: { Chip(text: s, on: vax.name == s) }.buttonStyle(.plain) }
            }
            HStack {
                Text("Given on").font(.round(14, .semibold)).foregroundStyle(Oat.ink2)
                Spacer()
                DatePicker("", selection: $vax.given, in: ...Date(), displayedComponents: .date).labelsHidden()
            }.card(12, radius: 16)
            if !isNew {
                Button { withAnimation(.spring) { vax.given = store.today } } label: { Chip(text: "Given today, start the clock again", icon: "arrow.clockwise", on: true, tint: Oat.sage) }.buttonStyle(.plain)
            }
            VStack(alignment: .leading, spacing: 8) {
                Eyebrow("Lasts")
                FlowChips(items: [("6", "6 months", nil), ("12", "1 year", nil), ("24", "2 years", nil), ("36", "3 years", nil)], selected: "\(vax.months)", tint: Oat.ink) { vax.months = Int($0) ?? 12 }
            }
            HStack(spacing: 10) {
                Image(systemName: "calendar.badge.clock").foregroundStyle(Oat.accent)
                Text("Next due \(D.long(store.due(vax))), \(D.rel(store.daysTo(vax))).").font(.round(14, .semibold)).foregroundStyle(Oat.ink2)
            }
            Field(label: "Clinic") { TextField("Maple Street Veterinary", text: $vax.clinic) }
        }
    }
}

// MARK: - Appointment

struct ApptEditor: View {
    @Environment(Store.self) private var store
    @State var appt: Appt
    let isNew: Bool
    init(appt: Appt, isNew: Bool) { _appt = State(initialValue: appt); self.isNew = isNew }
    var body: some View {
        EditorShell(title: isNew ? "Book a vet visit" : "Vet visit", canSave: !appt.what.isEmpty, save: { store.upsert(appt) }, delete: isNew ? nil : { store.delete(appt: appt.id) }) {
            PetPicker(selection: $appt.petID)
            Field(label: "What for") { TextField("Annual check-up", text: $appt.what).font(.round(18, .bold)) }
            DatePicker("When", selection: $appt.date).font(.round(14, .semibold)).card(12, radius: 16)
            Field(label: "Where") { TextField(store.db.vet.name.isEmpty ? "Clinic" : store.db.vet.name, text: $appt.place) }
            Toggler(title: "Remind me", sub: "The evening before at 6 pm, and 2 hours before.", icon: appt.remind ? "bell.fill" : "bell.slash.fill", on: Binding(get: { appt.remind }, set: { v in
                appt.remind = v
                if v && !store.demo { Reminders.shared.ask { ok in if !ok { appt.remind = false } } }
            }))
            if !isNew { Toggle(isOn: $appt.done) { Text("This visit has happened").font(.round(14, .semibold)).foregroundStyle(Oat.ink2) }.tint(Oat.sage).card(12, radius: 16) }
        }
    }
}

// MARK: - Weight

struct WeightEditor: View {
    @Environment(Store.self) private var store
    @State var w: Weigh
    let isNew: Bool
    @FocusState private var focus: Bool
    init(w: Weigh, isNew: Bool) { _w = State(initialValue: w); self.isNew = isNew }
    var body: some View {
        EditorShell(title: isNew ? "Log a weight" : "Weigh-in", canSave: w.value > 0, save: { store.upsert(w) }, delete: isNew ? nil : { store.delete(weight: w.id) }) {
            PetPicker(selection: $w.petID)
            HStack(alignment: .firstTextBaseline, spacing: 8) {
                TextField("0.0", value: $w.value, format: .number.precision(.fractionLength(0...2))).font(.num(64, .heavy)).foregroundStyle(Oat.ink)
                    .keyboardType(.decimalPad).focused($focus).fixedSize()
                Text(store.db.unit.rawValue).font(.round(22, .bold)).foregroundStyle(Oat.dim)
                Spacer()
            }
            .card(18, radius: 22)
            HStack(spacing: 10) {
                ForEach([-0.5, -0.1, 0.1, 0.5], id: \.self) { d in
                    Button { w.value = max(0, (w.value + d) * 10).rounded() / 10 } label: { Chip(text: String(format: "%+.1f", d)) }.buttonStyle(.plain)
                }
            }
            DatePicker("Date", selection: $w.date, in: ...Date(), displayedComponents: .date).font(.round(14, .semibold)).card(12, radius: 16)
            if let last = store.latest(w.petID), isNew {
                Text("Last time: \(store.wt(last.value)) on \(D.long(last.date)).").font(.round(13.5, .semibold)).foregroundStyle(Oat.dim)
            }
        }
    }
}

// MARK: - Note

struct NoteEditor: View {
    @Environment(Store.self) private var store
    @State var note: PetNote
    let isNew: Bool
    init(note: PetNote, isNew: Bool) { _note = State(initialValue: note); self.isNew = isNew }
    var body: some View {
        EditorShell(title: isNew ? "Write a note" : "Note", canSave: !note.text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty, save: { store.upsert(note) }, delete: isNew ? nil : { store.delete(note: note.id) }) {
            PetPicker(selection: $note.petID)
            VStack(alignment: .leading, spacing: 8) {
                Eyebrow("Kind")
                FlowChips(items: NoteTag.allCases.map { ($0.rawValue, $0.label, nil) }, selected: note.tag.rawValue, tint: note.tag.color) { note.tag = NoteTag(rawValue: $0) ?? .other }
            }
            Field(label: "What happened") { TextField("Slow getting up this morning, fine after a walk", text: $note.text, axis: .vertical).lineLimit(4...12) }
            DatePicker("Date", selection: $note.date, in: ...Date(), displayedComponents: .date).font(.round(14, .semibold)).card(12, radius: 16)
        }
    }
}

// MARK: - Household

struct HouseholdEditor: View {
    @Environment(Store.self) private var store
    @State private var db = DB()
    @State private var loaded = false
    @State private var status: UNAuthorizationStatus = .notDetermined
    var body: some View {
        EditorShell(title: "Household", save: { store.db.people = db.people; store.db.me = db.me; store.db.vet = db.vet; store.db.er = db.er; store.db.unit = db.unit; store.save() }) {
            VStack(alignment: .leading, spacing: 10) {
                Eyebrow("People who look after the pets")
                ForEach($db.people) { $p in
                    HStack(spacing: 10) {
                        Button { p.hue = (p.hue + 1) % Oat.people.count } label: { PersonDot(person: p, size: 34) }.buttonStyle(.plain)
                        TextField("Name", text: $p.name).font(.round(16, .bold))
                        TextField("Phone", text: $p.phone).font(.round(14)).keyboardType(.phonePad).frame(width: 130)
                        if db.people.count > 1 {
                            Button { db.people.removeAll { $0.id == p.id } } label: { Image(systemName: "minus.circle.fill").foregroundStyle(Oat.faint) }.buttonStyle(.plain)
                        }
                    }
                    .card(10, radius: 16)
                }
                Button { db.people.append(Person(name: "", hue: db.people.count % Oat.people.count)) } label: { Label("Add someone", systemImage: "plus").font(.round(14, .bold)).foregroundStyle(Oat.accent) }.buttonStyle(.plain)
                Text("Everyone ticks on this phone. Pick who is holding it on the Today screen, so the log shows who gave what.").font(.round(12.5, .medium)).foregroundStyle(Oat.dim)
            }
            VStack(alignment: .leading, spacing: 10) {
                Eyebrow("Your vet")
                ContactFields(c: $db.vet, placeholder: "Maple Street Veterinary")
                Eyebrow("Emergency vet, open 24 hours")
                ContactFields(c: $db.er, placeholder: "Northside Animal ER", who: false)
            }
            VStack(alignment: .leading, spacing: 8) {
                Eyebrow("Weigh in")
                FlowChips(items: [("lb", "Pounds", nil), ("kg", "Kilograms", nil)], selected: db.unit.rawValue, tint: Oat.ink) { db.unit = WUnit(rawValue: $0) ?? .lb }
            }
            HStack(spacing: 12) {
                Image(systemName: status == .authorized ? "bell.badge.fill" : "bell.slash.fill").foregroundStyle(status == .authorized ? Oat.sage : Oat.dim)
                Text(status == .authorized ? "Reminders are on for this phone." : status == .denied ? "Notifications are off. Turn them on in Settings to get dose reminders." : "Switch on Remind me on any dose to get notifications.")
                    .font(.round(13, .semibold)).foregroundStyle(Oat.ink2)
                Spacer(minLength: 0)
                if status == .denied, let url = URL(string: UIApplication.openSettingsURLString) {
                    Link("Settings", destination: url).font(.round(13, .bold))
                }
            }
            .card(12, radius: 16)
            Text("Pawprint keeps everything on this phone. No account, nothing uploaded.").font(.round(12, .medium)).foregroundStyle(Oat.dim)
        }
        .onAppear {
            if !loaded { db = store.db; loaded = true }
            Reminders.shared.status { status = $0 }
        }
    }
}

struct ContactFields: View {
    @Binding var c: Contact
    var placeholder: String
    var who = true
    var body: some View {
        VStack(spacing: 8) {
            TextField(placeholder, text: $c.name).font(.round(16, .bold))
            Divider()
            if who {
                TextField("Doctor", text: $c.who)
                Divider()
            }
            TextField("Phone", text: $c.phone).keyboardType(.phonePad)
            Divider()
            TextField("Address", text: $c.address)
        }
        .font(.round(14.5))
        .card(14, radius: 18)
    }
}
