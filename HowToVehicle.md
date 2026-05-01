# How to Add SPS Support to a Vehicle

This walkthrough covers adding **FS25_SlurryPipeSystem** (SPS) support to a tanker, slurry pump, or similar slurry-handling vehicle.

There are **two ways** to add support, depending on whether you own the vehicle XML:

| Path | Use when | Files you edit |
|---|---|---|
| **Bundled** | Adding SPS to a stock or third-party vehicle whose XML you should not modify | SPS-internal `fillPoints.xml`, `nodeTree.i3d`, `spsConfigManifest.xml` |
| **Embedded** | You're shipping your own modded vehicle and want it SPS-ready out of the box | Your vehicle's own XML — single `<slurryPipeSystem>` block |

Both paths use the same XML schema for the SPS config block. The only difference is **where** that block lives.

For full attribute-by-attribute reference see `VehicleConfigSetup_ReadMe.xml`.

---

## Path A — Bundled (you ship the SPS config inside SPS)

### 1. Find the runtime path of the vehicle's XML

Whatever Giants reports for `vehicle.configFileName` is what SPS matches against. For stock content this looks like `data/vehicles/kaweco/profi2/profi2.xml`. For mods it's `mods/<FS25_ModFolderName>/<rest>/<file>.xml`.

### 2. Create the bundled folder mirroring that path

Inside the SPS mod folder, create:

```
configs/<the runtime path with the trailing XML filename stripped>/
```

For example:
- Stock kaweco profi2 → `configs/data/vehicles/kaweco/profi2/`
- Modded BMIX80 → `configs/mods/FS25_Pichon_BMIX80/`

If the mod ships multiple XMLs sharing the same parent folder, add a per-XML subfolder and use the `configFolder` attribute (see step 5).

### 3. Author the nodeTree i3d

Open the example `nodeTree.i3d` shipped in SPS. The standard SPS node hierarchy is:

```
nodeTree root
├── effectNode/effect/pipeEffectSmoke (optional, for fill arms)
├── fillArms/
│   ├── SPS_fillArmCentre01
│   ├── SPS_fillArmUpper01
│   ├── SPS_fillArmLower01
│   └── SPS_fillArmTip01 (RUBBER_BOOT only)
├── pumpControls/
│   └── (visual anchor)
└── pipeCouplers/
    └── SPS_pipeCoupler01/
        └── SPS_pipeCoupler01Arcs/
            ├── SPS_pipeCoupler01Arc01
            └── SPS_pipeCoupler01Arc02
```

Place the SPS nodes correctly on the vehicle:

- **SPS_pipeCouplerXX**: at the centre of the coupling mouth, local Z pointing outward.
- **SPS_pipeCouplerXXArc01/02**: 1.5m left/right and 2.5m forward in local space — defines the arc detection triangle.
- **SPS_fillArmCentre / Upper / Lower / Tip**: per arm type. See `VehicleConfigSetup_ReadMe.xml` for placement rules.
- **rearControlNode** (if `selfPowered="true"`): wherever the player walks to access the rear pump controls.

For arm-equipped vehicles, drop your fill arm node onto the **last node in the arm hierarchy that the tip follows** in the GE scene tree. Zero translation and rotation. Then move the SPS arm nodes back into your `fillArms` group keeping their world positions.

Save the result as `nodeTree.i3d` in the bundled folder you created in step 2.

### 4. Author the fillPoints.xml

Create `fillPoints.xml` next to your `nodeTree.i3d`. Minimum content for a typical tanker:

```xml
<slurryPipeSystem>
    <nodeTree filename="nodeTree.i3d"/>
    <flow litersPerSecond="2000"/>
    <pump selfPowered="false"/>

    <fillArms>
        <fillArm
            id="1"
            tipType="OPEN_PIT"
            centreNodeName="SPS_fillArmCentre01"
            upperNodeName="SPS_fillArmUpper01"
            lowerNodeName="SPS_fillArmLower01"
            fillUnitIndex="1"/>
    </fillArms>

    <pipeCouplings>
        <pipeCoupling
            id="1"
            mountNodeName="SPS_pipeCoupler01"
            valveType="MANUAL"
            maxPipeLength="4.0"
            fillUnitIndex="1"
            connector="male"/>
    </pipeCouplings>
</slurryPipeSystem>
```

Match `litersPerSecond` to the vehicle's vanilla `<fillTriggerVehicle>` rate. See `VehicleConfigSetup_ReadMe.xml` for every attribute and the rules for `<pump>`, `<sounds>`, `<rubberBootPorts>`, `<pumpControls>`, and `<couplerAnimations>` if you need them.

### 5. Add a manifest entry

Edit `configs/spsConfigManifest.xml`. Add inside `<vehicleConfigs>`:

```xml
<vehicle path="data/vehicles/kaweco/profi2/profi2.xml"/>
```

The `path` attribute is the runtime path (step 1), exactly. SPS computes the bundled folder by stripping the trailing filename and prepending `configs/` — so your manifest path and your bundled folder layout must agree.

If your bundled folder is in a different location than auto-derivation expects (e.g. multiple XMLs share the same runtime parent folder), add the optional `configFolder` attribute:

```xml
<vehicle path="mods/X/myCab.xml"
         configFolder="mods/X/myCab"/>
```

`path` is what to match against runtime. `configFolder` is where SPS looks for the bundled fillPoints.xml.

### 6. Test

Load the game with the vehicle present in a save. Look in the log for:

```
[SPS] loadVehicleConfigs: registered '...path...' -> ...
[SPS] findVehicleConfigForVehicle: matched '...path...'
[SPS] registerVehicle - registered ...
```

If the match fails, the log will say `findVehicleConfigForVehicle: no match for '...'` and print the exact path Giants reports. Compare to your manifest entry's `path` attribute and adjust.

---

## Path B — Embedded (you ship a SPS-ready vehicle as a third-party mod)

This is the **preferred path for new mods**. No SPS-side files need editing. Your vehicle is self-contained.

### 1. Author your vehicle's i3d with SPS nodes included

Same node names as the bundled path (`SPS_pipeCoupler01`, etc.) but they live in your **own** vehicle i3d, not in a separate nodeTree file. Map them via `<i3dMapping>` in your vehicle XML so you can reference them by name.

### 2. Add a `<slurryPipeSystem>` block to your vehicle XML

Place it as a direct child of `<vehicle>`:

```xml
<vehicle ...>
    ... vanilla vehicle elements ...

    <slurryPipeSystem>
        <flow litersPerSecond="2000"/>
        <pump selfPowered="false"/>

        <pipeCouplings>
            <pipeCoupling
                id="1"
                mountNodeName="SPS_pipeCoupler01"
                valveType="MANUAL"
                maxPipeLength="4.0"
                fillUnitIndex="1"
                connector="male"
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

    ... more vanilla vehicle elements ...
</vehicle>
```

There is **no `<nodeTree>` element** in embedded blocks — SPS resolves all node names against your vehicle's own i3d.

The `<couplerAnimations>` block is optional. If your vehicle has animated parts (clamp handles, valve wheels) under each pipe coupling node, declare animations referenced by `connectorAnimation` and `valveAnimation` ids on the `<pipeCoupling>` lines. Animations are scoped to your vehicle — modders' ids don't collide with each other.

### 3. Test

Load the game with your mod active. Log shows:

```
[SPS] findVehicleConfigForVehicle: embedded <slurryPipeSystem> found in <your vehicle path>
[SPS] registerVehicle - registered ...
```

No manifest entry is needed. No SPS-side files were touched.

### 4. Distribution

Your mod ships SPS-ready. Players who already have FS25_SlurryPipeSystem installed get full integration automatically. Players without SPS installed get vanilla behaviour — your `<slurryPipeSystem>` block is silently ignored by Giants.

---

## Common Issues

**"no match for ..." in log**  
The runtime path Giants reports doesn't match what's in `spsConfigManifest.xml`. Check the exact string in the log line and update the `path` attribute.

**"no fillPoints.xml at ..." at boot**  
Manifest entry was registered but the bundled fillPoints.xml isn't in the expected folder. Check the path computed by SPS (printed in the log) against where you placed the file. If they don't match, either move the file or add a `configFolder` override on the manifest entry.

**"part node 'X' not found under mountNode for animation id=Y"**  
Your `<couplerAnimation>` references a node that isn't a descendant of the `<pipeCoupling mountNodeName="...">` node. Move it under the mount node hierarchy or fix the `node="..."` attribute.

**Embedded block ignored**  
The `<slurryPipeSystem>` element must be a direct child of `<vehicle>`. Not nested inside any other element.

---

## See Also

- **VehicleConfigSetup_ReadMe.xml** — full schema reference for every attribute.
- **HowToPlaceable.md** — equivalent walkthrough for buildings, tanks, and other placeables.
- **README.md** — project overview and file layout.