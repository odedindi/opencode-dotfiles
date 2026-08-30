# Rust Learner Guide

This skill helps **Oded** — an experienced TypeScript engineer — learn Rust by mapping concepts from TypeScript to Rust equivalents.

**Oded's goal**: Get hands dirty with Rust. Understand ownership, learn the ecosystem, write real code.

---

## The Core Difference: Ownership

Rust's ownership model is the hardest part. Everything else makes sense once this clicks.

### Memory in TypeScript vs Rust

```typescript
// TypeScript: GC handles memory — you never think about it
let s1 = "hello"
let s2 = s1  // s1 is still usable, both point to same data (GC manages)
console.log(s1, s2)  // works fine
```

```rust
// Rust: No GC. Each value has exactly ONE owner.
let s1 = String::from("hello");
let s2 = s1;  // s1 is MOVED into s2. s1 no longer exists.
println!("{}", s1);  // COMPILE ERROR: value borrowed after move
println!("{}", s2);  // OK
```

### The Three Rules of Ownership

1. Each value in Rust has **exactly one owner**
2. When the owner goes out of scope, the value is **dropped** (memory freed)
3. There can only be **one owner at a time**

### Borrowing — Temporary Access Without Transfer

```rust
// & = immutable reference (borrow without taking ownership)
fn print_length(s: &String) {
    println!("Length: {}", s.len());
    // s is dropped here, but we don't own it, so original is unaffected
}

let s = String::from("hello");
print_length(&s);  // lend s to the function
println!("{}", s); // s still works — we only borrowed it

// &mut = mutable reference
fn add_world(s: &mut String) {
    s.push_str(", world");
}

let mut s = String::from("hello");
add_world(&mut s);
println!("{}", s);  // "hello, world"
```

### Borrowing Rules (the compiler enforces these)

```rust
// Rule: At any given time, you can have EITHER:
// - Any number of immutable references (&T), OR
// - Exactly one mutable reference (&mut T)
// NOT BOTH AT THE SAME TIME

let mut s = String::from("hello");

let r1 = &s;      // OK: immutable borrow
let r2 = &s;      // OK: multiple immutable borrows are fine
let r3 = &mut s;  // COMPILE ERROR: can't borrow mutably while immutably borrowed

// This prevents data races at compile time!
```

---

## TypeScript → Rust Type Mapping

| TypeScript | Rust | Notes |
|---|---|---|
| `string` | `String` (owned) / `&str` (borrowed) | `&str` for literals and function params |
| `number` | `i32`, `i64`, `u32`, `u64`, `f64` | Pick the right size |
| `boolean` | `bool` | Same |
| `null` / `undefined` | `Option<T>` | `Some(value)` or `None` |
| Throwing errors | `Result<T, E>` | `Ok(value)` or `Err(error)` |
| `any[]` | `Vec<T>` | Growable array |
| `[T, U]` | `(T, U)` | Tuple |
| `Record<K, V>` | `HashMap<K, V>` | |
| `interface` | `struct` | |
| `type union` | `enum` | Much more powerful in Rust |

---

## String vs &str — The Biggest Gotcha

```rust
// String: owned, heap-allocated, growable
let owned: String = String::from("hello");
let also_owned: String = "hello".to_string();

// &str: borrowed string slice, just a reference to string data
let borrowed: &str = "hello";  // string literal — lives in program binary
let slice: &str = &owned[0..3];  // slice of an owned String

// Rule of thumb:
// - Function parameters: prefer &str (accepts both String and &str)
// - Return values: use String if you create it, &str if you borrow it
// - Struct fields: String (you need to own it for the struct to be valid)

fn greet(name: &str) -> String {  // takes &str, returns owned String
    format!("Hello, {}!", name)
}

greet("Alice");                    // works: &str literal
greet(&my_string);                 // works: String auto-borrows to &str
```

---

## Option and Result — No Nulls or Exceptions

### Option<T> = nullable value (like `T | null`)

```rust
// Option<T> = Some(T) | None
fn find_user(id: u32) -> Option<User> {
    if id == 1 { Some(User { id: 1, name: "Alice".to_string() }) }
    else { None }
}

// Pattern matching (exhaustive — compiler checks all cases)
match find_user(1) {
    Some(user) => println!("Found: {}", user.name),
    None => println!("Not found"),
}

// Convenience methods (like optional chaining in TS)
let name = find_user(1)
    .map(|u| u.name)             // transform if Some
    .unwrap_or("Anonymous".to_string());  // default if None

// ? operator: propagate None early (like optional chaining ?.)
fn get_user_name(id: u32) -> Option<String> {
    let user = find_user(id)?;  // returns None if find_user returns None
    Some(user.name)
}
```

### Result<T, E> = typed errors (like try/catch but in the type)

```rust
// Result<T, E> = Ok(T) | Err(E)
fn parse_age(s: &str) -> Result<u32, String> {
    s.parse::<u32>().map_err(|e| format!("Invalid age: {}", e))
}

// ? operator: propagate errors early (like throw in TS, but typed)
fn process(input: &str) -> Result<String, String> {
    let age = parse_age(input)?;  // returns Err early if parse fails
    Ok(format!("Age: {}", age))
}

// In main with anyhow (recommended crate for error handling)
use anyhow::{Result, anyhow, Context};

fn main() -> Result<()> {
    let content = std::fs::read_to_string("file.txt")
        .context("Failed to read file")?;  // adds context to error
    println!("{}", content);
    Ok(())
}
```

---

## Structs and Enums

### Structs (like interfaces/classes)

```rust
// Define
#[derive(Debug, Clone)]  // auto-implement Debug (printing) and Clone
struct User {
    id: u32,
    name: String,
    email: String,
}

// Implement methods
impl User {
    // Associated function (like static method)
    fn new(name: &str, email: &str) -> Self {
        User { id: rand::random(), name: name.to_string(), email: email.to_string() }
    }

    // Method (takes self)
    fn greeting(&self) -> String {
        format!("Hi, I'm {}", self.name)
    }

    // Mutable method
    fn set_name(&mut self, name: &str) {
        self.name = name.to_string();
    }
}

let mut user = User::new("Alice", "alice@example.com");
user.set_name("Bob");
println!("{}", user.greeting());
```

### Enums — More Powerful Than TypeScript

```rust
// Rust enums can hold data (like discriminated unions in TS)
enum Shape {
    Circle { radius: f64 },
    Rectangle { width: f64, height: f64 },
    Triangle(f64, f64, f64),  // tuple variant
}

// Pattern match on enum (must be exhaustive)
fn area(shape: &Shape) -> f64 {
    match shape {
        Shape::Circle { radius } => std::f64::consts::PI * radius * radius,
        Shape::Rectangle { width, height } => width * height,
        Shape::Triangle(a, b, c) => {
            let s = (a + b + c) / 2.0;
            (s * (s - a) * (s - b) * (s - c)).sqrt()
        }
    }
}
```

---

## Traits — Like TypeScript Interfaces

```rust
// Define trait (like TS interface)
trait Greet {
    fn greet(&self) -> String;
    fn greet_formally(&self) -> String {  // default implementation
        format!("Good day, {}.", self.greet())
    }
}

// Implement trait for a type
impl Greet for User {
    fn greet(&self) -> String {
        format!("Hi, I'm {}", self.name)
    }
}

// Trait bounds in function signatures (like generic constraints in TS)
fn print_greeting<T: Greet>(item: &T) {  // T must implement Greet
    println!("{}", item.greet());
}

// Or with where clause (cleaner for multiple bounds)
fn process<T>(item: &T) where T: Greet + Clone + std::fmt::Debug {
    println!("{:?}", item);
}
```

---

## Cargo — The Build System

```toml
# Cargo.toml — like package.json
[package]
name = "my-app"
version = "0.1.0"
edition = "2021"

[dependencies]
# Essentials for a Rust TypeScript developer
tokio = { version = "1", features = ["full"] }  # async runtime (like Node.js event loop)
serde = { version = "1", features = ["derive"] }  # JSON serialization
serde_json = "1"                                   # JSON support
anyhow = "1"                                       # ergonomic error handling
thiserror = "1"                                    # derive Error for custom errors
axum = "0.7"                                       # web framework (like Express)
sqlx = { version = "0.7", features = ["postgres", "runtime-tokio"] }  # SQL
reqwest = { version = "0.11", features = ["json"] }  # HTTP client
uuid = { version = "1", features = ["v4"] }        # UUIDs
chrono = { version = "0.4", features = ["serde"] } # Dates
dotenvy = "0.15"                                   # .env files
tracing = "0.1"                                    # structured logging
tracing-subscriber = "0.3"                         # log output
```

```bash
cargo new my-app          # create project (like npm init)
cargo add tokio           # add dependency (like npm install)
cargo build               # compile
cargo run                 # run
cargo test                # test
cargo check               # type check without building (fast)
cargo clippy              # linter (like eslint)
cargo fmt                 # formatter (like prettier)
```

---

## Async Rust with Tokio

```rust
use tokio;

// Async functions look similar to TypeScript
async fn fetch_user(id: u32) -> Result<User, anyhow::Error> {
    let url = format!("https://api.example.com/users/{}", id);
    let user: User = reqwest::get(&url).await?.json().await?;
    Ok(user)
}

// Main with tokio runtime
#[tokio::main]
async fn main() -> Result<(), anyhow::Error> {
    let user = fetch_user(1).await?;
    println!("{:?}", user);
    Ok(())
}

// Parallel execution (like Promise.all)
use tokio::join;
let (users, posts) = join!(fetch_users(), fetch_posts());

// Or for dynamic collections
use futures::future::join_all;
let results = join_all(ids.iter().map(|id| fetch_user(*id))).await;
```

---

## Axum — Express Equivalent

```rust
use axum::{Router, routing::get, Json, extract::Path};
use serde::{Serialize, Deserialize};

#[derive(Serialize, Deserialize)]
struct User {
    id: u32,
    name: String,
}

// Route handler
async fn get_user(Path(id): Path<u32>) -> Json<User> {
    Json(User { id, name: "Alice".to_string() })
}

#[tokio::main]
async fn main() {
    let app = Router::new()
        .route("/users/:id", get(get_user));

    let listener = tokio::net::TcpListener::bind("0.0.0.0:3000").await.unwrap();
    axum::serve(listener, app).await.unwrap();
}
```

---

## Serde — JSON Serialization

```rust
use serde::{Serialize, Deserialize};

// Auto-derive serialization (like Zod but compile-time)
#[derive(Debug, Serialize, Deserialize)]
struct CreateUserInput {
    name: String,
    email: String,
    #[serde(rename = "roleId")]  // camelCase JSON, snake_case Rust
    role_id: Option<u32>,
    #[serde(default)]  // use Default::default() if field missing
    active: bool,
}

// JSON to struct
let input: CreateUserInput = serde_json::from_str(json_str)?;

// Struct to JSON
let json = serde_json::to_string(&input)?;
```

---

## Lifetimes — When Borrowing Gets Complex

```rust
// Lifetimes are usually inferred. You only write them when the compiler can't figure it out.
// The 'a syntax means "this reference lives at least as long as lifetime 'a"

// This won't compile (compiler needs to know which input the output borrows from)
fn longest(x: &str, y: &str) -> &str {  // ERROR: missing lifetime specifier
    if x.len() > y.len() { x } else { y }
}

// With lifetime annotation: "output lives as long as the shorter of x and y"
fn longest<'a>(x: &'a str, y: &'a str) -> &'a str {
    if x.len() > y.len() { x } else { y }
}

// In practice: if you're getting lifetime errors, consider:
// 1. Return an owned value (String instead of &str)
// 2. Clone the data
// 3. Use Arc<String> for shared ownership
// Lifetimes in function signatures are needed less than you'd think
```

---

## Common Patterns for TypeScript Developers

```rust
// TypeScript: Optional chaining ?.
// Rust: Option combinators
let name = user.profile?.avatar?.url;
// vs
let name = user.profile.as_ref().and_then(|p| p.avatar.as_ref()).map(|a| &a.url);

// TypeScript: Array methods (map, filter, reduce)
// Rust: Iterator methods (same ideas, lazy evaluation)
let doubled: Vec<i32> = numbers.iter().map(|n| n * 2).collect();
let evens: Vec<&i32> = numbers.iter().filter(|&&n| n % 2 == 0).collect();
let sum: i32 = numbers.iter().sum();
let total: i32 = numbers.iter().fold(0, |acc, &n| acc + n);

// TypeScript: try { } catch { }
// Rust: ? operator + match/if let
fn process() -> Result<(), anyhow::Error> {
    let data = read_file()?;        // propagate error
    let parsed = parse_data(&data)?;
    Ok(())
}

// TypeScript: console.log
// Rust: println! / dbg! / tracing::info!
println!("Value: {}", value);           // basic print
println!("Debug: {:?}", complex_value); // debug print
dbg!(&value);                           // print with file/line info (dev only)
```

---

## Where to Start

1. **Read**: [The Book](https://doc.rust-lang.org/book/) — chapters 1-10 cover ownership, structs, enums, error handling
2. **Practice**: [Rustlings](https://github.com/rust-lang/rustlings) — small exercises
3. **First project**: CLI tool (parsing args with `clap`, reading files, JSON with `serde`)
4. **Second project**: HTTP API with `axum` + `sqlx` + `tokio`
5. **Reference**: [Rust by Example](https://doc.rust-lang.org/rust-by-example/)
