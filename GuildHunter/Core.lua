local GH = CreateFrame("Frame", "GuildHunterEventFrame")
GuildHunter = GH
GH.guildName = "irønclad"
GH.prefix = "GHv100"
GH.modules = {}
GH.ready = false
GH.serial = 0

function GH:RegisterModule(name, module)
  self.modules[name] = module
  self[name] = module
end
function GH:Now()
  if GetServerTime then return GetServerTime() end
  return time()
end
function GH:ID(prefix)
  self.serial = self.serial + 1
  if self.db then
    self.db.idCounter = (self.db.idCounter or 0) + 1
  end
  local id = self.db and self.db.idCounter or self.serial
  return (prefix or "id") .. ":" .. tostring(self:Now()) .. ":" .. tostring(id) .. ":" .. self:PlayerName()
end
function GH:Safe(v)
  if v == nil then return nil end
  if issecretvalue and issecretvalue(v) then return nil end
  return v
end
function GH:UnitName(unit)
  if not UnitExists or not UnitExists(unit) then return nil end
  if GetUnitName then
    local ok, name = pcall(GetUnitName, unit, true)
    if ok and type(self:Safe(name)) == "string" and name ~= "" then return name end
  end
  local ok, first, last = pcall(UnitName, unit)
  if not ok or type(self:Safe(first)) ~= "string" then return nil end
  if type(self:Safe(last)) == "string" and last ~= "" then return first .. " " .. last end
  return first
end
function GH:PlayerName()
  return self:UnitName("player") or "Unknown"
end
function GH:Normalize(name)
  if type(name) ~= "string" then return nil end
  return (name:gsub("^%s+", ""):gsub("%s+$", ""):gsub("%s+", " "):lower())
end
function GH:Print(message)
  if DEFAULT_CHAT_FRAME then DEFAULT_CHAT_FRAME:AddMessage("|cffF5CC42GuildHunter|r: " .. tostring(message)) end
end
function GH:InGuild()
  if not IsInGuild or not IsInGuild() or not GetGuildInfo then return false end
  local name = self:Safe(GetGuildInfo("player"))
  return type(name) == "string" and self:Normalize(name) == self:Normalize(self.guildName)
end
function GH:Roster()
  if C_GuildInfo and C_GuildInfo.GuildRoster then pcall(C_GuildInfo.GuildRoster) end
end
function GH:MemberRank(name)
  if not self:InGuild() or not GetGuildRosterInfo or not GetNumGuildMembers then return nil end
  local seek = self:Normalize(name)
  if not seek then return nil end
  for i=1,GetNumGuildMembers() do
    local member, _, rank = GetGuildRosterInfo(i)
    if type(self:Safe(member)) == "string" and self:Normalize(member) == seek then
      return tonumber(self:Safe(rank))
    end
  end
  return nil
end
function GH:IsOfficer(name)
  local rank = self:MemberRank(name or self:PlayerName())
  return rank ~= nil and rank <= (self.db and self.db.officerRankMax or 1)
end
function GH:Fire(event, ...)
  for _, module in pairs(self.modules) do
    local fn = module[event]
    if type(fn) == "function" then
      local ok, err = pcall(fn, module, ...)
      if not ok then self:Print(event .. ": " .. tostring(err)) end
    end
  end
end
function GH:Refresh()
  self:Fire("RefreshUI")
  self:Fire("RefreshTracker")
end
function GH:Initialize()
  if self.ready then return end
  self.Database:Initialize()
  self:Roster()
  for _, name in ipairs({"KOS","Detection","Tracker","Sync","Lottery","KillTracker","Audio","Settings","UI","LotteryUI"}) do
    local module = self.modules[name]
    if module and module.Initialize then
      local ok, err = pcall(module.Initialize, module)
      if not ok then self:Print(name .. " initialization: " .. tostring(err)) end
    end
  end
  self.ready = true
  self:Print("Loaded. Type /gh for the main window.")
  if self:InGuild() then self.Sync:Request() end
end
GH:RegisterEvent("ADDON_LOADED")
GH:RegisterEvent("PLAYER_LOGIN")
GH:SetScript("OnEvent", function(self, event, ...)
  if event == "PLAYER_LOGIN" then self:Initialize(); return end
  if not self.ready then return end
  self:Fire("OnEvent", event, ...)
end)

SLASH_GUILDHUNTER1 = "/gh"
SLASH_GUILDHUNTER2 = "/guildhunter"
SlashCmdList.GUILDHUNTER = function(msg)
  if not GH.ready then GH:Print("Loading") return end
  local command = (msg or ""):match("^%s*(%S*)") or ""
  command = command:lower()
  if command == "" or command == "kos" then GH.UI:Open("kos")
  elseif command == "guilds" then GH.UI:Open("guilds")
  elseif command == "tracker" then GH.Tracker:Toggle()
  elseif command == "lottery" then GH.LotteryUI:Open()
  elseif command == "add" then GH.KOS:AddTarget()
  elseif command == "sync" then GH.Sync:Request()
  elseif command == "settings" then GH.UI:Open("settings")
  elseif command == "help" then GH:Print("/gh /gh kos /gh guilds /gh tracker /gh lottery /gh add /gh sync /gh settings")
  else GH:Print("Unknown command. Use /gh help") end
end
