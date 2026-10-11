// Zig standard library imports
import std.stdio;
import std.math;
import std.container.ArrayList;
import std.traits;

// Cuckoo Filter data structure
struct CuckooFilter {
    ArrayList!(u8) hashTable;
    u32 numHashes;
    u32 capacity;
    u32 numElements;

    // Constructor
    fn init(capacity: u32) !void {
        this.capacity = capacity;
        this.numHashes = log2(capacity) + 1;
        this.hashTable = ArrayList!(u8).create(this.capacity);
        this.numElements = 0;
    }

    // Insert function
    fn insert(self, key: u8) !void {
        const hashIndex = hash(key, self.numHashes);
        const bucketIndex = hashIndex % self.capacity;

        while (self.hashTable[bucketIndex] != 0) {
            const bucketIndexNext = (bucketIndex + 1) % self.capacity;
            while (self.hashTable[bucketIndexNext] != 0) {
                bucketIndexNext = (bucketIndexNext + 1) % self.capacity;
            }
            self.hashTable[bucketIndex] = self.hashTable[bucketIndexNext];
            self.hashTable[bucketIndexNext] = 0;
            bucketIndex = bucketIndexNext;
        }
        self.hashTable[bucketIndex] = key;
        self.numElements += 1;
    }

    // Lookup function
    fn lookup(self, key: u8) bool {
        const hashIndex = hash(key, self.numHashes);
        var found: bool = false;
        for (self.hashTable) |value| {
            if (value == key) {
                found = true;
                break;
            }
        }
        return found;
    }

    // Delete function
    fn delete(self, key: u8) void {
        const hashIndex = hash(key, self.numHashes);
        var found: bool = false;
        for (self.hashTable) |value| {
            if (value == key) {
                found = true;
                break;
            }
        }
        if (!found) {
            std.log.warn("Element not found in Cuckoo Filter");
        }
    }

    // Hash function
    fn hash(key: u8, numHashes: u32) u32 {
        var hash: u32 = 0;
        for (0..numHashes) |i| {
            hash = hash ^ key;
        }
        return hash;
    }
}
