import Foundation
import UIKit
import UserNotifications

/// Local notifications for doses, low supply and vet visits. Nothing leaves the phone.
/// Reminders are rebuilt from the data every time it changes: the next two weeks of doses,
/// soonest first, within iOS's limit of 64 pending notifications.
final class Reminders: NSObject, UNUserNotificationCenterDelegate {
    static let shared = Reminders()
    private let center = UNUserNotificationCenter.current()
    private(set) weak var store: Store?

    func attach(_ s: Store) { store = s }

    func setUp() {
        center.delegate = self
        let given = UNNotificationAction(identifier: "GIVEN", title: "Given", options: [])
        let snooze = UNNotificationAction(identifier: "SNOOZE", title: "Snooze 30 min", options: [])
        center.setNotificationCategories([UNNotificationCategory(identifier: "DOSE", actions: [given, snooze], intentIdentifiers: [], options: [])])
    }

    /// Asked only when the first reminder is switched on.
    func ask(_ done: @escaping (Bool) -> Void) {
        center.getNotificationSettings { st in
            if st.authorizationStatus == .notDetermined {
                self.center.requestAuthorization(options: [.alert, .sound, .badge]) { ok, _ in DispatchQueue.main.async { done(ok) } }
            } else {
                DispatchQueue.main.async { done(st.authorizationStatus == .authorized || st.authorizationStatus == .provisional) }
            }
        }
    }

    func status(_ done: @escaping (UNAuthorizationStatus) -> Void) {
        center.getNotificationSettings { st in DispatchQueue.main.async { done(st.authorizationStatus) } }
    }

    func reschedule(_ s: Store) {
        guard !s.demo else { return }
        let reqs = s.pendingReminders()
        center.getNotificationSettings { st in
            guard st.authorizationStatus == .authorized || st.authorizationStatus == .provisional else { return }
            self.center.getPendingNotificationRequests { pending in
                let stale = pending.map(\.identifier).filter { !$0.hasPrefix("snooze-") }
                self.center.removePendingNotificationRequests(withIdentifiers: stale)
                for r in reqs { self.center.add(r) }
            }
        }
    }

    // MARK: delegate

    func userNotificationCenter(_ center: UNUserNotificationCenter, willPresent notification: UNNotification, withCompletionHandler completionHandler: @escaping (UNNotificationPresentationOptions) -> Void) {
        completionHandler([.banner, .sound, .list])
    }

    func userNotificationCenter(_ center: UNUserNotificationCenter, didReceive response: UNNotificationResponse, withCompletionHandler completionHandler: @escaping () -> Void) {
        let content = response.notification.request.content
        let key = content.userInfo["key"] as? String
        let action = response.actionIdentifier
        DispatchQueue.main.async {
            if let key, action == "GIVEN", let s = self.store {
                s.give(key: key, by: s.db.me)
            } else if let key, action == "SNOOZE" {
                let c = (content.mutableCopy() as? UNMutableNotificationContent) ?? UNMutableNotificationContent()
                c.subtitle = "Snoozed"
                let r = UNNotificationRequest(identifier: "snooze-\(key)-\(Int(Date().timeIntervalSince1970))", content: c, trigger: UNTimeIntervalNotificationTrigger(timeInterval: 30 * 60, repeats: false))
                self.center.add(r)
            }
            completionHandler()
        }
    }
}

extension Store {
    func pendingReminders() -> [UNNotificationRequest] {
        var out: [(Date, UNNotificationRequest)] = []
        let now = Date(), day0 = D.start(now)
        func req(_ id: String, _ when: Date, _ title: String, _ body: String, dose: Bool, key: String? = nil, thread: String) {
            let c = UNMutableNotificationContent()
            c.title = title; c.body = body; c.sound = .default; c.threadIdentifier = thread
            if dose { c.categoryIdentifier = "DOSE" }
            if let key { c.userInfo = ["key": key] }
            let comps = D.cal.dateComponents([.year, .month, .day, .hour, .minute], from: when)
            out.append((when, UNNotificationRequest(identifier: id, content: c, trigger: UNCalendarNotificationTrigger(dateMatching: comps, repeats: false))))
        }
        for d in db.doses where d.remind && !d.paused {
            guard let p = pet(d.petID) else { continue }
            for off in 0..<14 {
                let day = D.add(off, day0)
                guard isDue(d, on: day) else { continue }
                for t in d.times {
                    let s = Slot(dose: d, time: t, day: day)
                    guard s.at > now, db.given[s.key] == nil else { continue }
                    let body = [d.amount, d.note].filter { !$0.isEmpty }.joined(separator: ". ")
                    req(s.key, s.at, "\(p.name): \(d.name)", body.isEmpty ? "Time for \(p.name)'s \(d.kind.noun)." : body, dose: true, key: s.key, thread: p.id.uuidString)
                }
            }
            if let left = daysLeft(d), left <= 7 {
                var when = day0.addingTimeInterval(9 * 3600)
                if when <= now { when = D.add(1, when) }
                req("low-\(d.id.uuidString)", when, "\(d.name) is running low", left == 0 ? "\(p.name) has none left. Time to refill." : "About \(left) day\(left == 1 ? "" : "s") left for \(p.name). Time to refill.", dose: false, thread: p.id.uuidString)
            }
        }
        for a in db.appts where a.remind && !a.done && a.date > now {
            guard let p = pet(a.petID) else { continue }
            let eve = D.add(-1, D.start(a.date)).addingTimeInterval(18 * 3600)
            if eve > now { req("appt-eve-\(a.id.uuidString)", eve, "Vet tomorrow: \(p.name)", "\(a.what) at \(D.clock(a.date))\(a.place.isEmpty ? "" : ", \(a.place)").", dose: false, thread: p.id.uuidString) }
            let soon = a.date.addingTimeInterval(-2 * 3600)
            if soon > now { req("appt-\(a.id.uuidString)", soon, "\(p.name) at the vet in 2 hours", a.what, dose: false, thread: p.id.uuidString) }
        }
        return out.sorted { $0.0 < $1.0 }.prefix(60).map { $0.1 }
    }
}
