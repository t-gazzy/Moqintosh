# Moqintosh

![DocC Status](https://github.com/t-gazzy/Moqintosh/actions/workflows/docc.yml/badge.svg)
![Test Status](https://github.com/t-gazzy/Moqintosh/actions/workflows/test.yml/badge.svg)

A Swift MOQT client library built on Apple's `Network.framework`.

## Overview

Moqintosh implements Media over QUIC Transport (MOQT) client behavior on Apple platforms.

It currently targets `draft-ietf-moq-transport-14` and focuses on low-latency client-side publish, subscribe, fetch, and track status flows over QUIC.

Relay behavior and WebTransport are out of scope.

## Current Capabilities

- Session setup and GOAWAY handling
- `PUBLISH_NAMESPACE`, `PUBLISH`, `PUBLISH_DONE`, and namespace cancellation flows
- `SUBSCRIBE_NAMESPACE`, `SUBSCRIBE`, `SUBSCRIBE_UPDATE`, and unsubscribe flows
- `FETCH`, `FETCH_CANCEL`, and fetch stream delivery
- `TRACK_STATUS`
- Subgroup stream send and receive
- Object datagram send and receive
- Delegate-driven handling of inbound control requests with typed acceptance and rejection decisions
- Unit, integration, and sample-app based interoperability coverage

## Project Layout

- `Moqintosh/Source/API`: Public API surface
- `Moqintosh/Source/Domain`: Public domain models
- `Moqintosh/Source/Protocol`: MOQT control messages, common protocol types, and data frame models
- `Moqintosh/Source/Session`: Session orchestration, request tracking, and receive coordination
- `Moqintosh/Source/Transport`: Transport interfaces and QUIC implementation
- `Moqintosh/Source/Support`: Internal support types such as factories and helpers
- `Sample`: Manual sample app for interoperability testing
- `MoqintoshTests`: Unit and integration tests

## Requirements

- Xcode 26 or later
- Swift 6.2 toolchain
- Apple platforms with `Network.framework`

## Status

This library is under active development. The current implementation tracks the client side of the draft and does not aim for full specification coverage yet.
