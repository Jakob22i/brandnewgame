# Build contracts

The game scripts (`src/`) find things in the models built by `build/` by name. Keep these
contracts when changing any builder.

## Ship templates (`build/builders/Ships.luau` → `ServerStorage.Ships.<Sloop|Brigantine|Galleon>`)

Ship space: origin = waterline centre, bow towards **-Z**, starboard **+X**, up **+Y**.
`Config.Ships[id].Length/Width/Draft` must match the hull (used for docking and collisions).

| Name / class | Where | Used for |
| --- | --- | --- |
| `Root` (Part, PrimaryPart) | model | Invisible, anchored in the template, everything else is welded to it with classic `Weld`s (`P.weld`) |
| `HelmPost` (BasePart) + `HelmPrompt` (ProximityPrompt) | quarterdeck | Taking the helm |
| `WheelHub` (Part) with `WheelWeld` (Weld, Part0 = HelmPost) | wheel | Server spins `WheelWeld.C0` around Z |
| `HelmPoint` (Attachment on Root) | floor behind the wheel, facing -Z | Helmsman is locked here |
| `Sail` parts with `SailWeld` (Weld, Part0 = yard) | masts | Furl/unfurl. Attributes: `FullHeight`, `Gap` (yard→sail top), `ZOffset`, optional `XOffset`, optional `SailYaw` (radians). Server sets `Size.Y = h` and `SailWeld.C0 = CFrame.new(XOffset, -(Gap + h/2), ZOffset) * CFrame.Angles(0, SailYaw, 0)` where h goes 1.4 → FullHeight. Server recolours every `Sail` part (default black). |
| `SailEmblem` parts (same rules as `Sail`) | in front of the biggest sails | Thin transparent part; the server puts the player's symbol on it as SurfaceGuis (Front and Back) |
| `MastBase` with `SailPrompt` | each mast | Raise/lower sails |
| `Capstan` with `AnchorPrompt` | bow deck | Anchor |
| `AnchorRoot` with `AnchorWeld` (Weld) | bow | Anchor visual (moved 9 studs down when anchored) |
| `Cannons` folder → `Cannon` models | deck sides | `Carriage` (BasePart) with `CannonPrompt` + `OperatorPoint` attachment; `Pivot` (Part) with `AimWeld` (Weld, Part0 = Carriage, unrotated relative to Carriage) and attribute `MuzzleOffset`; barrel parts welded to Pivot; barrel points along Pivot -Z |
| `HoleSpot` attachments on Root | deck surface | Cannon damage holes |
| `CrewSpawn` attachment on Root | deck | Respawn point |
| `BowSpray`, `SternWake` attachments on Root with a `Wake` ParticleEmitter | waterline | Client sets Rate from speed |
| `NameTag` BillboardGui on Root with a `Label` TextLabel | above masts | Ship name |
| `Cargo`, `Holes` folders | model | Treasure on deck, hull holes |
| `Ladder` TrussParts | both sides | Climbing aboard |

Parts below the waterline (y < -0.3) should be `CanCollide = false`.

## Shops (`WorldData.Shops`)

Each shop has a position, `Yaw` (front = local +Z rotated by Yaw), `Width`, `Depth`, and a
computed `FrontX/FrontZ` where the path should arrive. The town builder must create for each shop:

- an NPC model tagged `ShopNPC` with attribute `ShopId`, anchored `HumanoidRootPart` holding a
  ProximityPrompt named `ShopPrompt` (the server connects it; the client then opens a dialogue)
- for the Merchant: a part tagged `SellCounter` with a ProximityPrompt `SellPrompt`

## Lune gotchas (the build runs in Lune, not Roblox)

- `Instance.new("Part")` defaults to studded surfaces: always create parts with `P.part`.
- No `PivotTo`/`GetPivot`/`GetBoundingBox`: build in local space, then `P.transform(model, cf)`.
- `part.Position` is not readable: use `part.CFrame.Position`.
- `CFrame.lookAt` is wrong for tilted directions: use `P.lookAt`.
- Text: set `FontFace` (`P.RYE`, or `Font.fromEnum(...)`), never `.Font`.
- No `Random`: use `Noise.Rng(seed)`.
