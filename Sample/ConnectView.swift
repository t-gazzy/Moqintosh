//
//  ConnectView.swift
//  Sample
//
//  Created by Codex on 2026/04/11.
//

import SwiftUI

struct ConnectView: View {

    @Bindable var controller: SampleAppController

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("Moqintosh Sample")
                .font(.largeTitle)
                .fontWeight(.semibold)

            TextField("host:port", text: $controller.destinationText)
                .textFieldStyle(.roundedBorder)

            Button("Connect") {
                Task {
                    await controller.connect()
                }
            }
            .buttonStyle(.borderedProminent)
            .disabled(controller.isConnecting)

            if controller.isConnecting {
                ProgressView()
            }

            if !controller.statusText.isEmpty {
                Text(controller.statusText)
                    .font(.body.monospaced())
                    .foregroundStyle(.secondary)
            }
        }
        .padding()
        .frame(maxWidth: 420)
    }
}
