import Foundation
import Observation
import SwiftUI
import UIKit

// MARK: - Dates

enum D {
    static var cal: Calendar { Calendar.current }
    private static let keyF: DateFormatter = { let f = DateFormatter(); f.locale = Locale(identifier: "en_US_POSIX"); f.calendar = Calendar(identifier: .gregorian); f.timeZone = .current; f.dateFormat = "yyyy-MM-dd"; return f }()
    private static let timeF: DateFormatter = { let f = DateFormatter(); f.dateFormat = "h:mm a"; f.amSymbol = "am"; f.pmSymbol = "pm"; return f }()
    static func key(_ d: Date) -> String { keyF.string(from: d) }
    static func parse(_ k: String) -> Date? { keyF.date(from: k) }
    static func start(_ d: Date) -> Date { cal.startOfDay(for: d) }
    static func add(_ n: Int, _ d: Date) -> Date { cal.date(byAdding: .day, value: n, to: d) ?? d }
    static func days(_ a: Date, _ b: Date) -> Int { cal.dateComponents([.day], from: start(a), to: start(b)).day ?? 0 }
    static func mins(_ t: String) -> Int { let p = t.split(separator: ":"); return (Int(p.first ?? "0") ?? 0) * 60 + (Int(p.count > 1 ? p[1] : "0") ?? 0) }
    static func at(_ t: String, on day: Date) -> Date { start(day).addingTimeInterval(TimeInterval(mins(t) * 60)) }
    static func time(_ t: String) -> String { timeF.string(from: at(t, on: Date())) }
    static func clock(_ d: Date) -> String { timeF.string(from: d) }
    static func hhmm(_ d: Date) -> String { let c = cal.dateComponents([.hour, .minute], from: d); return String(format: "%02d:%02d", c.hour ?? 0, c.minute ?? 0) }
    static func fmt(_ d: Date, _ f: String) -> String { let x = DateFormatter(); x.setLocalizedDateFormatFromTemplate(f); return x.string(from: d) }
    static func short(_ d: Date) -> String { fmt(d, "MMMd") }
    static func long(_ d: Date) -> String { fmt(d, "MMMdyyyy") }
    static func weekday(_ d: Date) -> String { fmt(d, "EEEEMMMMd") }
    /// "in 12 days", "tomorrow", "5 days ago".
    static func rel(_ n: Int) -> String {
        switch n {
        case 0: return "today"
        case 1: return "tomorrow"
        case -1: return "yesterday"
        case 2...: return "in \(n) days"
        default: return "\(-n) days ago"
        }
    }
    static func span(_ minutes: Int) -> String {
        let m = abs(minutes)
        if m < 60 { return "\(m) min" }
        let h = m / 60, r = m % 60
        return r == 0 ? "\(h) h" : "\(h) h \(r) min"
    }
}

// MARK: - Model

enum Species: String, Codable, CaseIterable, Identifiable {
    case dog, cat, rabbit, other
    var id: String { rawValue }
    var label: String {
        switch self { case .dog: return "Dog"; case .cat: return "Cat"; case .rabbit: return "Rabbit"; case .other: return "Other" }
    }
}

enum DoseKind: String, Codable, CaseIterable, Identifiable {
    case meal, med, flea, heart, supp
    var id: String { rawValue }
    var label: String {
        switch self { case .meal: return "Meal"; case .med: return "Medicine"; case .flea: return "Flea & tick"; case .heart: return "Heartworm"; case .supp: return "Supplement" }
    }
    var noun: String {
        switch self { case .meal: return "meal"; case .med: return "medicine"; case .flea: return "flea and tick dose"; case .heart: return "heartworm dose"; case .supp: return "supplement" }
    }
    var icon: String {
        switch self { case .meal: return "fork.knife"; case .med: return "pills.fill"; case .flea: return "shield.lefthalf.filled"; case .heart: return "heart.fill"; case .supp: return "drop.fill" }
    }
    var color: Color {
        switch self { case .meal: return Oat.honey; case .med: return Oat.accent; case .flea: return Oat.sky; case .heart: return Oat.berry; case .supp: return Oat.sage }
    }
}

enum Freq: String, Codable, CaseIterable, Identifiable {
    case daily, every, weekly, monthly
    var id: String { rawValue }
    var label: String {
        switch self { case .daily: return "Every day"; case .every: return "Every few days"; case .weekly: return "Weekly"; case .monthly: return "Monthly" }
    }
}

enum NoteTag: String, Codable, CaseIterable, Identifiable {
    case symptom, vet, food, behavior, other
    var id: String { rawValue }
    var label: String { rawValue.capitalized }
    var color: Color {
        switch self { case .symptom: return Oat.berry; case .vet: return Oat.sky; case .food: return Oat.honey; case .behavior: return Color(hex: 0x8A5A8C); case .other: return Oat.dim }
    }
}

enum WUnit: String, Codable, CaseIterable { case lb, kg }

struct Person: Codable, Identifiable, Hashable {
    var id = UUID()
    var name: String
    var hue: Int = 0
    var phone: String = ""
}

struct Pet: Codable, Identifiable, Hashable {
    var id = UUID()
    var name: String
    var species: Species = .dog
    var breed = ""
    var born: Date? = nil
    var sex = ""
    var coat = 0
    var targetMin: Double? = nil
    var targetMax: Double? = nil
    var chip = ""
    var food = ""
    var quirks = ""
    var health = ""
    var questions = ""
    var hasPhoto = false
}

struct Dose: Codable, Identifiable, Hashable {
    var id = UUID()
    var petID: UUID
    var kind: DoseKind = .med
    var name = ""
    var amount = ""
    var note = ""
    var freq: Freq = .daily
    var every = 2
    var times: [String] = ["08:00"]
    var start: Date = D.start(Date())
    var end: Date? = nil
    var stock: Int? = nil
    var perDose = 1
    var unit = "tablets"
    var remind = false
    var paused = false
    var created: Date = Date()
}

struct Given: Codable, Hashable {
    var by: UUID?
    var at: Date
}

struct Vaccine: Codable, Identifiable, Hashable {
    var id = UUID()
    var petID: UUID
    var name: String
    var given: Date
    var months = 12
    var clinic = ""
}

struct Appt: Codable, Identifiable, Hashable {
    var id = UUID()
    var petID: UUID
    var date: Date
    var what = ""
    var place = ""
    var done = false
    var remind = true
}

struct Weigh: Codable, Identifiable, Hashable {
    var id = UUID()
    var petID: UUID
    var date: Date
    var value: Double
}

struct PetNote: Codable, Identifiable, Hashable {
    var id = UUID()
    var petID: UUID
    var date: Date
    var tag: NoteTag = .symptom
    var text = ""
}

struct Contact: Codable, Hashable {
    var name = ""
    var who = ""
    var phone = ""
    var address = ""
}

struct Sitter: Codable, Hashable {
    var name = ""
    var from: Date = D.add(7, D.start(Date()))
    var to: Date = D.add(10, D.start(Date()))
    var petIDs: [UUID] = []
    var extra = ""
}

struct DB: Codable {
    var people: [Person] = []
    var me: UUID? = nil
    var pets: [Pet] = []
    var doses: [Dose] = []
    var given: [String: Given] = [:]
    var vaccines: [Vaccine] = []
    var appts: [Appt] = []
    var weights: [Weigh] = []
    var notes: [PetNote] = []
    var vet = Contact()
    var er = Contact()
    var house = ""
    var sitter = Sitter()
    var unit: WUnit = .lb
}

/// One dose at one time on one day.
struct Slot: Identifiable, Hashable {
    let dose: Dose
    let time: String
    let day: Date
    var key: String { "\(dose.id.uuidString)|\(D.key(day))|\(time)" }
    var id: String { key }
    var at: Date { D.at(time, on: day) }
    var minutes: Int { D.mins(time) }
}

enum VaxState { case overdue, soon, ok }

// MARK: - Photos

enum Photos {
    private static var cache: [UUID: UIImage] = [:]
    static var dir: URL { let u = URL.documentsDirectory.appending(path: "photos"); try? FileManager.default.createDirectory(at: u, withIntermediateDirectories: true); return u }
    static func url(_ id: UUID) -> URL { dir.appending(path: "\(id.uuidString).jpg") }
    static func load(_ id: UUID) -> UIImage? {
        if let c = cache[id] { return c }
        guard let d = try? Data(contentsOf: url(id)), let i = UIImage(data: d) else { return nil }
        cache[id] = i; return i
    }
    static func save(_ img: UIImage, _ id: UUID) {
        let m: CGFloat = 1400, s = img.size, k = min(1, m / max(s.width, s.height))
        let size = CGSize(width: s.width * k, height: s.height * k)
        let out = UIGraphicsImageRenderer(size: size).image { _ in img.draw(in: CGRect(origin: .zero, size: size)) }
        if let d = out.jpegData(compressionQuality: 0.85) { try? d.write(to: url(id), options: .atomic) }
        cache[id] = out
    }
    static func remove(_ id: UUID) { cache[id] = nil; try? FileManager.default.removeItem(at: url(id)) }
}

// MARK: - Store

@Observable
final class Store {
    var db = DB()
    let demo: Bool
    var clock = Date()
    private let url = URL.documentsDirectory.appending(path: "pawprint.json")

    init(demo: Bool) {
        self.demo = demo
        if demo { Demo.fill(self); return }
        if let d = try? Data(contentsOf: url), let x = try? JSONDecoder().decode(DB.self, from: d) { db = x }
        else {
            let me = Person(name: "Me", hue: 0)
            db.people = [me]; db.me = me.id
        }
    }

    var now: Date { demo ? Demo.now : clock }
    var today: Date { D.start(now) }
    func tick() { if !demo { clock = Date() } }

    func save() {
        guard !demo else { return }
        if let d = try? JSONEncoder().encode(db) { try? d.write(to: url, options: .atomic) }
        Reminders.shared.reschedule(self)
    }

    // MARK: lookups
    func pet(_ id: UUID?) -> Pet? { db.pets.first { $0.id == id } }
    func person(_ id: UUID?) -> Person? { db.people.first { $0.id == id } }
    var me: Person? { person(db.me) ?? db.people.first }
    func petOrder(_ id: UUID) -> Int { db.pets.firstIndex { $0.id == id } ?? 99 }
    func doses(for pet: UUID) -> [Dose] { db.doses.filter { $0.petID == pet }.sorted { ($0.kind == .meal ? 1 : 0, D.mins($0.times.first ?? "00:00")) < ($1.kind == .meal ? 1 : 0, D.mins($1.times.first ?? "00:00")) } }

    // MARK: schedule
    func isDue(_ d: Dose, on day: Date) -> Bool {
        if d.paused || d.times.isEmpty { return false }
        let day0 = D.start(day), s = D.start(d.start)
        if day0 < s { return false }
        if let e = d.end, day0 > D.start(e) { return false }
        let n = D.days(s, day0)
        switch d.freq {
        case .daily: return true
        case .every: return n % max(1, d.every) == 0
        case .weekly: return n % 7 == 0
        case .monthly:
            let sd = D.cal.component(.day, from: s), dd = D.cal.component(.day, from: day0)
            let last = D.cal.range(of: .day, in: .month, for: day0)?.count ?? 28
            return dd == min(sd, last)
        }
    }

    func slots(on day: Date, pet: UUID? = nil) -> [Slot] {
        db.doses.filter { pet == nil || $0.petID == pet }.filter { isDue($0, on: day) }
            .flatMap { d in d.times.map { Slot(dose: d, time: $0, day: D.start(day)) } }
            .sorted { ($0.minutes, petOrder($0.dose.petID)) < ($1.minutes, petOrder($1.dose.petID)) }
    }

    func given(_ s: Slot) -> Given? { db.given[s.key] }

    func nextDate(_ d: Dose) -> Date? {
        for off in 0..<400 { let day = D.add(off, today); if isDue(d, on: day) { return day } }
        return nil
    }

    func scheduleText(_ d: Dose) -> String {
        let times = d.times.sorted { D.mins($0) < D.mins($1) }.map(D.time).joined(separator: ", ")
        switch d.freq {
        case .daily: return d.times.count == 2 ? "Twice a day · \(times)" : d.times.count > 2 ? "\(d.times.count) times a day · \(times)" : "Every day · \(times)"
        case .every: return "Every \(d.every) days · \(times)"
        case .weekly: return "Every \(D.fmt(d.start, "EEEE")) · \(times)"
        case .monthly:
            if let n = nextDate(d) { return "Monthly · next \(D.short(n))" }
            return "Monthly · \(times)"
        }
    }

    // MARK: ticking
    func give(_ s: Slot, by: UUID?, at: Date? = nil) {
        guard db.given[s.key] == nil else { return }
        db.given[s.key] = Given(by: by, at: at ?? now)
        if let i = db.doses.firstIndex(where: { $0.id == s.dose.id }), let st = db.doses[i].stock { db.doses[i].stock = max(0, st - db.doses[i].perDose) }
        save()
    }

    func ungive(_ s: Slot) {
        guard db.given[s.key] != nil else { return }
        db.given[s.key] = nil
        if let i = db.doses.firstIndex(where: { $0.id == s.dose.id }), let st = db.doses[i].stock { db.doses[i].stock = st + db.doses[i].perDose }
        save()
    }

    /// From a notification action: "doseID|yyyy-MM-dd|HH:mm".
    func give(key: String, by: UUID?) {
        let p = key.split(separator: "|").map(String.init)
        guard p.count == 3, let id = UUID(uuidString: p[0]), let day = D.parse(p[1]), let d = db.doses.first(where: { $0.id == id }) else { return }
        give(Slot(dose: d, time: p[2], day: day), by: by, at: Date())
    }

    /// Another tick of the same dose in the last few hours, for the double-dose warning.
    func recent(_ s: Slot, hours: Double = 6) -> (Given, Slot)? {
        let prefix = s.dose.id.uuidString + "|"
        var best: (Given, Slot)? = nil
        for (k, g) in db.given where k.hasPrefix(prefix) && k != s.key {
            guard now.timeIntervalSince(g.at) < hours * 3600, now.timeIntervalSince(g.at) > -600 else { continue }
            let p = k.split(separator: "|").map(String.init)
            guard p.count == 3, let day = D.parse(p[1]) else { continue }
            if best == nil || g.at > best!.0.at { best = (g, Slot(dose: s.dose, time: p[2], day: day)) }
        }
        return best
    }

    // MARK: supply
    func perDay(_ d: Dose) -> Double {
        let n = Double(d.perDose * max(1, d.times.count))
        switch d.freq { case .daily: return n; case .every: return n / Double(max(1, d.every)); case .weekly: return n / 7; case .monthly: return n / 30.44 }
    }
    func daysLeft(_ d: Dose) -> Int? {
        guard let st = d.stock, !d.paused else { return nil }
        let pd = perDay(d); guard pd > 0 else { return nil }
        return Int(Double(st) / pd)
    }
    func missed(_ d: Dose, days: Int = 30) -> Int {
        var n = 0
        for off in 0..<days {
            let day = D.add(-off, today)
            if day < D.start(d.created) { break }
            guard isDue(d, on: day) else { continue }
            for t in d.times { let s = Slot(dose: d, time: t, day: day); if s.at < now.addingTimeInterval(-3600), db.given[s.key] == nil { n += 1 } }
        }
        return n
    }

    // MARK: vaccines
    func due(_ v: Vaccine) -> Date { D.cal.date(byAdding: .month, value: v.months, to: v.given) ?? v.given }
    func daysTo(_ v: Vaccine) -> Int { D.days(today, due(v)) }
    func state(_ v: Vaccine) -> VaxState { let n = daysTo(v); return n < 0 ? .overdue : n <= 30 ? .soon : .ok }
    var vaxByUrgency: [Vaccine] { db.vaccines.sorted { daysTo($0) < daysTo($1) } }

    // MARK: weight
    func weights(_ pet: UUID) -> [Weigh] { db.weights.filter { $0.petID == pet }.sorted { $0.date < $1.date } }
    func latest(_ pet: UUID) -> Weigh? { weights(pet).last }
    func change(_ pet: UUID, days: Int = 90) -> Double? {
        let w = weights(pet); guard let last = w.last else { return nil }
        let cut = D.add(-days, last.date)
        guard let then = w.last(where: { $0.date <= cut }) ?? w.first, then.id != last.id else { return nil }
        return last.value - then.value
    }
    func wt(_ v: Double) -> String { String(format: v >= 100 ? "%.0f" : "%.1f", v) + " " + db.unit.rawValue }

    func age(_ p: Pet) -> String? {
        guard let b = p.born else { return nil }
        let c = D.cal.dateComponents([.year, .month], from: b, to: now)
        if let y = c.year, y >= 1 { return y == 1 ? "1 year" : "\(y) years" }
        let m = max(0, c.month ?? 0); return m == 1 ? "1 month" : "\(m) months"
    }

    func notes(_ pet: UUID?) -> [PetNote] { db.notes.filter { pet == nil || $0.petID == pet }.sorted { $0.date > $1.date } }
    var upcomingAppts: [Appt] { db.appts.filter { !$0.done && $0.date >= D.add(-1, today) }.sorted { $0.date < $1.date } }

    // MARK: editing
    func upsert(_ p: Pet) { if let i = db.pets.firstIndex(where: { $0.id == p.id }) { db.pets[i] = p } else { db.pets.append(p) }; save() }
    func upsert(_ d: Dose) { if let i = db.doses.firstIndex(where: { $0.id == d.id }) { db.doses[i] = d } else { db.doses.append(d) }; save() }
    func upsert(_ v: Vaccine) { if let i = db.vaccines.firstIndex(where: { $0.id == v.id }) { db.vaccines[i] = v } else { db.vaccines.append(v) }; save() }
    func upsert(_ a: Appt) { if let i = db.appts.firstIndex(where: { $0.id == a.id }) { db.appts[i] = a } else { db.appts.append(a) }; save() }
    func upsert(_ w: Weigh) { if let i = db.weights.firstIndex(where: { $0.id == w.id }) { db.weights[i] = w } else { db.weights.append(w) }; save() }
    func upsert(_ n: PetNote) { if let i = db.notes.firstIndex(where: { $0.id == n.id }) { db.notes[i] = n } else { db.notes.append(n) }; save() }
    func delete(pet id: UUID) {
        db.pets.removeAll { $0.id == id }; db.doses.removeAll { $0.petID == id }; db.vaccines.removeAll { $0.petID == id }
        db.appts.removeAll { $0.petID == id }; db.weights.removeAll { $0.petID == id }; db.notes.removeAll { $0.petID == id }
        db.sitter.petIDs.removeAll { $0 == id }; Photos.remove(id); save()
    }
    func delete(dose id: UUID) { db.doses.removeAll { $0.id == id }; db.given = db.given.filter { !$0.key.hasPrefix(id.uuidString) }; save() }
    func delete(vaccine id: UUID) { db.vaccines.removeAll { $0.id == id }; save() }
    func delete(appt id: UUID) { db.appts.removeAll { $0.id == id }; save() }
    func delete(weight id: UUID) { db.weights.removeAll { $0.id == id }; save() }
    func delete(note id: UUID) { db.notes.removeAll { $0.id == id }; save() }
}
