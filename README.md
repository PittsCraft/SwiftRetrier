# SwiftRetrier

Rock-solid, concise and thorough library to retry and repeat `async throws` jobs.

## Use with shortcut functions

```swift
func fetchSomething() async throws -> Something {
    // Fetch something
}

let something = try await retry(job: fetchSomething)

```

This single line will try to fetch something with a preconfigured 
[exponential backoff delay](https://aws.amazon.com/fr/blogs/architecture/exponential-backoff-and-jitter/)
retry policy until it succeeds.

If you `try await` like this from inside a task that becomes cancelled, the retrier 
will be cancelled. Else it will run until it finishes. You can get more control using the underlying retrier directly (see below).

### Poll every 10s, still with retry:

```swift
let cancellable = retry(repeatEvery: 10, job: job)
    .sink {
        print("Fetched this: \($0)")
    }
```
If you want to cancel the polling when you cancel your subscription, use the `propagateSubscriptionCancellation`
argument.

### Execute jobs only when some condition is `true`

```swift
let conditionPublisher = isOnlinePublisher
                            .combineLatest(isAuthenticatedPublisher) { $0 && $1 }

let cancellable = retry(repeatEvery: 10, 
                        onlyWhen: conditionPublisher,
                        job: job)
    .sink {
        print("Fetched this: \($0)")
    }
```
The execution will be interrupted when the condition becomes `false` and resumed when it becomes `true` again.

### Configure policy to give up at some point

```swift
let value = try await fallibleRetry(policy: .exponentialBackoff(maxAttempts: 5), job: job)
```

If a policy gives up when repeating then everyting is stopped, there will be no further attempt or 
repeat.

### Monitor attempt failures

```swift
let value = try await retry(job: job, attemptFailureHandler: {
    print("An attempt error occured: \($0.localizedDescription)")
})

```

## Retriers

`retrier()` and `fallibleRetrier()` functions will provide you with the underlying retriers of respective `retry()` and 
`fallibleRetry()` functions, and give you more control.

All retriers provide these publishers and functions:

```swift
    var attemptPublisher: AnyPublisher<Result<Output, Error>, Failure> { get }
    
    var attemptSuccessPublisher: AnyPublisher<Output, Failure> { get }
    
    var attemptFailurePublisher: AnyPublisher<Error, Failure> { get }
    
    func cancel()
```

For infallible retriers, `Failure == Never`, and for fallible retriers, `Failure == Error`.

This gives you full access to retrier events, giving you an opportunity to trigger any action - for example cancelling 
the retrier.

Retriers with no repeat also provide:

```swift
var value: Output { get async throws }

var cancellableValue: Output { get async throws }
```

When a task awaiting on `cancellableValue` is cancelled, the retrier is cancelled. This is not the case for `value`.

You can also use the classes initializers directly, namely `SimpleInfallibleRetrier`, `ConditionalInfallibleRetrier`,
 `InfallibleRepeater`, `SimpleFallibleRetrier`, `ConditionalFallibleRetrier` and `InfallibleRepeater`.

## Retriers contract

- All retriers are cancellable.
- Retriers retry until either:
    - their policy gives up
    - the job succeeds
    - the retrier is cancelled
- When a policy gives up, the last job error is used is thrown on any `try await retrier.value`, and also embedded into 
publishers failure.
- Retriers publishers emit only on `DispatchQueue.main`.
- When cancelled, the retrier publishers emit a `.finished` completion and no intermediary attempt result.
- All retriers start their tasks immediately on initialization, and wait for the current main queue cycle to end before
 executing jobs. This way, if a retrier is created on main queue and cancelled in the same cycle, it's guaranteed 
 to not execute the job even once.
- You can create and cancel retriers on a different `DispatchQueue` or even in an asynchronous context. But in this 
case, guarantees such as the previous one are no longer valid.
- Condition publishers events will be processed on main `DispatchQueue`, but won't be delayed if they're already 
emitted on it.

## Retry Policies

It's important to understand that policies are not used to repeat after a success, but only to retry on failure.
When repeating, the policy is reused from start after each success.

### Built-in retry policies

```swift
retry(policy: .exponentialBackoff(), job: job)
retry(policy: .constantBackoff(), job: job)
retry(policy: .immediate(), job: job)
retry(policy: .custom(homeMadePolicy), job: job)
```

**Exponential backoff** policy is implemented according to state of the art algorithms.
Have a look to the available arguments and you'll recognize the standard parameters and options.
You can especially choose the jitter type between `none`, `full` (default) and `decorrelated`.

**Constant backoff** policy does what you expect, just waiting for a fixed amount of time.

**Immediate** policy is a constant backoff policy with a `0` delay.

In a fallible context, you can add some parameters to all these policies:
- `retryOn: (Error) -> Bool` to always retry on specific errors
- `giveUpOn: (Error) -> Bool` to always give up on specific errors
- `maxAttempts: Int` to limit the number of attempts

If an error has `retryOn(error) == true`, then the other checks are ignored.

### Home made policy

You can create policies that conform to these protocols:

```swift
public protocol InfallibleRetryPolicy {
    func retryDelay(attemptIndex: UInt, lastError: Error) -> TimeInterval
    func freshInfallibleCopy() -> InfallibleRetryPolicy
}

public protocol FallibleRetryPolicy {
    func shouldRetry(attemptIndex: UInt, lastError: Error) -> FallibleRetryDecision
    func freshFallibleCopy() -> FallibleRetryPolicy
}
```

With `FallibleRetryDecision`:

```swift
public enum FallibleRetryDecision {
    case giveUp
    case retry(delay: TimeInterval)
}
``` 

The "copy" functions are here to allow the reuse of stateful policies.

You can then expose them like this:

```swift
extension InfallibleRetryPolicyInstance {
    static func homeMade(param: Int = 8) -> InfallibleRetryPolicyInstance {
        .custom(HomeMadeInfalliblePolicy(param: param))
    }
}

extension FallibleRetryPolicyInstance {
    static func homeMade(param: Int = 8) -> FallibleRetryPolicyInstance {
        .custom(HomeMadeFalliblePolicy(param: param))
    }
}
```

And finally use them:

```swift
try await retry(with: .homeMade(), job: job)

```

## Contribute

Feel free to make any comment, critic, bug report or feature request using Github issues.
You can also directly send me an email at `pierre` *strange "a" with a long round tail* `pittscraft.com`.

## License

SwiftRetrier is available under the MIT license. See the LICENSE file for more info.
