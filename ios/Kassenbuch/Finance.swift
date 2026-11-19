import Foundation
import SwiftData

// MARK: - Monat

struct YM: Hashable, Comparable, Identifiable {
    var year: Int
    var month: Int

    var id: Int { year * 12 + (month - 1) }

    init(year: Int, month: Int) {
        self.year = year
        self.month = month
    }

    init(_ date: Date) {
        let c = Calendar.current.dateComponents([.year, .month], from: date)
        self.year = c.year ?? 2000
        self.month = c.month ?? 1
    }

    /// Format "YYYY-MM" (wie in der Web-App)
    init?(key: String) {
        let parts = key.split(separator: "-")
        guard parts.count >= 2, let y = Int(parts[0]), let m = Int(parts[1]), (1...12).contains(m) else { return nil }
        self.init(year: y, month: m)
    }

    static var now: YM { YM(Date()) }

    static func < (a: YM, b: YM) -> Bool { a.id < b.id }

    func adding(_ n: Int) -> YM {
        let t = id + n
        let y = Int((Double(t) / 12).rounded(.down))
        return YM(year: y, month: t - y * 12 + 1)
    }

    func months(until other: YM) -> Int { other.id - id }

    var firstDay: Date {
        Calendar.current.date(from: DateComponents(year: year, month: month, day: 1, hour: 12)) ?? Date()
    }

    var daysInMonth: Int {
        Calendar.current.range(of: .day, in: .month, for: firstDay)?.count ?? 30
    }

    func date(day: Int) -> Date {
        Calendar.current.date(from: DateComponents(year: year, month: month, day: min(max(day, 1), daysInMonth), hour: 12)) ?? firstDay
    }

    func contains(_ date: Date) -> Bool { YM(date) == self }

    var title: String { firstDay.formatted(.dateTime.month(.wide).year().locale(Fmt.de)) }
    var monthName: String { firstDay.formatted(.dateTime.month(.wide).locale(Fmt.de)) }
    var short: String { firstDay.formatted(.dateTime.month(.abbreviated).locale(Fmt.de)).replacingOccurrences(of: ".", with: "") }
    var key: String { String(format: "%04d-%02d", year, month) }
}

// MARK: - Formatierung

enum Fmt {
    static let de = Locale(identifier: "de_DE")

    static func eur(_ v: Double) -> String {
        v.formatted(.currency(code: "EUR").locale(de))
    }

    static func eur0(_ v: Double) -> String {
        v.formatted(.currency(code: "EUR").precision(.fractionLength(0)).locale(de))
    }

    static func compact(_ v: Double) -> String {
        if abs(v) >= 10_000 {
            return (v / 1000).formatted(.number.precision(.fractionLength(0...1)).locale(de)) + " T€"
        }
        return eur0(v)
    }

    static func pct(_ v: Double) -> String { "\(Int((v * 100).rounded())) %" }

    static func number(_ v: Double) -> String {
        v.formatted(.number.precision(.fractionLength(2)).grouping(.never).locale(de))
    }

    /// Wandelt "1.250,50", "1250.5" oder "12,5 €" in eine Zahl um.
    static func parse(_ text: String) -> Double? {
        var s = text.trimmingCharacters(in: .whitespaces)
            .replacingOccurrences(of: "€", with: "")
            .replacingOccurrences(of: " ", with: "")
        if s.isEmpty { return nil }
        if s.contains(",") {
            s = s.replacingOccurrences(of: ".", with: "").replacingOccurrences(of: ",", with: ".")
        }
        return Double(s)
    }

    static let isoDay: DateFormatter = {
        let f = DateFormatter()
        f.locale = Locale(identifier: "en_US_POSIX")
        f.timeZone = .current
        f.dateFormat = "yyyy-MM-dd"
        return f
    }()

    static func dayTitle(_ d: Date) -> String {
        if Calendar.current.isDateInToday(d) { return "Heute" }
        if Calendar.current.isDateInYesterday(d) { return "Gestern" }
        return d.formatted(.dateTime.weekday(.wide).day().month(.wide).locale(de))
    }
}

// MARK: - Summen

struct Totals {
    var income = 0.0
    var expense = 0.0
    var saving = 0.0
    var passive = 0.0
    var byCat: [Cat: Double] = [:]

    var free: Double { income - expense - saving }
    var savingsRate: Double { income > 0 ? saving / income : 0 }

    subscript(kind: Kind) -> Double {
        switch kind {
        case .income: return income
        case .expense: return expense
        case .saving: return saving
        }
    }

    var hasData: Bool { income != 0 || expense != 0 || saving != 0 }
}

extension Array where Element == Entry {
    func totals() -> Totals {
        var t = Totals()
        for e in self {
            switch e.kind {
            case .income:
                t.income += e.amount
                if e.cat.isPassive { t.passive += e.amount }
            case .expense: t.expense += e.amount
            case .saving: t.saving += e.amount
            }
            t.byCat[e.cat, default: 0] += e.amount
        }
        return t
    }

    func inMonth(_ ym: YM) -> [Entry] { filter { ym.contains($0.date) } }
    func inYear(_ year: Int) -> [Entry] { filter { Calendar.current.component(.year, from: $0.date) == year } }

    /// Sparguthaben bis einschließlich Monatsende (inkl. Startguthaben)
    func savingsBalance(until ym: YM, start: Double) -> Double {
        start + filter { $0.kind == .saving && YM($0.date) <= ym }.reduce(0) { $0 + $1.amount }
    }
}

// MARK: - Sparziele

struct GoalStats {
    var balance: Double
    var rate: Double          // Ø pro Monat
    var rest: Double
    var monthsLeft: Int?      // bis zum Erreichen
    var eta: YM?              // voraussichtlicher Monat
    var needed: Double?       // nötige Rate für Wunschtermin
    var onTrack: Bool?
    var done: Bool
    var progress: Double
}

enum Goals {
    static func stats(for goal: SavingsGoal, entries: [Entry], startSavings: Double) -> GoalStats {
        let now = YM.now
        func matches(_ e: Entry) -> Bool { e.kind == .saving && (goal.scope == "all" || e.catRaw == goal.scope) }
        let relevant = entries.filter(matches)
        let balance = (goal.scope == "all" ? startSavings : 0)
            + relevant.filter { YM($0.date) <= now }.reduce(0) { $0 + $1.amount }
        func sum(_ ym: YM) -> Double { relevant.filter { ym.contains($0.date) }.reduce(0) { $0 + $1.amount } }
        var rate = (1...3).map { sum(now.adding(-$0)) }.reduce(0, +) / 3
        if rate <= 0 { rate = sum(now) }
        let rest = max(0, goal.target - balance)
        var months: Int? = nil
        var eta: YM? = nil
        if rest > 0, rate > 0 {
            let n = Int((rest / rate).rounded(.up))
            months = n
            eta = now.adding(n)
        }
        var needed: Double? = nil
        var onTrack: Bool? = nil
        if let due = goal.due, rest > 0 {
            let dueYM = YM(due)
            let left = max(1, now.months(until: dueYM))
            needed = rest / Double(left)
            onTrack = eta.map { $0 <= dueYM } ?? false
        }
        return GoalStats(balance: balance, rate: rate, rest: rest, monthsLeft: months, eta: eta,
                         needed: needed, onTrack: onTrack, done: rest <= 0 && goal.target > 0,
                         progress: goal.target > 0 ? min(1, balance / goal.target) : 0)
    }
}

// MARK: - Monatliche Buchungen anlegen

enum Recurring {
    /// Legt für alle Daueraufträge die fehlenden Buchungen bis zum aktuellen Monat an.
    static func materialize(_ context: ModelContext) {
        guard let rules = try? context.fetch(FetchDescriptor<RecurringRule>()) else { return }
        let now = YM.now
        for rule in rules {
            var next = YM(rule.nextMonth)
            var guardCount = 0
            while next <= now && guardCount < 240 {
                context.insert(Entry(kind: rule.kind, cat: rule.cat, amount: rule.amount,
                                     date: next.date(day: rule.day), note: rule.note, ruleID: rule.uid))
                next = next.adding(1)
                guardCount += 1
            }
            rule.nextMonth = next.firstDay
        }
        try? context.save()
    }
}

// MARK: - Alles löschen

enum Store {
    static func wipe(_ context: ModelContext) {
        (try? context.fetch(FetchDescriptor<Entry>()))?.forEach { context.delete($0) }
        (try? context.fetch(FetchDescriptor<RecurringRule>()))?.forEach { context.delete($0) }
        (try? context.fetch(FetchDescriptor<SavingsGoal>()))?.forEach { context.delete($0) }
        try? context.save()
    }
}
