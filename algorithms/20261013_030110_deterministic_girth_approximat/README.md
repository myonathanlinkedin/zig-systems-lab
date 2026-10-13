# Deterministic Girth Approximation in Weighted Undirected Graphs

An in-memory reference implementation of **Deterministic Girth Approximation in Weighted Undirected Graphs** in **Zig**, adhering to standard library idioms, clean data structures, and assertion test suites.

### Core Highlights
* **Language & Standard**: Modern `Zig` standard library conventions.
* **Architecture Pattern**: Designed for `Graph Topology & Traversal` using `Adjacency List & Priority Heap`.
* **Runtime Overhead**: Memory allocations are kept minimal to maintain clear data locality and predictable memory bounds.
* **Concurrency & Safety**: State transitions follow clear ordering guarantees with explicit validation at each phase.

---

### Complexity Analysis

| Dimension | Bound |
| :--- | :--- |
| **Time (Best Case)** | `O(V + E)` |
| **Time (Worst Case)** | `O(V^2)` |
| **Auxiliary Space** | `O(V + E)` |

---

### Test Suite Execution

Self-contained verification drivers are embedded directly in `main.zig` to validate happy paths, boundary inputs, and invariant preservation.

```bash
zig run main.zig
```

---

*Source code released under the MIT License • [@myonathanlinkedin](https://github.com/myonathanlinkedin)*