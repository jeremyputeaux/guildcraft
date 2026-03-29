-- GuildCraft — Debug.lua
-- Interface de debug : affiche les donnees scannees en temps reel

local GC = GuildCraft

-- ─── Frame de debug ──────────────────────────────────────────────────────────

function GC:CreateDebugUI()
    if GC.debugFrame then return end

    local frame = CreateFrame("Frame", "GuildCraftDebugFrame", UIParent)
    frame:SetFrameStrata("DIALOG")
    frame:SetSize(580, 500)
    frame:SetPoint("CENTER", UIParent, "CENTER", 200, 0)
    frame:SetMovable(true)
    frame:EnableMouse(true)
    frame:RegisterForDrag("LeftButton")
    frame:SetScript("OnDragStart", frame.StartMoving)
    frame:SetScript("OnDragStop",  frame.StopMovingOrSizing)
    frame:SetClampedToScreen(true)
    frame:Hide()

    frame:SetBackdrop({
        bgFile   = "Interface\\DialogFrame\\UI-DialogBox-Background",
        edgeFile = "Interface\\DialogFrame\\UI-DialogBox-Border",
        tile = true, tileSize = 32, edgeSize = 32,
        insets = { left = 11, right = 12, top = 12, bottom = 11 },
    })

    -- Titre
    local title = frame:CreateFontString(nil, "OVERLAY", "GameFontHighlight")
    title:SetPoint("TOP", frame, "TOP", 0, -14)
    title:SetText("|cffffff00GuildCraft — Debug|r")

    -- Bouton fermer
    local closeBtn = CreateFrame("Button", nil, frame, "UIPanelCloseButton")
    closeBtn:SetPoint("TOPRIGHT", frame, "TOPRIGHT", -4, -4)
    closeBtn:SetScript("OnClick", function() frame:Hide() end)

    -- Bouton "Scanner maintenant"
    local scanBtn = CreateFrame("Button", nil, frame, "UIPanelButtonTemplate")
    scanBtn:SetSize(140, 22)
    scanBtn:SetPoint("TOPLEFT", frame, "TOPLEFT", 14, -36)
    scanBtn:SetText("Scanner mes metiers")
    scanBtn:SetScript("OnClick", function()
        GC:ScanProfessionLevels()
        GC:RefreshDebug()
        GC:Log("Scan des niveaux effectue.")
    end)

    -- Bouton "Broadcaster"
    local broadBtn = CreateFrame("Button", nil, frame, "UIPanelButtonTemplate")
    broadBtn:SetSize(140, 22)
    broadBtn:SetPoint("LEFT", scanBtn, "RIGHT", 6, 0)
    broadBtn:SetText("Broadcaster mes data")
    broadBtn:SetScript("OnClick", function()
        GC:SendMyData()
        GC:Log("Broadcast envoye a la guilde.")
    end)

    -- Bouton "Demander les data guilde"
    local helloBtn = CreateFrame("Button", nil, frame, "UIPanelButtonTemplate")
    helloBtn:SetSize(160, 22)
    helloBtn:SetPoint("LEFT", broadBtn, "RIGHT", 6, 0)
    helloBtn:SetText("Demander data guilde")
    helloBtn:SetScript("OnClick", function()
        GC:SendHello()
        GC:Log("HELLO envoye a la guilde.")
    end)

    -- Separateur
    local sep = frame:CreateTexture(nil, "BACKGROUND")
    sep:SetSize(550, 1)
    sep:SetPoint("TOP", frame, "TOP", 0, -62)
    sep:SetColorTexture(0.5, 0.5, 0.5, 0.5)

    -- Zone de donnees scannees (moitie haute)
    local dataTitle = frame:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
    dataTitle:SetPoint("TOPLEFT", frame, "TOPLEFT", 16, -72)
    dataTitle:SetText("|cff00ccffMes donnees scannees|r")

    local dataScroll = CreateFrame("ScrollFrame", "GCDebugDataScroll", frame, "UIPanelScrollFrameTemplate")
    dataScroll:SetPoint("TOPLEFT",  frame, "TOPLEFT",  14, -88)
    dataScroll:SetPoint("TOPRIGHT", frame, "TOPRIGHT", -30, -88)
    dataScroll:SetHeight(200)

    local dataContent = CreateFrame("Frame", nil, dataScroll)
    dataContent:SetSize(520, 1)
    dataScroll:SetScrollChild(dataContent)
    frame.dataContent = dataContent

    -- Zone de log (moitie basse)
    local logTitle = frame:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
    logTitle:SetPoint("TOPLEFT", frame, "TOPLEFT", 16, -296)
    logTitle:SetText("|cffff9900Log evenements|r")

    local logScroll = CreateFrame("ScrollFrame", "GCDebugLogScroll", frame, "UIPanelScrollFrameTemplate")
    logScroll:SetPoint("TOPLEFT",     frame, "TOPLEFT",     14, -312)
    logScroll:SetPoint("BOTTOMRIGHT", frame, "BOTTOMRIGHT", -30, 12)

    local logContent = CreateFrame("Frame", nil, logScroll)
    logContent:SetSize(520, 1)
    logScroll:SetScrollChild(logContent)
    frame.logContent  = logContent
    frame.logScroll   = logScroll

    frame.logLines    = {}
    frame.dataLines   = {}

    GC.debugFrame = frame
end

-- ─── Affichage des donnees scannees ──────────────────────────────────────────

function GC:RefreshDebug()
    if not GC.debugFrame then return end
    local content = GC.debugFrame.dataContent

    -- Effacer les lignes
    for _, fs in ipairs(GC.debugFrame.dataLines) do fs:SetText("") end
    GC.debugFrame.dataLines = {}

    local function addLine(text, yOffset)
        local fs = content:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
        fs:SetJustifyH("LEFT")
        fs:SetPoint("TOPLEFT", content, "TOPLEFT", 0, yOffset)
        fs:SetText(text)
        table.insert(GC.debugFrame.dataLines, fs)
        return fs
    end

    local y      = 0
    local lineH  = 16
    local myKey  = GC:GetMyKey()
    local member = GuildCraftDB and GuildCraftDB.members and GuildCraftDB.members[myKey]

    if not member then
        addLine("|cffff4444Aucune donnee scannee. Ouvrez une fenetre de metier ou cliquez Scanner.|r", y)
        content:SetHeight(30)
        return
    end

    addLine("|cffffff00Joueur :|r " .. myKey, y)
    y = y - lineH
    addLine("|cffffff00Classe :|r " .. (member.class or "?"), y)
    y = y - lineH
    addLine("|cffffff00Derniere mise a jour :|r " .. date("%H:%M:%S", member.timestamp), y)
    y = y - lineH
    addLine("|cffffff00Metiers detectes :|r " .. #(member.professions or {}), y)
    y = y - lineH * 1.5

    if #(member.professions or {}) == 0 then
        addLine("|cffff4444Aucun metier detecte. Verifiez que vos metiers sont dans la liste connue.|r", y)
        y = y - lineH
    end

    for _, prof in ipairs(member.professions or {}) do
        local recipeCount = #(prof.recipes or {})
        local color = recipeCount > 0 and "|cff00ff00" or "|cffff9900"
        addLine(color .. prof.name .. "|r  " ..
                "|cffaaaaaa" .. prof.level .. "/" .. prof.maxLevel .. "|r  " ..
                "|cff888888(" .. recipeCount .. " recette(s))|r", y)
        y = y - lineH

        -- Afficher les 5 premieres recettes a titre d'exemple
        local shown = 0
        for _, recipe in ipairs(prof.recipes or {}) do
            if shown < 5 then
                addLine("    |cffcccccc" .. recipe.name .. "|r", y)
                y = y - lineH
                shown = shown + 1
            end
        end
        if recipeCount > 5 then
            addLine("    |cff888888... et " .. (recipeCount - 5) .. " autres|r", y)
            y = y - lineH
        end
        if recipeCount == 0 then
            addLine("    |cffff9900Ouvrez la fenetre de ce metier pour scanner les recettes.|r", y)
            y = y - lineH
        end
        y = y - lineH * 0.5
    end

    -- Stats membres de la guilde en base
    local memberCount = 0
    for _ in pairs(GuildCraftDB.members) do memberCount = memberCount + 1 end
    y = y - lineH * 0.5
    addLine("|cffffff00Membres en base :|r " .. memberCount, y)

    content:SetHeight(math.abs(y) + 20)
end

-- ─── Log ─────────────────────────────────────────────────────────────────────

GC._logLines = {}

function GC:Log(msg)
    local frame = GC.debugFrame
    if not frame then return end

    local ts   = date("%H:%M:%S")
    local line = "|cff888888[" .. ts .. "]|r " .. msg
    table.insert(GC._logLines, line)

    -- Garder max 50 lignes
    while #GC._logLines > 50 do
        table.remove(GC._logLines, 1)
    end

    -- Redessiner le log
    local content = frame.logContent
    for _, fs in ipairs(frame.logLines) do fs:SetText("") end
    frame.logLines = {}

    local y = 0
    for i = #GC._logLines, 1, -1 do  -- plus recent en haut
        local fs = content:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
        fs:SetJustifyH("LEFT")
        fs:SetPoint("TOPLEFT", content, "TOPLEFT", 0, y)
        fs:SetText(GC._logLines[i])
        table.insert(frame.logLines, fs)
        y = y - 16
    end
    content:SetHeight(math.max(math.abs(y), 1))
end

-- ─── Hooks sur les events pour alimenter le log ──────────────────────────────

local _origOnLogin = GC.OnLogin
function GC:OnLogin()
    GC:Log("PLAYER_LOGIN — init en cours...")
    _origOnLogin(self)
end

local _origScanLevels = GC.ScanProfessionLevels
function GC:ScanProfessionLevels()
    _origScanLevels(self)
    local member = GuildCraftDB and GuildCraftDB.members and GuildCraftDB.members[GC:GetMyKey()]
    if member then
        GC:Log("ScanProfessionLevels — " .. #(member.professions or {}) .. " metier(s) detecte(s)")
    end
    if GC.debugFrame and GC.debugFrame:IsShown() then GC:RefreshDebug() end
end

local _origScanRecipes = GC.ScanTradeSkillRecipes
function GC:ScanTradeSkillRecipes()
    _origScanRecipes(self)
    local member = GuildCraftDB and GuildCraftDB.members and GuildCraftDB.members[GC:GetMyKey()]
    if member then
        for _, prof in ipairs(member.professions or {}) do
            GC:Log("Recettes scannees : " .. prof.name .. " (" .. #prof.recipes .. " recettes)")
        end
    end
    if GC.debugFrame and GC.debugFrame:IsShown() then GC:RefreshDebug() end
end

local _origOnMessage = GC.OnMessage
function GC:OnMessage(sender, message)
    local msgType = message:sub(1, 4)
    if msgType == "HELL" then
        GC:Log("HELLO recu de " .. sender)
    elseif msgType == "DATA" then
        GC:Log("DATA chunk recu de " .. sender)
    elseif msgType == "REMO" then
        GC:Log("REMOVE recu : " .. sender)
    end
    _origOnMessage(self, sender, message)
    if GC.debugFrame and GC.debugFrame:IsShown() then GC:RefreshDebug() end
end

local _origSendMyData = GC.SendMyData
function GC:SendMyData()
    GC:Log("Broadcast de mes donnees...")
    _origSendMyData(self)
end

-- ─── Toggle debug ─────────────────────────────────────────────────────────────

function GC:ToggleDebug()
    if not GC.debugFrame then
        GC:CreateDebugUI()
    end
    if GC.debugFrame:IsShown() then
        GC.debugFrame:Hide()
    else
        GC:RefreshDebug()
        GC.debugFrame:Show()
    end
end
