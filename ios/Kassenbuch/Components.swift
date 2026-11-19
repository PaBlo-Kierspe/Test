import SwiftUI
import SwiftData

// MARK: - Karte

struct Card<Content: View>: View {
    var title: String? = nil
    var trailing: String? = nil
    @ViewBuilder var content: Content

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            if let title {
                HStack(alignment: .firstTextBaseline) {
                    SectionLabel(title)
                    Spacer()
                    if let trailing {
                        Text(trailing).font(.footnote).foregroundStyle(.secondary)
                    }
                }
            }
            content
        }
        .padding(16)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Color(.secondarySystemGroupedBackground), in: RoundedRectangle(cornerRadius: 18, style: .continuous))
    }
}

struct SectionLabel: View {
    let text: String
    init(_ text: String) { self.text = text }

    var body: some View {
        Text(text.uppercased())
            .font(.caption.weight(.semibold))
            .tracking(0.6)
            .foregroundStyle(.secondary)
    }
}

// MARK: - Monatswahl

struct MonthSwitcher: View {
    @Environment(AppState.self) private var state

    var body: some View {
        HStack(spacing: 4) {
            Button { state.month = state.month.adding(-1) } label: {
                Image(systemName: "chevron.left").frame(width: 40, height: 36)
            }
            .accessibilityLabel("Vorheriger Monat")
            Text(state.month.title)
                .font(.headline)
                .frame(minWidth: 150)
                .contentTransition(.numericText())
            Button { state.month = state.month.adding(1) } label: {
                Image(systemName: "chevron.right").frame(width: 40, height: 36)
            }
            .accessibilityLabel("Nächster Monat")
            if state.month != .now {
                Button("Heute") { state.month = .now }
                    .font(.subheadline.weight(.semibold))
                    .padding(.horizontal, 8)
            }
        }
        .foregroundStyle(.primary)
        .padding(3)
        .background(Color(.secondarySystemGroupedBackground), in: Capsule())
        .animation(.snappy, value: state.month)
        .frame(maxWidth: .infinity)
    }
}

struct YearSwitcher: View {
    @Environment(AppState.self) private var state

    var body: some View {
        HStack(spacing: 4) {
            Button { state.year -= 1 } label: { Image(systemName: "chevron.left").frame(width: 40, height: 36) }
                .accessibilityLabel("Vorheriges Jahr")
            Text(String(state.year)).font(.headline).frame(minWidth: 90)
            Button { state.year += 1 } label: { Image(systemName: "chevron.right").frame(width: 40, height: 36) }
                .accessibilityLabel("Nächstes Jahr")
        }
        .foregroundStyle(.primary)
        .padding(3)
        .background(Color(.secondarySystemGroupedBackground), in: Capsule())
        .frame(maxWidth: .infinity)
    }
}

// MARK: - Hinweis auf Beispieldaten

struct DemoBanner: View {
    @Environment(\.modelContext) private var context
    @AppStorage("demoActive") private var demo = false
    @AppStorage("startSavings") private var startSavings = 0.0

    var body: some View {
        if demo {
            HStack(spacing: 12) {
                Text("Du siehst **Beispieldaten**, damit du die App kennenlernst.")
                    .font(.subheadline)
                Spacer(minLength: 0)
                Button("Leeren") {
                    Store.wipe(context)
                    startSavings = 0
                    demo = false
                }
                .font(.subheadline.weight(.semibold))
                .buttonStyle(.borderedProminent)
                .tint(Palette.ink)
                .foregroundStyle(Palette.inkText)
            }
            .padding(14)
            .background(Palette.warn.opacity(0.18), in: RoundedRectangle(cornerRadius: 18, style: .continuous))
        }
    }
}

// MARK: - Kleine Bausteine

struct Dot: View {
    let color: Color
    var size: CGFloat = 9
    var body: some View {
        RoundedRectangle(cornerRadius: 3).fill(color).frame(width: size, height: size)
    }
}

struct LegendItem: View {
    let color: Color
    let text: String
    var body: some View {
        HStack(spacing: 6) { Dot(color: color); Text(text) }
            .font(.caption)
    }
}

struct CatIcon: View {
    let cat: Cat
    var size: CGFloat = 38

    var body: some View {
        Image(systemName: cat.symbol)
            .font(.system(size: size * 0.42, weight: .semibold))
            .foregroundStyle(.white)
            .frame(width: size, height: size)
            .background(cat.color, in: RoundedRectangle(cornerRadius: size * 0.29, style: .continuous))
    }
}

struct Ring: View {
    let progress: Double
    var size: CGFloat = 96
    var line: CGFloat = 11
    var color: Color = Palette.saving

    var body: some View {
        ZStack {
            Circle().stroke(Color(.tertiarySystemFill), lineWidth: line)
            Circle()
                .trim(from: 0, to: max(0.001, min(1, progress)))
                .stroke(color, style: StrokeStyle(lineWidth: line, lineCap: .round))
                .rotationEffect(.degrees(-90))
            Text(Fmt.pct(progress)).font(.system(size: size * 0.19, weight: .bold)).monospacedDigit()
        }
        .frame(width: size, height: size)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("\(Fmt.pct(progress)) erreicht")
    }
}

struct ProgressBar: View {
    let value: Double
    let color: Color

    var body: some View {
        GeometryReader { geo in
            ZStack(alignment: .leading) {
                Capsule().fill(Color(.tertiarySystemFill))
                Capsule().fill(color).frame(width: max(0, min(1, value)) * geo.size.width)
            }
        }
        .frame(height: 8)
    }
}

struct EntryRow: View {
    let entry: Entry

    var body: some View {
        HStack(spacing: 12) {
            CatIcon(cat: entry.cat)
            VStack(alignment: .leading, spacing: 2) {
                HStack(spacing: 6) {
                    Text(entry.cat.name).font(.body.weight(.semibold)).lineLimit(1)
                    if entry.ruleID != nil { Tag("monatlich") }
                    if entry.kind == .saving { Tag("Sparen") }
                }
                Text(entry.note.isEmpty ? entry.kind.single : entry.note)
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
            }
            Spacer(minLength: 8)
            Text(sign + " " + Fmt.eur(entry.amount))
                .font(.body.weight(.semibold))
                .monospacedDigit()
                .foregroundStyle(entry.kind == .income ? Palette.income : .primary)
                .lineLimit(1)
                .fixedSize()
        }
        .contentShape(Rectangle())
    }

    private var sign: String {
        switch entry.kind {
        case .income: return "+"
        case .expense: return "−"
        case .saving: return "→"
        }
    }
}

struct Tag: View {
    let text: String
    init(_ text: String) { self.text = text }
    var body: some View {
        Text(text.uppercased())
            .font(.system(size: 9, weight: .bold))
            .tracking(0.4)
            .padding(.horizontal, 6)
            .padding(.vertical, 2)
            .background(Color(.tertiarySystemFill), in: RoundedRectangle(cornerRadius: 5))
            .foregroundStyle(.secondary)
    }
}

struct Pill: View {
    let text: String
    let symbol: String
    let color: Color

    var body: some View {
        Label(text, systemImage: symbol)
            .font(.caption.weight(.bold))
            .padding(.horizontal, 9)
            .padding(.vertical, 4)
            .background(color.opacity(0.2), in: Capsule())
    }
}

struct KPITile: View {
    let kind: Kind
    let value: Double
    var caption: String? = nil

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            HStack(spacing: 6) {
                Dot(color: kind.color)
                Text(kind.title).font(.caption).foregroundStyle(.secondary).lineLimit(1).minimumScaleFactor(0.8)
            }
            Text(Fmt.eur(value))
                .font(.system(.headline, design: .default).weight(.bold))
                .monospacedDigit()
                .lineLimit(1)
                .minimumScaleFactor(0.55)
            if let caption {
                Text(caption).font(.caption2).foregroundStyle(.tertiary).lineLimit(2)
            }
        }
        .padding(12)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Color(.secondarySystemGroupedBackground), in: RoundedRectangle(cornerRadius: 18, style: .continuous))
    }
}

/// Einfache Chip-Auswahl in Zeilen, die umbrechen.
struct ChipGrid<Item: Identifiable, ChipLabel: View>: View {
    let items: [Item]
    var minWidth: CGFloat = 104
    @ViewBuilder let label: (Item) -> ChipLabel

    var body: some View {
        LazyVGrid(columns: [GridItem(.adaptive(minimum: minWidth), spacing: 8)], spacing: 8) {
            ForEach(items) { label($0) }
        }
    }
}
