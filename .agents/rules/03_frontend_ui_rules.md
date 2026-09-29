# Rule 03: Frontend UI, Styling & JavaScript Standards

## 1. Aesthetic Identity & Design System
- **Template Identity:** Follow the Shop.co modern streetwear/e-commerce design aesthetic adapted for **Helmet Cartel** (premium, sleek, bold high-contrast monochrome with dark accents, rounded pill buttons, subtle shadows, and crisp typography).
- **CSS Architecture:**
  - Strictly use **Vanilla CSS** with CSS Custom Properties (`:root` variables) declared in `Content/css/variables.css`.
  - Follow the modular CSS file structure:
    - `variables.css`: Design tokens (colors, typography, spacing, shadows, radius, z-indexes).
    - `reset.css`: Modern normalized box-sizing and baseline rules.
    - `layout.css`: Header, navbar, top promo banner, hero layout, ticker, footer, containers.
    - `components.css`: Buttons, pill tags, badges, product cards, star ratings, inputs, modals, toasts.
    - `storefront.css`: Storefront specific layouts, bento grid for riding styles, customer review carousel, catalog sidebar, pagination, tabs, review cards.
    - `dashboard.css`: Staff/admin inventory tables, stock status badges, order fulfillment board, metrics cards.

## 2. Zero Inline Styles Mandate & CSS Variable Usage
- **Strictly No Inline Styles:** Inline CSS (`style="..."` attributes) is strictly forbidden across all markup files (`.aspx`, `.ascx`, `.Master`). All visual presentation, layout, sizing, padding, and coloring must be declared in modular CSS files using reusable component and utility classes.
- **Mandatory CSS Variable Consumption:** Raw attributes, hardcoded hex values (e.g. `#171717`), raw pixel dimensions (e.g. `24px`), and arbitrary font definitions are prohibited in markup and stylesheets. Every style definition MUST reference the centralized tokens defined in `Content/css/variables.css`:
  - Colors: `var(--color-primary)`, `var(--color-surface)`, `var(--color-text-main)`, `var(--color-border-subtle)`, etc.
  - Spacing: `var(--space-1)` through `var(--space-16)` and `var(--container-padding)`.
  - Radii: `var(--radius-sm)`, `var(--radius-md)`, `var(--radius-lg)`, `var(--radius-pill)`, etc.
  - Typography: `var(--font-display)`, `var(--font-body)`, `var(--text-h1)`, `var(--text-body-sm)`, `var(--weight-bold)`, etc.
- **Dynamic State Classes:** Never toggle styles via `element.style.xxx` in JavaScript; toggle semantic state classes instead (e.g., `.active`, `.hidden`, `.is-open`, `.is-loading`).

## 3. Character Encoding & Currency Formatting Standards
- **Mojibake & Glitch Prevention:** To guarantee symbols like the Philippine Peso (`₱`) and em-dashes (`—`) never corrupt into artifacts such as `â‚±` or `â€”`:
  - Web applications must specify UTF-8 globalization in `Web.config`: `<globalization fileEncoding="utf-8" requestEncoding="utf-8" responseEncoding="utf-8" culture="en-PH" uiCulture="en-PH" />`.
  - In static HTML / ASPX markup, use the official HTML entity `&#8369;` for Philippine Peso, and `&mdash;` for em-dashes.
  - In JavaScript code and string templates, use the Unicode escape `\u20B1` or `AppConstants.CURRENCY_SYMBOL` from `constants.js`.

## 4. UI Component Specifications (Shop.co Layouts)
- **Top Notification Bar:** High-contrast dark banner (`var(--color-surface-contrast)`) with white text and underlined action link.
- **Header:** Sticky navbar with brand logo (`HELMET CARTEL`), dropdown navigation, search bar capsule (`var(--radius-pill)`), shopping cart badge counter, and user profile trigger.
- **Hero Section:** High-impact typography, bold headline (`FIND HELMETS THAT MATCH YOUR STYLE`), bullet statistics (200+ International Brands, 2,000+ High-Quality Helmets, 30,000+ Satisfied Riders), lifestyle hero showcase with decorative star vectors.
- **Brand Ticker:** Black banner displaying leading helmet manufacturers (`SHOEI`, `AGV`, `ARAI`, `HJC`, `BELL`, `SHARK`).
- **Product Cards:** Off-white product image background (`var(--color-surface-subtle)` / `#F0EEED`), rounded corners (`20px`), product title, star rating with numeric score (e.g. `4.5/5`), current price with original strikethrough price and red discount pill (`-20%`).
- **Shop Catalog Page:** 295px sidebar filter card with expandable accordion sections, color swatches with active checkmark, size pill grid, 3-column product catalog grid, and bottom pagination bar (`← Previous`, page pills, `Next →`).
- **Product Detail Page:** Vertical thumbnail gallery (3 thumbnails on left + main image), price row with discount pill, color checkmarks, size selector, quantity stepper, tab bar (`Product Details`, `Rating & Reviews`, `FAQs`), and 2-column reviews grid with green verified badges (`✔`).
- **Bento Style Grid ("Browse by Riding Style"):** Asymmetric responsive cards with background imagery and bold titles (`Casual / Urban`, `Sport / Track`, `Touring / Adventure`, `Off-Road / Motocross`).
- **Customer Testimonials:** 5-star rating cards with verified customer badge (green checkmark), author name, and review quote.
- **Newsletter Card:** Floating dark rounded pill container overlapping the footer.

## 5. JavaScript Standards
- Write modular Vanilla ES6+ JavaScript (`async/await`, `fetch`, `addEventListener`).
- Use centralized constants from `Scripts/constants.js`.
- Store client state (Cart, Auth Tokens) safely in `localStorage` or `sessionStorage` with schema validation.
- Subscribe to real-time events via the SignalR JavaScript client (`Scripts/realtime.js`) and dynamically update stock badges and cart status.
- Ensure accessibility: All interactive elements must have clear focus states, descriptive `aria-label` attributes, and keyboard navigability.

## 6. Storefront Purchasing Flow & Cart Placement Standards
- **Landing Page (`Default.aspx`):** Product cards in "New Arrivals" and "Top Selling" sections serve as visual previews linking directly to `Pages/ProductDetail.aspx?id=...`. They **MUST NOT** include an inline "Add to Cart" button on the home page card.
- **Product Detail Page (`Pages/ProductDetail.aspx`):** The primary purchasing flow resides strictly on this page. It must provide clear color selection swatches, size selection pills, a quantity stepper, and a prominent "Add to Cart" button (`#btn-add-detail` / `.btn--add-cart`).
- **C# Backend Consumption:** The client-side JavaScript (`storefront.js`) must consume product data from the C# Web API endpoints (`/api/v1/products/new-arrivals`, `/api/v1/products/top-selling`, `/api/v1/products`), never inventing or simulating mock backend persistence. All checkout transactions must post to the C# Web API endpoint (`/api/v1/orders`).

## 7. Balanced Layout, Even Spacing & Inline Input Validation Standards
- **Grid-First & Flex Spacing (Zero Ad-Hoc Margin Stacking):** Never stack arbitrary or irregular margins/paddings (`margin-top: 10px`, `margin-bottom: 23px`) to separate form fields or layout cards. Every form, section, and card cluster MUST employ structured CSS Grid or Flexbox with semantic, uniform `gap` variables (`gap: var(--space-3)`, `gap: var(--space-4)`, `gap: var(--space-6)`).
- **Harmonious Form Proportions:** Multi-field inputs must be mathematically balanced (e.g. side-by-side First Name / Last Name split in `1fr 1fr`, city/postal codes in `1fr 1fr 1fr`).
- **Mandatory Inline Input Validation:** Never rely solely on transient toasts, top banners, or native browser alerts for form errors. All interactive input forms (Checkout, Authentication, Address, Profile) MUST feature:
  - Responsive inline validation states (`.is-invalid` on inputs, turning borders and background red).
  - Clear, accessible inline error messages placed directly below the invalid input container (`<span class="inline-error-msg">` or `<span class="auth-error-msg">`).
  - Dual-phase validation triggers: Real-time clearing on `input`, formatted guidance on `blur`, and thorough validation on submit attempt.

