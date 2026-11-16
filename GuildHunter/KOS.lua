local GH = GuildHunter
local M = {}
GH:RegisterModule("KOS", M)
function M:Initialize()
  for _,pair in ipairs({{"kos","player:"},{"guilds","guild:"}}) do
    local merged={}
    for id,r in pairs(GH.db[pair[1]]) do
      if type(r)=="table" and type(r.name)=="string" then
        local key=pair[2]..GH:Normalize(r.name)
        r.legacyIds=r.legacyIds or {};r.legacyIds[id]=true
        local old=merged[key]
        if not old or (r.revision or 0)>(old.revision or 0) or
          (r.revision==old.revision and (r.updatedBy or "")>(old.updatedBy or "")) then
          if old then for alias in pairs(old.legacyIds) do r.legacyIds[alias]=true end end
          r.id=key;merged[key]=r
        else for alias in pairs(r.legacyIds) do old.legacyIds[alias]=true end end
      end
    end
    GH.db[pair[1]]=merged
  end
end
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
local function newer(a,b)
  if not b then return true end
  if a.revision~=b.revision then return a.revision>b.revision end
  return (a.updatedBy or "")>(b.updatedBy or "")
end
local function newRecord(kind, record)
  local old = kind == "K" and GH.db.kos or GH.db.guilds
  local existing = old[record.id]
  if kind=="G" and existing and type(record.members)=="table" then
    existing.members=existing.members or {}
    for name,at in pairs(record.members) do existing.members[name]=math.max(existing.members[name] or 0,at) end
  end
  if existing~=record and existing and not newer(record,existing) then GH:Refresh();return false end
  local tomb = GH.db.tombstones[record.id]
  for alias in pairs(record.legacyIds or {}) do
    local candidate=GH.db.tombstones[alias]
    if candidate and (not tomb or newer(candidate,tomb)) then tomb=candidate end
  end
  if tomb and not newer(record,tomb) then return false end
  if kind=="G" and existing and existing.members then
    record.members=record.members or {}
    for name,at in pairs(existing.members) do record.members[name]=math.max(record.members[name] or 0,at) end
  end
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
  if not GH:InGuild() then return false end
  if not GH:Normalize(name) or GH:Normalize(name)=="" then return nil end
  local record = self:FindPlayer(guid, name) or {
    id="player:"..GH:Normalize(name), created=GH:Now(), addedBy=GH:PlayerName()
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
  if not GH:InGuild() then return false end
  if not GH:Normalize(name) or GH:Normalize(name)=="" then return nil end
  local record = self:FindGuild(name) or {
    id="guild:"..GH:Normalize(name),created=GH:Now(),addedBy=GH:PlayerName(),members={}
  }
  record.name=name
  record.reason=reason or record.reason or ""
  self:Write("G",record)
  return record
end
function M:Update(kind,id,reason)
  if not GH:InGuild() then return false end
  local record=(kind=="G" and GH.db.guilds or GH.db.kos)[id]
  if record then record.reason=reason;return self:Write(kind,record) end
end
function M:Remove(kind,id)
  if not GH:InGuild() then return false end
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
  if type(record)~="table" or type(record.id)~="string" or type(record.revision)~="number" or record.revision~=record.revision or record.revision==math.huge or record.revision<0 or type(record.updatedBy)~="string" then return false end
  GH.db.counter=math.max(GH.db.counter or 0,record.revision)
  if kind=="D" then
    local old=GH.db.tombstones[record.id]
    local live=GH.db.kos[record.id] or GH.db.guilds[record.id]
    if not live then
      for _,records in ipairs({GH.db.kos,GH.db.guilds}) do
        for _,r in pairs(records) do if r.legacyIds and r.legacyIds[record.id] then live=r;break end end
      end
    end
    if newer(record,old) and (not live or newer(record,live)) then
      GH.db.tombstones[record.id]=record
      GH.db.kos[record.id]=nil
      GH.db.guilds[record.id]=nil
      if live then GH.db.kos[live.id]=nil;GH.db.guilds[live.id]=nil;GH.db.tombstones[live.id]=record end
      GH:Refresh()
    end
    return true
  end
  if kind~="K" and kind~="G" then return false end
  if type(record.name)~="string" or #record.name>120 or record.name=="" then return false end
  for _,key in ipairs({"reason","guild","class","faction","guid","addedBy","updatedBy"}) do
    if record[key]~=nil and (type(record[key])~="string" or #record[key]>512) then return false end
  end
  if record.legacyIds~=nil then
    if type(record.legacyIds)~="table" then return false end
    for key,value in pairs(record.legacyIds) do if type(key)~="string" or value~=true then return false end end
  end
  if record.level~=nil and type(record.level)~="number" then return false end
  if record.members~=nil then
    if type(record.members)~="table" then return false end
    for n,t in pairs(record.members) do if type(n)~="string" or type(t)~="number" then return false end end
  end
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
