# SwiftRetrier

🪨 Rock-solid, concise and thorough library to retry and repeat `async throws` jobs.

## A cold retrier with all options

```swift
    var conditionPublisher: AnyPublisher<Bool, Never>
    
    // Fully configurable policy with good defaults. Also available: withConstantDelay(), withNoDelay()
    let coldRetrier = withExponentialBackoff() 
        // Fetch only when you've got network and your user is authenticated for example
        .onlyWhen(conditionPublisher)
        // Ensure your retrier fails on some conditions
        .giveUpAfter(maxAttempts: 10)
        .giveUpOnErrors(matching: {
            $0 is MyFatalError
        })
        // Ensure your retrier won't give up on some errors
        .retryOnErrors(matching: {
            $0 is MyTmpError
        })
        // All giveUp / retry modifiers are evaluated in reversed order.
```

[Exponential backoff](https://aws.amazon.com/fr/blogs/architecture/exponential-backoff-and-jitter/) with
full jitter is the default and recommended algorithm to fetch from a backend. 

## Execute and repeat

You can chain a call to `execute { try await job() }`, but you can also reuse any cold retrier to execute multiple
jobs independently.

```swift  
    let fetcher = coldRetrier { 
        try await fetchSomething() 
    }
    let poller = coldRetrier
        // If you want to poll, well you can
        .repeating(withDelay: 30)({ 
            try await fetchSomethingElse() 
        })
        
    // You can always cancel hot retriers
    fetcher.cancel()
```

## Combine publishers

All retriers (including repeaters) expose Combine publishers that publish relevant events.
- The publishers never fail, meaning their completion is always `.finished` and you can `sink {}` without handling 
the completion
- Instead, `attemptFailure`, `attemptSuccess` and `completion` events are materialized and sent as values.
- There are `successPublisher()`, `failurePublisher()` and `completionPublisher()` shortcuts.
- You can use `publisher(propagateCancellation: true)` to cancel the retrier when you're done listening to it.

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

## Await value in concurrency context

If you don't repeat, you can wait for a single value in a concurrency context

```swift
     func fetchValue() async throws -> Value {
        // This will throw if you cancel the retrier or if any `giveUp*()` function matches
        try await withExponentialBackoff() 
            .onlyWhen(conditionPublisher)
            .giveUpAfter(maxAttempts: 10)
            .giveUpOnErrors(matching: {
                $0 is MyFatalError
            })
            .retryOnErrors(matching: {
                $0 is MyTmpError
            }) {
                try await api.fetchValue()
            }
            .value
    }
    
```

Note that you can use `cancellableValue` instead of value. In this case, if the task wrapping the concurrency context
is cancelled, the underlying retrier will be cancelled.

## Without the main DSL

### `withRetries()` functions

You may prefer to use a function to more directly access either the `async` value of your job, or the success publisher
of your repeating job.

In this case you can use the `withRetries()` functions.

Their first argument is the `policy`. It:
- handles delays and failure criteria
- defaults to `Policy.exponentialBackoff()`
- can be built using the `Policy` entry point

```swift
let policy = Policy.exponentialBackoff().giveUpAfter(maxAttempts: 12)
let value = try await withRetries(policy: policy, job: { try await fetchSomething() })
// You can add an extra `attemptFailureHandler` block to log attempt errors.
// If the task executing the concurrency context is cancelled, the underlying retrier will be canceled.

withRetries(policy: Policy.exponentialBackoff(), repeatDelay: 10, job: { try await fetchSomething() })
    .success() // If you're not interested in all events, just use .success()
    .sink {
        print("Got a value: \($0), let's rest 10s now")
    }
// You can set `propagateCancellation` to `true` to cancel the underlying retrier when you're done listening to the
// success publisher.
```

Note that `conditionPublisher` is an optional argument to make the execution conditional.

### `retrier()` functions

Use the shortcut `retrier()` functions to build a hot retrier in one line and keep full control on it. They have
the same arguments as `withRetries()` but they return an executing retrier. 

### Actual retrier classes

Finally, you can also use the classes initializers directly, namely `SimpleRetrier`, 
`ConditionalRetrier` and `SimpleRepeater`.


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

## Retry Policies

It's important to understand that policies are not used to repeat after a success, but only to retry on failure.
When repeating, the policy is reused from start after each success.

### Built-in retry policies

```swift
Policy.exponentialBackoff()
Policy.constantDelay()
Policy.noDelay()
```

**Exponential backoff** policy is implemented according to state of the art algorithms.
Have a look to the available arguments and you'll recognize the standard parameters and options.
You can especially choose the jitter type between `none`, `full` (default) and `decorrelated`.

**Constant delay** policy does what you expect, just waiting for a fixed amount of time.

**No delay** policy is a constant delay policy with a `0` delay.

In a fallible context, you can add failure conditions using 
`giveUp*()` functions, and bypass these conditions using `retry*()` functions.

All giveUp / retry modifiers are evaluated in reversed order.

### Home made policy

You can create your own policies that conform `RetryPolicy` and they will benefit from the same modifiers.
Have a look at `ConstantDelayRetryPolicy.swift` for a basic example.

To create a DSL entry point using your policy:

```swift
public func withMyOwnPolicy() -> ColdInfallibleRetrier {
    let policy = MyOwnPolicy()
    return ColdInfallibleRetrier(policy: policy, conditionPublisher: nil)
}
```

## Contribute

Feel free to make any comment, critic, bug report or feature request using Github issues.
You can also directly send me an email at `pierre` *strange "a" with a long round tail* `pittscraft.com`.

## License

SwiftRetrier is available under the MIT license. See the LICENSE file for more info.
