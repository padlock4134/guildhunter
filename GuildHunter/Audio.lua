local GH=GuildHunter
local M={}
GH:RegisterModule("Audio",M)
local ticketSound="Interface\\AddOns\\GuildHunter\\Sounds\\TicketEarned.ogg"
function M:Initialize() end
function M:TicketCreated(ticket)
  if not ticket or GH:Normalize(ticket.owner)~=GH:Normalize(GH:PlayerName()) then return false end
  if GH.db.audioPlayed[ticket.id] then return false end
  GH.db.audioPlayed[ticket.id]=GH:Now()
  -- The optional audio file is supplied by the user after installation.
  if GH.db.settings.ticketSound and PlaySoundFile then
    pcall(PlaySoundFile,ticketSound,"Master")
  end
  local entries=0
  for _ in pairs(GH.db.audioPlayed) do entries=entries+1 end
  if entries>2500 then
    for k,t in pairs(GH.db.audioPlayed) do
      if GH:Now()-(t or 0)>60*60*24*120 then GH.db.audioPlayed[k]=nil end
    end
  end
  return true
end
