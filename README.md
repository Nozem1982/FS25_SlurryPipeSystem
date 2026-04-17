<?xml version="1.0" encoding="utf-8"?>
<!--
================================================================================
  FS25_SlurryPipeSystem — fillPoints Reference
  Oscar Mods
================================================================================
  This file is documentation only. It is not loaded by the mod.
  Place it in: configs/
  Each vehicle and placeable has its own fillPoints.xml in a subfolder.
================================================================================
-->

<slurryPipeSystemReference>

    <!-- ========================================================================
         FOLDER STRUCTURE
    =========================================================================

    configs/
    ├── REFERENCE.xml                       ← this file
    ├── vehicleConfigs/
    │   ├── <vehicleName>/
    │   │   ├── fillPoints.xml              ← vehicle SPS config
    │   │   └── nodeTree.i3d               ← SPS nodes for this vehicle
    │   └── ...
    └── placeableConfigs/
        ├── <placeableName>/
        │   └── fillPoints.xml             ← placeable SPS config
        └── ...

    The folder name under vehicleConfigs/ must exactly match the vehicle's
    i3d filename without extension. The manager matches by scanning the folder
    name against the loaded vehicle's config filename at map load time.

    ======================================================================== -->


    <!-- ========================================================================
         NODE TREE — i3d SETUP
    =========================================================================

    All SPS nodes for a vehicle are authored in a separate nodeTree i3d,
    typically named "nodeTree.i3d", placed alongside the vehicle fillPoints.xml.

    The nodeTree is loaded via loadI3DFile (not cloned) at runtime and linked
    into the vehicle scene hierarchy. It must have one root TransformGroup.
    All SPS nodes sit inside that root.

    Do NOT use cloneSharedI3DNode for nodeTree files — cloning breaks skin bindings.

    EXCEPTION: Conduit pump vehicles (conduit="true") have their coupling nodes
    authored directly in the vehicle's own i3d. No nodeTree is needed and the
    <nodeTree> element should be omitted from their fillPoints.xml. The manager
    finds the coupling nodes by searching the vehicle rootNode by name.

    ── FULL NODE TREE STRUCTURE ──────────────────────────────────────────────

    nodeTree root (TransformGroup)
    │
    ├── effectNode (TransformGroup)
    │   └── effect (TransformGroup)             ← PipeEffect shape node
    │       └── pipeEffectSmoke (TransformGroup) ← smoke/particle emitter
    │
    ├── fillArms (TransformGroup)
    │   ├── SPS_fillArmCentre01                 ← OPEN_PIT nozzle centre
    │   ├── SPS_fillArmUpper01                  ← OPEN_PIT upper detection
    │   ├── SPS_fillArmLower01                  ← OPEN_PIT lower detection
    │   ├── SPS_fillArmTip01                    ← RUBBER_BOOT tip node
    │   └── (repeat pattern for additional arms: Centre02, Upper02, Lower02 etc.)
    │
    ├── pumpControls (TransformGroup)
    │   └── tsa_vis (TransformGroup)            ← visual anchor for pump HUD
    │
    └── pipeCouplers (TransformGroup)
        ├── SPS_pipeCoupler01
        │   └── SPS_pipeCoupler01Arcs
        │       ├── SPS_pipeCoupler01Arc01      ← arc detection node left
        │       └── SPS_pipeCoupler01Arc02      ← arc detection node right
        ├── SPS_pipeCoupler02
        │   └── SPS_pipeCoupler02Arcs
        │       ├── SPS_pipeCoupler02Arc01
        │       └── SPS_pipeCoupler02Arc02
        └── (repeat pattern for SPS_pipeCoupler03 etc. if required)

    ── NODE PLACEMENT RULES ──────────────────────────────────────────────────

    SPS_pipeCouplerXX
        Place at the physical centre of the coupling mouth.
        Rotation: local Z-axis pointing outward away from the barrel.

    SPS_pipeCouplerXXArc01 / Arc02
        Place symmetrically either side of the coupler mouth:
            1.5m left and right in local X, 2.5m forward in local Z.
        These two nodes define the arc detection triangle used to detect
        whether a pipe end is close enough and angled correctly to connect.

    SPS_fillArmCentre
        Place at the nozzle tip centre.
        Used to determine the XZ position for slurry surface height sampling.

    SPS_fillArmUpper
        Place 0.3–0.5m above the nozzle tip.
        Must enter the store fill volume (trigger box) for connection to register.

    SPS_fillArmLower
        Place at or below the nozzle tip.
        Must be below the current slurry surface Y for flow to begin.
        If the surface drops below this node, flow stops automatically.

    SPS_fillArmTip
        RUBBER_BOOT and RUBBER_BOOT_PIT arms only.
        Place exactly at the nozzle tip.
        Used for proximity and angle checks against the rubber boot port nodes.

    effectNode / effect / pipeEffectSmoke
        Place at the point where slurry visually discharges.
        The PipeEffect streams from this node toward the slurry surface.
        pipeEffectSmoke is repositioned dynamically as stream length changes.

    SPS_rubberBootLower / SPS_rubberBootUpper
        Place at the lower and upper bounds of the rubber boot opening on the vehicle.
        A fill arm tip must fall between these two Y positions, within XZ proximity,
        for the arm to be considered docked into the boot.

    rearControlNode
        Place at the rear of the vehicle where the player stands to access
        the walkaround pump control (selfPowered vehicles only).

    ======================================================================== -->


    <!-- ========================================================================
         cylinderedConfigIndex
    =========================================================================

    FS25 vehicles with multiple arm/pipe configurations use the Cylindered
    specialization. The index maps to the active configuration slot (0-based):

        0 = first configuration  (default/folded state)
        1 = second configuration (e.g. arm extended, couplings deployed)
        2 = third configuration  etc.

    Only elements whose cylinderedConfigIndex matches the vehicle's currently
    active configuration are registered and active. Elements without this
    attribute are always registered regardless of configuration state.

    Omit cylinderedConfigIndex entirely if the vehicle has only one configuration.

    ======================================================================== -->


    <!-- ========================================================================
         VEHICLE fillPoints.xml — ELEMENT REFERENCE
    =========================================================================

    ── <nodeTree> ────────────────────────────────────────────────────────────

    <nodeTree filename="nodeTree.i3d"/>

    filename    Path to the nodeTree i3d relative to this fillPoints.xml.
                Omit this element entirely for conduit vehicles (PTO Slurry Pump)
                whose SPS nodes live directly in the vehicle i3d.

    ── <flow> ────────────────────────────────────────────────────────────────

    <flow litersPerSecond="N"/>

    litersPerSecond     Base transfer rate in litres per second at full pump speed.
                        Typical range: 500–2000.
                        Applies to all fill arms and pipe coupling transfers.

    ── <pump> ────────────────────────────────────────────────────────────────

    <pump selfPowered="bool" conduit="bool"/>

    selfPowered="true"  Vehicle has its own pump independent of PTO.
                        Used for self-propelled or electric-pump trailers (e.g. TSA).
                        Pump on/off toggle is available via the walkaround
                        pumpControl activatable at the rear of the vehicle.

    conduit="true"      Vehicle is a pass-through pump (e.g. PTO Slurry Pump).
                        No fill unit — slurry moves directly between two couplings.
                        Direction is set from the cab. Either coupling can be
                        inlet or outlet — the pump has no fixed side.
                        flowDirection restrictions on connected store couplings
                        are still respected and will block incorrect flow.
                        Pipe chains cannot be laid FROM conduit pump couplings —
                        pipes must be connected TO them.

    Omit <pump/> entirely for standard PTO-driven tankers with no special pump behaviour.

    ── <sounds> ──────────────────────────────────────────────────────────────

    <sounds>
        <engineLoop
            file="..."
            linkNode="..."
            innerRadius="N"
            outerRadius="N"
        />
    </sounds>

    file            Path to a .gls sound file. $data/ paths are valid.
    linkNode        Node name in the vehicle hierarchy to attach the sound source to.
    innerRadius     Distance in metres at which the sound plays at full volume.
    outerRadius     Distance in metres at which the sound fades to silence.

    Provides a looping pump/engine sound for selfPowered vehicles.
    Omit the <sounds> block entirely for PTO-driven vehicles.

    ── <fillArms> ────────────────────────────────────────────────────────────

    <fillArms>
        <fillArm
            id="N"
            cylinderedConfigIndex="N"
            tipType="OPEN_PIT|RUBBER_BOOT|RUBBER_BOOT_PIT"
            centreNodeName="..."
            upperNodeName="..."
            lowerNodeName="..."
            tipNodeName="..."
            fillUnitIndex="N"
        >
            <effects>
                <effectNode ... />
            </effects>
        </fillArm>
    </fillArms>

    id                      Unique integer ID for this arm within the vehicle.

    cylinderedConfigIndex   Active Cylindered config slot (0-based). Omit if N/A.

    tipType
        OPEN_PIT            Arm dips into an open slurry pit or store surface.
                            Requires: centreNodeName, upperNodeName, lowerNodeName.
                            Upper node must enter the store fill volume trigger.
                            Lower node must be below the slurry surface Y for flow.

        RUBBER_BOOT         Arm nozzle docks physically into a rubber boot port
                            on a building or placeable.
                            Requires: tipNodeName.
                            Connection confirmed by proximity and angle to boot nodes.

        RUBBER_BOOT_PIT     Combines RUBBER_BOOT physical docking with OPEN_PIT
                            surface detection. Used for enclosed inlet ports that
                            also have a visible slurry surface below.
                            Requires: tipNodeName, centreNodeName, upperNodeName, lowerNodeName.

    centreNodeName          Node at nozzle centre for XZ surface sampling (OPEN_PIT).
    upperNodeName           Node above nozzle — enters store fill volume (OPEN_PIT).
    lowerNodeName           Node at nozzle tip — must be below surface Y (OPEN_PIT).
    tipNodeName             Node at tip for proximity/angle docking check (RUBBER_BOOT).
    fillUnitIndex           Vehicle fill unit to fill or discharge. Default: 1.

    <effects> (optional child of <fillArm>)
        Declares discharge effect nodes explicitly for this arm.
        If omitted, the manager auto-detects from the nodeTree
        effectNode > effect > pipeEffectSmoke hierarchy.
        Use this block when the nodeTree does not follow the standard structure
        or when per-arm effect configuration is required.

        <effectNode
            effectClass="PipeEffect"    Must be PipeEffect for slurry stream visuals.
            effectNode="..."            Node name in the nodeTree for the PipeEffect shape.
            materialType="pipe"         Material type key — use "pipe" for slurry.
            maxBending="N.N"            Maximum pipe bending factor (0.0–1.0).
            extraDistance="N.N"         Extra stream distance added to surface offset.
            positionUpdateNodes="..."   Space-separated node names to reposition as
                                        stream length updates (e.g. pipeEffectSmoke).
        />
        <effectNode
            effectNode="..."            Node name of the secondary smoke/particle effect.
            materialType="unloadingSmoke"
            delay="N.N"                 Seconds before this effect starts after flow begins.
            alignToWorldY="true"        Keeps the emitter aligned to world up axis.
        />

    Leave <fillArms/> self-closing if this vehicle has no fill arms.

    ── <pipeCouplings> ───────────────────────────────────────────────────────

    <pipeCouplings>
        <pipeCoupling
            id="N"
            cylinderedConfigIndex="N"
            mountNodeName="..."
            valveType="MANUAL|HYDRAULIC|NONE"
            maxPipeLength="N.N"
            fillUnitIndex="N"
            valveFromRearControl="bool"
            connector="male|female"
        />
    </pipeCouplings>

    id                      Unique integer ID for this coupling within the vehicle.

    cylinderedConfigIndex   Active Cylindered config slot (0-based). Omit if N/A.

    mountNodeName           Node name of the coupling mount point in the nodeTree
                            (or directly in the vehicle i3d for conduit vehicles).
                            Arc detection nodes must exist as children named:
                                <mountNodeName>Arcs
                                    <mountNodeName>Arc01
                                    <mountNodeName>Arc02

    valveType
        MANUAL              Valve is opened by the player standing at the coupling
                            and using long press R. Standard for most tankers.
                            Player is shown: Disconnect | Open valve (hold R).

        HYDRAULIC           Valve is opened from the cab via SPS_TOGGLE_FLOW action.
                            Used for conduit pumps and hydraulically controlled trailers.
                            Player at the coupling is only offered disconnect — no valve
                            prompts appear. Pipe chains cannot be laid from this coupling.

        NONE                No valve. Flow begins immediately when connected and the
                            pump is running. Use with valveFromRearControl="true".

    maxPipeLength           Maximum distance in metres for a bez pipe or chain terminus
                            to connect to this coupling. Typical: 4.0–8.0.

    fillUnitIndex           Vehicle fill unit index. Default: 1.
                            Not applicable for conduit vehicles — omit or leave at default.

    valveFromRearControl    true = valve state is controlled by the rear pumpControl
                            activatable rather than manually at the coupling.
                            Pair with valveType="NONE" for self-powered trailers.

    connector               Physical connector shape shown on the vehicle end of the
                            bez pipe. Default: "male".
                            Use "female" for tankers whose coupling socket is a female
                            receiver rather than a male spigot.
                            Chain pipe segments always use male at the start and female
                            at the end regardless of this attribute — it only applies
                            to the bez pipe connecting the tanker to the chain or store.

    ── <rubberBootPorts> ─────────────────────────────────────────────────────

    <rubberBootPorts>
        <rubberBootPort
            id="N"
            lowerNodeName="..."
            upperNodeName="..."
            valveType="MANUAL|HYDRAULIC|NONE"
            fillUnitIndex="N"
        />
    </rubberBootPorts>

    id              Unique integer ID for this port.

    lowerNodeName   Lower boundary node of the rubber boot docking zone.
    upperNodeName   Upper boundary node of the rubber boot docking zone.
                    A fill arm tip must fall between the Y positions of these
                    two nodes, and within XZ proximity, for docking to register.

    valveType       Controls how the port valve is opened.
                    NONE = port is always open when an arm is docked.

    fillUnitIndex   Vehicle fill unit index. Default: 1.

    ── <pumpControls> ────────────────────────────────────────────────────────

    <pumpControls>
        <pumpControl
            id="N"
            nodeName="..."
            radius="N.N"
        />
    </pumpControls>

    id          Unique integer ID.
    nodeName    Node name in the vehicle hierarchy where the walkaround pump
                control activatable appears. The player must be within radius
                of this node to see the pump/valve/direction controls.
    radius      Activation radius in metres. Default: 1.5.

    Leave <pumpControls/> self-closing for vehicles that use in-cab controls only.

    ======================================================================== -->


    <!-- ========================================================================
         PLACEABLE fillPoints.xml — ELEMENT REFERENCE
    =========================================================================

    Placeable fillPoints.xml files live in configs/placeableConfigs/<n>/
    and are matched against loaded placeables by folder name.

    ── <nodeTree> ────────────────────────────────────────────────────────────

    <nodeTree filename="nodeTree.i3d"/>

    Same as vehicle nodeTree. Contains the fill plane centre/edge/corner nodes,
    hide nodes, hide collision nodes, and placeable coupler mount nodes.

    ── <fillPlane> ───────────────────────────────────────────────────────────

    <fillPlane
        shape="round|rectangle"
        centreNodeName="..."
        edgeNodeName="..."
        corner1NodeName="..."
        corner2NodeName="..."
    />

    shape="round"           Circular detection zone.
                            Requires: centreNodeName, edgeNodeName.
                            centreNode = centre of the fill area.
                            edgeNode   = any point on the edge — defines radius.

    shape="rectangle"       Rectangular detection zone.
                            Requires: centreNodeName, corner1NodeName, corner2NodeName.
                            centreNode  = centre of the fill area.
                            corner1Node = one corner of the rectangle.
                            corner2Node = the diagonally opposite corner.

    The fill plane is used to determine whether a fill arm upper node is inside
    the store's fill volume, and to sample slurry surface height for lower node
    detection. Nodes must be placed at ground level of the fill area.

    ── <hideNodes> ───────────────────────────────────────────────────────────

    <hideNodes>
        <node name="..."/>
    </hideNodes>

    Lists nodes in the placeable i3d to hide when SPS is active on this placeable.
    Used to suppress vanilla drive-in trigger meshes that would clip with SPS geometry.

    ── <hideCollisions> ──────────────────────────────────────────────────────

    <hideCollisions>
        <node name="..."/>
    </hideCollisions>

    Lists collision nodes in the placeable i3d to disable when SPS is active.
    Used to remove vanilla drive-in ramp collisions that block SPS vehicle access.

    ── <storeCouplings> ──────────────────────────────────────────────────────

    <storeCouplings>
        <pipeCoupling
            id="N"
            mountNodeName="..."
            flowDirection="DISCHARGE|FILL|BOTH"
            deployable="bool"
            connector="male|female"
            animNodeName="..."
            animRX="N" animRY="N" animRZ="N"
        >
            <effects inletDistance="N.N">
                <effectNode ... />
            </effects>
        </pipeCoupling>
    </storeCouplings>

    id              Unique integer ID for this store coupling.

    mountNodeName   Node name in the nodeTree for the coupling mount point.
                    Arc nodes must exist as children:
                        <mountNodeName>Arcs
                            <mountNodeName>Arc01
                            <mountNodeName>Arc02

    flowDirection
        DISCHARGE   Only allows slurry to be pumped INTO this store.
                    Vehicles connecting to this coupling cannot pull slurry out.
        FILL        Only allows slurry to be pulled OUT of this store.
        BOTH        No restriction — flow in either direction is permitted.

    deployable      true = coupling is hidden by default and deployed by the
                    player via long press R at the placeable.
                    Useful for couplings that are only needed occasionally
                    (e.g. cow shed pipe coupler hidden on the building wall).

    connector       Physical connector shape shown on the store end of the bez pipe.
                    Default: "female".
                    Only override if the store has an unusual coupling type that
                    physically presents a male spigot rather than a female socket.

    animNodeName    Node to rotate when the coupling is deployed/undeployed.
    animRX/Y/Z      Euler rotation in degrees applied to animNode when deployed.

    <effects> (optional child)
        Declares the visual inlet effect for flow arriving at this store coupling.
        inletDistance   Stream length in metres from the pipe end to the store inlet.
        <effectNode> attributes are identical to the vehicle fillArm effects block.

    ======================================================================== -->

</slurryPipeSystemReference>