# Mark — Brand Guidelines

## App Overview
Mark is a native macOS screenshot annotation tool. Capture, annotate, crop, and export screenshots with a rich set of tools — arrows, shapes, text, blur, and more. The fastest way to mark up a screenshot on Mac.

---

## Icon Concept

**Visual:** A pen/marker tip drawing a small horizontal line — the act of marking up.
- A rounded square icon in brand orange/amber
- A stylized pen nib or marker tip touching a horizontal line (like writing the letter "m" or marking a document)
- The pen and line in white, the background in vibrant orange
- Sizes: 16, 32, 64, 128, 256, 512, 1024

**Alternative concept:** A simple rectangular frame (screenshot) with a small orange marker/pen overlapping the corner.

---

## Color Palette

| Role | Hex | Usage |
|------|-----|-------|
| Primary Orange | `#F97316` | Toolbar background, CTAs, brand accent |
| Deep Orange | `#EA580C` | Pressed states |
| Light Orange | `#FDBA74` | Hover states |
| Annotation Red | `#EF4444` | Arrows, shapes default color |
| Annotation Blue | `#3B82F6` | Text highlight, blue shapes |
| Annotation Green | `#22C55E` | Approved/success annotations |
| Annotation Yellow | `#EAB308` | Highlight marker |
| Annotation Purple | `#8B5CF6` | Freeform annotation |
| Background Light | `#FFFFFF` | Annotation canvas (light) |
| Background Dark | `#1C1C1E` | Annotation canvas (dark) |
| Surface Light | `#F3F4F6` | Toolbar background (light) |
| Surface Dark | `#2C2C2E` | Toolbar background (dark) |
| Text Primary | `#0F172A` (light) / `#F9FAFB` (dark) | Labels |
| Text Secondary | `#6B7280` (light) / `#9CA3AF` (dark) | Captions |
| Blur Overlay | `#000000` at 60% | Blur tool background |

---

## Typography

- **Toolbar Labels:** SF Pro Text, Medium — 11px
- **Tool Names:** SF Pro Text, Regular — 12px
- **Annotation Text Tool:** SF Pro Text, Customizable size — 14–72px
- **Export Filename:** SF Pro Text, Regular — 13px
- **Keyboard Shortcut Labels:** SF Mono, Regular — 10px

**Font Stack:**
```
font-family: -apple-system, BlinkMacSystemFont, "SF Pro Text", "SF Mono", sans-serif;
```

---

## Visual Motif

**Theme:** "Sharp & Focused" — the tool is fast, decisive, and tactile. Every annotation action should feel immediate and snappy. The orange brand color is the thread connecting all interactions.

- **Toolbar:** Horizontal strip at the top. Orange background (light shade for light mode, dark shade for dark mode). Tool icons in white.
- **Tool icons:** SF Symbols, monochrome, with a subtle orange glow on the active tool
- **Canvas:** Clean white or dark canvas (matches system). Screenshot displayed full-bleed.
- **Selection handles:** Small orange squares at corners and edges of selected annotation
- **Cursor:** Changes per tool — crosshair for crop, pencil for draw, arrow for arrow tool
- **Annotation tools:** Arrow, Rectangle, Ellipse, Line, Freehand draw, Text, Highlight (yellow marker), Blur/Pixelate, Number stamp
- **Undo/Redo:** Floating pill in top-left (circular buttons, undo left, redo right)
- **Empty state:** A dashed rectangle with "Drop a screenshot here or press ⌘⇧4" — but Mark is usually launched with a screenshot already loaded

**Spatial rhythm:** 8pt grid. Toolbar 48px height. Tool buttons 36×36px. Icon size 20×20. Canvas fills remaining space.

---

## macOS-Specific Behavior

- **Window:** `NSWindow` with toolbar. Minimum 600×400. Resizable. Full-screen supported.
- **Menu Bar:** Persistent menu bar icon (orange "M") with quick capture shortcut
- **Multi-display:** Display picker before capture — shows all connected displays as thumbnails
- **Hotkey capture:** `⌘⇧M` (configurable) to trigger screen capture mode
- **Export formats:** PNG, JPEG, TIFF, PDF, GIF (animated for multi-frame)
- **Dark Mode:** Full support
- **Keyboard shortcuts:** `⌘⇧4` capture, `⌘S` save, `⌘⇧E` export, `⌘Z` undo, `⌘⇧Z` redo, `⌘C` copy

---

## Sizes & Behavior

| Element | Default | Floating (Mini) |
|---------|---------|-----------------|
| Toolbar height | 48px | 36px |
| Tool button | 36×36px | 28×28px |
| Icon size | 20×20 | 16×16 |
| Canvas padding | 0px (full bleed) | 0px |
| Window min | 600×400 | 300×200 |

Supports floating/picture-in-picture mode — a smaller, always-on-top annotation window.
