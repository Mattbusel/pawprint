import SwiftUI

struct SitterView: View {
    @Environment(Store.self) private var store
    @Environment(Router.self) private var router
    @State private var share: URL? = nil
    var body: some View {
        @Bindable var store = store
        let days = PDFs.tripDays(store).count
        ScrollView(showsIndicators: false) {
            VStack(alignment: .leading, spacing: 20) {
                VStack(alignment: .leading, spacing: 4) {
                    Eyebrow("Going away?")
                    Text("The sitter sheet").font(.display(34)).foregroundStyle(Oat.ink)
                    Text("Everything the sitter needs, on paper: who to call, what each pet eats, every dose and a tick sheet for the trip.")
                        .font(.round(14.5, .medium)).foregroundStyle(Oat.ink2).fixedSize(horizontal: false, vertical: true)
                }
                PageFan(store: store).frame(maxWidth: .infinity)
                BigButton(title: "Share the sitter sheet", icon: "square.and.arrow.up") { share = PDFs.sitter(store) }
                Text("\(PDFs.sitterPages(store).count) pages · \(days) day\(days == 1 ? "" : "s") on the tick sheet · print it or send it to them")
                    .font(.round(12.5, .semibold)).foregroundStyle(Oat.dim).frame(maxWidth: .infinity)

                VStack(alignment: .leading, spacing: 14) {
                    SectionTitle(title: "The trip")
                    Field(label: "Sitter's name") { TextField("Jordan", text: $store.db.sitter.name).onSubmit { store.save() } }
                    HStack(spacing: 12) {
                        VStack(alignment: .leading, spacing: 7) {
                            Eyebrow("From")
                            DatePicker("", selection: $store.db.sitter.from, displayedComponents: .date).labelsHidden()
                        }
                        VStack(alignment: .leading, spacing: 7) {
                            Eyebrow("To")
                            DatePicker("", selection: $store.db.sitter.to, in: store.db.sitter.from..., displayedComponents: .date).labelsHidden()
                        }
                        Spacer()
                    }
                    Eyebrow("Pets they're looking after")
                    HStack(spacing: 10) {
                        ForEach(store.db.pets) { p in
                            let on = store.db.sitter.petIDs.contains(p.id)
                            Button {
                                withAnimation(.spring(response: 0.3, dampingFraction: 0.7)) {
                                    if on { store.db.sitter.petIDs.removeAll { $0 == p.id } } else { store.db.sitter.petIDs.append(p.id) }
                                }
                                store.save()
                            } label: {
                                VStack(spacing: 6) {
                                    PetAvatar(pet: p, size: 58).opacity(on ? 1 : 0.4)
                                        .overlay(alignment: .bottomTrailing) {
                                            Image(systemName: on ? "checkmark.circle.fill" : "circle").font(.system(size: 18, weight: .bold))
                                                .foregroundStyle(on ? Oat.sage : Oat.faint).background(Circle().fill(Oat.bg))
                                        }
                                    Text(p.name).font(.round(12.5, .bold)).foregroundStyle(on ? Oat.ink : Oat.dim)
                                }
                            }.buttonStyle(Squish())
                        }
                    }
                    Field(label: "Anything else for this trip") {
                        TextField("Two short walks a day, not one long one", text: $store.db.sitter.extra, axis: .vertical).lineLimit(2...6)
                    }
                    Field(label: "About the house") {
                        TextField("Spare key, wifi, bins, the gate latch", text: $store.db.house, axis: .vertical).lineLimit(3...8)
                    }
                    Button { router.sheet = .household } label: {
                        HStack {
                            Image(systemName: "phone.fill").font(.system(size: 13, weight: .bold)).foregroundStyle(Oat.sky)
                            Text(store.db.vet.name.isEmpty ? "Add your vet and emergency vet" : "Vet, emergency vet and your numbers").font(.round(14.5, .bold)).foregroundStyle(Oat.ink)
                            Spacer()
                            Image(systemName: "chevron.right").font(.system(size: 11, weight: .heavy)).foregroundStyle(Oat.faint)
                        }.card(14, radius: 18)
                    }.buttonStyle(.plain)
                }
                .card(18, radius: 26)
            }
            .padding(.horizontal, 20).padding(.top, 8).padding(.bottom, 130)
        }
        .scrollDismissesKeyboard(.interactively)
        .onChange(of: store.db.sitter) { _, _ in store.save() }
        .onChange(of: store.db.house) { _, _ in store.save() }
        .sheet(item: Binding(get: { share.map(ShareItem.init) }, set: { if $0 == nil { share = nil } })) { s in ActivitySheet(items: [s.url]).ignoresSafeArea() }
    }
}

/// The first three pages of the sheet, fanned out like paper on a table.
struct PageFan: View {
    let store: Store
    var body: some View {
        let pages = Array(PDFs.sitterPages(store).prefix(3))
        let k: CGFloat = 0.43, w = 612 * k, h = 792 * k
        ZStack {
            ForEach(Array(pages.enumerated().reversed()), id: \.offset) { i, p in
                p.frame(width: 612, height: 792)
                    .scaleEffect(k, anchor: .topLeading)
                    .frame(width: w, height: h, alignment: .topLeading)
                    .clipShape(RoundedRectangle(cornerRadius: 6, style: .continuous))
                    .shadow(color: Oat.ink.opacity(0.16), radius: 12, y: 6)
                    .rotationEffect(.degrees(i == 0 ? -2 : i == 1 ? 6 : -9), anchor: .bottom)
                    .offset(x: i == 0 ? -10 : i == 1 ? 58 : -64, y: i == 0 ? 0 : 10)
            }
        }
        .frame(height: h + 30)
        .allowsHitTesting(false)
    }
}
