const std = @import("std");
const types = @import("types.zig");
const engine = @import("engine.zig");

pub fn main() !void {
    testAtomicCounter();
    testAtomicFlag();
    testAtomicQueue();
    testAtomicEngine();
    testEdgeCases();
    
    std.debug.print("All tests passed successfully!\n", .{});
}

fn testAtomicCounter() void {
    var counter = types.AtomicCounter.init(0);
    
    std.debug.assert(counter.load() == 0);
    
    counter.store(42);
    std.debug.assert(counter.load() == 42);
    
    const old_val = counter.fetchAdd(10);
    std.debug.assert(old_val == 42);
    std.debug.assert(counter.load() == 52);
    
    const old_val2 = counter.fetchSub(5);
    std.debug.assert(old_val2 == 52);
    std.debug.assert(counter.load() == 47);
    
    const success = counter.compareExchange(47, 100);
    std.debug.assert(success);
    std.debug.assert(counter.load() == 100);
    
    const failure = counter.compareExchange(47, 200);
    std.debug.assert(!failure);
    std.debug.assert(counter.load() == 100);
}

fn testAtomicFlag() void {
    var flag = types.AtomicFlag.init();
    
    std.debug.assert(!flag.isSet());
    
    flag.set();
    std.debug.assert(flag.isSet());
    
    flag.clear();
    std.debug.assert(!flag.isSet());
    
    const result1 = flag.testAndSet();
    std.debug.assert(!result1);
    std.debug.assert(flag.isSet());
    
    const result2 = flag.testAndSet();
    std.debug.assert(result2);
    std.debug.assert(flag.isSet());
    
    flag.clear();
    std.debug.assert(!flag.isSet());
}

fn testAtomicQueue() void {
    var queue = types.AtomicQueue.init(5);
    defer queue.deinit();
    
    std.debug.assert(queue.isEmpty());
    std.debug.assert(!queue.isFull());
    
    // Test pushing items
    std.debug.assert(queue.push(1));
    std.debug.assert(queue.push(2));
    std.debug.assert(queue.push(3));
    std.debug.assert(queue.push(4));
    std.debug.assert(queue.push(5));
    
    std.debug.assert(queue.isFull());
    std.debug.assert(!queue.push(6)); // Should fail when full
    
    // Test popping items
    std.debug.assert(queue.pop() == 1);
    std.debug.assert(queue.pop() == 2);
    std.debug.assert(queue.pop() == 3);
    std.debug.assert(queue.pop() == 4);
    std.debug.assert(queue.pop() == 5);
    std.debug.assert(queue.pop() == null); // Should be null when empty
    
    std.debug.assert(queue.isEmpty());
    std.debug.assert(!queue.isFull());
}

fn testAtomicEngine() void {
    var atomic_engine = engine.AtomicEngine.init(10);
    defer atomic_engine.deinit();
    
    // Test counter operations
    std.debug.assert(atomic_engine.getCounterValue() == 0);
    
    const inc_result = atomic_engine.increment();
    std.debug.assert(inc_result == 0);
    std.debug.assert(atomic_engine.getCounterValue() == 1);
    
    const dec_result = atomic_engine.decrement();
    std.debug.assert(dec_result == 1);
    std.debug.assert(atomic_engine.getCounterValue() == 0);
    
    // Test flag operations
    std.debug.assert(!atomic_engine.isFlagSet());
    
    atomic_engine.setFlag();
    std.debug.assert(atomic_engine.isFlagSet());
    
    atomic_engine.clearFlag();
    std.debug.assert(!atomic_engine.isFlagSet());
    
    const flag_result = atomic_engine.testAndSetFlag();
    std.debug.assert(!flag_result);
    std.debug.assert(atomic_engine.isFlagSet());
    
    // Test queue operations
    std.debug.assert(atomic_engine.isQueueEmpty());
    std.debug.assert(!atomic_engine.isQueueFull());
    
    std.debug.assert(atomic_engine.enqueue(100));
    std.debug.assert(atomic_engine.enqueue(200));
    std.debug.assert(atomic_engine.enqueue(300));
    
    std.debug.assert(!atomic_engine.isQueueEmpty());
    std.debug.assert(!atomic_engine.isQueueFull());
    
    std.debug.assert(atomic_engine.dequeue() == 100);
    std.debug.assert(atomic_engine.dequeue() == 200);
    std.debug.assert(atomic_engine.dequeue() == 300);
    std.debug.assert(atomic_engine.dequeue() == null);
    
    std.debug.assert(atomic_engine.isQueueEmpty());
}

fn testEdgeCases() void {
    // Test with small queue capacity
    var small_queue = types.AtomicQueue.init(1);
    defer small_queue.deinit();
    
    std.debug.assert(small_queue.push(1));
    std.debug.assert(small_queue.isFull());
    std.debug.assert(!small_queue.push(2));
    std.debug.assert(small_queue.pop() == 1);
    std.debug.assert(small_queue.isEmpty());
    
    // Test counter with negative values
    var counter = types.AtomicCounter.init(-100);
    std.debug.assert(counter.load() == -100);
    
    counter.fetchAdd(50);
    std.debug.assert(counter.load() == -50);
    
    counter.fetchSub(30);
    std.debug.assert(counter.load() == -80);
    
    // Test flag exchange
    var flag = types.AtomicFlag.init();
    std.debug.assert(flag.exchange(1) == 0);
    std.debug.assert(flag.isSet());
    std.debug.assert(flag.exchange(0) == 1);
    std.debug.assert(!flag.isSet());
}
