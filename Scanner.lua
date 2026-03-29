-- GuildCraft — Scanner.lua
-- Scan des metiers (niveaux) et des recettes (fenetre de craft ouverte)

local GC = GuildCraft

-- Noms de metiers connus, toutes locales confondues (enUS + frFR + deDE)
-- Utilise pour filtrer les skills non-metiers (armes, langues, etc.)
local KNOWN_PROFESSIONS = {
    -- enUS
    ["Alchemy"]          = true, ["Blacksmithing"]    = true,
    ["Enchanting"]       = true, ["Engineering"]      = true,
    ["Herbalism"]        = true, ["Jewelcrafting"]    = true,
    ["Leatherworking"]   = true, ["Mining"]           = true,
    ["Skinning"]         = true, ["Tailoring"]        = true,
    ["Cooking"]          = true, ["First Aid"]        = true,
    ["Fishing"]          = true, ["Inscription"]      = true,
    -- frFR
    ["Alchimie"]         = true, ["Forge"]            = true,
    ["Enchantement"]     = true, ["Ingenierie"]       = true,
    ["Herboristerie"]    = true, ["Joaillerie"]       = true,
    ["Travail du cuir"]  = true, ["Minage"]           = true,
    ["Depecage"]         = true, ["Couture"]          = true,
    ["Cuisine"]          = true, ["Secourisme"]       = true,
    ["Peche"]            = true, ["Calligraphie"]     = true,
    -- deDE
    ["Alchemie"]         = true, ["Schmiedekunst"]    = true,
    ["Verzauberkunst"]   = true, ["Ingenieurskunst"]  = true,
    ["Krauterkunde"]     = true, ["Juwelierskunst"]   = true,
    ["Lederverarbeitung"]= true, ["Bergbau"]          = true,
    ["Kurschnerei"]      = true, ["Schneiderei"]      = true,
    ["Kochkunst"]        = true, ["Erste Hilfe"]      = true,
    ["Angeln"]           = true, ["Inschriftenkunde"] = true,
}

-- Scan les niveaux de metiers du joueur via GetSkillLineInfo
-- Ne necessite pas l'ouverture d'une fenetre de craft
function GC:ScanProfessionLevels()
    if not GuildCraftDB then return end

    local myKey  = GC:GetMyKey()
    local existing = GuildCraftDB.members[myKey] or {}

    -- Conserver les recettes deja scannees par metier
    local savedRecipes = {}
    for _, prof in ipairs(existing.professions or {}) do
        savedRecipes[prof.name] = prof.recipes
    end

    local professions = {}
    local numSkills = GetNumSkillLines()
    for i = 1, numSkills do
        local name, isHeader, _, skillRank, _, _, skillMaximum = GetSkillLineInfo(i)
        if not isHeader and name and KNOWN_PROFESSIONS[name] then
            table.insert(professions, {
                name      = name,
                level     = skillRank    or 0,
                maxLevel  = skillMaximum or 0,
                recipes   = savedRecipes[name] or {},
            })
        end
    end

    GuildCraftDB.members[myKey] = {
        name        = UnitName("player"),
        realm       = GetRealmName(),
        class       = select(2, UnitClass("player")),
        professions = professions,
        timestamp   = time(),
    }
end

-- Scan toutes les recettes de la fenetre de craft actuellement ouverte
-- Appele sur TRADE_SKILL_SHOW / TRADE_SKILL_UPDATE
function GC:ScanTradeSkillRecipes()
    if not GuildCraftDB then return end

    local skillName, _, _, skillRank, _, _, skillMaximum = GetTradeSkillLine()
    if not skillName or skillName == "UNKNOWN" then return end

    local myKey = GC:GetMyKey()

    -- S'assurer que le membre existe en base
    if not GuildCraftDB.members[myKey] then
        GC:ScanProfessionLevels()
    end

    local member = GuildCraftDB.members[myKey]

    -- Trouver ou creer l'entree de ce metier
    local prof = nil
    for _, p in ipairs(member.professions) do
        if p.name == skillName then
            prof = p
            break
        end
    end
    if not prof then
        prof = { name = skillName, level = 0, maxLevel = 0, recipes = {} }
        table.insert(member.professions, prof)
    end

    prof.level    = skillRank    or prof.level
    prof.maxLevel = skillMaximum or prof.maxLevel
    prof.recipes  = {}

    local numRecipes = GetNumTradeSkills()
    for i = 1, numRecipes do
        local recipeName, recipeType = GetTradeSkillInfo(i)
        -- Ignorer les en-tetes de categorie (Armor, Weapon, etc.)
        if recipeType ~= "header" and recipeName then
            local numReagents = GetTradeSkillNumReagents(i)
            local reagents = {}
            for j = 1, numReagents do
                local rName, _, rCount = GetTradeSkillReagentInfo(i, j)
                if rName then
                    table.insert(reagents, { name = rName, count = rCount or 1 })
                end
            end
            table.insert(prof.recipes, { name = recipeName, reagents = reagents })
        end
    end

    member.timestamp = time()
end
