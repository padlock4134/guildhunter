local GH=GuildHunter
local M={queue={},prefix="GHForever1",received={},pending={}}
GH:RegisterModule("Sync",M)
local function escape(s)
 return tostring(s or ""):gsub("%%","%%25"):gsub("|","%%7C"):gsub("\n","%%0A")
end
local function unescape(s)
 return tostring(s or ""):gsub("%%0A","\n"):gsub("%%7C","|"):gsub("%%25","%%")
end
local fields={
 K={"id","name","guid","guild","reason","class","level","faction","addedBy","created","revision"},
 G={"id","name","reason","addedBy","created","revision"},
 D={"id","kind","revision"},
 L={"roundId","op","id","owner","numbers","source","timestamp","revision","amount","status","value"}
}
local function encode(kind,record)
 local out={kind}
 for _,field in ipairs(fields[kind] or {}) do out[#out+1]=escape(record[field]) end
 return table.concat(out,"|")
end
local function decode(raw)
 local parts={}
 for item in (raw.."|"):gmatch("(.-)|") do parts[#parts+1]=item end
 local kind=parts[1]
 if not fields[kind] then return end
 local record={}
 for i,field in ipairs(fields[kind]) do
  local value=unescape(parts[i+1])
  if value~="" then record[field]=value end
 end
 record.revision=tonumber(record.revision)
 record.created=tonumber(record.created)
 record.timestamp=tonumber(record.timestamp)
 record.amount=tonumber(record.amount)
 record.value=tonumber(record.value) or record.value
 return kind,record
end
local function guildMember(sender)
 if not IsInGuild or not IsInGuild() then return false end
 local short=(sender or ""):match("^[^-]+")
 for i=1,(GetNumGuildMembers and GetNumGuildMembers() or 0) do
  local name=GetGuildRosterInfo(i)
  if name==sender or name==short then return true end
 end
 return false
end
function M:IsOfficerSender(sender)
 local short=(sender or ""):match("^[^-]+")
 for i=1,(GetNumGuildMembers and GetNumGuildMembers() or 0) do
  local name,_,rank=GetGuildRosterInfo(i)
  if name==sender or name==short then
   return rank~=nil and rank <= (GH.db.officerRankMax or 1)
  end
 end
 return false
end
function M:Initialize()
 if RegisterAddonMessagePrefix then RegisterAddonMessagePrefix(self.prefix) end
 if C_ChatInfo and C_ChatInfo.RegisterAddonMessagePrefix then C_ChatInfo.RegisterAddonMessagePrefix(self.prefix) end
 self.frame=CreateFrame("Frame")
 self.frame:SetScript("OnUpdate",function(_,elapsed)
  M.elapsed=(M.elapsed or 0)+elapsed
  if M.elapsed>=0.3 then M.elapsed=0;M:Flush() end
 end)
end
function M:Send(raw)
 if not raw or #raw>230 then return false end
 self.queue[#self.queue+1]=raw
 return true
end
function M:Flush()
 if #self.queue==0 or not IsInGuild or not IsInGuild() then return end
 local send=(C_ChatInfo and C_ChatInfo.SendAddonMessage) or SendAddonMessage
 if not send then return end
 local message=self.queue[1]
 local ok=pcall(send,self.prefix,message,"GUILD")
 if ok then table.remove(self.queue,1) end
end
function M:Publish(kind,record)
 if not self:Send(encode(kind,record)) then GH:Print("Record too large to sync; saved locally") end
end
function M:Request()
 self:Send("R")
 GH:Print("Guild sync requested")
end
function M:SendSnapshot()
 for _,r in pairs(GH.db.kos) do self:Publish("K",r) end
 for _,r in pairs(GH.db.guilds) do self:Publish("G",r) end
 for id,revision in pairs(GH.db.tombstones) do self:Publish("D",{id=id,revision=revision}) end
 if GH:IsOfficer() then GH.Lottery:BroadcastLedger() end
end
function M:HandleEvent(event,prefix,message,channel,sender)
 if event~="CHAT_MSG_ADDON" or prefix~=self.prefix or channel~="GUILD" then return end
 if not sender or sender==GH:SelfName() or not guildMember(sender) then return end
 if message=="R" then self:SendSnapshot();return end
 local kind,record=decode(message)
 if not kind or not record or not record.id and kind~="L" then return end
 if kind=="L" then
  if self:IsOfficerSender(sender) then GH.Lottery:ReceiveLedger(record,sender) end
 else
  GH.KOS:Receive(kind,record)
 end
 end
end
