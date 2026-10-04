# RPG Services Architecture

## World Nodes

```text
World (Node2D)
├─ Actors
│  ├─ Tamer
│  └─ Partner
├─ MobileHUD
├─ WorldServiceController
└─ StoryPoints
   ├─ ArchiveNPC (Area2D / WorldServicePoint)
   │  ├─ CollisionShape2D
   │  ├─ Body
   │  ├─ Title
   │  └─ Prompt
   ├─ MerchantNPC (Area2D / WorldServicePoint)
   │  ├─ CollisionShape2D
   │  ├─ Body
   │  ├─ Title
   │  └─ Prompt
   └─ DigitalIncubator (Area2D / WorldServicePoint)
      ├─ CollisionShape2D
      ├─ Machine
      ├─ Title
      └─ Prompt
```

## Runtime UI

```text
WorldServiceController
├─ DigimonArchiveUI (CanvasLayer)
│  └─ Root
│     └─ Panel
│        ├─ Current Party (max 3)
│        └─ Storage Bank (unlimited)
├─ ShopUI (CanvasLayer)
│  └─ Root
│     └─ Panel
│        ├─ Buy
│        └─ Sell
└─ IncubatorUI (CanvasLayer)
   └─ Root
      └─ Panel
         ├─ Digitama list
         ├─ Inject status 0/5
         └─ Inject Data
```

## Rules

- Equipment inventory starts empty.
- Wearable equipment is not in ItemCatalog/ShopCatalog.
- Only World Boss nodes evaluate `boss_equipment_drops`.
- Party capacity is 3; Storage is unbounded and entries use unique `uid`.
- Bits live in GameManager and are serialized into the active character profile.
- Digitama stores a fixed `egg_partner_id`; hatch result never uses random species selection.
- Data injection consumes the configured Data Chip on every attempt.
- Incubator outcome can succeed, fail safely, or break the egg.
- World interactions support touch, left-click, and keyboard E.
