import Foundation
import SwiftData
import CoreTransferable
import UniformTypeIdentifiers

/// Backup-Format – identisch mit der Web-App, damit Backups in beide Richtungen funktionieren.
struct BackupData: Codable {
    struct E: Codable {
        var id: String?
        var type: String
        var amount: Double
        var cat: String
        var note: String?
        var date: String
        var rule: String?
    }
    struct R: Codable {
        var id: String
        var type: String
        var cat: String
        var amount: Double
        var note: String?
        var day: Int
        var next: String
    }
    struct G: Codable {
        var id: String?
        var name: String
        var target: Double
        var cat: String
        var due: String?
    }
    struct S: Codable {
        var startSavings: Double?
        var goal: Double?
    }

    var entries: [E]
    var rules: [R]?
    var goals: [G]?
    var settings: S?
    var demo: Bool?
}

enum Backup {
    static func makeJSON(entries: [Entry], rules: [RecurringRule], goals: [SavingsGoal], startSavings: Double) -> Data {
        let data = BackupData(
            entries: entries.sorted { $0.date < $1.date }.map {
                .init(id: $0.uid.uuidString, type: $0.kindRaw, amount: $0.amount, cat: $0.catRaw,
                      note: $0.note, date: Fmt.isoDay.string(from: $0.date), rule: $0.ruleID?.uuidString)
            },
            rules: rules.map {
                .init(id: $0.uid.uuidString, type: $0.kindRaw, cat: $0.catRaw, amount: $0.amount,
                      note: $0.note, day: $0.day, next: YM($0.nextMonth).key)
            },
            goals: goals.map {
                .init(id: $0.uid.uuidString, name: $0.name, target: $0.target, cat: $0.scope,
                      due: $0.due.map { YM($0).key } ?? "")
            },
            settings: .init(startSavings: startSavings, goal: nil),
            demo: false
        )
        let enc = JSONEncoder()
        enc.outputFormatting = [.prettyPrinted, .sortedKeys]
        return (try? enc.encode(data)) ?? Data()
    }

    static func makeCSV(entries: [Entry]) -> Data {
        var lines = ["Datum;Art;Kategorie;Betrag;Notiz"]
        for e in entries.sorted(by: { $0.date < $1.date }) {
            let signed = e.kind == .expense ? -e.amount : e.amount
            let fields = [Fmt.isoDay.string(from: e.date), e.kind.single, e.cat.name, Fmt.number(signed), e.note]
            lines.append(fields.map { "\"" + $0.replacingOccurrences(of: "\"", with: "\"\"") + "\"" }.joined(separator: ";"))
        }
        // BOM, damit Excel die Umlaute richtig erkennt
        return Data("\u{FEFF}".utf8) + Data(lines.joined(separator: "\n").utf8)
    }

    enum ImportError: LocalizedError {
        case invalid
        var errorDescription: String? { "Die Datei ist kein Kassenbuch-Backup." }
    }

    /// Ersetzt alle Daten durch das Backup. Gibt Anzahl Buchungen und Startguthaben zurück.
    static func restore(_ raw: Data, into context: ModelContext) throws -> (count: Int, startSavings: Double) {
        guard let data = try? JSONDecoder().decode(BackupData.self, from: raw) else { throw ImportError.invalid }
        Store.wipe(context)

        var ruleIDs: [String: UUID] = [:]
        for r in data.rules ?? [] {
            guard let kind = Kind(rawValue: r.type), let cat = Cat(rawValue: r.cat), let next = YM(key: r.next) else { continue }
            let rule = RecurringRule(kind: kind, cat: cat, amount: r.amount, note: r.note ?? "", day: r.day, nextMonth: next.firstDay)
            context.insert(rule)
            ruleIDs[r.id] = rule.uid
        }
        var count = 0
        for e in data.entries {
            guard let kind = Kind(rawValue: e.type), let cat = Cat(rawValue: e.cat), let day = Fmt.isoDay.date(from: e.date) else { continue }
            let date = Calendar.current.date(bySettingHour: 12, minute: 0, second: 0, of: day) ?? day
            context.insert(Entry(kind: kind, cat: cat, amount: e.amount, date: date, note: e.note ?? "", ruleID: e.rule.flatMap { ruleIDs[$0] }))
            count += 1
        }
        if let goals = data.goals {
            for g in goals {
                let due = g.due.flatMap { YM(key: $0) }?.firstDay
                context.insert(SavingsGoal(name: g.name, target: g.target, scope: g.cat, due: due))
            }
        } else if let legacy = data.settings?.goal, legacy > 0 {
            context.insert(SavingsGoal(name: "Gesamtes Erspartes", target: legacy))
        }
        try context.save()
        return (count, data.settings?.startSavings ?? 0)
    }
}

/// Datei zum Teilen (Dateien-App, AirDrop, Mail …)
struct ExportFile: Transferable {
    let filename: String
    let data: Data

    static var transferRepresentation: some TransferRepresentation {
        FileRepresentation(exportedContentType: .data) { file in
            let url = FileManager.default.temporaryDirectory.appendingPathComponent(file.filename)
            try file.data.write(to: url, options: .atomic)
            return SentTransferredFile(url)
        }
    }
}
