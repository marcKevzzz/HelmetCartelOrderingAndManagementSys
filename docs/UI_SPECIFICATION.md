# UI & Design System Specification: Helmet Cartel

Based directly on the approved e-commerce visual template (`E-commerce Website Template_page-0001.jpg`), adapted for **Helmet Cartel (Helmets & Riding Gear E-Commerce & Inventory Management)**.

---

## 1. Visual Identity & Brand Philosophy
- **Aesthetic:** Modern streetwear meets high-performance motorsports. Bold high-contrast typography, crisp minimalist off-white backgrounds, deep carbon black accents, and energetic amber/gold & red highlights.
- **Tone:** Premium, protective, athletic, modern, and trustworthy.

---

## 2. Color Palette & Token Definitions

| Token Name | Hex Code | Purpose / Usage |
|---|---|---|
| `--color-primary` | `#000000` | Primary buttons, headers, brand logos, active pills, top banner |
| `--color-primary-hover` | `#1F1F1F` | Hover states on primary dark buttons |
| `--color-surface` | `#FFFFFF` | Main background for cards, modals, and toasts |
| `--color-surface-subtle` | `#F2F0F1` | Product card image backgrounds, search bar fill, category cards |
| `--color-surface-muted` | `#F8F8F8` | Page hero background, bento container |
| `--color-border-subtle` | `#E5E5E5` | Card borders, dividers, table lines |
| `--color-text-main` | `#0A0A0A` | Primary headers, item titles, prices |
| `--color-text-secondary` | `#525252` | Balanced readable dark-gray body text |
| `--color-text-muted` | `#737373` | Secondary labels, descriptions, breadcrumbs, review dates |
| `--color-accent-red` | `#DC2626` | Discount tags (`-10%`), stock out warnings, delete/remove buttons |
| `--color-accent-amber` | `#F59E0B` | Review stars (5-star ratings), low-stock warning badges |
| `--color-accent-green` | `#10B981` | Verified customer checkmark, in-stock badge, completed orders |

---

## 3. Typography Hierarchy & Proportions

- **Display Headline Font:** `Integral CF`, `Cabinet Grotesk`, or `Impact, sans-serif` (Bold, uppercase, automotive styling)
- **Body & Interface Font:** `Satoshi`, `Inter`, or `system-ui, -apple-system, sans-serif`
- **Balanced Font Scale:**
  - `Hero Heading`: `clamp(2rem, 3.8vw, 3.25rem)` (Weight: 900, Line-height: 1.1)
  - `Section Heading (H2)`: `clamp(1.5rem, 2.5vw, 2.125rem)` (Weight: 800, Uppercase, Centered)
  - `Product Title`: `0.95rem` (Weight: 700)
  - `Price Text`: `1.15rem` (Weight: 700)
  - `Discount Tag`: `0.75rem` (Weight: 500, Pill shape)
  - `Body / Descriptions`: `0.9375rem` (15px, Line-height: 1.6, Color: `--color-text-secondary`)
  - `Toast Text`: `0.8125rem` (13px, Medium weight, Pure White background, minimal 8px edge curve)

---

## 4. Layout Architecture (From Template)

### 4.1. Top Promo Bar
- Height: `38px`
- Background: `#000000`
- Content: "Sign up and get 20% off your first helmet order. **Sign Up Now**"
- Dismissable close button on right.

### 4.2. Header Navigation
- Height: `72px`, Sticky with subtle border bottom.
- Left: **HELMET CARTEL** logo in bold heavy typeface.
- Center-Left: Navigation links:
  - `Shop` with dropdown (Full Face, Modular, Open Face, Off-Road)
  - `On Sale`
  - `New Arrivals`
  - `Brands`
- Center-Right: Search Input:
  - Full capsule pill (`border-radius: 9999px; background: #F0F0F0;`)
  - Magnifying glass icon + placeholder "Search for helmets, visors, gear..."
- Right: Action icons:
  - Shopping Cart icon with numerical badge counter.
  - User Account / Profile icon (links to Staff Login or Customer Profile).

### 4.3. Hero Section
- Dual-column desktop layout (flex / CSS grid):
  - **Left Column:**
    - Massive title: **"FIND HELMETS THAT MATCHES YOUR STYLE"**
    - Subtitle: "Browse through our diverse range of rigorously tested, DOT & ECE-certified helmets, designed to bring out your individuality and protect your ride."
    - Primary CTA Button: **"Shop Now"** (Black pill, `border-radius: 62px; padding: 16px 54px;`)
    - Statistics Strip:
      - `200+` International Brands
      - `2,000+` High-Quality Helmets & Gear
      - `30,000+` Satisfied Riders
  - **Right Column:**
    - High-resolution rider lifestyle visual showcasing rider with sport helmet.
    - Two 4-point decorative star vector accents in upper-right and mid-left.

### 4.4. Brand Ticker Strip
- Full-width black banner (`#000000`, height `122px`).
- Features high-contrast white logos of prestigious helmet manufacturers:
  - **AGV** | **SHOEI** | **ARAI** | **HJC** | **BELL** | **SHARK**

### 4.5. Section 1: "NEW ARRIVALS"
- Centered H2: **NEW ARRIVALS**
- 4-Column responsive grid:
  - Product Card:
    - Rounded image container (`background: #F0EEED; border-radius: 20px; aspect-ratio: 1/1;`)
    - Helmet Title (e.g., "Shoei RF-1400 Dedicated Helmet")
    - Star Rating component: ★★★★½ `4.5/5`
    - Price strip: `₱28,500` (Discounted) `₱32,000` (Original crossed out) `[-10%]` red badge
- Centered "View All" pill button (`border: 1px solid rgba(0,0,0,0.1); border-radius: 62px;`).

### 4.6. Section 2: "TOP SELLING"
- Centered H2: **TOP SELLING**
- 4-Column responsive grid mirroring the card structure of New Arrivals.
- Centered "View All" pill button.

### 4.7. Section 3: "BROWSE BY RIDING STYLE" (Bento Box)
- Light grey container background (`#F0F0F0; border-radius: 40px; padding: 70px 64px;`)
- Centered H2: **BROWSE BY RIDING STYLE**
- 2-row Bento Grid:
  - Row 1:
    - Card 1 (Span 1 / 35% width): **"Casual / Urban"** (Open Face & Retro Helmets)
    - Card 2 (Span 2 / 65% width): **"Sport / Track"** (Full Face Aerodynamic Racing)
  - Row 2:
    - Card 3 (Span 2 / 65% width): **"Touring / Adventure"** (Modular & Dual Sport)
    - Card 4 (Span 1 / 35% width): **"Motocross / Off-Road"** (Dirt & Enduro)

### 4.8. Section 4: "OUR HAPPY CUSTOMERS"
- Section Header with left-aligned H2 and right-aligned carousel navigation buttons (Left & Right arrows in circular outlines).
- Horizontal scroll/card grid:
  - 5 Golden Stars ★★★★★
  - Reviewer name with green verified checkmark: `Sarah M. ✓`
  - Review quote: *"The fitment and noise isolation on my Shoei helmet are unbelievable. Helmet Cartel delivered in 2 days and the stock availability was 100% accurate!"*

### 4.9. Section 5: Overlapping Newsletter Banner
- Overlaps the top boundary of the footer.
- Black pill/rounded box (`#000000; border-radius: 20px; padding: 36px 64px;`).
- Left: **STAY UP TO DATE ABOUT OUR LATEST DROPS & DEALS**
- Right: Email input with envelope icon + "Subscribe to Newsletter" white pill button.

### 4.10. Footer
- Background: `#F0F0F0`
- Brand bio & social icons (Twitter, Facebook, Instagram, GitHub).
- 4 Columns: `COMPANY`, `HELP`, `FAQ`, `RESOURCES`.
- Bottom row: Copyright notice + payment icons (Visa, Mastercard, PayPal, Apple Pay, Google Pay).

---

## 5. Staff & Admin Dashboard Views
- **Header:** Live SignalR connectivity indicator (Green dot: "SignalR Connected - Live Stock Sync Active").
- **Inventory Matrix Table:**
  - SKU, Product Name, Category, Size, Color, Available Stock, Reserved Stock, Reorder Point, Status Badge (In Stock, Low Stock, Out of Stock).
  - Quick inline stock restock trigger.
- **Order Kanban / Pipeline:**
  - Columns: `Pending Payment`, `Processing (Paid)`, `Ready for Pickup`, `Completed`.
  - Live sound / toast alert when a new order is received.
- **In-Store POS Quick Sale:**
  - Fast barcode/dropdown selector for walk-in customers to immediately decrement physical inventory and generate receipt.
