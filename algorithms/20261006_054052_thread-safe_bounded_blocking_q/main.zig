// Define a function to check if the queue is full after enqueue
pub fn isFullAfterEnqueue(q: ?Queue) bool {
    if (q == null) {
        return true;
    }

    var q_ptr = q.?;
    return isFullBeforeEnqueue(q);
}

// Define a function to check if the queue is empty after dequeue
pub fn isEmptyAfterDequeue(q: ?Queue) bool {
    if (q == null) {
        return true;
    }

    var q_ptr = q.?;
    return isEmptyBeforeDequeue(q);
}

// Define a function to check if the queue is full before dequeue
pub fn isFullBeforeDequeue(q: ?Queue) bool {
    if (q == null) {
        return true;
    }

    var q_ptr = q.?;
    return isFullAfterEnqueue(q);
}

// Define a function to check if the queue is empty after enqueue
pub fn isEmptyAfterEnqueue(q: ?Queue) bool {
    if (q == null) {
        return true;
    }

    var q_ptr = q.?;
    return isFullAfterDequeue(q);
}
