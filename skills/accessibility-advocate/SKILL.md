# Accessibility Advocate

WCAG 2.1 AA compliance for **Oded's** React + TypeScript stack. Accessibility is not optional — it's part of "done."

---

## 0. The Core Rule

If a keyboard-only user, a screen reader user, or a touch-only user can't use the feature, the feature is not complete.

---

## 1. Semantic HTML First

The best accessibility tool is the right HTML element. Use semantic elements before reaching for ARIA.

```tsx
// ❌ div soup — no semantics
<div onClick={handleSubmit}>Submit</div>
<div className="nav">
  <div onClick={() => navigate('/home')}>Home</div>
</div>

// ✅ semantic HTML
<button type="submit" onClick={handleSubmit}>Submit</button>
<nav>
  <a href="/home">Home</a>
</nav>
```

### Element → Role mapping (prefer the element)
| Semantic element | ARIA role it conveys |
|---|---|
| `<button>` | `button` (keyboard focusable, space/enter activates) |
| `<a href>` | `link` |
| `<nav>` | `navigation` |
| `<main>` | `main` |
| `<header>` | `banner` |
| `<footer>` | `contentinfo` |
| `<aside>` | `complementary` |
| `<h1>`–`<h6>` | `heading` with level |
| `<ul>/<ol>/<li>` | `list`/`listitem` |
| `<table>` | `table` (with `<th scope>`, `<caption>`) |
| `<input type="checkbox">` | `checkbox` |

---

## 2. ARIA — When and How

ARIA supplements HTML when semantics are missing. **First rule of ARIA: don't use ARIA if HTML can do it.**

### Required ARIA patterns

```tsx
// Modal / Dialog
<div
  role="dialog"
  aria-modal="true"
  aria-labelledby="dialog-title"
  aria-describedby="dialog-desc"
>
  <h2 id="dialog-title">Confirm Delete</h2>
  <p id="dialog-desc">This action cannot be undone.</p>
</div>

// Icon button (no visible text)
<button aria-label="Close dialog">
  <XIcon aria-hidden="true" />
</button>

// Loading state
<div aria-live="polite" aria-atomic="true">
  {isLoading ? 'Loading...' : ''}
</div>

// Form field with error
<div>
  <label htmlFor="email">Email</label>
  <input
    id="email"
    type="email"
    aria-describedby="email-error"
    aria-invalid={!!errors.email}
  />
  {errors.email && (
    <span id="email-error" role="alert">{errors.email.message}</span>
  )}
</div>

// Toggle button
<button
  aria-pressed={isActive}
  onClick={() => setIsActive(v => !v)}
>
  {isActive ? 'Active' : 'Inactive'}
</button>

// Expandable section
<button
  aria-expanded={isOpen}
  aria-controls="section-content"
>
  Show details
</button>
<div id="section-content" hidden={!isOpen}>...</div>
```

### `aria-live` regions for dynamic content
```tsx
// polite: announces after current speech finishes (status updates, search results)
// assertive: interrupts immediately (errors, critical alerts — use sparingly)
<div aria-live="polite">
  {statusMessage}
</div>

// Role="alert" is shorthand for aria-live="assertive" + aria-atomic="true"
<div role="alert">{errorMessage}</div>
```

---

## 3. Keyboard Navigation

Every interactive element must be:
1. **Focusable** — reachable via Tab
2. **Activatable** — Enter or Space triggers the action
3. **Visible** — focus indicator is never removed (`:focus-visible` is fine; `:focus { outline: none }` is not)

```tsx
// ❌ Non-keyboard-accessible custom "button"
<div className="btn" onClick={handleClick}>Click me</div>

// ✅ Option A: Use a real button
<button onClick={handleClick}>Click me</button>

// ✅ Option B: If truly must use div (avoid unless necessary)
<div
  role="button"
  tabIndex={0}
  onClick={handleClick}
  onKeyDown={(e) => (e.key === 'Enter' || e.key === ' ') && handleClick()}
>
  Click me
</div>
```

### Focus management for dynamic UI
```tsx
// Modal: trap focus inside when open, restore focus when closed
// Dropdown: arrow keys navigate items; Escape closes and returns focus
// Toast/notification: focus stays where it is (use aria-live instead)

// Move focus to modal on open
useEffect(() => {
  if (isOpen) {
    dialogRef.current?.focus();
  }
}, [isOpen]);
```

### Keyboard interaction patterns by widget type

| Widget | Keys required |
|---|---|
| Button | Enter, Space |
| Link | Enter |
| Checkbox | Space (toggle) |
| Radio group | Arrow keys move within group, Tab exits |
| Listbox / Select | Arrow keys navigate, Enter/Space select, Escape close |
| Combobox / Autocomplete | Arrow keys navigate suggestions, Enter select, Escape close |
| Dialog / Modal | Tab/Shift+Tab cycle within, Escape closes |
| Tabs | Arrow keys switch tabs, Tab moves into panel |
| Accordion | Enter/Space toggle, Arrow keys optionally move between headers |
| Slider | Arrow keys adjust value, Home/End jump to min/max |
| Menu / Menubar | Arrow keys navigate, Enter/Space activate, Escape close |
| Tree | Arrow keys expand/collapse/navigate, Enter activate |
| Date picker | Arrow keys navigate days, Page Up/Down switch months |

### Never do
- `outline: none` or `outline: 0` without providing a replacement focus style
- `tabIndex={-1}` on interactive elements (only valid on elements you programmatically focus)
- `tabIndex > 0` (breaks natural tab order — only `0` or `-1`)
- Trap focus outside of intentional overlays (modals, drawers)

---

## 4. Touch Devices

Touch users have no hover state, no keyboard, and interact with fingers — not pixel-precise pointers.

### Touch target sizing
```tsx
// Minimum 44×44px touch target (WCAG 2.5.5)
// Even if the visual element is smaller, pad it

// ❌ 16px icon button — impossible to tap accurately
<button className="p-0">
  <CloseIcon className="w-4 h-4" />
</button>

// ✅ Padded to meet minimum touch target
<button className="p-3" aria-label="Close">
  <CloseIcon className="w-4 h-4 pointer-events-none" />
</button>

// ✅ Or use min-w/min-h
<button className="min-w-[44px] min-h-[44px] flex items-center justify-center" aria-label="Close">
  <CloseIcon className="w-4 h-4" />
</button>
```

### Touch-specific interactions
```tsx
// Never rely on hover to reveal critical UI (touch has no hover)
// ❌ Tooltip that only shows on hover
<div className="group relative">
  <button>Info</button>
  <span className="hidden group-hover:block">Tooltip text</span>
</div>

// ✅ Use tap-toggleable tooltip or always-visible helper text
<div>
  <button
    aria-describedby="info-tooltip"
    onClick={() => setTooltipVisible(v => !v)}
  >
    Info
  </button>
  {tooltipVisible && (
    <span id="info-tooltip" role="tooltip">Tooltip text</span>
  )}
</div>

// Swipe gestures must always have a tap/button alternative
// Long-press must always have a tap/button alternative
```

### Pointer events
```tsx
// Use pointer events (not mouse events) for cross-device support
// onPointerDown / onPointerUp / onPointerMove — works for mouse, touch, stylus
// onClick — works everywhere for activation (prefer this for simple taps)

// ❌ Mouse-only drag
onMouseDown / onMouseMove / onMouseUp

// ✅ Pointer-based drag
onPointerDown / onPointerMove / onPointerUp
// Remember to call e.currentTarget.setPointerCapture(e.pointerId) on pointerdown for drag
```

### Scroll and overflow
```tsx
// Scrollable containers on iOS require -webkit-overflow-scrolling or overflow touch
// Use Tailwind: overflow-auto (includes touch scrolling fix via modern CSS)

// Pinch-zoom must not be disabled
// ❌ Never do this:
<meta name="viewport" content="width=device-width, initial-scale=1, user-scalable=no" />

// ✅
<meta name="viewport" content="width=device-width, initial-scale=1" />
```

### Touch checklist
- [ ] All tap targets ≥ 44×44px
- [ ] No functionality hidden behind hover only
- [ ] Swipe/long-press interactions have button alternatives
- [ ] Pinch-zoom is not disabled in the viewport meta tag
- [ ] Scrollable containers are scrollable with touch (not just mouse wheel)
- [ ] No `pointer-events: none` on elements that need to be tappable

---

## 4. Images and Media

```tsx
// Informative image — describe the content
<img src="chart.png" alt="Monthly revenue grew 45% from Jan to Jun 2024" />

// Decorative image — empty alt, screen reader ignores it
<img src="divider.svg" alt="" />

// Icon with adjacent text — hide icon from screen readers
<button>
  <SearchIcon aria-hidden="true" />
  Search
</button>

// Complex image (chart, diagram) — link to a description
<figure>
  <img src="architecture.png" alt="System architecture diagram" aria-describedby="arch-desc" />
  <figcaption id="arch-desc">
    The frontend connects to an Express API which queries PostgreSQL...
  </figcaption>
</figure>
```

---

## 5. Forms

```tsx
// Every input MUST have a label — never use placeholder as the only label
// ❌
<input type="email" placeholder="Enter your email" />

// ✅ Visible label
<label htmlFor="email">Email address</label>
<input id="email" type="email" placeholder="name@example.com" />

// ✅ Visually hidden label (when design has no visible label)
<label htmlFor="search" className="sr-only">Search</label>
<input id="search" type="search" />

// Group related controls
<fieldset>
  <legend>Notification preferences</legend>
  <label><input type="checkbox" name="email" /> Email</label>
  <label><input type="checkbox" name="sms" /> SMS</label>
</fieldset>
```

---

## 6. Color and Visual Design

- **Color contrast**: 4.5:1 minimum for normal text, 3:1 for large text (18pt+ or 14pt bold)
- **Never use color alone** to convey information — always pair with text, icon, or pattern
- **Focus indicators**: visible on all interactive elements (browser default is often sufficient with `:focus-visible`)

```tsx
// ❌ Color only — colorblind users can't distinguish
<span style={{ color: 'red' }}>Error</span>

// ✅ Color + icon + text
<span className="text-red-600">
  <ErrorIcon aria-hidden="true" />
  {' '}Error: Email is required
</span>
```

---

## 7. Tailwind Accessibility Utilities

```
sr-only          — visually hidden but available to screen readers
not-sr-only      — reverse sr-only
focus:ring-2     — visible focus ring
focus-visible:   — only show focus ring on keyboard navigation
```

```tsx
// Visually hidden (accessible text for screen readers)
<span className="sr-only">Close menu</span>

// Skip to main content link (important for keyboard users)
<a href="#main-content" className="sr-only focus:not-sr-only focus:fixed focus:top-4 focus:left-4">
  Skip to main content
</a>
```

---

## 8. Screen Readers — Deep Reference

### How screen readers work
Screen readers traverse the **accessibility tree** (a parallel DOM built from semantic HTML + ARIA). They announce elements by: **role → name → state → value**.

Example: `<button aria-pressed="true">Mute</button>` → announces *"Mute, toggle button, pressed"*

### Naming an element (accessible name computation, in priority order)
1. `aria-labelledby` — points to another element's text (highest priority)
2. `aria-label` — inline string label
3. Native label: `<label>` for inputs, `<caption>` for tables, `<figcaption>` for figures
4. Element's own text content (for buttons, links, headings)
5. `title` attribute (last resort — also shows as tooltip)

```tsx
// aria-labelledby: reuse visible text as the label
<section aria-labelledby="section-heading">
  <h2 id="section-heading">Recent Orders</h2>
</section>

// aria-label: when no visible text is available
<button aria-label="Delete order #1042">
  <TrashIcon aria-hidden="true" />
</button>

// Never put meaningful text only in title — it's unreliable across SRs
```

### Describing an element (additional context beyond the name)
```tsx
// aria-describedby: supplementary description (read after the name)
<input
  id="password"
  type="password"
  aria-describedby="password-hint password-error"
/>
<p id="password-hint">Must be at least 8 characters.</p>
<span id="password-error" role="alert">{errors.password}</span>
// SR announces: "Password, edit text. Must be at least 8 characters. [error if any]"
```

### ARIA roles — full reference

**Landmark roles** (use semantic HTML equivalents first):
| Role | HTML equivalent | Purpose |
|---|---|---|
| `banner` | `<header>` | Site header (once per page) |
| `navigation` | `<nav>` | Navigation region — give each a unique `aria-label` if multiple |
| `main` | `<main>` | Primary content (once per page) |
| `complementary` | `<aside>` | Secondary content |
| `contentinfo` | `<footer>` | Site footer (once per page) |
| `search` | `<search>` (HTML5) | Search region |
| `form` | `<form aria-label>` | Only assigned when form has an accessible name |
| `region` | `<section aria-labelledby>` | Generic landmark — only use with a label |

**Widget roles** (when semantic HTML is insufficient):
| Role | Use case | Required keyboard |
|---|---|---|
| `button` | Div acting as button | Enter, Space |
| `link` | Div acting as link | Enter |
| `checkbox` | Custom checkbox | Space to toggle |
| `radio` | Custom radio | Arrow keys within group |
| `switch` | On/off toggle | Space |
| `slider` | Range input | Arrow keys, Home, End |
| `spinbutton` | Numeric increment | Arrow keys, Home, End, Page Up/Down |
| `combobox` | Input + dropdown | Arrow keys, Enter, Escape |
| `listbox` | Select list | Arrow keys, Enter, Escape |
| `option` | Items inside listbox | (managed by listbox) |
| `menu` | Action menu | Arrow keys, Enter, Escape |
| `menuitem` | Item in menu | (managed by menu) |
| `menuitemcheckbox` | Checkable menu item | Space |
| `menuitemradio` | Radio menu item | Arrow keys |
| `tab` | Tab in tablist | Arrow keys |
| `tablist` | Container for tabs | (manages tabs) |
| `tabpanel` | Content of a tab | Tab to enter |
| `tree` | Hierarchical list | Arrow keys |
| `treeitem` | Item in tree | Arrow keys, Enter |
| `grid` | Interactive table | Arrow keys |
| `gridcell` | Cell in grid | Enter to activate |
| `dialog` | Modal overlay | Tab/Shift+Tab, Escape |
| `alertdialog` | Modal that requires response | Tab/Shift+Tab, Escape |
| `tooltip` | Hover/focus popup | Escape to dismiss |
| `status` | Non-urgent live region | (announced politely) |
| `alert` | Urgent live region | (interrupts immediately) |
| `log` | Appending live region (chat, log) | `aria-live="polite"` |
| `marquee` | Rotating content | (use sparingly) |
| `timer` | Countdown / elapsed | `aria-live="off"` usually |
| `progressbar` | Loading/progress | `aria-valuenow`, `aria-valuemin`, `aria-valuemax` |

**Document structure roles** (rarely needed — semantic HTML preferred):
`article`, `definition`, `figure`, `heading`, `img`, `list`, `listitem`, `math`, `note`, `presentation`, `none`, `separator`, `term`

### Critical ARIA attributes

```tsx
// State attributes — reflect UI state
aria-expanded={boolean}        // collapsibles, dropdowns, accordions
aria-pressed={boolean}         // toggle buttons
aria-checked={boolean | 'mixed'} // checkboxes, switches
aria-selected={boolean}        // options, tabs, tree items
aria-disabled={boolean}        // disabled but still in accessibility tree (vs HTML disabled which removes it)
aria-hidden={boolean}          // remove from accessibility tree entirely
aria-invalid={boolean | 'grammar' | 'spelling'} // form validation
aria-busy={boolean}            // content is updating (use on container)
aria-current={'page' | 'step' | 'location' | 'date' | 'time' | boolean} // current item in set

// Relationship attributes
aria-labelledby="id1 id2"      // label from other element(s)
aria-describedby="id1 id2"     // description from other element(s)
aria-controls="id"             // this element controls that one
aria-owns="id"                 // this element owns that one (for DOM order issues)
aria-flowto="id"               // next reading order element (rarely needed)
aria-activedescendant="id"     // active child in composite widget (listbox, grid)
aria-errormessage="id"         // points to error message element (use with aria-invalid)
aria-details="id"              // extended description (richer than aria-describedby)

// Set/position attributes
aria-setsize={number}          // total items in set (for virtual lists)
aria-posinset={number}         // position within set
aria-level={number}            // heading level for role="heading"
aria-rowcount / aria-colcount  // total rows/cols in grid (for virtual grids)
aria-rowindex / aria-colindex  // position in virtual grid

// Value attributes
aria-valuenow={number}         // current value (sliders, progress)
aria-valuemin={number}         // min value
aria-valuemax={number}         // max value
aria-valuetext="string"        // human-readable value when number is insufficient
                               // e.g. aria-valuenow=7 aria-valuetext="Monday"

// Live region attributes
aria-live="off | polite | assertive"
aria-atomic={boolean}          // announce entire region or just changed part
aria-relevant="additions removals text all" // what changes trigger announcement
```

### Common screen reader patterns

```tsx
// Tabs
<div role="tablist" aria-label="Account settings">
  <button role="tab" aria-selected={true} aria-controls="profile-panel" id="profile-tab">Profile</button>
  <button role="tab" aria-selected={false} aria-controls="billing-panel" id="billing-tab" tabIndex={-1}>Billing</button>
</div>
<div role="tabpanel" id="profile-panel" aria-labelledby="profile-tab">...</div>
<div role="tabpanel" id="billing-panel" aria-labelledby="billing-tab" hidden>...</div>

// Accordion
<h3>
  <button aria-expanded={isOpen} aria-controls="faq-answer">What is this?</button>
</h3>
<div id="faq-answer" hidden={!isOpen}>Answer text</div>

// Combobox / Autocomplete
<input
  role="combobox"
  aria-expanded={isOpen}
  aria-autocomplete="list"
  aria-controls="suggestions-list"
  aria-activedescendant={selectedId}
/>
<ul role="listbox" id="suggestions-list">
  <li role="option" id="opt-1" aria-selected={false}>Option 1</li>
</ul>

// Progress bar
<div
  role="progressbar"
  aria-valuenow={65}
  aria-valuemin={0}
  aria-valuemax={100}
  aria-valuetext="65% complete"
>
  <div style={{ width: '65%' }} />
</div>

// Breadcrumb
<nav aria-label="Breadcrumb">
  <ol>
    <li><a href="/">Home</a></li>
    <li><a href="/products">Products</a></li>
    <li><a href="/products/shoes" aria-current="page">Shoes</a></li>
  </ol>
</nav>

// Skip link (must be first focusable element)
<a href="#main" className="sr-only focus:not-sr-only focus:fixed focus:top-2 focus:left-2 focus:z-50 focus:p-2 focus:bg-white focus:text-black">
  Skip to main content
</a>

// Live status message
<div role="status" aria-live="polite" aria-atomic="true" className="sr-only">
  {statusMessage} {/* e.g. "3 results found" */}
</div>
```

### What screen readers actually announce — common gotchas

- `display: none` / `visibility: hidden` / `hidden` attr → **removed** from accessibility tree (correct for truly hidden content)
- `opacity: 0` → **still in** accessibility tree (focusable, announced — usually a bug)
- Placeholder text is **not** a label — it disappears on input and has low contrast
- `aria-hidden="true"` on a focusable element → **still focusable** (keyboard trap) — always pair with `tabIndex={-1}` or `disabled`
- Nested interactive elements (e.g. `<button>` inside `<a>`) → undefined behavior in most SRs — avoid
- SVG `<title>` is unreliable — use `aria-label` on the containing element instead
- `role="presentation"` / `role="none"` strips role but keeps content — use for layout tables, decorative wrappers

---

## 8. Accessibility Checklist for New Components

Before marking a component complete:

**Screen readers**
- [ ] Every interactive element has an accessible name (visible text, `aria-label`, or `aria-labelledby`)
- [ ] Landmark regions used correctly (`<main>`, `<nav>`, `<header>`, `<footer>`)
- [ ] Multiple `<nav>` / `<section>` elements each have a unique `aria-label`
- [ ] Dynamic content updates use `aria-live`, `role="status"`, or `role="alert"`
- [ ] ARIA state attributes kept in sync with UI state (`aria-expanded`, `aria-selected`, `aria-checked`, etc.)
- [ ] Icon-only elements have `aria-label`; decorative icons have `aria-hidden="true"`
- [ ] No `opacity: 0` on focusable elements (use `display: none` or `aria-hidden + tabIndex={-1}`)
- [ ] Custom widgets follow the correct ARIA role + keyboard pattern

**Keyboard users**
- [ ] All interactive elements reachable via Tab
- [ ] All interactive elements activatable via Enter or Space
- [ ] Focus indicator visible on all focused elements (no bare `outline: none`)
- [ ] Composite widgets (tabs, listbox, menu) use arrow-key navigation internally
- [ ] Modals/drawers trap focus when open and restore it on close
- [ ] Skip-to-main link is first focusable element on the page
- [ ] `tabIndex > 0` is never used

**Touch devices**
- [ ] All tap targets ≥ 44×44px
- [ ] No functionality gated behind hover only
- [ ] Swipe/long-press interactions have button alternatives
- [ ] Pinch-zoom not disabled in viewport meta
- [ ] Scrollable containers work with touch

**Visual**
- [ ] Semantic HTML element used (not div soup)
- [ ] All images have appropriate `alt` text (empty for decorative)
- [ ] All form inputs have `<label>` (not placeholder-only)
- [ ] Error messages linked via `aria-describedby` + `aria-invalid`
- [ ] Color contrast ≥ 4.5:1 for normal text, 3:1 for large text
- [ ] Color is never the sole conveyor of information

---

## 9. Testing Accessibility

```bash
# axe-core via jest-axe
import { axe, toHaveNoViolations } from 'jest-axe';
expect.extend(toHaveNoViolations);

it('has no accessibility violations', async () => {
  const { container } = render(<MyComponent />);
  const results = await axe(container);
  expect(results).toHaveNoViolations();
});
```

Manual checks (do these before shipping UI changes):
1. Tab through the entire feature — can you reach everything?
2. Activate everything with Enter/Space — does it work?
3. Touch-only: tap through on a phone — are all targets big enough? Any hover-only interactions?
4. Test with macOS VoiceOver (Cmd+F5) or NVDA — does it announce correctly?
5. Check browser devtools accessibility tree — verify roles, names, states
6. Run axe DevTools browser extension for automated violations
