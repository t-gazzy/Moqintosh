//
//  CallApplicationSampleApp.swift
//  CallApplicationSample
//
//  Created by Takemasa Kaji on 2026/04/22.
//

import SwiftUI

@main
struct CallApplicationSampleApp: App {
    @StateObject private var viewModel: CallApplicationViewModel

    init() {
        let coordinator: CallApplicationCoordinator = CallApplicationCoordinator()
        self._viewModel = StateObject(
            wrappedValue: CallApplicationViewModel(coordinator: coordinator)
        )
    }

    var body: some Scene {
        WindowGroup {
            ContentView(viewModel: viewModel)
        }
    }
}
