local GH=GuildHunter
local M={defaults={5,15,30,50,75,100}}
GH:RegisterModule("Lottery",M)
local ENTRY=50000 -- five gold in copper

local function copy(t)
  local out={}
  for k,v in pairs(t) do out[k]=type(v)=="table" and copy(v) or v end
  return out
end
local function validNumbers(nums)
  if type(nums)~="table" or #nums~=3 then return false end
  local seen={}
  for _,v in ipairs(nums) do
    if type(v)~="number" or v<1 or v>10 or math.floor(v)~=v or seen[v] then return false end
    seen[v]=true
  end
  return true
end
local function packNumbers(nums)
  if not validNumbers(nums) then return nil end
  local n={nums[1],nums[2],nums[3]}
  table.sort(n)
  return table.concat(n,",")
end
local function parseNumbers(v)
  if type(v)~="string" then return nil end
  local nums={}
  for n in v:gmatch("%d+") do nums[#nums+1]=tonumber(n) end
  if not validNumbers(nums) then return nil end
  return nums
end
M.ParseNumbers=parseNumbers
M.PackNumbers=packNumbers
function M:QuickPick()
  local available={1,2,3,4,5,6,7,8,9,10}
  local picked={}
  for i=1,3 do
    local idx=math.random(1,#available)
    picked[#picked+1]=table.remove(available,idx)
  end
  table.sort(picked)
  return picked
end
function M:Initialize()
  local db=GH.db.lottery
  db.entryRequests=db.entryRequests or {}
  db.pendingKills=db.pendingKills or {}
  db.unresolvedKills=db.unresolvedKills or {}
  for _,r in pairs(db.rounds) do
    if r.state and not r.status then r.status=r.state end
    r.requests=r.requests or {}
    r.killClaims=r.killClaims or {}
    r.recentVictims=r.recentVictims or {}
    r.tickets=r.tickets or {}
    r.payments=r.payments or {}
    r.kills=r.kills or {}
    r.awarded=r.awarded or {}
    r.thresholds=r.thresholds or copy(self.defaults)
    r.audit=r.audit or {}
    r.payouts=r.payouts or {}
    r.revision=r.revision or 0
  end
  self.tick=CreateFrame("Frame")
  self.tick.elapsed=0
  self.tick:SetScript("OnUpdate",function(frame,elapsed)
    frame.elapsed=frame.elapsed+elapsed
    if frame.elapsed>25 then frame.elapsed=0;M:Tick() end
  end)
end
function M:GetCurrent()
  local id=GH.db.lottery.currentId
  return id and GH.db.lottery.rounds[id] or nil
end
function M:RequireOfficer()
  if GH:IsOfficer() then return true end
  GH:Print("Officer rank required")
  return false
end
function M:CanEnter(r)
  return r and r.status=="open" and GH:Now() < (r.closesAt or math.huge)
end
function M:Log(r,event,details)
  local item={at=GH:Now(),by=GH:PlayerName(),action=event,details=tostring(details or "")}
  r.audit=r.audit or {}
  r.audit[#r.audit+1]=item
  while #r.audit>300 do table.remove(r.audit,1) end
  GH.Database:Audit(event,details)
end
function M:Touch(r,event,details,newTicket)
  self:Log(r,event,details)
  r.revision=GH.Database:Revision()
  r.writer=GH:PlayerName()
  GH.Sync:Publish({type="ROUND",round=copy(r),live=newTicket~=nil,ticketId=newTicket})
  GH:Refresh()
end
function M:NewRound(hoursUntilDraw)
  if not self:RequireOfficer() then return end
  local prior=self:GetCurrent()
  if prior and prior.status~="complete" then GH:Print("Finish this week's round first") return end
  local h=tonumber(hoursUntilDraw) or 168
  if h<1 or h>720 then GH:Print("Draw must be 1-720 hours from now") return end
  local rollover=prior and (prior.rolloverOut or 0) or 0
  local id=GH:ID("round")
  local r={id=id,created=GH:Now(),closesAt=GH:Now()+math.floor(h*3600)-300,
    drawAt=GH:Now()+math.floor(h*3600),status="open",entryFee=ENTRY,
    jackpot=rollover,rolloverIn=rollover,rolloverOut=0,
    thresholds=copy(self.defaults),payments={},tickets={},kills={},awarded={},
    requests={},killClaims={},recentVictims={},winning=nil,payouts={},audit={},revision=0}
  GH.db.lottery.rounds[id]=r
  GH.db.lottery.currentId=id
  self:Touch(r,"round_open",id)
  return r
end
function M:SetSchedule(hours,closeMinutes)
  if not self:RequireOfficer() then return false end
  local r=self:GetCurrent()
  if not self:CanEnter(r) then return false end
  hours=tonumber(hours);closeMinutes=tonumber(closeMinutes)
  if not hours or not closeMinutes or hours<1 or hours>720 or closeMinutes<0 or closeMinutes>240 then return false end
  r.drawAt=GH:Now()+math.floor(hours*3600)
  r.closesAt=r.drawAt-math.floor(closeMinutes*60)
  if r.closesAt<=GH:Now() then return false end
  self:Touch(r,"schedule","draw hours "..hours..", cutoff minutes "..closeMinutes)
  return true
end
function M:SetThresholds(list)
  if not self:RequireOfficer() then return false end
  local r=self:GetCurrent()
  if not self:CanEnter(r) then return false end
  for _,awards in pairs(r.awarded) do if next(awards) then GH:Print("Thresholds locked: tickets already awarded") return false end end
  if type(list)~="table" or #list<1 or #list>20 then return false end
  table.sort(list)
  local prev=0
  for _,v in ipairs(list) do
    if type(v)~="number" or v~=math.floor(v) or v<=prev or v>100000 then return false end
    prev=v
  end
  r.thresholds=copy(list)
  self:Touch(r,"thresholds",table.concat(list,","))
  return true
end
function M:RequestEntry(numbers)
  if not GH:InGuild() then GH:Print("irønclad members only") return false end
  local r=self:GetCurrent()
  if not self:CanEnter(r) then GH:Print("Entries are closed") return false end
  if r.payments[GH:PlayerName()] then GH:Print("Already entered") return false end
  numbers=numbers or self:QuickPick()
  if not validNumbers(numbers) then GH:Print("Choose three distinct numbers 1-10") return false end
  local req={type="ENTRY",roundId=r.id,player=GH:PlayerName(),numbers=copy(numbers),at=GH:Now()}
  GH.db.lottery.entryRequests[r.id]=req
  if GH:IsOfficer() then self:ReceiveRequest(req,GH:PlayerName())
  else GH.Sync:Publish(req) end
  GH:Print("Entry requested; trade 5g to a guild officer for confirmation")
  return true
end
function M:IssueTicket(r,player,source,numbers,lateQualified)
  if not GH:IsOfficer() or not r.payments[player] then return nil end
  if not self:CanEnter(r) and not (lateQualified and r.status=="closed" and GH:Now() < (r.drawAt or 0)) then return nil end
  numbers=numbers or self:QuickPick()
  local packed=packNumbers(numbers)
  if not packed then return nil end
  local ticket={id=GH:ID("ticket"),owner=player,roundId=r.id,source=source,
                numbers=packed,created=GH:Now(),status="active"}
  r.tickets[ticket.id]=ticket
  self:Touch(r,"ticket_issued",ticket.id,ticket.id)
  if GH:Normalize(player)==GH:Normalize(GH:PlayerName()) then GH.Audio:TicketCreated(ticket) end
  return ticket
end
function M:ConfirmPayment(player)
  if not self:RequireOfficer() then return false end
  local r=self:GetCurrent()
  if not self:CanEnter(r) then GH:Print("Entries closed") return false end
  player=GH:Normalize(player) and player or nil
  if not player or player=="" or r.payments[player] then GH:Print("Invalid player or already paid") return false end
  if GH:MemberRank(player)==nil then GH:Print("Player not in irønclad roster") return false end
  -- Payment is a manual attestation, not an automated trade.
  r.payments[player]={amount=ENTRY,at=GH:Now(),officer=GH:PlayerName()}
  r.jackpot=(r.jackpot or 0)+ENTRY
  local req=r.requests[player]
  self:Touch(r,"payment_confirmed",player)
  self:IssueTicket(r,player,"paid",req and req.numbers or nil)
  return true
end
function M:SubmitKill(claim)
  if not GH:InGuild() or type(claim)~="table" then return false end
  local r=self:GetCurrent()
  if not self:CanEnter(r) or not r.payments[GH:PlayerName()] then return false end
  claim.roundId=r.id
  claim.player=GH:PlayerName()
  if GH:IsOfficer() then return self:AcceptKill(claim,claim.player) end
  GH.db.lottery.pendingKills[claim.id]=claim
  GH.Sync:Publish({type="KILL",player=claim.player,claim=claim,roundId=r.id})
  return true
end
function M:AcceptKill(claim,sender)
  if not GH:IsOfficer() then return false end
  local r=self:GetCurrent()
  if not r or (r.status~="open" and r.status~="closed") or type(claim)~="table" or claim.roundId~=r.id then return false end
  if not claim.id or type(claim.victim)~="string" or type(claim.at)~="number" then return false end
  if claim.at<(r.created or 0) or claim.at>=(r.closesAt or 0) or claim.at>GH:Now()+10 then return false end
  if r.status=="closed" and GH:Now()>=(r.drawAt or 0) then return false end
  if GH:Normalize(sender)~=GH:Normalize(claim.player) or not r.payments[claim.player] then return false end
  if r.killClaims[claim.id] then return false end
  local key=claim.player..":"..claim.victim
  if r.recentVictims[key] and math.abs(claim.at-r.recentVictims[key])<4 then return false end
  r.killClaims[claim.id]={player=claim.player,victim=claim.victim,at=claim.at}
  r.recentVictims[key]=claim.at
  local count=(r.kills[claim.player] or 0)+1
  r.kills[claim.player]=count
  r.awarded[claim.player]=r.awarded[claim.player] or {}
  local toAward={}
  for _,milestone in ipairs(r.thresholds) do
    if count>=milestone and not r.awarded[claim.player][milestone] then
      r.awarded[claim.player][milestone]=true
      toAward[#toAward+1]=milestone
    end
  end
  self:Touch(r,"kill_confirmed",claim.player..":"..count)
  for _,milestone in ipairs(toAward) do self:IssueTicket(r,claim.player,"kill:"..milestone,nil,r.status=="closed") end
  return true
end
function M:CorrectKills(player,total,reason)
  if not self:RequireOfficer() then return false end
  local r=self:GetCurrent(); total=tonumber(total)
  if not self:CanEnter(r) or not r.payments[player] or not total or total<0 or total~=math.floor(total) then return false end
  local old=r.kills[player] or 0
  r.kills[player]=total
  -- Corrections never silently revoke paid or earned tickets. Award newly met milestones.
  r.awarded[player]=r.awarded[player] or {}
  local pending={}
  for _,threshold in ipairs(r.thresholds) do
    if total>=threshold and not r.awarded[player][threshold] then
      r.awarded[player][threshold]=true
      pending[#pending+1]=threshold
    end
  end
  self:Touch(r,"kill_adjustment",player..":"..old.."->"..total.." "..(reason or ""))
  for _,threshold in ipairs(pending) do self:IssueTicket(r,player,"kill:"..threshold) end
  return true
end
function M:ChangeTicket(ticketId,numbers,owner)
  local r=self:GetCurrent()
  if not self:CanEnter(r) then return false end
  local ticket=r.tickets[ticketId]
  if not ticket or GH:Normalize(ticket.owner)~=GH:Normalize(owner) or not validNumbers(numbers) then return false end
  if not GH:IsOfficer() then
    GH.Sync:Publish({type="EDIT",roundId=r.id,player=owner,ticketId=ticketId,numbers=copy(numbers)})
    GH:Print("Ticket number edit sent to officers")
    return true
  end
  ticket.numbers=packNumbers(numbers)
  self:Touch(r,"numbers_changed",ticketId)
  return true
end
function M:ReceiveRequest(p,sender)
  if not GH:IsOfficer() then return end
  local r=self:GetCurrent()
  if not r or r.id~=p.roundId or not self:CanEnter(r) then return end
  if p.type=="ENTRY" then
    if not r.payments[sender] and validNumbers(p.numbers) then
      r.requests[sender]={player=sender,numbers=copy(p.numbers),at=GH:Now()}
      self:Touch(r,"entry_requested",sender)
    end
  elseif p.type=="EDIT" then
    self:ChangeTicket(p.ticketId,p.numbers,sender)
  elseif p.type=="KILL" then
    self:AcceptKill(p.claim,sender)
  end
end
function M:CloseEntries()
  if not self:RequireOfficer() then return false end
  local r=self:GetCurrent()
  if not r or r.status~="open" then return false end
  r.status="closed";self:Touch(r,"entries_closed",r.id)
  return true
end
function M:Draw()
  if not self:RequireOfficer() then return false end
  local r=self:GetCurrent()
  if not r or r.status~="closed" or r.winning then return false end
  if GH:Now()<(r.drawAt or 0) then GH:Print("Draw time not reached") return false end
  r.winning=packNumbers(self:QuickPick())
  r.drawnAt=GH:Now()
  r.status="drawn"
  local winners={}
  for id,ticket in pairs(r.tickets) do
    if ticket.status=="active" and ticket.numbers==r.winning then winners[#winners+1]=id end
  end
  table.sort(winners)
  r.winners=winners
  r.payouts={}
  if #winners==0 then r.rolloverOut=r.jackpot
  else
    local share=math.floor(r.jackpot/#winners)
    r.rolloverOut=r.jackpot-share*#winners
    for _,id in ipairs(winners) do
      r.payouts[id]={owner=r.tickets[id].owner,amount=share,paid=false}
    end
  end
  self:Touch(r,"draw",r.winning)
  return true
end
function M:MarkPaid(ticketId)
  if not self:RequireOfficer() then return false end
  local r=self:GetCurrent()
  if not r or r.status~="drawn" or not r.payouts[ticketId] or r.payouts[ticketId].paid then return false end
  r.payouts[ticketId].paid=true
  r.payouts[ticketId].by=GH:PlayerName()
  r.payouts[ticketId].at=GH:Now()
  self:Touch(r,"payout_confirmed",ticketId)
  return true
end
function M:CompleteRound()
  if not self:RequireOfficer() then return false end
  local r=self:GetCurrent()
  if not r or r.status~="drawn" then return false end
  for _,pay in pairs(r.payouts) do
    if not pay.paid then GH:Print("Record payouts before completing") return false end
  end
  r.status="complete"
  self:Touch(r,"round_complete",r.id)
  return true
end
function M:Tick()
  local r=self:GetCurrent()
  if r and r.status=="open" and GH:IsOfficer() and GH:Now()>=(r.closesAt or math.huge) then
    self:CloseEntries()
  end
  if GH:InGuild() and not GH:IsOfficer() then
    for _,claim in pairs(GH.db.lottery.pendingKills) do
      if r and claim.roundId==r.id and (r.status=="open" or (r.status=="closed" and GH:Now()<(r.drawAt or 0))) then
        GH.Sync:Publish({type="KILL",player=claim.player,roundId=claim.roundId,claim=claim})
      elseif r and r.status=="complete" then GH.db.lottery.pendingKills[claim.id]=nil end
    end
  end
end
function M:BroadcastAll(live)
  if not GH:IsOfficer() then return end
  for _,round in pairs(GH.db.lottery.rounds) do
    GH.Sync:Publish({type="ROUND",round=copy(round),live=live and true or false})
  end
end
function M:ReceiveRound(p,sender)
  local incoming=p.round
  if type(incoming)~="table" or type(incoming.id)~="string" or type(incoming.revision)~="number" then return end
  local db=GH.db.lottery
  local previous=db.rounds[incoming.id]
  if previous and (previous.revision or 0)>=incoming.revision then return end
  db.rounds[incoming.id]=incoming
  local current=self:GetCurrent()
  if not current or (incoming.created or 0)>=(current.created or 0) then db.currentId=incoming.id end
  if p.live and type(p.ticketId)=="string" and incoming.tickets then
    local ticket=incoming.tickets[p.ticketId]
    if ticket and (not previous or not previous.tickets or not previous.tickets[p.ticketId]) then
      GH.Audio:TicketCreated(ticket)
    end
  end
  if incoming.killClaims then
    for id in pairs(incoming.killClaims) do db.pendingKills[id]=nil end
  end
  GH:Refresh()
end
