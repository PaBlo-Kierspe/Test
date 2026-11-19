import SwiftUI
import SwiftData

struct YearView: View {
    @Environment(AppState.self) private var state
    @Query(sort: \Entry.date) private var entries: [Entry]

    var body: some View {
        let yearEntries = entries.inYear(state.year)
        let tot = yearEntries.totals()
        let rows = (1...12).map { m -> (YM, Totals) in
            let ym = YM(year: state.year, month: m)
            return (ym, yearEntries.inMonth(ym).totals())
        }
        let activeMonths = max(1, rows.filter { $0.1.hasData }.count)

        NavigationStack {
            ScrollView {
                VStack(spacing: 14) {
                    YearSwitcher()
                    DemoBanner()
                    HStack(spacing: 8) {
                        KPITile(kind: .income, value: tot.income, caption: "davon passiv \(Fmt.eur0(tot.passive))")
                        KPITile(kind: .expense, value: tot.expense, caption: "Ø \(Fmt.eur0(tot.expense / Double(activeMonths)))/Monat")
                        KPITile(kind: .saving, value: tot.saving, caption: "Sparquote \(Fmt.pct(tot.savingsRate))")
                    }

                    Card(title: "Monatsübersicht \(String(state.year))") {
                        ScrollView(.horizontal, showsIndicators: false) {
                            Grid(alignment: .trailing, horizontalSpacing: 16, verticalSpacing: 0) {
                                GridRow {
                                    header("Monat").gridColumnAlignment(.leading)
                                    header("Einnahmen", Palette.income)
                                    header("davon passiv")
                                    header("Ausgaben", Palette.expense)
                                    header("Ersparnisse", Palette.saving)
                                    header("Saldo")
                                }
                                .padding(.bottom, 8)
                                Divider()
                                ForEach(rows, id: \.0) { ym, t in
                                    GridRow {
                                        Text(ym.monthName).gridColumnAlignment(.leading)
                                        cell(t.income)
                                        cell(t.passive)
                                        cell(t.expense)
                                        cell(t.saving)
                                        if t.hasData {
                                            Text(Fmt.eur(t.free)).foregroundStyle(t.free < 0 ? Palette.negative : .primary)
                                        } else {
                                            Text("–").foregroundStyle(.tertiary)
                                        }
                                    }
                                    .font(.subheadline)
                                    .monospacedDigit()
                                    .padding(.vertical, 9)
                                    .contentShape(Rectangle())
                                    .onTapGesture {
                                        state.month = ym
                                        state.filter = .all
                                        state.tab = .entries
                                    }
                                    Divider()
                                }
                                GridRow {
                                    Text("Summe").gridColumnAlignment(.leading)
                                    Text(Fmt.eur(tot.income))
                                    Text(Fmt.eur(tot.passive))
                                    Text(Fmt.eur(tot.expense))
                                    Text(Fmt.eur(tot.saving))
                                    Text(Fmt.eur(tot.free)).foregroundStyle(tot.free < 0 ? Palette.negative : .primary)
                                }
                                .font(.subheadline.bold())
                                .monospacedDigit()
                                .padding(.top, 9)
                            }
                        }
                        Text("Saldo = Einnahmen − Ausgaben − Ersparnisse. Tippe auf einen Monat für die Details.")
                            .font(.footnote).foregroundStyle(.secondary)
                    }

                    ExpenseDonutCard(title: "Ausgaben \(String(state.year)) nach Kategorie", t: tot, emptyHint: "In diesem Jahr gibt es noch keine Ausgaben.")
                }
                .padding(.horizontal)
                .padding(.bottom, 90)
            }
            .background(Color(.systemGroupedBackground))
            .navigationTitle("Jahr")
        }
    }

    private func header(_ text: String, _ color: Color? = nil) -> some View {
        HStack(spacing: 4) {
            if let color { Dot(color: color, size: 7) }
            Text(text.uppercased()).font(.caption2.weight(.semibold)).tracking(0.4).foregroundStyle(.secondary)
        }
    }

    @ViewBuilder
    private func cell(_ v: Double) -> some View {
        if v == 0 {
            Text("–").foregroundStyle(.tertiary)
        } else {
            Text(Fmt.eur(v))
        }
    }
}
