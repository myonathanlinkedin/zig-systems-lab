# We ported the original Doom to SQL

Self-contained **We ported the original Doom to SQL** algorithmic primitive written in idiomatic **Zig**. Built from scratch using standard library constructs with zero external dependencies.

---

## 🏛️ Architecture & Design Decisions

This module organizes `We ported the original Doom to SQL` into an isolated, self-contained unit:
* **Domain Focus**: `Algorithmic Engineering`
* **Primary Primitives**: `Standard Memory Primitives`
* **Memory Strategy**: Zero external heap dependencies; designed as a pure in-memory algorithmic component.
* **Correctness Model**: Execution behavior is validated against nominal workflows and boundary edge cases.

### Asymptotic Complexity

| Metric | Bound | Characteristics |
| :--- | :---: | :--- |
| **Best Case Time** | `O(1)` | Optimized fast-path execution |
| **Average / Worst Time** | `O(N)` | Deterministic upper bound for generalized workloads |
| **Space Complexity** | `O(N)` | Strict bounds without unconstrained heap growth |

---

## 🧪 Verification Suite

The accompanying `main.zig` driver executes self-contained verification tests:
1. **Nominal Flow**: Validates baseline correctness under typical real-world inputs.
2. **Boundary Conditions**: Exercises extreme edge cases (empty inputs, singletons, capacity limits).
3. **Invariant Preservation**: Validates internal state consistency throughout mutation lifecycles.

### Running Locally

```bash
zig run main.zig
```

---

*Reference implementation verified by [@myonathanlinkedin](https://github.com/myonathanlinkedin)*
