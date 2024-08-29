# SwiftRetrier

🪨 Rock-solid, concise and thorough library to retry and repeat `async throws` jobs.

## A cold retrier with all options ❄️

```swift
var conditionPublisher: AnyPublisher<Bool, Never>

// Fully configurable policy with good defaults. Also available: withConstantDelay(), withNoDelay()
let retrier = withExponentialBackoff() 
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

## Job retrier and repeater ❄️

You can directly chain a call to `job { try await job() }` to create a cold job retrier,
 but you can also reuse any retrier to create multiple job retriers.

```swift
let fetcher = retrier.job { 
    try await fetchSomething() 
}

let poller = retrier
    // If you want to poll, well you can
    .repeating(withDelay: 30)
    .job { 
        try await fetchSomethingElse() 
    }
```

Once the job is set, you can add event handlers to your (still cold ❄️) retrier.

```swift
let fetcherWithEventHandler = fetcher.handleRetrierEvents {
    switch $0 {
        case .attemptSuccess(let value):
            print("Fetched something: \(value)")
        case .attemptFailure(let failure):
            print("An attempt #\(failure.index) failed with \(failure.error)")
        case .completion(let error):
            print("Fetcher completed with \(error?.localizedDescription ?? "no error")")
    }
}.handleRetrierEvents {
   // Do something fun 🤡
}
```

## Collect 🔥

All job retriers are cold publishers and:
- **each subscription will create a new independent retrying stream**
- **cancelling the subscription cancels the retrier**

Once in the Combine world, you'll know what to do (else check next paragraph).

```swift
let cancellable = fetcher
   .sink { event in
        switch $0 {
            case .attemptSuccess(let value):
                print("Fetched something: \(value)")
            case .attemptFailure(let failure):
                print("An attempt #\(failure.index) failed with \(failure.error)")
            case .completion(let error):
                print("Poller completed with \(error?.localizedDescription ?? "no error")")
        }
   }

let cancellable = fetcher
    // Retrieve success values
   .success()
   .sink { fetchedValue in
      // Do something with values
   }
```

- `failure()` and `completion()` filters are also available
- The publishers never fail, meaning their completion is always `.finished` and you can `sink {}` without handling 
the completion
- Instead, `attemptFailure`, `attemptSuccess` and `completion` events are materialized and sent as values.
- You can use `success()`, `failure()` and `completion()` shortcuts.

## Await value in concurrency context 🔥

If you don't repeat, you can wait for a single value in a concurrency context and:
- **each awaiting will create a new independent retrying stream**
- **cancelling the task that is awaiting the value cancels the retrier**

```swift
// This will throw if you cancel the retrier or if any `giveUp*()` function matches
let value = try await withExponentialBackoff() 
    .onlyWhen(conditionPublisher)
    .giveUpAfter(maxAttempts: 10)
    .giveUpAfter(timeout: 30)
    .giveUpOnErrors {
        $0 is MyFatalError
    }
    .job {
        try await api.fetchValue()
    }
    .value
```

## Retriers contract

- All retriers are cancellable.
- Retriers retry until either:
    - their policy gives up
    - the job succeeds (except for repeaters that will delay another trial)
    - the retrier is cancelled (via its subscription or its awaiting task cancellation)
    - their conditionPublisher ends after having published no value or `false` as its last value
- When a policy gives up, the last job error is thrown on any `try await retrier.value`, and also embedded into 
a `RetrierEvent.completion`.
- Publishers emit only on `DispatchQueue.main`
- Everything here is `MainActor` friendly
- After a retrier is interrupted then resumed by its `conditionPublisher`, its policy is reused from start.
Consequently `giveUpAfter(maxAttempts:)` and `giveUpAfter(timeout:)` checks are applied to the current trial,
ignoring previous ones.

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
public func withMyOwnPolicy() -> Retrier {
    let policy = MyOwnPolicy()
    return Retrier(policy: policy, conditionPublisher: nil)
}
```

## Contribute

Feel free to make any comment, criticism, bug report or feature request using GitHub issues.
You can also directly send me an email at `pierre` *strange "a" with a long round tail* `pittscraft.com`.

## License

SwiftRetrier is available under the MIT license. See the LICENSE file for more info.
