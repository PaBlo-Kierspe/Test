import SwiftUI
import SwiftData

struct YearView: View {
    @Environment(AppState.self) private var state
    @Query(sort: \Entry.date) private var entries: [Entry]

    var body: some View {
        let yearEntries = entries.inYear(state.year)
        let tot = yearEntries.totals()
        let rows = (1...12).map { m -> MonthRow in
            let ym = YM(year: state.year, month: m)
            return MonthRow(ym: ym, totals: yearEntries.inMonth(ym).totals())
        }
        let activeMonths = max(1, rows.filter { $0.totals.hasData }.count)

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
                            VStack(spacing: 0) {
                                HStack(spacing: 0) {
                                    header("Monat").frame(width: monthW, alignment: .leading)
                                    header("Einnahmen", Palette.income).frame(width: colW, alignment: .trailing)
                                    header("davon passiv").frame(width: colW, alignment: .trailing)
                                    header("Ausgaben", Palette.expense).frame(width: colW, alignment: .trailing)
                                    header("Ersparnisse", Palette.saving).frame(width: colW, alignment: .trailing)
                                    header("Saldo").frame(width: colW, alignment: .trailing)
                                }
                                .padding(.bottom, 8)
                                Divider()
                                ForEach(rows) { row in
                                    let t = row.totals
                                    HStack(spacing: 0) {
                                        Text(row.ym.monthName).frame(width: monthW, alignment: .leading)
                                        cell(t.income)
                                        cell(t.passive)
                                        cell(t.expense)
                                        cell(t.saving)
                                        Group {
                                            if t.hasData {
                                                Text(Fmt.eur(t.free)).foregroundStyle(t.free < 0 ? Palette.negative : .primary)
                                            } else {
                                                Text("–").foregroundStyle(.tertiary)
                                            }
                                        }
                                        .frame(width: colW, alignment: .trailing)
                                    }
                                    .font(.subheadline)
                                    .monospacedDigit()
                                    .padding(.vertical, 9)
                                    .contentShape(Rectangle())
                                    .onTapGesture {
                                        state.month = row.ym
                                        state.filter = .all
                                        state.tab = .entries
                                    }
                                    Divider()
                                }
                                HStack(spacing: 0) {
                                    Text("Summe").frame(width: monthW, alignment: .leading)
                                    Text(Fmt.eur(tot.income)).frame(width: colW, alignment: .trailing)
                                    Text(Fmt.eur(tot.passive)).frame(width: colW, alignment: .trailing)
                                    Text(Fmt.eur(tot.expense)).frame(width: colW, alignment: .trailing)
                                    Text(Fmt.eur(tot.saving)).frame(width: colW, alignment: .trailing)
                                    Text(Fmt.eur(tot.free)).foregroundStyle(tot.free < 0 ? Palette.negative : .primary)
                                        .frame(width: colW, alignment: .trailing)
                                }
                                .font(.subheadline.bold())
                                .monospacedDigit()
                                .lineLimit(1)
                                .minimumScaleFactor(0.8)
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

    private let monthW: CGFloat = 92
    private let colW: CGFloat = 108

    private func cell(_ v: Double) -> some View {
        Group {
            if v == 0 {
                Text("–").foregroundStyle(.tertiary)
            } else {
                Text(Fmt.eur(v))
            }
        }
        .lineLimit(1)
        .minimumScaleFactor(0.8)
        .frame(width: colW, alignment: .trailing)
    }
}

struct MonthRow: Identifiable {
    let ym: YM
    let totals: Totals
    var id: Int { ym.id }
}
