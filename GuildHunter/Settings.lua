local GH=GuildHunter
local M={}
GH:RegisterModule("Settings",M)
function M:Initialize() end
function M:Toggle(key)
  if GH.db.settings[key]==nil then return end
  GH.db.settings[key]=not GH.db.settings[key]
  if key=="trackerVisible" and GH.Tracker.frame then
    GH.Tracker.frame:SetShown(GH.db.settings[key])
  end
  GH:Refresh()
end
function M:ToggleLock()
  GH.db.tracker.locked=not GH.db.tracker.locked
  GH:Refresh()
end
