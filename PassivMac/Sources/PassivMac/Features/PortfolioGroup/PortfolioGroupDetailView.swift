import SwiftUI
import SwiftData

struct PortfolioGroupDetailView: View {
    let groupId: UUID

    @Query private var groups: [PortfolioGroup]
    @State private var selectedTab = Tab.overview

    private var group: PortfolioGroup? {
        groups.first(where: { $0.id == groupId })
    }

    enum Tab: String, CaseIterable, Identifiable {
        case overview    = "Overview"
        case targets     = "Targets"
        case rebalance   = "Rebalance"
        case performance = "Performance"

        var id: String { rawValue }
        var icon: String {
            switch self {
            case .overview:    return "list.bullet"
            case .targets:     return "target"
            case .rebalance:   return "arrow.2.circlepath"
            case .performance: return "chart.xyaxis.line"
            }
        }
    }

    var body: some View {
        if let group {
            VStack(spacing: 0) {
                Picker("Tab", selection: $selectedTab) {
                    ForEach(Tab.allCases) { tab in
                        Label(tab.rawValue, systemImage: tab.icon).tag(tab)
                    }
                }
                .pickerStyle(.segmented)
                .padding([.horizontal, .top])

                Divider().padding(.top, 8)

                switch selectedTab {
                case .overview:
                    HoldingsTableView(group: group)
                case .targets:
                    TargetAllocationEditorView(group: group)
                case .rebalance:
                    RebalanceView(group: group)
                case .performance:
                    PerformanceView(group: group)
                }
            }
            .navigationTitle(group.name)
        } else {
            ContentUnavailableView("Group not found", systemImage: "exclamationmark.triangle")
        }
    }
}
