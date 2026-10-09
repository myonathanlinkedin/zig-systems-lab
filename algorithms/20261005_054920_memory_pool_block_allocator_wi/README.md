# Memory Pool Block Allocator with Free List

An in-memory reference implementation of **Memory Pool Block Allocator with Free List** in **Zig**, adhering to standard library idioms, clean data structures, and assertion test suites.

### Core Highlights
* **Language & Standard**: Modern `Zig` standard library conventions.
* **Architecture Pattern**: Designed for `Low-Latency Systems & Memory Layout` using `Contiguous Memory Buffer & Ring Pointers`.
* **Runtime Overhead**: Zero external heap dependencies; designed as a pure in-memory algorithmic component.
* **Concurrency & Safety**: Execution behavior is validated against nominal workflows and boundary edge cases.

---

### Complexity Analysis

| Dimension | Bound |
| :--- | :--- |
| **Time (Best Case)** | `O(1)` |
| **Time (Worst Case)** | `O(1) amortized` |
| **Auxiliary Space** | `O(N) bounded` |

---

### Test Suite Execution

Self-contained verification drivers are embedded directly in `main.zig` to validate happy paths, boundary inputs, and invariant preservation.

```bash
zig run main.zig
```

---

*Source code released under the MIT License • [@myonathanlinkedin](https://github.com/myonathanlinkedin)*
