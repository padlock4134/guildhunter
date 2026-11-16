local GH=GuildHunter
local M={}
GH:RegisterModule("Database",M)
local CURRENT_VERSION=1
local function defaults()
 return {
   version=CURRENT_VERSION,
   kos={}, guilds={}, tombstones={}, seen={}, syncRevision=0,
   officerRankMax=1,
   settings={trackerVisible=true,kosAlerts=true,guildAlerts=true,audioAlerts=true,ticketSound=true},
   tracker={point="CENTER",relativePoint="CENTER",x=300,y=50,width=260,height=280,locked=false,minimized=false},
   lottery={rounds={},currentId=nil,audit={},ledgerVersion=0}
 }
end
function M:Initialize()
 if type(GuildHunterDB)~="table" then GuildHunterDB=defaults() end
 local db=GuildHunterDB
 local base=defaults()
 for k,v in pairs(base) do if db[k]==nil then db[k]=v end end
 for k,v in pairs(base.settings) do if db.settings[k]==nil then db.settings[k]=v end end
 for k,v in pairs(base.tracker) do if db.tracker[k]==nil then db.tracker[k]=v end end
 for k,v in pairs(base.lottery) do if db.lottery[k]==nil then db.lottery[k]=v end end
 if (db.version or 0) > CURRENT_VERSION then GH:Print("Saved data from a newer version; no downgrade performed")
 else db.version=CURRENT_VERSION end
 GH.db=db
end
function M:NextRevision()
 GH.db.syncRevision=(GH.db.syncRevision or 0)+1
 return GH.db.syncRevision
end
function M:UniqueID(prefix)
 return tostring(prefix)..":"..tostring(GH:Now())..":"..tostring(math.random(100000,999999))..":"..GH:SelfName()
end
