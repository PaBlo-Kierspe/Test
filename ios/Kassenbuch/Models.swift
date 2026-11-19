import Foundation
import SwiftData
import SwiftUI

// MARK: - Art der Buchung

enum Kind: String, Codable, CaseIterable, Identifiable {
    case income, expense, saving

    var id: String { rawValue }

    var title: String {
        switch self {
        case .income: return "Einnahmen"
        case .expense: return "Ausgaben"
        case .saving: return "Ersparnisse"
        }
    }

    var single: String {
        switch self {
        case .income: return "Einnahme"
        case .expense: return "Ausgabe"
        case .saving: return "Sparen"
        }
    }

    var color: Color {
        switch self {
        case .income: return Palette.income
        case .expense: return Palette.expense
        case .saving: return Palette.saving
        }
    }

    var categories: [Cat] { Cat.allCases.filter { $0.kind == self } }
}

// MARK: - Kategorien (IDs identisch mit der Web-App, damit Backups kompatibel sind)

enum Cat: String, Codable, CaseIterable, Identifiable {
    // Einnahmen
    case gehalt, zinsen
    case mieteEin = "miete_ein"
    case dividende, nebenjob
    case sonstEin = "sonst_ein"
    // Ausgaben
    case wohnen, lebensmittel, mobil, versich, freizeit, gesund, abos
    case sonstAus = "sonst_aus"
    // Ersparnisse
    case tagesgeld, etf, notgroschen, rente
    case sonstSpar = "sonst_spar"

    var id: String { rawValue }

    var kind: Kind {
        switch self {
        case .gehalt, .zinsen, .mieteEin, .dividende, .nebenjob, .sonstEin: return .income
        case .wohnen, .lebensmittel, .mobil, .versich, .freizeit, .gesund, .abos, .sonstAus: return .expense
        case .tagesgeld, .etf, .notgroschen, .rente, .sonstSpar: return .saving
        }
    }

    var name: String {
        switch self {
        case .gehalt: return "Gehalt"
        case .zinsen: return "Zinsen"
        case .mieteEin: return "Mieteinnahmen"
        case .dividende: return "Dividenden"
        case .nebenjob: return "Nebenjob"
        case .sonstEin, .sonstAus, .sonstSpar: return "Sonstiges"
        case .wohnen: return "Wohnen"
        case .lebensmittel: return "Lebensmittel"
        case .mobil: return "Mobilität"
        case .versich: return "Versicherungen"
        case .freizeit: return "Freizeit"
        case .gesund: return "Gesundheit"
        case .abos: return "Abos & Verträge"
        case .tagesgeld: return "Tagesgeld"
        case .etf: return "ETF / Depot"
        case .notgroschen: return "Notgroschen"
        case .rente: return "Altersvorsorge"
        }
    }

    var symbol: String {
        switch self {
        case .gehalt: return "briefcase.fill"
        case .zinsen: return "percent"
        case .mieteEin: return "key.fill"
        case .dividende: return "chart.line.uptrend.xyaxis"
        case .nebenjob: return "hammer.fill"
        case .sonstEin: return "plus"
        case .wohnen: return "house.fill"
        case .lebensmittel: return "cart.fill"
        case .mobil: return "car.fill"
        case .versich: return "shield.fill"
        case .freizeit: return "theatermasks.fill"
        case .gesund: return "cross.case.fill"
        case .abos: return "repeat"
        case .sonstAus: return "ellipsis"
        case .tagesgeld: return "banknote.fill"
        case .etf: return "chart.bar.fill"
        case .notgroschen: return "lifepreserver.fill"
        case .rente: return "hourglass"
        case .sonstSpar: return "tray.full.fill"
        }
    }

    /// Zinsen, Mieten und Dividenden zählen als passives Einkommen.
    var isPassive: Bool { self == .zinsen || self == .mieteEin || self == .dividende }

    var color: Color {
        switch kind {
        case .income:
            switch self {
            case .zinsen: return Palette.series[0]
            case .mieteEin: return Palette.series[3]
            case .dividende: return Palette.series[6]
            default: return Palette.income
            }
        case .saving:
            return Palette.saving
        case .expense:
            let i = Kind.expense.categories.firstIndex(of: self) ?? 7
            return Palette.series[i % Palette.series.count]
        }
    }
}

// MARK: - Gespeicherte Daten (SwiftData)

@Model
final class Entry {
    var uid: UUID = UUID()
    var kindRaw: String = Kind.expense.rawValue
    var catRaw: String = Cat.sonstAus.rawValue
    var amount: Double = 0
    var date: Date = Date()
    var note: String = ""
    var ruleID: UUID?

    init(kind: Kind, cat: Cat, amount: Double, date: Date, note: String = "", ruleID: UUID? = nil) {
        self.uid = UUID()
        self.kindRaw = kind.rawValue
        self.catRaw = cat.rawValue
        self.amount = amount
        self.date = date
        self.note = note
        self.ruleID = ruleID
    }

    var kind: Kind {
        get { Kind(rawValue: kindRaw) ?? .expense }
        set { kindRaw = newValue.rawValue }
    }

    var cat: Cat {
        get { Cat(rawValue: catRaw) ?? .sonstAus }
        set { catRaw = newValue.rawValue }
    }
}

@Model
final class RecurringRule {
    var uid: UUID = UUID()
    var kindRaw: String = Kind.expense.rawValue
    var catRaw: String = Cat.sonstAus.rawValue
    var amount: Double = 0
    var note: String = ""
    var day: Int = 1
    /// Erster Tag des nächsten Monats, für den noch eine Buchung angelegt werden muss.
    var nextMonth: Date = Date()

    init(kind: Kind, cat: Cat, amount: Double, note: String, day: Int, nextMonth: Date) {
        self.uid = UUID()
        self.kindRaw = kind.rawValue
        self.catRaw = cat.rawValue
        self.amount = amount
        self.note = note
        self.day = day
        self.nextMonth = nextMonth
    }

    var kind: Kind { Kind(rawValue: kindRaw) ?? .expense }
    var cat: Cat { Cat(rawValue: catRaw) ?? .sonstAus }
}

@Model
final class SavingsGoal {
    var uid: UUID = UUID()
    var name: String = ""
    var target: Double = 0
    /// "all" = gesamtes Erspartes, sonst die ID einer Sparkategorie
    var scope: String = "all"
    var due: Date?
    var createdAt: Date = Date()

    init(name: String, target: Double, scope: String = "all", due: Date? = nil) {
        self.uid = UUID()
        self.name = name
        self.target = target
        self.scope = scope
        self.due = due
        self.createdAt = Date()
    }

    var scopeName: String {
        scope == "all" ? "Gesamtes Erspartes" : (Cat(rawValue: scope)?.name ?? "Gesamtes Erspartes")
    }
}

// MARK: - Farben (hell / dunkel)

enum Palette {
    static let income = Color(light: 0x1BAF7A, dark: 0x199E70)
    static let expense = Color(light: 0xEB6834, dark: 0xD95926)
    static let saving = Color(light: 0x2A78D6, dark: 0x3987E5)
    static let warn = Color(light: 0xEDA100, dark: 0xC98500)
    static let negative = Color(light: 0xC8372F, dark: 0xEF6B63)
    static let series: [Color] = [
        Color(light: 0x2A78D6, dark: 0x3987E5),
        Color(light: 0xEB6834, dark: 0xD95926),
        Color(light: 0x1BAF7A, dark: 0x199E70),
        Color(light: 0xEDA100, dark: 0xC98500),
        Color(light: 0xE87BA4, dark: 0xD55181),
        Color(light: 0x008300, dark: 0x0CA30C),
        Color(light: 0x6250D6, dark: 0x9085E9),
        Color(light: 0xE34948, dark: 0xE66767)
    ]
    static let ink = Color(light: 0x111521, dark: 0xEEF0F5)
    static let inkText = Color(light: 0xFFFFFF, dark: 0x0C0E13)
}

extension Color {
    init(light: UInt32, dark: UInt32) {
        self.init(uiColor: UIColor { traits in
            UIColor(hex: traits.userInterfaceStyle == .dark ? dark : light)
        })
    }
}

extension UIColor {
    convenience init(hex: UInt32) {
        self.init(red: CGFloat((hex >> 16) & 0xFF) / 255,
                  green: CGFloat((hex >> 8) & 0xFF) / 255,
                  blue: CGFloat(hex & 0xFF) / 255,
                  alpha: 1)
    }
}
