import Foundation

extension UserDefaults {
    static let app: UserDefaults = {
        #if DEBUG
        return UserDefaults(suiteName: "com.memoria.debug") ?? .standard
        #else
        return .standard
        #endif
    }()
}
