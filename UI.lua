-- GuildCraft — UI.lua
-- Interface principale : onglets par metier, recherche, liste des recettes

local GC = GuildCraft

local UI_W   = 720
local UI_H   = 520
local ROW_H  = 18
local INDENT = 16

-- Couleurs
local C_TITLE    = "|cffffd700"  -- or
local C_MEMBER   = "|cff00ccff"  -- bleu clair
local C_LEVEL    = "|cffaaaaaa"  -- gris
local C_RECIPE   = "|cffffffff"  -- blanc
local C_REAGENT  = "|cff88cc44"  -- vert clair
local C_RESET    = "|r"

GC.currentProf   = nil   -- metier actuellement filtre (nil = tous)
GC.currentSearch = ""    -- texte de recherche

-- ─── Creation du frame principal ─────────────────────────────────────────────

function GC:CreateUI()
    if GC.mainFrame then return end

    local frame = CreateFrame("Frame", "GuildCraftMainFrame", UIParent)
    frame:SetFrameStrata("HIGH")
    frame:SetSize(UI_W, UI_H)
    frame:SetPoint("CENTER")
    frame:SetMovable(true)
    frame:EnableMouse(true)
    frame:RegisterForDrag("LeftButton")
    frame:SetScript("OnDragStart", frame.StartMoving)
    frame:SetScript("OnDragStop",  frame.StopMovingOrSizing)
    frame:SetClampedToScreen(true)
    frame:Hide()

    -- Fond
    frame:SetBackdrop({
        bgFile   = "Interface\\DialogFrame\\UI-DialogBox-Background",
        edgeFile = "Interface\\DialogFrame\\UI-DialogBox-Border",
        tile = true, tileSize = 32, edgeSize = 32,
        insets = { left = 11, right = 12, top = 12, bottom = 11 },
    })

    -- Titre
    local title = frame:CreateFontString(nil, "OVERLAY", "GameFontHighlightLarge")
    title:SetPoint("TOP", frame, "TOP", 0, -14)
    title:SetText(C_TITLE .. "GuildCraft" .. C_RESET)
    frame.title = title

    -- Bouton fermer
    local closeBtn = CreateFrame("Button", nil, frame, "UIPanelCloseButton")
    closeBtn:SetPoint("TOPRIGHT", frame, "TOPRIGHT", -4, -4)
    closeBtn:SetScript("OnClick", function() frame:Hide() end)

    -- Bouton rafraichir
    local refreshBtn = CreateFrame("Button", nil, frame, "UIPanelButtonTemplate")
    refreshBtn:SetSize(90, 22)
    refreshBtn:SetPoint("TOPRIGHT", frame, "TOPRIGHT", -30, -14)
    refreshBtn:SetText("Actualiser")
    refreshBtn:SetScript("OnClick", function()
        GC:ScanProfessionLevels()
        GC:SendMyData()
        GC:RefreshUI()
    end)

    -- Zone des onglets de metiers
    local tabArea = CreateFrame("Frame", nil, frame)
    tabArea:SetPoint("TOPLEFT",  frame, "TOPLEFT",  14, -40)
    tabArea:SetPoint("TOPRIGHT", frame, "TOPRIGHT", -14, -40)
    tabArea:SetHeight(26)
    frame.tabArea = tabArea

    -- Barre de recherche
    local searchBox = CreateFrame("EditBox", "GuildCraftSearchBox", frame)
    searchBox:SetFontObject(ChatFontNormal)
    searchBox:SetSize(200, 22)
    searchBox:SetPoint("TOPLEFT", tabArea, "BOTTOMLEFT", 0, -6)
    searchBox:SetAutoFocus(false)
    searchBox:SetMaxLetters(50)
    searchBox:EnableMouse(true)

    -- Fond de la searchbox
    local sbBg = searchBox:CreateTexture(nil, "BACKGROUND")
    sbBg:SetAllPoints()
    sbBg:SetColorTexture(0, 0, 0, 0.5)

    local sbLabel = frame:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
    sbLabel:SetPoint("LEFT", searchBox, "RIGHT", 6, 0)
    sbLabel:SetText(C_LEVEL .. "Rechercher..." .. C_RESET)
    frame.sbLabel = sbLabel

    searchBox:SetScript("OnTextChanged", function(self)
        GC.currentSearch = self:GetText():lower()
        sbLabel:SetShown(GC.currentSearch == "")
        GC:RefreshUI()
    end)
    searchBox:SetScript("OnEscapePressed", function(self)
        self:SetText("")
        self:ClearFocus()
    end)
    frame.searchBox = searchBox

    -- Compteur de resultats
    local countLabel = frame:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
    countLabel:SetPoint("RIGHT", frame, "RIGHT", -16, 0)
    countLabel:SetPoint("TOP", searchBox, "TOP", 0, 0)
    frame.countLabel = countLabel

    -- ScrollFrame
    local scrollFrame = CreateFrame("ScrollFrame", "GuildCraftScroll", frame, "UIPanelScrollFrameTemplate")
    scrollFrame:SetPoint("TOPLEFT",     frame, "TOPLEFT",     14, -96)
    scrollFrame:SetPoint("BOTTOMRIGHT", frame, "BOTTOMRIGHT", -30, 12)

    local content = CreateFrame("Frame", "GuildCraftContent", scrollFrame)
    content:SetSize(UI_W - 44, 1)
    scrollFrame:SetScrollChild(content)
    frame.scrollFrame = scrollFrame
    frame.content     = content

    GC.mainFrame = frame
    GC:BuildTabs()
    GC:RefreshUI()
end

-- ─── Onglets de metiers ───────────────────────────────────────────────────────

function GC:BuildTabs()
    local frame   = GC.mainFrame
    local tabArea = frame.tabArea

    -- Supprimer les anciens onglets
    if frame.tabs then
        for _, t in ipairs(frame.tabs) do t:Hide() end
    end
    frame.tabs = {}

    local profList = { "Tous" }
    for _, name in ipairs(GC:GetAllProfessions()) do
        table.insert(profList, name)
    end

    local x = 0
    for _, profName in ipairs(profList) do
        local btn = CreateFrame("Button", nil, tabArea)
        btn:SetHeight(22)
        btn:SetPoint("LEFT", tabArea, "LEFT", x, 0)

        local lbl = btn:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
        lbl:SetPoint("CENTER")
        lbl:SetText(profName)
        local txtWidth = lbl:GetStringWidth()
        btn:SetWidth(txtWidth + 16)

        local bg = btn:CreateTexture(nil, "BACKGROUND")
        bg:SetAllPoints()
        bg:SetColorTexture(0.2, 0.2, 0.2, 0.7)
        btn.bg = bg

        btn:SetScript("OnClick", function()
            GC.currentProf = (profName == "Tous") and nil or profName
            GC:BuildTabs()
            GC:RefreshUI()
        end)

        btn:SetScript("OnEnter", function(self) self.bg:SetColorTexture(0.35, 0.35, 0.35, 0.9) end)
        btn:SetScript("OnLeave", function(self)
            local active = (profName == "Tous" and GC.currentProf == nil)
                        or (profName == GC.currentProf)
            self.bg:SetColorTexture(active and 0.3 or 0.2, active and 0.3 or 0.2, active and 0.3 or 0.2, 0.7)
        end)

        -- Surligner l'onglet actif
        local active = (profName == "Tous" and GC.currentProf == nil)
                    or (profName == GC.currentProf)
        bg:SetColorTexture(active and 0.3 or 0.2, active and 0.3 or 0.2, active and 0.3 or 0.2, 0.7)

        x = x + btn:GetWidth() + 4
        table.insert(frame.tabs, btn)
    end
end

-- ─── Construction de la liste ─────────────────────────────────────────────────

-- Pool de FontStrings pour eviter de recreer a chaque refresh
local rowPool = {}
local function GetRow(parent, idx)
    if not rowPool[idx] then
        local fs = parent:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
        fs:SetJustifyH("LEFT")
        fs:SetPoint("TOPLEFT", parent, "TOPLEFT", 0, -(idx - 1) * ROW_H)
        rowPool[idx] = fs
    end
    return rowPool[idx]
end

function GC:RefreshUI()
    if not GC.mainFrame then return end
    local frame   = GC.mainFrame
    local content = frame.content
    local search  = GC.currentSearch
    local filter  = GC.currentProf

    -- Masquer toutes les lignes existantes
    for _, fs in pairs(rowPool) do fs:SetText("") end

    local rowIdx     = 1
    local totalCount = 0

    -- Iterer sur les membres tries par nom
    local members = {}
    for key, member in pairs(GC:GetAllMembers()) do
        table.insert(members, member)
    end
    table.sort(members, function(a, b) return (a.name or "") < (b.name or "") end)

    for _, member in ipairs(members) do
        local memberHasResults = false
        local memberRows = {}  -- accumuler pour afficher en bloc

        for _, prof in ipairs(member.professions or {}) do
            -- Filtrer par onglet metier
            if not filter or prof.name == filter then
                local profHasResults = false
                local profRows = {}

                for _, recipe in ipairs(prof.recipes or {}) do
                    -- Filtrer par recherche
                    local match = (search == "")
                               or recipe.name:lower():find(search, 1, true)

                    if match then
                        profHasResults   = true
                        memberHasResults = true
                        totalCount       = totalCount + 1

                        -- Ligne recette
                        local line = "    " .. C_RECIPE .. recipe.name .. C_RESET
                        table.insert(profRows, line)

                        -- Composants
                        if #recipe.reagents > 0 then
                            local reagentParts = {}
                            for _, r in ipairs(recipe.reagents) do
                                table.insert(reagentParts, r.count .. "x " .. r.name)
                            end
                            table.insert(profRows,
                                "        " .. C_REAGENT
                                .. table.concat(reagentParts, "  |  ")
                                .. C_RESET)
                        end
                    end
                end

                -- Si ce metier a des resultats, preparer son header
                if profHasResults then
                    local header = "  " .. C_LEVEL .. prof.name
                                .. " (" .. prof.level .. "/" .. prof.maxLevel .. ")"
                                .. C_RESET
                    table.insert(memberRows, header)
                    for _, r in ipairs(profRows) do
                        table.insert(memberRows, r)
                    end
                end
            end
        end

        -- Afficher le membre + ses metiers si au moins un resultat
        if memberHasResults then
            -- Header membre
            local isOnline = IsGuildMember and IsGuildMember(member.name) or false
            local statusDot = isOnline and "|cff00ff00[En ligne]|r " or "|cff666666[Hors ligne]|r "
            local row = GetRow(content, rowIdx)
            row:SetText(C_MEMBER .. member.name .. C_RESET .. " " .. statusDot)
            rowIdx = rowIdx + 1

            for _, line in ipairs(memberRows) do
                local r = GetRow(content, rowIdx)
                r:SetText(line)
                rowIdx = rowIdx + 1
            end

            -- Ligne vide entre membres
            local r = GetRow(content, rowIdx)
            r:SetText("")
            rowIdx = rowIdx + 1
        end
    end

    -- Afficher un message si vide
    if totalCount == 0 then
        local r = GetRow(content, rowIdx)
        if search ~= "" then
            r:SetText(C_LEVEL .. "Aucun resultat pour \"" .. GC.currentSearch .. "\"." .. C_RESET)
        else
            r:SetText(C_LEVEL .. "Aucune donnee. Attendez que des membres se connectent." .. C_RESET)
        end
        rowIdx = rowIdx + 1
    end

    -- Ajuster la hauteur du content pour le scroll
    content:SetHeight(math.max(rowIdx * ROW_H, 1))

    -- Mise a jour du compteur
    frame.countLabel:SetText(C_LEVEL .. totalCount .. " recette(s)" .. C_RESET)
end

-- ─── Toggle ──────────────────────────────────────────────────────────────────

function GC:ToggleUI()
    if not GC.mainFrame then
        GC:CreateUI()
    else
        if GC.mainFrame:IsShown() then
            GC.mainFrame:Hide()
        else
            GC:BuildTabs()
            GC:RefreshUI()
            GC.mainFrame:Show()
        end
    end
end
