local GH=GuildHunter
local M={}
GH:RegisterModule("Tracker",M)
function M:Initialize()
 local cfg=GH.db.tracker
 local f=CreateFrame("Frame","GuildHunterTracker",UIParent)
 f:SetWidth(cfg.width);f:SetHeight(cfg.height)
 f:SetPoint(cfg.point,UIParent,cfg.relativePoint,cfg.x,cfg.y)
 f:SetBackdrop({bgFile="Interface\\DialogFrame\\UI-DialogBox-Background",
  edgeFile="Interface\\Tooltips\\UI-Tooltip-Border",tile=true,tileSize=16,edgeSize=16,
  insets={left=4,right=4,top=4,bottom=4}})
 f:SetMovable(true);f:EnableMouse(true);f:SetResizable(true)
 f:RegisterForDrag("LeftButton")
 f:SetScript("OnDragStart",function(frame) if not GH.db.tracker.locked then frame:StartMoving() end end)
 f:SetScript("OnDragStop",function(frame)
  frame:StopMovingOrSizing()
  local point,_,relative,x,y=frame:GetPoint()
  cfg.point=point;cfg.relativePoint=relative;cfg.x=x;cfg.y=y
 end)
 local title=f:CreateFontString(nil,"OVERLAY","GameFontNormal")
 title:SetPoint("TOPLEFT",12,-12);title:SetText("GuildHunter — Enemies")
 local minimize=CreateFrame("Button",nil,f,"UIPanelButtonTemplate")
 minimize:SetSize(23,20);minimize:SetPoint("TOPRIGHT",-7,-5)
 minimize:SetText("_")
 minimize:SetScript("OnClick",function()
  cfg.minimized=not cfg.minimized
  f:SetHeight(cfg.minimized and 35 or cfg.height)
  M.body:SetShown(not cfg.minimized)
 end)
 local body=CreateFrame("Frame",nil,f)
 body:SetPoint("TOPLEFT",8,-38);body:SetPoint("BOTTOMRIGHT",-8,8)
 M.body=body
 local rows={}
 for i=1,9 do
  local b=CreateFrame("Button",nil,body)
  b:SetHeight(23);b:SetPoint("TOPLEFT",5,-(i-1)*24);b:SetPoint("TOPRIGHT",-5,-(i-1)*24)
  local label=b:CreateFontString(nil,"OVERLAY","GameFontHighlightSmall")
  label:SetPoint("LEFT",2,0);label:SetJustifyH("LEFT")
  b.label=label;rows[i]=b
 end
 M.rows=rows;M.frame=f
 if not GH.db.settings.trackerVisible then f:Hide() end
 body:SetShown(not cfg.minimized)
 if cfg.minimized then f:SetHeight(35) end
 self:RefreshTracker()
end
function M:RefreshTracker()
 if not self.frame then return end
 local all={}
 for _,r in pairs(GH.db.seen) do
  if GH:Now()-(r.lastSeen or 0)<1800 then all[#all+1]=r end
 end
 table.sort(all,function(a,b)
  local ap=(a.kos and 2 or a.guildKos and 1 or 0)
  local bp=(b.kos and 2 or b.guildKos and 1 or 0)
  if ap~=bp then return ap>bp end
  return (a.lastSeen or 0)>(b.lastSeen or 0)
 end)
 for i,b in ipairs(self.rows) do
  local r=all[i]
  if r then
   b:Show()
   local color=r.kos and "|cffff4444" or r.guildKos and "|cffffa500" or "|cffffffff"
   b.label:SetText(color..(r.name or "?").." "..(r.level or "?").." "..(r.guild or "").."|r")
  else b:Hide() end
 end
end
function M:Toggle()
 GH.db.settings.trackerVisible=not GH.db.settings.trackerVisible
 if GH.db.settings.trackerVisible then self.frame:Show() else self.frame:Hide() end
end
