# GuildHunter — irønclad

**Version:** 1.0.0 · **Game:** World of Warcraft: Forever · **Interface:** 16001

GuildHunter is an in-game addon for **irønclad**: a shared PvP kill-on-sight tracker and a weekly 5-gold lottery. No websites, external accounts, background services, or third-party addon libraries are required.

## Installation

1. Extract `GuildHunter-v1.0.0.zip` so the folder is named **GuildHunter**.
2. Put that folder inside your active Forever client AddOns directory:
   `World of Warcraft/_forever_/Interface/AddOns/GuildHunter/`
3. If your launcher uses `_classic_beta_` instead of `_forever_`, install it under that client's `Interface/AddOns` directory.
4. Restart WoW. Type `/gh` to open the main window, or `/gh lottery` for the lottery.
5. All participants who want guild data synchronization need the addon installed.

The final audio asset is **not** bundled. After everything else is installed, put your own `TicketEarned.ogg` into `GuildHunter/Sounds/` and **restart** WoW; no Lua edits are required. The sound plays on the Master channel for each newly received ticket, one time per ticket ID. You can disable it in Settings.

## PvP Intelligence

- `/gh kos` opens the player KoS list. Manually enter the **entire name (including surname)**, or target an enemy and click **Add Target**. Select a record to edit its reason or remove it.
- `/gh guilds` opens watched enemy guilds. Manually add a guild or use **Target Guild**. Names, reasons, reporting members, timestamps and known members are saved.
- `/gh tracker` shows/hides the on-screen detected-enemies tracker. Drag the window, use its lock/minimize controls, or resize it using the bottom-right grip. The tracker shows names, levels, guilds, last-seen ages and KoS priority colors.
- Enemy sightings come from **target**, **mouseover**, **focus** and supported **nameplate** events; there is no prohibited radar scan or automatic combat action.
- KoS records and removals sync through the WoW guild addon channel; reconnecting players can request records with `/gh sync`. Updated records and deletion tombstones prevent stale entries returning.
- Alert and audio settings persist via SavedVariables. Repeated sightings are throttled.

## Weekly 5g Lottery

### Members

1. Open `/gh lottery` > **My Lottery**.
2. Choose three **distinct** numbers from 1 to 10, or press **Quick Pick**.
3. Press **Request 5g Entry**, then trade **5 gold** normally to an officer.
4. The officer confirms the trade in GuildHunter. One paid ticket is created for that character.
5. Earn one additional ticket at each **confirmed Horde killing-blow** total of **5, 15, 30, 50, 75, 100**. Milestones are cumulative and are awarded only once. Bonus tickets use Quick Pick and add **no gold** to the jackpot.
6. Select an existing ticket and edit its three numbers while entries are open. Saving numbers does not create another ticket.
7. Check your progress, jackpot, tickets, drawing numbers and history in the UI.

**Kill qualification:** The addon reads the permitted Forever `PARTY_KILL(attackerGUID,targetGUID)` event and only counts a blow attributed to your character or your current pet, **when the victim has previously been seen and verified as a Horde player**. Unknown/restricted identities go into a local unresolved-kills list instead of generating unearned tickets. It does not count NPCs, general assists or another party member's killing blow. While offline, officers cannot independently verify the underlying gameplay; guild members' addons submit claims from their local client and the officer ledger deduplicates and records them. Addons cannot enforce tamper-proof competitive payouts.

### Officers

Use `/gh lottery` > **Officer Desk** (rank index 0–1 by default).

- **Start Weekly Round:** set the hours until drawing (default 168 hours / 7 days).
- **Payment confirmation:** select a pending entry or type a guild member's full name. Confirm **only after** receiving the 5g trade. Each player can buy one paid entry in that round.
- **Schedule:** set hours until drawing and how many minutes before it to close entries. Times display in **UTC derived from server timestamps**.
- **Milestones:** edit comma-separated thresholds before any bonus tickets are awarded. Thresholds are locked after an award.
- **Corrections:** enter a member, the corrected kill count, and an audit reason. Awards newly met milestones once; never silently revokes an issued ticket.
- **Draw:** close entries, wait for the scheduled draw time and click **Draw**. The addon picks three unique winning numbers from 1–10, order-independent. All tickets matching all three numbers win. Multiple winning tickets split the jackpot equally; an indivisible copper remainder rolls over.
- **Payout:** trade gold manually, mark each prize paid, and complete the round. If no ticket wins, the full jackpot rolls into the next week. Completed drawings cannot be rerolled.
- **History:** review rounds, results, payouts, rollover, and recent audit entries.

All monetary totals are internally tracked in **copper**; the UI displays **gold**.

## Commands

| Command | Action |
|:--|:--|
| `/gh` or `/guildhunter` | Main KoS interface |
| `/gh kos` | Player KoS records |
| `/gh guilds` | Enemy guild KoS records |
| `/gh tracker` | Show/hide PvP tracker |
| `/gh lottery` | Lottery dashboard |
| `/gh add` | Add targeted enemy player |
| `/gh sync` | Request latest guild data |
| `/gh settings` | Settings |
| `/gh help` | Command reference |

## Saved data and sync

- `GuildHunterDB` stores records, UI locations, settings, ledger state, history, kill claims, and processed sound tickets.
- Guild addon messages use a namespaced prefix, a length-prefixed non-executable serializer, chunked/throttled delivery and roster-based sender verification.
- KoS records are shared among guild members. Lottery ledger writes are accepted only from members holding an officer rank. Member entry/edit/kill requests must identify their own sender.
- Rejoiners request snapshots. Queued outbound messages and unacknowledged kill claims survive UI reloads.
- By design, this is a social guild lottery. WoW APIs do **not** permit an addon to take 5g automatically, independently prove a user's gold trade or guarantee the client running a PvP-kill claim has not been modified. Officers must confirm money and reconcile disputes.

## Tests and validation

`tests/test.lua` contains the internal, **non-production** headless test harness. It stubs WoW functions and validates 62 assertions covering addon startup, SavedVariables, KoS, officer permissions, sound handling, tickets, 5/15/30/100 milestones, kill deduplication, valid numbers, payment deduplication, jackpot splits, rollover, drawing finality, serialization, stale/unauthorized sync messages and packet reassembly.

To run with Lua available: `lua tests/test.lua` from inside the `GuildHunter/` folder. No simulated kills or tickets are written into the game ledger by the test harness.

**Validation boundary:** Syntax and headless workflow checks have passed. This build **has not been executed in an actual WoW Forever client or tested between two live guild members** here. Confirm the game's changing 16001 API, restricted combat state, player surnames, guild messaging and optional sound file in game before using a jackpot involving real in-game gold.
