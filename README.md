# SwiftRetrier

🪨 Rock-solid, concise and thorough library to retry and repeat `async throws` jobs.

## A cold retrier with all options

```swift
var conditionPublisher: AnyPublisher<Bool, Never>

// Fully configurable policy with good defaults. Also available: withConstantDelay(), withNoDelay()
let coldRetrier = withExponentialBackoff() 
    // Fetch only when you've got network and your user is authenticated for example
    .onlyWhen(conditionPublisher)
    // Ensure your retrier gives up on some conditions
    .giveUpAfter(maxAttempts: 10)
    .giveUpAfter(timeout: 30)
    .giveUpOnErrors {
        $0 is MyFatalError
    }
```

[Exponential backoff](https://aws.amazon.com/fr/blogs/architecture/exponential-backoff-and-jitter/) with
full jitter is the default and recommended algorithm to fetch from a backend. 

## Execute and repeat

You can chain a call to `execute { try await job() }`, but you can also reuse any cold retrier to execute multiple
jobs independently.

```swift  
let fetcher = coldRetrier.execute { 
    try await fetchSomething() 
}

let poller = coldRetrier
    // If you want to poll, well you can
    .repeating(withDelay: 30)
    .execute { 
        try await fetchSomethingElse() 
    }
 
// you can omit `execute` and call the retrier as a function:
let otherFetcher = coldRetrier { try await fetchSomethingElse() }

// You can always cancel hot retriers
fetcher.cancel()
```

## Await value in concurrency context

If you don't repeat, you can wait for a single value in a concurrency context

```swift
// This will throw if you cancel the retrier or if any `giveUp*()` function matches
let value = try await withExponentialBackoff() 
    .onlyWhen(conditionPublisher)
    .giveUpAfter(maxAttempts: 10)
    .giveUpAfter(timeout: 30)
    .giveUpOnErrors {
        $0 is MyFatalError
    }
    .execute {
        try await api.fetchValue()
    }
    .value
```

Note that you can use `cancellableValue` instead of `value`. In this case, if the task wrapping the concurrency context
is cancelled, the underlying retrier will be cancelled.

## Simple events handling

Retrier events can be handled simply.

```swift
fetcher.onEach {
    switch $0 {
        case .attemptSuccess(let value):
            print("Fetched something: \(value)")
        case .attemptFailure(let failure):
            print("An attempt #\(failure.index) failed with \(failure.error)")
        case .completion(let error):
            print("Fetcher completed with \(error?.localizedDescription ?? "no error")")
    }
}
```

Keep in mind that the event handler will be retained until the retrier finishes (succeeding, failing or being 
cancelled).

## Combine publishers

All retriers (including repeaters) expose Combine publishers that publish relevant events.

```swift
let cancellable = poller.publisher()
    .sink {
        switch $0 {
            case .attemptSuccess(let value):
                print("Fetched something: \(value)")
            case .attemptFailure(let failure):
                print("An attempt #\(failure.index) failed with \(failure.error)")
            case .completion(let error):
                print("Poller completed with \(error?.localizedDescription ?? "no error")")
        }
    }
```

- The publishers never fail, meaning their completion is always `.finished` and you can `sink {}` without handling 
the completion
- Instead, `attemptFailure`, `attemptSuccess` and `completion` events are materialized and sent as values.
- Retriers expose `successPublisher()`, `failurePublisher()` and `completionPublisher()` shortcuts.
- You can use `publisher(propagateCancellation: true)` to cancel the retrier when you're done listening to it.

## Retriers contract

- All retriers are cancellable.
- Retriers retry until either:
    - their policy gives up
    - the job succeeds (except for repeaters that will delay another trial)
    - the retrier is cancelled
    - their conditionPublisher ends after having published no value or `false` as its last value
- When a policy gives up, the last job error is thrown on any `try await retrier.value`, and also embedded into 
a `RetrierEvent.completion`.
- Retriers publishers emit only on `DispatchQueue.main`.
- When cancelled, the retrier publishers emit a `RetrierEvent.completion(CancellationError())` value then a `.finished`
completion and no intermediary attempt result.
- All retriers start their tasks immediately on initialization, and just wait for the current main queue cycle to end
 before executing jobs. This way, if a retrier is created on main queue and cancelled in the same cycle, it's guaranteed 
 to not execute the job even once.
- You can create and cancel retriers on a different `DispatchQueue` or even in an asynchronous context. But in this 
case, guarantees such as the previous one are no longer valid.
- Condition publishers events will be processed on `DispatchQueue.main`, but won't be delayed if they're already 
emitted on it.
- After a retrier is interrupted then resumed by its `conditionPublisher`, its policy is reused from start.
Consequently `giveUpAfter(maxAttempts:)` and `giveUpAfter(timeout:)` checks are applied to the current trial, ignoring previous ones.

## Retry Policies

It's important to understand that policies are not used to repeat after a success, but only to retry on failure.
When repeating, the policy is reused from start after each success.

### Built-in retry policies

**ExponentialBackoffRetryPolicy** is implemented according to state-of-the-art algorithms.
Have a look to the available arguments, and you'll recognize the standard parameters and options.
You can especially choose the jitter type between `none`, `full` (default) and `decorrelated`.

**ConstantDelayRetryPolicy** does what you expect, just waiting for a fixed amount of time.

You can add failure conditions using `giveUp*()` functions.

### Homemade policy

You can create your own policies that conform `RetryPolicy` and they will benefit from the same modifiers.
Have a look at `ConstantDelayRetryPolicy.swift` for a basic example.

⚠️ Policies should be stateless. To ensure that, I recommend implementing them with `struct` types.

If a policy needs to know about attempts history, ensure you propagate what's needed when implementing
`policyAfter(attemptFailure:, delay:) -> any RetryPolicy`.

To create a DSL entry point using your policy:

```swift
public func withMyOwnPolicy() -> ColdRetrier {
    let policy = MyOwnPolicy()
    return ColdRetrier(policy: policy, conditionPublisher: nil)
}
```

## Actual retrier classes

You can use the classes initializers directly, namely `SimpleRetrier`, 
`ConditionalRetrier` and `Repeater`.

## Contribute

Feel free to make any comment, criticism, bug report or feature request using GitHub issues.
You can also directly send me an email at `pierre` *strange "a" with a long round tail* `pittscraft.com`.

## License

SwiftRetrier is available under the MIT license. See the LICENSE file for more info.
