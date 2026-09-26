import SwiftUI
import UIKit

final class AppDelegate: NSObject, UIApplicationDelegate {
    func application(_ application: UIApplication, didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]? = nil) -> Bool {
        Reminders.shared.setUp()
        return true
    }
}

@main
struct PawprintApp: App {
    @UIApplicationDelegateAdaptor(AppDelegate.self) private var delegate
    @State private var store: Store
    @State private var router: Router
    @State private var pro: Pro
    @Environment(\.scenePhase) private var phase
    init() {
        let a = ProcessInfo.processInfo.arguments
        let s = Store(demo: a.contains("-shot") || a.contains("-demoAutoplay"))
        _store = State(initialValue: s)
        // Screenshots and the review recording never touch StoreKit; `-shot paywall` shows the real, locked paywall.
        let shot = a.firstIndex(of: "-shot").flatMap { $0 + 1 < a.count ? a[$0 + 1] : nil }
        let p: Pro
        if shot == "paywall" { p = Pro(forced: false); p.paywall = .pets }
        else if shot != nil || a.contains("-demoAutoplay") { p = Pro(forced: true) }
        else { p = Pro() }
        _pro = State(initialValue: p)
        _router = State(initialValue: Router(pro: p))
        Reminders.shared.attach(s)
    }
    var body: some Scene {
        WindowGroup {
            RootView().environment(store).environment(router).environment(pro).preferredColorScheme(.light).tint(Oat.accent)
                .onAppear { router.applyShotArgs(store); Autopilot.shared.run(store, router, pro) }
        }
        .onChange(of: phase) { _, p in
            if p == .active { store.tick(); Reminders.shared.reschedule(store) }
        }
    }
}

enum Tab: String, CaseIterable, Identifiable {
    case today, pets, vet, health, sitter
    var id: String { rawValue }
    var title: String { rawValue == "vet" ? "Vet" : rawValue.capitalized }
    var icon: String {
        switch self {
        case .today: return "sun.max.fill"
        case .pets: return "pawprint.fill"
        case .vet: return "cross.case.fill"
        case .health: return "heart.text.square.fill"
        case .sitter: return "house.fill"
        }
    }
}

enum Sheet: Identifiable {
    case dose(Dose, Bool), pet(Pet, Bool), vaccine(Vaccine, Bool), appt(Appt, Bool), weight(Weigh, Bool), note(PetNote, Bool), household, add
    var id: String {
        switch self {
        case .dose(let d, _): return "dose-\(d.id)"
        case .pet(let p, _): return "pet-\(p.id)"
        case .vaccine(let v, _): return "vax-\(v.id)"
        case .appt(let a, _): return "appt-\(a.id)"
        case .weight(let w, _): return "w-\(w.id)"
        case .note(let n, _): return "n-\(n.id)"
        case .household: return "household"
        case .add: return "add"
        }
    }
}

@Observable
final class Router {
    var tab: Tab = .today
    var petPath: [UUID] = []
    var sheet: Sheet? = nil
    var healthPet: UUID? = nil
    var todayPet: UUID? = nil
    let pro: Pro
    init(pro: Pro) { self.pro = pro }

    func applyShotArgs(_ s: Store) {
        let a = ProcessInfo.processInfo.arguments
        guard let i = a.firstIndex(of: "-shot"), i + 1 < a.count, let first = s.db.pets.first else { return }
        switch a[i + 1] {
        case "pet": tab = .pets; petPath = [first.id]
        case "vet": tab = .vet
        case "weight": tab = .health; healthPet = first.id
        case "sitter": tab = .sitter
        case "add":
            var d = Dose(petID: first.id, kind: .med, name: "Gabapentin 100 mg", amount: "1 capsule in a pill pocket", note: "Can make him sleepy", freq: .daily, times: ["08:00", "20:00"], start: s.today, stock: 60, perDose: 1, unit: "capsules", remind: true)
            d.created = s.now
            sheet = .dose(d, true)
        default: break
        }
    }

    // New things, with sensible defaults for the pet on screen.
    func newDose(_ s: Store, pet: UUID? = nil) { if let p = pet ?? todayPet ?? s.db.pets.first?.id { sheet = .dose(Dose(petID: p, start: s.today), true) } else { sheet = .pet(Pet(name: ""), true) } }
    /// The first pet is free; more need Pro.
    @MainActor func newPet(_ s: Store) {
        guard pro.canAddPet(s) else { sheet = nil; pro.paywall = .pets; return }
        sheet = .pet(Pet(name: "", coat: Int.random(in: 0..<Coat.all.count)), true) }
    func newVaccine(_ s: Store, pet: UUID? = nil) { if let p = pet ?? s.db.pets.first?.id { sheet = .vaccine(Vaccine(petID: p, name: "", given: s.today), true) } }
    func newAppt(_ s: Store, pet: UUID? = nil) { if let p = pet ?? s.db.pets.first?.id { sheet = .appt(Appt(petID: p, date: D.add(7, s.today).addingTimeInterval(10 * 3600)), true) } }
    func newWeight(_ s: Store, pet: UUID? = nil) { if let p = pet ?? healthPet ?? s.db.pets.first?.id { sheet = .weight(Weigh(petID: p, date: s.now, value: s.latest(p)?.value ?? 0), true) } }
    func newNote(_ s: Store, pet: UUID? = nil) { if let p = pet ?? healthPet ?? s.db.pets.first?.id { sheet = .note(PetNote(petID: p, date: s.now), true) } }
}

struct RootView: View {
    @Environment(Store.self) private var store
    @Environment(Router.self) private var router
    @Environment(Pro.self) private var pro
    var body: some View {
        @Bindable var router = router
        @Bindable var pro = pro
        ZStack(alignment: .bottom) {
            OatBackground()
            Group {
                switch router.tab {
                case .today: TodayView()
                case .pets: PetsNav()
                case .vet: VetView()
                case .health: HealthView()
                case .sitter: SitterView()
                }
            }
            .transition(.opacity)
            Collar(selection: $router.tab) { router.sheet = .add }
        }
        .sheet(item: $router.sheet) { sheet in
            Group {
                switch sheet {
                case .dose(let d, let new): DoseEditor(dose: d, isNew: new)
                case .pet(let p, let new): PetEditor(pet: p, isNew: new)
                case .vaccine(let v, let new): VaccineEditor(vax: v, isNew: new)
                case .appt(let a, let new): ApptEditor(appt: a, isNew: new)
                case .weight(let w, let new): WeightEditor(w: w, isNew: new)
                case .note(let n, let new): NoteEditor(note: n, isNew: new)
                case .household: HouseholdEditor()
                case .add: AddMenu().presentationDetents([.height(430)])
                }
            }
            .presentationBackground(Oat.bg).presentationCornerRadius(34)
            .environment(store).environment(router).environment(pro)
        }
        .overlay {
            // A second presenter, so the paywall can come up whatever else is showing.
            Color.clear.allowsHitTesting(false)
                .sheet(item: $pro.paywall) { why in
                    PaywallView(reason: why).environment(pro).presentationBackground(Oat.bg).presentationCornerRadius(34)
                }
        }
    }
}

/// The tab bar: a dark cocoa collar with a persimmon tag on the chosen tab, and the add button.
struct Collar: View {
    @Binding var selection: Tab
    var add: () -> Void
    @Namespace private var ns
    var body: some View {
        HStack(spacing: 10) {
            HStack(spacing: 2) {
                ForEach(Tab.allCases) { t in
                    Button {
                        withAnimation(.spring(response: 0.38, dampingFraction: 0.78)) { selection = t }
                    } label: {
                        HStack(spacing: 6) {
                            Image(systemName: t.icon).font(.system(size: 15, weight: .bold))
                            if selection == t { Text(t.title).font(.round(13, .bold)).lineLimit(1).fixedSize() }
                        }
                        .foregroundStyle(selection == t ? .white : Oat.card.opacity(0.62))
                        .padding(.horizontal, selection == t ? 13 : 0).frame(height: 44)
                        .frame(maxWidth: selection == t ? nil : .infinity)
                        .background {
                            if selection == t { Capsule().fill(Oat.accent).matchedGeometryEffect(id: "tag", in: ns) }
                        }
                        .contentShape(Rectangle())
                    }
                    .buttonStyle(.plain)
                    .sensoryFeedback(.selection, trigger: selection)
                }
            }
            .padding(5)
            .background(Capsule().fill(Oat.ink).shadow(color: Oat.ink.opacity(0.28), radius: 18, y: 10))
            Button(action: add) {
                Image(systemName: "plus").font(.system(size: 20, weight: .heavy)).foregroundStyle(Oat.ink)
                    .frame(width: 54, height: 54)
                    .background(Circle().fill(Oat.card).shadow(color: Oat.ink.opacity(0.2), radius: 14, y: 8))
                    .overlay(Circle().strokeBorder(Oat.line2))
            }.pressable()
        }
        .padding(.horizontal, 16).padding(.bottom, 4)
    }
}

/// What the plus button offers.
struct AddMenu: View {
    @Environment(Store.self) private var store
    @Environment(Router.self) private var router
    @Environment(\.dismiss) private var dismiss
    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("Add").font(.display(28)).foregroundStyle(Oat.ink).padding(.top, 26)
            LazyVGrid(columns: [GridItem(.flexible(), spacing: 12), GridItem(.flexible(), spacing: 12)], spacing: 12) {
                tile("Dose or meal", "pills.fill", Oat.accent) { router.newDose(store) }
                tile("Weight", "scalemass.fill", Oat.sage) { router.newWeight(store) }
                tile("Vaccine", "syringe.fill", Oat.sky) { router.newVaccine(store) }
                tile("Vet visit", "calendar", Oat.honey) { router.newAppt(store) }
                tile("Note", "note.text", Color(hex: 0x8A5A8C)) { router.newNote(store) }
                tile("Pet", "pawprint.fill", Oat.ink) { router.newPet(store) }
            }
            Spacer(minLength: 0)
        }
        .padding(.horizontal, 20)
    }
    func tile(_ title: String, _ icon: String, _ tint: Color, _ go: @escaping () -> Void) -> some View {
        Button {
            router.sheet = nil
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.45) { go() }
        } label: {
            HStack(spacing: 12) {
                Image(systemName: icon).font(.system(size: 17, weight: .bold)).foregroundStyle(tint)
                    .frame(width: 42, height: 42).background(Circle().fill(tint.opacity(0.13)))
                Text(title).font(.round(15.5, .bold)).foregroundStyle(Oat.ink)
                Spacer(minLength: 0)
            }
            .card(12, radius: 20)
        }.pressable()
    }
}
