local GH=GuildHunter
local M={lastAlerts={}}
GH:RegisterModule("Detection",M)
function M:Initialize() end
function M:InspectUnit(unit)
 if not UnitExists(unit) or not UnitIsPlayer(unit) or not UnitCanAttack("player",unit) then return end
 local name=UnitName(unit)
 local guid=UnitGUID and UnitGUID(unit)
 local guild=GetGuildInfo and GetGuildInfo(unit)
 local _,class=UnitClass(unit)
 local player=GH.KOS:FindPlayer(guid,name)
 local enemyGuild=GH.KOS:FindGuild(guild)
 local key=guid or name
 GH.db.seen[key]={name=name,guid=guid,guild=guild,class=class,level=UnitLevel(unit),faction=UnitFactionGroup(unit),
  lastSeen=GH:Now(),kos=player and true or false,guildKos=enemyGuild and true or false}
 if (player or enemyGuild) and ((not self.lastAlerts[key]) or (GH:Now()-self.lastAlerts[key]>30)) then
   local allowed=(player and GH.db.settings.kosAlerts) or (enemyGuild and GH.db.settings.guildAlerts)
   if allowed then
     self.lastAlerts[key]=GH:Now()
     GH:Print((player and "KoS detected: " or "Enemy guild: ")..name)
     if GH.db.settings.audioAlerts and PlaySound then PlaySound("RaidWarning") end
   end
 end
 GH:Emit("RefreshTracker")
end
function M:HandleEvent(event,...)
 if event=="PLAYER_TARGET_CHANGED" then self:InspectUnit("target") end
 if event=="UPDATE_MOUSEOVER_UNIT" then self:InspectUnit("mouseover") end
 -- Additional detection is limited to inspectable unit tokens; no combat automation.
end
