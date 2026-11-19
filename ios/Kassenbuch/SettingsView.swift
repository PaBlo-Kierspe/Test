import SwiftUI
import SwiftData
import LocalAuthentication

struct SettingsView: View {
    @Environment(\.modelContext) private var context
    @Query(sort: \Entry.date) private var entries: [Entry]
    @Query(sort: \RecurringRule.day) private var rules: [RecurringRule]
    @Query(sort: \SavingsGoal.createdAt) private var goals: [SavingsGoal]
    @AppStorage("startSavings") private var startSavings = 0.0
    @AppStorage("lockEnabled") private var lockEnabled = false
    @AppStorage("demoActive") private var demo = false

    @State private var startText = ""
    @State private var importing = false
    @State private var pendingImport: Data?
    @State private var confirmWipe = false
    @State private var message: String?

    var body: some View {
        NavigationStack {
            Form {
                Section {
                    HStack {
                        Text("Startguthaben")
                        TextField("0", text: $startText)
                            .keyboardType(.decimalPad)
                            .multilineTextAlignment(.trailing)
                            .monospacedDigit()
                            .onChange(of: startText) { _, v in
                                if let d = Fmt.parse(v) { startSavings = d } else if v.isEmpty { startSavings = 0 }
                            }
                        Text("€").foregroundStyle(.secondary)
                    }
                } header: {
                    Text("Ersparnisse")
                } footer: {
                    Text("Was du vor Beginn schon gespart hattest. Sparziele legst du im Bereich „Sparen“ an.")
                }

                Section {
                    if rules.isEmpty {
                        Text("Keine. Aktiviere beim Erfassen „Jeden Monat wiederholen“, z. B. für Gehalt, Miete oder Sparplan.")
                            .font(.subheadline).foregroundStyle(.secondary)
                    }
                    ForEach(rules) { r in
                        HStack(spacing: 12) {
                            CatIcon(cat: r.cat, size: 32)
                            VStack(alignment: .leading) {
                                Text(r.cat.name).fontWeight(.semibold)
                                Text("\(Fmt.eur(r.amount)) am \(r.day). · \(r.note.isEmpty ? r.kind.single : r.note)")
                                    .font(.footnote).foregroundStyle(.secondary).lineLimit(1)
                            }
                        }
                        .swipeActions {
                            Button("Beenden", role: .destructive) {
                                context.delete(r)
                                try? context.save()
                            }
                        }
                    }
                } header: {
                    Text("Monatliche Buchungen")
                } footer: {
                    if !rules.isEmpty { Text("Nach links wischen, um eine Wiederholung zu beenden. Bisherige Buchungen bleiben erhalten.") }
                }

                Section {
                    Toggle(isOn: $lockEnabled) {
                        Label(biometryName, systemImage: biometryIcon)
                    }
                } header: {
                    Text("Schutz")
                } footer: {
                    Text("Die App wird beim Öffnen gesperrt und im App-Umschalter ausgeblendet.")
                }

                Section {
                    ShareLink(item: ExportFile(filename: "Kassenbuch-\(Fmt.isoDay.string(from: Date())).csv", data: Backup.makeCSV(entries: entries)),
                              preview: SharePreview("Kassenbuch als CSV")) {
                        Label("Als CSV exportieren (Excel, Numbers)", systemImage: "tablecells")
                    }
                    ShareLink(item: ExportFile(filename: "Kassenbuch-Backup-\(Fmt.isoDay.string(from: Date())).json",
                                               data: Backup.makeJSON(entries: entries, rules: rules, goals: goals, startSavings: startSavings)),
                              preview: SharePreview("Kassenbuch-Backup")) {
                        Label("Backup sichern", systemImage: "square.and.arrow.up")
                    }
                    Button { importing = true } label: {
                        Label("Backup laden", systemImage: "square.and.arrow.down")
                    }
                    if !demo {
                        Button {
                            Store.wipe(context)
                            DemoData.insert(into: context)
                            startSavings = DemoData.startSavings
                            startText = Fmt.number(startSavings)
                            demo = true
                        } label: {
                            Label("Beispieldaten anzeigen", systemImage: "sparkles")
                        }
                    }
                    Button(role: .destructive) { confirmWipe = true } label: {
                        Label("Alle Daten löschen", systemImage: "trash")
                    }
                } header: {
                    Text("Daten")
                } footer: {
                    Text("Deine Daten bleiben auf diesem iPhone. Sichere sie ab und zu, z. B. in iCloud Drive. Backups der Web-Version kannst du hier ebenfalls laden.")
                }

                Section {
                    LabeledContent("Buchungen", value: "\(entries.count)")
                    LabeledContent("Version", value: Bundle.main.object(forInfoDictionaryKey: "CFBundleShortVersionString") as? String ?? "1.0")
                }
            }
            .navigationTitle("Mehr")
            .onAppear { startText = startSavings == 0 ? "" : Fmt.number(startSavings) }
            .fileImporter(isPresented: $importing, allowedContentTypes: [.json, .data]) { result in
                guard case .success(let url) = result else { return }
                let access = url.startAccessingSecurityScopedResource()
                defer { if access { url.stopAccessingSecurityScopedResource() } }
                if let data = try? Data(contentsOf: url) {
                    pendingImport = data
                } else {
                    message = "Die Datei konnte nicht gelesen werden."
                }
            }
            .confirmationDialog("Backup laden?", isPresented: Binding(get: { pendingImport != nil }, set: { if !$0 { pendingImport = nil } }), titleVisibility: .visible) {
                Button("Ersetzen", role: .destructive) {
                    guard let data = pendingImport else { return }
                    do {
                        let result = try Backup.restore(data, into: context)
                        startSavings = result.startSavings
                        startText = result.startSavings == 0 ? "" : Fmt.number(result.startSavings)
                        demo = false
                        Recurring.materialize(context)
                        message = "\(result.count) Buchungen geladen."
                    } catch {
                        message = error.localizedDescription
                    }
                    pendingImport = nil
                }
            } message: {
                Text("Alle aktuellen Daten werden durch das Backup ersetzt.")
            }
            .confirmationDialog("Wirklich alle Daten löschen?", isPresented: $confirmWipe, titleVisibility: .visible) {
                Button("Alles löschen", role: .destructive) {
                    Store.wipe(context)
                    demo = false
                    message = "Alle Daten gelöscht."
                }
            } message: {
                Text("Das lässt sich nicht rückgängig machen. Sichere vorher ein Backup.")
            }
            .alert(message ?? "", isPresented: Binding(get: { message != nil }, set: { if !$0 { message = nil } })) {
                Button("OK", role: .cancel) {}
            }
        }
    }

    private var biometryType: LABiometryType {
        let ctx = LAContext()
        _ = ctx.canEvaluatePolicy(.deviceOwnerAuthenticationWithBiometrics, error: nil)
        return ctx.biometryType
    }

    private var biometryName: String {
        switch biometryType {
        case .faceID: return "Mit Face ID sperren"
        case .touchID: return "Mit Touch ID sperren"
        default: return "Mit Code sperren"
        }
    }

    private var biometryIcon: String {
        switch biometryType {
        case .faceID: return "faceid"
        case .touchID: return "touchid"
        default: return "lock"
        }
    }
}
