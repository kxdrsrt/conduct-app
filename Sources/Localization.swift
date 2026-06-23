import Foundation

/// Localization helper - wraps NSLocalizedString for cleaner call sites
func L(_ key: String) -> String {
    NSLocalizedString(key, tableName: nil, bundle: Bundle.main, value: key, comment: "")
}
