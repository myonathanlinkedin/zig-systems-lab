# AFORE: Attention-FFN Disaggregation with Overlapped Reconfiguration of Experts

A clean, dependency-free **Zig** reference implementation of **AFORE: Attention-FFN Disaggregation with Overlapped Reconfiguration of Experts**, focused on core algorithmic mechanics, clear memory layout, and test verification.

### Core Highlights
* **Language & Standard**: Modern `Zig` standard library conventions.
* **Architecture Pattern**: Designed for `Algorithmic Engineering` using `Standard Memory Primitives`.
* **Runtime Overhead**: Memory allocations are kept minimal to maintain clear data locality and predictable memory bounds.
* **Concurrency & Safety**: State consistency is verified after mutations through assertion test coverage.

---

### Complexity Analysis

| Dimension | Bound |
| :--- | :--- |
| **Time (Best Case)** | `O(1)` |
| **Time (Worst Case)** | `O(N log N)` |
| **Auxiliary Space** | `O(N)` |

---

### Test Suite Execution

Self-contained verification drivers are embedded directly in `types.zig` to validate happy paths, boundary inputs, and invariant preservation.

```bash
zig run types.zig
```

---

*Part of the Polyglot Systems Lab • Maintained by [@myonathanlinkedin](https://github.com/myonathanlinkedin)*
