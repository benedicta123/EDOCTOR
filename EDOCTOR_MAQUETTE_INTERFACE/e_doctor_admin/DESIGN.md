---
name: E-DOCTOR Admin
colors:
  surface: '#fcfaff'
  surface-dim: '#cbdbf5'
  surface-bright: '#f8f9ff'
  surface-container-lowest: '#ffffff'
  surface-container-low: '#eff4ff'
  surface-container: '#e5eeff'
  surface-container-high: '#dce9ff'
  surface-container-highest: '#d3e4fe'
  on-surface: '#0b1c30'
  on-surface-variant: '#4a4455'
  inverse-surface: '#213145'
  inverse-on-surface: '#eaf1ff'
  outline: '#7b7487'
  outline-variant: '#ccc3d8'
  surface-tint: '#732ee4'
  primary: '#630ed4'
  on-primary: '#ffffff'
  primary-container: '#7c3aed'
  on-primary-container: '#ede0ff'
  inverse-primary: '#d2bbff'
  secondary: '#5b598c'
  on-secondary: '#ffffff'
  secondary-container: '#c7c3fe'
  on-secondary-container: '#514f81'
  tertiary: '#7d3d00'
  on-tertiary: '#ffffff'
  tertiary-container: '#a15100'
  on-tertiary-container: '#ffe0cd'
  error: '#ba1a1a'
  on-error: '#ffffff'
  error-container: '#ffdad6'
  on-error-container: '#93000a'
  primary-fixed: '#eaddff'
  primary-fixed-dim: '#d2bbff'
  on-primary-fixed: '#25005a'
  on-primary-fixed-variant: '#5a00c6'
  secondary-fixed: '#e3dfff'
  secondary-fixed-dim: '#c4c1fb'
  on-secondary-fixed: '#181445'
  on-secondary-fixed-variant: '#444173'
  tertiary-fixed: '#ffdcc6'
  tertiary-fixed-dim: '#ffb784'
  on-tertiary-fixed: '#301400'
  on-tertiary-fixed-variant: '#713700'
  background: '#f8f9ff'
  on-background: '#0b1c30'
  surface-variant: '#d3e4fe'
  border-subtle: '#e2e8f0'
  success-green: '#22c55e'
  waiting-orange: '#f97316'
  urgent-red: '#ef4444'
typography:
  display-lg:
    fontFamily: Epilogue
    fontSize: 40px
    fontWeight: '700'
    lineHeight: '1.2'
  headline-lg:
    fontFamily: Epilogue
    fontSize: 32px
    fontWeight: '600'
    lineHeight: '1.25'
  headline-md:
    fontFamily: Epilogue
    fontSize: 24px
    fontWeight: '600'
    lineHeight: '1.3'
  headline-sm:
    fontFamily: Epilogue
    fontSize: 20px
    fontWeight: '600'
    lineHeight: '1.4'
  body-lg:
    fontFamily: Plus Jakarta Sans
    fontSize: 18px
    fontWeight: '400'
    lineHeight: '1.6'
  body-md:
    fontFamily: Plus Jakarta Sans
    fontSize: 16px
    fontWeight: '400'
    lineHeight: '1.5'
  body-sm:
    fontFamily: Plus Jakarta Sans
    fontSize: 14px
    fontWeight: '400'
    lineHeight: '1.5'
  label-lg:
    fontFamily: Plus Jakarta Sans
    fontSize: 14px
    fontWeight: '600'
    lineHeight: '1.2'
    letterSpacing: 0.02em
  label-sm:
    fontFamily: Plus Jakarta Sans
    fontSize: 12px
    fontWeight: '600'
    lineHeight: '1.2'
    letterSpacing: 0.05em
rounded:
  sm: 0.25rem
  DEFAULT: 0.5rem
  md: 0.75rem
  lg: 1rem
  xl: 1.5rem
  full: 9999px
spacing:
  unit: 4px
  container-padding-mobile: 16px
  container-padding-desktop: 32px
  gutter: 24px
  card-gap: 20px
---

## Brand & Style

The design system for the E-DOCTOR Hospital Administration dashboard is defined by an **Elevated Premium** aesthetic. It takes the clinical foundations of Togo Health Direct and transforms them into a high-end, sophisticated management interface. The visual narrative moves away from general patient care toward an authoritative, curated environment for medical executives and administrators.

The style leverages **Minimalism** with a **Corporate Modern** edge. It uses sophisticated geometric pairings to create a UI that feels both expertly curated and technologically advanced. The interface communicates efficiency, precision, and high-level oversight through generous whitespace, razor-thin borders, and a disciplined "Paper & Pane" layering strategy. The emotional response is one of calm control and professional mastery over complex data.

## Colors

The palette is anchored by a professional **Purple (#7c3aed)**, which serves as the primary accent for actions, navigation highlights, and brand reinforcement. This hue is chosen to signify innovation and wisdom within the healthcare sector.

- **Primary:** Purple (#7c3aed) for high-intent actions and active states.
- **Secondary:** Deep Indigo (#1e1b4b) for text hierarchies and heavy functional elements, providing a grounded, professional contrast.
- **Status Badges:** Strictly semantic and high-clarity. **Green** signifies "Succès/Terminé", **Orange** signifies "En attente", and **Red** indicates "Urgent/Alerte".
- **Backgrounds:** A crisp, light surface (`#fcfaff`) ensures a clean, clinical feel that minimizes eye strain during long administration shifts.
- **Borders:** Thin, low-contrast lines (`#e2e8f0`) are used to define structure without adding visual noise.

## Typography

This design system utilizes a sophisticated typographic pairing to balance character with utility. 

**Epilogue** is the headline face, providing a distinctive, geometric, and editorial feel that gives the dashboard its modern "tech-forward" identity. It is reserved for titles, section headers, and key data points.

**Plus Jakarta Sans** is the primary workhorse for body text, labels, and data grids. It offers a soft, welcoming, and highly approachable feel that reduces the "coldness" of a medical administrative tool. 

**Internationalization (French):**
- Layouts account for longer French word strings (e.g., "Tableau de bord" vs "Dashboard") by using flexible containers.
- Line heights are slightly increased to manage diacritics (accents) without overlapping.

## Layout & Spacing

The layout philosophy follows a **Fixed Grid** model for desktop to ensure data-heavy tables and dashboards remain legible and consistent, while transitioning to a **Fluid Grid** for mobile.

- **Desktop (12-column):** Central content area maxes at 1440px with a persistent 280px left sidebar for primary navigation.
- **Gaps:** A 24px gutter is maintained between dashboard widgets to prevent visual crowding.
- **Rhythm:** An 8px (2x unit) spatial scale governs all internal component padding, ensuring that elements like patient rows or staff lists have enough "breathing room" to be scanned quickly.
- **French Context:** Horizontal spacing in buttons and labels is increased by 15% to accommodate the character expansion typical in French translations.

## Elevation & Depth

Elevation is achieved through **Low-Contrast Outlines** and **Tonal Layers** rather than heavy shadows. This maintains a "flat-plus" aesthetic that feels professional and sober.

- **Surface Tiering:** The main dashboard background is slightly off-white, while primary widgets and cards are pure white.
- **Borders:** All containers use a 1px solid border (`#e2e8f0`). This provides structural definition that is more precise than a shadow.
- **Interactive States:** On hover, cards may receive an extremely subtle, diffused purple-tinted shadow (4% opacity) to indicate "lift" and interactivity.
- **Modals:** Use a semi-transparent backdrop blur (8px) to maintain the user's spatial awareness of the dashboard behind the action layer.

## Shapes

The design system utilizes the **Rounded (2)** shape language to soften the clinical nature of the dashboard. This specific level of roundedness (14px as requested) strikes the perfect balance between professional structure and modern friendliness.

- **Main Containers/Cards:** Use 14px (`rounded-lg` equivalent in this system) to frame dashboard widgets.
- **Inner Elements:** Smaller elements like input fields or buttons use a slightly smaller 8px radius to maintain nested visual harmony.
- **Icons:** Must be **Outline only**. Use a 1.5px stroke with rounded terminals to mirror the soft curves of the typography and containers.

## Components

### Buttons
Primary buttons are solid Purple (`#7c3aed`) with white text. Secondary buttons use a Purple outline with a subtle ghost-white background on hover. Tertiary buttons are text-only. All use the 14px roundedness.

### Input Fields
Fields feature a thin 1px border. Upon focus, the border thickens slightly to 1.5px and changes to the primary Purple. Labels are positioned above the field in `label-lg` Plus Jakarta Sans.

### Status Badges (États)
Essential for the hospital environment. They use a low-opacity background of the semantic color with high-saturation text of the same hue.
- **Succès:** Green background (10% opacity), Dark Green text.
- **En attente:** Orange background (10% opacity), Dark Orange text.
- **Urgent:** Red background (10% opacity), Dark Red text.

### Cards & Widgets
The primary container for data. Cards are white with a 1px light gray border and 14px corners. Header sections within cards use a subtle bottom border to separate titles from content.

### Tables (Data Grids)
The core of the administration experience. Rows use a 56px minimum height with thin horizontal dividers. The header row uses a very light Purple tint to distinguish it from the data entries.

### Icons
Use a consistent set of thin-line icons. Never use filled icons unless they represent a "selected" or "active" state in a toggle.