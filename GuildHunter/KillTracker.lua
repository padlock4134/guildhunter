local GH=GuildHunter
local M={lastKey=nil,lastAt=0,unresolved={}}
GH:RegisterModule("KillTracker",M)
function M:Initialize() end
function M:HandleEvent(event,...)
 if event~="PARTY_KILL" then return end
 local victim=...
 local name=type(victim)=="string" and victim or (type(victim)=="table" and victim.name)
 local unit="target"
 local guid=UnitExists(unit) and UnitName(unit)==name and UnitGUID(unit) or nil
 local faction=UnitExists(unit) and UnitName(unit)==name and UnitFactionGroup(unit) or nil
 -- PARTY_KILL alone does not prove the local player landed the killing blow.
 -- Preserve unresolved events for review instead of awarding unverified tickets.
 local id=tostring(GH:Now())..":"..tostring(guid or name or "unknown")
 if self.lastKey==id then return end
 self.lastKey=id
 self.unresolved[#self.unresolved+1]={time=GH:Now(),name=name,guid=guid,faction=faction,
  reason="Killing blow not verified by PARTY_KILL"}
 if #self.unresolved>200 then table.remove(self.unresolved,1) end
end
