//
//  ControlMessageReceiver.swift
//  Moqintosh
//
//  Created by Codex on 2026/04/10.
//

final class ControlMessageReceiver {

    private let controlStream: TransportBiStream
    private var receiveTask: Task<Void, Never>?

    init(controlStream: TransportBiStream) {
        self.controlStream = controlStream
        self.receiveTask = nil
    }

    deinit {
        receiveTask?.cancel()
    }

    func start(dispatcher: ControlMessageDispatcher) {
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

    func stop() {
        receiveTask?.cancel()
        receiveTask = nil
    }
}
