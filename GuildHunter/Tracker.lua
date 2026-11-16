local GH=GuildHunter
local M={rows={},offset=0}
GH:RegisterModule("Tracker",M)
local function btn(parent,caption,width)
  local b=CreateFrame("Button",nil,parent,"UIPanelButtonTemplate")
  b:SetSize(width,22);b:SetText(caption);return b
end
function M:Initialize()
  local c=GH.db.tracker
  local f=CreateFrame("Frame","GuildHunterTracker",UIParent,"BackdropTemplate")
  f:SetSize(c.width,c.minimized and 37 or c.height)
  f:SetPoint(c.point or "CENTER",UIParent,c.point or "CENTER",c.x or 210,c.y or 30)
  f:SetFrameStrata("MEDIUM")
  f:SetBackdrop({bgFile="Interface\\DialogFrame\\UI-DialogBox-Background",
    edgeFile="Interface\\Tooltips\\UI-Tooltip-Border",tile=true,tileSize=16,edgeSize=16,
    insets={left=5,right=5,top=5,bottom=5}})
  f:SetMovable(true);f:EnableMouse(true)
  f:RegisterForDrag("LeftButton")
  f:SetScript("OnDragStart",function(frame)
    if not c.locked then frame:StartMoving() end
  end)
  f:SetScript("OnDragStop",function(frame)
    frame:StopMovingOrSizing()
    local point,_,_,x,y=frame:GetPoint()
    c.point=point;c.x=x;c.y=y
  end)
  local title=f:CreateFontString(nil,"OVERLAY","GameFontNormal")
  title:SetPoint("TOPLEFT",12,-12)
  title:SetText("GuildHunter | PvP")
  self.title=title
  local minimize=btn(f,"_",23)
  minimize:SetPoint("TOPRIGHT",-7,-8)
  minimize:SetScript("OnClick",function() M:Minimize() end)
  local lock=btn(f,"L",25)
  lock:SetPoint("TOPRIGHT",-36,-8)
  lock:SetScript("OnClick",function()
    c.locked=not c.locked
    lock:SetText(c.locked and "U" or "L")
  end)
  lock:SetText(c.locked and "U" or "L")
  local scroll=CreateFrame("ScrollFrame",nil,f,"UIPanelScrollFrameTemplate")
  scroll:SetPoint("TOPLEFT",9,-41)
  scroll:SetPoint("BOTTOMRIGHT",-28,14)
  local content=CreateFrame("Frame",nil,scroll)
  content:SetSize(250,250)
  scroll:SetScrollChild(content)
  self.scroll=scroll;self.content=content
  local grip=CreateFrame("Button",nil,f)
  grip:SetSize(17,17);grip:SetPoint("BOTTOMRIGHT",-3,3)
  grip:EnableMouse(true)
  grip:SetNormalTexture("Interface\\ChatFrame\\UI-ChatIM-SizeGrabber-Up")
  grip:SetHighlightTexture("Interface\\ChatFrame\\UI-ChatIM-SizeGrabber-Highlight")
  grip:SetPushedTexture("Interface\\ChatFrame\\UI-ChatIM-SizeGrabber-Down")
  if f.SetResizable then f:SetResizable(true) end
  if f.SetResizeBounds then f:SetResizeBounds(225,150,540,660)
  elseif f.SetMinResize then f:SetMinResize(225,150);f:SetMaxResize(540,660) end
  grip:SetScript("OnMouseDown",function()
    if not c.locked and not c.minimized then f:StartSizing("BOTTOMRIGHT") end
  end)
  grip:SetScript("OnMouseUp",function() f:StopMovingOrSizing() end)
  f:SetScript("OnSizeChanged",function(_,w,h)
    if not c.minimized then
      c.width=math.floor(w+0.5);c.height=math.floor(h+0.5)
    end
  end)
  self.frame=f;self.grip=grip
  if c.minimized then scroll:Hide();grip:Hide() end
  if not GH.db.settings.trackerVisible then f:Hide() end
  self:RefreshTracker()
end
function M:Minimize()
  local c=GH.db.tracker
  c.minimized=not c.minimized
  if c.minimized then self.scroll:Hide();self.grip:Hide();self.frame:SetHeight(37)
  else self.frame:SetHeight(c.height);self.scroll:Show();self.grip:Show() end
end
function M:Toggle()
  GH.db.settings.trackerVisible=not GH.db.settings.trackerVisible
  self.frame:SetShown(GH.db.settings.trackerVisible)
end
function M:RefreshTracker()
  if not self.content then return end
  local list={}
  for _,record in pairs(GH.db.seen) do
    if GH:Now()-(record.lastSeen or 0)<1800 then
      -- Compute priority from latest KoS records, not a stale snapshot flag.
      record.kos=GH.KOS:FindPlayer(record.guid,record.name)~=nil
      record.guildKos=GH.KOS:FindGuild(record.guild)~=nil
      list[#list+1]=record
    end
  end
  table.sort(list,function(a,b)
    local ka=a.kos and 2 or a.guildKos and 1 or 0
    local kb=b.kos and 2 or b.guildKos and 1 or 0
    if ka~=kb then return ka>kb end
    return (a.lastSeen or 0)>(b.lastSeen or 0)
  end)
  self.content:SetHeight(math.max(#list*27,35))
  self.content:SetWidth(math.max(195,self.frame:GetWidth()-55))
  for i,record in ipairs(list) do
    local row=self.rows[i]
    if not row then
      row=CreateFrame("Button",nil,self.content)
      row:SetHeight(25)
      row:SetPoint("TOPLEFT",3,-(i-1)*27)
      row:SetPoint("TOPRIGHT",-4,-(i-1)*27)
      row.text=row:CreateFontString(nil,"OVERLAY","GameFontHighlightSmall")
      row.text:SetAllPoints();row.text:SetJustifyH("LEFT")
      self.rows[i]=row
    end
    local flag=record.kos and "|cffff5151KoS|r " or record.guildKos and "|cffffa531Guild|r " or ""
    local age=math.floor((GH:Now()-(record.lastSeen or 0))/60)
    row.text:SetText(flag..(record.name or "Unknown").."  "..(record.level or "?")..
      "  "..(record.guild or "").."  |cff999999"..age.."m|r")
    row:SetScript("OnClick",function()
      if record.name then
        GH.UI:Open("kos")
        GH.UI:FillTarget(record.name)
      end
    end)
    row:Show()
  end
  for i=#list+1,#self.rows do self.rows[i]:Hide() end
end
