# Architecture

The prototype's code name is Flick; the targets and bundle ids carry it.

One event type, one classifier, two ends of a link.

## Data flow

```
Watch                                    iPhone
-----                                    ------
DragGesture ends
  -> SwipeClassifier.classify
  -> SwipeEvent (direction, distance, speed, sentAt, source)
  -> WatchLink.send
       reachable:  sendMessageData ---------> PhoneLink.didReceiveMessageData
       else:       transferUserInfo --------> PhoneLink.didReceiveUserInfo
                                                -> SwipeHub.handle
                                                     deck.apply(direction)
                                                     log.insert(event, receivedAt)
                                                     link.publish(deck.context)
       reply <----------------------------- replyHandler(PhoneContext)
  -> lastRoundTrip, phoneContext
                                             updateApplicationContext -----> WatchLink.didReceiveApplicationContext
```

## Shared

`Shared/` is a folder in both targets. It holds only Foundation and
CoreGraphics code so both platforms compile it unchanged.

- `SwipeEvent` is the message. `PhoneContext` is the reply.
- `SwipeClassifier` decides direction from a drag's translation, predicted
  end and velocity. Both the Watch pad and the phone's local swipe use it,
  so the two feel the same.
- `Wire` packs events and contexts as JSON. Dates go as seconds since 1970
  to keep millisecond precision for latency.

## Concurrency

Swift 6 language mode, strict concurrency. Link classes are `@MainActor`
and `@Observable`. `WCSessionDelegate` methods are `nonisolated`, take a
Sendable snapshot of the session, and `Task { @MainActor in }` to apply it.
Closures handed to the session capture `self`, which is fine because a
main-actor class is Sendable.

## What the deck is for

The deck is a placeholder target. Anything with next, previous, select and
dismiss can replace it: subscribe to `SwipeHub` and act on `handle`. The
Watch does not know about cards, only about a title, an index and a count.
