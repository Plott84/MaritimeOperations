import Foundation
import Testing
@testable import MaritimeOperations

struct PortUnlocodeTests {
    private static let loaded = Result<[PortUnlocodeCatalog.Port], Error> {
        try PortUnlocodeCatalog.loadBundled()
    }

    private static var ports: [PortUnlocodeCatalog.Port] {
        (try? loaded.get()) ?? []
    }

    @Test func creditString() {
        #expect(PortUnlocodeCatalog.credit == "UN/LOCODE 2025-1, UNECE")
        #expect(PortUnlocodeCatalog.noPosition == "No position")
        #expect(PortUnlocodeCatalog.functionLabel == "Port")
    }

    @Test func loaderDecompressesGzipPortCut() throws {
        let ports = try Self.loaded.get()
        #expect(ports.count == 17600)
        #expect(ports.allSatisfy { $0.functionCode.first == "1" })
    }

    @Test func stavanger() throws {
        let port = try known("NOSVG")
        #expect(port.name == "Stavanger")
        #expect(port.coordinateLabel == "58° 58' N 5° 45' E")
        expectCoordinates(port, latitude: 58.966667, longitude: 5.75)
        #expect(PortUnlocodeCatalog.mapState(for: port) == .pin(latitude: port.latitude!, longitude: port.longitude!))
    }

    @Test func bergen() throws {
        let port = try known("NOBGO")
        #expect(port.name == "Bergen")
        #expect(port.coordinateLabel == "60° 23' N 5° 19' E")
        #expect(port.subdivisionLabel == "Vestland")
        expectCoordinates(port, latitude: 60.383333, longitude: 5.316667)
    }

    @Test func bronnoySundByCodeAndName() throws {
        let byCode = try #require(PortUnlocodeCatalog.search(Self.ports, query: "NOBNN").first)
        #expect(byCode.code == "NOBNN")
        #expect(byCode.name == "Brønnøysund")
        #expect(byCode.coordinateLabel == "65° 28' N 12° 12' E")
        #expect(byCode.countryLine == "Norway (NO)")
        #expect(byCode.subdivisionLabel == "Nordland")
        #expect(byCode.placeLine == "Norway · Nordland")
        expectCoordinates(byCode, latitude: 65.466667, longitude: 12.2)

        let lower = try #require(PortUnlocodeCatalog.search(Self.ports, query: "nobnn").first { $0.code == "NOBNN" })
        #expect(lower.name == "Brønnøysund")

        for query in ["bronno", "Bronnoysund"] {
            let hit = try #require(PortUnlocodeCatalog.search(Self.ports, query: query).first { $0.code == "NOBNN" })
            #expect(hit.name == "Brønnøysund")
            expectCoordinates(hit, latitude: 65.466667, longitude: 12.2)
        }
    }

    @Test func londonAndAlstahaugHaveNoPosition() throws {
        let london = try known("GBLON")
        #expect(london.name == "London")
        #expect(london.countryLine == "United Kingdom (GB)")
        #expect(london.latitude == nil)
        #expect(london.longitude == nil)
        #expect(london.hasPosition == false)
        #expect(london.coordinateLabel == PortUnlocodeCatalog.noPosition)
        #expect(PortUnlocodeCatalog.mapState(for: london) == .noPosition)

        let alstahaug = try known("NOALS")
        #expect(alstahaug.name == "Alstahaug")
        #expect(alstahaug.latitude == nil)
        #expect(alstahaug.longitude == nil)
        #expect(alstahaug.hasPosition == false)
        #expect(alstahaug.coordinateLabel == PortUnlocodeCatalog.noPosition)
        #expect(PortUnlocodeCatalog.mapState(for: alstahaug) == .noPosition)
        #expect(PortUnlocodeCatalog.mapState(for: nil) == .pickResult)
    }

    @Test func otherKnownPorts() throws {
        let expected: [(String, String, Double, Double, String)] = [
            ("NOOSL", "Oslo", 59.9, 10.733333, "59° 54' N 10° 44' E"),
            ("NOTRD", "Trondheim", 63.433333, 10.4, "63° 26' N 10° 24' E"),
            ("NLRTM", "Rotterdam", 51.916667, 4.5, "51° 55' N 4° 30' E"),
            ("SGSIN", "Singapore", 1.283333, 103.85, "1° 17' N 103° 51' E"),
            ("USNYC", "New York", 40.7, -74.0, "40° 42' N 74° 00' W"),
            ("DEHAM", "Hamburg", 53.516667, 9.933333, "53° 31' N 9° 56' E"),
            ("CNSGH", "Shanghai", 31.233333, 121.483333, "31° 14' N 121° 29' E")
        ]
        for row in expected {
            let port = try known(row.0)
            #expect(port.name == row.1)
            #expect(port.coordinateLabel == row.4)
            expectCoordinates(port, latitude: row.2, longitude: row.3)
        }
    }

    @Test func nameSearchStavangerAndCodeIsPrefixNotSubstring() throws {
        let stavanger = try #require(PortUnlocodeCatalog.search(Self.ports, query: "stavanger").first { $0.code == "NOSVG" })
        #expect(stavanger.name == "Stavanger")
        let notPrefix = PortUnlocodeCatalog.search(Self.ports, query: "svg")
        #expect(notPrefix.contains { $0.code == "NOSVG" } == false)
        #expect(PortUnlocodeCatalog.search(Self.ports, query: "   ").isEmpty)
    }

    @Test func primeMeridianIsARealPosition() throws {
        let port = try known("GBPHV")
        #expect(port.longitude == 0)
        #expect(port.hasPosition == true)
        if case .pin(_, let longitude) = PortUnlocodeCatalog.mapState(for: port) {
            #expect(longitude == 0)
        } else {
            Issue.record("Expected a pin at longitude 0")
        }
    }

    @Test func rejectsNonGzip() {
        #expect(throws: PortUnlocodeCatalog.LoadError.self) {
            try PortUnlocodeCatalog.ports(fromGzip: Data("not gzip".utf8))
        }
    }

    private func known(_ code: String) throws -> PortUnlocodeCatalog.Port {
        try #require(Self.ports.first { $0.code == code })
    }

    private func expectCoordinates(
        _ port: PortUnlocodeCatalog.Port,
        latitude: Double,
        longitude: Double
    ) {
        #expect(abs((port.latitude ?? 999) - latitude) < 0.001)
        #expect(abs((port.longitude ?? 999) - longitude) < 0.001)
        #expect(port.hasPosition)
    }
}
