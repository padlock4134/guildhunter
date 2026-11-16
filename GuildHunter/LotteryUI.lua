local GH=GuildHunter
local M={page="member",ticketSelected=nil,rows={},officerRows={},historyRows={}}
GH:RegisterModule("LotteryUI",M)
local function btn(parent,text,x,y,w,fn)
  local b=CreateFrame("Button",nil,parent,"UIPanelButtonTemplate")
  b:SetSize(w or 100,25);b:SetPoint("TOPLEFT",x,y);b:SetText(text)
  b:SetScript("OnClick",fn)
  return b
end
local function edit(parent,x,y,w)
  local e=CreateFrame("EditBox",nil,parent,"InputBoxTemplate")
  e:SetSize(w or 130,25);e:SetPoint("TOPLEFT",x,y)
  e:SetAutoFocus(false)
  e:SetScript("OnEscapePressed",function(self) self:ClearFocus() end)
  return e
end
local function label(parent,x,y,text,width)
  local t=parent:CreateFontString(nil,"OVERLAY","GameFontHighlight")
  t:SetPoint("TOPLEFT",x,y);t:SetJustifyH("LEFT")
  if width then t:SetWidth(width) end
  t:SetText(text or "")
  return t
end
local function scroll(parent,x,y,w,h)
  local s=CreateFrame("ScrollFrame",nil,parent,"UIPanelScrollFrameTemplate")
  s:SetPoint("TOPLEFT",x,y);s:SetSize(w,h)
  local c=CreateFrame("Frame",nil,s)
  c:SetSize(w-34,h);s:SetScrollChild(c)
  return s,c
end
local function clock(stamp)
  if not stamp then return "Not scheduled" end
  return date("!%d %b %Y %H:%M",stamp).." UTC"
end
local function gold(copper)
  copper=math.floor(copper or 0)
  return string.format("%dg %ds %dc",math.floor(copper/10000),math.floor(copper/100)%100,copper%100)
end
function M:Initialize()
  local cfg=GH.db.windows
  local f=CreateFrame("Frame","GuildHunterLotteryWindow",UIParent,"BackdropTemplate")
  f:SetSize(745,620)
  f:SetPoint(cfg.lotteryPoint or "CENTER",UIParent,cfg.lotteryRelative or "CENTER",cfg.lotteryX or 0,cfg.lotteryY or 0)
  f:SetFrameStrata("DIALOG")
  f:SetBackdrop({bgFile="Interface\\DialogFrame\\UI-DialogBox-Background",
    edgeFile="Interface\\DialogFrame\\UI-DialogBox-Border",tile=true,tileSize=32,edgeSize=32,
    insets={left=12,right=12,top=12,bottom=12}})
  f:EnableMouse(true);f:SetMovable(true);f:RegisterForDrag("LeftButton")
  f:SetScript("OnDragStart",function(self) self:StartMoving() end)
  f:SetScript("OnDragStop",function(self)
    self:StopMovingOrSizing()
    local point,_,relative,x,y=self:GetPoint();cfg.lotteryPoint=point;cfg.lotteryRelative=relative;cfg.lotteryX=x;cfg.lotteryY=y
  end)
  label(f,24,-22,"GuildHunter — irønclad Weekly Lottery")
  btn(f,"X",692,-16,29,function() f:Hide() end)
  btn(f,"My Lottery",23,-58,125,function() M:ShowPage("member") end)
  self.officerTab=btn(f,"Officer Desk",156,-58,140,function() M:ShowPage("officer") end)
  btn(f,"History",304,-58,102,function() M:ShowPage("history") end)
  local area=CreateFrame("Frame",nil,f)
  area:SetPoint("TOPLEFT",26,-101);area:SetPoint("BOTTOMRIGHT",-24,20)
  self.frame=f;self.area=area
  local elapsed=0
  f:SetScript("OnUpdate",function(_,dt) elapsed=elapsed+dt;if elapsed>=1 then elapsed=0;if M.page=="member" then M:RefreshMember() elseif M.page=="officer" then M:RefreshOfficer() end end end)
  self:BuildMember()
  self:BuildOfficer()
  self:BuildHistory()
  self:ShowPage("member")
  f:Hide()
end
function M:BuildMember()
  local p=CreateFrame("Frame",nil,self.area)
  p:SetAllPoints();self.memberPage=p
  self.head=label(p,8,-7,"",645)
  self.stats=label(p,8,-35,"",645)
  self.draw=label(p,8,-62,"",645)
  self.progress=label(p,8,-104,"",645)
  local bar=CreateFrame("StatusBar",nil,p)
  bar:SetStatusBarTexture("Interface\\TargetingFrame\\UI-StatusBar")
  bar:SetPoint("TOPLEFT",8,-132);bar:SetSize(480,18)
  bar:SetMinMaxValues(0,100);bar:SetValue(0)
  bar.bg=bar:CreateTexture(nil,"BACKGROUND")
  bar.bg:SetAllPoints();bar.bg:SetColorTexture(0.15,0.15,0.15,0.85)
  self.bar=bar
  self.entryStatus=label(p,8,-171,"",645)
  label(p,8,-202,"Your numbers (three distinct values 1–10)")
  self.numbers=edit(p,9,-223,165)
  self.numbers:SetText("1,2,3")
  btn(p,"Quick Pick",189,-223,105,function()
    M.numbers:SetText(table.concat(GH.Lottery:QuickPick(),","))
  end)
  self.entryButton=btn(p,"Request 5g Entry",309,-223,155,function()
    local values=GH.Lottery.ParseNumbers(M.numbers:GetText())
    if not values then GH:Print("Enter three distinct numbers from 1 to 10") return end
    GH.Lottery:RequestEntry(values)
    M:RefreshMember()
  end)
  self.editButton=btn(p,"Save Ticket Numbers",473,-223,182,function()
    local values=GH.Lottery.ParseNumbers(M.numbers:GetText())
    if not M.ticketSelected or not values then GH:Print("Select your ticket and enter three valid numbers") return end
    GH.Lottery:ChangeTicket(M.ticketSelected,values,GH:PlayerName())
    M:RefreshMember()
  end)
  self.ticketLabel=label(p,8,-265,"Your tickets",640)
  self.ticketScroll,self.ticketContent=scroll(p,8,-292,644,183)
  self.win=label(p,8,-491,"",640)
end
function M:BuildOfficer()
  local p=CreateFrame("Frame",nil,self.area)
  p:SetAllPoints();self.officerPage=p
  self.offStatus=label(p,8,-4,"",660)
  self.newHours=edit(p,8,-33,62);self.newHours:SetText("168")
  label(p,78,-36,"hours until draw",165)
  self.newRound=btn(p,"Start Weekly Round",248,-33,169,function()
    GH.Lottery:NewRound(tonumber(M.newHours:GetText()))
    M:RefreshOfficer()
  end)
  self.close=btn(p,"Close Entries",430,-33,124,function()
    GH.Lottery:CloseEntries();M:RefreshOfficer()
  end)
  self.execute=btn(p,"Draw",563,-33,89,function()
    GH.Lottery:Draw();M:RefreshOfficer()
  end)
  self.complete=btn(p,"Complete Round",523,-65,130,function()
    GH.Lottery:CompleteRound();M:RefreshOfficer()
  end)
  label(p,8,-78,"Trade confirmation: player name (5 gold handed to an officer)",640)
  self.paymentName=edit(p,8,-99,250)
  btn(p,"Confirm 5g Paid",269,-99,155,function()
    GH.Lottery:ConfirmPayment(M.paymentName:GetText())
    M:RefreshOfficer()
  end)
  label(p,8,-143,"Draw in hours / close entries minutes before draw",560)
  self.drawHours=edit(p,8,-164,70);self.drawHours:SetText("168")
  self.cutoff=edit(p,91,-164,68);self.cutoff:SetText("5")
  btn(p,"Update Schedule",175,-164,160,function()
    GH.Lottery:SetSchedule(M.drawHours:GetText(),M.cutoff:GetText())
    M:RefreshOfficer()
  end)
  self.schedule=label(p,344,-168,"",310)
  label(p,8,-207,"Horde kill milestones (comma-separated)",410)
  self.thresholds=edit(p,8,-229,240)
  btn(p,"Save Thresholds",263,-229,160,function()
    local input=M.thresholds:GetText()
    local values={}
    for n in input:gmatch("%d+") do values[#values+1]=tonumber(n) end
    if not GH.Lottery:SetThresholds(values) then GH:Print("Threshold change rejected") end
    M:RefreshOfficer()
  end)
  label(p,8,-270,"Kill correction: player / confirmed total / audit reason",640)
  self.killName=edit(p,8,-290,193)
  self.killTotal=edit(p,216,-290,62)
  self.killReason=edit(p,292,-290,180)
  btn(p,"Correct",488,-290,101,function()
    GH.Lottery:CorrectKills(M.killName:GetText(),M.killTotal:GetText(),M.killReason:GetText())
    M:RefreshOfficer()
  end)
  self.members=label(p,8,-333,"Members, payment, kills and pending entries",630)
  self.officerScroll,self.officerContent=scroll(p,8,-350,649,146)
  self.payout=label(p,8,-511,"",635)
  self.payoutButton=btn(p,"",300,-503,290,function()
    if M.pendingPayout then GH.Lottery:MarkPaid(M.pendingPayout) end
    M:RefreshOfficer()
  end)
end
function M:BuildHistory()
  local p=CreateFrame("Frame",nil,self.area)
  p:SetAllPoints();self.historyPage=p
  label(p,8,-8,"Completed rounds, drawing results, jackpot rollover and audit records")
  self.historyScroll,self.historyContent=scroll(p,8,-38,655,450)
end
function M:Open()
  self.frame:Show()
  self:ShowPage(self.page or "member")
end
function M:ShowPage(page)
  if page=="officer" and not GH:IsOfficer() then
    GH:Print("Officer dashboard requires an officer rank")
    page="member"
  end
  self.page=page
  self.memberPage:SetShown(page=="member")
  self.officerPage:SetShown(page=="officer")
  self.historyPage:SetShown(page=="history")
  self.officerTab:SetShown(GH:IsOfficer())
  if page=="member" then self:RefreshMember()
  elseif page=="officer" then self:RefreshOfficer()
  else self:RefreshHistory() end
end
local function setRows(pool,container,records,formatter,callback)
  container:SetHeight(math.max(220,#records*27+2))
  for i,item in ipairs(records) do
    local row=pool[i]
    if not row then
      row=CreateFrame("Button",nil,container)
      row:SetHeight(26)
      row:SetPoint("TOPLEFT",2,-(i-1)*27)
      row:SetPoint("TOPRIGHT",-3,-(i-1)*27)
      row.text=row:CreateFontString(nil,"OVERLAY","GameFontHighlightSmall")
      row.text:SetAllPoints();row.text:SetJustifyH("LEFT")
      pool[i]=row
    end
    row.text:SetText(formatter(item))
    row:SetScript("OnClick",function() callback(item) end)
    row:Show()
  end
  for i=#records+1,#pool do pool[i]:Hide() end
end
function M:RefreshMember()
  local r=GH.Lottery:GetCurrent()
  if not r then
    self.head:SetText("No weekly round currently open")
    self.stats:SetText("Your guild officer will open a lottery round")
    self.draw:SetText("");self.progress:SetText("")
    self.entryStatus:SetText("Entry fee: 5g per character")
    self.ticketLabel:SetText("My tickets: 0")
    self.win:SetText("");self.bar:SetValue(0)
    self.entryButton:SetEnabled(false);self.editButton:SetEnabled(false)
    setRows(self.rows,self.ticketContent,{},function() end,function() end)
    return
  end
  local count=0;local paid=0
  for _ in pairs(r.tickets) do count=count+1 end
  for _ in pairs(r.payments) do paid=paid+1 end
  self.head:SetText("Round: "..r.status.."   |   Jackpot: "..gold(r.jackpot))
  self.stats:SetText("Entry: 5g   |   Players: "..paid.."   |   Tickets: "..count)
  self.draw:SetText("Closes: "..clock(r.closesAt).."   Draw: "..clock(r.drawAt))
  local me=GH:PlayerName();local kills=r.kills[me] or 0
  local previous=0;local target
  for _,t in ipairs(r.thresholds) do
    if kills<t then target=t;break end
    previous=t
  end
  local progress=target and math.floor((kills-previous)/(target-previous)*100) or 100
  self.bar:SetValue(progress)
  self.progress:SetText("Verified Horde killing blows: "..kills.."  |  Next ticket at: "..(target or "all completed")..
    "  |  Progress: "..progress.."%")
  local mine={}
  for _,ticket in pairs(r.tickets) do if ticket.owner==me then mine[#mine+1]=ticket end end
  table.sort(mine,function(a,b) return (a.created or 0)<(b.created or 0) or (a.created==b.created and a.id<b.id) end)
  self.entryStatus:SetText(r.payments[me] and "Entry paid and confirmed by officer" or
    (GH.db.lottery.entryRequests[r.id] and "Entry requested — trade 5g to an officer" or "Not entered"))
  self.ticketLabel:SetText("Your tickets: "..#mine.."   (click one to edit numbers)")
  self.entryButton:SetEnabled(GH.Lottery:CanEnter(r) and not r.payments[me])
  self.editButton:SetEnabled(GH.Lottery:CanEnter(r) and self.ticketSelected~=nil)
  setRows(self.rows,self.ticketContent,mine,function(t)
    return ((self.ticketSelected==t.id) and "|cffffd34d> " or "  ")..
      t.numbers.."   |   "..t.source.."   |   "..t.id
  end,function(ticket)
    M.ticketSelected=ticket.id
    M.numbers:SetText(ticket.numbers)
    M:RefreshMember()
  end)
  local winnerCount=0
  for _ in pairs(r.payouts or {}) do winnerCount=winnerCount+1 end
  self.win:SetText(r.winning and ("Winning numbers: "..r.winning.."   |   Winning tickets: "..winnerCount)
    or "Winning numbers: drawing pending")
end
function M:RefreshOfficer()
  if not GH:IsOfficer() then return end
  local r=GH.Lottery:GetCurrent()
  self.offStatus:SetText(r and ("Round "..r.status.."  |  Jackpot "..gold(r.jackpot).."  |  Draw "..clock(r.drawAt))
    or "No round open")
  self.newRound:SetEnabled(not r or r.status=="complete")
  self.close:SetEnabled(r and r.status=="open")
  self.execute:SetEnabled(r and r.status=="closed" and GH:Now()>=(r.drawAt or 0))
  self.complete:SetEnabled(r and r.status=="drawn")
  self.schedule:SetText(r and "Cutoff: "..clock(r.closesAt) or "")
  self.thresholds:SetText(r and table.concat(r.thresholds,",") or "5,15,30,50,75,100")
  self.payoutButton:Hide();self.pendingPayout=nil
  if not r then
    self.payout:SetText("No payments to report")
    setRows(self.officerRows,self.officerContent,{},function() end,function() end)
    return
  end
  local all={}
  local names={}
  for name in pairs(r.payments) do names[name]=true end
  for name in pairs(r.requests) do names[name]=true end
  for name in pairs(names) do all[#all+1]=name end
  table.sort(all)
  local pending=0
  for name in pairs(r.requests) do if not r.payments[name] then pending=pending+1 end end
  self.members:SetText("Participants "..#all.."  |  Pending payments "..pending.."  |  Click a player to confirm payment")
  setRows(self.officerRows,self.officerContent,all,function(name)
    local paid=r.payments[name]~=nil
    local n=0
    for _,t in pairs(r.tickets) do if t.owner==name then n=n+1 end end
    return (paid and "|cff73d873PAID|r " or "|cffffc050PENDING|r ")..
      name.."  |  kills "..(r.kills[name] or 0).."  |  tickets "..n
  end,function(name)
    M.paymentName:SetText(name);M.killName:SetText(name)
  end)
  local pendingPayout
  for ticketId,p in pairs(r.payouts or {}) do
    if not p.paid then pendingPayout=ticketId;break end
  end
  if pendingPayout then
    local p=r.payouts[pendingPayout]
    self.pendingPayout=pendingPayout
    self.payout:SetText("Next payout: "..p.owner.."   |   "..gold(p.amount))
    self.payoutButton:SetText("Mark this ticket paid")
    self.payoutButton:Show()
  else
    self.payout:SetText(r.status=="drawn" and "All recorded payouts confirmed" or
      (r.winning and ("Winning numbers: "..r.winning.."  |  Rollover "..gold(r.rolloverOut)) or "Draw not yet completed"))
  end
end
function M:RefreshHistory()
  local lines={}
  local rounds={}
  for _,r in pairs(GH.db.lottery.rounds) do rounds[#rounds+1]=r end
  table.sort(rounds,function(a,b) return (a.created or 0)>(b.created or 0) end)
  for _,r in ipairs(rounds) do
    lines[#lines+1]={label=clock(r.created).." | "..r.status.." | Jackpot "..gold(r.jackpot),round=r}
    lines[#lines+1]={label="    Draw: "..(r.winning or "pending").." | Rollover: "..gold(r.rolloverOut or 0)}
    for id,p in pairs(r.payouts or {}) do
      lines[#lines+1]={label="    "..p.owner.." won "..gold(p.amount).." ["..(p.paid and "PAID" or "UNPAID").."]"}
    end
    for i=math.max(1,#(r.audit or {})-4),#(r.audit or {}) do
      local log=r.audit[i]
      lines[#lines+1]={label="      "..clock(log.at).."  "..log.action.." "..(log.details or "")}
    end
  end
  setRows(self.historyRows,self.historyContent,lines,function(line) return line.label end,function() end)
end
function M:RefreshUI()
  if self.frame and self.frame:IsShown() then self:ShowPage(self.page) end
end
