import SwiftUI
import SwiftData

struct EntriesView: View {
    @Environment(AppState.self) private var state
    @Environment(\.modelContext) private var context
    @Query(sort: \Entry.date, order: .reverse) private var entries: [Entry]
    @State private var search = ""

    var body: some View {
        @Bindable var s = state
        let searching = !search.trimmingCharacters(in: .whitespaces).isEmpty
        let list = filtered(searching: searching)
        let t = list.totals()
        let groups = Dictionary(grouping: list) { Calendar.current.startOfDay(for: $0.date) }
        let days = groups.keys.sorted(by: >)

        NavigationStack {
            List {
                Section {
                    VStack(spacing: 12) {
                        if !searching { MonthSwitcher() }
                        DemoBanner()
                        ScrollView(.horizontal, showsIndicators: false) {
                            HStack(spacing: 6) {
                                ForEach(ListFilter.allCases, id: \.self) { f in
                                    Button(f.title) { state.filter = f }
                                        .font(.subheadline.weight(.medium))
                                        .padding(.horizontal, 13)
                                        .padding(.vertical, 7)
                                        .foregroundStyle(state.filter == f ? Palette.inkText : .secondary)
                                        .background(state.filter == f ? AnyShapeStyle(Palette.ink) : AnyShapeStyle(Color(.secondarySystemGroupedBackground)), in: Capsule())
                                        .buttonStyle(.plain)
                                }
                            }
                        }
                        HStack(spacing: 8) {
                            KPITile(kind: .income, value: t.income)
                            KPITile(kind: .expense, value: t.expense)
                            KPITile(kind: .saving, value: t.saving)
                        }
                    }
                    .listRowInsets(EdgeInsets())
                    .listRowBackground(Color.clear)
                }

                if list.isEmpty {
                    Section {
                        ContentUnavailableView(searching ? "Nichts gefunden" : "Keine Buchungen",
                                               systemImage: searching ? "magnifyingglass" : "tray",
                                               description: Text(searching ? "Keine Buchung passt zu „\(search)“." : "Für \(state.month.title) gibt es hier noch nichts. Tippe auf +, um eine Buchung anzulegen."))
                    }
                    .listRowBackground(Color.clear)
                }

                ForEach(days, id: \.self) { day in
                    Section(Fmt.dayTitle(day)) {
                        ForEach(groups[day] ?? []) { e in
                            Button { state.editor = .edit(e) } label: { EntryRow(entry: e) }
                                .buttonStyle(.plain)
                                .swipeActions {
                                    Button(role: .destructive) {
                                        context.delete(e)
                                        try? context.save()
                                    } label: { Label("Löschen", systemImage: "trash") }
                                }
                        }
                    }
                }
            }
            .listStyle(.insetGrouped)
            .contentMargins(.bottom, 90, for: .scrollContent)
            .searchable(text: $search, prompt: "In allen Buchungen suchen")
            .navigationTitle("Buchungen")
        }
    }

    private func filtered(searching: Bool) -> [Entry] {
        var list = entries.filter { state.filter.matches($0) }
        if searching {
            let q = search.lowercased()
            list = list.filter {
                $0.note.lowercased().contains(q) || $0.cat.name.lowercased().contains(q) || $0.kind.single.lowercased().contains(q)
            }
        } else {
            list = list.inMonth(state.month)
        }
        return list
    }
}
