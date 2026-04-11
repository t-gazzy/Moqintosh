//
//  SampleLogSheetView.swift
//  Sample
//
//  Created by Codex on 2026/04/11.
//

import SwiftUI

struct SampleLogSheetView: View {

    let eventMessages: [String]
    let receivedMessages: [String]

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 20) {
                GroupBox("Event Log") {
                    VStack(alignment: .leading, spacing: 8) {
                        if eventMessages.isEmpty {
                            Text("No events")
                                .foregroundStyle(.secondary)
                        } else {
                            ForEach(eventMessages, id: \.self) { message in
                                Text(message)
                                    .font(.footnote.monospaced())
                                    .frame(maxWidth: .infinity, alignment: .leading)
                            }
                        }
                    }
                }

                GroupBox("Received Data") {
                    VStack(alignment: .leading, spacing: 8) {
                        if receivedMessages.isEmpty {
                            Text("No received data")
                                .foregroundStyle(.secondary)
                        } else {
                            ForEach(receivedMessages, id: \.self) { message in
                                Text(message)
                                    .font(.footnote.monospaced())
                                    .frame(maxWidth: .infinity, alignment: .leading)
                            }
                        }
                    }
                }
            }
            .padding()
        }
        .frame(minWidth: 480, minHeight: 520)
    }
}
