import SwiftUI
import StoreKit

/// Pawprint Pro: one non-consumable. One pet, every dose, reminder, vaccine, vet visit,
/// weight and note is free forever. Pro adds more pets and the printable sheets.
///
/// Doses and reminders are never gated: a pet's medication keeps its notifications no
/// matter what. Nothing already entered is ever hidden.
///
/// Anyone whose first download was a build before `firstFreemiumBuild` got the app when it
/// cost money, so they keep everything. AppTransaction's originalAppVersion is that build
/// number. Only trusted in production: sandbox reports made-up values, and App Review must
/// see the real paywall.
@MainActor
@Observable
final class Pro {
    static let productID = "com.mattbusel.pawprint.pro"
    /// The first build that has Pro in it. Anything earlier was the paid app.
    static let firstFreemiumBuild = 2
    /// How many pets are free.
    static let freePets = 1

    enum Reason: String, Identifiable { case pets, sitter, vet, settings; var id: String { rawValue } }

    private(set) var unlocked: Bool
    private(set) var grandfathered = false
    private(set) var product: Product?
    var busy = false
    var message: String?
    var paywall: Reason? = nil

    private var updates: Task<Void, Never>?
    private let key = "pawprint.pro.unlocked"
    private let forced: Bool

    /// `forced` is for screenshots and the review recording, which must not touch StoreKit.
    init(forced: Bool? = nil) {
        self.forced = forced != nil
        if let forced { unlocked = forced; return }
        unlocked = UserDefaults.standard.bool(forKey: key)
        updates = Task { [weak self] in
            for await result in Transaction.updates { await self?.apply(result) }
        }
        Task { await refresh() }
    }

    var price: String { product?.displayPrice ?? "$3.99" }

    /// True when the action may go ahead; otherwise shows the paywall.
    @discardableResult
    func allow(_ why: Reason) -> Bool {
        if unlocked { return true }
        paywall = why
        return false
    }

    func canAddPet(_ s: Store) -> Bool { unlocked || s.db.pets.count < Pro.freePets }

    func refresh() async {
        guard !forced else { return }
        if product == nil { product = try? await Product.products(for: [Pro.productID]).first }
        for await result in Transaction.currentEntitlements { await apply(result) }
        if case .verified(let app)? = try? await AppTransaction.shared,
           app.environment == .production, (Int(app.originalAppVersion) ?? Int.max) < Pro.firstFreemiumBuild {
            grandfathered = true
            grant()
        }
    }

    func buy() async {
        guard !forced, !busy else { return }
        busy = true; message = nil
        defer { busy = false }
        if product == nil { product = try? await Product.products(for: [Pro.productID]).first }
        guard let product else {
            message = "The App Store did not answer. Check your connection and try again."
            return
        }
        do {
            switch try await product.purchase() {
            case .success(let result):
                await apply(result)
                if !unlocked { message = "Apple could not confirm the purchase. Try Restore in a minute." }
            case .pending:
                message = "Waiting for approval. Pro unlocks by itself once it is approved."
            case .userCancelled:
                break
            @unknown default:
                message = "Something unexpected happened. You were not charged."
            }
        } catch {
            message = "The purchase did not go through: \(error.localizedDescription)"
        }
    }

    func restore() async {
        guard !forced, !busy else { return }
        busy = true; message = nil
        defer { busy = false }
        do { try await AppStore.sync() } catch {
            if let e = error as? StoreKitError, case .userCancelled = e { return }
            message = "Could not reach the App Store. Check your connection and try again."
            return
        }
        await refresh()
        message = unlocked ? "Pro is unlocked. Welcome back." : "No Pro purchase found on this Apple ID."
    }

    private func apply(_ result: VerificationResult<StoreKit.Transaction>) async {
        guard case .verified(let t) = result, t.productID == Pro.productID else { return }
        if t.revocationDate == nil { grant() } else if !grandfathered { revoke() }
        await t.finish()
    }

    private func grant() {
        guard !unlocked else { return }
        withAnimation(.spring(response: 0.45, dampingFraction: 0.7)) { unlocked = true }
        paywall = nil
        UserDefaults.standard.set(true, forKey: key)
    }

    private func revoke() {
        unlocked = false
        UserDefaults.standard.set(false, forKey: key)
    }
}

// MARK: - Paywall

/// A family portrait on oat paper with a persimmon tag hanging off the collar.
struct PaywallView: View {
    @Environment(Pro.self) private var pro
    @Environment(\.dismiss) private var dismiss
    let reason: Pro.Reason
    @State private var swing = false

    var body: some View {
        ZStack {
            OatBackground()
            ScrollView(showsIndicators: false) {
                VStack(alignment: .leading, spacing: 20) {
                    HStack {
                        Eyebrow("Pawprint Pro", color: Oat.accent)
                        Spacer()
                        Button { dismiss() } label: {
                            Image(systemName: "xmark").font(.system(size: 13, weight: .heavy)).foregroundStyle(Oat.ink2)
                                .frame(width: 36, height: 36).background(Circle().fill(Oat.card)).overlay(Circle().strokeBorder(Oat.line2))
                        }
                        .buttonStyle(.plain)
                        .accessibilityLabel("Close")
                    }
                    family.frame(maxWidth: .infinity)
                    VStack(alignment: .leading, spacing: 8) {
                        Text(headline).font(.display(34)).foregroundStyle(Oat.ink).fixedSize(horizontal: false, vertical: true)
                        Text("Your first pet's doses, reminders, vaccines, vet visits and weight are free for good. Pro is for the whole household and the paperwork.")
                            .font(.round(14.5, .medium)).foregroundStyle(Oat.ink2).fixedSize(horizontal: false, vertical: true)
                    }
                    VStack(alignment: .leading, spacing: 16) {
                        feature("pawprint.fill", Oat.accent, "Every pet in the house", "Dogs, cats, rabbits and the rest, each with their own doses and reminders.")
                        feature("house.fill", Oat.sage, "The sitter sheet", "Contacts, food, every dose and a tick sheet for the trip, ready to print.")
                        feature("doc.richtext.fill", Oat.sky, "Vet visit summary", "One page for the check-up: meds, missed doses, vaccines, weight and your questions.")
                    }
                    .card(18, radius: 26)
                    VStack(spacing: 4) {
                        Text(pro.price).font(.display(38)).foregroundStyle(Oat.ink)
                        Text("once · no subscription · Family Sharing").font(.round(12.5, .bold)).foregroundStyle(Oat.dim)
                    }
                    .frame(maxWidth: .infinity)
                    if let m = pro.message {
                        Text(m).font(.round(13, .semibold)).foregroundStyle(Oat.berry)
                            .multilineTextAlignment(.center).frame(maxWidth: .infinity)
                    }
                    BigButton(title: pro.busy ? "One moment" : "Unlock Pro for \(pro.price)", icon: "lock.open.fill") {
                        Task { await pro.buy() }
                    }
                    .disabled(pro.busy)
                    HStack {
                        SoftButton(title: "Restore purchase", icon: "arrow.clockwise") { Task { await pro.restore() } }
                        Spacer()
                        SoftButton(title: "Not now") { dismiss() }
                    }
                    Text("Reminders for every pet you have already added keep working, Pro or not. Nothing you have entered is ever locked away.")
                        .font(.round(11.5, .medium)).foregroundStyle(Oat.dim).fixedSize(horizontal: false, vertical: true)
                }
                .padding(.horizontal, 20).padding(.top, 20).padding(.bottom, 40)
            }
        }
        .onAppear { withAnimation(.easeInOut(duration: 1.6).repeatForever(autoreverses: true)) { swing = true } }
        .onChange(of: pro.unlocked) { _, now in if now { dismiss() } }
    }

    var headline: String {
        switch reason {
        case .pets: return "Room for the whole pack."
        case .sitter: return "Hand the sitter one sheet."
        case .vet: return "Walk into the vet prepared."
        case .settings: return "Everyone, and the paperwork."
        }
    }

    /// Four drawn faces side by side, with the Pro tag swinging off the middle.
    var family: some View {
        let faces: [(Species, Int)] = [(.cat, 3), (.dog, 1), (.rabbit, 5), (.other, 4)]
        return ZStack(alignment: .top) {
            HStack(spacing: -18) {
                ForEach(Array(faces.enumerated()), id: \.offset) { i, f in
                    ZStack {
                        Coat.of(f.1).bg
                        PetFace(species: f.0, coat: f.1).frame(width: 80, height: 80).offset(y: 5)
                    }
                    .frame(width: 84, height: 84).clipShape(Circle())
                    .overlay(Circle().strokeBorder(Oat.card, lineWidth: 4))
                    .shadow(color: Oat.ink.opacity(0.12), radius: 8, y: 4)
                    .offset(y: i % 2 == 0 ? 6 : -4)
                    .zIndex(Double(i == 1 ? 9 : i))
                }
            }
            .padding(.top, 8)
            ProTag()
                .rotationEffect(.degrees(swing ? 7 : -7), anchor: .top)
                .offset(x: 30, y: 78)
                .zIndex(20)
        }
        .frame(height: 170)
    }

    func feature(_ icon: String, _ tint: Color, _ title: String, _ detail: String) -> some View {
        HStack(alignment: .top, spacing: 12) {
            Image(systemName: icon).font(.system(size: 15, weight: .bold)).foregroundStyle(tint)
                .frame(width: 38, height: 38).background(Circle().fill(tint.opacity(0.13)))
            VStack(alignment: .leading, spacing: 2) {
                Text(title).font(.round(15.5, .bold)).foregroundStyle(Oat.ink)
                Text(detail).font(.round(12.5, .medium)).foregroundStyle(Oat.dim).fixedSize(horizontal: false, vertical: true)
            }
        }
    }
}

/// A persimmon bone-shaped name tag on a split ring.
struct ProTag: View {
    var body: some View {
        VStack(spacing: -3) {
            Circle().strokeBorder(Oat.honey, lineWidth: 3).frame(width: 16, height: 16)
            ZStack {
                Capsule().fill(Oat.accent).frame(width: 64, height: 34)
                    .shadow(color: Oat.accent.opacity(0.4), radius: 8, y: 4)
                Capsule().strokeBorder(.white.opacity(0.35), lineWidth: 1.5).frame(width: 56, height: 26)
                Text("PRO").font(.round(14, .heavy)).tracking(2).foregroundStyle(.white)
            }
        }
    }
}

/// On the pets page: what Pro adds, or a quiet thank-you once it is unlocked. Restore lives here too.
struct ProCard: View {
    @Environment(Pro.self) private var pro
    var body: some View {
        if pro.unlocked {
            HStack(spacing: 10) {
                Image(systemName: "checkmark.seal.fill").font(.system(size: 15, weight: .bold)).foregroundStyle(Oat.sage)
                Text(pro.grandfathered ? "Pawprint Pro, with thanks for buying early" : "Pawprint Pro is unlocked")
                    .font(.round(13.5, .bold)).foregroundStyle(Oat.ink2)
                Spacer()
            }
            .card(14, radius: 20)
        } else {
            VStack(alignment: .leading, spacing: 12) {
                HStack(spacing: 12) {
                    ProTag().scaleEffect(0.8).frame(width: 56, height: 50)
                    VStack(alignment: .leading, spacing: 2) {
                        Text("Pawprint Pro").font(.display(19)).foregroundStyle(Oat.ink)
                        Text("More pets, the sitter sheet and the vet summary. \(pro.price) once.")
                            .font(.round(12.5, .medium)).foregroundStyle(Oat.dim).fixedSize(horizontal: false, vertical: true)
                    }
                }
                HStack {
                    SoftButton(title: "See Pro", icon: "sparkles") { pro.paywall = .settings }
                    Spacer()
                    SoftButton(title: "Restore purchase", icon: "arrow.clockwise") { Task { await pro.restore() } }
                }
                if let m = pro.message, pro.paywall == nil {
                    Text(m).font(.round(12, .semibold)).foregroundStyle(Oat.berry)
                }
            }
            .card(16, radius: 24)
        }
    }
}
