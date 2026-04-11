//
//  SessionView.swift
//  Sample
//
//  Created by Codex on 2026/04/11.
//

import SwiftUI

struct SessionView: View {

    @Bindable var controller: SampleSessionController
    @State private var isLogSheetPresented: Bool = false

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 20) {
                Text("Session")
                    .font(.title2)
                    .fontWeight(.semibold)

                Text(controller.statusText)
                    .font(.body.monospaced())
                    .foregroundStyle(.secondary)

                GroupBox("Publish Namespace") {
                    VStack(alignment: .leading, spacing: 12) {
                        TextField("example/live", text: $controller.publishNamespaceText)
                            .textFieldStyle(.roundedBorder)
                        Button("Publish Namespace") {
                            Task {
                                await controller.publishNamespace()
                            }
                        }
                        .buttonStyle(.borderedProminent)
                        .disabled(controller.isWorking)
                    }
                }

                if !controller.advertisedNamespaceOptions.isEmpty {
                    GroupBox("Advertised Namespaces") {
                        VStack(alignment: .leading, spacing: 8) {
                            ForEach(controller.advertisedNamespaceOptions, id: \.self) { namespace in
                                Text(namespace)
                                    .font(.body.monospaced())
                                    .frame(maxWidth: .infinity, alignment: .leading)
                            }
                        }
                    }
                }

                GroupBox("Subscribe Namespace") {
                    VStack(alignment: .leading, spacing: 12) {
                        TextField("example/live", text: $controller.subscribeNamespaceText)
                            .textFieldStyle(.roundedBorder)
                        Button("Subscribe Namespace") {
                            Task {
                                await controller.subscribeNamespace()
                            }
                        }
                        .buttonStyle(.borderedProminent)
                        .disabled(controller.isWorking)
                    }
                }

                GroupBox("Subscribe Track") {
                    VStack(alignment: .leading, spacing: 12) {
                        Picker("Remote Namespace", selection: $controller.selectedRemotePublishedNamespace) {
                            Text("Select namespace").tag("")
                            ForEach(controller.remotePublishedNamespaceOptions, id: \.self) { namespace in
                                Text(namespace).tag(namespace)
                            }
                        }
                        .pickerStyle(.menu)

                        TextField("track name", text: $controller.subscribeTrackNameText)
                            .textFieldStyle(.roundedBorder)

                        Button("Subscribe") {
                            Task {
                                await controller.subscribeTrack()
                            }
                        }
                        .buttonStyle(.borderedProminent)
                        .disabled(controller.isWorking || !controller.canSubscribeTrack)
                    }
                }

                GroupBox("Data Send") {
                    HStack(spacing: 12) {
                        Button("Send Stream Timestamp") {
                            Task {
                                await controller.sendStreamTimestamp()
                            }
                        }
                        .buttonStyle(.borderedProminent)
                        .disabled(controller.isWorking || !controller.canSendStream)

                        Button("Send Datagram Timestamp") {
                            Task {
                                await controller.sendDatagramTimestamp()
                            }
                        }
                        .buttonStyle(.bordered)
                        .disabled(controller.isWorking || !controller.canSendDatagram)
                    }
                }

                Button("Show Logs") {
                    isLogSheetPresented = true
                }
                .buttonStyle(.bordered)
            }
            .padding()
        }
        .sheet(isPresented: $isLogSheetPresented) {
            SampleLogSheetView(
                eventMessages: controller.eventMessages,
                receivedMessages: controller.receivedMessages
            )
        }
    }
}
