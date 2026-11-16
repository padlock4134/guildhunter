local GH=GuildHunter
local M={buffers={}, counter=0,elapsed=0,lastSnapshot=0}
GH:RegisterModule("Sync",M)
-- Length-prefixed serializer: never evaluates incoming Lua or executable text.
local function encode(v,depth,stack)
  depth=depth or 0;stack=stack or {}
  if depth>14 then error("data nesting too deep") end
  local kind=type(v)
  if kind=="nil" then return "z" end
  if kind=="boolean" then return v and "b1" or "b0" end
  if kind=="number" then
    if v~=v or v==math.huge or v==-math.huge then error("invalid number") end
    return "n"..string.format("%.17g",v)..";"
  end
  if kind=="string" then return "s"..#v..":"..v end
  if kind~="table" or stack[v] then error("unsupported or cyclic data") end
  stack[v]=true
  local keys={}
  for k in pairs(v) do
    if type(k)~="string" and type(k)~="number" then error("invalid key") end
    keys[#keys+1]=k
  end
  if #keys>8000 then error("table too large") end
  table.sort(keys,function(a,b) return tostring(a)<tostring(b) end)
  local out={"t",tostring(#keys),":"}
  for _,k in ipairs(keys) do
    out[#out+1]=encode(k,depth+1,stack)
    out[#out+1]=encode(v[k],depth+1,stack)
  end
  stack[v]=nil
  return table.concat(out)
end
local function decode(raw)
  if type(raw)~="string" or #raw>1351680 then error("payload too large") end
  local pos=1
  local function read(depth)
    if depth>14 then error("data too deep") end
    local tag=raw:sub(pos,pos);pos=pos+1
    if tag=="z" then return nil end
    if tag=="b" then
      local val=raw:sub(pos,pos);pos=pos+1
      if val~="1" and val~="0" then error("bad bool") end
      return val=="1"
    end
    if tag=="n" then
      local e=raw:find(";",pos,true)
      if not e or e-pos>25 then error("bad number") end
      local n=tonumber(raw:sub(pos,e-1))
      if not n or n~=n or n==math.huge or n==-math.huge then error("bad number") end
      pos=e+1;return n
    end
    if tag=="s" or tag=="t" then
      local e=raw:find(":",pos,true)
      if not e or e-pos>8 then error("bad length") end
      local n=tonumber(raw:sub(pos,e-1))
      if not n or n<0 or n>100000 then error("bad length") end
      pos=e+1
      if tag=="s" then
        if pos+n-1>#raw then error("short string") end
        local s=raw:sub(pos,pos+n-1);pos=pos+n;return s
      end
      if n>8000 then error("table too large") end
      local obj={}
      for i=1,n do
        local key=read(depth+1)
        if type(key)~="string" and type(key)~="number" then error("bad key") end
        obj[key]=read(depth+1)
      end
      return obj
    end
    error("bad tag")
  end
  local result=read(0)
  if pos<=#raw then error("trailing data") end
  return result
end
M.Encode=encode
M.Decode=decode
function M:Initialize()
  if C_ChatInfo and C_ChatInfo.RegisterAddonMessagePrefix then
    pcall(C_ChatInfo.RegisterAddonMessagePrefix,GH.prefix)
  elseif RegisterAddonMessagePrefix then pcall(RegisterAddonMessagePrefix,GH.prefix) end
  GH:RegisterEvent("CHAT_MSG_ADDON")
  GH:RegisterEvent("GUILD_ROSTER_UPDATE")
  GH:RegisterEvent("PLAYER_ENTERING_WORLD")
  self.ticker=CreateFrame("Frame")
  self.ticker:SetScript("OnUpdate",function(_,elapsed)
    M.elapsed=M.elapsed+elapsed
    if M.elapsed>0.32 then M.elapsed=0;M:Flush() end
  end)
end
function M:Publish(payload)
  if not GH:InGuild() then return false end
  local ok,serialized=pcall(encode,payload)
  if not ok then GH:Print("Sync encoding: "..tostring(serialized));return false end
  local blockSize=165
  local total=math.ceil(#serialized/blockSize)
  if total==0 or total>8192 then GH:Print("Sync record exceeds size limit") return false end
  if #GH.db.outbox+total>16384 then GH:Print("Sync queue full; waiting to retry");return false end
  self.counter=self.counter+1
  local id=tostring(GH:Now()).."_"..tostring(self.counter)
  for i=1,total do
    local piece=serialized:sub((i-1)*blockSize+1,i*blockSize)
    local msg="M:"..id..":"..i..":"..total..":"..piece
    GH.db.outbox[#GH.db.outbox+1]=msg
  end
  return true
end
function M:Flush()
  if not GH:InGuild() or #GH.db.outbox==0 then return end
  local send=C_ChatInfo and C_ChatInfo.SendAddonMessage or SendAddonMessage
  if not send then return end
  local ok,result=pcall(send,GH.prefix,GH.db.outbox[1],"GUILD")
  local success=Enum and Enum.SendAddonMessageResult and Enum.SendAddonMessageResult.Success or 0
  if ok and (result==success or result==true) then table.remove(GH.db.outbox,1) end
end
function M:Request()
  if not GH:InGuild() then GH:Print("Guild sync requires irønclad membership") return end
  self:Publish({type="REQ"})
end
function M:Snapshot()
  for _,r in pairs(GH.db.kos) do self:Publish({type="RECORD",kind="K",record=r}) end
  for _,r in pairs(GH.db.guilds) do self:Publish({type="RECORD",kind="G",record=r}) end
  for _,r in pairs(GH.db.tombstones) do self:Publish({type="RECORD",kind="D",record=r}) end
  if GH:IsLedgerOwner() then GH.Lottery:BroadcastAll(false) end
end
function M:HandlePayload(p,sender)
  if type(p)~="table" or type(p.type)~="string" then return end
  if p.type=="REQ" then
    -- Avoid a mass snapshot storm: one responder per client every ten seconds.
    if GH:Now()-self.lastSnapshot>=10 then
      self.lastSnapshot=GH:Now();self:Snapshot()
    end
  elseif p.type=="RECORD" then
    if type(p.record)=="table" then GH.KOS:Accept(p.kind,p.record,sender) end
  elseif p.type=="ENTRY" or p.type=="EDIT" or p.type=="KILL" then
    if GH:Normalize(p.player)==GH:Normalize(sender) then GH.Lottery:ReceiveRequest(p,sender) end
  elseif p.type=="ROUND" then
    if GH:IsOfficer(sender) then GH.Lottery:ReceiveRound(p,sender) end
  end
end
function M:OnEvent(event,prefix,msg,channel,sender)
  if event=="PLAYER_ENTERING_WORLD" then self.rosterRequested=false;GH:Roster();return end
  if event=="GUILD_ROSTER_UPDATE" then
    if GH:InGuild() and not self.rosterRequested then
      self.rosterRequested=true
      self:Request()
    end
    return
  end
  if event~="CHAT_MSG_ADDON" or prefix~=GH.prefix or channel~="GUILD" then return end
  if type(msg)~="string" or #msg>250 or type(sender)~="string" or not GH:InGuild() then return end
  if GH:Normalize(sender)==GH:Normalize(GH:PlayerName()) then return end
  if GH:MemberRank(sender)==nil then GH:Roster();return end
  local id,index,total,data=msg:match("^M:([%d_]+):(%d+):(%d+):(.*)$")
  index=tonumber(index);total=tonumber(total)
  if not id or not index or not total or total<1 or total>8192 or index<1 or index>total or #data>165 then return end
  local key=sender..":"..id
  local b=self.buffers[key]
  if b and (b.total~=total or GH:Now()-b.at>3600) then self.buffers[key]=nil;b=nil end
  if not b then
    local n=0;for _ in pairs(self.buffers) do n=n+1 end
    if n>30 then self.buffers={};return end
    b={total=total,parts={},count=0,at=GH:Now()};self.buffers[key]=b
  end
  if not b.parts[index] then b.parts[index]=data;b.count=b.count+1 end
  if b.count==total then
    self.buffers[key]=nil
    local raw=table.concat(b.parts)
    local ok,p=pcall(decode,raw)
    if ok then self:HandlePayload(p,sender) end
  end
end
