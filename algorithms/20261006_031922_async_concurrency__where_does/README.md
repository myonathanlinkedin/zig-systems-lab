# Async Concurrency: Where does the scheduler live?

Self-contained **Async Concurrency: Where does the scheduler live?** algorithmic primitive written in idiomatic **Zig**. Built from scratch using standard library constructs with zero external dependencies.

---

## 🏛️ Architecture & Design Decisions

This module organizes `Async Concurrency: Where does the scheduler live?` into an isolated, self-contained unit:
* **Domain Focus**: `Algorithmic Engineering`
* **Primary Primitives**: `Standard Memory Primitives`
* **Memory Strategy**: Memory allocations are kept minimal to maintain clear data locality and predictable memory bounds.
* **Correctness Model**: State transitions follow clear ordering guarantees with explicit validation at each phase.

### Asymptotic Complexity

| Metric | Bound | Characteristics |
| :--- | :---: | :--- |
| **Best Case Time** | `O(1)` | Optimized fast-path execution |
| **Average / Worst Time** | `O(N)` | Deterministic upper bound for generalized workloads |
| **Space Complexity** | `O(N)` | Strict bounds without unconstrained heap growth |

---

## 🧪 Verification Suite

The accompanying `core.zig` driver executes self-contained verification tests:
1. **Nominal Flow**: Validates baseline correctness under typical real-world inputs.
2. **Boundary Conditions**: Exercises extreme edge cases (empty inputs, singletons, capacity limits).
3. **Invariant Preservation**: Validates internal state consistency throughout mutation lifecycles.

### Running Locally

```bash
zig run core.zig
```

---

<sub>Standard Zig reference implementation • Maintained by [@myonathanlinkedin](https://github.com/myonathanlinkedin)</sub>
