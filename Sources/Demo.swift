import Foundation

/// A three-pet household for screenshots and the review recording. Never saved.
enum Demo {
    static var now: Date { D.start(Date()).addingTimeInterval(9 * 3600 + 41 * 60) }

    static func fill(_ s: Store) {
        let T = D.start(Date())
        func day(_ n: Int) -> Date { D.add(n, T) }
        var seed: UInt64 = 7
        func rnd() -> Double { seed = seed &* 6364136223846793005 &+ 1442695040888963407; return Double(seed >> 33) / Double(1 << 31) }

        let sam = Person(name: "Sam", hue: 0, phone: "(555) 301-5522"), priya = Person(name: "Priya", hue: 1, phone: "(555) 301-7784"), leo = Person(name: "Leo", hue: 2)
        s.db.people = [sam, priya, leo]; s.db.me = sam.id

        let biscuit = Pet(name: "Biscuit", species: .dog, breed: "Beagle mix", born: day(-4060), sex: "Male, neutered", coat: 0, targetMin: 28, targetMax: 32, chip: "985 112 004 771 203",
                          food: "Senior dry food, 1 level cup per meal (the blue scoop).",
                          quirks: "Steals socks and will swallow them, keep the laundry basket shut.\nScared of thunder: shut him in the bathroom with the radio on.\nNeeds a lift into the car, his back legs are stiff.",
                          health: "Arthritis in the back legs. Low thyroid. Allergic to chicken.",
                          questions: "Is the carprofen dose still right now he weighs less?\nShould we add a kidney check to the bloodwork?")
        let miso = Pet(name: "Miso", species: .cat, breed: "Domestic shorthair", born: day(-2250), sex: "Female, spayed", coat: 1, targetMin: 9, targetMax: 11, chip: "941 000 019 552 870",
                       food: "Half a pouch of wet food per meal. Dry food bowl topped up once a day.",
                       quirks: "Indoor only, do not let her out.\nHides under the spare bed when visitors come. Leave her be, she comes out at night.\nLoves the laser pointer.",
                       health: "Gets hairballs. Sensitive tummy with fish flavors.")
        let clover = Pet(name: "Clover", species: .rabbit, breed: "Holland Lop", born: day(-1150), sex: "Female, spayed", coat: 2, targetMin: 3.5, targetMax: 4.2,
                         food: "Unlimited timothy hay. 1/4 cup pellets in the morning, a handful of greens in the evening.",
                         quirks: "Thumps her back foot when annoyed.\nFree-roams the living room when someone is home, pen otherwise.\nCheck she is eating and pooping every day.",
                         health: "Had GI stasis once in March. Call the vet if she stops eating.")
        s.db.pets = [biscuit, miso, clover]

        func dom(_ off: Int) -> Date { D.cal.date(byAdding: .month, value: -5, to: day(off)) ?? day(off) }
        func M(_ pet: Pet, _ kind: DoseKind, _ name: String, _ amount: String, _ times: [String], freq: Freq = .daily, every: Int = 2, start: Date? = nil, end: Date? = nil, stock: Int? = nil, unit: String = "tablets", note: String = "", remind: Bool = true) -> Dose {
            Dose(petID: pet.id, kind: kind, name: name, amount: amount, note: note, freq: freq, every: every, times: times, start: start ?? day(-200), end: end, stock: stock, perDose: 1, unit: unit, remind: remind, created: day(-60))
        }
        s.db.doses = [
            M(biscuit, .meal, "Breakfast", "1 cup senior food", ["07:30"], remind: false),
            M(biscuit, .meal, "Dinner", "1 cup senior food", ["18:00"], remind: false),
            M(biscuit, .med, "Carprofen 75 mg", "1 tablet with food", ["08:00", "20:00"], start: day(-181), stock: 23, note: "Hide it in a cube of cheese"),
            M(biscuit, .med, "Levothyroxine 0.5 mg", "1 tablet", ["08:00"], start: day(-400), stock: 41),
            M(biscuit, .heart, "Heartworm chew", "1 chew", ["09:00"], freq: .monthly, start: dom(6), stock: 4, unit: "chews"),
            M(biscuit, .flea, "Flea & tick chew", "1 chew", ["09:00"], freq: .monthly, start: dom(0), stock: 2, unit: "chews"),
            M(miso, .meal, "Breakfast", "Half a pouch wet food", ["07:30"], remind: false),
            M(miso, .meal, "Dinner", "Half a pouch wet food", ["18:00"], remind: false),
            M(miso, .supp, "Hairball paste", "1 inch on her paw", ["12:00"], freq: .every, every: 3, start: day(-9)),
            M(miso, .flea, "Flea drops", "1 tube on the back of the neck", ["20:00"], freq: .monthly, start: dom(-3), stock: 3, unit: "tubes"),
            M(clover, .meal, "Pellets", "1/4 cup", ["08:00"], remind: false),
            M(clover, .meal, "Greens", "A handful, romaine and cilantro", ["18:30"], remind: false),
            M(clover, .supp, "Probiotic gel", "1 g by mouth", ["18:30"], start: day(-5), end: day(9), stock: 6, unit: "doses", note: "Course ends in 9 days"),
        ]

        let who = [sam.id, priya.id, leo.id], nowMin = 9 * 60 + 41
        for off in -45...0 {
            let d = day(off)
            for dose in s.db.doses where s.isDue(dose, on: d) {
                for t in dose.times {
                    let m = D.mins(t)
                    if off == 0 && (m > nowMin - 30 || dose.kind == .flea) { continue }
                    if (off == -2 || off == -17) && dose.name.hasPrefix("Carprofen") && t == "20:00" { continue }
                    if off == -4 && dose.name == "Greens" { continue }
                    let by = m < 600 ? (rnd() < 0.6 ? sam.id : priya.id) : who[Int(rnd() * 3) % 3]
                    let at = D.at(t, on: d).addingTimeInterval(TimeInterval((Int(rnd() * 25) - 6) * 60))
                    s.db.given[Slot(dose: dose, time: t, day: d).key] = Given(by: by, at: at)
                }
            }
        }

        func V(_ p: Pet, _ name: String, _ given: Int, _ months: Int) -> Vaccine { Vaccine(petID: p.id, name: name, given: day(given), months: months, clinic: "Maple Street Veterinary") }
        s.db.vaccines = [V(biscuit, "Rabies", -800, 36), V(biscuit, "DHPP", -353, 12), V(biscuit, "Bordetella", -370, 12), V(biscuit, "Leptospirosis", -240, 12), V(biscuit, "Lyme", -300, 12),
                         V(miso, "FVRCP", -865, 36), V(miso, "Rabies", -325, 12), V(clover, "RHDV2", -346, 12)]

        func A(_ p: Pet, _ off: Int, _ time: String, _ what: String, done: Bool = false) -> Appt { Appt(petID: p.id, date: D.at(time, on: day(off)), what: what, place: "Maple Street Veterinary", done: done, remind: !done) }
        s.db.appts = [A(biscuit, 9, "10:30", "Senior bloodwork and thyroid recheck"), A(clover, 23, "16:00", "Nail trim and dental check"), A(miso, 40, "09:15", "Rabies booster"),
                      A(biscuit, -62, "08:00", "Dental cleaning", done: true), A(clover, -190, "11:00", "GI stasis follow-up", done: true), A(biscuit, -181, "17:30", "Limping on back left leg", done: true)]

        func W(_ p: Pet, _ vals: [Double], _ step: Int) { for (i, v) in vals.enumerated() { s.db.weights.append(Weigh(petID: p.id, date: day(-(vals.count - 1 - i) * step - 2), value: v)) } }
        W(biscuit, [33.9, 33.6, 33.8, 33.2, 32.9, 32.6, 32.1, 31.9, 31.5, 31.2, 31.0, 30.8, 30.6], 30)
        W(miso, [10.4, 10.6, 10.5, 10.8, 10.7, 10.9, 10.6, 10.5, 10.6], 45)
        W(clover, [3.7, 3.8, 3.6, 3.3, 3.5, 3.7, 3.8, 3.9], 48)

        func N(_ p: Pet, _ off: Int, _ tag: NoteTag, _ text: String) { s.db.notes.append(PetNote(petID: p.id, date: day(off), tag: tag, text: text)) }
        N(biscuit, -181, .vet, "Limping on the back left after the long hike. Vet started carprofen twice a day and said to keep walks short.")
        N(biscuit, -62, .vet, "Dental cleaning: two teeth out. Bloodwork normal, thyroid dose stays the same.")
        N(biscuit, -20, .symptom, "Slow getting up in the mornings, fine after breakfast and a short walk.")
        N(biscuit, -6, .symptom, "Threw up grass once on the walk. Ate dinner normally.")
        N(biscuit, -2, .behavior, "Barking at the mail van again. Leo moved his bed away from the window.")
        N(miso, -15, .symptom, "Hairball on the hall rug. Otherwise eating well.")
        N(miso, -40, .food, "Switched to the chicken pouches. Eats them faster than the fish ones.")
        N(clover, -190, .vet, "GI stasis: stopped eating overnight. Vet gave gut meds and syringe food. Back to normal in 3 days.")
        N(clover, -8, .food, "Not keen on the new pellets. Mixing half and half with the old ones for two weeks.")

        s.db.vet = Contact(name: "Maple Street Veterinary", who: "Dr. Alvarez", phone: "(555) 214-8830", address: "412 Maple St, Springfield")
        s.db.er = Contact(name: "Northside 24-Hour Animal ER", who: "", phone: "(555) 790-1100", address: "88 Route 9, Springfield")
        s.db.house = "Spare key is with Gail next door at no. 14.\nWifi: MapleHouse / biscuit2015\nBins go out Thursday night.\nPlease don't use the back gate, the latch is broken."
        s.db.sitter = Sitter(name: "Jordan", from: day(14), to: day(18), petIDs: [biscuit.id, miso.id, clover.id], extra: "Biscuit gets two short walks a day, not one long one. Treats are in the tin above the fridge, 3 a day at most.")
    }
}
