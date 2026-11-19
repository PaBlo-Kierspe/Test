import SwiftUI
import SwiftData

struct EntryEditor: View {
    let target: EditorTarget
    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var context
    @Environment(AppState.self) private var state
    @AppStorage("demoActive") private var demo = false
    @AppStorage("startSavings") private var startSavings = 0.0

    @State private var kind: Kind
    @State private var cat: Cat
    @State private var amountText: String
    @State private var date: Date
    @State private var note: String
    @State private var repeatMonthly = false
    @State private var confirmDelete = false
    @State private var error: String?
    @FocusState private var amountFocused: Bool

    init(target: EditorTarget, defaultDate: Date) {
        self.target = target
        switch target {
        case .new(let k):
            _kind = State(initialValue: k)
            _cat = State(initialValue: k.categories[0])
            _amountText = State(initialValue: "")
            _date = State(initialValue: defaultDate)
            _note = State(initialValue: "")
        case .edit(let e):
            _kind = State(initialValue: e.kind)
            _cat = State(initialValue: e.cat)
            _amountText = State(initialValue: Fmt.number(e.amount))
            _date = State(initialValue: e.date)
            _note = State(initialValue: e.note)
        }
    }

    private var editing: Entry? {
        if case .edit(let e) = target { return e }
        return nil
    }

    var body: some View {
        NavigationStack {
            Form {
                Section {
                    Picker("Art", selection: $kind) {
                        ForEach(Kind.allCases) { Text($0.single).tag($0) }
                    }
                    .pickerStyle(.segmented)
                    .listRowBackground(Color.clear)
                    .listRowInsets(EdgeInsets())
                }

                Section {
                    HStack(alignment: .firstTextBaseline, spacing: 8) {
                        TextField("0,00", text: $amountText)
                            .keyboardType(.decimalPad)
                            .font(.system(size: 40, weight: .bold))
                            .monospacedDigit()
                            .multilineTextAlignment(.center)
                            .minimumScaleFactor(0.5)
                            .focused($amountFocused)
                        Text("€").font(.title.weight(.semibold)).foregroundStyle(.secondary)
                    }
                    .padding(.vertical, 6)
                } header: {
                    Text("Betrag")
                } footer: {
                    if let error { Text(error).foregroundStyle(Palette.negative) }
                }

                Section("Kategorie") {
                    ChipGrid(items: kind.categories) { c in
                        Button { cat = c } label: {
                            HStack(spacing: 6) {
                                Image(systemName: c.symbol).font(.caption)
                                Text(c.name).font(.subheadline.weight(.medium)).lineLimit(1).minimumScaleFactor(0.8)
                            }
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 9)
                            .padding(.horizontal, 6)
                            .foregroundStyle(cat == c ? Palette.inkText : .primary)
                            .background(cat == c ? AnyShapeStyle(Palette.ink) : AnyShapeStyle(Color(.tertiarySystemFill)), in: Capsule())
                        }
                        .buttonStyle(.plain)
                        .accessibilityAddTraits(cat == c ? .isSelected : [])
                    }
                    .padding(.vertical, 4)
                }

                Section {
                    DatePicker("Datum", selection: $date, displayedComponents: .date)
                    TextField("Notiz (optional)", text: $note)
                    if editing == nil {
                        Toggle("Jeden Monat wiederholen", isOn: $repeatMonthly)
                    } else if editing?.ruleID != nil {
                        Label("Monatliche Buchung", systemImage: "repeat").foregroundStyle(.secondary)
                    }
                } footer: {
                    if editing == nil {
                        Text("Für feste Posten wie Gehalt, Miete oder Sparplan. Die Buchung wird dann jeden Monat automatisch angelegt.")
                    }
                }

                if editing != nil {
                    Section {
                        Button("Buchung löschen", role: .destructive) { confirmDelete = true }
                    }
                }
            }
            .navigationTitle(editing == nil ? "Neue Buchung" : "Buchung bearbeiten")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) { Button("Abbrechen") { dismiss() } }
                ToolbarItem(placement: .confirmationAction) { Button("Sichern") { save() }.fontWeight(.semibold) }
            }
            .onChange(of: kind) { _, k in
                if cat.kind != k { cat = k.categories[0] }
            }
            .confirmationDialog("Buchung wirklich löschen?", isPresented: $confirmDelete, titleVisibility: .visible) {
                Button("Löschen", role: .destructive) {
                    if let e = editing { context.delete(e); try? context.save() }
                    dismiss()
                }
            }
            .onAppear { if editing == nil { amountFocused = true } }
        }
        .presentationDragIndicator(.visible)
    }

    private func save() {
        guard let value = Fmt.parse(amountText), value > 0 else {
            error = "Bitte einen Betrag größer als 0 eingeben, z. B. 12,50."
            return
        }
        let amount = (value * 100).rounded() / 100
        let trimmed = note.trimmingCharacters(in: .whitespaces)

        if let e = editing {
            e.kind = kind
            e.cat = cat
            e.amount = amount
            e.date = date
            e.note = trimmed
            if let rid = e.ruleID,
               let rule = try? context.fetch(FetchDescriptor<RecurringRule>(predicate: #Predicate { $0.uid == rid })).first {
                rule.kindRaw = kind.rawValue
                rule.catRaw = cat.rawValue
                rule.amount = amount
                rule.note = trimmed
            }
        } else {
            if demo {
                Store.wipe(context)
                startSavings = 0
                demo = false
            }
            var ruleID: UUID? = nil
            if repeatMonthly {
                let ym = YM(date)
                let rule = RecurringRule(kind: kind, cat: cat, amount: amount, note: trimmed,
                                         day: Calendar.current.component(.day, from: date),
                                         nextMonth: ym.adding(1).firstDay)
                context.insert(rule)
                ruleID = rule.uid
            }
            context.insert(Entry(kind: kind, cat: cat, amount: amount, date: date, note: trimmed, ruleID: ruleID))
        }
        try? context.save()
        if editing == nil { Recurring.materialize(context) }
        state.month = YM(date)
        dismiss()
    }
}
