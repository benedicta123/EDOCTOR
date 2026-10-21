---
name: Togo Health Direct
colors:
  surface: '#f8f9ff'
  surface-dim: '#cbdbf5'
  surface-bright: '#f8f9ff'
  surface-container-lowest: '#ffffff'
  surface-container-low: '#eff4ff'
  surface-container: '#e5eeff'
  surface-container-high: '#dce9ff'
  surface-container-highest: '#d3e4fe'
  on-surface: '#0b1c30'
  on-surface-variant: '#3c4947'
  inverse-surface: '#213145'
  inverse-on-surface: '#eaf1ff'
  outline: '#6c7a77'
  outline-variant: '#bbcac6'
  surface-tint: '#006b5f'
  primary: '#006b5f'
  on-primary: '#ffffff'
  primary-container: '#14b8a6'
  on-primary-container: '#00423b'
  inverse-primary: '#4fdbc8'
  secondary: '#006a63'
  on-secondary: '#ffffff'
  secondary-container: '#99efe5'
  on-secondary-container: '#006f67'
  tertiary: '#9b4426'
  on-tertiary: '#ffffff'
  tertiary-container: '#f38764'
  on-tertiary-container: '#6c2106'
  error: '#ba1a1a'
  on-error: '#ffffff'
  error-container: '#ffdad6'
  on-error-container: '#93000a'
  primary-fixed: '#71f8e4'
  primary-fixed-dim: '#4fdbc8'
  on-primary-fixed: '#00201c'
  on-primary-fixed-variant: '#005048'
  secondary-fixed: '#9cf2e8'
  secondary-fixed-dim: '#80d5cb'
  on-secondary-fixed: '#00201d'
  on-secondary-fixed-variant: '#00504a'
  tertiary-fixed: '#ffdbd0'
  tertiary-fixed-dim: '#ffb59e'
  on-tertiary-fixed: '#3a0b00'
  on-tertiary-fixed-variant: '#7c2d11'
  background: '#f8f9ff'
  on-background: '#0b1c30'
  surface-variant: '#d3e4fe'
typography:
  display-lg:
    fontFamily: Epilogue
    fontSize: 40px
    fontWeight: '700'
    lineHeight: 48px
    letterSpacing: -0.02em
  headline-lg:
    fontFamily: Epilogue
    fontSize: 32px
    fontWeight: '600'
    lineHeight: 40px
    letterSpacing: -0.01em
  headline-md:
    fontFamily: Epilogue
    fontSize: 24px
    fontWeight: '600'
    lineHeight: 32px
  headline-sm:
    fontFamily: Epilogue
    fontSize: 20px
    fontWeight: '600'
    lineHeight: 28px
  body-lg:
    fontFamily: Atkinson Hyperlegible Next
    fontSize: 18px
    fontWeight: '400'
    lineHeight: 28px
  body-md:
    fontFamily: Atkinson Hyperlegible Next
    fontSize: 16px
    fontWeight: '400'
    lineHeight: 24px
  body-sm:
    fontFamily: Atkinson Hyperlegible Next
    fontSize: 14px
    fontWeight: '400'
    lineHeight: 20px
  label-md:
    fontFamily: Atkinson Hyperlegible Next
    fontSize: 14px
    fontWeight: '600'
    lineHeight: 16px
    letterSpacing: 0.02em
  caption:
    fontFamily: Atkinson Hyperlegible Next
    fontSize: 12px
    fontWeight: '500'
    lineHeight: 16px
rounded:
  sm: 0.5rem
  DEFAULT: 1rem
  md: 1.5rem
  lg: 2rem
  xl: 3rem
  full: 9999px
spacing:
  base: 4px
  xs: 4px
  sm: 8px
  md: 16px
  lg: 24px
  xl: 32px
  gutter: 16px
  margin-mobile: 16px
  margin-desktop: 64px
---

## Brand & Style

The design system is engineered for the West African healthcare landscape, specifically tailored for Togo. It balances the authoritative nature of medical services with a warm, community-driven spirit. By utilizing the "Experimental" visual identity, we pair the distinctive, geometric character of **Epilogue** for headlines with the industry-leading legibility of **Atkinson Hyperlegible Next** for functional content.

The style is a refined **Modern Corporate** aesthetic with a soft, human touch. It avoids loud gradients and aggressive depth in favor of a "Paper & Pane" approach—clean white surfaces, subtle tonal shifts, and purposeful use of teal to guide the eye. The UI feels established and professional, ensuring users in moments of medical need feel supported and certain.

## Colors

The palette is anchored by a primary **Teal (#14B8A6)**, chosen for its psychological association with hygiene, vitality, and clinical precision. We use a light-mode default to ensure maximum readability under various lighting conditions common in mobile-first environments.

- **Primary:** Used for main actions, active states, and brand presence.
- **Secondary:** A deeper teal for high-contrast text or hover states to ensure accessibility.
- **Status Badges:** Strictly mapped to semantic colors. **Green** for available doctors or successful bookings, **Orange** for low stock in pharmacies or pending status, and **Red** for urgent alerts or errors.
- **Neutral:** A range of slate blues and grays that provide a sober foundation, avoiding the harshness of pure black.

## Typography

Typography is the cornerstone of this design system’s accessibility. **Epilogue** provides a modern, geometric flair for titles, creating a memorable brand voice. **Atkinson Hyperlegible Next** is used for all body copy and UI labels; its letterforms are specifically designed to be indistinguishable from one another, which is critical for medical information where clarity is life-essential.

For mobile-first optimization:
- Headlines above 32px scale down to 28px on mobile devices.
- Body text never drops below 14px to ensure readability for all age groups.
- Line heights are generous (1.5x for body) to facilitate easier scanning of medical reports and instructions.

## Layout & Spacing

This design system employs a **Fluid Grid** model with a mobile-first philosophy. We use an 8px spatial scale to ensure consistency across all components.

- **Mobile:** 4-column grid with 16px side margins.
- **Tablet/Desktop:** 12-column grid with a maximum content width of 1200px.
- **Vertical Rhythm:** Components are separated by 16px (md) or 24px (lg) to maintain a clean, uncluttered appearance that reduces cognitive load for patients.
- **Safe Areas:** Navigation elements are padded to account for modern mobile gestures and "notch" areas.

## Elevation & Depth

To maintain a professional and "sober" feel, elevation is used sparingly. This design system avoids heavy shadows, instead utilizing **Tonal Layers** and **Low-Contrast Outlines**.

1.  **Level 0 (Base):** The main background (`#F8FAFC`).
2.  **Level 1 (Cards):** White surfaces with a 1px border in a light neutral (`#E2E8F0`).
3.  **Level 2 (Interactive):** When a user interacts with a card, a very soft, diffused teal-tinted shadow is applied to indicate lift without feeling "heavy."
4.  **Level 3 (Modals/Overlays):** Used for urgent health alerts or confirmation sheets. These use a 15% opacity backdrop blur to keep the user grounded in their current context.

## Shapes

The design system uses **Pill-shaped (3)** roundedness to project friendliness and safety. In a healthcare context, sharp corners can feel aggressive; rounded forms are perceived as more organic and approachable.

- **Buttons & Chips:** Use a full pill-shape (32px+ radius).
- **Cards & Inputs:** Use `rounded-lg` (2rem) for a modern, soft container feel.
- **Icons:** Use a consistent 2px stroke weight with rounded caps and joins to match the typography's friendly nature.

## Components

### Buttons
Primary buttons are solid Teal with white text. Secondary buttons use a thin 1.5px Teal outline with Teal text. All buttons use the pill-shape for a friendly, modern touch.

### Input Fields
Inputs feature a subtle light-gray border that turns Primary Teal on focus. Labels use the `label-md` typography style, positioned clearly above the field for accessibility. Error states use a 1px Red border with a supporting error message below.

### Status Badges
Used for doctor availability or prescription status. They are small, pill-shaped containers with a low-opacity background of the semantic color (e.g., light green) and high-contrast text (e.g., dark green).

### Cards
Medical record cards or doctor profiles use a white background with a thin gray border. Information is hierarchically structured with Epilogue for the name and Atkinson Hyperlegible Next for the specialty and details.

### Icons
Thin-outline icons are mandatory. They must be simple, geometric, and avoid filled states unless used as a toggle (e.g., a saved "heart" icon).

### Lists
Lists use 16px of vertical padding between items, with a thin horizontal divider (`#F1F5F9`) to maintain clinical organization without cluttering the interface.