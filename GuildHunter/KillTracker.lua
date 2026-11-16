local GH=GuildHunter
local M={recent={}}
GH:RegisterModule("KillTracker",M)
function M:Initialize()
  GH:RegisterEvent("PARTY_KILL")
  GH:RegisterEvent("UNIT_PET")
  self.pet=GH:Safe(UnitGUID("pet"))
end
local function unresolved(why,guid)
  local log=GH.db.lottery.unresolvedKills
  log[#log+1]={at=GH:Now(),reason=why,guid=guid}
  while #log>150 do table.remove(log,1) end
end
function M:OnEvent(event,attacker,victim)
  if event=="UNIT_PET" then
    if attacker=="player" then self.pet=GH:Safe(UnitGUID("pet")) end
    return
  end
  if event~="PARTY_KILL" or not GH:InGuild() then return end
  attacker=GH:Safe(attacker)
  victim=GH:Safe(victim)
  if type(attacker)~="string" or type(victim)~="string" then
    unresolved("Restricted kill identity",nil) return
  end
  local player=GH:Safe(UnitGUID("player"))
  if attacker~=player and attacker~=self.pet then return end
  local info=GH.db.seen[victim]
  if not info or info.faction~="Horde" then
    unresolved("Horde player identity unverified",victim) return
  end
  local round=GH.Lottery:GetCurrent()
  if not round or round.status~="open" then return end
  local key=round.id..":"..victim
  local now=GH:Now()
  if self.recent[key] and now-self.recent[key]<4 then return end
  self.recent[key]=now
  GH.Lottery:SubmitKill({id=GH:ID("kill"),victim=victim,name=info.name,at=now,
                         roundId=round.id,player=GH:PlayerName()})
end
