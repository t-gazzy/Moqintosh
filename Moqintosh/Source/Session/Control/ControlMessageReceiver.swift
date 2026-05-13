//
//  ControlMessageReceiver.swift
//  Moqintosh
//
//  Created by Codex on 2026/04/10.
//

import Synchronization

final class ControlMessageReceiver: Sendable {

    private let controlStream: TransportBiStream
    private let receiveTask: Mutex<Task<Void, Never>?>

    init(controlStream: TransportBiStream) {
        self.controlStream = controlStream
        self.receiveTask = Mutex<Task<Void, Never>?>(nil)
    }

    deinit {
        receiveTask.withLock { receiveTask in
            receiveTask?.cancel()
        }
    }

    func start(dispatcher: ControlMessageDispatcher) {
        receiveTask.withLock { receiveTask in
            precondition(receiveTask == nil, "ControlMessageReceiver.start(dispatcher:) must only be called once")
            receiveTask = Task { [controlStream] in
                let frameReader: MessageFrameReader = MessageFrameReader()
                do {
                    while !Task.isCancelled {
                        let message: MOQTMessage = try await frameReader.read(from: controlStream)
                        await dispatcher.handle(message)
                    }
                } catch is CancellationError {
                } catch {
                    OSLogger.error("Control stream receive error: \(error)")
                }
            }
        }
    }

    func stop() {
        receiveTask.withLock { receiveTask in
            receiveTask?.cancel()
            receiveTask = nil
        }
    }
}
