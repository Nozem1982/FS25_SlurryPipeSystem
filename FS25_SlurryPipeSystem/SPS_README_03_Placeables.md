# Slurry Pipe System (SPS) — Adding SPS to Placeables (Stores, Pits & Source Tanks)

This guide is for placeable / map modders who want their own slurry store, open pit, manure
lagoon, or liquid-fertiliser source tank to work with SPS — so SPS tankers and sprayers can
load from and discharge into them.

**You never edit the SPS mod.** Everything is done inside *your own* placeable's XML and i3d.
Editing files inside the SPS mod folder will break multiplayer and is not supported.

Two placeable kinds, two blocks:
- **Slurry store / pit / lagoon** → `<slurryPipeSystem>`.
- **Liquid-fertiliser / herbicide source tank** (for sprayers) → `<sprayerPipeSystem>`.

> Drawing **water** from map lakes/ponds is a separate, map-i3d system — see the dedicated
> map-side water guide, not this document.

All element/attribute names below are exactly what the SPS parser reads.

---

## 1. How to register your placeable — embedded block

```xml
<placeable ...>
    ...
    <slurryPipeSystem>
        ... SPS config ...
    </slurryPipeSystem>
</placeable>
```

SPS uses `placeable.slurryPipeSystem` / `placeable.sprayerPipeSystem` directly. On load:

```
[SPS fillPlane debug] <yourPlaceable>.xml ...
... registerPlaceable - registered <yourPlaceable>.xml
```

**Storage requirement.** A slurry store only becomes a source if it has `spec_silo`,
`spec_husbandry`, or `spec_siloExtension`. (A `spec_husbandry` / `spec_productionPoint` with
no fill plane still works as a *coupling-only* source — pipe access, no arm surface
detection.)

---

## 2. Node resolution — which nodes need a nodeTree

Two resolution paths:

**A) Against your placeable's own i3d** (mapping name or index path) — no nodeTree needed:
- `fillPlane#node`
- `hideNodes` / `hideCollisions` entries
- `pipeAnimNode#node`
- a coupling's legacy `#node` (+ `#offsetX/Y/Z`)

**B) By name from an injected nodeTree only** (not searched in the placeable's own tree):
- a coupling's `mountNodeName`
- `fillPlane#centreNodeName` / `edgeNodeName` / `corner1NodeName` / `corner2NodeName`
- coupling `effects` effect-node names

### nodeTree (optional)

```xml
<nodeTree filename="path/to/nodeTree.i3d"/>
```

First child is the SPS root; under it are *group* transforms; under each group are *container*
transforms whose names must match a node in your placeable's first component
(`components[1]`). Each container's children are re-linked under that live node.

---

## 3. The fill plane — `<fillPlane>` (slurry stores)

Lets a tanker's fill arm detect the slurry surface, submerge into it, and follow it up/down.

```xml
<fillPlane node="0>5|2"
           minY="0.0"
           maxY="1.8"
           fillType="LIQUIDMANURE"
           shape="round"
           centreNodeName="pitCentre"
           edgeNodeName="pitEdge"/>
```

| Attribute        | Default        | Meaning |
|------------------|----------------|---------|
| `node`           | —              | The fill-plane node (your own i3d, by mapping name or index path). Moved in Y to represent the surface. |
| `minY`           | 0              | Local Y of the surface when **empty**. |
| `maxY`           | 1              | Local Y of the surface when **full**. |
| `fillType`       | `LIQUIDMANURE` | Content type. Falls back to LIQUIDMANURE if unknown. |
| `shape`          | —              | Optional XZ detection bounds: `round` or `rectangle`. |
| `centreNodeName` | —              | Centre of the detection area (nodeTree). |
| `edgeNodeName`   | —              | `round`: rim node; radius = XZ distance centre→edge. |
| `corner1NodeName`| —              | `rectangle`: one corner. |
| `corner2NodeName`| —              | `rectangle`: opposite corner. |

Surface Y = `minY + (fillLevel / capacity) * (maxY - minY)`. The shape nodes define only the
XZ footprint the arm must be over (their Y is ignored). Omit `shape` and the store still works
for piped access; the shape is what enables arm-into-pit surface detection.

---

## 4. Pipe couplings — `<pipeCouplings>` (store inlet/outlet)

A fixed connection point a tanker's strap pipe connects to. Walk-up connect and lay-chain are
added automatically on the placeable side.

```xml
<pipeCouplings>
    <pipeCoupling id="1"
                  mountNodeName="storeInlet01"
                  valveType="MANUAL"
                  flowDirection="BOTH"
                  connector="female"/>
</pipeCouplings>
```

| Attribute              | Default  | Meaning |
|------------------------|----------|---------|
| `id`                   | index+1  | Identifier. |
| `mountNodeName`        | —        | Coupler mount node (nodeTree). Required unless using legacy `#node`. |
| `node` (legacy)        | —        | Alternative: a node from your own i3d. |
| `offsetX/Y/Z` (legacy) | 0        | Optional local offset on the legacy `#node` mount. |
| `valveType`            | `MANUAL` | `MANUAL`, `HYDRAULIC`, or `NONE`. |
| `flowDirection`        | `BOTH`   | `BOTH`, `FILL`, or `DISCHARGE`. |
| `connector`            | `female` | `male` / `female` — matched against the tanker end (tankers default `male`). |
| `connectorAnimation`   | —        | Optional coupler animation id (see §7). |
| `valveAnimation`       | —        | Optional valve animation id (see §7). |
| `deployable`           | false    | If true the coupler starts hidden + non-colliding until deployed. |
| `undeployedVisibleNode`| —        | Space-separated node names shown while undeployed (e.g. a cap). |

### Required mount node structure

Same as on vehicles — the connection arc is resolved **by child position**:

```
storeInlet01                   <- the mountNodeName
├── arcs                       <- MUST be child index 0 (any name) = arc apex
│   ├── arcA                   <- child 0 of arcs
│   └── arcB                   <- child 1 of arcs
├── inNode                     <- direct child, named EXACTLY "inNode"
└── outNode                    <- direct child, named EXACTLY "outNode"
```

- First child of the mount node = arc apex; its first two children = the arc points.
- The player must stand **inside this arc triangle** for the coupler to be selectable, and a
  tanker coupler connects only when the two triangles overlap within **5.9 m**.
- If no arc geometry is resolvable, the placeable coupler falls back to a **1.8 m** proximity
  radius (slurry only — this fallback does not exist for sprayers).
- `inNode` / `outNode` are direct children matched by exact name; they are the flow points.

### Connect / valve interaction (slurry)

At the coupler, the player presses ACTIVATE_OBJECT (R):
- **Short press** — connect (when a tanker coupler overlaps) or disconnect (when connected).
- **Hold ~0.8 s** — open the valve, then hold again to close it.
- If the coupling is `HYDRAULIC` or driven from a rear control, the walk-up prompt only
  disconnects (no valve via this prompt).

### Optional inlet effects

```xml
<pipeCoupling id="1" mountNodeName="storeInlet01">
    <effects inletDistance="1.5">
        <effectNode effectNode="inletEffectTG"/>   <!-- index 0: pipe effect root (nodeTree) -->
        <effectNode effectNode="smokeNode"/>       <!-- index 1: smoke node name beneath it -->
    </effects>
</pipeCoupling>
```

`effectNode(0)` is the pipe-effect transform group; `effectNode(1)` names the smoke node
beneath it. `inletDistance` (default 1.5) sets the effect length.

---

## 5. Hiding base-game parts — `<hideNodes>` / `<hideCollisions>`

Both resolve against your placeable's own i3d.

```xml
<hideNodes>
    <node name="vanillaFillPlane"/>
</hideNodes>
<hideCollisions>
    <node name="oldCollision"/>
    <node node="0>3|1|4"/>   <!-- or by index path -->
</hideCollisions>
```

`hideNodes` sets visibility off (restored on mod removal). `hideCollisions` removes the node
from physics, by `name` (deep search, all matches) or by `node` index/mapping path.

---

## 6. Agitation / thickening — root `agitator` attribute

```xml
<slurryPipeSystem agitator="true">
```

`agitator="true"` (default false) makes the store participate in the slurry thickness model —
its content thickens over time and can be agitated. Leave off for a simple always-liquid
source.

> **Crust vegetation visuals are not currently available via the embedded block.** The crust
> reader looks for a non-prefixed `slurryPipeSystem.crust` key, which an embedded placeable
> (prefix `placeable.`) never matches. The thickening behaviour from `agitator="true"` works;
> the on-surface crust foliage does not, on an embedded placeable, until that is addressed in
> the mod.

---

## 7. Animations — connector / valve ids

`connectorAnimation` / `valveAnimation` are **integer ids** referring to entries in the SPS
mod's `configs/couplerAnimations.xml`. Each entry's parts name nodes that SPS searches for
**under your coupling's mount node** and animates (rotation/translation over a time span).
connector plays forward on connect / reverse on disconnect; valve plays on open / close.

You use an **existing** id and name your part sub-objects to match the part names that id
expects (open `couplerAnimations.xml` read-only to see them). You cannot define new ids
without editing the SPS mod, so stick to the shipped ones or omit the attribute.

---

## 8. Optional pipe animation node — `<pipeAnimNode>`

```xml
<pipeAnimNode node="0>7|0" rx="0" ry="0" rz="0"/>
```

A node (your own i3d) rotated by the given degrees while the store is in use. All default 0.

---

## 9. Liquid-fertiliser / herbicide source tank — `<sprayerPipeSystem>`

For a placeable that feeds **sprayers**. Simpler — no fill plane, source comes from storage.

```xml
<placeable ...>
    ...
    <sprayerPipeSystem>
        <sprayerPipeCouplings>
            <sprayerPipeCoupling id="1" mountNodeName="tankOutlet01"
                                 flowDirection="BOTH" maxPipeLength="7.5"/>
        </sprayerPipeCouplings>
        <nodeTree filename="nodeTree.i3d"/>   <!-- optional -->
    </sprayerPipeSystem>
</placeable>
```

| Element / attribute                     | Default | Meaning |
|-----------------------------------------|---------|---------|
| `sprayerPipeCoupling#id`                 | index+1 | Identifier. |
| `sprayerPipeCoupling#mountNodeName`      | —       | Coupler mount node. **Required.** |
| `sprayerPipeCoupling#flowDirection`      | `BOTH`  | `BOTH` / `FILL` / `DISCHARGE`. |
| `sprayerPipeCoupling#maxPipeLength`      | 7.5     | Max pipe span (m). |
| `sprayerPipeCoupling#connectorAnimation` | —       | Optional coupler animation id. |
| `sprayerPipeCoupling#valveAnimation`     | —       | Optional valve animation id. |

- **Mount node structure** is identical to §4: first child = arc apex (2 arc children), plus
  `inNode` + `outNode` direct children. Arcs are **mandatory** for sprayer couplers (no
  proximity fallback).
- **Storage requirement:** the placeable must expose storage via `spec_silo` (incl.
  `spec_silo.storages[1]`) or `spec_husbandry`. SPS reads the fill level from there.
- **No placeable-side prompt** — all sprayer connect/disconnect is driven from the sprayer
  vehicle's pump control node. The source tank just defines the coupling.
- If you author the coupler nodes directly in the placeable i3d (no nodeTree), embedded
  sprayer placeables find them by name in the placeable's component tree.

---

## 10. Minimal worked example — slurry pit + coupling

```xml
<placeable ...>
    ...
    <slurryPipeSystem agitator="true">
        <nodeTree filename="nodeTree.i3d"/>
        <fillPlane node="0>5|2" minY="0.0" maxY="1.6" fillType="LIQUIDMANURE"
                   shape="rectangle"
                   centreNodeName="pitCentre"
                   corner1NodeName="pitCorner1"
                   corner2NodeName="pitCorner2"/>
        <pipeCouplings>
            <pipeCoupling id="1" mountNodeName="pitInlet01"
                          valveType="MANUAL" flowDirection="BOTH" connector="female"/>
        </pipeCouplings>
        <hideNodes>
            <node name="vanillaFillPlane"/>
        </hideNodes>
    </slurryPipeSystem>
</placeable>
```

Node requirements: `0>5|2` is the fill-plane mesh in your i3d; `pitCentre/pitCorner1/
pitCorner2` and `pitInlet01` live in the nodeTree, with `pitInlet01` built per §4 (arc apex
first child + arc points, plus `inNode`/`outNode`).

---

## 11. Checklist

1. Add the block to **your own** placeable XML — never edit the SPS mod.
2. Slurry store: ensure it is real storage (`spec_silo` / `spec_husbandry` /
   `spec_siloExtension`).
3. `<fillPlane>` with `node`, `minY`, `maxY`, `fillType`, and a `shape` for arm detection.
4. `<pipeCouplings>` — each mount node needs the arc-apex first child (2 arc points) and
   `inNode` + `outNode` direct children.
5. Hide replaced vanilla parts with `<hideNodes>` / `<hideCollisions>`.
6. Liquid-fert tank: `<sprayerPipeSystem>` with a coupling (same mount structure) + real
   storage.
7. Load and confirm `registerPlaceable - registered …`; missing nodes are named in the log.
