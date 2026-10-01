# JM Road Encounters

Native-search foundation for **JM Road Encounters**, targeting **Skyrim Special Edition 1.5.97**.

## Architecture

The SKSE DLL is intentionally narrow.

It does:
- enumerate Skyrim's existing high-process actors;
- reject invalid/dead/unloaded/out-of-space actors;
- radius-filter them;
- sort nearest-first;
- return a capped Actor array to Papyrus.

It does **not**:
- classify PLRP or Hydra roles;
- select encounter content;
- change AI;
- spawn or teleport actors;
- run a background thread;
- poll every frame.

All encounter classification, cadence, cooldowns, probability, and consequences remain in `JM_RE_Core.psc`.

## Native Papyrus API

```papyrus
Bool Function IsAvailable() Global Native
Actor[] Function GetNearbyActors(ObjectReference akCenter, Float afRadius = 3500.0, Int aiMaxResults = 32) Global Native
```

Script class: `JM_RE_Native`.

## Detection cadence

The Papyrus core is designed around:
- 0-8 game hours since a successful encounter: no actor scan;
- 8-24h: one native scan every 12 real seconds, 10% opportunity chance;
- 24-48h: every 10 seconds, 25%;
- 48-60h: every 7 seconds, 50%;
- 60h+: every 5 seconds, 100% on the first valid encounter opportunity.

A failed probability roll applies the existing per-category retry gate, set to 1 game hour in the native-search build.

## Build

GitHub Actions builds `JM_RoadEncounters.dll` with:
- CommonLibSSE-NG v3.7.0;
- MSVC / Windows Server 2022;
- SE-only CommonLib configuration;
- an explicit runtime guard for Skyrim SE 1.5.97.

The workflow artifact is named:

`JM-Road-Encounters-SE-1.5.97`

Deploy the DLL to:

`Data/SKSE/Plugins/JM_RoadEncounters.dll`

Compile and deploy `JM_RE_Native.psc` and the matching `JM_RE_Core.psc`.

## Existing saves

The old Hello/idle dialogue path is retired. Its plugin records may remain inert for save safety, but acquisition no longer depends on dialogue arbitration.

The updated core uses a new scanner state so a save upgraded from the failed Hello build can migrate into native scanning without relying on the old director state.
