local GH=GuildHunter
local M={page="kos",rows={},selected=nil}
GH:RegisterModule("UI",M)
local function button(parent,text,x,y,w,handler)
  local b=CreateFrame("Button",nil,parent,"UIPanelButtonTemplate")
  b:SetSize(w or 100,25)
  b:SetPoint("TOPLEFT",x,y)
  b:SetText(text)
  b:SetScript("OnClick",handler)
  return b
end
local function input(parent,x,y,w)
  local e=CreateFrame("EditBox",nil,parent,"InputBoxTemplate")
  e:SetSize(w or 190,26)
  e:SetPoint("TOPLEFT",x,y)
  e:SetAutoFocus(false)
  e:SetScript("OnEscapePressed",function(self) self:ClearFocus() end)
  return e
end
local function label(parent,x,y,text)
  local t=parent:CreateFontString(nil,"OVERLAY","GameFontNormal")
  t:SetPoint("TOPLEFT",x,y)
  t:SetText(text or "")
  t:SetJustifyH("LEFT")
  return t
end
M.Button=button
M.Input=input
M.Label=label
function M:Initialize()
  local cfg=GH.db.windows
  local f=CreateFrame("Frame","GuildHunterWindow",UIParent,"BackdropTemplate")
  f:SetSize(730,550)
  f:SetPoint("CENTER",UIParent,"CENTER",cfg.mainX or 0,cfg.mainY or 0)
  f:SetFrameStrata("DIALOG")
  f:SetBackdrop({bgFile="Interface\\DialogFrame\\UI-DialogBox-Background",
    edgeFile="Interface\\DialogFrame\\UI-DialogBox-Border",tile=true,tileSize=32,edgeSize=32,
    insets={left=12,right=12,top=12,bottom=12}})
  f:EnableMouse(true);f:SetMovable(true);f:RegisterForDrag("LeftButton")
  f:SetScript("OnDragStart",function(self) self:StartMoving() end)
  f:SetScript("OnDragStop",function(self)
    self:StopMovingOrSizing()
    local _,_,_,x,y=self:GetPoint()
    cfg.mainX=x;cfg.mainY=y
  end)
  local title=label(f,23,-22,"GuildHunter | irønclad")
  title:SetFontObject("GameFontNormalLarge")
  button(f,"X",678,-17,30,function() f:Hide() end)
  button(f,"KoS Players",22,-60,122,function() M:ShowPage("kos") end)
  button(f,"Enemy Guilds",150,-60,128,function() M:ShowPage("guilds") end)
  button(f,"Lottery",285,-60,98,function() GH.LotteryUI:Open() end)
  button(f,"Settings",390,-60,100,function() M:ShowPage("settings") end)
  button(f,"Sync",498,-60,90,function() GH.Sync:Request() end)
  local main=CreateFrame("Frame",nil,f)
  main:SetPoint("TOPLEFT",25,-106)
  main:SetPoint("BOTTOMRIGHT",-25,25)
  self.frame=f;self.main=main
  self:BuildRecords()
  self:BuildSettings()
  self:ShowPage("kos")
  f:Hide()
end
function M:BuildRecords()
  local p=CreateFrame("Frame",nil,self.main)
  p:SetAllPoints()
  self.recordPage=p
  label(p,5,-8,"Player or guild name")
  label(p,240,-8,"Reason for KoS")
  label(p,490,-8,"Filter")
  self.name=input(p,5,-27,221)
  self.reason=input(p,240,-27,235)
  self.search=input(p,490,-27,170)
  self.search:SetScript("OnTextChanged",function() M:RefreshRows() end)
  self.addBtn=button(p,"Add record",5,-64,110,function()
    local name=M.name:GetText()
    local reason=M.reason:GetText()
    if M.page=="guilds" then GH.KOS:AddGuild(name,reason)
    else GH.KOS:AddPlayer(name,nil,nil,reason) end
    M.selected=nil;M.name:SetText("");M.reason:SetText("");M:RefreshRows()
  end)
  self.targetBtn=button(p,"Add target",122,-64,112,function()
    GH.KOS:AddTarget();M:RefreshRows()
  end)
  self.guildTargetBtn=button(p,"Target guild",241,-64,112,function()
    GH.KOS:AddTargetGuild();M:RefreshRows()
  end)
  self.editBtn=button(p,"Save reason",360,-64,111,function()
    if M.selected then GH.KOS:Update(M.page=="guilds" and "G" or "K",M.selected,M.reason:GetText()) end
    M:RefreshRows()
  end)
  self.deleteBtn=button(p,"Remove",478,-64,88,function()
    if M.selected then
      GH.KOS:Remove(M.page=="guilds" and "G" or "K",M.selected)
      M.selected=nil;M.name:SetText("");M.reason:SetText("");M:RefreshRows()
    end
  end)
  self.details=label(p,8,-105,"Select a record to view its details and edit the reason.")
  self.details:SetWidth(638)
  self.scroll=CreateFrame("ScrollFrame",nil,p,"UIPanelScrollFrameTemplate")
  self.scroll:SetPoint("TOPLEFT",5,-140)
  self.scroll:SetPoint("BOTTOMRIGHT",-34,5)
  local content=CreateFrame("Frame",nil,self.scroll)
  content:SetSize(620,240)
  self.scroll:SetScrollChild(content)
  self.list=content
end
function M:BuildSettings()
  local p=CreateFrame("Frame",nil,self.main)
  p:SetAllPoints()
  self.settingsPage=p
  label(p,6,-8,"Saved settings")
  local options={
    {"KoS detection alerts","kosAlerts"},
    {"Enemy-guild alerts","guildAlerts"},
    {"Built-in alert sound","audioAlerts"},
    {"Lottery ticket sound","ticketSound"},
    {"Show enemy tracker","trackerVisible"},
  }
  self.settingsButtons={}
  for i,opt in ipairs(options) do
    local key=opt[2]
    local b=button(p,"",7,-42-(i-1)*38,420,function() GH.Settings:Toggle(key) end)
    self.settingsButtons[i]={button=b,text=opt[1],key=key}
  end
  self.lock=button(p,"",7,-247,420,function() GH.Settings:ToggleLock() end)
  label(p,9,-296,"All data and window locations are saved between logins.")
  label(p,9,-319,"Guild records sync only while connected to irønclad.")
  label(p,9,-342,"Lottery gold is traded manually; officer confirms the payment.")
end
function M:ShowPage(page)
  self.page=page or "kos"
  local settings=(self.page=="settings")
  self.recordPage:SetShown(not settings)
  self.settingsPage:SetShown(settings)
  if settings then self:RefreshSettings() else
    self.selected=nil
    self:RefreshRows()
  end
end
function M:Open(page)
  self.frame:Show()
  self:ShowPage(page or "kos")
end
function M:FillTarget(name)
  self.name:SetText(name or "")
  local record=GH.KOS:FindPlayer(nil,name)
  if record then
    self.selected=record.id
    self.reason:SetText(record.reason or "")
    self:RefreshRows()
  end
end
function M:RefreshSettings()
  for _,item in ipairs(self.settingsButtons) do
    item.button:SetText((GH.db.settings[item.key] and "[ON]  " or "[OFF] ")..item.text)
  end
  self.lock:SetText((GH.db.tracker.locked and "[LOCKED]" or "[UNLOCKED]").."  PvP tracker")
end
function M:RefreshRows()
  if not self.list or self.page=="settings" then return end
  local isGuild=self.page=="guilds"
  self.targetBtn:SetShown(not isGuild)
  self.guildTargetBtn:SetShown(isGuild)
  local filter=GH:Normalize(self.search:GetText() or "") or ""
  local source=isGuild and GH.db.guilds or GH.db.kos
  local records={}
  for _,r in pairs(source) do
    local needle=(r.name or "").." "..(r.reason or "").." "..(r.guild or "")
    if filter=="" or (GH:Normalize(needle) or ""):find(filter,1,true) then
      records[#records+1]=r
    end
  end
  table.sort(records,function(a,b) return (a.name or "")<(b.name or "") end)
  self.list:SetHeight(math.max(200,#records*27+3))
  for i,r in ipairs(records) do
    local row=self.rows[i]
    if not row then
      row=CreateFrame("Button",nil,self.list)
      row:SetHeight(25)
      row:SetPoint("TOPLEFT",5,-(i-1)*27)
      row:SetPoint("TOPRIGHT",-4,-(i-1)*27)
      row.text=row:CreateFontString(nil,"OVERLAY","GameFontHighlight")
      row.text:SetAllPoints();row.text:SetJustifyH("LEFT")
      self.rows[i]=row
    end
    local selected=r.id==self.selected
    row.text:SetText((selected and "|cffffd34d> " or "  ")..(r.name or "")..
      "  |cffaaaaaa"..(r.reason or "").."|r")
    row:SetScript("OnClick",function()
      M.selected=r.id
      M.name:SetText(r.name or "")
      M.reason:SetText(r.reason or "")
      local extra=isGuild and ("Known members: "..tostring(function() local n=0;for _ in pairs(r.members or {}) do n=n+1 end;return n end)())
       or ("Guild: "..(r.guild or "Unknown").." | Class: "..(r.class or "?")..
         " | Level: "..tostring(r.level or "?").." | Added by: "..(r.addedBy or "?"))
      M.details:SetText(extra)
      M:RefreshRows()
    end)
    row:Show()
  end
  for i=#records+1,#self.rows do self.rows[i]:Hide() end
  self.editBtn:SetEnabled(self.selected~=nil)
  self.deleteBtn:SetEnabled(self.selected~=nil)
end
function M:RefreshUI()
  if not self.frame or not self.frame:IsShown() then return end
  if self.page=="settings" then self:RefreshSettings() else self:RefreshRows() end
end
