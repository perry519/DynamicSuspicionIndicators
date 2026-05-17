# Dynamic Suspicion Indicators

PAYDAY 2 SuperBLT mod for stealth detection indicators.

## Features

- Filling icons for NPC and camera detection progress with optional percentage text.
- Indicators on things being investigated: players, bodies, hostages, bags, drills, and other map objects.
- Icon styles: Vanilla, Vanilla HUD Plus, Extra.
- Custom indicators colors.
- Casing-mode early suspicion indicators while unmasked.
- Multiplayer sync when host and clients use the mod.

## Install

1. Install SuperBLT.
2. Put this folder in `PAYDAY 2/mods/`.
3. Start the game.
4. Configure it in `Options` -> `Mod Options` -> `Dynamic Suspicion Indicators`.

### Multiplayer

Detection sync sends live detection values from the host to clients.

For best experience, both host and clients should have this mod installed and `Detection sync` enabled.

Without host sync, clients cannot see real per-guard values. If several guards are detecting the client player, the client uses the highest known value for all of them.

Example: guards at 10%, 30%, and 80% will all show 80% on the non-synced client.

Without host sync:

- Target indicators only work for other players.
- Casing-mode early suspicion does not work.

## License

MIT for code and original assets. PAYDAY 2 / third-party assets belong to their owners.
