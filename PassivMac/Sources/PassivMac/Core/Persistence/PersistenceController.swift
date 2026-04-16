import Foundation
import SwiftData

/// Configures and owns the SwiftData ModelContainer for the app.
/// Use `PersistenceController.shared` everywhere except tests.
@MainActor
final class PersistenceController {

    static let shared = PersistenceController()

    let container: ModelContainer

    private init() {
        let schema = Schema([
            BrokerageConnection.self,
            Account.self,
            PortfolioGroup.self,
            Security.self,
            Position.self,
            Balance.self,
            TargetAllocation.self,
            CalculatedTrade.self,
            Order.self,
            PortfolioSnapshot.self,
            DividendRecord.self,
        ])
        let config = ModelConfiguration(
            schema: schema,
            isStoredInMemoryOnly: false
        )
        do {
            container = try ModelContainer(for: schema, configurations: [config])
        } catch {
            fatalError("Failed to create ModelContainer: \(error)")
        }
    }

    /// In-memory container for SwiftUI previews and unit tests.
    static func preview() -> ModelContainer {
        let schema = Schema([
            BrokerageConnection.self,
            Account.self,
            PortfolioGroup.self,
            Security.self,
            Position.self,
            Balance.self,
            TargetAllocation.self,
            CalculatedTrade.self,
            Order.self,
            PortfolioSnapshot.self,
            DividendRecord.self,
        ])
        let config = ModelConfiguration(schema: schema, isStoredInMemoryOnly: true)
        do {
            return try ModelContainer(for: schema, configurations: [config])
        } catch {
            fatalError("Failed to create preview ModelContainer: \(error)")
        }
    }
}
