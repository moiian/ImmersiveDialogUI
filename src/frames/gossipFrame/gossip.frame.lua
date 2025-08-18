---@diagnostic disable: undefined-global
NUMGOSSIPBUTTONS = 32;

-- 【已移除】不再在文件顶部定义固定的布局变量
-- local GOSSIP_TEXT_FADE_DURATION = 0.1;
-- local LayoutConfig = { ... };

-- 全局常量与颜色定义（这些保持不变）
QUEST_FADING_DISABLE = "0";
local COLORS = {
    DarkBrown = {1, 1, 1},
    LightBrown = {1, 1, 1},
    Ivory = {1, 1, 1},
	TitleBrown = {0.99,0.83,0.07}
};

local totalGossipButtons = 0;

-- 文本分页显示状态变量
local DGossipTextChunks = {};
local DGossipCurrentChunkIndex = 1;
local DGossipTextFullyDisplayed = false;

-- 【已移除】不再需要 layoutApplied 标志
-- local layoutApplied = false;

-- =================================================================
-- ========= 核心布局函数（已重构） =================================
-- =================================================================
-- 此函数现在会在每次Gossip窗口显示时被调用，以应用最新的设置
function ApplyDynamicLayout()
    --[[
        【修改】配置加载逻辑已移入此函数内部。
        这确保了每次调用时都会从全局ImmersiveUIDB中读取最新的值。
    ]]
    local GOSSIP_DEFAULTS = {
        FadeDuration = 0.1,
        TextLanguage = false,
        TextBottomOffset = 35,
        TextWidthPct = 0.80,
        TitleBottomOffset = 100,
        RightColumnXOffset = -500,
        RightColumnYOffset = 0,
        RightColumnWidthPct = 0.25,
        AncillaryInitialYOffset = -10,
        AncillarySpacing = -10,
        FontSize = 19
    }
    local db = ImmersiveUIDB or {}

    -- 定义本次布局所需的变量
    local GOSSIP_TEXT_FADE_DURATION = db.FadeDuration or GOSSIP_DEFAULTS.FadeDuration
    _G.Text_Language = db.TextLanguage or GOSSIP_DEFAULTS.TextLanguage -- 使用_G使其全局化，如果其他地方需要

    local LayoutConfig = {
        TextBottomOffset = db.TextBottomOffset or GOSSIP_DEFAULTS.TextBottomOffset,
        TextWidthPct = db.TextWidthPct or GOSSIP_DEFAULTS.TextWidthPct,
        TitleBottomOffset = db.TitleBottomOffset or GOSSIP_DEFAULTS.TitleBottomOffset,
        RightColumnXOffset = db.RightColumnXOffset or GOSSIP_DEFAULTS.RightColumnXOffset,
        RightColumnYOffset = db.RightColumnYOffset or GOSSIP_DEFAULTS.RightColumnYOffset,
        FontSize = db.FontSize or GOSSIP_DEFAULTS.FontSize,
        RightColumnWidthPct = (db.RightColumnWidthPct or 0.15) + 0.10,
        AncillaryInitialYOffset = (db.AncillaryInitialYOffset or -30) + 20,
        AncillarySpacing = (db.AncillarySpacing or -20) + 10
    };

    -- 字体配置也需要在这里动态生成，因为它依赖于FontSize
    local FontConfig = {
        ButtonFont = "Fonts\\FRIZQT__.TTF",
        ButtonFontSize = LayoutConfig.FontSize - 3,
        ButtonFontFlags = "OUTLINE",
    };

    -- =================== 布局应用代码（来自原函数） ===================
    local screenWidth, screenHeight = GetScreenWidth(), GetScreenHeight();

    -- 步骤 1: 扩大父框架
    DGossipFrame:ClearAllPoints();
    DGossipFrame:SetAllPoints(UIParent);
    DGossipGreetingScrollFrame:ClearAllPoints();
    DGossipGreetingScrollFrame:SetAllPoints(DGossipFrame);
    DGossipGreetingScrollChildFrame:SetWidth(screenWidth);
    DGossipGreetingScrollChildFrame:SetHeight(screenHeight);

    -- 步骤 2: 布局文本和标题
    DGossipGreetingText:ClearAllPoints();
    DGossipGreetingText:SetWidth(screenWidth * LayoutConfig.TextWidthPct);
    DGossipGreetingText:SetPoint("BOTTOM", UIParent, "BOTTOM", 0, LayoutConfig.TextBottomOffset);
    DGossipGreetingText:SetJustifyH("CENTER");
	SetFontColor(DGossipGreetingText, "LightBrown", LayoutConfig.FontSize); -- 确保字体大小实时更新

    DGossipFrameNpcNameText:ClearAllPoints();
    DGossipFrameNpcNameText:SetWidth(screenWidth * LayoutConfig.TextWidthPct);
    DGossipFrameNpcNameText:SetPoint("BOTTOM", UIParent, "BOTTOM", 0, LayoutConfig.TitleBottomOffset);
    DGossipFrameNpcNameText:SetJustifyH("CENTER");
	SetFontColor(DGossipFrameNpcNameText, "TitleBrown"); -- 确保标题字体大小实时更新

    -- 步骤 3: 布局右侧按钮列
    DGossipFrameGreetingGoodbyeButton:ClearAllPoints();
    DGossipFrameGreetingGoodbyeButton:SetPoint("CENTER", UIParent, "RIGHT", LayoutConfig.RightColumnXOffset, LayoutConfig.RightColumnYOffset);
    SetFontColor(DGossipFrameGreetingGoodbyeButtonText,"LightBrown"); -- 确保字体大小实时更新


    local lastAnchor = DGossipFrameGreetingGoodbyeButton;

    for i = 1, NUMGOSSIPBUTTONS do
        local button = getglobal("DGossipTitleButton" .. i);
        if button then
            button:SetWidth(screenWidth * LayoutConfig.RightColumnWidthPct);
            local fontString = button:GetFontString();
            if fontString then
                fontString:SetFont(FontConfig.ButtonFont, FontConfig.ButtonFontSize, FontConfig.ButtonFontFlags);
            end

            button:ClearAllPoints();
            if i == 1 then
                button:SetPoint("TOPLEFT", lastAnchor, "BOTTOMLEFT", -35, LayoutConfig.AncillaryInitialYOffset);
			elseif i==8 then
				button:SetPoint("BOTTOMLEFT", DGossipFrameGreetingGoodbyeButton, "TOPLEFT", -35, -LayoutConfig.AncillaryInitialYOffset);
            elseif i<8 then
                button:SetPoint("TOPLEFT", lastAnchor, "BOTTOMLEFT", 0, LayoutConfig.AncillarySpacing);
            elseif i>8 then
                button:SetPoint("BOTTOMLEFT", lastAnchor, "TOPLEFT", 0, -LayoutConfig.AncillarySpacing);
            end
            
            lastAnchor = button;
        end
    end
end


-- =================================================================
-- ========= 核心工具及文本显示函数 ===================================
-- =================================================================

-- UTF-8 安全的字符字节数计算
local function utf8_charbytes(s, i)
    local c = string.byte(s, i)
    if not c then return 0 end
    if c > 240 then return 4
    elseif c > 224 then return 3
    elseif c > 192 then return 2
    else return 1 end
end

function SplitQuestTextToChunks(text, word_limit_en, char_limit_zh)
    -- 根據您的建議，將判斷邏輯內置
    local mode = Text_Language and "zh" or "en"
    
    local chunks = {}
    if type(text) ~= "string" or text == "" then return chunks end
    word_limit_en = word_limit_en or 25
    char_limit_zh = char_limit_zh or 45

    -- 1. 预处理：移除换行符和首尾空格
    text = string.gsub(text, "[\r\n]", " ") -- 将换行符统一变为空格，以正确计算单词数
    text = string.gsub(text, "^%s+", "")
    text = string.gsub(text, "%s+$", "")
    text = string.gsub(text, "%s+", " ") -- 将多个连续空格合并为单个，使单词计数更准确

    local buffer = ""
    local space_count = 0 -- 单词计数器 (英文模式)
    local char_count = 0  -- 字符计数器 (中文模式)
    
    local i, len = 1, string.len(text)
    while i <= len do
        -- 正确处理 UTF-8 字符
        local byte1 = string.byte(text, i)
        local charLen = (byte1 > 240 and 4) or (byte1 > 224 and 3) or (byte1 > 192 and 2) or 1
        local char = string.sub(text, i, i + charLen - 1)
        
        buffer = buffer .. char

        -- 2. 检查是否为终结符或特殊符号
        local should_split = false
        local is_ender_char = false

        -- 检查 "..." 和 "…"
        if char == "." and string.sub(text, i, i + 2) == "..." then
            -- 检测到 "..."，作为一个整体处理
            buffer = buffer .. ".." -- 补全省略号
            i = i + 2 -- 跳过后面两个点
            charLen = 3
            is_ender_char = true
        elseif char == "…" or char == "—" then
            -- 对于成对出现的符号，可以检查下一个是否也是同类
            local next_char_start = i + charLen
            if next_char_start <= len then
                local next_char_byte1 = string.byte(text, next_char_start)
                local next_charLen = (next_char_byte1 > 240 and 4) or (next_char_byte1 > 224 and 3) or (next_char_byte1 > 192 and 2) or 1
                if string.sub(text, next_char_start, next_char_start + next_charLen - 1) == char then
                    is_ender_char = true
                end
            end
        elseif char == "。" or char == "！" or char == "？" or char == "!" or char == "?" or char == ";" or char == "；" then
            is_ender_char = true
        elseif char == "." then
            -- 核心优化：处理 Mr.Z的情况
            -- 只有当句点后是空格，或是字符串结尾时，才认为是句子结束
            local next_char = string.sub(text, i + 1, i + 1)
            if next_char == " " or next_char == "" then
                is_ender_char = true
            end
        end

        -- 3. 根据模式判断是否分段
        if is_ender_char then
            if mode == "en" and space_count >= 3 then -- 英文模式下，句子至少有一定单词量，避免超短句
                should_split = true
            elseif mode == "zh" and char_count >= 10 then -- 中文模式下，句子至少有一定字数
                should_split = true
            end
        end
        
        -- 4. 检查是否达到长度上限，强制分段
        if not should_split then
            if mode == "en" and char == " " then
                space_count = space_count + 1
                if space_count >= word_limit_en then
                    should_split = true
                end
            elseif mode == "zh" then
                -- 在中文模式下，我们统计非符号字符的数量
                if not string.find("，。,！!？?；;……— ", char) then
                    char_count = char_count + 1
                    if char_count >= char_limit_zh then
                        should_split = true
                    end
                end
            end
        end

        -- 5. 执行分段
        if should_split then
            -- Trim a leading space from the new buffer if the split happens after a space
            local next_start = i + charLen
            if next_start <= len and string.sub(text, next_start, next_start) == " " then
                i = i + 1 -- 如果当前分段结尾是空格，下一个分段就跳过这个空格
            end
            table.insert(chunks, buffer)
            buffer, space_count, char_count = "", 0, 0
        end

        i = i + charLen
    end

    -- 6. 添加最后剩余的 buffer
    if string.gsub(buffer, "%s+", "") ~= "" then
        table.insert(chunks, buffer)
    end
    
    return chunks
end

function DGossip_SetTextAndFadeIn(fontString, text)
    if not fontString then return end
	local db = ImmersiveUIDB or {}
    local GOSSIP_TEXT_FADE_DURATION = db.FadeDuration or 0.1 -- 再次读取以保证淡入效果也是实时的
	
    if (QUEST_FADING_DISABLE == "1") then
        fontString:SetAlpha(1);
        fontString:SetText(text or "");
    else
        fontString:SetAlpha(0);
        fontString:SetText(text or "");
        UIFrameFadeIn(fontString, GOSSIP_TEXT_FADE_DURATION, 0, 1);
    end
end

-- =================================================================
-- ========= 封装后的文本分页逻辑函数 ================================
-- =================================================================

function ResetGossipPaginationState()
    DGossipTextChunks = {};
    DGossipCurrentChunkIndex = 1;
    DGossipTextFullyDisplayed = false;
end

function PlayNextGossipSentence()
    local sentence = DGossipTextChunks[DGossipCurrentChunkIndex] or "";
    DGossip_SetTextAndFadeIn(DGossipGreetingText, sentence);
    if DGossipCurrentChunkIndex >= table.getn(DGossipTextChunks) then
        DGossipTextFullyDisplayed = true;
    end
end

function StartGossipPagination(fullText)
    ResetGossipPaginationState();
    DGossipTextChunks = SplitQuestTextToChunks(fullText or "");
    if table.getn(DGossipTextChunks) == 0 then
        if fullText and fullText ~= "" then
            DGossipTextChunks = { fullText };
        else
            DGossipGreetingText:SetText("");
            DGossipTextFullyDisplayed = true;
            return;
        end
    end
    PlayNextGossipSentence();
end

function AdvanceGossip()
    if DGossipCurrentChunkIndex < table.getn(DGossipTextChunks) then
        DGossipCurrentChunkIndex = DGossipCurrentChunkIndex + 1;
        PlayNextGossipSentence();
    else
        DGossipTextFullyDisplayed = true;
        DGossipSelectOption(1);
    end
end

-- =================================================================
-- ========= 插件原有函数（有删改）====================================
-- =================================================================
GossipHiddenFrames = {}
local function GossipShouldKeepFrame(name)
    return name and (
        string.find(name, "^DQuest") or
        string.find(name, "^DGossip") or
		string.find(name, "^Gossip") or
        string.find(name, "^DMoneyFrame") or
        string.find(name, "^DUI") or
        name == "QuestFrame"
    )
end

function HideAllFramesExceptDGossip()
    GossipHiddenFrames = {}
	if QuestFrameCloseButton then QuestFrameCloseButton:Hide() end
    local children = { UIParent:GetChildren() }
    for _, frame in ipairs(children) do
        local name = frame:GetName()
        if frame:IsVisible() and not GossipShouldKeepFrame(name) then
           frame:Hide()
            table.insert(GossipHiddenFrames, frame)
        end
    end
end

function RestoreGossipHiddenFrames()
    for _, frame in ipairs(GossipHiddenFrames) do
        if frame and frame.Show then
            frame:Show()
        end
    end
    GossipHiddenFrames = {}
end

local function KillPortrait()
    if GossipFramePortrait then
        GossipFramePortrait:Hide()
        GossipFramePortrait.SetTexture = function() end
    end
    if DGossipFramePortrait then
        DGossipFramePortrait:Hide()
        DGossipFramePortrait.SetTexture = function() end
    end
end

function ShowBlackBars()
    local screenWidth = GetScreenWidth() or 1024;
	local screenHeight = GetScreenHeight() or 768;
	local barHeight = screenHeight * 0.10;
    if not DQuestTopBlackBar then
        DQuestTopBlackBar = CreateFrame("Frame", nil, UIParent);
        DQuestTopBlackBar:SetFrameStrata("BACKGROUND");
        DQuestTopBlackBar:SetBackdrop({ bgFile = "Interface\\Addons\\ImmersiveDialogUI\\src\\assets\\art\\parchment\\BlackBar" });
        DQuestTopBlackBar:SetBackdropColor(0, 0, 0, 0.95);
        DQuestTopBlackBar:SetPoint("TOPLEFT", UIParent, "TOPLEFT", -5, 5);
    end
    DQuestTopBlackBar:SetWidth(screenWidth+10);
    DQuestTopBlackBar:SetHeight(barHeight+10);
    DQuestTopBlackBar:Show();
    if not DQuestBottomBlackBar then
        DQuestBottomBlackBar = CreateFrame("Frame", nil, UIParent);
        DQuestBottomBlackBar:SetFrameStrata("BACKGROUND");
        DQuestBottomBlackBar:SetBackdrop({ bgFile = "Interface\\Addons\\ImmersiveDialogUI\\src\\assets\\art\\parchment\\BlackBar" });
        DQuestBottomBlackBar:SetBackdropColor(0, 0, 0, 0.95);
        DQuestBottomBlackBar:SetPoint("BOTTOMLEFT", UIParent, "BOTTOMLEFT", -5, 5);
    end
    DQuestBottomBlackBar:SetWidth(screenWidth+10);
    DQuestBottomBlackBar:SetHeight(barHeight+10);
    DQuestBottomBlackBar:Show();
end

function HideBlackBars()
    if DQuestTopBlackBar then DQuestTopBlackBar:Hide() end
    if DQuestBottomBlackBar then DQuestBottomBlackBar:Hide() end
end

function SetFontColor(fontObject, key, size)
    local color = COLORS[key];
    fontObject:SetTextColor(color[1], color[2], color[3]);
	local db = ImmersiveUIDB or {}
	local fontSize = size or db.FontSize or 19 -- 获取动态字体大小

	fontObject:SetFont("Fonts\\FRIZQT__.TTF", fontSize, "OUTLINE");
end

function HideDefaultFrames()
    if GossipFrameGreetingPanel then GossipFrameGreetingPanel:Hide() end
    if GossipNpcNameFrame then GossipNpcNameFrame:Hide() end
    if GossipFrameCloseButton then GossipFrameCloseButton:Hide() end
    if GossipFramePortrait then GossipFramePortrait:SetTexture() end
end

function DGossipFrame_OnLoad()
    HideDefaultFrames()
    this:RegisterEvent("GOSSIP_SHOW");
    this:RegisterEvent("GOSSIP_CLOSED");
	KillPortrait();
    
    if not DGossipKeyFrame then
        CreateFrame("Frame", "DGossipKeyFrame", UIParent)
        DGossipKeyFrame:SetScript("OnKeyDown", DGossipFrame_OnKeyDown)
        DGossipKeyFrame:EnableKeyboard(false)
        DGossipKeyFrame:SetToplevel(true)
        DGossipKeyFrame:SetAllPoints(UIParent)
        DGossipKeyFrame:SetFrameStrata("TOOLTIP")
    end
end

function DGossipFrame_OnEvent()
    if (event == "GOSSIP_SHOW") then
		-- 【修改】每次显示时都应用最新的布局和设置
		ApplyDynamicLayout();

        if (not DGossipFrame:IsVisible()) then
			HideAllFramesExceptDGossip();
            ShowUIPanel(DGossipFrame);
			ShowBlackBars();
            if (not DGossipFrame:IsVisible()) then
                DGossipFrame_CloseUI();
                return;
            end
        end
        DGossipFrameUpdate();
        StartGossipPagination(GetGossipText());
        DGossipKeyFrame:EnableKeyboard(true)
    elseif (event == "GOSSIP_CLOSED") then
        HideUIPanel(DGossipFrame);
        DGossipKeyFrame:EnableKeyboard(false)
		DGossipFrame_CloseUI();
    end
end

function DGossipFrame_OnKeyDown()
    -- 【新增】直接从 ImmersiveUIDB 读取最新的按键设置，并提供默认值
    local KEY_YES = (ImmersiveUIDB and ImmersiveUIDB.KEY_YES) or "E"
    local KEY_NO = (ImmersiveUIDB and ImmersiveUIDB.KEY_NO) or "R"

    local key = arg1;
    -- 【修改】使用 KEY_NO 变量替代 "B"，并保留 ESCAPE
	if (key == KEY_NO or key == "ESCAPE") then
        DGossipFrame_CloseUI()
        return
    end

    -- 【修改】使用 KEY_YES 变量替代 "X"，并保留 SPACE
    if (key == KEY_YES or key == "SPACE") then
        AdvanceGossip();
        return
    end

    if key >= "1" and key <= "9" then
        local buttonIndex = tonumber(key)
        DGossipSelectOption(buttonIndex)
        return
    end

    DGossipKeyFrame:EnableKeyboard(false)
    local reEnableTime = GetTime() + 0.05
    DGossipKeyFrame:SetScript("OnUpdate", function()
        if GetTime() >= reEnableTime then
            if DGossipFrame:IsVisible() then
                DGossipKeyFrame:EnableKeyboard(true)
            end
            DGossipKeyFrame:SetScript("OnUpdate", nil)
        end
    end)
end

function DGossipSelectOption(buttonIndex)
    if not DGossipFrame:IsVisible() then return end
    for i = 1, NUMGOSSIPBUTTONS do
        local titleButton = getglobal("DGossipTitleButton" .. i)
        if titleButton and titleButton:IsVisible() and titleButton:GetText() and titleButton:GetText() ~= "" then
            local _, _, numStr = string.find(titleButton:GetText(), "^(%d+)%.")
            if numStr then
                local displayNum = tonumber(numStr)
                if displayNum == buttonIndex then
                    DGossipTitleButton_OnClick_Direct(titleButton)
                    return
                end
            end
        end
    end
end

function DGossipTitleButton_OnClick()
    local b = this
    if not b then return end
    DGossipTitleButton_OnClick_Direct(b)
end

function DGossipTitleButton_OnClick_Direct(button)
    if not button then return end
    if button.type == "Available" then
        SelectGossipAvailableQuest(button:GetID())
        return
    elseif button.type == "Active" then
        SelectGossipActiveQuest(button:GetID())
        return
    elseif button.type == "Option" then
        SelectGossipOption(button:GetID())
        local closeTypes = {
            trainer = true, taxi = true, banker = true, vendor = true,
            binder = true, unlearn = true, tabard = true, flight = true,
            stablemaster = true, professionTrainer = true, classTrainer = true,
            pettrainer = true, guildMaster = true, auctionHouse = true,
            mailbox = true, deeprunTram = true
        }
        local ot = button.optionType
        if ot and closeTypes[ot] then
            RestoreGossipHiddenFrames()
            HideBlackBars()
        end
        return
    else
        SelectGossipOption(button:GetID())
        RestoreGossipHiddenFrames()
        HideBlackBars()
        return
    end
end

function DGossipFrame_CloseUI()
    ResetGossipPaginationState();
    CloseGossip();
	RestoreGossipHiddenFrames();
	HideBlackBars();
end

function DGossipFrameUpdate()
    ClearAllGossipIcons();
    DGossipFrame.buttonIndex = 1;
    totalGossipButtons = 0;
    DGossipGreetingText:SetText("");
    DGossipFrameAvailableQuestsUpdate(GetGossipAvailableQuests());
    DGossipFrameActiveQuestsUpdate(GetGossipActiveQuests());
    DGossipFrameOptionsUpdate(GetGossipOptions());
    for i = DGossipFrame.buttonIndex, NUMGOSSIPBUTTONS do
        getglobal("DGossipTitleButton" .. i):Hide();
    end
    DGossipFrameNpcNameText:SetText(UnitName("npc"));
    if (UnitExists("npc")) then
        SetPortraitTexture(DGossipFramePortrait, "npc");
    else
        DGossipFramePortrait:SetTexture("Interface\\QuestFrame\\UI-QuestLog-BookIcon");
    end
    if DGossipSpacerFrame then DGossipSpacerFrame:Hide() end;
    DGossipGreetingScrollFrame:SetVerticalScroll(0);
    DGossipGreetingScrollFrame:UpdateScrollChildRect();
    local actualCount = 0
    for i = 1, NUMGOSSIPBUTTONS do
        local titleButton = getglobal("DGossipTitleButton" .. i)
        if titleButton and titleButton:IsVisible() and titleButton:GetText() and titleButton:GetText() ~= "" then
            local _, _, numStr = string.find(titleButton:GetText(), "^(%d+)%.")
            if numStr then
                actualCount = actualCount + 1
            end
        end
    end
    totalGossipButtons = actualCount
end

function DGossipFrameAvailableQuestsUpdate(...)
    local titleButton
    local titleIndex = 1
    for i = 1, arg.n, 2 do
        if (DGossipFrame.buttonIndex > NUMGOSSIPBUTTONS) then break end
        titleButton = getglobal("DGossipTitleButton" .. DGossipFrame.buttonIndex)
        local numberedText = DGossipFrame.buttonIndex .. ". " .. arg[i]
        titleButton:SetText(numberedText)
        totalGossipButtons = totalGossipButtons + 1
        titleButton:SetID(titleIndex)
        titleButton.type = "Available"
        local gossipIcon = getglobal(titleButton:GetName() .. "GossipIcon")
        if gossipIcon then gossipIcon:Hide() end
        if not gossipIcon then
            gossipIcon = titleButton:CreateTexture(titleButton:GetName() .. "GossipIcon", "OVERLAY")
            gossipIcon:SetPoint("TOPLEFT", titleButton, "TOPLEFT", 3, -5)
        end
        gossipIcon:SetTexture("Interface\\AddOns\\ImmersiveDialogUI\\src\\assets\\art\\icons\\availableQuestIcon")
        gossipIcon:Show()
        titleButton:SetNormalTexture("Interface\\AddOns\\ImmersiveDialogUI\\src\\assets\\art\\parchment\\OptionBackground-common")
        SetFontColor(titleButton, "Ivory")
        titleButton:SetHeight(titleButton:GetTextHeight() + 20)
        gossipIcon:SetWidth(20)
        gossipIcon:SetHeight(20)
        DGossipFrame.buttonIndex = DGossipFrame.buttonIndex + 1
        titleIndex = titleIndex + 1
        titleButton:Show()
    end
end

function DGossipFrameActiveQuestsUpdate(...)
    local titleButton;
    local titleIndex = 1;
    for i = 1, arg.n, 2 do
        if (DGossipFrame.buttonIndex > NUMGOSSIPBUTTONS) then break end
        titleButton = getglobal("DGossipTitleButton" .. DGossipFrame.buttonIndex);
        local numberedText = DGossipFrame.buttonIndex .. ". " .. arg[i]
        titleButton:SetText(numberedText);
        totalGossipButtons = totalGossipButtons + 1
        titleButton:SetID(titleIndex);
        titleButton.type = "Active";
        local gossipIconName = titleButton:GetName() .. "GossipIcon"
        local gossipIcon = getglobal(gossipIconName)
        if gossipIcon then gossipIcon:Hide() end
        if not gossipIcon then
            gossipIcon = titleButton:CreateTexture(gossipIconName, "OVERLAY")
            gossipIcon:SetPoint("TOPLEFT", titleButton, "TOPLEFT", 3, -5)
        end
        gossipIcon:SetTexture("Interface\\AddOns\\ImmersiveDialogUI\\src\\assets\\art\\icons\\activeQuestIcon");
        gossipIcon:Show()
        DGossipFrame.buttonIndex = DGossipFrame.buttonIndex + 1;
        titleIndex = titleIndex + 1;
        titleButton:Show();
        titleButton:SetNormalTexture("Interface\\AddOns\\ImmersiveDialogUI\\src\\assets\\art\\parchment\\OptionBackground-common")
        titleButton:SetHeight(titleButton:GetTextHeight() + 20)
        gossipIcon:SetHeight(20)
        gossipIcon:SetWidth(20)
        SetFontColor(titleButton, "Ivory")
    end
end

function DGossipFrameOptionsUpdate(...)
    local titleButton;
    local titleIndex = 1;
    for i = 1, arg.n, 2 do
        if (DGossipFrame.buttonIndex > NUMGOSSIPBUTTONS) then break end
        titleButton = getglobal("DGossipTitleButton" .. DGossipFrame.buttonIndex);
        local numberedText = DGossipFrame.buttonIndex .. ". " .. arg[i]
        titleButton:SetText(numberedText);
        totalGossipButtons = totalGossipButtons + 1
        titleButton:SetID(titleIndex);
        titleButton.type = "Option";
        local gossipIconName = titleButton:GetName() .. "GossipIcon"
        local gossipIcon = getglobal(gossipIconName)
        if gossipIcon then gossipIcon:Hide() end
        if not gossipIcon then
            gossipIcon = titleButton:CreateTexture(gossipIconName, "OVERLAY")
            gossipIcon:SetPoint("TOPLEFT", titleButton, "TOPLEFT", 5, -6)
        end
        if titleButton.type == "Option" then
            titleButton:SetNormalTexture(nil)
            titleButton:SetHeight(titleButton:GetTextHeight() + 20)
            SetFontColor(titleButton, "DarkBrown")
        end
        local iconType = arg[i + 1]
        local texturePath
        local iconMap = {
            ["banker"]="bankerGossipIcon",
            ["battlemaster"]="battlemasterGossipIcon",
            ["binder"]="binderGossipIcon",
            ["gossip"]=nil,
            ["healer"]=nil,
            ["tabard"]="guild masterGossipIcon",
            ["taxi"]="flightGossipIcon",
            ["trainer"]="trainerGossipIcon",
            ["unlearn"]="unlearnGossipIcon",
            ["vendor"]="vendorGossipIcon",
        }
        if iconType == "gossip" then
            local specificType = DetermineGossipIconType(arg[i])
            texturePath = "Interface\\AddOns\\ImmersiveDialogUI\\src\\assets\\art\\icons\\" .. (specificType or "gossip") .. "GossipIcon"
        elseif iconMap[iconType] then
            texturePath = "Interface\\AddOns\\ImmersiveDialogUI\\src\\assets\\art\\icons\\" .. iconMap[iconType]
        else
            texturePath = "Interface\\AddOns\\ImmersiveDialogUI\\src\\assets\\art\\icons\\petitionGossipIcon"
        end
        if texturePath then
            gossipIcon:SetTexture(texturePath);
            gossipIcon:Show()
            if not gossipIcon:GetTexture() then
                gossipIcon:SetTexture("Interface\\AddOns\\ImmersiveDialogUI\\src\\assets\\art\\icons\\petitionGossipIcon");
            end
        else
            gossipIcon:Hide()
        end
        gossipIcon:SetWidth(20)
        gossipIcon:SetHeight(20)
        DGossipFrame.buttonIndex = DGossipFrame.buttonIndex + 1;
        titleIndex = titleIndex + 1;
        titleButton:Show();
    end
end

function DetermineGossipIconType(gossipText)
    local text = string.lower(gossipText)
    local professions = {"alchemy","blacksmithing","enchanting","engineering","herbalism","leatherworking","mining","skinning","tailoring","jewelcrafting","inscription","cooking","fishing","first aid"}
    for _, profession in pairs(professions) do
        if string.find(text, profession) then return profession end
    end
    local classes = {"warrior","paladin","hunter","rogue","priest","shaman","mage","warlock","druid","death knight"}
    for _, class in pairs(classes) do
        if string.find(text, class) then return class end
    end
    if string.find(text, "profession") and string.find(text, "trainer") then return "professionTrainer"
    elseif string.find(text, "class") and string.find(text, "trainer") then return "classTrainer"
    elseif string.find(text, "stable") then return "stablemaster"
    elseif string.find(text, "inn") then return "innkeeper"
    elseif string.find(text, "mailbox") then return "mailbox"
    elseif string.find(text, "guild master") then return "guildMaster"
    elseif string.find(text, "trainer") and string.find(text, "pet") then return "pettrainer"
    elseif string.find(text, "auction") then return "auctionHouse"
    elseif string.find(text, "weapon") and string.find(text, "trainer") then return "weaponsTrainer"
    elseif string.find(text, "deeprun") then return "deeprunTram"
    elseif string.find(text, "bat handler") or string.find(text, "wind rider master") or string.find(text, "gryphon master") or string.find(text, "hippogryph master") or string.find(text, "flight master") then return "flight"
    elseif string.find(text, "bank") then return "banker"
    else return "gossip" end
end

function ClearAllGossipIcons()
    -- 【修正】修正了变量拼写错误
    for i = 1, NUMGOSSIPBUTTONS do
        local titleButton = getglobal("DGossipTitleButton" .. i)
        if titleButton then
            local gossipIcon = getglobal(titleButton:GetName() .. "GossipIcon")
            if gossipIcon then
                gossipIcon:Hide()
            end
        end
    end
end