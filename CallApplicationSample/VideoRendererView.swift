//
//  VideoRendererView.swift
//  CallApplicationSample
//
//  Created by Codex on 2026/04/22.
//

import SwiftUI

#if canImport(UIKit)
import UIKit
import RealtimeMediaKit

struct VideoRendererView: UIViewRepresentable {
    let renderView: VideoRenderView?

    func makeUIView(context: Context) -> UIView {
        let containerView: UIView = UIView()
        containerView.backgroundColor = UIColor.black
        return containerView
    }

    func updateUIView(_ uiView: UIView, context: Context) {
        uiView.subviews.forEach { subview in
            subview.removeFromSuperview()
        }

        guard let renderView else {
            return
        }

        renderView.translatesAutoresizingMaskIntoConstraints = false
        uiView.addSubview(renderView)
        NSLayoutConstraint.activate([
            renderView.topAnchor.constraint(equalTo: uiView.topAnchor),
            renderView.bottomAnchor.constraint(equalTo: uiView.bottomAnchor),
            renderView.leadingAnchor.constraint(equalTo: uiView.leadingAnchor),
            renderView.trailingAnchor.constraint(equalTo: uiView.trailingAnchor)
        ])
    }
}
#else
struct VideoRendererView: View {
    let renderView: Any?

    var body: some View {
        Color.black
    }
}
#endif
