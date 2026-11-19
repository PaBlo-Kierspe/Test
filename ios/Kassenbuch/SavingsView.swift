import SwiftUI
import SwiftData
import Charts

struct SavingsView: View {
    @Environment(AppState.self) private var state
    @Query(sort: \Entry.date) private var entries: [Entry]
    @Query(sort: \SavingsGoal.createdAt) private var goals: [SavingsGoal]
    @AppStorage("startSavings") private var startSavings = 0.0
    @State private var editingGoal: GoalTarget?

    var body: some View {
        let shownMonth = min(state.month, .now)
        let balance = entries.savingsBalance(until: shownMonth, start: startSavings)
        let months = (0..<12).map { state.month.adding($0 - 11) }
        let points = months.map { SavePoint(ym: $0, value: entries.savingsBalance(until: $0, start: startSavings)) }
        let allSavings = entries.filter { $0.kind == .saving && YM($0.date) <= state.month }
        let byCat = Kind.saving.categories
            .map { c in CatSlice(cat: c, value: allSavings.filter { $0.cat == c }.reduce(0) { $0 + $1.amount }) }
            .filter { $0.value > 0 }
        let maxCat = max(byCat.map(\.value).max() ?? 0, 1)
        let monthList = entries.inMonth(state.month).filter { $0.kind == .saving }.sorted { $0.date > $1.date }

        NavigationStack {
            ScrollView {
                VStack(spacing: 14) {
                    MonthSwitcher()
                    DemoBanner()

                    Card(title: "Sparguthaben Ende \(state.month.title)") {
                        Text(Fmt.eur(balance))
                            .font(.system(size: 32, weight: .bold))
                            .monospacedDigit()
                            .minimumScaleFactor(0.6)
                        SavingsChart(points: points)
                        Text("Inklusive Startguthaben von \(Fmt.eur(startSavings)).")
                            .font(.footnote).foregroundStyle(.secondary)
                    }

                    HStack {
                        SectionLabel("Sparziele")
                        Spacer()
                        Button {
                            editingGoal = .new
                        } label: {
                            Label("Sparziel", systemImage: "plus")
                                .font(.subheadline.weight(.semibold))
                        }
                        .buttonStyle(.borderedProminent)
                        .tint(Palette.ink)
                        .foregroundStyle(Palette.inkText)
                        .buttonBorderShape(.capsule)
                    }
                    .padding(.horizontal, 4)
                    .padding(.top, 4)

                    if goals.isEmpty {
                        Card {
                            VStack(spacing: 6) {
                                Text("Noch kein Sparziel").font(.headline)
                                Text("Lege ein Ziel an, z. B. „Urlaub 3.000 €“. Die App rechnet aus, wann du es voraussichtlich erreichst.")
                                    .font(.subheadline).foregroundStyle(.secondary).multilineTextAlignment(.center)
                            }
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 12)
                        }
                    }
                    ForEach(goals) { g in
                        GoalCard(goal: g, stats: Goals.stats(for: g, entries: entries, startSavings: startSavings)) {
                            editingGoal = .edit(g)
                        }
                    }

                    if !byCat.isEmpty {
                        Card(title: "Wohin das Ersparte geht") {
                            ForEach(byCat) { s in
                                VStack(spacing: 6) {
                                    HStack {
                                        Text(s.cat.name)
                                        Spacer()
                                        Text(Fmt.eur(s.value)).fontWeight(.semibold).monospacedDigit()
                                    }
                                    ProgressBar(value: s.value / maxCat, color: Palette.saving)
                                }
                            }
                        }
                    }

                    VStack(alignment: .leading, spacing: 8) {
                        SectionLabel("Sparbuchungen \(state.month.title)").padding(.horizontal, 4)
                        if monthList.isEmpty {
                            Card {
                                Text("Noch nichts gespart. Tippe auf + und wähle „Sparen“.")
                                    .font(.subheadline).foregroundStyle(.secondary)
                                    .frame(maxWidth: .infinity)
                            }
                        } else {
                            VStack(spacing: 0) {
                                ForEach(monthList) { e in
                                    Button { state.editor = .edit(e) } label: { EntryRow(entry: e) }
                                        .buttonStyle(.plain)
                                        .padding(.horizontal, 14)
                                        .padding(.vertical, 10)
                                    if e.uid != monthList.last?.uid { Divider().padding(.leading, 64) }
                                }
                            }
                            .background(Color(.secondarySystemGroupedBackground), in: RoundedRectangle(cornerRadius: 18, style: .continuous))
                        }
                    }
                }
                .padding(.horizontal)
                .padding(.bottom, 90)
            }
            .background(Color(.systemGroupedBackground))
            .navigationTitle("Sparen")
            .sheet(item: $editingGoal) { t in
                GoalEditor(target: t).environment(\.locale, Fmt.de)
            }
        }
    }
}

struct SavePoint: Identifiable {
    let ym: YM
    let value: Double
    var id: Int { ym.id }
}

struct SavingsChart: View {
    let points: [SavePoint]

    var body: some View {
        Chart {
            ForEach(points) { p in
                AreaMark(x: .value("Monat", p.ym.firstDay, unit: .month), y: .value("Guthaben", p.value))
                    .foregroundStyle(LinearGradient(colors: [Palette.saving.opacity(0.28), Palette.saving.opacity(0.02)], startPoint: .top, endPoint: .bottom))
                    .interpolationMethod(.monotone)
                LineMark(x: .value("Monat", p.ym.firstDay, unit: .month), y: .value("Guthaben", p.value))
                    .foregroundStyle(Palette.saving)
                    .lineStyle(StrokeStyle(lineWidth: 2.5))
                    .interpolationMethod(.monotone)
            }
            if let last = points.last {
                PointMark(x: .value("Monat", last.ym.firstDay, unit: .month), y: .value("Guthaben", last.value))
                    .foregroundStyle(Palette.saving)
                    .symbolSize(70)
            }
        }
        .chartYAxis {
            AxisMarks(position: .leading, values: .automatic(desiredCount: 4)) { v in
                AxisGridLine()
                AxisValueLabel { if let d = v.as(Double.self) { Text(Fmt.compact(d)) } }
            }
        }
        .chartXAxis {
            AxisMarks(values: .stride(by: .month, count: 2)) { _ in
                AxisValueLabel(format: .dateTime.month(.abbreviated))
            }
        }
        .frame(height: 160)
    }
}

// MARK: - Sparziel-Karte

struct GoalCard: View {
    let goal: SavingsGoal
    let stats: GoalStats
    let onEdit: () -> Void

    var body: some View {
        Card {
            HStack(alignment: .top) {
                VStack(alignment: .leading, spacing: 2) {
                    Text(goal.name).font(.title3.bold())
                    Text(goal.scopeName).font(.subheadline).foregroundStyle(.secondary)
                }
                Spacer()
                Button("Bearbeiten", action: onEdit)
                    .font(.subheadline)
                    .buttonStyle(.bordered)
                    .buttonBorderShape(.capsule)
            }
            HStack(spacing: 16) {
                Ring(progress: stats.progress, color: stats.done ? Palette.income : Palette.saving)
                VStack(alignment: .leading, spacing: 3) {
                    Text(Fmt.eur(stats.balance)).font(.title3.bold()).monospacedDigit()
                    Text("von \(Fmt.eur(goal.target))" + (stats.done ? "" : " · noch \(Fmt.eur(stats.rest))"))
                        .font(.footnote).foregroundStyle(.secondary)
                    if stats.done {
                        Pill(text: "Ziel erreicht", symbol: "checkmark", color: Palette.income)
                    } else if let eta = stats.eta, let n = stats.monthsLeft {
                        Text("Voraussichtlich erreicht").font(.footnote).foregroundStyle(.secondary).padding(.top, 2)
                        Text(eta.title).font(.headline).foregroundStyle(Palette.saving)
                        Text("in \(n) \(n == 1 ? "Monat" : "Monaten") · bei Ø \(Fmt.eur(stats.rate)) im Monat")
                            .font(.caption).foregroundStyle(.secondary)
                    } else {
                        Text("Voraussichtliches Datum folgt, sobald du für dieses Ziel sparst.")
                            .font(.footnote).foregroundStyle(.secondary)
                    }
                }
                Spacer(minLength: 0)
            }
            if let due = goal.due, !stats.done {
                VStack(alignment: .leading, spacing: 6) {
                    HStack {
                        Text("Wunschtermin **\(YM(due).title)**").font(.subheadline)
                        Spacer()
                        if stats.onTrack == true {
                            Pill(text: "Im Plan", symbol: "checkmark", color: Palette.income)
                        } else {
                            Pill(text: "Zu langsam", symbol: "exclamationmark", color: Palette.warn)
                        }
                    }
                    if stats.onTrack != true, let need = stats.needed {
                        Text("Dafür nötig: **\(Fmt.eur(need))** im Monat" + (stats.rate > 0 ? " (bisher Ø \(Fmt.eur(stats.rate)))" : ""))
                            .font(.footnote).foregroundStyle(.secondary)
                    }
                }
                .padding(12)
                .background(Color(.tertiarySystemFill).opacity(0.6), in: RoundedRectangle(cornerRadius: 12, style: .continuous))
            }
        }
    }
}

// MARK: - Sparziel bearbeiten

enum GoalTarget: Identifiable {
    case new
    case edit(SavingsGoal)

    var id: String {
        switch self {
        case .new: return "new"
        case .edit(let g): return g.uid.uuidString
        }
    }
}

struct GoalEditor: View {
    let target: GoalTarget
    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var context
    @State private var name: String
    @State private var amountText: String
    @State private var scope: String
    @State private var hasDue: Bool
    @State private var due: Date
    @State private var error: String?
    @State private var confirmDelete = false

    init(target: GoalTarget) {
        self.target = target
        let defaultDue = YM.now.adding(12).firstDay
        switch target {
        case .new:
            _name = State(initialValue: "")
            _amountText = State(initialValue: "")
            _scope = State(initialValue: "all")
            _hasDue = State(initialValue: false)
            _due = State(initialValue: defaultDue)
        case .edit(let g):
            _name = State(initialValue: g.name)
            _amountText = State(initialValue: Fmt.number(g.target))
            _scope = State(initialValue: g.scope)
            _hasDue = State(initialValue: g.due != nil)
            _due = State(initialValue: g.due ?? defaultDue)
        }
    }

    private var goal: SavingsGoal? {
        if case .edit(let g) = target { return g }
        return nil
    }

    var body: some View {
        NavigationStack {
            Form {
                Section {
                    TextField("Name, z. B. Urlaub, Auto, Notgroschen", text: $name)
                    HStack {
                        Text("Zielbetrag")
                        TextField("5.000", text: $amountText)
                            .keyboardType(.decimalPad)
                            .multilineTextAlignment(.trailing)
                            .monospacedDigit()
                        Text("€").foregroundStyle(.secondary)
                    }
                } footer: {
                    if let error { Text(error).foregroundStyle(Palette.negative) }
                }

                Section {
                    Picker("Welches Ersparte zählt?", selection: $scope) {
                        Text("Gesamtes Erspartes").tag("all")
                        ForEach(Kind.saving.categories) { Text($0.name).tag($0.rawValue) }
                    }
                } footer: {
                    Text("Wähle eine Sparkategorie, wenn du gezielt dafür sparst, z. B. Tagesgeld für den Urlaub.")
                }

                Section {
                    Toggle("Wunschtermin", isOn: $hasDue.animation())
                    if hasDue {
                        DatePicker("Bis", selection: $due, in: Date()..., displayedComponents: .date)
                    }
                } footer: {
                    Text("Mit Termin siehst du, ob du im Plan liegst und wie viel du dafür im Monat sparen musst.")
                }

                if goal != nil {
                    Section {
                        Button("Sparziel löschen", role: .destructive) { confirmDelete = true }
                    }
                }
            }
            .navigationTitle(goal == nil ? "Neues Sparziel" : "Sparziel bearbeiten")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) { Button("Abbrechen") { dismiss() } }
                ToolbarItem(placement: .confirmationAction) { Button("Sichern") { save() }.fontWeight(.semibold) }
            }
            .confirmationDialog("Sparziel löschen?", isPresented: $confirmDelete, titleVisibility: .visible) {
                Button("Löschen", role: .destructive) {
                    if let g = goal { context.delete(g); try? context.save() }
                    dismiss()
                }
            } message: {
                Text("Deine Sparbuchungen bleiben erhalten.")
            }
        }
    }

    private func save() {
        let trimmed = name.trimmingCharacters(in: .whitespaces)
        guard !trimmed.isEmpty else { error = "Bitte gib dem Sparziel einen Namen."; return }
        guard let target = Fmt.parse(amountText), target > 0 else {
            error = "Bitte einen Zielbetrag größer als 0 eingeben, z. B. 3.000."
            return
        }
        let dueDate = hasDue ? YM(due).firstDay : nil
        if let g = goal {
            g.name = trimmed
            g.target = target
            g.scope = scope
            g.due = dueDate
        } else {
            context.insert(SavingsGoal(name: trimmed, target: target, scope: scope, due: dueDate))
        }
        try? context.save()
        dismiss()
    }
}
