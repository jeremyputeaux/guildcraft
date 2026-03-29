-- GuildCraft — Core.lua
-- Namespace, initialisation, gestion des events

GuildCraft = {}
local GC = GuildCraft

GC.PREFIX   = "GCRAFT"
GC.VERSION  = 1

-- Timer sans dependance a C_Timer (compatible TBC/Wrath/Cata)
function GC:After(delay, callback)
    local elapsed = 0
    local f = CreateFrame("Frame")
    f:SetScript("OnUpdate", function(self, dt)
        elapsed = elapsed + dt
        if elapsed >= delay then
            self:SetScript("OnUpdate", nil)
            callback()
        end
    end)
end

-- Enregistrement du prefix (requis Cata+, sans effet sur TBC/Wrath)
if RegisterAddonMessagePrefix then
    RegisterAddonMessagePrefix(GC.PREFIX)
end

-- Frame principal d'events
local eventFrame = CreateFrame("Frame", "GuildCraftEventFrame")

eventFrame:RegisterEvent("PLAYER_LOGIN")
eventFrame:RegisterEvent("CHAT_MSG_ADDON")
eventFrame:RegisterEvent("GUILD_ROSTER_UPDATE")
eventFrame:RegisterEvent("TRADE_SKILL_SHOW")
eventFrame:RegisterEvent("TRADE_SKILL_UPDATE")
eventFrame:RegisterEvent("LEARNED_SPELL_IN_TAB")

eventFrame:SetScript("OnEvent", function(self, event, ...)
    if event == "PLAYER_LOGIN" then
        GC:OnLogin()

    elseif event == "CHAT_MSG_ADDON" then
        local prefix, message, channel, sender = ...
        if prefix == GC.PREFIX then
            GC:OnMessage(sender, message)
        end

    elseif event == "GUILD_ROSTER_UPDATE" then
        GC:OnRosterUpdate()

    elseif event == "TRADE_SKILL_SHOW" or event == "TRADE_SKILL_UPDATE" then
        -- Leger delai pour que la fenetre soit pleinement chargee
        GC:After(0.2, function()
            GC:ScanTradeSkillRecipes()
        end)

    elseif event == "LEARNED_SPELL_IN_TAB" then
        -- Nouveau patron appris : rescan + rebroadcast
        GC:After(0.5, function()
            GC:ScanTradeSkillRecipes()
            GC:SendMyData()
        end)
    end
end)

-- Cle unique du joueur courant : "Nom-Royaume"
function GC:GetMyKey()
    if not GC._myKey then
        GC._myKey = UnitName("player") .. "-" .. GetRealmName()
    end
    return GC._myKey
end

function GC:OnLogin()
    -- Initialise la DB si premiere utilisation
    if not GuildCraftDB then
        GuildCraftDB = { members = {}, version = GC.VERSION }
    end

    if not IsInGuild() then return end

    -- Attendre 3s que les donnees de guilde soient chargees cote client
    GC:After(3, function()
        GC:ScanProfessionLevels()

        -- Annoncer sa presence : demander les donnees des membres connectes
        GC:After(0.5, function()
            GC:SendHello()
        end)

        -- Broadcaster ses propres donnees (apres scan)
        GC:After(2, function()
            GC:SendMyData()
        end)
    end)
end

function GC:OnRosterUpdate()
    if not GuildCraftDB then return end
    GC:CleanupDepartedMembers()
end

-- Commandes slash
SLASH_GUILDCRAFT1 = "/gc"
SLASH_GUILDCRAFT2 = "/guildcraft"
SlashCmdList["GUILDCRAFT"] = function(msg)
    local ok, err = pcall(function()
        if msg == "reload" or msg == "scan" then
            GC:ScanProfessionLevels()
            GC:SendMyData()
            print("|cff00ff00GuildCraft:|r Scan et broadcast effectues.")
        elseif msg == "debug" then
            GC:ToggleDebug()
        else
            GC:ToggleUI()
        end
    end)
    if not ok then
        print("|cffff0000GuildCraft erreur:|r " .. tostring(err))
    end
end
