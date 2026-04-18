//
//  InternalAudioBackend.swift
//  RealtimeMediaKit
//
//  Created by Codex on 2026/04/18.
//

import Foundation

protocol InternalAudioBackend: AnyObject {
    var client: (any AudioBackendClient)? { get set }
    var configuration: AudioDeviceConfiguration { get }

    func start() throws
    func stop() throws
}
