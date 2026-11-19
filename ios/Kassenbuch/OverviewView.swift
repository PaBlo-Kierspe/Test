import SwiftUI
import SwiftData
import Charts

struct OverviewView: View {
    @Environment(AppState.self) private var state
    @Query(sort: \Entry.date, order: .reverse) private var entries: [Entry]

    var body: some View {
        let t = entries.inMonth(state.month).totals()
        let prev = entries.inMonth(state.month.adding(-1)).totals()
        NavigationStack {
            ScrollView {
                VStack(spacing: 14) {
                    MonthSwitcher()
                    DemoBanner()
                    HeroCard(month: state.month, t: t)
                    HStack(spacing: 10) {
                        ForEach(Kind.allCases) { k in
                            Button {
                                state.filter = .from(k)
                                state.tab = .entries
                            } label: {
                                KPITile(kind: k, value: t[k], caption: delta(t[k], prev[k]))
                            }
                            .buttonStyle(.plain)
                        }
                    }
                    PassiveCard(t: t, yearPassive: entries.inYear(state.month.year).totals().passive, year: state.month.year)
                    ExpenseDonutCard(title: "Ausgaben nach Kategorie", t: t, emptyHint: "Tippe auf + um die erste Ausgabe für \(state.month.title) zu erfassen.")
                    SixMonthCard(entries: entries)
                }
                .padding(.horizontal)
                .padding(.bottom, 90)
            }
            .background(Color(.systemGroupedBackground))
            .navigationTitle("Übersicht")
        }
    }

    private func delta(_ a: Double, _ b: Double) -> String {
        guard b != 0 else { return "Vormonat: –" }
        let d = Int(((a - b) / b * 100).rounded())
        return "\(d >= 0 ? "+" : "−")\(abs(d)) % zum Vormonat"
    }
}

// MARK: - Monatssaldo

struct HeroCard: View {
    let month: YM
    let t: Totals

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("FREI VERFÜGBAR · \(month.title.uppercased())")
                .font(.caption.weight(.semibold)).tracking(0.6).opacity(0.7)
            Text(Fmt.eur(t.free))
                .font(.system(size: 40, weight: .bold))
                .monospacedDigit()
                .minimumScaleFactor(0.5)
                .lineLimit(1)
                .contentTransition(.numericText())
            Text("Einnahmen minus Ausgaben minus Ersparnisse · Sparquote \(Fmt.pct(t.savingsRate))")
                .font(.footnote).opacity(0.75)
            FlowBar(t: t)
            HStack(spacing: 14) {
                LegendItem(color: Palette.expense, text: "Ausgaben")
                LegendItem(color: Palette.saving, text: "Gespart")
                LegendItem(color: Palette.income, text: "Übrig")
            }
        }
        .foregroundStyle(Palette.inkText)
        .padding(18)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Palette.ink, in: RoundedRectangle(cornerRadius: 20, style: .continuous))
        .animation(.snappy, value: t.free)
    }
}

struct FlowBar: View {
    let t: Totals

    var body: some View {
        let base = max(t.income, t.expense + t.saving, 1)
        GeometryReader { geo in
            HStack(spacing: 2) {
                seg(t.expense / base, Palette.expense, geo.size.width)
                seg(t.saving / base, Palette.saving, geo.size.width)
                seg(max(t.free, 0) / base, Palette.income, geo.size.width)
                Spacer(minLength: 0)
            }
        }
        .frame(height: 12)
        .background(Palette.inkText.opacity(0.18))
        .clipShape(RoundedRectangle(cornerRadius: 6))
        .accessibilityElement()
        .accessibilityLabel("Ausgaben \(Fmt.eur(t.expense)), gespart \(Fmt.eur(t.saving)), übrig \(Fmt.eur(t.free))")
    }

    private func seg(_ share: Double, _ color: Color, _ width: CGFloat) -> some View {
        Rectangle().fill(color).frame(width: max(0, CGFloat(share) * (width - 6)))
    }
}

// MARK: - Passives Einkommen

struct PassiveCard: View {
    let t: Totals
    let yearPassive: Double
    let year: Int

    var body: some View {
        let items: [Cat] = [.zinsen, .mieteEin, .dividende]
        let maxV = max(items.map { t.byCat[$0] ?? 0 }.max() ?? 0, 1)
        Card(title: "Passives Einkommen", trailing: "\(t.income > 0 ? Fmt.pct(t.passive / t.income) : "0 %") der Einnahmen") {
            VStack(spacing: 12) {
                ForEach(items) { c in
                    let v = t.byCat[c] ?? 0
                    VStack(spacing: 6) {
                        HStack {
                            Dot(color: c.color)
                            Text(c.name)
                            Spacer()
                            Text(Fmt.eur(v)).fontWeight(.semibold).monospacedDigit()
                        }
                        ProgressBar(value: v / maxV, color: c.color)
                    }
                }
            }
            Text("Summe Monat **\(Fmt.eur(t.passive))** · \(String(year)) bisher **\(Fmt.eur(yearPassive))**")
                .font(.footnote).foregroundStyle(.secondary)
        }
    }
}

// MARK: - Ausgaben nach Kategorie

struct CatSlice: Identifiable {
    let cat: Cat
    let value: Double
    var id: String { cat.rawValue }
}

struct ExpenseDonutCard: View {
    let title: String
    let t: Totals
    var emptyHint: String = ""

    var body: some View {
        let slices = Kind.expense.categories
            .map { CatSlice(cat: $0, value: t.byCat[$0] ?? 0) }
            .filter { $0.value > 0 }
            .sorted { $0.value > $1.value }
        Card(title: title) {
            if slices.isEmpty {
                VStack(spacing: 6) {
                    Text("Noch keine Ausgaben").font(.headline)
                    Text(emptyHint).font(.subheadline).foregroundStyle(.secondary).multilineTextAlignment(.center)
                }
                .frame(maxWidth: .infinity)
                .padding(.vertical, 20)
            } else {
                HStack(alignment: .center, spacing: 16) {
                    ZStack {
                        Chart(slices) { s in
                            SectorMark(angle: .value("Betrag", s.value), innerRadius: .ratio(0.64), angularInset: 1.5)
                                .cornerRadius(3)
                                .foregroundStyle(s.cat.color)
                        }
                        .chartLegend(.hidden)
                        VStack(spacing: 0) {
                            Text("Ausgaben").font(.caption2).foregroundStyle(.secondary)
                            Text(Fmt.compact(t.expense)).font(.subheadline.bold()).monospacedDigit()
                        }
                    }
                    .frame(width: 124, height: 124)
                    VStack(spacing: 9) {
                        ForEach(slices.prefix(6)) { s in
                            HStack(spacing: 8) {
                                Dot(color: s.cat.color)
                                VStack(alignment: .leading, spacing: 0) {
                                    Text(s.cat.name).font(.subheadline).lineLimit(1)
                                    Text(Fmt.pct(s.value / max(t.expense, 1))).font(.caption2).foregroundStyle(.secondary)
                                }
                                Spacer(minLength: 4)
                                Text(Fmt.eur(s.value)).font(.subheadline.weight(.semibold)).monospacedDigit().lineLimit(1).minimumScaleFactor(0.8)
                            }
                        }
                        if slices.count > 6 {
                            Text("+ \(slices.count - 6) weitere").font(.caption).foregroundStyle(.secondary)
                                .frame(maxWidth: .infinity, alignment: .leading)
                        }
                    }
                }
            }
        }
    }
}

// MARK: - Letzte 6 Monate

struct BarPoint: Identifiable {
    let ym: YM
    let kind: Kind
    let value: Double
    var id: String { "\(ym.key)-\(kind.rawValue)" }
}

struct SixMonthCard: View {
    @Environment(AppState.self) private var state
    let entries: [Entry]
    @State private var selected: String?

    var body: some View {
        let months = (0..<6).map { state.month.adding($0 - 5) }
        let points = months.flatMap { ym -> [BarPoint] in
            let t = entries.inMonth(ym).totals()
            return Kind.allCases.map { BarPoint(ym: ym, kind: $0, value: t[$0]) }
        }
        Card(title: "Letzte 6 Monate") {
            HStack(spacing: 14) {
                ForEach(Kind.allCases) { LegendItem(color: $0.color, text: $0.title) }
            }
            Chart(points) { p in
                BarMark(x: .value("Monat", p.ym.short), y: .value("Betrag", p.value), width: .fixed(9))
                    .position(by: .value("Art", p.kind.title))
                    .foregroundStyle(by: .value("Art", p.kind.title))
                    .cornerRadius(3)
                    .opacity(p.ym == state.month ? 1 : 0.75)
            }
            .chartForegroundStyleScale(domain: Kind.allCases.map(\.title), range: Kind.allCases.map(\.color))
            .chartLegend(.hidden)
            .chartYAxis {
                AxisMarks(position: .leading, values: .automatic(desiredCount: 4)) { v in
                    AxisGridLine()
                    AxisValueLabel {
                        if let d = v.as(Double.self) { Text(Fmt.compact(d)) }
                    }
                }
            }
            .chartXSelection(value: $selected)
            .frame(height: 190)
            .onChange(of: selected) { _, label in
                if let label, let ym = months.first(where: { $0.short == label }) { state.month = ym }
            }
            Text("Tippe auf einen Monat, um ihn auszuwählen.").font(.footnote).foregroundStyle(.secondary)
        }
    }
}
