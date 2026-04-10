//
//  MessageType.swift
//  Moqintosh
//
//  Created by takemasa kaji on 2026/04/10.
//

import Foundation

/// MOQT control message type identifiers (Table 1, draft-ietf-moq-transport-14).
public enum MessageType: UInt64 {
    // MARK: - Session
    case clientSetup             = 0x20  // Section 9.3
    case serverSetup             = 0x21  // Section 9.3
    case goaway                  = 0x10  // Section 9.4
    case maxRequestID            = 0x15  // Section 9.5
    case requestsBlocked         = 0x1A  // Section 9.6

    // MARK: - Subscribe
    case subscribe               = 0x03  // Section 9.7
    case subscribeOK             = 0x04  // Section 9.8
    case subscribeError          = 0x05  // Section 9.9
    case subscribeUpdate         = 0x02  // Section 9.10
    case unsubscribe             = 0x0A  // Section 9.11

    // MARK: - Publish
    case publishDone             = 0x0B  // Section 9.12
    case publish                 = 0x1D  // Section 9.13
    case publishOK               = 0x1E  // Section 9.14
    case publishError            = 0x1F  // Section 9.15

    // MARK: - Fetch
    case fetch                   = 0x16  // Section 9.16
    case fetchOK                 = 0x18  // Section 9.17
    case fetchError              = 0x19  // Section 9.18
    case fetchCancel             = 0x17  // Section 9.19

    // MARK: - Track Status
    case trackStatus             = 0x0D  // Section 9.20
    case trackStatusOK           = 0x0E  // Section 9.21
    case trackStatusError        = 0x0F  // Section 9.22

    // MARK: - Publish Namespace
    case publishNamespace        = 0x06  // Section 9.23
    case publishNamespaceOK      = 0x07  // Section 9.24
    case publishNamespaceError   = 0x08  // Section 9.25
    case publishNamespaceDone    = 0x09  // Section 9.26
    case publishNamespaceCancel  = 0x0C  // Section 9.27

    // MARK: - Subscribe Namespace
    case subscribeNamespace      = 0x11  // Section 9.28
    case subscribeNamespaceOK    = 0x12  // Section 9.29
    case subscribeNamespaceError = 0x13  // Section 9.30
    case unsubscribeNamespace    = 0x14  // Section 9.31
}
