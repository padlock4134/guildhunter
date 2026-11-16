local GH=GuildHunter
local M={page="kos"}
GH:RegisterModule("UI",M)
local function button(parent,text,x,y,width,callback)
 local b=CreateFrame("Button",nil,parent,"UIPanelButtonTemplate")
 b:SetSize(width or 95,24);b:SetPoint("TOPLEFT",x,y)
 b:SetText(text);b:SetScript("OnClick",callback)
 return b
end
local function edit(parent,x,y,width)
 local e=CreateFrame("EditBox",nil,parent,"InputBoxTemplate")
 e:SetSize(width or 210,24);e:SetPoint("TOPLEFT",x,y)
 e:SetAutoFocus(false)
 e:SetScript("OnEscapePressed",function(self) self:ClearFocus() end)
 return e
end
local function label(parent,text,x,y)
 local l=parent:CreateFontString(nil,"OVERLAY","GameFontNormal")
 l:SetPoint("TOPLEFT",x,y);l:SetText(text)
 return l
end
function M:Initialize()
 local f=CreateFrame("Frame","GuildHunterWindow",UIParent)
 f:SetSize(600,470);f:SetPoint("CENTER")
 f:SetFrameStrata("DIALOG");f:EnableMouse(true);f:SetMovable(true)
 f:RegisterForDrag("LeftButton")
 f:SetScript("OnDragStart",function(self) self:StartMoving() end)
 f:SetScript("OnDragStop",function(self) self:StopMovingOrSizing() end)
 f:SetBackdrop({bgFile="Interface\\DialogFrame\\UI-DialogBox-Background",
  edgeFile="Interface\\DialogFrame\\UI-DialogBox-Border",tile=true,tileSize=32,edgeSize=32,
  insets={left=11,right=12,top=12,bottom=11}})
 label(f,"GuildHunter — irønclad",22,-18)
 button(f,"X",554,-14,30,function() f:Hide() end)
 button(f,"KoS",20,-50,75,function() M:Open("kos") end)
 button(f,"Guilds",100,-50,75,function() M:Open("guilds") end)
 button(f,"Lottery",180,-50,85,function() GH.LotteryUI:Open() end)
 button(f,"Settings",270,-50,85,function() M:Open("settings") end)
 local body=CreateFrame("Frame",nil,f)
 body:SetPoint("TOPLEFT",20,-92);body:SetPoint("BOTTOMRIGHT",-20,16)
 self.body=body
 self.widgets={}
 self.frame=f;f:Hide()
end
function M:Clear()
 for _,w in ipairs(self.widgets) do w:Hide();w:SetParent(nil) end
 self.widgets={}
end
function M:Add(w)
 self.widgets[#self.widgets+1]=w
 return w
end
function M:Open(page)
 self.page=page or "kos"
 self.frame:Show()
 self:Render()
end
function M:RefreshUI()
 if self.frame and self.frame:IsShown() then self:Render() end
end
function M:Render()
 self:Clear()
 local body=self.body
 if self.page=="settings" then
  local keys={{"KoS alerts","kosAlerts"},{"Enemy guild alerts","guildAlerts"},
  {"Audio alerts","audioAlerts"},{"Ticket sound","ticketSound"},{"Show tracker","trackerVisible"}}
  for i,item in ipairs(keys) do
   local key=item[2]
   self:Add(button(body,(GH.db.settings[key] and "[ON] " or "[OFF] ")..item[1],
    8,-(i-1)*39,300,function() GH.Settings:Toggle(key) end))
  end
  return
 end
 local isGuild=self.page=="guilds"
 self:Add(label(body,isGuild and "Enemy guilds" or "Kill on Sight",8,-4))
 local name=self:Add(edit(body,10,-35,220))
 local reason=self:Add(edit(body,240,-35,190))
 self:Add(label(body,"Name",12,-21));self:Add(label(body,"Reason",240,-21))
 self:Add(button(body,"Add",440,-35,100,function()
  local n=name:GetText();local why=reason:GetText()
  if isGuild then GH.KOS:AddGuild(n,why)
  else GH.KOS:AddPlayer(n,nil,nil,why) end
  self:Render()
 end))
 if not isGuild then
  self:Add(button(body,"Add target",10,-72,125,function() GH.KOS:AddTarget() end))
  self:Add(button(body,"Target guild",145,-72,125,function()
   if UnitExists("target") then
    local g=GetGuildInfo and GetGuildInfo("target")
    if g then GH.KOS:AddGuild(g,"") else GH:Print("Target has no visible guild") end
   end
  end))
 end
 local records=isGuild and GH.db.guilds or GH.db.kos
 local ordered={}
 for _,r in pairs(records) do ordered[#ordered+1]=r end
 table.sort(ordered,function(a,b) return (a.name or "")<(b.name or "") end)
 local offset=isGuild and -93 or -119
 for i=1,math.min(#ordered,9) do
  local r=ordered[i]
  local line=self:Add(label(body,(r.name or "?").." — "..(r.reason or ""),12,offset-(i-1)*26))
  line:SetWidth(410);line:SetJustifyH("LEFT")
  self:Add(button(body,"Remove",450,offset+7-(i-1)*26,85,function()
   GH.KOS:Remove(isGuild and "G" or "K",r.id)
  end))
 end
end
