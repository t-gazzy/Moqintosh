//
//  ControlMessageReceiver.swift
//  Moqintosh
//
//  Created by Codex on 2026/04/10.
//

final class ControlMessageReceiver {

    private let controlStream: TransportBiStream
    private let dispatcher: ControlMessageDispatcher
    private let frameReader: MessageFrameReader

    init(
        controlStream: TransportBiStream,
        dispatcher: ControlMessageDispatcher,
        frameReader: MessageFrameReader = MessageFrameReader()
    ) {
        self.controlStream = controlStream
        self.dispatcher = dispatcher
        self.frameReader = frameReader
    }

    func start() {
        Task {
            do {
                while true {
                    let message: MOQTMessage = try await frameReader.read(from: controlStream)
                    await dispatcher.handle(message)
                }
            } catch {
                OSLogger.error("Control stream receive error: \(error)")
            }
        }
    }
}
