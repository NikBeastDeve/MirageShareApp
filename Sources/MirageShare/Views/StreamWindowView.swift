//
//  StreamWindowView.swift
//  MirageShare
//
//  Created by Assistant on 2/1/26.
//
//  Window for viewing remote streams with full input support.
//

import SwiftUI

struct StreamWindowView: View {
    let sessions: [MirageStreamSessionState]
    let clientService: MirageClientService
    let sessionStore: MirageClientSessionStore

    @Environment(\.dismiss)
    private var dismiss

    @State
    private var selectedSessionID: String?

    private var selectedSession: MirageStreamSessionState? {
        sessions.first { $0.id.uuidString == selectedSessionID }
    }

    var body: some View {
        VStack(spacing: 0) {
            toolbarSection

            Divider()

            if let session = selectedSession ?? sessions.first {
                streamContent(for: session)
            } else {
                emptyState
            }
        }
        .frame(minWidth: 800, minHeight: 600)
    }

    // MARK: - Sections

    private var toolbarSection: some View {
        HStack(spacing: 16) {
            // Session picker
            if sessions.count > 1 {
                Picker("Session", selection: $selectedSessionID) {
                    ForEach(sessions) { session in
                        Text(session.window.title ?? "Untitled")
                            .tag(session.id.uuidString as String?)
                    }
                }
                .pickerStyle(.segmented)
                .frame(maxWidth: 300)
            } else if let session = sessions.first {
                HStack {
                    Image(systemName: "display")
                    Text(session.window.title ?? "Remote Screen")
                        .lineLimit(1)
                }
            }

            Spacer()

            // Connection status
            StatusBadge(
                icon: "checkmark.circle.fill",
                text: "Connected",
                color: .green
            )

            // Close button
            Button {
                dismiss()
            } label: {
                Image(systemName: "xmark.circle.fill")
                    .font(.title3)
            }
            .buttonStyle(.borderless)
            .foregroundStyle(.secondary)
        }
        .padding()
        .background(.quaternary.opacity(0.2))
    }

    private func streamContent(for session: MirageStreamSessionState) -> some View {
        MirageStreamContentView(
            session: session,
            sessionStore: sessionStore,
            clientService: clientService,
            isDesktopStream: false,
            desktopStreamMode: .mirrored
        )
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    private var emptyState: some View {
        VStack(spacing: 16) {
            Image(systemName: "display.slash")
                .font(.system(size: 48))
                .foregroundStyle(.secondary)

            Text("No Active Streams")
                .font(.title2)
                .foregroundStyle(.secondary)

            Button("Close") {
                dismiss()
            }
            .buttonStyle(.borderedProminent)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
}

// MARK: - Preview

#Preview {
    StreamWindowView(
        sessions: [],
        clientService: MirageClientService(),
        sessionStore: MirageClientSessionStore()
    )
}
