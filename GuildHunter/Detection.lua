local GH=GuildHunter
local M={lastAlerts={}}
GH:RegisterModule("Detection",M)
function M:Initialize()
  GH:RegisterEvent("PLAYER_TARGET_CHANGED")
  GH:RegisterEvent("UPDATE_MOUSEOVER_UNIT")
  GH:RegisterEvent("NAME_PLATE_UNIT_ADDED")
  GH:RegisterEvent("PLAYER_FOCUS_CHANGED")
end
function M:Inspect(unit)
  if not unit or not UnitExists(unit) then return end
  local ok, isPlayer, enemy=pcall(function()
    return UnitIsPlayer(unit), UnitCanAttack("player",unit)
  end)
  if not ok or not GH:Safe(isPlayer) or not GH:Safe(enemy) then return end
  local name=GH:UnitName(unit)
  local guid=GH:Safe(UnitGUID(unit))
  if not name and not guid then return end
  local guild=GH:Safe(GetGuildInfo(unit))
  local _,class=UnitClass(unit)
  local level=GH:Safe(UnitLevel(unit))
  local faction=GH:Safe(UnitFactionGroup(unit))
  local kos=GH.KOS:FindPlayer(guid,name)
  local watch=GH.KOS:FindGuild(guild)
  local key=guid or name
  if not key then return end
  local record=GH.db.seen[key] or {}
  record.name=name or record.name
  record.guid=guid or record.guid
  record.guild=guild or record.guild
  record.class=GH:Safe(class) or record.class
  record.level=level or record.level
  record.faction=faction or record.faction
  record.lastSeen=GH:Now()
  record.kos=(kos~=nil)
  record.guildKos=(watch~=nil)
  GH.db.seen[key]=record
  if watch and name then
    watch.members=watch.members or {}
    if not watch.members[name] then
      watch.members[name]=GH:Now()
      GH.KOS:Write("G",watch)
    end
  end
  local alert=(kos and GH.db.settings.kosAlerts) or (watch and GH.db.settings.guildAlerts)
  if alert and (GH:Now()-(self.lastAlerts[key] or 0)) >= 30 then
    self.lastAlerts[key]=GH:Now()
    GH:Print((kos and "KoS spotted: " or "Enemy guild spotted: ")..(name or "unknown"))
    if GH.db.settings.audioAlerts and PlaySound then
      pcall(PlaySound, SOUNDKIT and SOUNDKIT.RAID_WARNING or 8959, "Master")
    end
  end
  GH:Fire("RefreshTracker")
end
function M:OnEvent(event,unit)
  if event=="PLAYER_TARGET_CHANGED" then self:Inspect("target")
  elseif event=="UPDATE_MOUSEOVER_UNIT" then self:Inspect("mouseover")
  elseif event=="PLAYER_FOCUS_CHANGED" then self:Inspect("focus")
  elseif event=="NAME_PLATE_UNIT_ADDED" then self:Inspect(unit) end
end
