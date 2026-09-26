import SwiftUI

/// Drives the real screens for the App Review recording (-demoAutoplay).
@Observable
final class Autopilot {
    static let shared = Autopilot()
    static var on: Bool { ProcessInfo.processInfo.arguments.contains("-demoAutoplay") }
    private var running = false
    @MainActor private func wait(_ s: Double) async { try? await Task.sleep(for: .seconds(s)) }
    @MainActor
    func run(_ store: Store, _ router: Router, _ pro: Pro) {
        guard Autopilot.on, !running else { return }
        running = true
        Task { @MainActor in
            await wait(3.5)
            // Tick the overdue flea chew as Priya.
            if let s = store.slots(on: store.today).first(where: { store.given($0) == nil && $0.at < store.now }) {
                withAnimation(.spring(response: 0.4, dampingFraction: 0.6)) { store.give(s, by: store.db.people.dropFirst().first?.id) }
            }
            await wait(3)
            if let first = store.db.pets.first {
                withAnimation { router.tab = .pets }; await wait(2)
                withAnimation { router.petPath = [first.id] }; await wait(4.5)
                withAnimation { router.petPath = [] }; await wait(1)
            }
            withAnimation { router.tab = .vet }; await wait(4.5)
            withAnimation { router.tab = .health }; await wait(4.5)
            withAnimation { router.tab = .sitter }; await wait(4.5)
            withAnimation { router.tab = .today }; await wait(1.2)
            router.applyShotArgsAdd(store); await wait(4)
            router.sheet = nil; await wait(1.5)
            // The one purchase: Pawprint Pro, as a reviewer would reach it.
            withAnimation { router.tab = .pets }; await wait(1.5)
            pro.paywall = .pets; await wait(5)
            pro.paywall = nil; await wait(1.5)
            try? Data("ok".utf8).write(to: URL.documentsDirectory.appending(path: "demo_done"))
        }
    }
}

extension Router {
    func applyShotArgsAdd(_ s: Store) {
        guard let first = s.db.pets.first else { return }
        sheet = .dose(Dose(petID: first.id, kind: .med, name: "Gabapentin 100 mg", amount: "1 capsule in a pill pocket", note: "Can make him sleepy", freq: .daily, times: ["08:00", "20:00"], start: s.today, stock: 60, perDose: 1, unit: "capsules", remind: true), true)
    }
}
