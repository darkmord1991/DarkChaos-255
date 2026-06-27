C_CreatureMixin = {}

enum:E_CREATURE_CACHE {
    "DISPLAY_ID",
    "NAME",
    "ICON",
}

function C_CreatureMixin:GetCreatureDisplayId(creatureEntry)
    if not creatureEntry or not CreaturesCache then
        return
    end

    local row = CreaturesCache[tonumber(creatureEntry) or creatureEntry]
    if not row then
        return
    end

    return row[E_CREATURE_CACHE.DISPLAY_ID]
end

function C_CreatureMixin:SetCreatureModel(model, creatureEntry)
    if not model or not creatureEntry then
        return
    end

    local displayId = self:GetCreatureDisplayId(creatureEntry) or creatureEntry
    if displayId <= 0 then
        return
    end

    if model.ClearModel then
        pcall(model.ClearModel, model)
    end

    if model.SetCreature then
        model:SetCreature(displayId)
    end

    if model.SetRotation then
        model:SetRotation(model.rotation or model.defaultRotation or MODELFRAME_DEFAULT_ROTATION or 0.61)
    end

    if model.SetSequence then
        pcall(model.SetSequence, model, 3)
    end
end

C_Creature = CreateFromMixins(C_CreatureMixin)

function EJ_GetCreatureDisplayId(creatureEntry)
    if C_Creature then
        return C_Creature:GetCreatureDisplayId(creatureEntry)
    end
end

function EJ_SetCreatureModel(model, creatureEntry)
    if C_Creature then
        C_Creature:SetCreatureModel(model, creatureEntry)
    end
end
