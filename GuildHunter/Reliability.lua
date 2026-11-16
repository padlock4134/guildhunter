local GH=GuildHunter
local M={}
GH:RegisterModule("Reliability",M)
local L=GH.Lottery
local S=GH.Sync
local function copy(v)
  if type(v)~="table" then return v end
  local t={};for k,x in pairs(v) do t[k]=copy(x) end;return t
end
local function finite(v) return type(v)=="number" and v==v and v~=math.huge and v~=-math.huge end
local function text(v,n) return type(v)=="string" and #v>0 and #v<=(n or 160) end
local function safe(v,depth,budget)
  depth=depth or 0;budget=budget or {n=0}
  budget.n=budget.n+1
  if depth>14 or budget.n>100000 then return false end
  if type(v)=="number" then return finite(v) end
  if type(v)=="string" then return #v<=4096 and not v:find("%z") end
  if type(v)=="boolean" or v==nil then return true end
  if type(v)~="table" then return false end
  for k,x in pairs(v) do
    if type(k)~="string" and type(k)~="number" then return false end
    if not safe(k,depth+1,budget) or not safe(x,depth+1,budget) then return false end
  end
  return true
end
function M:ValidRound(r)
  if not safe(r) or type(r)~="table" or not text(r.id) or not finite(r.revision) then return false end
  if not ({open=true,closed=true,drawn=true,complete=true})[r.status] then return false end
  for _,k in ipairs({"payments","tickets","kills","awarded","requests","killClaims","recentVictims","thresholds","payouts","audit"}) do
    if type(r[k])~="table" then return false end
  end
  for _,k in ipairs({"created","closesAt","drawAt","jackpot","rolloverIn","rolloverOut"}) do
    if not finite(r[k]) or r[k]<0 then return false end
  end
  if not text(r.authority) or #r.thresholds<1 or #r.thresholds>20 then return false end
  local last=0
  for _,v in ipairs(r.thresholds) do if not finite(v) or v<=last or v~=math.floor(v) then return false end;last=v end
  local accounted=r.rolloverIn
  for _,p in pairs(r.payments) do
    if type(p)~="table" or p.amount~=50000 then return false end
    accounted=accounted+p.amount
  end
  if r.jackpot~=accounted then return false end
  for _,entry in ipairs(r.audit) do
    if type(entry)~="table" or not finite(entry.at) or not text(entry.action) or type(entry.details)~="string" then return false end
  end
  if r.review~=nil and type(r.review)~="table" then return false end
  for id,c in pairs(r.review or {}) do
    if type(c)~="table" or id~=c.id or not text(id) or not text(c.victim) or not text(c.player) or not finite(c.at)
      or (c.name~=nil and type(c.name)~="string") then return false end
  end
  for name,p in pairs(r.payments) do
    if not text(name) or type(p)~="table" or p.amount~=50000 then return false end
  end
  for id,t in pairs(r.tickets) do
    if type(t)~="table" or id~=t.id or not text(id) or not text(t.owner) or not r.payments[t.owner]
      or t.roundId~=r.id or not text(t.source) or not L.ParseNumbers(t.numbers) or
      (t.status~="active" and t.status~="void") then return false end
  end
  for name,n in pairs(r.kills) do if not text(name) or not finite(n) or n<0 or n~=math.floor(n) then return false end end
  for name,a in pairs(r.awarded) do if not text(name) or type(a)~="table" then return false end end
  for id,p in pairs(r.payouts) do
    if not r.tickets[id] or type(p)~="table" or p.owner~=r.tickets[id].owner or not finite(p.amount) or p.amount<0 or type(p.paid)~="boolean" then return false end
  end
  if (r.status=="drawn" or r.status=="complete") and not L.ParseNumbers(r.winning) then return false end
  return true
end
function M:Queue(payload)
  payload.opId=payload.opId or GH:ID("operation")
  payload.player=GH:PlayerName()
  GH.db.requests[payload.opId]=copy(payload)
  S:Publish(payload)
  GH:Print("Action queued for the guild leader; confirmation appears when processed.")
  return true
end
function L:Touch(r,event,details,newTicket)
  self:Log(r,event,details)
  self.dirty=true
  if newTicket then self.notices=self.notices or {};self.notices[#self.notices+1]=newTicket end
  if not self.transaction then M:Commit(r) end
end
function M:Commit(r)
  if not L.dirty or not r then return end
  r.authority=r.authority or GH:PlayerName()
  r.revision=GH.Database:Revision();r.writer=GH:PlayerName()
  S:Publish({type="ROUND",round=copy(r),live=false})
  for _,id in ipairs(L.notices or {}) do
    r.notifications=r.notifications or {};r.notifications[id]=GH:Now()
    S:Publish({type="TICKET_NOTICE",ticket=copy(r.tickets[id]),at=GH:Now()})
  end
  L.notices={};L.dirty=false;GH:Refresh()
end
local admin={"NewRound","SetSchedule","SetThresholds","ConfirmPayment","CorrectKills","CloseEntries","Draw","MarkPaid","CompleteRound","ApproveKill","RejectKill"}
local allowed={}
for _,name in ipairs(admin) do allowed[name]=true end
function L:RejectKill(id)
  local r=self:GetCurrent()
  if not r or not r.review or not r.review[id] then return false end
  r.rejected=r.rejected or {};r.rejected[id]=true;r.review[id]=nil
  self:Touch(r,"claim_rejected",id)
  return true
end
function L:ApproveKill(id)
  local r=self:GetCurrent();local claim=r and r.review and r.review[id]
  if not claim then return false end
  local ok=self:AcceptKill(claim,claim.player)
  if ok then r.review[id]=nil;self:Touch(r,"claim_reviewed",id) end
  return ok
end
local function wrap(name,officerOnly)
  local original=L[name]
  L[name]=function(self,...)
    if officerOnly and not GH:IsOfficer() then return false end
    if not GH:IsLedgerOwner() then
      if officerOnly then return M:Queue({type="COMMAND",method=name,args={...},roundId=self:GetCurrent() and self:GetCurrent().id}) end
      return false
    end
    local r=self:GetCurrent()
    if r and r.authority and GH:Normalize(r.authority)~=GH:Normalize(GH:PlayerName()) then
      GH:Print("This round belongs to a different ledger owner. Reconcile it before continuing.");return false
    end
    if self.transaction then return original(self,...) end
    self.transaction=true;self.dirty=false;self.notices={}
    local saved=copy(GH.db.lottery)
    local result={pcall(original,self,...)}
    self.transaction=false
    if not result[1] then GH.db.lottery=saved;self.dirty=false;self.notices={};GH:Print("Action failed: "..tostring(result[2]));return false end
    M:Commit(self:GetCurrent())
    return unpack(result,2)
  end
end
for _,name in ipairs(admin) do wrap(name,true) end
wrap("AcceptKill",false)
local originalRequest=L.ReceiveRequest
function L:ReceiveRequest(p,sender)
  if not GH:IsLedgerOwner() then return end
  sender=GH:CanonicalName(sender)
  if not sender then return end
  if p.type=="KILL" then
    local r=self:GetCurrent();local c=p.claim
    if not r or r.id~=p.roundId or type(c)~="table" or not text(c.id) or not text(c.victim)
      or (c.name~=nil and type(c.name)~="string") or not finite(c.at) or c.at<r.created or c.at>=r.closesAt or c.at>GH:Now()+10
      or GH:Normalize(c.player)~=GH:Normalize(sender) or not r.payments[sender]
      or (r.status~="open" and r.status~="closed") or GH:Now()>=r.drawAt then return end
    c=copy(c);c.player=sender;c.roundId=r.id
    r.review=r.review or {}
    if not r.review[c.id] and not r.killClaims[c.id] and not (r.rejected and r.rejected[c.id]) then
      r.review[c.id]=c;self:Touch(r,"claim_pending_review",sender.." "..c.victim)
    end
    return true
  end
  return originalRequest(self,p,sender)
end
local change=L.ChangeTicket
function L:ChangeTicket(id,numbers,owner)
  owner=GH:CanonicalName(owner)
  if not owner or not self.PackNumbers(numbers) then return false end
  if not GH:IsLedgerOwner() then
    if GH:Normalize(owner)~=GH:Normalize(GH:PlayerName()) then return false end
    local r=self:GetCurrent()
    if not self:CanEnter(r) then return false end
    return M:Queue({type="EDIT",roundId=r.id,ticketId=id,numbers=numbers})
  end
  return change(self,id,numbers,owner)
end
local entry=L.RequestEntry
function L:RequestEntry(numbers)
  if GH:IsLedgerOwner() then return entry(self,numbers) end
  local r=self:GetCurrent()
  if not GH:InGuild() or not self:CanEnter(r) or r.payments[GH:PlayerName()] or not self.PackNumbers(numbers) then return false end
  local p={type="ENTRY",roundId=r.id,numbers=copy(numbers)}
  GH.db.lottery.entryRequests[r.id]=p
  return M:Queue(p)
end
local receive=L.ReceiveRound
function L:ReceiveRound(p,sender)
  if not GH:IsLedgerOwner(sender) or not M:ValidRound(p.round) or GH:Normalize(p.round.authority)~=GH:Normalize(sender) then return end
  local old=GH.db.lottery.rounds[p.round.id]
  if old then
    if old.authority and GH:Normalize(old.authority)~=GH:Normalize(p.round.authority) then return end
    local stages={open=1,closed=2,drawn=3,complete=4}
    if stages[p.round.status]<stages[old.status] or (old.winning and old.winning~=p.round.winning) then return end
  end
  GH.db.counter=math.max(GH.db.counter or 0,p.round.revision)
  receive(self,p,sender)
end
local handle=S.HandlePayload
function S:HandlePayload(p,sender)
  if not safe(p) or type(p)~="table" then return end
  if p.type=="ACK" then
    if GH:IsLedgerOwner(sender) and GH:Normalize(p.player)==GH:Normalize(GH:PlayerName()) then GH.db.requests[p.opId]=nil end
    return
  end
  if p.type=="TICKET_NOTICE" then
    if GH:IsLedgerOwner(sender) and type(p.ticket)=="table" and text(p.ticket.id) and text(p.ticket.owner)
      and finite(p.at) and p.at>=M.sessionStart and p.at<=GH:Now()+10 then GH.Audio:TicketCreated(p.ticket) end
    return
  end
  if p.type=="COMMAND" or p.type=="ENTRY" or p.type=="EDIT" then
    if not GH:IsLedgerOwner() or not text(p.opId) or GH:Normalize(p.player)~=GH:Normalize(sender) then return end
    if not GH.db.processed[p.opId] then
      if p.type=="COMMAND" then
        if not GH:IsOfficer(sender) or not allowed[p.method] or type(p.args)~="table" then return end
        local r=L:GetCurrent()
        if p.roundId~=(r and r.id) then return end
        L[p.method](L,unpack(p.args))
      else L:ReceiveRequest(p,sender) end
      GH.db.processed[p.opId]=GH:Now()
    end
    self:Publish({type="ACK",opId=p.opId,player=sender})
    return
  end
  return handle(self,p,sender)
end
function M:Initialize()
  self.sessionStart=GH:Now()
  local f=CreateFrame("Frame");local elapsed=0
  f:SetScript("OnUpdate",function(_,dt)
    elapsed=elapsed+dt;if elapsed<10 then return end;elapsed=0
    for _,p in pairs(GH.db.requests) do
      if GH:Normalize(p.player)==GH:Normalize(GH:PlayerName()) then S:Publish(p) end
    end
  end)
  local ui=GH.LotteryUI
  local label=ui.officerPage:CreateFontString(nil,"OVERLAY","GameFontHighlightSmall")
  label:SetPoint("TOPLEFT",8,-535);label:SetWidth(470);label:SetJustifyH("LEFT")
  local b=CreateFrame("Button",nil,ui.officerPage,"UIPanelButtonTemplate")
  b:SetSize(170,25);b:SetPoint("TOPLEFT",480,-535);b:SetText("Approve shown claim")
  local refresh=ui.RefreshOfficer
  function ui:RefreshOfficer()
    refresh(self)
    local r=L:GetCurrent();local first
    for id,c in pairs(r and r.review or {}) do if not first or id<first.id then first=c end end
    self.reviewId=first and first.id
    label:SetText(first and ("Review: "..first.player.." / "..(first.name or first.victim).." / "..date("!%H:%M:%S",first.at).." UTC") or "No kill claims awaiting review")
    b:SetEnabled(first~=nil)
  end
  b:SetScript("OnClick",function() if ui.reviewId then L:ApproveKill(ui.reviewId) end end)
  local reject=CreateFrame("Button",nil,ui.officerPage,"UIPanelButtonTemplate")
  reject:SetSize(170,25);reject:SetPoint("TOPLEFT",480,-565);reject:SetText("Reject shown claim")
  reject:SetScript("OnClick",function() if ui.reviewId then L:RejectKill(ui.reviewId) end end)
  local unresolved=ui.memberPage:CreateFontString(nil,"OVERLAY","GameFontHighlightSmall")
  unresolved:SetPoint("TOPLEFT",8,-525);unresolved:SetWidth(640);unresolved:SetJustifyH("LEFT")
  local memberRefresh=ui.RefreshMember
  function ui:RefreshMember()
    memberRefresh(self)
    local log=GH.db.lottery.unresolvedKills;local last=log[#log]
    unresolved:SetText(last and ("Unresolved kills: "..#log.." | Latest: "..date("!%H:%M:%S",last.at).." UTC | "..last.reason) or "No unresolved local kill events")
  end
  ui.frame:SetHeight(710)
end

-- Send recursive changes between snapshots; request a full snapshot after a gap.
local publish=S.Publish
local baselines={}
local queued={}
local function changes(a,b,path,out)
  if type(a)=="table" and type(b)=="table" then
    for key,v in pairs(b) do local p=copy(path);p[#p+1]=key;changes(a[key],v,p,out) end
    for key in pairs(a) do if b[key]==nil then local p=copy(path);p[#p+1]=key;out[#out+1]={path=p,remove=true} end end
  elseif a~=b then out[#out+1]={path=copy(path),value=copy(b)} end
end
function S:Publish(p)
  local original=p
  if p.opId and queued[p.opId] then
    local prefix=queued[p.opId]
    for _,packet in ipairs(GH.db.outbox) do if packet:sub(1,#prefix)==prefix then return true end end
  end
  if p.type=="ROUND" and baselines[p.round.id] and not p.snapshot then
    local old=baselines[p.round.id];local ops={}
    changes(old,p.round,{},ops)
    p={type="PATCH",id=p.round.id,base=old.revision,ops=ops}
  end
  local ok=publish(self,p)
  if ok then
    if original.type=="ROUND" then baselines[original.round.id]=copy(original.round) end
    if original.opId then queued[original.opId]="M:"..GH:Now().."_"..self.counter..":" end
  end
  return ok
end
local dispatch=S.HandlePayload
function S:HandlePayload(p,sender)
  if type(p)=="table" and p.type=="PATCH" then
    if not GH:IsLedgerOwner(sender) or not safe(p) or not text(p.id) or type(p.ops)~="table" then return end
    local old=GH.db.lottery.rounds[p.id]
    if not old or old.revision~=p.base then
      if GH:Now()-(self.gapRequest or 0)>=5 then self.gapRequest=GH:Now();self:Request() end
      return
    end
    local r=copy(old)
    for _,op in ipairs(p.ops) do
      if type(op)~="table" or type(op.path)~="table" or #op.path<1 or #op.path>14 then return end
      local t=r
      for i=1,#op.path-1 do t=t[op.path[i]];if type(t)~="table" then return end end
      if op.remove then t[op.path[#op.path]]=nil else t[op.path[#op.path]]=copy(op.value) end
    end
    L:ReceiveRound({round=r,live=false},sender)
    return
  end
  return dispatch(self,p,sender)
end
