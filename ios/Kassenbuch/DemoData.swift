import Foundation
import SwiftData

/// Beispieldaten für den ersten Start, damit die App nicht leer ist.
enum DemoData {
    static let startSavings = 4200.0

    static func insert(into context: ModelContext) {
        let now = YM.now
        let today = Calendar.current.component(.day, from: Date())
        var seed: UInt64 = 7
        func rnd() -> Double {
            seed = (seed &* 16807) % 2147483647
            return Double(seed) / 2147483647
        }
        func add(_ ym: YM, _ day: Int, _ kind: Kind, _ amount: Double, _ cat: Cat, _ note: String) {
            context.insert(Entry(kind: kind, cat: cat, amount: (amount * 100).rounded() / 100, date: ym.date(day: day), note: note))
        }

        for i in stride(from: 5, through: 0, by: -1) {
            let ym = now.adding(-i)
            let lim: (Int) -> Bool = { d in i > 0 || d <= today }
            if lim(1) {
                add(ym, 1, .income, 3240, .gehalt, "Nettogehalt")
                add(ym, 1, .expense, 1080, .wohnen, "Warmmiete")
            }
            if lim(2) {
                add(ym, 2, .saving, 400, .etf, "Sparplan MSCI World")
                add(ym, 2, .saving, 150, .tagesgeld, "Dauerauftrag")
            }
            if lim(3) { add(ym, 3, .income, 640, .mieteEin, "Wohnung Lindenstraße") }
            if lim(28) { add(ym, 28, .income, 38 + rnd() * 6, .zinsen, "Tagesgeld 2,6 %") }
            if [2, 5].contains(ym.month % 6), lim(15) { add(ym, 15, .income, 120 + rnd() * 140, .dividende, "Quartalsausschüttung") }
            if lim(5) { add(ym, 5, .expense, 96.5, .versich, "Haftpflicht & Hausrat") }
            if lim(6) { add(ym, 6, .expense, 32.97, .abos, "Handy, Streaming") }
            let shops = ["Wocheneinkauf", "Markt", "Supermarkt", "Drogerie & Einkauf"]
            for w in 0..<4 where lim(4 + w * 7) {
                add(ym, 4 + w * 7, .expense, 70 + rnd() * 55, .lebensmittel, shops[w])
            }
            if lim(10) { add(ym, 10, .expense, 58, .mobil, "Deutschlandticket") }
            if lim(18) { add(ym, 18, .expense, 55 + rnd() * 90, .mobil, "Tanken") }
            if lim(13) { add(ym, 13, .expense, 40 + rnd() * 120, .freizeit, ["Kino & Essen", "Konzert", "Restaurant", "Ausflug"][Int(rnd() * 4) % 4]) }
            if lim(22), rnd() > 0.5 { add(ym, 22, .expense, 20 + rnd() * 60, .gesund, "Apotheke") }
            if lim(24) { add(ym, 24, .expense, 25 + rnd() * 70, .sonstAus, "Geschenk") }
            if i == 3, lim(20) { add(ym, 20, .income, 380, .nebenjob, "Nachhilfe") }
        }

        context.insert(SavingsGoal(name: "Vermögensaufbau", target: 15000))
        context.insert(SavingsGoal(name: "Urlaub Japan", target: 3000, scope: Cat.tagesgeld.rawValue, due: now.adding(10).firstDay))
        context.insert(SavingsGoal(name: "ETF-Depot", target: 10000, scope: Cat.etf.rawValue, due: now.adding(24).firstDay))
        try? context.save()
    }
}
