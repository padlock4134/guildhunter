local GH=GuildHunter
local M={}
GH:RegisterModule("Lottery",M)
local thresholds={5,15,30,50,75,100}
local function money(n) return tonumber(n) or 0 end
local function ordered(a)
 table.sort(a)
 return table.concat(a,",")
end
local function validNumbers(numbers)
 if type(numbers)~="table" or #numbers~=3 then return false end
 local seen={}
 for _,n in ipairs(numbers) do
  if type(n)~="number" or n<1 or n>10 or n~=math.floor(n) or seen[n] then return false end
  seen[n]=true
 end
 return true
end
function M:Initialize()
 self:RefreshCurrent()
end
function M:RefreshCurrent()
 local id=GH.db.lottery.currentId
 self.current=id and GH.db.lottery.rounds[id] or nil
end
function M:CanAdmin()
 if not GH:IsOfficer() then GH:Print("Guild officer permissions required") return false end
 return true
end
function M:Audit(action,note)
 local audit=GH.db.lottery.audit
 audit[#audit+1]={time=GH:Now(),by=GH:SelfName(),action=action,note=tostring(note or "")}
end
function M:NewRound(drawTime)
 if not self:CanAdmin() then return end
 if self.current and self.current.state~="complete" then GH:Print("Finish current round first") return end
 local previous=self.current
 local rollover=previous and previous.rolloverOut or 0
 local id=GH.Database:UniqueID("round")
 local round={id=id,state="open",created=GH:Now(),drawTime=drawTime or (GH:Now()+604800),
 thresholds={unpack(thresholds)},payments={},tickets={},kills={},awarded={},killEvents={},
 jackpot=rollover,rolloverIn=rollover,rolloverOut=0,winning=nil,payouts={},revision=0}
 GH.db.lottery.rounds[id]=round;GH.db.lottery.currentId=id
 self.current=round
 self:Audit("round_open",id)
 self:BroadcastLedger()
 GH:Emit("RefreshUI")
 return round
end
function M:QuickPick()
 local nums={}
 local pool={1,2,3,4,5,6,7,8,9,10}
 for i=1,3 do
  local index=math.random(#pool)
  nums[#nums+1]=table.remove(pool,index)
 end
 table.sort(nums)
 return nums
end
function M:CreateTicket(owner,source,numbers)
 local round=self.current
 if not round or round.state~="open" then return end
 if not round.payments[owner] then return end
 numbers=numbers or self:QuickPick()
 if not validNumbers(numbers) then return end
 local id=GH.Database:UniqueID("ticket")
 if round.tickets[id] then return end
 local ticket={id=id,roundId=round.id,owner=owner,numbers=ordered(numbers),
  source=source,status="active",created=GH:Now()}
 round.tickets[id]=ticket
 self:Audit("ticket_issued",id)
 self:BroadcastTicket(ticket)
 GH:OnTicketCreated(ticket)
 GH:Emit("RefreshUI")
 return ticket
end
function M:ConfirmPayment(player,numbers)
 if not self:CanAdmin() then return end
 local round=self.current
 if not round or round.state~="open" then GH:Print("No open round") return end
 if not player or player=="" or round.payments[player] then GH:Print("Entry already recorded or invalid") return end
 if numbers and not validNumbers(numbers) then GH:Print("Invalid numbers") return end
 round.payments[player]={confirmedBy=GH:SelfName(),time=GH:Now(),amount=50000}
 round.jackpot=money(round.jackpot)+50000
 self:Audit("payment",player..":50000")
 self:CreateTicket(player,"paid",numbers)
 self:BroadcastLedger()
end
function M:RecordKill(player,eventId)
 local round=self.current
 if not round or round.state~="open" or not round.payments[player] then return false end
 if not eventId or round.killEvents[eventId] then return false end
 round.killEvents[eventId]=true
 local count=(round.kills[player] or 0)+1
 round.kills[player]=count
 round.awarded[player]=round.awarded[player] or {}
 for _,threshold in ipairs(round.thresholds) do
  if count>=threshold and not round.awarded[player][threshold] then
   round.awarded[player][threshold]=true
   self:CreateTicket(player,"kill:"..threshold)
  end
 end
 self:BroadcastProgress(player)
 GH:Emit("RefreshUI")
 return true
end
function M:ChangeNumbers(player,ticketId,numbers)
 local round=self.current
 if not round or round.state~="open" or not validNumbers(numbers) then return false end
 local ticket=round.tickets[ticketId]
 if not ticket or ticket.owner~=player then return false end
 ticket.numbers=ordered(numbers)
 self:BroadcastTicket(ticket)
 GH:Emit("RefreshUI")
 return true
end
function M:SetThresholds(values)
 if not self:CanAdmin() or not self.current or self.current.state~="open" then return false end
 for _,awards in pairs(self.current.awarded) do
  if next(awards) then GH:Print("Thresholds locked after awards") return false end
 end
 table.sort(values)
 local prior=0
 for _,v in ipairs(values) do if type(v)~="number" or v<=prior or v<1 then return false end prior=v end
 self.current.thresholds=values
 self:Audit("thresholds",table.concat(values,","))
 self:BroadcastLedger()
 return true
end
function M:CorrectKills(player,newCount,reason)
 if not self:CanAdmin() or not self.current or self.current.state~="open" then return false end
 if not self.current.payments[player] or type(newCount)~="number" or newCount<0 then return false end
 local old=self.current.kills[player] or 0
 self.current.kills[player]=math.floor(newCount)
 self:Audit("kill_correction",player..":"..old..">"..newCount..":"..tostring(reason or ""))
 -- Corrections do not automatically revoke already issued tickets.
 self:BroadcastProgress(player)
 return true
end
function M:CloseEntries()
 if not self:CanAdmin() or not self.current or self.current.state~="open" then return end
 self.current.state="closed";self:Audit("entries_closed",self.current.id);self:BroadcastLedger()
 GH:Emit("RefreshUI")
end
function M:Draw()
 if not self:CanAdmin() then return end
 local r=self.current
 if not r or r.state~="closed" or r.winning then return end
 local numbers=self:QuickPick()
 r.winning=ordered(numbers)
 r.state="drawn";r.drawnAt=GH:Now()
 local winners={}
 for _,ticket in pairs(r.tickets) do
  if ticket.status=="active" and ticket.numbers==r.winning then winners[#winners+1]=ticket end
 end
 r.winners=winners
 local jackpot=money(r.jackpot)
 if #winners==0 then r.rolloverOut=jackpot
 else
  local share=math.floor(jackpot/#winners)
  local remainder=jackpot-share*#winners
  r.rolloverOut=remainder
  for _,ticket in ipairs(winners) do r.payouts[ticket.id]={amount=share,paid=false,owner=ticket.owner} end
 end
 self:Audit("draw",r.id..":"..r.winning)
 self:BroadcastLedger()
 GH:Emit("RefreshUI")
 return numbers
end
function M:ConfirmPayout(ticketId)
 if not self:CanAdmin() or not self.current or self.current.state~="drawn" then return end
 local p=self.current.payouts[ticketId]
 if p and not p.paid then p.paid=true;self:Audit("payout",ticketId);self:BroadcastLedger() end
end
function M:CompleteRound()
 if not self:CanAdmin() or not self.current or self.current.state~="drawn" then return end
 for _,p in pairs(self.current.payouts) do if not p.paid then GH:Print("Confirm all payouts first") return end end
 self.current.state="complete"
 self:Audit("round_complete",self.current.id)
 self:BroadcastLedger()
 GH:Emit("RefreshUI")
end
function M:BroadcastTicket(ticket)
 GH.Sync:Publish("L",{roundId=ticket.roundId,op="ticket",id=ticket.id,
  owner=ticket.owner,numbers=ticket.numbers,source=ticket.source,
  timestamp=ticket.created,revision=GH:Now()*1000+GH.Database:NextRevision(),status=ticket.status})
end
function M:BroadcastProgress(player)
 local r=self.current
 GH.Sync:Publish("L",{roundId=r.id,op="kills",id=player,owner=player,
  value=r.kills[player] or 0,revision=GH:Now()*1000+GH.Database:NextRevision()})
end
function M:BroadcastLedger()
 local r=self.current
 if not r or not GH:IsOfficer() then return end
 GH.Sync:Publish("L",{roundId=r.id,op="round",id=r.id,owner=GH:SelfName(),
  status=r.state,amount=r.jackpot,revision=GH:Now()*1000+GH.Database:NextRevision(),
  numbers=r.winning or "",timestamp=r.drawTime})
 for player,p in pairs(r.payments) do
  GH.Sync:Publish("L",{roundId=r.id,op="payment",id=player,owner=player,
    amount=p.amount,revision=GH:Now()*1000+GH.Database:NextRevision()})
 end
 for _,ticket in pairs(r.tickets) do self:BroadcastTicket(ticket) end
 for player in pairs(r.kills) do self:BroadcastProgress(player) end
end
function M:ReceiveLedger(record,sender)
 if not record.roundId or not record.op then return end
 local r=GH.db.lottery.rounds[record.roundId]
 if not r then
  r={id=record.roundId,state="open",payments={},tickets={},kills={},awarded={},killEvents={},
   thresholds={unpack(thresholds)},jackpot=0,payouts={},revision=0}
  GH.db.lottery.rounds[record.roundId]=r
 end
 local rev=record.revision or 0
 local key=record.op..":"..(record.id or "")
 r.receivedRevisions=r.receivedRevisions or {}
 if rev <= (r.receivedRevisions[key] or 0) then return end
 r.receivedRevisions[key]=rev
 if record.op=="round" then
  r.state=record.status or r.state
  r.jackpot=record.amount or r.jackpot
  r.drawTime=record.timestamp or r.drawTime
  r.winning=record.numbers~="" and record.numbers or r.winning
  GH.db.lottery.currentId=r.id
 elseif record.op=="payment" then
  r.payments[record.owner]={amount=record.amount or 50000}
 elseif record.op=="ticket" then
  r.tickets[record.id]={id=record.id,roundId=r.id,owner=record.owner,numbers=record.numbers,
   source=record.source,status=record.status or "active"}
 elseif record.op=="kills" then r.kills[record.owner]=record.value or 0 end
 self:RefreshCurrent()
 GH:Emit("RefreshUI")
end
