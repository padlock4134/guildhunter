# GuildHunter — irønclad

A World of Warcraft: Forever addon. Interface version: 16001.

## Install

Copy the GuildHunter folder into:
`World of Warcraft/_forever_/Interface/AddOns/GuildHunter/`

Restart the game, then type `/gh`.

## Commands

`/gh` opens KoS; `/gh kos`, `/gh guilds`, `/gh lottery`,
`/gh tracker`, `/gh add`, `/gh sync`, `/gh settings`, `/gh help`.

## Current implementation status

This is an **initial, incomplete development build**, not a verified v1 release.
The addon manifest and Lua modules are implemented, but the Forever client
has not been available to run actual in-game tests.

Important remaining work:
- Confirm 16001 client compatibility, event and messaging signatures.
- Finish secure guild synchronization of all round state, audit and payout records.
- Implement verifiable Horde killing blows and faction recognition before granting any bonus tickets.
- Add scrollable lists, record editing, expanded officer controls, manual ticket number selection.
- Verify end-to-end drawing, replay resistance, and two-client reconciliation in game.

The in-game payment and payout mechanism is ordinary manual gold trading.
No audio is bundled. To enable ticket audio later, add
`Sounds/TicketEarned.ogg` and restart the client.
