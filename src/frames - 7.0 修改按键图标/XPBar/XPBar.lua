-- XPBar.lua
-- 经验条（简化版，无 SavedVariables，无开关，始终显示）

XPBar_Config = XPBar_Config or {
    color = {1, 0.7, 0},
    screenWidth = GetScreenWidth()+200,
    height = 10,
    level = {
        fontTemplate = "GameFontNormalSmall",
        xOffset = 6,
        yOffset = -3,
        width = 80,
    },
    classIcon = {
        size = 15,
        xOffset = -6,
        yOffset = 0,
        paths = {
            WARRIOR = "Interface\\AddOns\\ImmersiveDialogUI\\src\\assets\\art\\icons\\warriorGossipIcon.tga",
            PALADIN = "Interface\\AddOns\\ImmersiveDialogUI\\src\\assets\\art\\icons\\paladinGossipIcon.tga",
            HUNTER  = "Interface\\AddOns\\ImmersiveDialogUI\\src\\assets\\art\\icons\\hunterGossipIcon.tga",
            ROGUE   = "Interface\\AddOns\\ImmersiveDialogUI\\src\\assets\\art\\icons\\rogueGossipIcon.tga",
            PRIEST  = "Interface\\AddOns\\ImmersiveDialogUI\\src\\assets\\art\\icons\\priestGossipIcon.tga",
            SHAMAN  = "Interface\\AddOns\\ImmersiveDialogUI\\src\\assets\\art\\icons\\shamanGossipIcon.tga",
            MAGE    = "Interface\\AddOns\\ImmersiveDialogUI\\src\\assets\\art\\icons\\mageGossipIcon.tga",
            WARLOCK = "Interface\\AddOns\\ImmersiveDialogUI\\src\\assets\\art\\icons\\warlockGossipIcon.tga",
            DRUID   = "Interface\\AddOns\\ImmersiveDialogUI\\src\\assets\\art\\icons\\druidGossipIcon.tga",
        },
    },
    statusBarTexture = "Interface\\AddOns\\ImmersiveDialogUI\\src\\assets\\art\\xpbars\\statusBar.tga",
    leftTexture = {
        path = "Interface\\AddOns\\ImmersiveDialogUI\\src\\assets\\art\\xpbars\\XPLeft.TGA",
        width = 128,
        height = 32,
        xOffset = 0,
        yOffset = 0,
    },
    middleTexture = {
        path = "Interface\\AddOns\\ImmersiveDialogUI\\src\\assets\\art\\xpbars\\XPMiddle.TGA",
        height = 32,
        xOffset = 0,
        yOffset = 0,
    },
    rightTexture = {
        path = "Interface\\AddOns\\ImmersiveDialogUI\\src\\assets\\art\\xpbars\\XPRight.TGA",
        width = 128,
        height = 32,
        xOffset = 0,
        yOffset = 0,
    },
}

local cfg = XPBar_Config

-- ========== 创建经验条 ==========
local xpBar = CreateFrame("StatusBar", "XPBar_Main", UIParent)
xpBar:SetPoint("BOTTOMLEFT", UIParent, "BOTTOMLEFT", 65, 0.5)
xpBar:SetPoint("BOTTOMRIGHT", UIParent, "BOTTOMRIGHT", -65, 0.5)
xpBar:SetHeight(cfg.height or 10)
xpBar:SetFrameStrata("MEDIUM")
xpBar:Hide() -- 初始隐藏，等待检查开关状态

xpBar:SetStatusBarTexture(cfg.statusBarTexture or "Interface\\TargetingFrame\\UI-StatusBar")

local bg = xpBar:CreateTexture(nil, "BACKGROUND")
bg:SetAllPoints(xpBar)
bg:SetTexture(1, 1, 1, 0.15)

do
    local sbTex = xpBar:GetStatusBarTexture()
    if sbTex then
        if sbTex.SetHorizTile then sbTex:SetHorizTile(true) end
        if sbTex.SetVertTile then sbTex:SetVertTile(false) end
    end
end

-- ========== 左右材质 ==========
local function TrySetTexture(texObject, path)
    if not texObject or not path then return false end
    texObject:SetTexture(path)
    if texObject.GetTexture then
        local got = texObject:GetTexture()
        if not got or got == "" then return false end
    end
    return true
end

local leftCfg = cfg.leftTexture or {}
local leftFrame = CreateFrame("Frame", "XPBar_LeftTexture", UIParent)
leftFrame:SetFrameStrata("HIGH")
leftFrame:SetFrameLevel(xpBar:GetFrameLevel() + 10)
leftFrame:SetWidth(leftCfg.width or 32)
leftFrame:SetHeight(leftCfg.height or 32)
leftFrame:SetPoint("BOTTOMLEFT", UIParent, "BOTTOMLEFT", -22, leftCfg.yOffset or 0)
leftFrame:Hide() -- 初始隐藏
local leftTex = leftFrame:CreateTexture(nil, "ARTWORK")
leftTex:SetAllPoints(leftFrame)
if not TrySetTexture(leftTex, leftCfg.path) then
    leftTex:SetTexture("Interface\\Icons\\INV_Misc_QuestionMark")
end

local middleCfg = cfg.middleTexture or {}
local middleFrame = CreateFrame("Frame", "XPBar_middleTexture", UIParent)
middleFrame:SetFrameStrata("HIGH")
middleFrame:SetFrameLevel(xpBar:GetFrameLevel() + 10)
middleFrame:SetWidth(XPBar_Config.screenWidth)
middleFrame:SetHeight(10)
middleFrame:SetPoint("BOTTOMLEFT", xpBar, "BOTTOMLEFT", 0, 0)
middleFrame:Hide() -- 初始隐藏
local middleTex = middleFrame:CreateTexture(nil, "ARTWORK")
middleTex:SetAllPoints(middleFrame)
if not TrySetTexture(middleTex, middleCfg.path) then
    middleTex:SetTexture("Interface\\Icons\\INV_Misc_QuestionMark")
end

local rightCfg = cfg.rightTexture or {}
local rightFrame = CreateFrame("Frame", "XPBar_RightTexture", UIParent)
rightFrame:SetFrameStrata("HIGH")
rightFrame:SetFrameLevel(xpBar:GetFrameLevel() + 10)
rightFrame:SetWidth(rightCfg.width or 32)
rightFrame:SetHeight(rightCfg.height or 32)
rightFrame:SetPoint("BOTTOMRIGHT", UIParent, "BOTTOMRIGHT", 22, rightCfg.yOffset or 0)
rightFrame:Hide() -- 初始隐藏
local rightTex = rightFrame:CreateTexture(nil, "ARTWORK")
rightTex:SetAllPoints(rightFrame)
if not TrySetTexture(rightTex, rightCfg.path) then
    rightTex:SetTexture("Interface\\Icons\\INV_Misc_QuestionMark")
end

-- ========== overlay ==========
local overlay = CreateFrame("Frame", "XPBar_Overlay", UIParent)
overlay:SetFrameStrata("HIGH")
overlay:SetFrameLevel(xpBar:GetFrameLevel() + 20)
overlay:SetAllPoints(xpBar)
overlay:Hide() -- 初始隐藏

local overlayLevelFrame = CreateFrame("Frame", "XPBar_LevelFrame", overlay)
overlayLevelFrame:SetHeight(cfg.height or 32)
overlayLevelFrame:SetWidth((cfg.level and cfg.level.width) or 80)
overlayLevelFrame:SetPoint("BOTTOMLEFT", xpBar, "LEFT", -35, (cfg.level and cfg.level.yOffset) or -5)
local overlayLevelText = overlayLevelFrame:CreateFontString(nil, "OVERLAY", (cfg.level and cfg.level.fontTemplate) or "GameFontNormalSmall")
overlayLevelText:SetAllPoints(overlayLevelFrame)
overlayLevelText:SetJustifyH("LEFT")
overlayLevelText:SetFont("Interface\\AddOns\\ImmersiveUI\\assets\\fonts\\OptimusPrinceps.ttf", 16, "OUTLINE")
overlayLevelText:SetTextColor(1,0.7,0)
overlayLevelText:SetText("")

local overlayClassFrame = CreateFrame("Frame", "XPBar_ClassIconFrame", overlay)
overlayClassFrame:SetPoint("RIGHT", xpBar, "RIGHT", 45, 5)
overlayClassFrame:SetWidth((cfg.classIcon and cfg.classIcon.size) or 20)
overlayClassFrame:SetHeight((cfg.classIcon and cfg.classIcon.size) or 20)
local overlayClassTex = overlayClassFrame:CreateTexture(nil, "OVERLAY")
overlayClassTex:SetAllPoints(overlayClassFrame)
overlayClassTex:SetTexture("Interface\\Icons\\INV_Misc_QuestionMark")


-- ========== 刷新逻辑 ==========
local function UpdateXPBar()
    -- 检查是否应该显示XPBar
    local shouldShow = true
    if ImmersiveUIDB and ImmersiveUIDB.IfXPbarOn ~= nil then
        shouldShow = (ImmersiveUIDB.IfXPbarOn == 1)
    end
    
    if not shouldShow then
        -- 如果不应该显示，确保所有组件都隐藏
        xpBar:Hide()
        leftFrame:Hide()
        rightFrame:Hide()
        middleFrame:Hide()
        overlay:Hide()
        return
    end
    
    -- 确保组件都显示（防止状态不同步）
    if not xpBar:IsVisible() then
        xpBar:Show()
        leftFrame:Show()
        rightFrame:Show()
        middleFrame:Show()
        overlay:Show()
    end
    
    -- 更新经验条数据
    local curXP = UnitXP("player") or 0
    local maxXP = UnitXPMax("player") or 1
    if maxXP == 0 then maxXP = 1 end

    xpBar:SetMinMaxValues(0, maxXP)
    xpBar:SetValue(curXP)

    local col = cfg.color or {0.2,0.6,1.0}
    xpBar:SetStatusBarColor(col[1] or 0.2, col[2] or 0.6, col[3] or 1.0)

    local lvl = UnitLevel("player") or 0
    overlayLevelText:SetText(tostring(lvl))

    local _, classToken = UnitClass("player")
    local iconPath = nil
    if classToken and cfg.classIcon and cfg.classIcon.paths and cfg.classIcon.paths[classToken] then
        iconPath = cfg.classIcon.paths[classToken]
    end
    if iconPath then
        overlayClassTex:SetTexture(iconPath)
    else
        overlayClassTex:SetTexture("Interface\\Icons\\INV_Misc_QuestionMark")
    end
end

-- ========== 显示/隐藏控制函数 ==========
function XPBar_UpdateDisplay()
    -- 检查ImmersiveUIDB是否存在以及IfXPbarOn的值
    local shouldShow = true -- 默认显示
    if ImmersiveUIDB and ImmersiveUIDB.IfXPbarOn ~= nil then
        shouldShow = (ImmersiveUIDB.IfXPbarOn == 1)
    end
    
    if shouldShow then
        -- 显示所有组件
        xpBar:Show()
        leftFrame:Show()
        rightFrame:Show()
        middleFrame:Show()
        overlay:Show()
        
        -- 重要：重新更新经验条数据
        UpdateXPBar()
    else
        -- 隐藏所有组件
        xpBar:Hide()
        leftFrame:Hide()
        rightFrame:Hide()
        middleFrame:Hide()
        overlay:Hide()
    end
end
-- ========== 事件处理 ==========
local eventFrame = CreateFrame("Frame")
eventFrame:RegisterEvent("PLAYER_LOGIN")
eventFrame:RegisterEvent("PLAYER_XP_UPDATE")
eventFrame:RegisterEvent("PLAYER_LEVEL_UP")
eventFrame:RegisterEvent("VARIABLES_LOADED") -- 添加这个事件来确保SavedVariables已加载

eventFrame:SetScript("OnEvent", function()
    local event = arg1 or event
    if event == "VARIABLES_LOADED" then
        -- SavedVariables加载完成后，检查显示状态
        XPBar_UpdateDisplay()
    end
    UpdateXPBar()
end)

-- 如果已经登录，立即更新
if IsLoggedIn and IsLoggedIn() then
    UpdateXPBar()
end
