# FS25_SlurryPipeSystem

**Realistic physical slurry pipe system for Farming Simulator 2025.**

Replaces vanilla "drive into a trigger and fill" mechanics with a tactile system where you physically connect tanker fill arms or pipe chains, run a PTO-driven pump, control flow direction, and watch slurry move through real plumbing.

---

## What it does

- **Fill arms** swung out of the tanker by joystick into open slurry pits or rubber boot ports on buildings and other vehicles.
- **Pipe chains** — multi-segment pipes laid by walking from one coupler toward another, locked into place when both ends overlap with valid couplings.
- **Direct bez pipes** — a single connecting pipe between two nearby couplers, useful for quick pump transfers between a tanker and a building.
- **Conduit pump (PTO Slurry Pump)** — a passive pump trailer that lets two pipe chains transfer through it.
- **Animated couplers and valves** — clamp handles close on connect, valve wheels rotate on open. Per-vehicle animations so each modder can ship their own.
- **Coloured pipes** — pick from a palette per pipe segment, stored per save.
- **Multi-fill-type support** — works with both `LIQUIDMANURE` and `DIGESTATE`. Pipe transfers automatically pick whichever fill type is actually present.

---

## How to add support to your own content

Two paths, depending on whether you own the vehicle or placeable XML:

### Bundled (SPS itself supports the content)

You add files inside the SPS mod folder and a manifest entry. Used for the stock fleet shipped with SPS, and for adding support to mods without modifying the modder's files.

See **HowToVehicle.md** and **HowToPlaceable.md** for step-by-step walkthroughs.

### Embedded (you ship SPS-ready content as a third-party modder)

You add a single `<slurryPipeSystem>` block to your vehicle or placeable XML. No SPS-side files needed. No manifest entry needed. Players with SPS installed get integration automatically; players without SPS see your mod work normally.

This is the **preferred path** for new modded content. Self-contained, no conflicts with other mods of the same vehicle.

See **HowToVehicle.md** and **HowToPlaceable.md**.

---

## File layout

```
FS25_SlurryPipeSystem/
├── modDesc.xml
├── README.md                              ← this file
├── HowToVehicle.md                        ← vehicle setup walkthrough
├── HowToPlaceable.md                      ← placeable setup walkthrough
│
├── configs/
│   ├── spsConfigManifest.xml              ← list of bundled-supported vehicles/placeables
│   ├── couplerAnimations.xml              ← bundled coupler animation library
│   ├── spsColors.xml                      ← pipe colour palette
│   │
│   ├── data/                              ← stock fleet bundled configs
│   │   ├── vehicles/<vendor>/<model>/
│   │   │   ├── fillPoints.xml
│   │   │   └── nodeTree.i3d
│   │   └── placeables/<vendor>/<model>/
│   │       ├── fillPoints.xml
│   │       └── nodeTree.i3d
│   │
│   └── mods/                              ← third-party fleet bundled configs
│       └── <FS25_ModFolderName>/...
│
├── i3d/                                   ← SPS visual assets
│   ├── pipes/slurryPipe.i3d              ← pipe mesh and rig
│   ├── nodes/spsPivot.i3d                 ← chain pivot helper
│   └── dockingStation/dockingStation.i3d  ← docking station building
│
├── scripts/                               ← Lua source
│   ├── SlurryPipeManager.lua              ← singleton manager
│   ├── SPSPipeChain.lua                   ← chain segment + lifecycle
│   ├── SPSPipeVisual.lua                  ← bezier pipe mesh driver
│   ├── SPSPipeActivatable.lua             ← in-cab/at-coupler input
│   ├── SPSChainActivatable.lua            ← chain end input
│   ├── SPSPumpControlActivatable.lua      ← walkaround pump controls
│   ├── SPSCouplerAnimator.lua             ← per-coupling animator
│   ├── SPSEvents.lua                      ← network events
│   └── ...
│
├── VehicleConfigSetup_ReadMe.xml          ← full vehicle schema reference
└── PlaceableConfigSetup_ReadMe.xml        ← full placeable schema reference
```

---

## Documentation map

If you want to... | Read this
---|---
Add SPS to a tanker or pump | **HowToVehicle.md**
Add SPS to a building or storage tank | **HowToPlaceable.md**
Look up an attribute on `<pipeCoupling>` etc. | **VehicleConfigSetup_ReadMe.xml** or **PlaceableConfigSetup_ReadMe.xml**
Understand the manifest schema | **VehicleConfigSetup_ReadMe.xml** (top section)
Ship a SPS-ready mod | HowToVehicle/HowToPlaceable, "Path B — Embedded"

---

## Key concepts

### Path-based manifest matching

Each manifest entry has a `path` attribute that must match the **tail** of the runtime configFileName Giants reports for the vehicle or placeable. Stock content uses `data/vehicles/...`. Mods use `mods/<FS25_ModFolderName>/...`. Match is case-insensitive but otherwise exact. No fuzzy matching.

The bundled fillPoints.xml location is auto-derived from the manifest path — drop the trailing XML filename, prepend `configs/`, append `fillPoints.xml`. An optional `configFolder` attribute overrides this when needed.

### Embedded `<slurryPipeSystem>` blocks

Detected first, before any manifest lookup. A modder shipping their own vehicle/placeable adds the block inside their XML and SPS picks it up automatically. The manifest is only consulted when no embedded block is present. This means a third-party retexture of (say) kaweco profi2 can ship its own embedded block and override SPS's stock support for that file's instance, without affecting other instances of the same vehicle.

### Per-vehicle animation libraries

Each registered vehicle or placeable has its own animation library. For bundled content this is the global SPS-bundled `couplerAnimations.xml`. For embedded content it's parsed from the inline `<couplerAnimations>` block inside the modder's XML. Animation ids are scoped — Modder A's `id="1"` and Modder B's `id="1"` don't collide.

### Multi-fill-type pipes

Coupling-to-coupling transfers and pipe discharge effects automatically use whatever fill type is actually present in the source. A FRC65 nurse tanker carrying digestate pumped through a pipe chain to a digestate-accepting storage works exactly like the equivalent liquidmanure transfer.

---

## Compatibility

- **Manual Attach** — load-order-safe integration. SPS detects FS25_manualAttach and routes pipe-related connection-hose checks through MA's API when present.
- **Real autosave** — confirmed working. SPS save data is preserved across autosaves.
- **Multiplayer** — server-authoritative state, all valve toggles and connections sync via dedicated events.

---

## Credits

**Oscar Mods** — design, code, art.

Contributions, bug reports, and modder-side embedded integrations welcome.