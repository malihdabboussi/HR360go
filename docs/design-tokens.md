# HR360 Go — Design tokens

Aligned with the HRMS web **Client** (`tailwind.config.js`, `globals.css`, `Navbar.tsx`).

## Brand colors

| Token | Hex | Usage |
|-------|-----|--------|
| `primary` | `#01C3FF` | Check-in, links, scrollbar, nav selected |
| `secondary` | `#FF7132` | Check-out, accents |
| `darkBlue` | `#0077FF` | Logo accent, emphasis |
| `navy` | `#00004F` | Logo wordmark |

## Semantic

| Token | Hex | Usage |
|-------|-----|--------|
| `danger` | `#FF3D33` | Errors, destructive |
| `gold` | `#FFCC17` | Warnings, highlights |

## Light theme

| Token | Hex | Usage |
|-------|-----|--------|
| `background` | `#F4F4F4` | Scaffold background |
| `surface` | `#FFFFFF` | Cards, sheets |
| `label` | `#1E293B` | Primary text |
| `light` | `#9A9A9A` | Secondary / hint text |
| `border` | `#EAEAEA` | Dividers, outlines |

## Dark theme

| Token | Hex | Usage |
|-------|-----|--------|
| `background` | `#0D1621` | Scaffold background |
| `surface` | `#162633` | Cards, sheets (`dark.alternative` on web) |
| `border` | `#263B4D` | Dividers, outlines |

## Typography

- **UI font:** Inter (web `--font-inter`, `GoogleFonts.inter`)
- **Timer / elapsed:** Monospace with tabular figures (`FontFeature.tabularFigures()`)

## Spacing & shape

| Token | Value |
|-------|-------|
| `space-xs` | 4 |
| `space-sm` | 8 |
| `space-md` | 16 |
| `space-lg` | 24 |
| `radius-card` | 12 |
| `radius-button` | 8 |

## Components

- **Check-in button:** `primary` (`#01C3FF`), radius 8
- **Check-out button:** `secondary` (`#FF7132`), radius 8
- **Bottom navigation:** selected icon/label = `primary`
- **Cards:** `surface` fill, `radius-card`, light border `#EAEAEA` / dark `#263B4D`

## RTL (Arabic)

Web sets `dir="rtl"` for Arabic (`Navbar.tsx`). Flutter should use `Directionality` / locale from `AppLocalizations` when Arabic is active: mirror row layouts, align text start/end accordingly, and keep icons that imply direction (chevrons) mirrored where appropriate.

## Figma handoff

**Frame:** Mobile `375 × 812` (iPhone-style), light + dark variants.

**Color styles** (name exactly like tokens):

- `primary` `#01C3FF`
- `secondary` `#FF7132`
- `darkBlue` `#0077FF`
- `navy` `#00004F`
- `danger` `#FF3D33`
- `gold` `#FFCC17`
- `background/light` `#F4F4F4`
- `surface/light` `#FFFFFF`
- `label` `#1E293B`
- `light` `#9A9A9A`
- `border/light` `#EAEAEA`
- `background/dark` `#0D1621`
- `surface/dark` `#162633`
- `border/dark` `#263B4D`

**Key screens:** Login, Check-in (timer + primary/secondary CTA), My time, Workspace, bottom nav.

**Assets:** `new-logo.svg` centered on login; timer uses Inter Display or mono tabular style.
