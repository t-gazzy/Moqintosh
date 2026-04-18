//
//  AudioDevice.swift
//  RealtimeMediaKit
//
//  Created by Codex on 2026/04/18.
//

import Foundation

public protocol AudioDevice: AnyObject {
    var configuration: AudioDeviceConfiguration { get }
    var pipeline: AudioPipeline { get }

    func start() throws
    func stop() throws
}
