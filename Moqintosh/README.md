# Moqintosh

A Swift MOQT client library built on Apple's Network.framework.

## Overview

Moqintosh is a Swift library that implements Media over QUIC Transport (MOQT) over QUIC using Apple's Network.framework.

It is based on `draft-ietf-moq-transport-14` and currently targets MOQT client behavior only.

Relay behavior is out of scope, and WebTransport is unsupported.

## Features

- Session connection and setup handshake
- `PUBLISH_NAMESPACE`
- `SUBSCRIBE_NAMESPACE`
- `SUBSCRIBE`
- Stream object send and receive
- Object Datagram send and receive
- Interoperability checks with the sample app

## Unsupported / Out of Scope

- Relay behavior
- WebTransport
- Full specification coverage
- Production-hardening level error handling across all cases

## Architecture

- `Source/API`: Public API surface
- `Source/Protocol`: MOQT message and frame encoding and decoding
- `Source/Session`: Session state, control dispatch, request handling, and receiver coordination
- `Source/Transport`: QUIC transport abstraction built on top of `Network.framework`
- `Sample`: Manual interoperability sample app
- `MoqintoshTests`: Unit and integration tests

## Requirements

- Xcode
- Swift
- Apple platforms with `Network.framework`
