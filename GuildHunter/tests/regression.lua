dofile("tests/test.lua")
local GH=GuildHunter
local n=0
local function check(label,ok) n=n+1;if not ok then error("FAIL regression: "..label) end end
local function clone(v) return GH.Sync.Decode(GH.Sync.Encode(v)) end
local now=GH:Now()+100000
GetServerTime=function() return now end
local who="Shock Ironwang"
GetUnitName=function(unit) return unit=="player" and who or "Enemy Target" end
local function reset()
  GuildHunterDB=nil;GH.Database:Initialize();GH.Lottery:Initialize()
end
reset()
local r=GH.Lottery:NewRound(1)
check("new round owner",r.authority==who)
check("canonical payment",GH.Lottery:ConfirmPayment("  SHOCK IRONWANG "))
check("alias payment rejected",not GH.Lottery:ConfirmPayment("shock ironwang"))
check("one contribution",r.jackpot==50000)
local tickets=0;for _ in pairs(r.tickets) do tickets=tickets+1 end
check("one ticket",tickets==1)
local beforeDraw,beforeClose=r.drawAt,r.closesAt
check("invalid cutoff rejected",not GH.Lottery:SetSchedule(1,240))
check("invalid schedule atomic",r.drawAt==beforeDraw and r.closesAt==beforeClose)
check("negative number text",GH.Lottery.ParseNumbers("-1,2,3")==nil)
check("decimal number text",GH.Lottery.ParseNumbers("1.2,3")==nil)
check("extra number text",GH.Lottery.ParseNumbers("1,2,3,4")==nil)
check("valid numbers",GH.Lottery.PackNumbers(GH.Lottery.ParseNumbers("3, 1, 2"))=="1,2,3")
check("kill correction requires reason",not GH.Lottery:CorrectKills(who,100,""))
check("kill correction awards",GH.Lottery:CorrectKills(who,100,"Verified test evidence"))
check("downward correction",GH.Lottery:CorrectKills(who,0,"Remove mistaken credit"))
local active=0;for _,t in pairs(r.tickets) do if t.status=="active" then active=active+1 end end
check("only paid ticket remains active",active==1)
-- Two independent saved states: another officer queues, never changes the ledger.
local leaderDB=GH.db
local officerDB=clone(leaderDB);officerDB.outbox={};officerDB.requests={}
GH.db=officerDB;GuildHunterDB=officerDB;who="First Mate"
local oldTotal=GH.Lottery:GetCurrent().jackpot
check("officer payment queued",GH.Lottery:ConfirmPayment("Regular Member"))
check("officer cannot write local jackpot",GH.Lottery:GetCurrent().jackpot==oldTotal)
local opId,op=next(GH.db.requests)
check("durable command",op and op.method=="ConfirmPayment")
GH.db=leaderDB;GuildHunterDB=leaderDB;who="Shock Ironwang"
GH.Sync:HandlePayload(op,"First Mate")
check("leader serializes officer request",r.payments["Regular Member"]~=nil and r.jackpot==100000)
GH.Sync:HandlePayload(op,"First Mate")
check("command replay idempotent",r.jackpot==100000)
local bad=clone(op);bad.opId="bad";bad.player="Regular Member";bad.method="CorrectKills";bad.args={"Regular Member",100,"forged"}
GH.Sync:HandlePayload(bad,"Regular Member")
check("member admin command rejected",r.kills["Regular Member"]==nil)
local claim={id="review1",victim="Horde-verified",name="Horde Target",player="Regular Member",at=now,roundId=r.id}
GH.Lottery:ReceiveRequest({type="KILL",roundId=r.id,claim=claim},"Regular Member")
check("claim awaits officer review",r.review.review1~=nil and r.kills["Regular Member"]==nil)
GH.Lottery:CloseEntries()
check("reviewed preclose claim",GH.Lottery:ApproveKill("review1"))
check("review earns one kill",r.kills["Regular Member"]==1)
claim.id="review2"
GH.Lottery:ReceiveRequest({type="KILL",roundId=r.id,claim=claim},"Regular Member")
check("closed round receives timely claim",r.review.review2~=nil)
check("reject claim",GH.Lottery:RejectKill("review2"))
GH.Lottery:ReceiveRequest({type="KILL",roundId=r.id,claim=claim},"Regular Member")
check("rejected claim does not return",r.review.review2==nil)
local record=GH.KOS:AddPlayer("Enemy A","guidA",nil,"original")
local stale={id=record.id,kind="K",revision=record.revision-1,updatedBy="First Mate"}
GH.KOS:Accept("D",stale)
check("old deletion preserves new record",GH.db.kos[record.id]~=nil)
local badRecord={id="invalid",revision=GH.Database:Revision(),updatedBy="First Mate",name="Broken",reason={}}
check("reject malformed record",not GH.KOS:Accept("K",badRecord,"First Mate"))
check("decoder rejects infinity",not pcall(GH.Sync.Decode,"n1e309;"))
GH.db.outbox={"packet"}
C_ChatInfo.SendAddonMessage=function() return 3 end
GH.Sync:Flush()
check("numeric throttle retains packet",#GH.db.outbox==1)
C_ChatInfo.SendAddonMessage=function() return 0 end
GH.Sync:Flush()
check("numeric success dequeues",#GH.db.outbox==0)
GH.KOS:AddGuild("Enemy Guild","reason")
GH.UI:Open("guilds")
check("enemy guild row callback",pcall(GH.UI.rows[1].OnClick))
local broken={id="incomplete",revision=999}
check("invalid round rejected",not GH.Reliability:ValidRound(broken))
local before=GH.Lottery:GetCurrent()
GH.Lottery:ReceiveRound({round=broken},"Shock Ironwang")
check("invalid round leaves state",GH.Lottery:GetCurrent()==before)
-- Old persisted schema gets an explicit schedule.
GuildHunterDB={version=1,lottery={rounds={legacy={id="legacy",state="open",drawTime=now+5000}},currentId="legacy"}}
GH.Database:Initialize();GH.Lottery:Initialize()
local migrated=GH.Lottery:GetCurrent()
check("legacy draw migrated",migrated.drawAt==now+5000)
check("legacy cutoff migrated",migrated.closesAt==now+4700)
check("legacy state migrated",migrated.status=="open")
local big=179487720000123
check("revision roundtrip precision",GH.Sync.Decode(GH.Sync.Encode(big))==big)
print("PASS "..n.." repair regression assertions")
