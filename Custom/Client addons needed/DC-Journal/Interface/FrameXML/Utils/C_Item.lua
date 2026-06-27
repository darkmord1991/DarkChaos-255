C_ItemMixin = {}

enum:E_ITEM_INFO {
    "NAME_ENGB",
    "NAME_RURU",
    "RARITY",
    "ILEVEL",
    "MINLEVEL",
    "TYPE",
    "SUBTYPE",
    "STACKCOUNT",
    "EQUIPLOC",
    "TEXTURE",
    "VENDORPRICE"
}

function C_ItemMixin:Init()
    self._GetItemInfo = GetItemInfo
end

function C_ItemMixin:GetLocaleIndex()
    return GetLocale() == "ruRU" and E_ITEM_INFO.NAME_RURU or E_ITEM_INFO.NAME_ENGB
end

function C_ItemMixin:GetItemInfoFromCache(itemIdentifier)
    if not itemIdentifier or not ItemsCache then
        return
    end

    local identifier = tonumber(itemIdentifier) or tonumber(string.match(itemIdentifier, "Hitem:(%d+)"))
    if not identifier then
        return
    end

    local cacheData = ItemsCache[identifier]
    if not cacheData or type(cacheData) ~= "table" then
        return
    end

    if not cacheData.itemEntry then
        cacheData.itemEntry = identifier
    end

    local itemData = {}
    itemData.name = cacheData[self:GetLocaleIndex()]
    itemData.rarity = cacheData[E_ITEM_INFO.RARITY]
    itemData.iLevel = cacheData[E_ITEM_INFO.ILEVEL]
    itemData.mLevel = cacheData[E_ITEM_INFO.MINLEVEL]
    itemData.type = _G["ITEM_CLASS_"..cacheData[E_ITEM_INFO.TYPE]]
    itemData.subType = _G[string.format("ITEM_SUB_CLASS_%d_%d", cacheData[E_ITEM_INFO.TYPE], cacheData[E_ITEM_INFO.SUBTYPE])]
    itemData.stackCount = cacheData[E_ITEM_INFO.STACKCOUNT]
    itemData.equipLoc = SHARED_INVTYPE_BY_ID and SHARED_INVTYPE_BY_ID[cacheData[E_ITEM_INFO.EQUIPLOC]] or ""
    itemData.vendorPrice = cacheData[E_ITEM_INFO.VENDORPRICE]
    itemData.texture = "Interface\\Icons\\"..cacheData[E_ITEM_INFO.TEXTURE]

    if itemData.name and CreateColor and GetItemQualityColor then
        local r, g, b = GetItemQualityColor(itemData.rarity)
        itemData.link = CreateColor(r, g, b):WrapTextInColorCode(string.format("|Hitem:%d:0:0:0:0:0:0:0:%d|h[%s]|h", identifier, itemData.mLevel or 0, itemData.name))
    end

    return itemData
end

function C_ItemMixin:GetItemInfo(itemIdentifier)
    if not itemIdentifier then
        return
    end

    local itemName, itemLink, itemRarity, itemLevel, itemMinLevel, itemType, itemSubType, itemStackCount, itemEquipLoc, itemTexture, vendorPrice = self._GetItemInfo(itemIdentifier)
    if itemName then
        return itemName, itemLink, itemRarity, itemLevel, itemMinLevel, itemType, itemSubType, itemStackCount, itemEquipLoc, itemTexture, vendorPrice
    end

    local cacheData = self:GetItemInfoFromCache(itemIdentifier)
    if not cacheData or not cacheData.name then
        return
    end

    return cacheData.name, cacheData.link, cacheData.rarity, cacheData.iLevel, cacheData.mLevel, cacheData.type, cacheData.subType, cacheData.stackCount, cacheData.equipLoc, cacheData.texture, cacheData.vendorPrice
end

C_Item = CreateFromMixins(C_ItemMixin)
C_Item:Init()

function EJ_GetItemInfo(itemIdentifier)
    if C_Item then
        return C_Item:GetItemInfo(itemIdentifier)
    end
    return GetItemInfo(itemIdentifier)
end
