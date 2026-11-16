local GH=GuildHunter
local M={}
GH:RegisterModule("LotteryUI",M)
local function label(parent,text,x,y)
 local l=parent:CreateFontString(nil,"OVERLAY","GameFontHighlight")
 l:SetPoint("TOPLEFT",x,y);l:SetText(text);l:SetWidth(440);l:SetJustifyH("LEFT")
 return l
end
local function button(parent,title,x,y,width,fn)
 local b=CreateFrame("Button",nil,parent,"UIPanelButtonTemplate")
 b:SetSize(width or 120,24);b:SetPoint("TOPLEFT",x,y);b:SetText(title)
 b:SetScript("OnClick",fn);return b
end
local function edit(parent,x,y)
 local e=CreateFrame("EditBox",nil,parent,"InputBoxTemplate")
 e:SetAutoFocus(false);e:SetSize(190,24);e:SetPoint("TOPLEFT",x,y)
 e:SetScript("OnEscapePressed",function(s) s:ClearFocus() end)
 return e
end
function M:Initialize()
 local f=CreateFrame("Frame","GuildHunterLotteryWindow",UIParent)
 f:SetSize(520,490);f:SetPoint("CENTER")
 f:SetFrameStrata("DIALOG");f:EnableMouse(true)
 f:SetMovable(true);f:RegisterForDrag("LeftButton")
 f:SetScript("OnDragStart",function(s) s:StartMoving() end)
 f:SetScript("OnDragStop",function(s) s:StopMovingOrSizing() end)
 f:SetBackdrop({bgFile="Interface\\DialogFrame\\UI-DialogBox-Background",
 edgeFile="Interface\\DialogFrame\\UI-DialogBox-Border",tile=true,tileSize=32,edgeSize=32,
 insets={left=10,right=10,top=10,bottom=10}})
 self.frame=f;self.widgets={}
 label(f,"irønclad Weekly Lottery",20,-19)
 button(f,"X",470,-14,32,function() f:Hide() end)
 f:Hide()
end
function M:Clear()
 for _,w in ipairs(self.widgets) do w:Hide();w:SetParent(nil) end
 self.widgets={}
end
function M:Add(w) self.widgets[#self.widgets+1]=w return w end
function M:Open()
 self.frame:Show();self:Render()
end
function M:RefreshUI()
 if self.frame and self.frame:IsShown() then self:Render() end
end
function M:Render()
 self:Clear()
 local r=GH.Lottery.current
 local f=self.frame
 local y=-62
 if not r then
  self:Add(label(f,"No active lottery round.",25,y))
  if GH:IsOfficer() then self:Add(button(f,"Open Round",25,y-36,145,function()
   GH.Lottery:NewRound();self:Render()
  end)) end
  return
 end
 self:Add(label(f,"Status: "..r.state.."  |  Jackpot: "..string.format("%.2f",(r.jackpot or 0)/10000).."g",25,y))
 self:Add(label(f,"Round: "..r.id,25,y-26))
 self:Add(label(f,"Draw: "..date("%Y-%m-%d %H:%M",r.drawTime or GH:Now()),25,y-51))
 local paid=0;local tickets=0
 for _ in pairs(r.payments) do paid=paid+1 end
 for _ in pairs(r.tickets) do tickets=tickets+1 end
 self:Add(label(f,"Paid players: "..paid.."   Tickets: "..tickets,25,y-77))
 local me=GH:SelfName()
 local kills=r.kills[me] or 0
 local nextThreshold
 for _,t in ipairs(r.thresholds) do if kills<t then nextThreshold=t;break end end
 self:Add(label(f,"My Horde kills: "..kills.." | Next milestone: "..tostring(nextThreshold or "Complete"),25,y-103))
 local mine={}
 for _,ticket in pairs(r.tickets) do if ticket.owner==me then mine[#mine+1]=ticket end end
 table.sort(mine,function(a,b) return a.id<b.id end)
 self:Add(label(f,"My tickets:",25,y-133))
 for i=1,math.min(5,#mine) do
  local ticket=mine[i]
  self:Add(label(f,ticket.numbers.."  ("..ticket.source..")",35,y-133-i*23))
 end
 self:Add(label(f,"Winning numbers: "..(r.winning or "Pending"),25,-345))
 if GH:IsOfficer() then
  if r.state=="open" then
   self:Add(label(f,"Confirm in-game 5g trade for:",25,-369))
   local player=self:Add(edit(f,25,-391))
   self:Add(button(f,"Confirm 5g",230,-391,120,function()
    GH.Lottery:ConfirmPayment(player:GetText())
    self:Render()
   end))
   self:Add(button(f,"Close entries",363,-391,123,function()
    GH.Lottery:CloseEntries();self:Render()
   end))
  elseif r.state=="closed" then
   self:Add(button(f,"Draw numbers",25,-390,145,function() GH.Lottery:Draw();self:Render() end))
  elseif r.state=="drawn" then
   local allPaid=true
   for id,p in pairs(r.payouts) do
    if not p.paid then allPaid=false
     self:Add(button(f,"Paid: "..p.owner,25,-390,200,function()
      GH.Lottery:ConfirmPayout(id);self:Render()
     end))
     break
    end
   end
   if allPaid then self:Add(button(f,"Complete round",25,-425,160,function()
    GH.Lottery:CompleteRound();self:Render()
   end)) end
  elseif r.state=="complete" then
   self:Add(button(f,"Next round",25,-405,150,function()
    GH.Lottery:NewRound();self:Render()
   end))
  end
 end
end
