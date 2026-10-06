# Dostoevsky: Better Space-Time Trade-Offs for LSM-Tree Based Key-Value Stores via Adaptive

A clean, dependency-free **Zig** reference implementation of **Dostoevsky: Better Space-Time Trade-Offs for LSM-Tree Based Key-Value Stores via Adaptive**, focused on core algorithmic mechanics, clear memory layout, and test verification.

### Core Highlights
* **Language & Standard**: Modern `Zig` standard library conventions.
* **Architecture Pattern**: Designed for `Balanced Hierarchical Indexing` using `Node Pointers & Self-Balancing Trees`.
* **Runtime Overhead**: Contiguous memory layouts and standard collections are favored for straightforward iteration and access.
* **Concurrency & Safety**: State consistency is verified after mutations through assertion test coverage.

---

### Complexity Analysis

| Dimension | Bound |
| :--- | :--- |
| **Time (Best Case)** | `O(1)` |
| **Time (Worst Case)** | `O(log N)` |
| **Auxiliary Space** | `O(N)` |

---

### Test Suite Execution

Self-contained verification drivers are embedded directly in `main.zig` to validate happy paths, boundary inputs, and invariant preservation.

```bash
zig run main.zig
```

---

*Source code released under the MIT License • [@myonathanlinkedin](https://github.com/myonathanlinkedin)*
