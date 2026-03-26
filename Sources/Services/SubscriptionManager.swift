import Foundation
import StoreKit

/// R16: Subscription management for Mark
@available(macOS 13.0, *)
public final class MarkSubscriptionManager: ObservableObject {
    public static let shared = MarkSubscriptionManager()
    @Published public private(set) var subscription: MarkSubscription?
    @Published public private(set) var products: [Product] = []
    
    private init() {}
    
    public func loadProducts() async {
        do {
            products = try await Product.products(for: [
                "com.mark.macos.pro.monthly",
                "com.mark.macos.pro.yearly",
                "com.mark.macos.team.monthly",
                "com.mark.macos.team.yearly"
            ])
        } catch { print("Failed to load products") }
    }
    
    public func canAccess(_ feature: MarkFeature) -> Bool {
        guard let sub = subscription else { return false }
        switch feature {
        case .advancedAnnotations: return sub.tier != .free
        case .cloudExport: return sub.tier != .free
        case .widgets: return sub.tier != .free
        case .shortcuts: return sub.tier != .free
        case .teamSharing: return sub.tier == .team
        }
    }
    
    public func updateStatus() async {
        var found: MarkSubscription = MarkSubscription(tier: .free)
        for await result in Transaction.currentEntitlements {
            do {
                let t = try checkVerified(result)
                if t.productID.contains("team") {
                    found = MarkSubscription(tier: .team, status: t.revocationDate == nil ? "active" : "expired")
                } else if t.productID.contains("pro") {
                    found = MarkSubscription(tier: .pro, status: t.revocationDate == nil ? "active" : "expired")
                }
            } catch { continue }
        }
        await MainActor.run { self.subscription = found }
    }
    
    public func restore() async throws {
        try await AppStore.sync()
        await updateStatus()
    }
    
    private func checkVerified<T>(_ r: VerificationResult<T>) throws -> T {
        switch r { case .unverified: throw NSError(domain: "Mark", code: -1); case .verified(let s): return s }
    }
}

public enum MarkFeature { case advancedAnnotations, cloudExport, widgets, shortcuts, teamSharing }
