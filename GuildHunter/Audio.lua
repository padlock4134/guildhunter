local GH=GuildHunter
local M={}
GH:RegisterModule("Audio",M)
local soundPath="Interface\\AddOns\\GuildHunter\\Sounds\\TicketEarned.ogg"
function M:Initialize() end
function M:OnTicketCreated(ticket)
 if ticket.owner~=GH:SelfName() or not GH.db.settings.ticketSound then return end
 if PlaySoundFile then pcall(PlaySoundFile,soundPath,"Master") end
end
