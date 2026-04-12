# ``Moqintosh``

A Swift MOQT client library for Apple platforms.

## Overview

Moqintosh provides client-side Media over QUIC Transport (MOQT) over QUIC on top of Apple's `Network.framework`.

Use it to:

- connect to a MOQT server
- publish tracks and namespaces
- subscribe to tracks and namespaces
- handle inbound control requests through ``SessionDelegate``
- exchange subgroup stream objects and object datagrams
- serve and receive fetches

The library currently targets client behavior from `draft-ietf-moq-transport-14`.
Relay behavior and WebTransport are out of scope.

## Getting Started

The public API follows a small set of entry points:

1. Create an ``Endpoint``.
2. Connect and obtain a ``Session``.
3. Create a ``Publisher`` or ``Subscriber`` from the session.
4. Implement ``SessionDelegate`` if you need to accept or reject inbound control requests.

For end-to-end sample usage, see the `Sample` target in this repository.

## Topics

### Essentials

- ``Endpoint``
- ``Session``
- ``SessionDelegate``
- ``PublishDecision``
- ``SubscribeDecision``

### Publishing

- ``Publisher``
- ``PublishedTrack``
- ``StreamSenderFactory``
- ``StreamSender``
- ``DatagramSender``
- ``PublishDone``

### Subscribing

- ``Subscriber``
- ``Subscription``
- ``StreamReceiverFactory``
- ``StreamReceiver``
- ``DatagramReceiver``
- ``SubscribeUpdate``

### Fetch

- ``FetchRequest``
- ``FetchResponse``
- ``FetchSubscription``
- ``FetchSender``
- ``FetchReceiver``

### Track Metadata

- ``TrackResource``
- ``TrackStatus``
- ``TrackStatusRequest``
- ``TrackNamespace``
- ``Location``
- ``GroupOrder``
- ``ContentExist``
- ``SubscriptionFilter``
