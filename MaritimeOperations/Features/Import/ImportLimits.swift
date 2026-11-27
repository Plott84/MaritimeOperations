import Foundation

/// Hard bounds for Import. A DP logbook export is far smaller than either cap.
/// `import.error.tooLarge` and `import.error.tooManyEntries` are the copy keys for the alerts.
enum ImportLimits {
    /// 5 MB. Measured with `URLResourceValues.fileSizeKey` before the file is read.
    static let maxFileBytes = 5 * 1024 * 1024
    /// Entries across every book in one file, checked after a successful decode.
    static let maxEntries = 20_000
}

/// Pure size and entry-count gate. Nothing is written from here.
/// A nil `byteCount` means the security-scoped URL did not report `.fileSizeKey`.
enum ImportValidator {
    static func validate(byteCount: Int?, entryCount: Int) -> Result<Void, ImportLimitError> {
        if let byteCount {
            if byteCount > ImportLimits.maxFileBytes {
                return .failure(.tooLarge(byteCount: byteCount))
            }
        } else {
            return .failure(.tooLarge(byteCount: nil))
        }
        if entryCount > ImportLimits.maxEntries {
            return .failure(.tooManyEntries(entryCount: entryCount))
        }
        return .success(())
    }
}

enum ImportLimitFormatting {
    /// `ByteCountFormatter` with the `.file` count style (Finder units, current locale).
    static func fileSize(_ bytes: Int) -> String {
        let formatter = ByteCountFormatter()
        formatter.countStyle = .file
        return formatter.string(fromByteCount: Int64(bytes))
    }

    /// Thousands separators follow `locale` (the current locale unless a test passes one).
    static func entryCount(_ count: Int, locale: Locale = .current) -> String {
        count.formatted(.number.locale(locale))
    }
}

enum ImportLimitCopy {
    /// `import.error.tooLarge`
    static let tooLargeKey = "import.error.tooLarge"
    /// `import.error.tooManyEntries`
    static let tooManyEntriesKey = "import.error.tooManyEntries"

    static let tooLargeTitle = "File too large"
    static let tooManyEntriesTitle = "Too many entries"
    static let chooseAnotherFile = "Choose Another File"
    static let tooLargeIdentifier = "importErrorTooLarge"
    static let tooManyEntriesIdentifier = "importErrorTooManyEntries"
}

enum ImportLimitError: Error, Equatable, Sendable {
    /// `import.error.tooLarge`. Nil `byteCount` means the size could not be read.
    case tooLarge(byteCount: Int?)
    /// `import.error.tooManyEntries`
    case tooManyEntries(entryCount: Int)

    var title: String {
        switch self {
        case .tooLarge:
            ImportLimitCopy.tooLargeTitle
        case .tooManyEntries:
            ImportLimitCopy.tooManyEntriesTitle
        }
    }

    var accessibilityIdentifier: String {
        switch self {
        case .tooLarge:
            ImportLimitCopy.tooLargeIdentifier
        case .tooManyEntries:
            ImportLimitCopy.tooManyEntriesIdentifier
        }
    }

    var message: String {
        switch self {
        case .tooLarge(let byteCount):
            if let byteCount {
                let size = ImportLimitFormatting.fileSize(byteCount)
                return "This file is \(size). Maritime Operations can import files up to 5 MB. Nothing was imported and your entries are unchanged."
            }
            return "This file is larger than 5 MB and can't be imported. Your entries are unchanged."
        case .tooManyEntries(let entryCount):
            let count = ImportLimitFormatting.entryCount(entryCount)
            return "This file has \(count) entries. Maritime Operations can import up to 20,000 at a time. Nothing was imported and your entries are unchanged."
        }
    }
}
