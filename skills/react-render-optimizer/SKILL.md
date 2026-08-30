# React Render Optimizer

React performance guidance for **Oded's** React + TypeScript stack. Focus: preventing unnecessary re-renders and wasted work.

**Rule zero**: Profile before optimizing. Never add `useMemo`/`useCallback` speculatively.

---

## 0. How React Decides to Re-render

A component re-renders when:
1. Its own state changes (`useState`, `useReducer`)
2. Its parent re-renders AND passes new props (by reference)
3. A context it consumes changes
4. Its `key` prop changes (full unmount + remount)

Understanding this is the foundation of all render optimization.

---

## 1. When to Actually Optimize

**Don't optimize until you can measure the problem.**

Signs you have a real render problem:
- Interaction feels sluggish (>50ms input delay)
- React DevTools Profiler shows the same component re-rendering 10+ times per user action
- A heavy component re-renders when clearly nothing relevant changed

**Don't premature-optimize:**
- Simple components (< 50ms to render) — the memoization overhead can exceed the savings
- Components that almost always need to update anyway
- Components not in a hot render path

---

## 2. `React.memo` — Component Memoization

Prevents re-render when parent re-renders but props haven't changed (by shallow comparison).

```typescript
// Use when: the component is expensive AND its parent re-renders frequently
// with props that haven't changed
const UserCard = React.memo(function UserCard({ user }: { user: User }) {
  return <div>{user.name}</div>;
});

// With custom comparison (rare — only when shallow comparison is wrong):
const UserCard = React.memo(UserCardInner, (prev, next) =>
  prev.user.id === next.user.id && prev.user.updatedAt === next.user.updatedAt
);
```

**Common trap**: `React.memo` is useless if the parent passes a new object/array/function literal on every render:

```typescript
// ❌ memo does nothing here — new array reference every render
<UserList users={users.filter(u => u.active)} onSelect={(id) => setSelected(id)} />

// ✅ stabilize the values
const activeUsers = useMemo(() => users.filter(u => u.active), [users]);
const handleSelect = useCallback((id: string) => setSelected(id), []);
<UserList users={activeUsers} onSelect={handleSelect} />
```

---

## 3. `useMemo` — Memoize Expensive Computations

```typescript
// Use when: the computation is genuinely expensive (sort/filter large arrays,
// complex derivations) AND the inputs don't change on every render

const sortedUsers = useMemo(
  () => [...users].sort((a, b) => a.name.localeCompare(b.name)),
  [users]
);

// DO NOT use for: trivial operations
const fullName = useMemo(() => `${first} ${last}`, [first, last]); // ❌ overkill
const fullName = `${first} ${last}`; // ✅ just compute it
```

---

## 4. `useCallback` — Stabilize Function References

```typescript
// Use when: the function is passed as a prop to a memoized child component
// OR is a dependency of another hook

const handleSubmit = useCallback(async (data: FormData) => {
  await createUser(data);
}, []); // stable reference — no deps that change

// DO NOT add useCallback speculatively to every function
// DO NOT wrap functions that aren't passed to memo'd children
```

---

## 5. State Structure Anti-Patterns

### Derived state — compute, don't store
```typescript
// ❌ Storing derived state — double update required, can go out of sync
const [users, setUsers] = useState<User[]>([]);
const [activeCount, setActiveCount] = useState(0); // derived!

// ✅ Compute it
const [users, setUsers] = useState<User[]>([]);
const activeCount = users.filter(u => u.isActive).length; // always correct
```

### State updates that cascade
```typescript
// ❌ Two state updates = two renders
setIsLoading(true);
setData(null);

// ✅ useReducer for related state that changes together
type State = { isLoading: boolean; data: User[] | null; error: string | null };
// Or batch with React 18's automatic batching (already on by default)
```

### Too-high state placement
State placed higher than needed causes the entire subtree to re-render.
Rule: **Place state as close to where it's used as possible.**

---

## 6. Context Performance

Context re-renders ALL consumers whenever the value changes — even consumers that don't use the changed part.

```typescript
// ❌ One context with everything — any change re-renders all consumers
const AppContext = createContext({ user, theme, notifications, cart });

// ✅ Split by update frequency
const UserContext = createContext<User | null>(null);      // changes rarely
const ThemeContext = createContext<Theme>('light');         // changes rarely
const NotifContext = createContext<Notification[]>([]);    // changes often
```

For high-frequency updates in context (e.g., mouse position, scroll), prefer Zustand or a dedicated subscription system.

---

## 7. List Rendering

```typescript
// Always use stable, unique keys — NOT array index for reorderable lists
// ❌ index as key — causes DOM thrashing on reorder/insert
{users.map((user, i) => <UserCard key={i} user={user} />)}

// ✅ stable ID
{users.map(user => <UserCard key={user.id} user={user} />)}

// For very long lists (1000+ items) — virtualize
import { useVirtualizer } from '@tanstack/react-virtual'; // or react-window
```

---

## 8. useEffect Dependency Array Pitfalls

```typescript
// Object/array in deps — new reference every render = infinite loop
useEffect(() => {
  fetchData(options);
}, [options]); // ❌ if options = { page: 1 } — new object each render

// Fix: use primitives or memoize the object
useEffect(() => {
  fetchData({ page, limit });
}, [page, limit]); // ✅ primitives

// Missing deps — stale closures
useEffect(() => {
  setInterval(() => console.log(count), 1000); // ❌ count is stale
}, []);

useEffect(() => {
  const id = setInterval(() => console.log(count), 1000);
  return () => clearInterval(id); // ✅ cleanup + correct dep
}, [count]);
```

---

## 9. Profiling Workflow

1. Open React DevTools Profiler
2. Enable "Record why each component rendered" in settings
3. Record the interaction that feels slow
4. Look for: components that render frequently, renders that take >16ms
5. Fix the most expensive/most-frequent first
6. Re-profile to confirm improvement before moving on

**Chrome Performance tab** for measuring actual frame time and JS blocking.

---

## 10. Quick Reference: When to Use What

| Tool | Use when |
|---|---|
| `React.memo` | Memoized child that receives stable props from a frequently re-rendering parent |
| `useMemo` | Expensive computation (sort/filter/transform large data) with stable deps |
| `useCallback` | Function passed to `memo`-wrapped child or used as a hook dep |
| `useReducer` | Multiple related state values that change together |
| Context split | Context value has parts that update at different frequencies |
| Virtualization | List with 100+ items that causes scroll jank |
| State co-location | State placed too high, causing unrelated subtrees to re-render |
