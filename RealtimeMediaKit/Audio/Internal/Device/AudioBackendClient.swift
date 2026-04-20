//
//  AudioBackendClient.swift
//  RealtimeMediaKit
//
//  Created by Codex on 2026/04/18.
//

import Foundation

protocol AudioBackendClient: AnyObject {
    func audioBackend(_ backend: any InternalAudioBackend, didCapture frame: inout AudioFrame)
    func audioBackend(_ backend: any InternalAudioBackend, willRender frame: inout AudioFrame)
}
