import Foundation
import zlib

/// Offline UN/LOCODE port cut (Function position 1 = port).
/// Coordinates come only from the file. Empty lat/lon stays empty — never invented.
nonisolated enum PortUnlocodeCatalog {
    static let credit = "UN/LOCODE 2025-1, UNECE"
    static let noPosition = "No position"
    static let functionLabel = "Port"
    static let pickResult = "Pick a result"
    static let resourceFileName = "ports.csv.gz"

    enum LoadError: Error {
        case missingResource
        case gzip
        case unreadable
    }

    struct Port: Identifiable, Equatable, Sendable {
        var id: String
        var code: String
        var countryCode: String
        var name: String
        var subdivisionCode: String
        var functionCode: String
        /// Decimal degrees from the file. Nil when the cell is empty.
        var latitude: Double?
        var longitude: Double?
        var coordinateLabel: String
        var countryName: String
        var countryLine: String
        var subdivisionLabel: String
        var placeLine: String
        var resultAccessibilityIdentifier: String
        var codeKey: String
        var nameKey: String
        var plainKey: String

        var hasPosition: Bool { latitude != nil && longitude != nil }
    }

    enum MapState: Equatable {
        case pickResult
        case pin(latitude: Double, longitude: Double)
        case noPosition
    }

    /// Pin only when both file coordinates exist. Otherwise no pin.
    static func mapState(for port: Port?) -> MapState {
        guard let port else { return .pickResult }
        if let latitude = port.latitude, let longitude = port.longitude {
            return .pin(latitude: latitude, longitude: longitude)
        }
        return .noPosition
    }

    static func loadBundled() throws -> [Port] {
        var seen = Set<ObjectIdentifier>()
        for bundle in [Bundle(for: PortUnlocodeBundleToken.self), Bundle.main] {
            let token = ObjectIdentifier(bundle)
            if seen.contains(token) { continue }
            seen.insert(token)
            if let url = bundledGzipURL(in: bundle) {
                return try ports(fromGzip: Data(contentsOf: url))
            }
        }
        throw LoadError.missingResource
    }

    static func ports(fromGzip data: Data) throws -> [Port] {
        let inflated = try gunzip(data)
        guard let text = String(data: inflated, encoding: .utf8) else {
            throw LoadError.unreadable
        }
        let ports = parseCSV(text)
        if ports.isEmpty { throw LoadError.unreadable }
        return ports
    }

    /// Case-insensitive. Code: exact or prefix. Name: substring of `name` or `nameWoDiacritics`.
    static func search(_ ports: [Port], query: String) -> [Port] {
        let q = searchKey(query)
        guard !q.isEmpty else { return [] }
        var exact: [Port] = []
        var prefix: [Port] = []
        var names: [Port] = []
        exact.reserveCapacity(2)
        for port in ports {
            if port.codeKey == q {
                exact.append(port)
            } else if port.codeKey.hasPrefix(q) {
                prefix.append(port)
            } else if port.nameKey.contains(q) || port.plainKey.contains(q) {
                names.append(port)
            }
        }
        exact.sort(by: byName)
        prefix.sort(by: byName)
        names.sort(by: byName)
        return exact + prefix + names
    }

    /// `5858N 00545E` → `58° 58' N 5° 45' E`. Nil when the field is not that UNECE shape.
    static func formatCoordinateField(_ raw: String) -> String? {
        let s = raw.trimmingCharacters(in: .whitespacesAndNewlines)
        guard s.count == 12 else { return nil }
        let chars = Array(s)
        let latH = chars[4]
        let lonH = chars[11]
        guard (latH == "N" || latH == "S"), chars[5] == " ", (lonH == "E" || lonH == "W") else {
            return nil
        }
        let latDigits = chars[0..<4]
        let lonDigits = chars[6..<11]
        guard latDigits.allSatisfy(\.isNumber), lonDigits.allSatisfy(\.isNumber) else { return nil }
        let latDeg = Int(String(latDigits[0..<2])) ?? 0
        let latMin = String(latDigits[2..<4])
        let lonDeg = Int(String(lonDigits[0..<3])) ?? 0
        let lonMin = String(lonDigits[3..<5])
        return "\(latDeg)° \(latMin)' \(latH) \(lonDeg)° \(lonMin)' \(lonH)"
    }

    static func countryName(for code: String) -> String {
        switch code {
        case "NO": return "Norway"
        case "GB": return "United Kingdom"
        case "XZ": return "International waters"
        default:
            let locale = Locale(identifier: "en_US")
            if let name = locale.localizedString(forRegionCode: code), !name.isEmpty {
                return name
            }
            return code
        }
    }

    /// Norwegian counties in this cut. Code 12 is shown as Vestland (Bergen), matching the screen mock.
    static func subdivisionLabel(country: String, code: String) -> String {
        let trimmed = code.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return "" }
        if country == "NO", let name = norwaySubdivisionNames[trimmed] {
            return name
        }
        return trimmed
    }

    // MARK: - Private

    private static let searchLocale = Locale(identifier: "en_US_POSIX")

    private static let norwaySubdivisionNames: [String: String] = [
        "01": "Østfold",
        "02": "Akershus",
        "03": "Oslo",
        "05": "Oppland",
        "06": "Buskerud",
        "07": "Vestfold",
        "08": "Telemark",
        "09": "Aust-Agder",
        "10": "Vest-Agder",
        "11": "Rogaland",
        "12": "Vestland",
        "14": "Sogn og Fjordane",
        "15": "Møre og Romsdal",
        "16": "Sør-Trøndelag",
        "17": "Nord-Trøndelag",
        "18": "Nordland",
        "19": "Troms",
        "20": "Finnmark"
    ]

    private static func searchKey(_ text: String) -> String {
        text.trimmingCharacters(in: .whitespacesAndNewlines).lowercased(with: searchLocale)
    }

    private static func byName(_ a: Port, _ b: Port) -> Bool {
        if a.nameKey != b.nameKey { return a.nameKey < b.nameKey }
        return a.codeKey < b.codeKey
    }

    private static func bundledGzipURL(in bundle: Bundle) -> URL? {
        if let url = bundle.url(forResource: "ports.csv", withExtension: "gz") {
            return url
        }
        if let url = bundle.url(forResource: "ports.csv", withExtension: "gz", subdirectory: "Features/Tools") {
            return url
        }
        guard let root = bundle.resourceURL else { return nil }
        guard let enumerator = FileManager.default.enumerator(
            at: root,
            includingPropertiesForKeys: nil,
            options: [.skipsHiddenFiles]
        ) else { return nil }
        for case let url as URL in enumerator where url.lastPathComponent == resourceFileName {
            return url
        }
        return nil
    }

    private static func parseCSV(_ text: String) -> [Port] {
        var source = text
        if source.hasPrefix("\u{feff}") {
            source.removeFirst()
        }
        let chars = Array(source)
        var records: [[String]] = []
        var field = ""
        var record: [String] = []
        var inQuotes = false
        var index = 0
        while index < chars.count {
            let character = chars[index]
            if inQuotes {
                if character == "\"" {
                    if index + 1 < chars.count, chars[index + 1] == "\"" {
                        field.append("\"")
                        index += 2
                        continue
                    }
                    inQuotes = false
                    index += 1
                    continue
                }
                field.append(character)
                index += 1
                continue
            }
            switch character {
            case "\"":
                inQuotes = true
                index += 1
            case ",":
                record.append(field)
                field = ""
                index += 1
            case "\n", "\r":
                if character == "\r", index + 1 < chars.count, chars[index + 1] == "\n" {
                    index += 1
                }
                record.append(field)
                field = ""
                if !(record.count == 1 && record[0].isEmpty) {
                    records.append(record)
                }
                record = []
                index += 1
            default:
                field.append(character)
                index += 1
            }
        }
        if !field.isEmpty || !record.isEmpty {
            record.append(field)
            if !(record.count == 1 && record[0].isEmpty) {
                records.append(record)
            }
        }

        var ports: [Port] = []
        ports.reserveCapacity(max(0, records.count - 1))
        var seenCodes: [String: Int] = [:]
        for raw in records {
            guard raw.count >= 12 else { continue }
            let code = raw[0].trimmingCharacters(in: .whitespacesAndNewlines)
            if code.isEmpty || code == "code" { continue }
            let country = raw[1].trimmingCharacters(in: .whitespacesAndNewlines)
            let name = raw[3].trimmingCharacters(in: .whitespacesAndNewlines)
            let plain = raw[4].trimmingCharacters(in: .whitespacesAndNewlines)
            let subdivision = raw[5].trimmingCharacters(in: .whitespacesAndNewlines)
            let function = raw[6].trimmingCharacters(in: .whitespacesAndNewlines)
            let coordinates = raw[8].trimmingCharacters(in: .whitespacesAndNewlines)
            let latitude = decimal(raw[9])
            let longitude = decimal(raw[10])
            let occurrence = (seenCodes[code] ?? 0) + 1
            seenCodes[code] = occurrence
            let resolvedCountry = countryName(for: country)
            let resolvedSubdivision = subdivisionLabel(country: country, code: subdivision)
            let placeLine = resolvedSubdivision.isEmpty ? resolvedCountry : "\(resolvedCountry) · \(resolvedSubdivision)"
            // Degrees come from the UNECE field. No lat/lon in the file → "No position", even if a
            // coordinate string were present. Never fill a missing cell with 0.
            let coordinateLabel: String
            if let latitude, let longitude {
                coordinateLabel = formatCoordinateField(coordinates)
                    ?? formatDecimal(latitude: latitude, longitude: longitude)
            } else {
                coordinateLabel = noPosition
            }
            let identifier = occurrence == 1
                ? "portUnlocode.result.\(code)"
                : "portUnlocode.result.\(code).\(occurrence)"
            ports.append(Port(
                id: "\(code)#\(occurrence)",
                code: code,
                countryCode: country,
                name: name,
                subdivisionCode: subdivision,
                functionCode: function,
                latitude: latitude,
                longitude: longitude,
                coordinateLabel: coordinateLabel,
                countryName: resolvedCountry,
                countryLine: resolvedCountry == country ? country : "\(resolvedCountry) (\(country))",
                subdivisionLabel: resolvedSubdivision,
                placeLine: placeLine,
                resultAccessibilityIdentifier: identifier,
                codeKey: searchKey(code),
                nameKey: searchKey(name),
                plainKey: searchKey(plain.isEmpty ? name : plain)
            ))
        }
        return ports
    }

    /// Fallback when the file has decimal degrees but not the `DDMMH DDDMMH` field.
    private static func formatDecimal(latitude: Double, longitude: Double) -> String {
        "\(hemisphere(latitude, positive: "N", negative: "S")) \(hemisphere(longitude, positive: "E", negative: "W"))"
    }

    private static func hemisphere(_ value: Double, positive: String, negative: String) -> String {
        let sign = value >= 0 ? positive : negative
        let absolute = abs(value)
        var degrees = Int(absolute)
        var minutes = Int(((absolute - Double(degrees)) * 60).rounded())
        if minutes == 60 {
            minutes = 0
            degrees += 1
        }
        return "\(degrees)° \(String(format: "%02d", minutes))' \(sign)"
    }

    /// Empty cell → nil. A real 0 (prime meridian) stays 0.
    private static func decimal(_ raw: String) -> Double? {
        let trimmed = raw.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty, let value = Double(trimmed), value.isFinite else { return nil }
        return value
    }

    private static func gunzip(_ data: Data) throws -> Data {
        guard !data.isEmpty else { throw LoadError.gzip }
        return try data.withUnsafeBytes { raw in
            guard let base = raw.bindMemory(to: Bytef.self).baseAddress else {
                throw LoadError.gzip
            }
            try ZLIB_VERSION.withCString { version in
                var stream = z_stream()
                stream.next_in = UnsafeMutablePointer(mutating: base)
                stream.avail_in = uInt(raw.count)
                let status = inflateInit2_(&stream, Int32(15 + 32), version, Int32(MemoryLayout<z_stream>.size))
                guard status == Z_OK else { throw LoadError.gzip }
                defer { inflateEnd(&stream) }

                var output = Data()
                output.reserveCapacity(max(raw.count * 3, 64 * 1024))
                let chunk = 32_768
                let buffer = UnsafeMutablePointer<Bytef>.allocate(capacity: chunk)
                defer { buffer.deallocate() }
                var loops = 0
                while true {
                    loops += 1
                    if loops > 10_000 { throw LoadError.gzip }
                    stream.next_out = buffer
                    stream.avail_out = uInt(chunk)
                    let inflateStatus = inflate(&stream, Z_NO_FLUSH)
                    let produced = chunk - Int(stream.avail_out)
                    if produced > 0 {
                        output.append(buffer, count: produced)
                    }
                    switch inflateStatus {
                    case Z_STREAM_END:
                        return output
                    case Z_OK:
                        if produced == 0, stream.avail_in == 0 { throw LoadError.gzip }
                    default:
                        throw LoadError.gzip
                    }
                }
            }
        }
    }
}

/// Anchor so `Bundle(for:)` resolves the app bundle that contains `ports.csv.gz`.
nonisolated private final class PortUnlocodeBundleToken: NSObject {}
