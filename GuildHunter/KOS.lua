local GH=GuildHunter
local M={}
GH:RegisterModule("KOS",M)
local function normalized(s)
 return (tostring(s or ""):gsub("^%s+",""):gsub("%s+$",""):lower())
end
local function mergeRecord(collection,record)
 if not record or not record.id then return false end
 local existing=collection[record.id]
 if existing and (existing.revision or 0)>=(record.revision or 0) then return false end
 if GH.db.tombstones[record.id] and GH.db.tombstones[record.id]>=(record.revision or 0) then return false end
 collection[record.id]=record
 return true
end
function M:Initialize() end
function M:FindPlayer(guid,name)
 for _,r in pairs(GH.db.kos) do
   if guid and r.guid==guid then return r end
   if normalized(r.name)==normalized(name) and name then return r end
 end
 return nil
end
function M:FindGuild(name)
 for _,r in pairs(GH.db.guilds) do if normalized(r.name)==normalized(name) and name then return r end end
end
function M:AddPlayer(name,guid,guild,reason,class,level,faction)
 if not name or normalized(name)=="" then GH:Print("Player name required") return end
 local existing=self:FindPlayer(guid,name)
 local record=existing or {}
 record.id=record.id or GH.Database:UniqueID("player")
 record.name=name; record.guid=guid or record.guid; record.guild=guild or record.guild
 record.reason=reason or record.reason or "";record.class=class or record.class
 record.level=level or record.level;record.faction=faction or record.faction
 record.addedBy=record.addedBy or GH:SelfName()
 record.created=record.created or GH:Now()
 record.revision=GH:Now()*1000+GH.Database:NextRevision()
 GH.db.kos[record.id]=record
 GH.Sync:Publish("K",record)
 GH:Emit("RefreshUI")
 return record
end
function M:AddTarget()
 if not UnitExists("target") or not UnitIsPlayer("target") or not UnitCanAttack("player","target") then
   GH:Print("Target an enemy player first") return
 end
 local name=UnitName("target")
 local guid=UnitGUID and UnitGUID("target")
 local guild=GetGuildInfo and GetGuildInfo("target")
 local _,class=UnitClass("target")
 self:AddPlayer(name,guid,guild,"",class,UnitLevel("target"),UnitFactionGroup("target"))
end
function M:AddGuild(name,reason)
 if normalized(name)=="" then GH:Print("Guild name required") return end
 local record=self:FindGuild(name) or {}
 record.id=record.id or GH.Database:UniqueID("guild")
 record.name=name;record.reason=reason or record.reason or ""
 record.addedBy=record.addedBy or GH:SelfName()
 record.created=record.created or GH:Now()
 record.revision=GH:Now()*1000+GH.Database:NextRevision()
 GH.db.guilds[record.id]=record
 GH.Sync:Publish("G",record)
 GH:Emit("RefreshUI")
 return record
end
function M:Remove(kind,id)
 local collection=kind=="G" and GH.db.guilds or GH.db.kos
 if not collection[id] then return end
 local revision=GH:Now()*1000+GH.Database:NextRevision()
 collection[id]=nil
 GH.db.tombstones[id]=revision
 GH.Sync:Publish("D",{id=id,kind=kind,revision=revision})
 GH:Emit("RefreshUI")
end
function M:Receive(kind,record)
 if kind=="D" then
   local previous=GH.db.tombstones[record.id] or 0
   if (record.revision or 0)>previous then
     GH.db.tombstones[record.id]=record.revision
     GH.db.kos[record.id]=nil;GH.db.guilds[record.id]=nil
   end
 elseif kind=="K" then mergeRecord(GH.db.kos,record)
 elseif kind=="G" then mergeRecord(GH.db.guilds,record) end
 GH:Emit("RefreshUI")
end
