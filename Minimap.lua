-- GuildCraft — Minimap.lua
-- Bouton draggable autour de la minimap pour toggle l'interface

local GC = GuildCraft

local RADIUS = 80  -- distance du centre de la minimap

local button = CreateFrame("Button", "GuildCraftMinimapButton", Minimap)
button:SetSize(31, 31)
button:SetFrameStrata("MEDIUM")
button:SetFrameLevel(8)
button:RegisterForClicks("LeftButtonUp", "RightButtonUp")
button:RegisterForDrag("LeftButton")
button:SetHighlightTexture("Interface\\Minimap\\UI-Minimap-ZoomButton-Highlight")

-- Bordure circulaire
local border = button:CreateTexture(nil, "OVERLAY")
border:SetSize(53, 53)
border:SetPoint("CENTER")
border:SetTexture("Interface\\Minimap\\MiniMap-TrackingBorder")

-- Icone (parchemin/recette)
local icon = button:CreateTexture(nil, "BACKGROUND")
icon:SetSize(20, 20)
icon:SetPoint("CENTER")
icon:SetTexture("Interface\\Icons\\INV_Scroll_03")

-- ─── Position autour de la minimap ───────────────────────────────────────────

local function UpdatePosition()
    local angle = GuildCraftDB and GuildCraftDB.minimapAngle or 45
    local rad   = math.rad(angle)
    button:ClearAllPoints()
    button:SetPoint("CENTER", Minimap, "CENTER",
        RADIUS * math.cos(rad),
        RADIUS * math.sin(rad))
end

-- ─── Drag autour de la minimap ────────────────────────────────────────────────

button:SetScript("OnDragStart", function(self)
    self:SetScript("OnUpdate", function()
        local mx, my   = Minimap:GetCenter()
        local cx, cy   = GetCursorPosition()
        local scale    = UIParent:GetEffectiveScale()
        cx, cy         = cx / scale, cy / scale
        local newAngle = math.deg(math.atan2(cy - my, cx - mx))
        if GuildCraftDB then
            GuildCraftDB.minimapAngle = newAngle
        end
        UpdatePosition()
    end)
end)

button:SetScript("OnDragStop", function(self)
    self:SetScript("OnUpdate", nil)
end)

-- ─── Clics ────────────────────────────────────────────────────────────────────

button:SetScript("OnClick", function(self, btn)
    if btn == "LeftButton" then
        GC:ToggleUI()
    elseif btn == "RightButton" then
        GC:ToggleDebug()
    end
end)

-- ─── Tooltip ─────────────────────────────────────────────────────────────────

button:SetScript("OnEnter", function(self)
    GameTooltip:SetOwner(self, "ANCHOR_LEFT")
    GameTooltip:AddLine("GuildCraft")
    GameTooltip:AddLine("|cffaaaaaa Clic gauche|r : Ouvrir l'interface", 1, 1, 1)
    GameTooltip:AddLine("|cffaaaaaa Clic droit|r  : Debug", 1, 1, 1)
    GameTooltip:AddLine("|cffaaaaaa Drag|r         : Deplacer le bouton", 1, 1, 1)
    GameTooltip:Show()
end)

button:SetScript("OnLeave", function()
    GameTooltip:Hide()
end)

-- ─── Init apres PLAYER_LOGIN (GuildCraftDB dispo) ────────────────────────────

local initFrame = CreateFrame("Frame")
initFrame:RegisterEvent("PLAYER_LOGIN")
initFrame:SetScript("OnEvent", function()
    -- S'assurer que minimapAngle est initialise
    if GuildCraftDB and not GuildCraftDB.minimapAngle then
        GuildCraftDB.minimapAngle = 45
    end
    UpdatePosition()
end)
