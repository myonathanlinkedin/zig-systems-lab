# AFORE: Attention-FFN Disaggregation with Overlapped Reconfiguration of Experts

A clean, dependency-free **Zig** implementation of **AFORE: Attention-FFN Disaggregation with Overlapped Reconfiguration of Experts**, focused on predictable latency, strict memory layout, and deterministic execution.

### Core Highlights
* **Language & Standard**: Modern `Zig` standard library conventions.
* **Architecture Pattern**: Designed for `Algorithmic Engineering` using `Standard Memory Primitives`.
* **Runtime Overhead**: Memory allocations are kept minimal to avoid allocator contention and preserve CPU cache locality.
* **Concurrency & Safety**: State consistency is verified after every mutation through formal invariant validation.

---

### Complexity Analysis

| Dimension | Bound |
| :--- | :--- |
| **Time (Best Case)** | `$O(1)$` |
| **Time (Worst Case)** | `$O(N \log N)$` |
| **Auxiliary Space** | `$O(N)$` |

---

### Test Suite Execution

Self-contained verification drivers are embedded directly in `types.zig` to validate happy paths, boundary inputs, and invariant preservation.

```bash
zig run types.zig
```

---

*Curated as part of the Polyglot Systems Lab • Maintained by [@myonathanlinkedin](https://github.com/myonathanlinkedin)*