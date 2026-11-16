local GH = GuildHunter
local M = {}
GH:RegisterModule("Database", M)
local currentVersion = 2
local function merge(out, template)
  for k, value in pairs(template) do
    if out[k] == nil then
      if type(value) == "table" then
        out[k] = {}
        merge(out[k], value)
      else out[k] = value end
    elseif type(value) == "table" and type(out[k]) == "table" then
      merge(out[k], value)
    end
  end
end
function M:Initialize()
  if type(GuildHunterDB) ~= "table" then GuildHunterDB = {} end
  local db = GuildHunterDB
  merge(db, {
    version = currentVersion,
    kos = {}, guilds = {}, tombstones = {}, seen = {},
    settings = {trackerVisible = true, kosAlerts = true, guildAlerts = true,
                audioAlerts = true, ticketSound = true},
    tracker = {x = 210, y = 30, width = 285, height = 310,
               point = "CENTER", locked = false, minimized = false},
    windows = {mainX=0,mainY=0,lotteryX=0,lotteryY=0},
    lottery = {rounds = {}, currentId = nil, audit = {}, entryRequests = {},
               pendingKills = {}, unresolvedKills = {}, paidReceiptCount = 0},
    audioPlayed = {}, outbox = {}, officerRankMax = 1,
    counter = 0, idCounter = 0
  })
  if (db.version or 0) > currentVersion then
    GH:Print("Newer saved data version; no automatic downgrade")
  else
    db.version = currentVersion
  end
  GH.db = db
  for id,record in pairs(db.tombstones) do
    if type(record)=="number" then
      db.tombstones[id]={id=id,kind="D",revision=record,updatedBy="legacy"}
    end
  end
  db.lottery.rounds = db.lottery.rounds or {}
  db.lottery.audit = db.lottery.audit or {}
end
function M:Revision()
  GH.db.counter = (GH.db.counter or 0) + 1
  -- Monotonically increasing on one client; deterministic ties across clients.
  return GH:Now() * 100000 + (GH.db.counter % 100000)
end
function M:Audit(action, detail, who)
  local log = GH.db.lottery.audit
  log[#log+1] = {at=GH:Now(),action=action,detail=tostring(detail or ""),by=who or GH:PlayerName()}
  while #log > 400 do table.remove(log, 1) end
end
