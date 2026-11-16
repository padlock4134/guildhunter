local GH=GuildHunter
local M={recent={},unresolved={}}
GH:RegisterModule("KillTracker",M)

function M:Initialize()
 self.petGUID=UnitGUID and UnitGUID("pet") or nil
end

local function combatFields(...)
 local args={...}
 if CombatLogGetCurrentEventInfo then
  local event={CombatLogGetCurrentEventInfo()}
  if #event>0 then args=event end
 end
 local subevent=args[2]
 if subevent~="PARTY_KILL" then return end
 local modern=type(args[3])=="boolean"
 local src=modern and args[4] or args[3]
 local dst=modern and args[8] or args[6]
 local dstName=modern and args[9] or args[7]
 return src,dst,dstName
end

function M:HandleEvent(event,...)
 if event=="UNIT_PET" then
  if ...=="player" then self.petGUID=UnitGUID and UnitGUID("pet") end
  return
 end
 if event~="COMBAT_LOG_EVENT_UNFILTERED" then return end
 local sourceGUID,victimGUID,victimName=combatFields(...)
 if not sourceGUID or not victimGUID then return end
 local myGUID=UnitGUID and UnitGUID("player")
 if sourceGUID~=myGUID and sourceGUID~=self.petGUID then return end

 local round=GH.Lottery.current
 if not round or round.state~="open" or not round.payments[GH:SelfName()] then return end

 local seen=GH.db.seen[victimGUID]
 if not seen or seen.faction~="Horde" then
  local item={time=GH:Now(),name=victimName,guid=victimGUID,reason="Horde player faction not verified"}
  self.unresolved[#self.unresolved+1]=item
  if #self.unresolved>200 then table.remove(self.unresolved,1) end
  return
 end

 local now=GH:Now()
 local key=round.id..":"..victimGUID
 if self.recent[key] and now-self.recent[key]<10 then return end
 self.recent[key]=now
 GH.Lottery:RecordKill(GH:SelfName(),key..":"..now)
end
