-- ImmersiveDialogUI.lua (修正SavedVariables保存问题并添加XPBar控制和按键绑定)

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
    xOffsetOffset = 4.5, -- 这个值会根据TextLanguage动态变化
    FadeDuration = 0.1,
    IfXPbarOn = 1,
    KEY_YES = "E", -- 新增：接受按键
    KEY_NO = "R",  -- 新增：拒绝/返回按键
}

-- 获取动态默认值的函数
local function GetDynamicDefault(name)
    if name == "xOffsetOffset" then
        -- 根据当前TextLanguage状态返回对应的默认值
        local currentLanguage = ImmersiveUIDB and ImmersiveUIDB.TextLanguage
        if currentLanguage then
            return 3.1  -- 中文时的默认值
        else
            return 4.5  -- 英文时的默认值
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
        local newXOffsetDefault = val and 3.1 or 4.5
        -- 只有当前xOffsetOffset是默认值时才自动调整
        local currentXOffset = ImmersiveUIDB.xOffsetOffset
        local oldXOffsetDefault = val and 4.5 or 3.1  -- 之前的默认值
        
        -- 如果当前值等于之前的默认值，则更新为新的默认值
        if currentXOffset == oldXOffsetDefault then
            ImmersiveUIDB.xOffsetOffset = newXOffsetDefault
            -- 更新滑块显示
            local xOffsetSlider = getglobal("IDUI_Slider_xOffsetOffset")
            if xOffsetSlider then
                xOffsetSlider:SetValue(newXOffsetDefault)
                UpdateSliderVisuals(xOffsetSlider, newXOffsetDefault, 0.1)
            end
        end
    end
    
    -- 如果是XPBar开关，立即通知XPBar更新
    if name == "IfXPbarOn" and XPBar_UpdateDisplay then
        XPBar_UpdateDisplay()
    end
    
    -- 强制保存到磁盘（虽然这在1.12中可能不会立即生效）
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
        -- 对于XPBar开关，转换为数字格式
        if name == "IfXPbarOn" then
            SetVar(name, checked and 1 or 0)
        else
            SetVar(name, checked)
        end
    end)
    return cb, lbl
end

-- ================= 修正：按键绑定框逻辑 =================
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

    -- 修正第一步：将设置的名称(name)保存到按钮对象上
    btn.bindingName = name

    local lbl = parent:CreateFontString(frameName .. "_Label", "ARTWORK", "GameFontNormal")
    lbl:SetText(title)
    
    local keyText = btn:CreateFontString(frameName .. "_KeyText", "OVERLAY", "GameFontNormal")
    keyText:SetPoint("CENTER", btn, "CENTER", 0, 0) -- 此行已确保文字居中
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
                
                -- 修正第二步：从按钮对象获取正确的 bindingName
                local currentBindingName = button.bindingName

                -- 不允许绑定 ESCAPE
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


local function CreateConfigPanel()
    if ImmersiveDialogUIConfigFrame then return end

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
        { name = "xOffsetOffset", title = "Typewriter Text XOffset", min = 0.0, max = 10.0, step = 0.1, def = IDUI_Defaults.xOffsetOffset },
        { name = "FadeDuration", title = "Fade in Duration", min = 0.0, max = 1.0, step = 0.01, def = IDUI_Defaults.FadeDuration },
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
        local s, lbl = CreateSlider(f, d.name, d.title, d.min, d.max, d.step, d.def)
        s:SetPoint("TOPLEFT", f, "TOPLEFT", x, y)
        lbl:SetPoint("BOTTOMLEFT", s, "TOPLEFT", 0, 4)
    end

    -- 创建复选框和按键绑定区域
    local right_col_rows = total - rows
    local control_y_start = startY - (right_col_rows) * rowSpacing
    
    -- TextLanguage 复选框
    local cb1, cbLabel1 = CreateCheck(f, "TextLanguage", "Select when Text is Hanzi中文 日文 韓文...", IDUI_Defaults.TextLanguage)
    cb1:SetPoint("TOPLEFT", f, "TOPLEFT", rightX-3, control_y_start+13)
    cbLabel1:SetPoint("LEFT", cb1, "RIGHT", 6, 0)

    -- XPBar 复选框
    local cb2, cbLabel2 = CreateCheck(f, "IfXPbarOn", "XP bar looks like GuildWars 2", IDUI_Defaults.IfXPbarOn == 1)
    cb2:SetPoint("TOPLEFT", cb1, "BOTTOMLEFT", 0, 5)
    cbLabel2:SetPoint("LEFT", cb2, "RIGHT", 6, 0)
    
    -- Accept 按键绑定
    local kb1, kbLabel1 = CreateKeybinding(f, "KEY_YES", "Accept", IDUI_Defaults.KEY_YES)
    kb1:SetPoint("BOTTOM", f, "BOTTOM", -45, 12)
    -- 修正布局：将标签放在右侧
    kbLabel1:SetPoint("BOTTOM", kb1, "TOP", 0, 4)
    
    -- Decline 按键绑定
    local kb2, kbLabel2 = CreateKeybinding(f, "KEY_NO", "Decline", IDUI_Defaults.KEY_NO)
    kb2:SetPoint("TOPLEFT", kb1, "TOPRIGHT", 10, 0)
    -- 修正布局：将标签放在右侧
    kbLabel2:SetPoint("BOTTOM", kb2, "TOP", 0, 4)

    local resetBtn = CreateFrame("Button", "IDUI_ResetBtn", f, "UIPanelButtonTemplate")
    resetBtn:SetWidth(80)
    resetBtn:SetHeight(22)
    resetBtn:SetText("Reset")
    resetBtn:SetPoint("BOTTOMLEFT", f, "BOTTOMLEFT", 16, 12)
    resetBtn:SetScript("OnClick", function()
        -- 保存当前的TextLanguage状态，不重置它
        local currentTextLanguage = ImmersiveUIDB.TextLanguage
        
        for i=1, table.getn(defs) do
            local d = defs[i]
            local resetValue
            if d.name == "xOffsetOffset" then
                -- 根据当前TextLanguage状态决定xOffsetOffset的重置值
                resetValue = currentTextLanguage and 3.1 or 4.5
            else
                resetValue = d.def
            end
            
            SetVar(d.name, resetValue)
            local s = getglobal("IDUI_Slider_"..d.name)
            if s then 
                s:SetValue(resetValue)
                UpdateSliderVisuals(s, resetValue, d.step)
            end
        end
        
        -- 重置其他设置
        SetVar("TextLanguage", currentTextLanguage)
        SetVar("IfXPbarOn", 1)
        SetVar("KEY_YES", IDUI_Defaults.KEY_YES)
        SetVar("KEY_NO", IDUI_Defaults.KEY_NO)

        -- 更新UI显示
        local cb1 = getglobal("IDUI_Check_TextLanguage")
        if cb1 then if currentTextLanguage then cb1:SetChecked(1) else cb1:SetChecked(nil) end end
        
        local cb2 = getglobal("IDUI_Check_IfXPbarOn")
        if cb2 then cb2:SetChecked(1) end
        
        local kb1 = getglobal("IDUI_Keybind_KEY_YES")
        if kb1 then kb1.keyText:SetText(IDUI_Defaults.KEY_YES) end
        
        local kb2 = getglobal("IDUI_Keybind_KEY_NO")
        if kb2 then kb2.keyText:SetText(IDUI_Defaults.KEY_NO) end
        
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
        -- 更新滑块
        for i = 1, table.getn(defs) do
            local d = defs[i]
            local slider = getglobal("IDUI_Slider_" .. d.name)
            if slider then
                local cur = ImmersiveUIDB[d.name]
                if cur == nil then
                    cur = GetDynamicDefault(d.name)
                end
                slider:SetValue(cur)
                UpdateSliderVisuals(slider, cur, d.step)
            end
        end
        
        -- 更新复选框
        local cbObj1 = getglobal("IDUI_Check_TextLanguage")
        if cbObj1 then if ImmersiveUIDB.TextLanguage then cbObj1:SetChecked(1) else cbObj1:SetChecked(nil) end end
        
        local cbObj2 = getglobal("IDUI_Check_IfXPbarOn")
        if cbObj2 then if ImmersiveUIDB.IfXPbarOn == 1 then cbObj2:SetChecked(1) else cbObj2:SetChecked(nil) end end

        -- 更新按键绑定
        local kbObj1 = getglobal("IDUI_Keybind_KEY_YES")
        if kbObj1 then kbObj1.keyText:SetText(ImmersiveUIDB.KEY_YES or IDUI_Defaults.KEY_YES) end

        local kbObj2 = getglobal("IDUI_Keybind_KEY_NO")
        if kbObj2 then kbObj2.keyText:SetText(ImmersiveUIDB.KEY_NO or IDUI_Defaults.KEY_NO) end
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