# How to Add SPS Support to a Placeable

This walkthrough covers adding **FS25_SlurryPipeSystem** (SPS) support to a slurry-storing placeable: cow shed, slurry pit, lagoon, dedicated storage tank, etc.

There are **two ways** to add support:

| Path | Use when | Files you edit |
|---|---|---|
| **Bundled** | Adding SPS to a stock or third-party placeable whose XML you should not modify | SPS-internal `fillPoints.xml`, `nodeTree.i3d`, `spsConfigManifest.xml` |
| **Embedded** | You're shipping your own modded placeable (or a custom map's bundled placeable) and want it SPS-ready | Your placeable's own XML — single `<slurryPipeSystem>` block |

Both paths use the same XML schema for the SPS config block.

For full attribute-by-attribute reference see `PlaceableConfigSetup_ReadMe.xml`.

---

## Path A — Bundled (you ship the SPS config inside SPS)

### 1. Find the runtime path of the placeable's XML

`placeable.configFileName` from Giants. For stock content this looks like `data/placeables/rudolfHormann/cowBarnMedium/cowBarnMedium.xml`. For mods it's `mods/<FS25_ModFolderName>/<rest>/<file>.xml`. Map mods bundling placeables typically use `mods/<FS25_MapName>/map/placeables/<name>/<name>.xml`.

### 2. Create the bundled folder mirroring that path

Inside the SPS mod folder, create:

```
configs/<runtime path with the trailing XML filename stripped>/
```

For example:
- Stock cowBarnMedium → `configs/data/placeables/rudolfHormann/cowBarnMedium/`
- Witcombe map's cowBarn01 → `configs/mods/FS25_Witcombe/map/placeables/cowBarn01/`

### 3. Author the nodeTree i3d

The placeable's nodeTree must have **one container child** under its root, named to match a node already in the placeable's own component hierarchy. SPS parents the nodeTree contents into that node.

Standard placeable node hierarchy:

```
nodeTree root
└── <containerName> (matches an existing placeable i3d node)
    ├── pipeCouplers/
    │   └── SPS_pipeCoupler01/
    │       └── SPS_pipeCoupler01Arcs/
    │           ├── SPS_pipeCoupler01Arc01
    │           └── SPS_pipeCoupler01Arc02
    │
    ├── fillPlaneNodes/
    │   ├── slurryPlaneCentre        ← centre of fill area (always)
    │   ├── slurryPlaneEdge           ← round shape only
    │   ├── slurryPlaneCorner1        ← rectangle shape only
    │   └── slurryPlaneCorner2        ← rectangle shape only
    │
    └── effects/                      ← optional, for inlet streams
        └── effect/pipeEffectSmoke
```

Node placement:

- **SPS_pipeCouplerXX**: at the centre of the coupling mouth on the building, local Z pointing outward.
- **SPS_pipeCouplerXXArc01/02**: 1.5m left/right and 2.5m forward — defines the arc detection triangle.
- **slurryPlaneCentre**: at ground level at the centre of the slurry surface area.
- **slurryPlaneEdge**: at ground level on the edge of the circular pit (round shape). Distance to centre = detection radius.
- **slurryPlaneCorner1/2**: two diagonal corners of a rectangular pit at ground level.
- **effect/pipeEffectSmoke**: at the inlet point where pumped slurry visually enters the store.

Save as `nodeTree.i3d` in the bundled folder.

### 4. Author the fillPoints.xml

Minimum content for a typical placeable:

```xml
<slurryPipeSystem>
    <nodeTree filename="nodeTree.i3d"/>

    <fillPlane
        node="liquidManureFillPlane"
        minY="0"
        maxY="2"
        fillType="LIQUIDMANURE"
        shape="round"
        centreNodeName="slurryPlaneCentre"
        edgeNodeName="slurryPlaneEdge"/>

    <hideNodes>
        <node name="vanillaDriveInTrigger"/>
    </hideNodes>

    <hideCollisions>
        <node name="vanillaRampCollision"/>
    </hideCollisions>

    <pipeCouplings>
        <pipeCoupling
            id="1"
            mountNodeName="SPS_pipeCoupler01"
            flowDirection="BOTH"
            valveType="MANUAL"
            connector="female"/>
    </pipeCouplings>
</slurryPipeSystem>
```

The `<fillPlane node="...">` references the engine-animated fill plane node in the placeable's own i3d (the one that moves between `minY` and `maxY` as the storage fills/empties). SPS reads its world Y each tick to know the surface height for fill arm detection.

For husbandries (cow sheds, pig barns) where the fill plane is hidden inside the building and arms can't reach it, omit the `<fillPlane>` element entirely. SPS will register the placeable in coupling-only mode — pipes work, fill arms do not.

See `PlaceableConfigSetup_ReadMe.xml` for every attribute, plus `<pipeAnimNode>` for deployable couplings, `<effects>` blocks on pipe couplings, and `<couplerAnimations>` for animated handles.

### 5. Add a manifest entry

Edit `configs/spsConfigManifest.xml`. Add inside `<placeableConfigs>`:

```xml
<placeable path="data/placeables/rudolfHormann/cowBarnMedium/cowBarnMedium.xml"/>
```

The `path` attribute is the runtime path (step 1), exactly. SPS strips the trailing filename and prepends `configs/` to find the bundled fillPoints.xml.

If multiple placeables in the same mod share the same parent folder (for example `mods/UKBuildings/xml/cowShedUK.xml` AND `mods/UKBuildings/xml/cowShedUK_nonMilk.xml`), auto-derivation would collide. Use the optional `configFolder` attribute:

```xml
<placeable path="mods/UKBuildings/xml/cowShedUK.xml"
           configFolder="mods/UKBuildings/xml/cowShedUK"/>
<placeable path="mods/UKBuildings/xml/cowShedUK_nonMilk.xml"
           configFolder="mods/UKBuildings/xml/cowShedUK_nonMilk"/>
```

`path` is the runtime configFileName tail. `configFolder` is where the bundled fillPoints.xml lives under `configs/`.

### 6. Test

Place the building in a save. Log shows:

```
[SPS] loadPlaceableConfigs: registered '...path...' -> ...
[SPS] findPlaceableConfigForPlaceable: matched '...path...'
[SPS] registerPlaceable - registered ...
```

If matching fails, the log says `findPlaceableConfigForPlaceable: no match for '...'` with the exact runtime string. Adjust the manifest `path` to match.

---

## Path B — Embedded (you ship a SPS-ready placeable)

The **preferred path for new mods**. No SPS-side files. Self-contained.

### 1. Author your placeable's i3d with SPS nodes included

Same node names as the bundled path (`SPS_pipeCoupler01`, etc.) but inside your **own** placeable i3d. Map them via `<i3dMapping>` in your placeable XML.

Important: each i3dMapping `id` must be unique. If your placeable already uses `id="storage"` for the husbandry storage, do not re-use that id for an SPS subtree node — pick a different unique id.

### 2. Add a `<slurryPipeSystem>` block to your placeable XML

Direct child of `<placeable>`:

```xml
<placeable ...>
    ... vanilla placeable elements ...

    <slurryPipeSystem>
        <fillPlane
            node="myFillPlane"
            minY="0"
            maxY="1.5"
            fillType="LIQUIDMANURE"/>

        <pipeCouplings>
            <pipeCoupling
                id="1"
                mountNodeName="SPS_pipeCoupler01"
                flowDirection="BOTH"
                valveType="MANUAL"
                connector="female"
                connectorAnimation="1"
                valveAnimation="2"/>
        </pipeCouplings>

        <couplerAnimations>
            <couplerAnimation id="1" name="myClamp">
                <part node="myClampHandle"
                      startTime="0" endTime="0.5"
                      startRot="125 0 0" endRot="0 0 0"/>
            </couplerAnimation>
            <couplerAnimation id="2" name="myValve">
                <part node="myValveHandle"
                      startTime="0" endTime="0.5"
                      startRot="0 0 0" endRot="20 0 0"/>
            </couplerAnimation>
        </couplerAnimations>
    </slurryPipeSystem>

    ... more vanilla placeable elements ...
</placeable>
```

No `<nodeTree>` element — all node names resolve against your placeable's own i3d.

The `<couplerAnimations>` block is optional. Animations are scoped to this placeable.

### 3. Test

Place the building in a save. Log shows:

```
[SPS] findPlaceableConfigForPlaceable: embedded <slurryPipeSystem> found in <your placeable path>
[SPS] registerPlaceable - registered ...
```

No manifest entry needed.

### 4. Distribution

Your mod ships SPS-ready. Players with FS25_SlurryPipeSystem installed get integration automatically. Players without SPS get vanilla behaviour — your `<slurryPipeSystem>` block is silently ignored by Giants.

---

## Map-Bundled Placeables

Map mods (custom maps that ship buildings) work exactly like normal mods. The runtime path will be something like `mods/FS25_MyMap/map/placeables/<name>/<name>.xml`. Use either bundled or embedded path.

For embedded, the `<slurryPipeSystem>` block goes inside each placeable XML the map ships. No special handling needed for "map-shipped" placeables — SPS treats them the same as any other mod placeable.

---

## Common Issues

**"no match for ..." in log**  
Runtime path doesn't match `spsConfigManifest.xml`. Check the exact string in the log and update the `path` attribute.

**"no fillPoints.xml at ..." at boot**  
Bundled fillPoints.xml isn't where SPS expects. Either move the file to the auto-derived location, or add `configFolder` to the manifest entry.

**fillPlane debug shows fillPlaneNode=nil**  
The `node="..."` attribute on `<fillPlane>` references a node that doesn't exist in the placeable's i3d or i3dMappings. Check the node name and i3dMapping id.

**Pipe couplings work but fill arms get rejected**  
The `<fillPlane>` block is missing or incorrect — fill arms need surface detection bounds. Either add a proper `<fillPlane shape="...">` block, or accept coupling-only mode if the placeable has no exposed slurry surface.

**i3dMapping conflicts after adding SPS nodes**  
Duplicate `id="..."` mappings. Each i3dMapping id must be unique. Most common collision is the SPS node tree being given `id="storage"` which conflicts with the husbandry's own storage node mapping.

---

## See Also

- **PlaceableConfigSetup_ReadMe.xml** — full schema reference for every attribute.
- **HowToVehicle.md** — equivalent walkthrough for tankers and pumps.
- **README.md** — project overview and file layout.
