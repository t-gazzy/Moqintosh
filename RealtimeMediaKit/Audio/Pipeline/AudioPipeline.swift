//
//  AudioPipeline.swift
//  RealtimeMediaKit
//
//  Created by Codex on 2026/04/18.
//

import Foundation

// Safe because processors are configured before the realtime path starts.
final class AudioPipeline: @unchecked Sendable {
    private var processors: [any AudioProcessor]

    init(processors: [any AudioProcessor] = []) {
        self.processors = processors
    }

    func appendProcessor(_ processor: any AudioProcessor) {
        processors.append(processor)
    }

    func removeAllProcessors() {
        processors.removeAll(keepingCapacity: true)
    }

    func processCapture(_ frame: inout AudioFrame) {
        for processor in processors {
            processor.processCapture(&frame)
        }
    }

    func processRender(_ frame: inout AudioFrame) {
        for processor in processors {
            processor.processRender(&frame)
        }
    }
}
