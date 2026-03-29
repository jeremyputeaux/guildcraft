-- GuildCraft — Broadcast.lua
-- Serialisation, chunking, envoi et reception des donnees de guilde

local GC = GuildCraft

local SEP        = "\001"   -- separateur interne (ASCII 1, jamais dans les noms WoW)
local CHUNK_SIZE = 200      -- caracteres max par message addon
local CHUNK_SEP  = "\002"   -- separateur du header de chunk (ASCII 2)

-- Chunks entrants en cours de reassemblage : { [senderKey] = { total, count, chunks={} } }
GC.incoming = {}

-- ─── Utilitaire : split d'une chaine par un separateur ───────────────────────

local function split(str, sep)
    local result = {}
    local pos = 1
    while pos <= #str do
        local found = str:find(sep, pos, true)
        if found then
            table.insert(result, str:sub(pos, found - 1))
            pos = found + #sep
        else
            table.insert(result, str:sub(pos))
            break
        end
    end
    return result
end

-- ─── Serialisation ───────────────────────────────────────────────────────────

-- Convertit les donnees d'un membre en chaine transportable
-- Format : V1|nom|royaume|classe|timestamp|PROF|nom|lvl|max|REC|nom|compo=n|compo=n|PROF|...
function GC:Serialize(data)
    local p = { "V1", data.name, data.realm, data.class or "", tostring(data.timestamp or 0) }

    for _, prof in ipairs(data.professions or {}) do
        table.insert(p, "PROF")
        table.insert(p, prof.name)
        table.insert(p, tostring(prof.level   or 0))
        table.insert(p, tostring(prof.maxLevel or 0))

        for _, recipe in ipairs(prof.recipes or {}) do
            table.insert(p, "REC")
            table.insert(p, recipe.name)
            for _, reagent in ipairs(recipe.reagents or {}) do
                -- Remplacer "=" eventuel dans les noms par " " (tres rare)
                local rName = reagent.name:gsub("=", " ")
                table.insert(p, rName .. "=" .. tostring(reagent.count or 1))
            end
        end
    end

    return table.concat(p, SEP)
end

-- Reconstruit les donnees d'un membre a partir d'une chaine serialisee
function GC:Deserialize(str)
    local parts = split(str, SEP)
    if not parts[1] or parts[1] ~= "V1" then return nil end

    local data = {
        name        = parts[2] or "",
        realm       = parts[3] or "",
        class       = parts[4] or "",
        timestamp   = tonumber(parts[5]) or 0,
        professions = {},
    }

    local currentProf   = nil
    local currentRecipe = nil
    local i = 6

    while i <= #parts do
        local p = parts[i]

        if p == "PROF" then
            currentProf = {
                name     = parts[i + 1] or "",
                level    = tonumber(parts[i + 2]) or 0,
                maxLevel = tonumber(parts[i + 3]) or 0,
                recipes  = {},
            }
            table.insert(data.professions, currentProf)
            currentRecipe = nil
            i = i + 4

        elseif p == "REC" then
            if currentProf then
                currentRecipe = { name = parts[i + 1] or "", reagents = {} }
                table.insert(currentProf.recipes, currentRecipe)
            end
            i = i + 2

        elseif p ~= "" then
            -- Format reagent : "nom=quantite"
            if currentRecipe then
                local rName, rCount = p:match("^(.+)=(%d+)$")
                if rName and rCount then
                    table.insert(currentRecipe.reagents, { name = rName, count = tonumber(rCount) })
                end
            end
            i = i + 1

        else
            i = i + 1
        end
    end

    return data
end

-- ─── Envoi ───────────────────────────────────────────────────────────────────

-- Decoupe un payload long en plusieurs messages addon de CHUNK_SIZE caracteres
-- Format d'un chunk : "DATA<CHUNK_SEP>senderKey<CHUNK_SEP>idx<CHUNK_SEP>total<CHUNK_SEP>data"
function GC:SendChunked(senderKey, payload)
    local chunks = {}
    for i = 1, #payload, CHUNK_SIZE do
        table.insert(chunks, payload:sub(i, i + CHUNK_SIZE - 1))
    end

    local total = #chunks
    for idx, chunk in ipairs(chunks) do
        local msg = "DATA" .. CHUNK_SEP .. senderKey .. CHUNK_SEP
                 .. idx .. CHUNK_SEP .. total .. CHUNK_SEP .. chunk
        -- Delai de 0.05s entre chaque chunk pour ne pas flooder
        GC:After((idx - 1) * 0.05, function()
            SendAddonMessage(GC.PREFIX, msg, "GUILD")
        end)
    end
end

-- Broadcaster ses propres donnees a toute la guilde
function GC:SendMyData()
    if not IsInGuild() or not GuildCraftDB then return end
    local myKey = GC:GetMyKey()
    local data  = GuildCraftDB.members[myKey]
    if not data then return end
    GC:SendChunked(myKey, GC:Serialize(data))
end

-- Envoyer un HELLO : "je suis nouveau, envoyez-moi tout ce que vous avez"
function GC:SendHello()
    if not IsInGuild() then return end
    SendAddonMessage(GC.PREFIX, "HELLO" .. CHUNK_SEP .. GC:GetMyKey(), "GUILD")
end

-- Envoyer toutes les donnees stockees (reponse a un HELLO)
-- Delai aleatoire pour eviter que tous repondent en meme temps
function GC:SendFullGuildData()
    if not GuildCraftDB then return end
    local delay = math.random() * 3  -- 0-3s aleatoire
    local extra = 0
    for key, memberData in pairs(GuildCraftDB.members) do
        local k, d = key, memberData
        GC:After(delay + extra, function()
            GC:SendChunked(k, GC:Serialize(d))
        end)
        extra = extra + 0.5  -- 0.5s entre chaque membre
    end
end

-- ─── Reception ───────────────────────────────────────────────────────────────

function GC:OnMessage(sender, message)
    local parts = split(message, CHUNK_SEP)
    if #parts < 1 then return end

    local msgType = parts[1]

    -- Un nouveau membre demande toutes les donnees de la guilde
    if msgType == "HELLO" then
        local requester = parts[2]
        -- Ne pas repondre a soi-meme
        if requester ~= GC:GetMyKey() then
            GC:SendFullGuildData()
        end

    -- Reception d'un chunk de donnees membre
    elseif msgType == "DATA" then
        local senderKey = parts[2]
        local idx       = tonumber(parts[3])
        local total     = tonumber(parts[4])
        local data      = parts[5]

        if not senderKey or not idx or not total or not data then return end

        -- Ne pas traiter ses propres donnees
        if senderKey == GC:GetMyKey() then return end

        -- Accumuler les chunks
        if not GC.incoming[senderKey] then
            GC.incoming[senderKey] = { total = total, count = 0, chunks = {} }
        end

        local inc = GC.incoming[senderKey]
        if not inc.chunks[idx] then
            inc.chunks[idx] = data
            inc.count = inc.count + 1
        end

        -- Tous les chunks recus : reassembler et sauvegarder
        if inc.count >= inc.total then
            local full = ""
            for i = 1, inc.total do
                full = full .. (inc.chunks[i] or "")
            end
            GC.incoming[senderKey] = nil

            local memberData = GC:Deserialize(full)
            if memberData and memberData.name ~= "" then
                local key = memberData.name .. "-" .. memberData.realm
                -- Ne sauvegarder que si plus recent
                local existing = GuildCraftDB.members[key]
                if not existing or memberData.timestamp >= existing.timestamp then
                    GuildCraftDB.members[key] = memberData
                    if GC.mainFrame and GC.mainFrame:IsShown() then
                        GC:RefreshUI()
                    end
                end
            end
        end

    -- Un membre a quitte la guilde, purger ses donnees
    elseif msgType == "REMOVE" then
        local key = parts[2]
        if key then
            GC:RemoveMember(key)
            if GC.mainFrame and GC.mainFrame:IsShown() then
                GC:RefreshUI()
            end
        end
    end
end
