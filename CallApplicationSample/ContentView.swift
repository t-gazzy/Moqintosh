//
//  ContentView.swift
//  CallApplicationSample
//
//  Created by Takemasa Kaji on 2026/04/22.
//

import SwiftUI

struct ContentView: View {
    @ObservedObject private var viewModel: CallApplicationViewModel

    init(viewModel: CallApplicationViewModel) {
        self.viewModel = viewModel
    }

    var body: some View {
        Group {
            if viewModel.isConnected {
                connectedView
            } else {
                connectionView
            }
        }
        .sheet(isPresented: $viewModel.isControlPanelPresented) {
            controlPanelView
        }
    }
}

private extension ContentView {
    var connectionView: some View {
        NavigationStack {
            Form {
                Section("Connection") {
                    TextField("localhost:4433", text: $viewModel.endpointAddress)
                        .textInputAutocapitalization(.never)
                        .autocorrectionDisabled()
                    Toggle("Allow Untrusted Certificates", isOn: $viewModel.allowsUntrustedCertificates)
                    Button {
                        Task {
                            await viewModel.connect()
                        }
                    } label: {
                        if viewModel.isConnecting {
                            ProgressView()
                        } else {
                            Text("Connect")
                        }
                    }
                    .disabled(viewModel.isConnecting)
                }

                if let connectionErrorMessage: String = viewModel.connectionErrorMessage {
                    Section("Error") {
                        Text(connectionErrorMessage)
                            .foregroundStyle(.red)
                    }
                }

                Section("Event Log") {
                    if viewModel.eventLogLines.isEmpty {
                        Text("No events yet.")
                            .foregroundStyle(.secondary)
                    } else {
                        ScrollView {
                            LazyVStack(alignment: .leading, spacing: 8) {
                                ForEach(viewModel.eventLogLines.indices, id: \.self) { index in
                                    Text(viewModel.eventLogLines[index])
                                        .font(.footnote.monospaced())
                                        .frame(maxWidth: .infinity, alignment: .leading)
                                }
                            }
                        }
                        .frame(minHeight: 180)
                    }
                }
            }
            .navigationTitle("Call Sample")
        }
    }

    var connectedView: some View {
        NavigationStack {
            VStack(spacing: 16) {
                VStack(alignment: .leading, spacing: 8) {
                    Text(viewModel.connectedEndpointDescription)
                        .font(.headline)
                    if viewModel.remoteVideoTracks.isEmpty {
                        Text("No remote video tracks are being rendered.")
                            .foregroundStyle(.secondary)
                    } else {
                        Picker("Displayed Video", selection: $viewModel.selectedRemoteVideoTrackID) {
                            Text("None").tag(Optional<UInt64>.none)
                            ForEach(viewModel.remoteVideoTracks) { track in
                                Text(track.displayName).tag(Optional(track.id))
                            }
                        }
                        .pickerStyle(.menu)
                    }
                }
                .frame(maxWidth: .infinity, alignment: .leading)

                VideoRendererView(renderView: viewModel.selectedVideoRenderView)
                    .frame(maxWidth: .infinity)
                    .aspectRatio(16.0 / 9.0, contentMode: .fit)
                    .clipShape(RoundedRectangle(cornerRadius: 16))
                    .overlay {
                        if viewModel.selectedVideoRenderView == nil {
                            RoundedRectangle(cornerRadius: 16)
                                .strokeBorder(Color.secondary.opacity(0.3), style: StrokeStyle(lineWidth: 1, dash: [6]))
                            Text("Remote video will appear here.")
                                .foregroundStyle(.secondary)
                        }
                    }

                Form {
                    Section("Published Namespaces") {
                        if viewModel.activePublishedNamespaces.isEmpty {
                            Text("None")
                                .foregroundStyle(.secondary)
                        } else {
                            ForEach(viewModel.activePublishedNamespaces) { namespace in
                                Text(namespace.displayName)
                            }
                        }
                    }

                    Section("Subscribed Namespaces") {
                        if viewModel.activeSubscribedNamespaces.isEmpty {
                            Text("None")
                                .foregroundStyle(.secondary)
                        } else {
                            ForEach(viewModel.activeSubscribedNamespaces) { namespace in
                                Text(namespace.displayName)
                            }
                        }
                    }

                    Section("Incoming Subscribes") {
                        if viewModel.inboundSubscriptionRequests.isEmpty {
                            Text("No active subscribe requests.")
                                .foregroundStyle(.secondary)
                        } else {
                            ForEach(viewModel.inboundSubscriptionRequests) { request in
                                VStack(alignment: .leading, spacing: 8) {
                                    Text(request.displayName)
                                        .font(.headline)
                                    Text("forward=\(request.forwardDescription)")
                                        .font(.caption)
                                        .foregroundStyle(.secondary)
                                    HStack {
                                        Button("Stream") {
                                            Task {
                                                await viewModel.startSending(for: request.id, mode: .stream)
                                            }
                                        }
                                        .disabled(!request.canStartDelivery)
                                        Button("Datagram") {
                                            Task {
                                                await viewModel.startSending(for: request.id, mode: .datagram)
                                            }
                                        }
                                        .disabled(!request.canStartDelivery)
                                    }
                                }
                            }
                        }
                    }

                    Section("Data Log") {
                        if viewModel.dataLogLines.isEmpty {
                            Text("No timestamps received.")
                                .foregroundStyle(.secondary)
                        } else {
                            ForEach(viewModel.dataLogLines.indices, id: \.self) { index in
                                Text(viewModel.dataLogLines[index])
                                    .font(.footnote.monospaced())
                            }
                        }
                    }

                    Section("Event Log") {
                        if viewModel.eventLogLines.isEmpty {
                            Text("No events yet.")
                                .foregroundStyle(.secondary)
                        } else {
                            ForEach(viewModel.eventLogLines.indices, id: \.self) { index in
                                Text(viewModel.eventLogLines[index])
                                    .font(.footnote.monospaced())
                            }
                        }
                    }
                }
            }
            .padding()
            .navigationTitle("Session")
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button("GOAWAY") {
                        Task {
                            await viewModel.sendGoAway()
                        }
                    }
                }
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Control Panel") {
                        viewModel.isControlPanelPresented = true
                    }
                }
            }
        }
    }

    var controlPanelView: some View {
        NavigationStack {
            Form {
                Section("Publish Namespace") {
                    TextField("call/room1", text: $viewModel.publishNamespaceInput)
                        .textInputAutocapitalization(.never)
                        .autocorrectionDisabled()
                    Button("Publish Namespace") {
                        Task {
                            await viewModel.publishNamespace()
                        }
                    }
                }

                Section("Subscribe Namespace") {
                    TextField("call/room1", text: $viewModel.subscribeNamespaceInput)
                        .textInputAutocapitalization(.never)
                        .autocorrectionDisabled()
                    Button("Subscribe Namespace") {
                        Task {
                            await viewModel.subscribeNamespace()
                        }
                    }
                }

                Section("Publish Track") {
                    if viewModel.activePublishedNamespaces.isEmpty {
                        Text("Publish a namespace first.")
                            .foregroundStyle(.secondary)
                    } else {
                        Picker("Namespace", selection: $viewModel.selectedPublishedNamespaceID) {
                            ForEach(viewModel.activePublishedNamespaces) { namespace in
                                Text(namespace.displayName).tag(Optional(namespace.id))
                            }
                        }
                        Picker("Track", selection: $viewModel.selectedTrackKind) {
                            ForEach(CallApplicationViewModel.TrackKind.allCases) { trackKind in
                                Text(trackKind.rawValue).tag(trackKind)
                            }
                        }
                        .pickerStyle(.segmented)
                        Toggle("Forward", isOn: $viewModel.publishForwardEnabled)
                        Button("Publish Track") {
                            Task {
                                await viewModel.publishTrack()
                            }
                        }
                    }
                }

                Section("Active Published Tracks") {
                    if viewModel.localPublishedTracks.isEmpty {
                        Text("No published tracks.")
                            .foregroundStyle(.secondary)
                    } else {
                        ForEach(viewModel.localPublishedTracks) { track in
                            VStack(alignment: .leading, spacing: 8) {
                                Text(track.displayName)
                                    .font(.headline)
                                Text("forward=\(track.forwardDescription)")
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                                HStack {
                                    Button("Publish Done") {
                                        Task {
                                            await viewModel.publishDone(for: track.id)
                                        }
                                    }
                                    Button("Namespace Done") {
                                        Task {
                                            await viewModel.publishNamespaceDone(for: track.namespaceID)
                                        }
                                    }
                                }
                            }
                        }
                    }
                }

                Section("Remote Tracks") {
                    if viewModel.remoteTracks.isEmpty {
                        Text("No remote tracks.")
                            .foregroundStyle(.secondary)
                    } else {
                        ForEach(viewModel.remoteTracks) { track in
                            VStack(alignment: .leading, spacing: 8) {
                                Text(track.displayName)
                                    .font(.headline)
                                Button("Unsubscribe") {
                                    Task {
                                        await viewModel.unsubscribeRemoteTrack(track.id)
                                    }
                                }
                            }
                        }
                    }
                }

                Section("Fetch") {
                    if viewModel.remoteTracks.isEmpty {
                        Text("A remote track is required.")
                            .foregroundStyle(.secondary)
                    } else {
                        Picker("Track", selection: $viewModel.selectedFetchTrackID) {
                            ForEach(viewModel.remoteTracks) { track in
                                Text(track.displayName).tag(Optional(track.id))
                            }
                        }
                        TextField("Start Object", text: $viewModel.fetchStartObjectText)
                            .keyboardType(.numberPad)
                        TextField("End Object", text: $viewModel.fetchEndObjectText)
                            .keyboardType(.numberPad)
                        Button("Fetch") {
                            Task {
                                await viewModel.fetchRemoteTrack()
                            }
                        }
                    }
                }

                Section("Active Fetches") {
                    if viewModel.activeFetchSubscriptions.isEmpty {
                        Text("No active fetch subscriptions.")
                            .foregroundStyle(.secondary)
                    } else {
                        ForEach(viewModel.activeFetchSubscriptions) { fetch in
                            VStack(alignment: .leading, spacing: 8) {
                                Text(fetch.displayName)
                                    .font(.headline)
                                Button("Fetch Cancel") {
                                    Task {
                                        await viewModel.cancelFetch(fetch.id)
                                    }
                                }
                            }
                        }
                    }
                }

                Section("Namespace Controls") {
                    if viewModel.activeSubscribedNamespaces.isEmpty {
                        Text("No subscribed namespaces.")
                            .foregroundStyle(.secondary)
                    } else {
                        ForEach(viewModel.activeSubscribedNamespaces) { namespace in
                            Button("Unsubscribe Namespace: \(namespace.displayName)") {
                                Task {
                                    await viewModel.unsubscribeNamespace(namespace.id)
                                }
                            }
                        }
                    }
                }
            }
            .navigationTitle("Control Panel")
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Close") {
                        viewModel.isControlPanelPresented = false
                    }
                }
            }
        }
    }
}

#Preview {
    ContentView(
        viewModel: CallApplicationViewModel(
            coordinator: CallApplicationCoordinator()
        )
    )
}
