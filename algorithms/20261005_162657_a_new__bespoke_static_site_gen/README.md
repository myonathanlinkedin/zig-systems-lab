# A new, bespoke static site generator to replace Jekyll (Zig)

> A clean, dependency-free **Zig** implementation of **A new, bespoke static site generator to replace Jekyll**, focused on predictable latency, strict memory layout, and deterministic execution.

## Overview & Mechanics

The implementation focuses on the core mathematical properties of **A new, bespoke static site generator to replace Jekyll**:
* **Data Organization**: Built upon `Standard Memory Primitives` to ensure predictable traversal and storage overhead.
* **Safety Invariants**: Memory allocations are kept minimal to avoid allocator contention and preserve CPU cache locality.
* **Execution Guarantees**: State transitions adhere to strict ordering guarantees with explicit synchronization fences where necessary.

## Complexity Profile

* **Time Complexity**:
  * Fast Path (Best): `$O(1)$`
  * Generalized (Avg / Worst): `$O(N)$`
* **Space Footprint**: `$O(N)$` resident heap / stack overhead.

## Verification & Test Scenarios

The test suite in `main.zig` validates:
* Standard operational paths against expected outcomes.
* Extreme values and edge inputs to ensure robust failure handling.
* State stability across sequential and repeated operations.

```bash
# Execute local verification runner
zig run main.zig
```

---

*Source code released under the MIT License • [@myonathanlinkedin](https://github.com/myonathanlinkedin)*