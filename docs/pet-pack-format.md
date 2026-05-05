# Pet Pack Format

Petty reads Codex-compatible pet packs created by tools such as `hatch-pet`.

## Location

Petty scans:

```text
~/.codex/pets/<pet-id>/
```

Each pet folder must include:

```text
pet.json
spritesheet.webp
```

## Manifest

Minimum `pet.json`:

```json
{
  "id": "clawd",
  "displayName": "Clawd",
  "description": "A compact Codex pet.",
  "spritesheetPath": "spritesheet.webp"
}
```

`creator` or `author` may be included for attribution.

## Spritesheet

The MVP expects the Codex pet atlas shape:

- `1536x1872` pixels
- `8x9` grid
- `192x208` pixel cells

Default row mapping:

| Row | State |
| --- | --- |
| 0 | `idle` |
| 1 | `running-right` |
| 2 | `running-left` |
| 3 | `waving` |
| 4 | `jumping` |
| 5 | `failed` |
| 6 | `waiting` |
| 7 | `running` |
| 8 | `review` |

Optional animation overrides can be placed under `animations` or `states`:

```json
{
  "animations": {
    "idle": { "row": 0, "frames": 6, "fps": 8 },
    "failed": { "row": 5, "frames": 8, "fps": 8 }
  }
}
```

## Petty State Mapping

- `idle` -> `idle`
- `thinking` -> `review`
- `success` -> `waving`
- `error` -> `failed`
- drag right -> `running-right`
- drag left -> `running-left`

## Safety

Petty reads only `pet.json` and `spritesheet.webp`. It does not run install commands, scripts, hooks, or other executable files from pet packs.
