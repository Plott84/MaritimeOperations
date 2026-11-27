import Foundation

/// Hard bounds for Import. A DP logbook export is far smaller than either cap.
/// Copy keys: `import.error.tooLarge`, `import.error.unknownSize`, `import.error.tooManyEntries`.
enum ImportLimits {
    /// 5 MB. Measured with `URLResourceValues.fileSizeKey` before the file is read.
    static let maxFileBytes = 5 * 1024 * 1024
    /// Entries across every book in one file, checked after a successful decode.
    static let maxEntries = 20_000
}

/// Pure size and entry-count gate. Nothing is written from here.
/// A nil `byteCount` means the security-scoped URL did not report `.fileSizeKey`.
/// That is its own failure. `tooLarge` is only a known size over the cap.
enum ImportValidator {
    static func validate(byteCount: Int?, entryCount: Int) -> Result<Void, ImportLimitError> {
        guard let byteCount else {
            return .failure(.unknownSize)
        }
        if byteCount > ImportLimits.maxFileBytes {
            return .failure(.tooLarge(byteCount: byteCount))
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
    /// `import.error.unknownSize`
    static let unknownSizeKey = "import.error.unknownSize"
    /// `import.error.tooManyEntries`
    static let tooManyEntriesKey = "import.error.tooManyEntries"

    static let tooLargeTitle = "File too large"
    static let unknownSizeTitle = "Can't check this file"
    static let tooManyEntriesTitle = "Too many entries"
    static let chooseAnotherFile = "Choose Another File"
    static let tooLargeIdentifier = "importErrorTooLarge"
    static let unknownSizeIdentifier = "importErrorUnknownSize"
    static let tooManyEntriesIdentifier = "importErrorTooManyEntries"
}

enum ImportLimitError: Error, Equatable, Sendable {
    /// `import.error.tooLarge`. The size was read and it is over the cap.
    case tooLarge(byteCount: Int)
    /// `import.error.unknownSize`. `.fileSizeKey` could not be read, so the bytes are not loaded.
    case unknownSize
    /// `import.error.tooManyEntries`
    case tooManyEntries(entryCount: Int)

    var title: String {
        switch self {
        case .tooLarge:
            ImportLimitCopy.tooLargeTitle
        case .unknownSize:
            ImportLimitCopy.unknownSizeTitle
        case .tooManyEntries:
            ImportLimitCopy.tooManyEntriesTitle
        }
    }

    var accessibilityIdentifier: String {
        switch self {
        case .tooLarge:
            ImportLimitCopy.tooLargeIdentifier
        case .unknownSize:
            ImportLimitCopy.unknownSizeIdentifier
        case .tooManyEntries:
            ImportLimitCopy.tooManyEntriesIdentifier
        }
    }

    var message: String {
        switch self {
        case .tooLarge(let byteCount):
            let size = ImportLimitFormatting.fileSize(byteCount)
            return "This file is \(size). Maritime Operations can import files up to 5 MB. Nothing was imported and your entries are unchanged."
        case .unknownSize:
            return "Maritime Operations couldn't read this file's size, so nothing was imported. Your entries are unchanged."
        case .tooManyEntries(let entryCount):
            let count = ImportLimitFormatting.entryCount(entryCount)
            return "This file has \(count) entries. Maritime Operations can import up to 20,000 at a time. Nothing was imported and your entries are unchanged."
        }
    }
}
