import CoreLocation
import MapKit
import SwiftUI

/// Offline UN/LOCODE port lookup. Map pin only when the file has lat and lon.
struct PortUnlocodeToolView: View {
    @State private var model = PortUnlocodeToolModel()
    @FocusState private var searchFocused: Bool

    private let resultLimit = 100

    var body: some View {
        ZStack {
            AppCanvas()
            VStack(spacing: 12) {
                searchField
                mapCard
                detailCard
                credit
            }
            .padding(.horizontal, 16)
            .padding(.top, 8)
            .padding(.bottom, 8)
        }
        .navigationTitle("Port UN/LOCODE")
        .navigationBarTitleDisplayMode(.inline)
        .systemGlassNavigation()
        .toolsKeyboardDone()
        .task { model.loadIfNeeded() }
        .onChange(of: searchFocused) { _, focused in
            if focused { model.selectedID = nil }
        }
        .accessibilityIdentifier("portUnlocode.screen")
    }

    private var searchField: some View {
        HStack(spacing: 8) {
            Image(systemName: "magnifyingglass")
                .font(.body.weight(.semibold))
                .foregroundStyle(AppTheme.textSecondary)
            TextField(
                "",
                text: $model.query,
                prompt: Text("Code or name").foregroundStyle(AppTheme.textSecondary)
            )
            .textFieldStyle(.plain)
            .textInputAutocapitalization(.never)
            .autocorrectionDisabled()
            .submitLabel(.search)
            .focused($searchFocused)
            .foregroundStyle(AppTheme.textPrimary)
            .accessibilityLabel("Search ports")
            .accessibilityIdentifier("portUnlocode.search")
            if !model.query.isEmpty {
                Button {
                    model.query = ""
                } label: {
                    Image(systemName: "xmark.circle.fill")
                        .foregroundStyle(AppTheme.textSecondary)
                }
                .buttonStyle(.plain)
                .accessibilityLabel("Clear search")
                .accessibilityIdentifier("portUnlocode.search.clear")
            }
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 12)
        .background(Color.black.opacity(0.28), in: RoundedRectangle(cornerRadius: 14, style: .continuous))
        .overlay {
            RoundedRectangle(cornerRadius: 14, style: .continuous)
                .strokeBorder(AppTheme.fieldBorder, lineWidth: 1)
        }
    }

    private var mapCard: some View {
        let state = PortUnlocodeCatalog.mapState(for: model.selected)
        return ZStack(alignment: .bottomLeading) {
            mapBody(state)
            chip(for: state)
                .padding(10)
        }
        .frame(height: 176)
        .frame(maxWidth: .infinity)
        .clipShape(RoundedRectangle(cornerRadius: 22, style: .continuous))
        .overlay {
            RoundedRectangle(cornerRadius: 22, style: .continuous)
                .strokeBorder(AppTheme.cardBorder, lineWidth: 1)
        }
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(mapAccessibilityLabel(state))
        .accessibilityIdentifier(mapAccessibilityIdentifier(state))
    }

    @ViewBuilder
    private func mapBody(_ state: PortUnlocodeCatalog.MapState) -> some View {
        switch state {
        case .pickResult:
            placeholderMap(title: PortUnlocodeCatalog.pickResult)
        case .noPosition:
            placeholderMap(title: PortUnlocodeCatalog.noPosition)
        case .pin(let latitude, let longitude):
            let coordinate = CLLocationCoordinate2D(latitude: latitude, longitude: longitude)
            Map(position: .constant(.region(MKCoordinateRegion(
                center: coordinate,
                span: MKCoordinateSpan(latitudeDelta: 0.4, longitudeDelta: 0.4)
            ))), interactionModes: [.pan, .zoom]) {
                Annotation(model.selected?.name ?? "", coordinate: coordinate, anchor: .bottom) {
                    Image(systemName: "mappin")
                        .font(.system(size: 28, weight: .semibold))
                        .foregroundStyle(AppTheme.teal)
                        .shadow(color: .black.opacity(0.35), radius: 2, y: 1)
                }
            }
            .mapStyle(.standard(elevation: .flat, pointsOfInterest: .excludingAll))
            .mapControls {}
            .mapControlVisibility(.hidden)
            .accessibilityHidden(true)
            .id(model.selected?.id ?? "pin")
        }
    }

    private func placeholderMap(title: String) -> some View {
        ZStack {
            AppTheme.surface
            PortUnlocodeMapWaves()
            Text(title)
                .font(.body.weight(.medium))
                .foregroundStyle(AppTheme.textSecondary)
        }
    }

    @ViewBuilder
    private func chip(for state: PortUnlocodeCatalog.MapState) -> some View {
        switch state {
        case .pickResult:
            mapChip("Search a port")
        case .noPosition, .pin:
            if let name = model.selected?.name {
                mapChip(name)
            }
        }
    }

    private func mapChip(_ title: String) -> some View {
        Text(title)
            .font(.caption.weight(.semibold))
            .foregroundStyle(AppTheme.textPrimary)
            .lineLimit(1)
            .padding(.horizontal, 10)
            .padding(.vertical, 6)
            .background(AppTheme.badgeFill.opacity(0.92), in: Capsule())
            .overlay {
                Capsule().strokeBorder(AppTheme.cardBorder, lineWidth: 1)
            }
    }

    private func mapAccessibilityIdentifier(_ state: PortUnlocodeCatalog.MapState) -> String {
        switch state {
        case .pickResult: return "portUnlocode.map.pickResult"
        case .pin: return "portUnlocode.map.pin"
        case .noPosition: return "portUnlocode.map.noPosition"
        }
    }

    private func mapAccessibilityLabel(_ state: PortUnlocodeCatalog.MapState) -> String {
        switch state {
        case .pickResult:
            return PortUnlocodeCatalog.pickResult
        case .noPosition:
            let name = model.selected?.name ?? ""
            return "\(PortUnlocodeCatalog.noPosition). \(name)"
        case .pin:
            let name = model.selected?.name ?? ""
            return "Map pin. \(name)"
        }
    }

    private var detailCard: some View {
        GlassCard(padding: 14) {
            VStack(alignment: .leading, spacing: 8) {
                if let error = model.loadError {
                    Text(error)
                        .font(.subheadline)
                        .foregroundStyle(AppTheme.danger)
                        .accessibilityIdentifier("portUnlocode.loadError")
                } else if !model.isLoaded {
                    HStack {
                        Spacer()
                        ProgressView()
                            .tint(AppTheme.teal)
                        Spacer()
                    }
                    .padding(.vertical, 24)
                    .accessibilityLabel("Loading ports")
                } else if let selected = model.selected {
                    sectionTitle("SELECTED")
                    selectedBody(selected)
                } else if model.query.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                    Text("Search by UN/LOCODE or name")
                        .font(.subheadline)
                        .foregroundStyle(AppTheme.textSecondary)
                        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
                } else if model.results.isEmpty {
                    sectionTitle("RESULTS")
                    Text("No ports match")
                        .font(.subheadline)
                        .foregroundStyle(AppTheme.textSecondary)
                        .accessibilityIdentifier("portUnlocode.results.empty")
                } else {
                    sectionTitle("RESULTS")
                    resultsList
                }
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
    }

    private func sectionTitle(_ title: String) -> some View {
        Text(title)
            .font(.caption.weight(.bold))
            .tracking(1.1)
            .foregroundStyle(AppTheme.teal)
    }

    private var resultsList: some View {
        let visible = Array(model.results.prefix(resultLimit))
        return ScrollView {
            LazyVStack(alignment: .leading, spacing: 0) {
                ForEach(visible) { port in
                    Button {
                        model.selectedID = port.id
                        ToolsKeyboard.dismiss()
                    } label: {
                        resultRow(port)
                    }
                    .buttonStyle(.plain)
                    .accessibilityIdentifier(port.resultAccessibilityIdentifier)
                }
                if model.results.count > visible.count {
                    Text("Showing \(visible.count) of \(model.results.count)")
                        .font(.caption2)
                        .foregroundStyle(AppTheme.textSecondary)
                        .padding(.top, 8)
                }
            }
        }
        .scrollDismissesKeyboard(.interactively)
        .accessibilityIdentifier("portUnlocode.results")
    }

    private func resultRow(_ port: PortUnlocodeCatalog.Port) -> some View {
        HStack(alignment: .center, spacing: 10) {
            VStack(alignment: .leading, spacing: 2) {
                HStack(alignment: .firstTextBaseline, spacing: 8) {
                    Text(port.code)
                        .font(.subheadline.weight(.bold))
                        .foregroundStyle(AppTheme.teal)
                    Text(port.name)
                        .font(.body.weight(.semibold))
                        .foregroundStyle(AppTheme.textPrimary)
                        .lineLimit(1)
                }
                Text(port.placeLine)
                    .font(.caption)
                    .foregroundStyle(AppTheme.textSecondary)
                    .lineLimit(1)
            }
            Spacer(minLength: 8)
            Image(systemName: "chevron.right")
                .font(.caption.weight(.semibold))
                .foregroundStyle(AppTheme.textSecondary)
        }
        .padding(.vertical, 10)
        .contentShape(Rectangle())
    }

    private func selectedBody(_ port: PortUnlocodeCatalog.Port) -> some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 4) {
                Text(port.name)
                    .font(.title2.weight(.bold))
                    .foregroundStyle(AppTheme.textPrimary)
                    .fixedSize(horizontal: false, vertical: true)
                    .accessibilityIdentifier("portUnlocode.selected.name")
                Text(port.code)
                    .font(.headline.weight(.bold))
                    .foregroundStyle(AppTheme.teal)
                    .accessibilityIdentifier("portUnlocode.selected.code")
                VStack(spacing: 0) {
                    detailRow("Country", port.countryLine, identifier: "portUnlocode.country")
                    if !port.subdivisionLabel.isEmpty {
                        detailRow("Subdivision", port.subdivisionLabel, identifier: "portUnlocode.subdivision")
                    }
                    detailRow("Coordinates", port.coordinateLabel, identifier: "portUnlocode.coordinates")
                    detailRow("Function", PortUnlocodeCatalog.functionLabel, identifier: "portUnlocode.function")
                }
                .padding(.top, 8)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
        }
        .accessibilityIdentifier("portUnlocode.selected")
    }

    private func detailRow(_ label: String, _ value: String, identifier: String) -> some View {
        VStack(spacing: 0) {
            HStack(alignment: .firstTextBaseline, spacing: 12) {
                Text(label)
                    .foregroundStyle(AppTheme.textSecondary)
                Spacer(minLength: 12)
                Text(value)
                    .fontWeight(.semibold)
                    .foregroundStyle(AppTheme.textPrimary)
                    .multilineTextAlignment(.trailing)
                    .accessibilityIdentifier(identifier)
            }
            .font(.subheadline)
            .padding(.vertical, 11)
            Rectangle()
                .fill(AppTheme.cardBorder)
                .frame(height: 1)
        }
    }

    private var credit: some View {
        Text(PortUnlocodeCatalog.credit)
            .font(.caption)
            .foregroundStyle(AppTheme.textSecondary)
            .frame(maxWidth: .infinity)
            .accessibilityIdentifier("portUnlocode.credit")
    }
}

@MainActor
@Observable
final class PortUnlocodeToolModel {
    var ports: [PortUnlocodeCatalog.Port] = []
    var query = "" {
        didSet {
            if query != oldValue { selectedID = nil }
        }
    }
    var selectedID: String?
    var loadError: String?
    var isLoaded = false
    private var started = false

    var results: [PortUnlocodeCatalog.Port] {
        PortUnlocodeCatalog.search(ports, query: query)
    }

    var selected: PortUnlocodeCatalog.Port? {
        guard let selectedID else { return nil }
        return ports.first { $0.id == selectedID }
    }

    func loadIfNeeded() {
        guard !started else { return }
        started = true
        do {
            ports = try PortUnlocodeCatalog.loadBundled()
            isLoaded = true
        } catch {
            loadError = "Could not read the port list."
            isLoaded = true
        }
    }
}

private struct PortUnlocodeMapWaves: View {
    var body: some View {
        Canvas { context, size in
            var path = Path()
            for index in 0..<4 {
                let yBase = size.height * (0.58 + CGFloat(index) * 0.07)
                path.move(to: CGPoint(x: 0, y: yBase))
                var x: CGFloat = 0
                while x <= size.width {
                    let wave = sin(Double(x / max(size.width, 1)) * .pi * 2 + Double(index))
                    let y = yBase + CGFloat(wave) * (5 + CGFloat(index) * 2)
                    path.addLine(to: CGPoint(x: x, y: y))
                    x += 6
                }
            }
            context.stroke(path, with: .color(AppTheme.teal.opacity(0.22)), lineWidth: 1.1)
        }
        .allowsHitTesting(false)
    }
}
