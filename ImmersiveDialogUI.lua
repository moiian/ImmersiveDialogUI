-- ImmersiveDialogUI.lua (修正SavedVariables保存问题并添加XPBar控制和按键绑定)
-- Version 2.1: Fixed tab creation logic to prevent UIPanelTemplates error.

local IDUI_Defaults = {
    TextBottomOffset = 35,
    TextWidthPct = 0.80,
    TitleBottomOffset = 100,
    RightColumnXOffset = -500,
    RightColumnYOffset = 0,
    RightColumnWidthPct = 0.15,
    AncillaryInitialYOffset = -30,
    AncillarySpacing = -20,
    ItemGridColumnSpacing = 50,
    ItemGridRowSpacing = -2,
    FontSize = 19,
    TextLanguage = false,
    xOffsetOffset = 3, -- 这个参数改为了WordMinLimit，决定句子的最短长度
    FadeDuration = 0.3,
    IfXPbarOn = 1,
    KEY_YES = "E", -- 接受按键
    KEY_NO = "R",  -- 拒绝/返回按键
	-- 新增副面板默认值
	IfCameraMode = 0, --相机模式开关
	IfButtonShow = 1, --按钮图标开关
	IfXBOXButton = 0  --XBOX图标开关
}

-- 获取动态默认值的函数
local function GetDynamicDefault(name)
    if name == "xOffsetOffset" then
        -- 根据当前TextLanguage状态返回对应的默认值
        local currentLanguage = ImmersiveUIDB and ImmersiveUIDB.TextLanguage
        if currentLanguage then
            return 6  -- 中文时的默认值
        else
            return 3  -- 英文时的默认值
        end
    else
        return IDUI_Defaults[name]
    end
end

-- 将UpdateSliderVisuals函数移到前面定义
local function UpdateSliderVisuals(slider, value, step)
    local valFS = slider.valueText
    if not valFS then return end
    
    local outv
    if step >= 1 then
        outv = math.floor(value + 0.5)
    else
        local ok, formatted = pcall(string.format, "%.2f", value)
        if ok then outv = tonumber(formatted) or value else outv = value end
    end
    valFS:SetText(tostring(outv))
	--DEFAULT_CHAT_FRAME:AddMessage("IfCameraMode is " .. ImmersiveUIDB.IfCameraMode) 
end

-- 全局变量初始化函数
local function InitializeDatabase()
    if not ImmersiveUIDB then 
        ImmersiveUIDB = {}
    end
    
    -- 确保所有默认值存在
    for k, v in pairs(IDUI_Defaults) do
        if ImmersiveUIDB[k] == nil then
            ImmersiveUIDB[k] = v
        end
    end
end

local function SetVar(name, val)
    InitializeDatabase()
    ImmersiveUIDB[name] = val
    
    -- 当TextLanguage改变时，自动调整xOffsetOffset
    if name == "TextLanguage" then
        local newXOffsetDefault = val and 6 or 3
        local currentXOffset = ImmersiveUIDB.xOffsetOffset
        local oldXOffsetDefault = val and 3 or 6  -- 之前的默认值
        
        if currentXOffset == oldXOffsetDefault then
            ImmersiveUIDB.xOffsetOffset = newXOffsetDefault
            local xOffsetSlider = getglobal("IDUI_Slider_xOffsetOffset")
            if xOffsetSlider then
                xOffsetSlider:SetValue(newXOffsetDefault)
                UpdateSliderVisuals(xOffsetSlider, newXOffsetDefault, 0.1)
            end
        end
    end
    
    if name == "IfXPbarOn" and XPBar_UpdateDisplay then
        XPBar_UpdateDisplay()
    end
    
    if SaveBindings then
        SaveBindings(1)
    end
end

local function CreateSlider(parent, name, title, minV, maxV, step, default)
    local frameName = "IDUI_Slider_" .. name
    local s = CreateFrame("Slider", frameName, parent, "OptionsSliderTemplate")
    s:SetMinMaxValues(minV, maxV)
    s:SetValueStep(step)
    s:SetWidth(220)
    s:SetHeight(16)

    local lbl = parent:CreateFontString(frameName .. "_Label", "ARTWORK", "GameFontNormal")
    lbl:SetText(title)
    lbl:SetJustifyH("LEFT")

    local valFS = parent:CreateFontString(frameName .. "_Value", "ARTWORK", "GameFontHighlightSmall")
    s.valueText = valFS

    s:SetValue(default)
    UpdateSliderVisuals(s, default, step)
    valFS:SetPoint("LEFT", s, "RIGHT", 10, 0)

    s:SetScript("OnValueChanged", function()
        if not this or not this.GetValue then return end
        local v = this:GetValue()
        local formattedValue = tonumber(string.format("%.2f", v))
        SetVar(name, formattedValue)
        UpdateSliderVisuals(this, formattedValue, step)
    end)

    return s, lbl
end

local function CreateCheck(parent, name, title, default)
    local cbName = "IDUI_Check_" .. name
    local cb = CreateFrame("CheckButton", cbName, parent, "UICheckButtonTemplate")
    cb:SetWidth(26)
    cb:SetHeight(26)
    local lbl = parent:CreateFontString(cbName .. "_Label", "ARTWORK", "GameFontNormal")
    lbl:SetText(title)
    lbl:SetJustifyH("LEFT")
    if default then cb:SetChecked(1) else cb:SetChecked(nil) end
    cb:SetScript("OnClick", function()
        local checked = false
        if this and this.GetChecked and this:GetChecked() then 
            checked = true 
        end
        -- 对于需要返回1或0的开关进行转换
        if name == "IfXPbarOn" or name == "IfCameraMode" or name == "IfButtonShow" or name == "IfXBOXButton" then
            SetVar(name, checked and 1 or 0)
        else
            SetVar(name, checked)
        end
    end)
    return cb, lbl
end

-- ================= 按键绑定框逻辑 =================
local IDUI_KeybindCaptureFrame = nil
local IDUI_CurrentBindingButton = nil

local function CreateKeybinding(parent, name, title, default)
    local frameName = "IDUI_Keybind_" .. name
    local btn = CreateFrame("Button", frameName, parent,"UIPanelButtonTemplate")
    btn:SetWidth(80)
    btn:SetHeight(21)
    btn:SetNormalTexture("Interface\\Buttons\\UI-Panel-Button-Up")
    btn:SetPushedTexture("Interface\\Buttons\\UI-Panel-Button-Down")
    btn:SetHighlightTexture("Interface\\Buttons\\UI-Panel-Button-Highlight")
    btn.bindingName = name

    local lbl = parent:CreateFontString(frameName .. "_Label", "ARTWORK", "GameFontNormal")
    lbl:SetText(title)
    
    local keyText = btn:CreateFontString(frameName .. "_KeyText", "OVERLAY", "GameFontNormal")
    keyText:SetPoint("CENTER", btn, "CENTER", 0, 0)
    keyText:SetText(default or "")
    btn.keyText = keyText

    btn:SetScript("OnClick", function()
        if IDUI_KeybindCaptureFrame and IDUI_KeybindCaptureFrame:IsShown() then return end
        IDUI_CurrentBindingButton = this
        this.keyText:SetText("...")
        if not IDUI_KeybindCaptureFrame then
            IDUI_KeybindCaptureFrame = CreateFrame("Frame", "IDUI_KeybindCaptureFrame", UIParent)
            IDUI_KeybindCaptureFrame:SetFrameStrata("FULLSCREEN_DIALOG")
            IDUI_KeybindCaptureFrame:SetAllPoints(UIParent)
            IDUI_KeybindCaptureFrame:EnableKeyboard(true)
            IDUI_KeybindCaptureFrame:SetScript("OnKeyDown", function()
                local key = arg1
                local button = IDUI_CurrentBindingButton
                IDUI_KeybindCaptureFrame:Hide()
                if not button or not button.bindingName then return end
                local currentBindingName = button.bindingName
                if key == "ESCAPE" then
                    button.keyText:SetText(ImmersiveUIDB[currentBindingName] or IDUI_Defaults[currentBindingName])
                    return
                end
                SetVar(currentBindingName, key)
                button.keyText:SetText(key)
                IDUI_CurrentBindingButton = nil
            end)
            IDUI_KeybindCaptureFrame:SetScript("OnMouseDown", function()
                local button = IDUI_CurrentBindingButton
                IDUI_KeybindCaptureFrame:Hide()
                if button and button.bindingName then
                    local currentBindingName = button.bindingName
                    button.keyText:SetText(ImmersiveUIDB[currentBindingName] or IDUI_Defaults[currentBindingName])
                end
                IDUI_CurrentBindingButton = nil
            end)
        end
        IDUI_KeybindCaptureFrame:Show()
    end)
    return btn, lbl
end


-- ================= 面板创建核心函数 =================
local function CreateConfigPanel()
    if ImmersiveDialogUIConfigFrame then return end

    -- 1. 创建主框架
    local f = CreateFrame("Frame", "ImmersiveDialogUIConfigFrame", UIParent)
    f:SetWidth(560)
    f:SetHeight(500)
    f:SetPoint("CENTER", UIParent, "CENTER", 0, 0)
    f:SetBackdrop({
        bgFile = "Interface\\DialogFrame\\UI-DialogBox-Background", 
        edgeFile = "Interface\\DialogFrame\\UI-DialogBox-Border",
        tile = true, tileSize = 16, edgeSize = 16, 
        insets = { left = 8, right = 8, top = 8, bottom = 8 }
    })
    f:SetBackdropColor(0,0,0,0.8)
    f:Hide()
    
    local title = f:CreateFontString(nil, "OVERLAY", "GameFontNormalLarge")
    title:SetPoint("TOP", f, "TOP", 0, -14)
    title:SetText("Immersive Dialog UI")
    
    local closeBtn = CreateFrame("Button", "IDUI_CloseButton", f, "UIPanelCloseButton")
    closeBtn:SetPoint("TOPRIGHT", f, "TOPRIGHT", -6, -6)

    -- 2. 创建主面板和副面板容器
    local mainPanel = CreateFrame("Frame", "IDUI_MainPanel", f)
    mainPanel:SetAllPoints(f)
    
    local miscPanel = CreateFrame("Frame", "IDUI_MiscPanel", f)
    miscPanel:SetAllPoints(f)
    miscPanel:Hide()

    -- 3. 【修正部分】创建和设置标签页按钮
    local tabHUD = CreateFrame("CheckButton", "IDUI_Tab_HUD", f, "CharacterFrameTabButtonTemplate")
    tabHUD:SetText("HUD")
    tabHUD:SetPoint("BOTTOMLEFT", f, "TOPLEFT", 0, -30)

    local tabMisc = CreateFrame("CheckButton", "IDUI_Tab_Misc", f, "CharacterFrameTabButtonTemplate")
    tabMisc:SetText("Misc")
    tabMisc:SetPoint("LEFT", tabHUD, "RIGHT", -15, 0)
    
    tabHUD:SetScript("OnClick", function()
        tabMisc:SetChecked(nil) -- 取消另一个按钮的选中状态
        this:SetChecked(1)      -- 确保当前按钮是选中状态
        mainPanel:Show()
        miscPanel:Hide()
    end)

    tabMisc:SetScript("OnClick", function()
        tabHUD:SetChecked(nil)  -- 取消另一个按钮的选中状态
        this:SetChecked(1)      -- 确保当前按钮是选中状态
        mainPanel:Hide()
        miscPanel:Show()
    end)

    -- 设置初始选中的标签页
    tabHUD:SetChecked(1)

    -- 4. 填充主面板 (HUD)
    local defs = {
        { name = "TextBottomOffset", title = "Main Text YOffset", min = -200, max = 200, step = 1, def = IDUI_Defaults.TextBottomOffset },
        { name = "TextWidthPct", title = "Main Text Width", min = 0.10, max = 1.00, step = 0.01, def = IDUI_Defaults.TextWidthPct },
        { name = "TitleBottomOffset", title = "Main Title YOffset", min = -200, max = 400, step = 1, def = IDUI_Defaults.TitleBottomOffset },
        { name = "RightColumnXOffset", title = "Right Frame XOffset", min = -1000, max = 0, step = 1, def = IDUI_Defaults.RightColumnXOffset },
        { name = "RightColumnYOffset", title = "Right Frame YOffset", min = -500, max = 500, step = 1, def = IDUI_Defaults.RightColumnYOffset },
        { name = "RightColumnWidthPct", title = "Right Frame Width", min = 0.05, max = 0.50, step = 0.01, def = IDUI_Defaults.RightColumnWidthPct },
        { name = "AncillaryInitialYOffset", title = "Right Text YOffset", min = -300, max = 300, step = 1, def = IDUI_Defaults.AncillaryInitialYOffset },
        { name = "AncillarySpacing", title = "Right Text Spacing", min = -200, max = 200, step = 1, def = IDUI_Defaults.AncillarySpacing },
        { name = "ItemGridColumnSpacing", title = "Reward Item Column Spacing", min = 0, max = 300, step = 1, def = IDUI_Defaults.ItemGridColumnSpacing },
        { name = "ItemGridRowSpacing", title = "Reward Item Row Spacing", min = -50, max = 50, step = 1, def = IDUI_Defaults.ItemGridRowSpacing },
        { name = "FontSize", title = "Font Size", min = 8, max = 40, step = 1, def = IDUI_Defaults.FontSize },
        { name = "xOffsetOffset", title = "Length of Shortest Sentence", min = 2, max = 15, step = 1, def = IDUI_Defaults.xOffsetOffset },
        { name = "FadeDuration", title = "Fade in Duration", min = 0.0, max = 2.0, step = 0.01, def = IDUI_Defaults.FadeDuration },
    }
    
    local total = table.getn(defs)
    local cols = 2
    local rows = math.ceil(total / cols)
    local availableHeight = 500 * 0.75
    local topMargin = (500 - availableHeight) / 2 + 15
    local rowSpacing = availableHeight / rows
    if rowSpacing < 30 then rowSpacing = 30 end
    local leftX = 24
    local columnGap = 260
    local rightX = leftX + columnGap
    local startY = -topMargin - 14

    for i = 1, total do
        local d = defs[i]
        local col = (i <= rows) and 1 or 2
        local row = (col == 1) and i or (i - rows)
        local x = (col == 1) and leftX or rightX
        local y = startY - (row - 1) * rowSpacing
        -- 将所有控件的父容器设置为 mainPanel
        local s, lbl = CreateSlider(mainPanel, d.name, d.title, d.min, d.max, d.step, d.def)
        s:SetPoint("TOPLEFT", mainPanel, "TOPLEFT", x, y)
        lbl:SetPoint("BOTTOMLEFT", s, "TOPLEFT", 0, 4)
    end

    local right_col_rows = total - rows
    local control_y_start = startY - (right_col_rows) * rowSpacing
    
    local cb1, cbLabel1 = CreateCheck(mainPanel, "TextLanguage", "Select when Text is Hanzi中文 日文 韓文...", IDUI_Defaults.TextLanguage)
    cb1:SetPoint("TOPLEFT", mainPanel, "TOPLEFT", rightX-3, control_y_start+13)
    cbLabel1:SetPoint("LEFT", cb1, "RIGHT", 6, 0)

    local cb2, cbLabel2 = CreateCheck(mainPanel, "IfXPbarOn", "XP bar looks like GuildWars 2", IDUI_Defaults.IfXPbarOn == 1)
    cb2:SetPoint("TOPLEFT", cb1, "BOTTOMLEFT", 0, 5)
    cbLabel2:SetPoint("LEFT", cb2, "RIGHT", 6, 0)
    
    local kb1, kbLabel1 = CreateKeybinding(mainPanel, "KEY_YES", "Accept", IDUI_Defaults.KEY_YES)
    kb1:SetPoint("BOTTOM", mainPanel, "BOTTOM", -45, 12)
    kbLabel1:SetPoint("BOTTOM", kb1, "TOP", 0, 4)
    
    local kb2, kbLabel2 = CreateKeybinding(mainPanel, "KEY_NO", "Decline", IDUI_Defaults.KEY_NO)
    kb2:SetPoint("TOPLEFT", kb1, "TOPRIGHT", 10, 0)
    kbLabel2:SetPoint("BOTTOM", kb2, "TOP", 0, 4)

    -- 5. 填充副面板 (Misc)
    do
        local leftColX = 40
        local rightColX = leftX + columnGap
        local currentY = -60

        -- 左列: Camera
        local cameraTitle = miscPanel:CreateFontString(nil, "OVERLAY", "GameFontNormalLarge")
        cameraTitle:SetPoint("TOPLEFT", miscPanel, "TOPLEFT", leftColX, currentY)
        cameraTitle:SetText("Camera")
        currentY = currentY - 30

        local camCheck, camCheckLabel = CreateCheck(miscPanel, "IfCameraMode", "Dialog Camera", ImmersiveUIDB.IfCameraMode == 1)
        camCheck:SetPoint("TOPLEFT", cameraTitle, "BOTTOMLEFT", -4, -10)
        camCheckLabel:SetPoint("LEFT", camCheck, "RIGHT", 6, 0)
        currentY = currentY - 40

        local setDefaultCam = CreateFrame("Button", "IDUI_SetCamBtn", miscPanel, "UIPanelButtonTemplate")
        setDefaultCam:SetWidth(150)
        setDefaultCam:SetHeight(25)
        setDefaultCam:SetText("Set Default Camera")
        setDefaultCam:SetPoint("TOPLEFT", camCheck, "BOTTOMLEFT", 0, -10)
        setDefaultCam:SetScript("OnClick", function() if SaveView then SaveView(5) end end)
		
        local setCamButton = CreateFrame("Button", "IDUI_SetCamBtn", miscPanel, "UIPanelButtonTemplate")
        setCamButton:SetWidth(150)
        setCamButton:SetHeight(25)
        setCamButton:SetText("Set Dialog Camera")
        setCamButton:SetPoint("TOPLEFT", setDefaultCam, "BOTTOMLEFT", 0, -10)
        setCamButton:SetScript("OnClick", function() if SaveView then SaveView(2) end end)
        
        local setCamDesc = miscPanel:CreateFontString(nil, "ARTWORK", "GameFontHighlightSmall")
        setCamDesc:SetPoint("TOPLEFT", setCamButton, "BOTTOMLEFT", 0, -8)
        setCamDesc:SetWidth(200)
        setCamDesc:SetJustifyH("LEFT")
        setCamDesc:SetText("These buttons will save your current camera view. \nSo here are your steps:\n\n1.Zoom in the camera, adjust the angle, and click the Set Dialog Camera button.\n\nFrom now on, your dialogue camera will match the current view.\n\n2.(Optional) If you want to modify the camera for non-dialogue scenarios, simply click Set Default Camera.")
        
        -- 右列: Button Style
        currentY = -60 -- 重置Y坐标供右列使用
        local styleTitle = miscPanel:CreateFontString(nil, "OVERLAY", "GameFontNormalLarge")
        styleTitle:SetPoint("TOPLEFT", miscPanel, "TOPLEFT", rightColX, currentY)
        styleTitle:SetText("Button Style")
        currentY = currentY - 30

        local showBtnCheck, showBtnLabel = CreateCheck(miscPanel, "IfButtonShow", "If Show Button Icon", ImmersiveUIDB.IfButtonShow == 1)
        showBtnCheck:SetPoint("TOPLEFT", styleTitle, "BOTTOMLEFT", -4, -10)
        showBtnLabel:SetPoint("LEFT", showBtnCheck, "RIGHT", 6, 0)
        currentY = currentY - 40
        
        local xboxBtnCheck, xboxBtnLabel = CreateCheck(miscPanel, "IfXBOXButton", "If Show XBOX Icon", ImmersiveUIDB.IfXBOXButton == 1)
        xboxBtnCheck:SetPoint("TOPLEFT", showBtnCheck, "BOTTOMLEFT", 0, -5)
        xboxBtnLabel:SetPoint("LEFT", xboxBtnCheck, "RIGHT", 6, 0)
    end
    
    -- 6. 创建通用底部按钮
    local resetBtn = CreateFrame("Button", "IDUI_ResetBtn", f, "UIPanelButtonTemplate")
    resetBtn:SetWidth(80)
    resetBtn:SetHeight(22)
    resetBtn:SetText("Reset")
    resetBtn:SetPoint("BOTTOMLEFT", f, "BOTTOMLEFT", 16, 12)
    resetBtn:SetScript("OnClick", function()
        local currentTextLanguage = ImmersiveUIDB.TextLanguage
        
        -- 重置主面板滑块
        for i=1, table.getn(defs) do
            local d = defs[i]
            local resetValue = (d.name == "xOffsetOffset") and (currentTextLanguage and 6 or 3) or d.def
            SetVar(d.name, resetValue)
            local s = getglobal("IDUI_Slider_"..d.name)
            if s then 
                s:SetValue(resetValue)
                UpdateSliderVisuals(s, resetValue, d.step)
            end
        end
        
        -- 重置其他设置
        SetVar("TextLanguage", currentTextLanguage)
        SetVar("IfXPbarOn", IDUI_Defaults.IfXPbarOn)
        SetVar("KEY_YES", IDUI_Defaults.KEY_YES)
        SetVar("KEY_NO", IDUI_Defaults.KEY_NO)
        SetVar("IfCameraMode", IDUI_Defaults.IfCameraMode)
        SetVar("IfButtonShow", IDUI_Defaults.IfButtonShow)
        SetVar("IfXBOXButton", IDUI_Defaults.IfXBOXButton)

        -- 刷新UI显示
        -- 主面板
        local cb1 = getglobal("IDUI_Check_TextLanguage"); if cb1 then if currentTextLanguage then cb1:SetChecked(1) else cb1:SetChecked(nil) end end
        local cb2 = getglobal("IDUI_Check_IfXPbarOn"); if cb2 then if IDUI_Defaults.IfXPbarOn == 1 then cb2:SetChecked(1) else cb2:SetChecked(nil) end end
        local kb1 = getglobal("IDUI_Keybind_KEY_YES"); if kb1 then kb1.keyText:SetText(IDUI_Defaults.KEY_YES) end
        local kb2 = getglobal("IDUI_Keybind_KEY_NO"); if kb2 then kb2.keyText:SetText(IDUI_Defaults.KEY_NO) end
        -- 副面板
        local cbCam = getglobal("IDUI_Check_IfCameraMode"); if cbCam then if IDUI_Defaults.IfCameraMode == 1 then cbCam:SetChecked(1) else cbCam:SetChecked(nil) end end
        local cbShow = getglobal("IDUI_Check_IfButtonShow"); if cbShow then if IDUI_Defaults.IfButtonShow == 1 then cbShow:SetChecked(1) else cbShow:SetChecked(nil) end end
        local cbXbox = getglobal("IDUI_Check_IfXBOXButton"); if cbXbox then if IDUI_Defaults.IfXBOXButton == 1 then cbXbox:SetChecked(1) else cbXbox:SetChecked(nil) end end
        
        if DEFAULT_CHAT_FRAME then 
            DEFAULT_CHAT_FRAME:AddMessage("IDUI: Settings have been reset (Language setting preserved).") 
        end
    end)

    local closeBottom = CreateFrame("Button", "IDUI_CloseBottom", f, "UIPanelButtonTemplate")
    closeBottom:SetWidth(80)
    closeBottom:SetHeight(22)
    closeBottom:SetText("Close")
    closeBottom:SetPoint("BOTTOMRIGHT", f, "BOTTOMRIGHT", -16, 12)
    closeBottom:SetScript("OnClick", function() f:Hide() end)

    f:SetScript("OnShow", function()
        InitializeDatabase()
        -- 更新主面板滑块
        for i = 1, table.getn(defs) do
            local d = defs[i]
            local slider = getglobal("IDUI_Slider_" .. d.name)
            if slider then
                local cur = ImmersiveUIDB[d.name] or GetDynamicDefault(d.name)
                slider:SetValue(cur)
                UpdateSliderVisuals(slider, cur, d.step)
            end
        end
        
        -- 更新主面板复选框和按键
        local cbObj1 = getglobal("IDUI_Check_TextLanguage"); if cbObj1 then if ImmersiveUIDB.TextLanguage then cbObj1:SetChecked(1) else cbObj1:SetChecked(nil) end end
        local cbObj2 = getglobal("IDUI_Check_IfXPbarOn"); if cbObj2 then if ImmersiveUIDB.IfXPbarOn == 1 then cbObj2:SetChecked(1) else cbObj2:SetChecked(nil) end end
        local kbObj1 = getglobal("IDUI_Keybind_KEY_YES"); if kbObj1 then kbObj1.keyText:SetText(ImmersiveUIDB.KEY_YES or IDUI_Defaults.KEY_YES) end
        local kbObj2 = getglobal("IDUI_Keybind_KEY_NO"); if kbObj2 then kbObj2.keyText:SetText(ImmersiveUIDB.KEY_NO or IDUI_Defaults.KEY_NO) end

        -- 更新副面板复选框
        local cbCam = getglobal("IDUI_Check_IfCameraMode"); if cbCam then if ImmersiveUIDB.IfCameraMode == 1 then cbCam:SetChecked(1) else cbCam:SetChecked(nil) end end
        local cbShow = getglobal("IDUI_Check_IfButtonShow"); if cbShow then if ImmersiveUIDB.IfButtonShow == 1 then cbShow:SetChecked(1) else cbShow:SetChecked(nil) end end
        local cbXbox = getglobal("IDUI_Check_IfXBOXButton"); if cbXbox then if ImmersiveUIDB.IfXBOXButton == 1 then cbXbox:SetChecked(1) else cbXbox:SetChecked(nil) end end
    end)
    
    f:SetScript("OnHide", function()
        if DEFAULT_CHAT_FRAME then
            DEFAULT_CHAT_FRAME:AddMessage("IDUI: Settings saved. Type /reload to ensure all changes take effect.")
        end
    end)
end

-- 事件处理框架
local IDUI_EventFrame = CreateFrame("Frame")
IDUI_EventFrame:RegisterEvent("ADDON_LOADED")
IDUI_EventFrame:RegisterEvent("VARIABLES_LOADED")
IDUI_EventFrame:RegisterEvent("PLAYER_ENTERING_WORLD")
IDUI_EventFrame:SetScript("OnEvent", function()
    local event = arg1
    local addonName = arg2
    
    if event == "ADDON_LOADED" and addonName == "ImmersiveDialogUI" then
        InitializeDatabase()
        CreateConfigPanel()
        if DEFAULT_CHAT_FRAME then
            DEFAULT_CHAT_FRAME:AddMessage("ImmersiveDialogUI loaded. Type /idui to configure.")
        end
    elseif event == "VARIABLES_LOADED" then
        InitializeDatabase()
    elseif event == "PLAYER_ENTERING_WORLD" then
        InitializeDatabase()
    end
end)

-- 斜线命令
SLASH_IDUI1 = "/idui"
SlashCmdList["IDUI"] = function()
    if not ImmersiveDialogUIConfigFrame then 
        CreateConfigPanel() 
    end
    if ImmersiveDialogUIConfigFrame:IsShown() then 
        ImmersiveDialogUIConfigFrame:Hide() 
    else 
        ImmersiveDialogUIConfigFrame:Show() 
    end
end

-- 添加调试命令
SLASH_IDUICHECK1 = "/iduicheck"
SlashCmdList["IDUICHECK"] = function()
    if DEFAULT_CHAT_FRAME then
        if ImmersiveUIDB then
            DEFAULT_CHAT_FRAME:AddMessage("ImmersiveUIDB exists:")
            for k, v in pairs(ImmersiveUIDB) do
                DEFAULT_CHAT_FRAME:AddMessage("  " .. k .. " = " .. tostring(v))
            end
        else
            DEFAULT_CHAT_FRAME:AddMessage("ImmersiveUIDB does not exist!")
        end
    end
end