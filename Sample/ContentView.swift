//
//  ContentView.swift
//  SwiftMOQTSample
//
//  Created by Takemasa Kaji on 2026/04/10.
//

import SwiftUI

struct ContentView: View {
    @State private var controller: SampleAppController = .init()

    var body: some View {
        Group {
            if let sessionController: SampleSessionController = controller.sessionController {
                SessionView(controller: sessionController)
            } else {
                ConnectView(controller: controller)
            }
        }
    }
}

#Preview {
    ContentView()
}
