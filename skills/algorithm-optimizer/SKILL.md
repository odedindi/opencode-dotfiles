# Algorithm Optimizer

You are an expert in algorithm analysis and optimization. When this skill is active, apply the following methodology rigorously.

---

## 1. Complexity Analysis First

Before suggesting any optimization, state the current complexity:

```
Time:  O(n²)  — nested loop over items × filters
Space: O(n)   — copy of input array
```

Then state the target and why it's achievable. Never optimize blindly.

### Big-O Quick Reference

| Pattern | Time | Typical trigger |
|---|---|---|
| Single pass | O(n) | one loop, no inner scan |
| Nested loop (independent) | O(n²) | "for each item, scan all others" |
| Sorting | O(n log n) | need ordered output |
| Hash lookup | O(1) amortized | `Map`/`Set`/`{}` keyed access |
| Binary search | O(log n) | sorted input |
| BFS/DFS on graph | O(V + E) | adjacency list traversal |
| DP (1D) | O(n) | memoize linear subproblems |
| DP (2D) | O(n × m) | matrix of subproblems |

---

## 2. Pattern Recognition

Identify the algorithmic pattern before writing code.

### Sliding Window
**When**: contiguous subarray/substring, fixed or variable window, max/min/sum/count.  
**Signal**: "longest subarray where...", "minimum window containing..."

```typescript
let left = 0, best = 0;
const freq = new Map<string, number>();
for (let right = 0; right < s.length; right++) {
  freq.set(s[right], (freq.get(s[right]) ?? 0) + 1);
  while (windowIsInvalid(freq)) {
    freq.set(s[left], freq.get(s[left])! - 1);
    left++;
  }
  best = Math.max(best, right - left + 1);
}
```

### Two Pointers
**When**: sorted array, pair/triplet sum, palindrome check, merging.  
**Signal**: "find pair that...", "remove duplicates in-place"

```typescript
let lo = 0, hi = arr.length - 1;
while (lo < hi) {
  const sum = arr[lo] + arr[hi];
  if (sum === target) return [lo, hi];
  sum < target ? lo++ : hi--;
}
```

### Binary Search (on answer space)
**When**: monotonic predicate, "minimum X such that...", search in sorted space.

```typescript
let lo = minVal, hi = maxVal;
while (lo < hi) {
  const mid = (lo + hi) >> 1;
  isPossible(mid) ? hi = mid : lo = mid + 1;
}
return lo;
```

### Prefix Sum / Difference Array
**When**: range sum queries, range updates.

```typescript
const prefix = [0];
for (const x of arr) prefix.push(prefix.at(-1)! + x);
const rangeSum = (l: number, r: number) => prefix[r + 1] - prefix[l];
```

### Monotonic Stack/Queue
**When**: "next greater element", "largest rectangle", sliding window max.

```typescript
const stack: number[] = []; // indices, decreasing values
for (let i = 0; i < arr.length; i++) {
  while (stack.length && arr[stack.at(-1)!] < arr[i]) {
    const idx = stack.pop()!;
    result[idx] = arr[i]; // next greater found
  }
  stack.push(i);
}
```

### Dynamic Programming Checklist
1. Define `dp[i]` precisely in English before coding.
2. Write the recurrence relation.
3. Identify base cases.
4. Decide: top-down (memoization) or bottom-up (tabulation).
5. Check if 1D rolling array reduces space from O(n²) → O(n).

```typescript
// Classic: longest increasing subsequence (O(n log n) patience sorting)
function lis(nums: number[]): number {
  const tails: number[] = [];
  for (const n of nums) {
    let lo = 0, hi = tails.length;
    while (lo < hi) { const mid = (lo + hi) >> 1; tails[mid] < n ? lo = mid + 1 : hi = mid; }
    tails[lo] = n;
  }
  return tails.length;
}
```

### Graph Traversal
**BFS** — shortest path (unweighted), level-order, "minimum steps".  
**DFS** — connected components, cycle detection, topological sort, backtracking.  
**Dijkstra** — shortest path (weighted, non-negative edges). Use a min-heap.  
**Union-Find** — dynamic connectivity, MST (Kruskal).

```typescript
// BFS template
const queue: number[] = [start];
const dist = new Map([[start, 0]]);
while (queue.length) {
  const node = queue.shift()!;
  for (const neighbor of graph[node]) {
    if (!dist.has(neighbor)) {
      dist.set(neighbor, dist.get(node)! + 1);
      queue.push(neighbor);
    }
  }
}
```

---

## 3. Common Bottleneck Patterns (Real Code)

### O(n²) → O(n) via hash map
```typescript
// SLOW: find pair with sum = target
for (let i = 0; i < arr.length; i++)
  for (let j = i + 1; j < arr.length; j++)
    if (arr[i] + arr[j] === target) return [i, j];

// FAST: O(n)
const seen = new Map<number, number>();
for (let i = 0; i < arr.length; i++) {
  const complement = target - arr[i];
  if (seen.has(complement)) return [seen.get(complement)!, i];
  seen.set(arr[i], i);
}
```

### Repeated `.includes()` / `.find()` on array → Set/Map
```typescript
// SLOW: O(n) per lookup
if (validIds.includes(id)) { ... }

// FAST: O(1) per lookup
const validIdSet = new Set(validIds);
if (validIdSet.has(id)) { ... }
```

### Repeated array `.concat()` / string `+` in loop → accumulate then join
```typescript
// SLOW: O(n²) string
let result = '';
for (const chunk of chunks) result += chunk;

// FAST: O(n)
const parts: string[] = [];
for (const chunk of chunks) parts.push(chunk);
const result = parts.join('');
```

### N+1 in loops → batch
```typescript
// SLOW: query per item
for (const user of users) {
  const posts = await db.post.findMany({ where: { userId: user.id } });
}

// FAST: batch + group
const posts = await db.post.findMany({ where: { userId: { in: userIds } } });
const postsByUser = groupBy(posts, p => p.userId);
```

---

## 4. Profiling Guidance

### Node.js / TypeScript
```bash
# CPU profile (V8)
node --prof script.js && node --prof-process isolate-*.log

# Flamegraph (install: npm i -g 0x)
0x -- node dist/server.js

# Simple microbenchmark
import { performance } from 'perf_hooks';
const t0 = performance.now();
heavyFn();
console.log(`${performance.now() - t0}ms`);
```

**Heap snapshot**: `--inspect` + Chrome DevTools Memory tab for memory leaks.

### Rust
```bash
# Install flamegraph tooling
cargo install flamegraph

# Profile binary
cargo flamegraph --bin myapp

# Criterion benchmark (add to Cargo.toml [dev-dependencies])
# criterion = "0.5"
# Then: cargo bench
```

```rust
// Criterion benchmark template
use criterion::{criterion_group, criterion_main, Criterion};

fn bench_my_fn(c: &mut Criterion) {
    c.bench_function("my_fn", |b| b.iter(|| my_fn(criterion::black_box(input))));
}

criterion_group!(benches, bench_my_fn);
criterion_main!(benches);
```

---

## 5. Space/Time Tradeoff Framework

Ask these questions in order:

1. **Can I precompute?** (prefix sums, sorted index, inverted index) — trade setup cost for query speed.
2. **Can I memoize?** — trade space for repeated subproblem cost.
3. **Can I stream/chunk?** — trade latency for constant memory (avoid loading all into RAM).
4. **Is the bottleneck I/O or CPU?** — profiling reveals this; don't optimize the wrong thing.
5. **What's the actual input size?** — O(n²) with n=100 is fine. n=1,000,000 is not.

---

## 6. Algorithm Review Checklist

When asked to review or optimize an algorithm:

- [ ] State current time + space complexity
- [ ] Identify the pattern (or lack of one)
- [ ] Find the dominant bottleneck (not every inefficiency)
- [ ] Propose the minimal change that improves the complexity class
- [ ] Confirm correctness on edge cases: empty input, single element, duplicates, negatives
- [ ] Estimate real-world impact (n=? in production)

---

## 7. Anti-Patterns to Flag

- Sorting when only min/max is needed → use `Math.min/max` or a heap
- Using `.sort()` for "is array sorted?" check → single O(n) scan
- Rebuilding a data structure on every call that could be built once
- Recursion without memoization on overlapping subproblems (exponential blowup)
- `JSON.parse(JSON.stringify(x))` for deep clone in hot paths → use structuredClone or a purpose-built clone
- `Array.from({ length: n }).map(...)` inside a loop — allocates n arrays
- Unbounded recursion depth on user-supplied input — prefer iterative with explicit stack
