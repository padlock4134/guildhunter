local GH = CreateFrame("Frame", "GuildHunterEventFrame")
GuildHunter = GH
GH.modules = {}
GH.ready = false
GH.prefix = "GHForever1"
GH.player = nil

function GH:RegisterModule(name, module)
  self.modules[name] = module
  self[name] = module
end

function GH:Print(message)
  DEFAULT_CHAT_FRAME:AddMessage("|cffFFD344GuildHunter|r: " .. tostring(message))
end

function GH:Now()
  return time()
end

function GH:SelfName()
  return UnitName("player") or "Unknown"
end

function GH:IsOfficer()
  if not IsInGuild or not IsInGuild() then return false end
  local myName = self:SelfName()
  if GetGuildRosterInfo then
    for i=1,(GetNumGuildMembers and GetNumGuildMembers() or 0) do
      local name,rank,rankIndex = GetGuildRosterInfo(i)
      if name and (name == myName or name:match("^[^-]+") == myName) then
        return rankIndex ~= nil and rankIndex <= (self.db and self.db.officerRankMax or 1)
      end
    end
  end
  return false
end

function GH:Emit(event, ...)
  for _,module in pairs(self.modules) do
    if module[event] then
      local ok,err = pcall(module[event], module, ...)
      if not ok then self:Print("Module error: "..tostring(err)) end
    end
  end
end

function GH:OnTicketCreated(ticket)
  self:Emit("OnTicketCreated", ticket)
end

function GH:Initialize()
  if self.ready then return end
  self.player = self:SelfName()
  self.Database:Initialize()
  for _,name in ipairs({"KOS","Detection","Tracker","Sync","Lottery","KillTracker","Audio","Settings","UI","LotteryUI"}) do
    local module=self.modules[name]
    if module and module.Initialize then
      local ok,err=pcall(module.Initialize,module)
      if not ok then self:Print(name .. " failed: "..tostring(err)) end
    end
  end
  self.ready = true
  self:Print("Loaded. /gh for commands.")
end

GH:RegisterEvent("ADDON_LOADED")
GH:RegisterEvent("PLAYER_LOGIN")
GH:RegisterEvent("PLAYER_TARGET_CHANGED")
GH:RegisterEvent("UPDATE_MOUSEOVER_UNIT")
GH:RegisterEvent("COMBAT_LOG_EVENT_UNFILTERED")
GH:RegisterEvent("PARTY_KILL")
GH:RegisterEvent("CHAT_MSG_ADDON")
GH:RegisterEvent("GUILD_ROSTER_UPDATE")
GH:SetScript("OnEvent",function(self,event,...)
  if event == "ADDON_LOADED" then
    local addon = ...
    if addon == "GuildHunter" then self.addonLoaded = true end
    return
  end
  if event == "PLAYER_LOGIN" then self:Initialize() end
  if not self.ready then return end
  self:Emit("HandleEvent",event,...)
end)

SLASH_GUILDHUNTER1="/gh"
SLASH_GUILDHUNTER2="/guildhunter"
SlashCmdList.GUILDHUNTER=function(message)
  local cmd=(message or ""):lower():match("^%s*(%S*)") or ""
  if not GH.ready then GH:Print("Still loading") return end
  if cmd == "" then GH.UI:Open("kos")
  elseif cmd == "kos" or cmd == "guilds" or cmd == "settings" then GH.UI:Open(cmd)
  elseif cmd == "lottery" then GH.LotteryUI:Open()
  elseif cmd == "tracker" then GH.Tracker:Toggle()
  elseif cmd == "add" then GH.KOS:AddTarget()
  elseif cmd == "sync" then GH.Sync:Request()
  elseif cmd == "help" then GH:Print("/gh, kos, guilds, tracker, lottery, add, sync, settings, help")
  else GH:Print("Unknown command. /gh help") end
end
