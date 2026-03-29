-- GuildCraft — DB.lua
-- Lecture / ecriture des donnees membres dans GuildCraftDB (SavedVariables)

local GC = GuildCraft

-- Sauvegarde ou mise a jour d'un membre
function GC:SaveMember(data)
    if not data or not data.name or not data.realm then return end
    local key = data.name .. "-" .. data.realm
    GuildCraftDB.members[key] = data
end

-- Suppression d'un membre par cle
function GC:RemoveMember(key)
    if GuildCraftDB and GuildCraftDB.members then
        GuildCraftDB.members[key] = nil
    end
end

-- Retourne toutes les donnees membres sous forme de table { key = data }
function GC:GetAllMembers()
    if not GuildCraftDB then return {} end
    return GuildCraftDB.members or {}
end

-- Retourne les membres qui ont un metier donne
function GC:GetMembersWithProfession(profName)
    local result = {}
    for key, member in pairs(GC:GetAllMembers()) do
        for _, prof in ipairs(member.professions or {}) do
            if prof.name == profName then
                table.insert(result, { key = key, member = member, prof = prof })
                break
            end
        end
    end
    -- Trier par niveau de metier decroissant
    table.sort(result, function(a, b)
        return (a.prof.level or 0) > (b.prof.level or 0)
    end)
    return result
end

-- Retourne la liste de tous les metiers presents dans la guilde (sans doublon)
function GC:GetAllProfessions()
    local seen = {}
    local list = {}
    for _, member in pairs(GC:GetAllMembers()) do
        for _, prof in ipairs(member.professions or {}) do
            if not seen[prof.name] then
                seen[prof.name] = true
                table.insert(list, prof.name)
            end
        end
    end
    table.sort(list)
    return list
end

-- Purge les membres qui ne sont plus dans la guilde
function GC:CleanupDepartedMembers()
    if not IsInGuild() or not GuildCraftDB then return end

    -- Construire un set des membres actuels (par nom de base)
    local current = {}
    local numMembers = GetNumGuildMembers and GetNumGuildMembers() or 0
    for i = 1, numMembers do
        local name = (GetGuildRosterInfo(i))
        if name then
            -- Retirer le suffixe -Royaume si present (Cata+)
            local baseName = name:match("^([^%-]+)") or name
            current[baseName] = true
        end
    end

    -- Supprimer ceux qui ne sont plus dans la guilde
    for key in pairs(GuildCraftDB.members) do
        local baseName = key:match("^([^%-]+)") or key
        if not current[baseName] then
            GuildCraftDB.members[key] = nil
        end
    end
end
