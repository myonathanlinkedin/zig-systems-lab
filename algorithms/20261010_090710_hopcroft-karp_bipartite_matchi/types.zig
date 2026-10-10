pub const Graph = struct {
    left: usize,
    right: usize,
    // adjacency list for each left‑side vertex; each inner slice contains right‑side indices (0..right-1)
    adj: [][]usize,
};
