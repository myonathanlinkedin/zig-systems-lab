# The Data Race That Wasn t a Bug (and the One That Was) in Zig

An in-memory reference implementation of **The Data Race That Wasn t a Bug (and the One That Was)** in **Zig**, adhering to standard library idioms, clean data structures, and assertion test suites.

## Implementation Details

* **Category**: `Algorithmic Engineering`
* **Data Structure Foundation**: `Standard Memory Primitives`
* **Allocation Pattern**: Contiguous memory layouts and standard collections are favored for straightforward iteration and access.
* **Invariant Integrity**: Execution behavior is validated against nominal workflows and boundary edge cases.

## Performance Characteristics

* **Time**: `O(N)` average, with `O(1)` best-case response under ideal conditions.
* **Space**: `O(N)` memory usage.

## Test Harness

To compile and execute the test assertions for this module:

```bash
zig run core.zig
```

---

*Source code released under the MIT License • [@myonathanlinkedin](https://github.com/myonathanlinkedin)*