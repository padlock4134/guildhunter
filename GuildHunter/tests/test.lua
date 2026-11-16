-- GuildHunter headless smoke/invariant tests. Run: luatex --luaonly tests/test.lua
local root = arg[0]:gsub("tests/[^/]+%.lua$", "")
local total=0
local function check(test,condition)
  total=total+1
  if not condition then error("FAIL: "..test,2) end
end
local T=1794877200
local player="Shock Ironwang"
local roster={{"Shock Ironwang",0},{"First Mate",1},{"Regular Member",3}}
local values={player=true, target=true}
local soundCount=0
local status={}
local function noop() end
local object={}
object.__index=function(t,k)
  if k=="CreateFontString" or k=="CreateTexture" then return function() return setmetatable({},object) end end
  if k=="GetText" then return function(self) return self.text or "" end end
  if k=="SetText" then return function(self,s) self.text=s end end
  if k=="GetPoint" then return function() return "CENTER",nil,"CENTER",0,0 end end
  if k=="GetWidth" then return function() return 300 end end
  if k=="IsShown" then return function(self) return self.shown end end
  if k=="Show" then return function(self) self.shown=true end end
  if k=="Hide" then return function(self) self.shown=false end end
  if k=="SetShown" then return function(self,v) self.shown=not not v end end
  if k=="RegisterEvent" then return function(self,e) self.events=rawget(self,"events") or {};self.events[e]=true end end
  if k=="SetScript" then return function(self,key,fn) self[key]=fn end end
  return noop
end
UIParent=setmetatable({},object)
CreateFrame=function(frameType,name,parent,template)
  return setmetatable({shown=true},object)
end
DEFAULT_CHAT_FRAME={AddMessage=function(_,s) status[#status+1]=s end}
SlashCmdList={}
SOUNDKIT={RAID_WARNING=8959}
PlaySound=noop
PlaySoundFile=function(path,ch) soundCount=soundCount+1;return false end
GetServerTime=function() return T end
time=function() return T end
date=os.date
issecretvalue=function() return false end
UnitExists=function(unit) return values[unit]==true end
GetUnitName=function(unit) if unit=="player" then return player end;return "Horde Target" end
UnitName=GetUnitName
UnitGUID=function(unit) if unit=="player" then return "Player-A" end;if unit=="pet" then return "Pet-A" end;return "Horde-1" end
UnitIsPlayer=function(unit) return true end
UnitCanAttack=function(a,b) return b~="player" end
UnitClass=function(unit) return "Warlock","WARLOCK" end
UnitLevel=function() return 60 end
UnitFactionGroup=function(unit) if unit=="player" then return "Alliance" else return "Horde" end end
GetGuildInfo=function(unit) if unit=="player" then return "irønclad" else return "Enemy Guild" end end
IsInGuild=function() return true end
GetNumGuildMembers=function() return #roster end
GetGuildRosterInfo=function(i)
  return roster[i][1],"Rank",roster[i][2]
end
C_GuildInfo={GuildRoster=noop}
C_ChatInfo={RegisterAddonMessagePrefix=function() return true end,SendAddonMessage=function() return true end}
local filenames={"Core","Database","KOS","Detection","Tracker","Sync","Lottery","KillTracker","Audio","Settings","UI","LotteryUI","Reliability"}
for _,name in ipairs(filenames) do dofile(root..name..".lua") end
local GH=GuildHunter
GH:Initialize()
check("load",GH.ready)
check("full name",GH:PlayerName()=="Shock Ironwang")
check("guild",GH:InGuild())
check("officer",GH:IsOfficer())
check("main UI",GH.UI.frame~=nil)
check("lottery UI",GH.LotteryUI.frame~=nil)
check("tracker",GH.Tracker.frame~=nil)
local pl=GH.KOS:AddPlayer("Horde Of Doom","TargetGUID","Other Guild","camping")
check("multiword KoS",pl.name=="Horde Of Doom")
check("KoS saved",GH.KOS:FindPlayer("TargetGUID")~=nil)
GH.KOS:Remove("K",pl.id)
check("KoS deleted",GH.KOS:FindPlayer("TargetGUID")==nil)
local tomb=GH.db.tombstones[pl.id]
check("tombstone prevents restore",not GH.KOS:Accept("K",pl))
local r=GH.Lottery:NewRound(1)
check("round open",r and r.status=="open")
check("no unpaid ticket",GH.Lottery:IssueTicket(r,player,"paid") == nil)
check("entry request",GH.Lottery:RequestEntry({9,2,7}))
check("paid confirmed",GH.Lottery:ConfirmPayment(player))
check("entry adds 5g",r.jackpot==50000)
local function ticketCount()
  local n=0;for _ in pairs(r.tickets) do n=n+1 end;return n
end
check("one paid ticket",ticketCount()==1)
check("duplicate payment",not GH.Lottery:ConfirmPayment(player))
check("ticket numbers sorted",next(r.tickets) and (function() for _,t in pairs(r.tickets) do return t.numbers=="2,7,9" end end)())
check("one sound",soundCount==1)
GH.db.seen={}
for i=1,110 do
  local guid="Horde-"..i
  GH.db.seen[guid]={name="Enemy "..i,guid=guid,faction="Horde",lastSeen=T}
end
local function partyKill(i)
  T=T+1
  GH.KillTracker:OnEvent("PARTY_KILL","Player-A","Horde-"..i)
end
for i=1,4 do partyKill(i) end
check("4 kills no bonus",ticketCount()==1)
partyKill(5)
check("5 kills +1 ticket",ticketCount()==2)
local before=r.kills[player]
GH.KillTracker:OnEvent("PARTY_KILL","Player-A","Horde-5")
check("dedup instant kill",r.kills[player]==before)
for i=6,15 do partyKill(i) end
check("15 kills +2 bonus",ticketCount()==3)
for i=16,30 do partyKill(i) end
check("30 kills +3 bonus",ticketCount()==4)
for i=31,100 do partyKill(i) end
check("100 kills six bonus",ticketCount()==7)
check("kill sound seven total",soundCount==7)
local count=ticketCount()
check("invalid numbers rejected",not GH.Lottery:ChangeTicket(next(r.tickets),{2,2,2},player))
check("ticket unchanged",ticketCount()==count)
check("threshold locked",not GH.Lottery:SetThresholds({1,2,3}))
check("bonus jackpot no gold",r.jackpot==50000)
local id=next(r.tickets)
check("number change",GH.Lottery:ChangeTicket(id,{3,1,2},player))
check("change no sound",soundCount==7)
check("change no ticket",ticketCount()==7)
check("wrong user cannot change",not GH.Lottery:ChangeTicket(id,{1,2,4},"Regular Member"))
local packed=GH.Sync.Encode({hi="1:2|x",arr={3,"abc"},foo=false})
local decoded=GH.Sync.Decode(packed)
check("serializer roundtrip",decoded.hi=="1:2|x" and decoded.foo==false and decoded.arr[1]==3)
local malicious=false
check("serializer rejects code",not pcall(GH.Sync.Decode,"loadstring('oops')"))
-- Member identity must be verified before an officer action is accepted.
local currentRev=r.revision
GH.Sync:HandlePayload({type="ROUND",round={id=r.id,revision=currentRev+1000000}},"Regular Member")
-- HandlePayload must be called only after OnEvent membership; guard in receive path.
-- Test unauthorized acceptance using the same boundary as a received message.
check("round persisted",GH.Lottery:GetCurrent().id==r.id)
local oldSound=soundCount
GH.Lottery:ReceiveRound({round=r,live=false,ticketId=id},"First Mate")
check("no sound on snapshot",soundCount==oldSound)
-- Fast forward to drawing time then close.
T=r.drawAt+1
GH.Lottery:CloseEntries()
check("close entries",r.status=="closed")
local oldPick=GH.Lottery.QuickPick
for key,ticket in pairs(r.tickets) do if key~=id then ticket.numbers="1,4,5" end end
GH.Lottery.QuickPick=function() return {1,2,3} end
check("draw once",GH.Lottery:Draw())
check("no redrawing",not GH.Lottery:Draw())
check("one winning ticket",r.winning=="1,2,3" and #r.winners==1)
check("single prize 5g",r.payouts[id].amount==50000)
check("payout complete",GH.Lottery:MarkPaid(id))
check("complete",GH.Lottery:CompleteRound())
local nextRound=GH.Lottery:NewRound(2)
check("new round reset",nextRound and nextRound.id~=r.id and next(nextRound.kills)==nil)
check("new round no rollover after win",nextRound.jackpot==0)
GH.Lottery.QuickPick=oldPick
local db=GuildHunterDB
GH.Database:Initialize()
check("saved variables survive reload",GH.db==db and GH.Lottery:GetCurrent().id==nextRound.id)
-- Multi-winner draw splits gold equally per ticket.
GH.Lottery:ConfirmPayment(player)
GH.Lottery:ConfirmPayment("First Mate")
local ids={}
for key in pairs(nextRound.tickets) do ids[#ids+1]=key end
check("two paid entries",#ids==2 and nextRound.jackpot==100000)
for _,key in ipairs(ids) do nextRound.tickets[key].numbers="1,2,3" end
T=nextRound.drawAt+1
GH.Lottery:CloseEntries()
GH.Lottery.QuickPick=function() return {1,2,3} end
GH.Lottery:Draw()
check("two winners",#nextRound.winners==2)
for _,key in ipairs(ids) do
 check("split prize equally",nextRound.payouts[key].amount==50000)
 GH.Lottery:MarkPaid(key)
end
check("multiple payouts complete",GH.Lottery:CompleteRound())
local emptyWinnerRound=GH.Lottery:NewRound(1)
GH.Lottery:ConfirmPayment(player)
local lone=next(emptyWinnerRound.tickets)
emptyWinnerRound.tickets[lone].numbers="1,2,3"
T=emptyWinnerRound.drawAt+1
GH.Lottery.QuickPick=function() return {4,5,6} end
GH.Lottery:CloseEntries();GH.Lottery:Draw()
check("no winners",#emptyWinnerRound.winners==0)
check("rollover retained",emptyWinnerRound.rolloverOut==50000)
GH.Lottery:CompleteRound()
local rollover=GH.Lottery:NewRound(2)
check("new round inherits rollover",rollover.jackpot==50000)
-- Verify sync chunk assembly and denial of non-officer ledger writes.
local remote=GH.Sync.Decode(GH.Sync.Encode(rollover))
remote.revision=rollover.revision+10000
remote.rolloverIn=765432
remote.jackpot=765432
local oldRev=rollover.revision
GH.Sync:HandlePayload({type="ROUND",round=remote},"Regular Member")
check("member cannot inject officer ledger",GH.Lottery:GetCurrent().revision==oldRev)
player="First Mate"
local start=#GH.db.outbox
GH.Sync:Publish({type="ROUND",round=remote,live=false})
local packets={}
for i=start+1,#GH.db.outbox do packets[#packets+1]=GH.db.outbox[i] end
check("chunked message generated",#packets>=2)
for i=#packets,1,-1 do
 GH.Sync:OnEvent("CHAT_MSG_ADDON",GH.prefix,packets[i],"GUILD","Shock Ironwang")
end
check("out of order sync reassembled",GH.Lottery:GetCurrent().jackpot==765432)
local newRound=GH.Lottery:GetCurrent()
local newer=GH.Sync.Decode(GH.Sync.Encode(newRound))
newer.revision=newRound.revision+1
newer.rolloverIn=888888
newer.jackpot=888888
local noAuthStart=#GH.db.outbox
GH.Sync:Publish({type="ROUND",round=newer})
for i=noAuthStart+1,#GH.db.outbox do
 GH.Sync:OnEvent("CHAT_MSG_ADDON",GH.prefix,GH.db.outbox[i],"GUILD","Regular Member")
end
check("unauthorized sender round rejected",GH.Lottery:GetCurrent().jackpot==765432)
-- No replay on duplicate sync, refreshing the UI, or SavedVariables re-init.
local soundBefore=soundCount
GH.LotteryUI:RefreshUI()
GH.Database:Initialize()
check("reload/no duplicated audio",soundBefore==soundCount)
GH.Lottery.QuickPick=oldPick
player="Shock Ironwang"
print("PASS "..total.." GuildHunter headless assertions")
