local GH = GuildHunter
local M = {}
GH:RegisterModule("KOS", M)
function M:Initialize() end
function M:FindPlayer(guid, name)
  if guid then
    for _,record in pairs(GH.db.kos) do
      if record.guid==guid then return record end
    end
  end
  if name then
    for _,record in pairs(GH.db.kos) do
      if (not guid or not record.guid) and GH:Normalize(record.name)==GH:Normalize(name) then
        return record
      end
    end
  end
end
function M:FindGuild(name)
  if not name then return end
  for _, record in pairs(GH.db.guilds) do
    if GH:Normalize(record.name) == GH:Normalize(name) then return record end
  end
end
local function newRecord(kind, record, fields)
  local old = kind == "K" and GH.db.kos or GH.db.guilds
  local existing = old[record.id]
  if existing and (existing.revision or 0) >= (record.revision or 0) then return false end
  local tomb = GH.db.tombstones[record.id]
  if tomb and (type(tomb)=="number" and tomb or tomb.revision or 0) >= (record.revision or 0) then return false end
  old[record.id] = record
  GH:Refresh()
  return true
end
function M:Write(kind, record)
  if not GH:InGuild() then GH:Print("Only available in irønclad") return false end
  record.revision = GH.Database:Revision()
  record.updatedBy = GH:PlayerName()
  newRecord(kind, record)
  GH.Sync:Publish({type="RECORD",kind=kind,record=record})
  return true
end
function M:AddPlayer(name, guid, guild, reason, class, level, faction)
  if not GH:Normalize(name) or GH:Normalize(name)=="" then return nil end
  local record = self:FindPlayer(guid, name) or {
    id=GH:ID("player"), created=GH:Now(), addedBy=GH:PlayerName()
  }
  record.name = name
  record.guid = guid or record.guid
  record.guild = guild or record.guild
  record.reason = reason or record.reason or ""
  record.class = class or record.class
  record.level = level or record.level
  record.faction = faction or record.faction
  self:Write("K",record)
  return record
end
function M:AddGuild(name, reason)
  if not GH:Normalize(name) or GH:Normalize(name)=="" then return nil end
  local record = self:FindGuild(name) or {
    id=GH:ID("guild"),created=GH:Now(),addedBy=GH:PlayerName(),members={}
  }
  record.name=name
  record.reason=reason or record.reason or ""
  self:Write("G",record)
  return record
end
function M:Update(kind,id,reason)
  local record=(kind=="G" and GH.db.guilds or GH.db.kos)[id]
  if record then record.reason=reason;return self:Write(kind,record) end
end
function M:Remove(kind,id)
  local records=kind=="G" and GH.db.guilds or GH.db.kos
  if not records[id] then return false end
  local tomb={id=id,kind=kind,revision=GH.Database:Revision(),updatedBy=GH:PlayerName()}
  GH.db.tombstones[id]=tomb
  records[id]=nil
  GH.Sync:Publish({type="RECORD",kind="D",record=tomb})
  GH:Refresh()
  return true
end
function M:Accept(kind,record,sender)
  if type(record)~="table" or type(record.id)~="string" or type(record.revision)~="number" then return false end
  if kind=="D" then
    local old=GH.db.tombstones[record.id]
    if not old or old.revision < record.revision then
      GH.db.tombstones[record.id]=record
      GH.db.kos[record.id]=nil
      GH.db.guilds[record.id]=nil
      GH:Refresh()
    end
    return true
  end
  if kind~="K" and kind~="G" then return false end
  if type(record.name)~="string" or #record.name>120 then return false end
  return newRecord(kind,record)
end
function M:AddTarget()
  if not UnitExists("target") or not UnitIsPlayer("target") or not UnitCanAttack("player","target") then
    GH:Print("Select an enemy player first") return
  end
  local name=GH:UnitName("target")
  if not name then GH:Print("Target name is restricted") return end
  local guid=GH:Safe(UnitGUID("target"))
  local guild=GH:Safe(GetGuildInfo("target"))
  local class=select(2,UnitClass("target"))
  self:AddPlayer(name,guid,guild,"",GH:Safe(class),GH:Safe(UnitLevel("target")),GH:Safe(UnitFactionGroup("target")))
end
function M:AddTargetGuild()
  if not UnitExists("target") or not UnitIsPlayer("target") then GH:Print("Select a player") return end
  local guild=GH:Safe(GetGuildInfo("target"))
  if type(guild)~="string" or guild=="" then GH:Print("No enemy guild available") return end
  self:AddGuild(guild,"")
end
