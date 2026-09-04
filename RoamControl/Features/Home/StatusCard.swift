import SwiftUI

struct StatusCard: View {
    let state: ConnectionState

    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: iconName)
                .foregroundStyle(tint)

            VStack(alignment: .leading, spacing: 2) {
                Text(title).font(.headline)
                Text(detail).font(.subheadline).foregroundStyle(.secondary)
            }

            Spacer()
        }
        .padding()
        .background(.thinMaterial, in: RoundedRectangle(cornerRadius: 16))
        .accessibilityElement(children: .combine)
    }

    private var title: String {
        switch state {
        case .notConfigured: "Not configured"
        case .ready: "Ready"
        case .connecting: "Connecting"
        case .active: "Location session active"
        case .failed: "Connection error"
        }
    }

    private var detail: String {
        switch state {
        case .notConfigured: "Pairing support has not been added yet."
        case .ready: "The paired device is available."
        case .connecting: "Roam Control is preparing the secure device session."
        case .active: "Roam Control is controlling the session."
        case .failed(let message): message
        }
    }

    private var iconName: String {
        switch state {
        case .notConfigured: "circle.dashed"
        case .ready: "checkmark.circle.fill"
        case .connecting: "arrow.triangle.2.circlepath"
        case .active: "location.fill"
        case .failed: "exclamationmark.triangle.fill"
        }
    }

    private var tint: Color {
        switch state {
        case .notConfigured: .secondary
        case .ready: .green
        case .connecting: .blue
        case .active: .blue
        case .failed: .red
        }
    }
}
