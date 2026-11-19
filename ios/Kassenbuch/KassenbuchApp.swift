import SwiftUI
import SwiftData
import LocalAuthentication

@main
struct KassenbuchApp: App {
    var body: some Scene {
        WindowGroup {
            RootView()
                .environment(\.locale, Fmt.de)
        }
        .modelContainer(for: [Entry.self, RecurringRule.self, SavingsGoal.self])
    }
}

// MARK: - Gemeinsamer Zustand der Oberfläche

enum AppTab: Hashable { case overview, entries, year, savings, more }

enum ListFilter: Hashable, CaseIterable {
    case all, income, passive, expense, saving

    var title: String {
        switch self {
        case .all: return "Alle"
        case .income: return "Einnahmen"
        case .passive: return "Zinsen · Mieten · Dividenden"
        case .expense: return "Ausgaben"
        case .saving: return "Ersparnisse"
        }
    }

    func matches(_ e: Entry) -> Bool {
        switch self {
        case .all: return true
        case .income: return e.kind == .income
        case .passive: return e.kind == .income && e.cat.isPassive
        case .expense: return e.kind == .expense
        case .saving: return e.kind == .saving
        }
    }

    static func from(_ kind: Kind) -> ListFilter {
        switch kind {
        case .income: return .income
        case .expense: return .expense
        case .saving: return .saving
        }
    }
}

enum EditorTarget: Identifiable {
    case new(Kind)
    case edit(Entry)

    var id: String {
        switch self {
        case .new(let k): return "new-\(k.rawValue)"
        case .edit(let e): return e.uid.uuidString
        }
    }
}

@Observable
final class AppState {
    var month = YM.now
    var year = YM.now.year
    var tab: AppTab = .overview
    var filter: ListFilter = .all
    var editor: EditorTarget?

    var defaultDate: Date { month == .now ? Date() : month.firstDay }

    var defaultKind: Kind {
        switch tab {
        case .savings: return .saving
        case .entries:
            switch filter {
            case .income, .passive: return .income
            case .saving: return .saving
            default: return .expense
            }
        default: return .expense
        }
    }
}

// MARK: - App-Sperre (Face ID / Code)

@Observable
final class AppLock {
    var locked = false
    private var busy = false

    func unlock() {
        guard !busy else { return }
        let ctx = LAContext()
        var error: NSError?
        guard ctx.canEvaluatePolicy(.deviceOwnerAuthentication, error: &error) else {
            locked = false
            return
        }
        busy = true
        ctx.evaluatePolicy(.deviceOwnerAuthentication, localizedReason: "Kassenbuch entsperren") { ok, _ in
            DispatchQueue.main.async {
                self.busy = false
                if ok { self.locked = false }
            }
        }
    }
}

// MARK: - Hauptansicht

struct RootView: View {
    @Environment(\.modelContext) private var context
    @Environment(\.scenePhase) private var phase
    @State private var state = AppState()
    @State private var lock = AppLock()
    @AppStorage("seeded") private var seeded = false
    @AppStorage("demoActive") private var demo = false
    @AppStorage("lockEnabled") private var lockEnabled = false
    @AppStorage("startSavings") private var startSavings = 0.0

    var body: some View {
        @Bindable var s = state
        TabView(selection: $s.tab) {
            OverviewView()
                .tabItem { Label("Übersicht", systemImage: "chart.pie") }
                .tag(AppTab.overview)
            EntriesView()
                .tabItem { Label("Buchungen", systemImage: "list.bullet") }
                .tag(AppTab.entries)
            YearView()
                .tabItem { Label("Jahr", systemImage: "tablecells") }
                .tag(AppTab.year)
            SavingsView()
                .tabItem { Label("Sparen", systemImage: "banknote") }
                .tag(AppTab.savings)
            SettingsView()
                .tabItem { Label("Mehr", systemImage: "gearshape") }
                .tag(AppTab.more)
        }
        .overlay(alignment: .bottomTrailing) {
            if state.tab != .more {
                Button {
                    state.editor = .new(state.defaultKind)
                } label: {
                    Image(systemName: "plus")
                        .font(.system(size: 26, weight: .semibold))
                        .foregroundStyle(Palette.inkText)
                        .frame(width: 58, height: 58)
                        .background(Palette.ink, in: Circle())
                        .shadow(color: .black.opacity(0.22), radius: 12, y: 6)
                }
                .accessibilityLabel("Neue Buchung")
                .padding(.trailing, 18)
                .padding(.bottom, 62)
            }
        }
        .environment(state)
        .sheet(item: $s.editor) { target in
            EntryEditor(target: target, defaultDate: state.defaultDate)
                .environment(state)
                .environment(\.locale, Fmt.de)
        }
        .overlay {
            if lockEnabled && (lock.locked || phase != .active) {
                LockScreen(lock: lock)
            }
        }
        .task {
            if !seeded {
                let count = (try? context.fetchCount(FetchDescriptor<Entry>())) ?? 0
                if count == 0 {
                    DemoData.insert(into: context)
                    startSavings = DemoData.startSavings
                    demo = true
                }
                seeded = true
            }
            Recurring.materialize(context)
            if lockEnabled {
                lock.locked = true
                lock.unlock()
            }
        }
        .onChange(of: phase) { _, newPhase in
            if newPhase == .background && lockEnabled { lock.locked = true }
            if newPhase == .active {
                Recurring.materialize(context)
                if lockEnabled && lock.locked { lock.unlock() }
            }
        }
    }
}

struct LockScreen: View {
    let lock: AppLock

    var body: some View {
        ZStack {
            Rectangle().fill(.ultraThinMaterial).ignoresSafeArea()
            VStack(spacing: 16) {
                Image(systemName: "lock.fill").font(.system(size: 44))
                Text("Kassenbuch ist gesperrt").font(.title3.bold())
                if lock.locked {
                    Button("Entsperren") { lock.unlock() }
                        .buttonStyle(.borderedProminent)
                }
            }
        }
    }
}
