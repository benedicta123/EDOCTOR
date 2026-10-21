---
name: E-DOCTOR Pharmacy
colors:
  surface: '#fff8f6'
  surface-dim: '#edd5cb'
  surface-bright: '#fff8f6'
  surface-container-lowest: '#ffffff'
  surface-container-low: '#fff1eb'
  surface-container: '#ffeae0'
  surface-container-high: '#fce3d9'
  surface-container-highest: '#f6ded3'
  on-surface: '#251913'
  on-surface-variant: '#584237'
  inverse-surface: '#3c2d26'
  inverse-on-surface: '#ffede6'
  outline: '#8c7164'
  outline-variant: '#e0c0b1'
  surface-tint: '#9d4300'
  primary: '#9d4300'
  on-primary: '#ffffff'
  primary-container: '#f97316'
  on-primary-container: '#582200'
  inverse-primary: '#ffb690'
  secondary: '#565e74'
  on-secondary: '#ffffff'
  secondary-container: '#dae2fd'
  on-secondary-container: '#5c647a'
  tertiary: '#006398'
  on-tertiary: '#ffffff'
  tertiary-container: '#00a2f4'
  on-tertiary-container: '#003554'
  error: '#ba1a1a'
  on-error: '#ffffff'
  error-container: '#ffdad6'
  on-error-container: '#93000a'
  primary-fixed: '#ffdbca'
  primary-fixed-dim: '#ffb690'
  on-primary-fixed: '#341100'
  on-primary-fixed-variant: '#783200'
  secondary-fixed: '#dae2fd'
  secondary-fixed-dim: '#bec6e0'
  on-secondary-fixed: '#131b2e'
  on-secondary-fixed-variant: '#3f465c'
  tertiary-fixed: '#cde5ff'
  tertiary-fixed-dim: '#93ccff'
  on-tertiary-fixed: '#001d32'
  on-tertiary-fixed-variant: '#004b74'
  background: '#fff8f6'
  on-background: '#251913'
  surface-variant: '#f6ded3'
  success-green: '#22c55e'
  warning-orange: '#f97316'
  error-red: '#ef4444'
  border-subtle: '#e2e8f0'
  bg-surface: '#f8f9ff'
typography:
  display-lg:
    fontFamily: Plus Jakarta Sans
    fontSize: 40px
    fontWeight: '700'
    lineHeight: 48px
    letterSpacing: -0.02em
  headline-lg:
    fontFamily: Plus Jakarta Sans
    fontSize: 32px
    fontWeight: '600'
    lineHeight: 40px
    letterSpacing: -0.01em
  headline-lg-mobile:
    fontFamily: Plus Jakarta Sans
    fontSize: 28px
    fontWeight: '600'
    lineHeight: 36px
  headline-md:
    fontFamily: Plus Jakarta Sans
    fontSize: 24px
    fontWeight: '600'
    lineHeight: 32px
  headline-sm:
    fontFamily: Plus Jakarta Sans
    fontSize: 20px
    fontWeight: '600'
    lineHeight: 28px
  body-lg:
    fontFamily: Inter
    fontSize: 18px
    fontWeight: '400'
    lineHeight: 28px
  body-md:
    fontFamily: Inter
    fontSize: 16px
    fontWeight: '400'
    lineHeight: 24px
  body-sm:
    fontFamily: Inter
    fontSize: 14px
    fontWeight: '400'
    lineHeight: 20px
  label-md:
    fontFamily: Inter
    fontSize: 14px
    fontWeight: '600'
    lineHeight: 16px
    letterSpacing: 0.01em
  caption:
    fontFamily: Inter
    fontSize: 12px
    fontWeight: '500'
    lineHeight: 16px
rounded:
  sm: 0.25rem
  DEFAULT: 0.5rem
  md: 0.75rem
  lg: 1rem
  xl: 1.5rem
  full: 9999px
spacing:
  unit: 4px
  xs: 4px
  sm: 8px
  md: 16px
  lg: 24px
  xl: 32px
  gutter: 16px
  margin-mobile: 16px
  margin-desktop: 32px
---

## Brand & Style

The design system for the E-DOCTOR pharmacy dashboard is built on a foundation of **Modern Corporate** efficiency blended with a warm, accessible **Minimalism**. It is designed to empower pharmacists with a high-clarity interface that minimizes cognitive load during critical inventory management and prescription fulfillment.

The aesthetic prioritizes precision through a "Clean Clinical" approach—utilizing generous whitespace, thin architectural borders, and a vibrant coral accent that signifies energy and responsiveness. By moving away from traditional medical blues and greens, the design system establishes a distinctive presence that feels both professional and modern. The UI evokes a sense of trust and technological sophistication, ensuring that even complex pharmaceutical data remains legible and actionable.

## Colors

This design system uses a light-centric palette to maintain a clean and airy pharmacy environment. The primary color is a **Coral Orange (#f97316)**, which serves as the main brand signal and call-to-action color.

- **Primary:** Coral Orange is used for active states, primary buttons, and critical brand highlights.
- **Secondary:** A deep Slate Blue (#0f172a) provides grounding for text and structural elements.
- **Neutral:** The background uses a soft, cool-tinted off-white (#f8f9ff) to reduce glare while maintaining a clinical feel.
- **Semantic Statuses:** 
    - **Success (Vert):** Used for "En stock" or "Validé" states.
    - **Warning (Orange/Coral):** Used for "Stock faible" (low stock) and "En attente."
    - **Error (Rouge):** Reserved for "Rupture de stock" (out of stock) and urgent system alerts.

## Typography

The typography strategy balances friendly approachability with utilitarian precision. **Plus Jakarta Sans** is the headline face; its soft, geometric curves make the dashboard feel welcoming and modern. For all functional data—dosage instructions, inventory numbers, and patient details—**Inter** is used for its exceptional clarity and neutral tone.

Hierarchical rules:
- Headlines utilize tight letter-spacing to maintain a "contained" and professional look.
- Large numerical data (e.g., stock counts) should use `headline-md` for immediate visibility.
- All French-language UI labels (e.g., "Quantité," "Date d'expiration") use the semi-bold `label-md` for quick scanning.

## Layout & Spacing

The layout follows a **Fixed Grid** model on desktop and a **Fluid Grid** model on mobile, ensuring the pharmacy dashboard remains organized and structured across all hardware.

- **Grid:** A 12-column grid is used for the desktop dashboard to allow for side-by-side data visualization (e.g., inventory list next to a prescription preview).
- **Rhythm:** An 8px spatial system (based on a 4px base unit) ensures consistent vertical and horizontal alignment.
- **Margins:** Desktop views use 32px outer margins to provide "breathing room," while mobile views collapse to 16px to maximize content area.
- **Reflow:** On tablet and mobile, the dashboard sidebar transitions into a bottom navigation bar or a hamburger menu to preserve screen real estate for data tables.

## Elevation & Depth

To maintain the requested "sober" and thin-border aesthetic, this design system relies on **Low-Contrast Outlines** rather than heavy shadows.

- **Surface Layers:** The background is the lowest layer. Cards and containers sit on top with a pure white surface.
- **Borders:** Every container (cards, inputs, tables) is defined by a thin 1px border (`#e2e8f0`). This creates a structural, "tabbed" feel common in professional software.
- **Subtle Depth:** A very soft, low-opacity shadow (4% opacity) is only applied to active modals or floating action buttons to provide a hint of "lift" without breaking the flat, minimalist aesthetic.
- **Active States:** Instead of elevation, active items are indicated by a 2px left-border accent in the primary coral color.

## Shapes

The shape language is defined by a consistent **Rounded (2)** corner radius, specifically set to 14px for main containers as per requirements.

- **Main Containers:** Cards, modals, and the main dashboard content area use a 14px (approx. 0.875rem to 1rem) radius.
- **Small Elements:** Buttons, chips, and input fields use a consistent 8px (0.5rem) radius to feel cohesive with the larger containers.
- **Iconography:** All icons must be **thin-outline** (1.5px to 2px stroke) with slightly rounded terminals to match the font's character.

## Components

### Buttons
- **Primary:** Solid Coral (#f97316) with white text. Rounded edges (8px).
- **Secondary:** Thin 1px border in Coral with Coral text. Used for "Modifier" or "Imprimer."
- **Ghost:** No background or border; used for secondary actions like "Annuler."

### Input Fields
- Thin 1px borders in Slate 200. On focus, the border transitions to Coral.
- Labels are always visible, placed 8px above the input in `label-md` weight.

### Status Badges (Pills)
- Small, rounded pills with low-opacity backgrounds.
- **Success:** Light green background with dark green text ("En stock").
- **Warning:** Light coral background with dark coral text ("Stock faible").
- **Rupture:** Light red background with dark red text ("Rupture").

### Data Tables
- Use thin horizontal dividers only (no vertical lines).
- Row height is generous (56px) to ensure touch-friendliness and readability.
- The "Header" row uses a light gray background to distinguish it from data.

### Cards
- White background, 14px rounded corners, and a 1px Slate 200 border. 
- No shadows are used for standard dashboard cards to keep the interface "flat" and fast.

### Icons
- Outline-only style. Stroke weight must be 1.5px. Icons are never filled unless they represent an active selection toggle.