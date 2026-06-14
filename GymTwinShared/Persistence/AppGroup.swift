import Foundation

/// Shared configuration for the App Group container that lets the iOS app and
/// the watchOS app read the same on-disk SwiftData store.
enum AppGroup {
    /// Must match the `com.apple.security.application-groups` entitlement on
    /// both the iOS and watchOS targets.
    static let identifier = "group.com.markusvaitl.gymtwin"

    /// File name of the SwiftData store inside the group container.
    static let storeName = "GymTwin.store"
}
