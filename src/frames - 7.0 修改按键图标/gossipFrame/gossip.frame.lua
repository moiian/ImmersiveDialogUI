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
        FontSize = 19,
		WordMinLimit = 3,
		IfCameraMode = 1,
		IfButtonShow = 1,
		IfXBOXButton = 0,
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
        AncillarySpacing = (db.AncillarySpacing or -20) + 10,
		WordMinLimit = db.xOffsetOffset or GOSSIP_DEFAULTS.xOffsetOffset,
		IfCameraMode = db.IfCameraMode or GOSSIP_DEFAULTS.IfCameraMode,
		IfButtonShow = db.IfButtonShow or GOSSIP_DEFAULTS.IfButtonShow,
		IfXBOXButton = db.IfXBOXButton or GOSSIP_DEFAULTS.IfXBOXButton,
		
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
--	添加相机模式
local function IDUICamIn()	
	if GOSSIP_DEFAULTS.IfCameraMode==1 then
		--SaveView(5)
		SetView(2)
		--CameraZoomIn(0.5)
	end
end

local function IDUICamOut()
	if GOSSIP_DEFAULTS.IfCameraMode==1 then
		SetView(5)
	end
end

--===根据开关改变按键图标===--
local function IDUISetTexture(button, path)
	local ButtonIcon = getglobal(button)
	if ButtonIcon then
		ButtonIcon:SetTexture(path)
	end
end

local function SetButtonTexture()
	if LayoutConfig.IfButtonShow == 0 then
		IDUISetTexture("DGossipFrameGreetingGoodbyeButtonIcon", "Interface\\AddOns\\ImmersiveDialogUI\\src\\assets\\art\\keys\\empty\\esc.tga")
	elseif LayoutConfig.IfXBOXButton == 1 then
		IDUISetTexture("DGossipFrameGreetingGoodbyeButtonIcon", "Interface\\AddOns\\ImmersiveDialogUI\\src\\assets\\art\\keys\\xbox\\esc.tga")
	elseif LayoutConfig.IfXBOXButton == 0 then
		IDUISetTexture("DGossipFrameGreetingGoodbyeButtonIcon", "Interface\\AddOns\\ImmersiveDialogUI\\src\\assets\\art\\keys\\keyboard\\esc.tga")
	end
end
-- =================================================================
-- ========= 核心工具及文本显示函数 ===================================
-- =================================================================

-- UTF-8 安全的字符字节数计算
-- 优化后的文本分段函数（新增：若结束符后紧接省略符（… 或 多个 .），则不分句）
function SplitQuestTextToChunks(text, word_limit_en, char_limit_zh)
    local mode = Text_Language and "zh" or "en"

    local chunks = {}
    if type(text) ~= "string" or text == "" then return chunks end
    word_limit_en = word_limit_en or 25
    char_limit_zh = char_limit_zh or 45

    -- 预处理
    text = string.gsub(text, "[\r\n]", " ")
    text = string.gsub(text, "^%s+", "")
    text = string.gsub(text, "%s+$", "")
    text = string.gsub(text, "%s+", " ")

    -- UTF-8 字节长度判断（Lua5.0 可用）
    local function utf8_len_at(s, pos)
        local b = string.byte(s, pos)
        if not b then return 1 end
        if b > 240 then return 4 end
        if b > 224 then return 3 end
        if b > 192 then return 2 end
        return 1
    end

    -- 结束符集合
    local ender_lookup = {}
    local function add_to_lookup(t, key) t[key] = true end
    add_to_lookup(ender_lookup, ".")
    add_to_lookup(ender_lookup, "。")
    add_to_lookup(ender_lookup, "!")
    add_to_lookup(ender_lookup, "！")
    add_to_lookup(ender_lookup, "?")
    add_to_lookup(ender_lookup, "？")
    add_to_lookup(ender_lookup, ";")
    add_to_lookup(ender_lookup, "；")
    add_to_lookup(ender_lookup, "…")
    add_to_lookup(ender_lookup, "—")

    local function is_ender_char(ch)
        return ender_lookup[ch] and true or false
    end

    -- 变量
    local buffer = ""
    local space_count = 0
    local char_count = 0
    local i = 1
    local len = string.len(text)

    while i <= len do
        local charLen = utf8_len_at(text, i)
        local ch = string.sub(text, i, i + charLen - 1)

        -- 先把当前字符加入 buffer（后续可能再追加连续的标点串）
        buffer = buffer .. ch

        local should_split = false
        local is_ender = false

        -- 若当前为可能的结束符（包含单点 '.' 的情况），向后扫描连续的标点串
        if is_ender_char(ch) or ch == "." then
            local j = i + charLen
            while j <= len do
                local nlen = utf8_len_at(text, j)
                local nch = string.sub(text, j, j + nlen - 1)
                if is_ender_char(nch) or nch == "." then
                    j = j + nlen
                else
                    break
                end
            end

            -- 标点串（从 i 到 j-1）
            local seq = ""
            if j - 1 >= i then seq = string.sub(text, i, j - 1) end

            -- 若标点串中包含省略符 '…'，或包含连续两个点 ("..")，则视为省略续写 —— 不分句
            if (string.find(seq, "…", 1, true) ~= nil) or (string.find(seq, "..", 1, true) ~= nil) then
                -- 我们已经把第一个字符加入 buffer，需把 seq 中除首个字符外的部分也追加
                if j > i + charLen then
                    buffer = buffer .. string.sub(text, i + charLen, j - 1)
                end
                -- 跳过整段标点串，不认为这里是句末，继续处理下一个位置
                i = j
                -- 不改变计数（标点不计入字/词计数）
            else
                -- 标点串不包含省略续写，视作正常候选句末
                if j > i + charLen then
                    buffer = buffer .. string.sub(text, i + charLen, j - 1)
                end

                -- 特殊处理：如果 seq 仅为单个 '.'，按照缩写规则（只有后面是空格或结尾才算句末）
                if seq == "." then
                    local next_pos = j
                    local next_ch = ""
                    if next_pos <= len then
                        local nl2 = utf8_len_at(text, next_pos)
                        next_ch = string.sub(text, next_pos, next_pos + nl2 - 1)
                    end
                    if next_ch == " " or next_ch == "" then
                        is_ender = true
                    else
                        is_ender = false
                    end
                else
                    -- 其它（多符号连写或非点号标点等）视为句末候选
                    is_ender = true
                end

                -- 将读取位置移动到标点串之后
                i = j
            end
        else
            -- 非标点字符：更新计数并继续
            if mode == "en" then
                if ch == " " then
                    space_count = space_count + 1
                    if space_count >= word_limit_en then should_split = true end
                end
            else
                -- 中文模式：不把标点计入字数，空格也忽略
                if not is_ender_char(ch) and ch ~= " " then
                    char_count = char_count + 1
                    if char_count >= char_limit_zh then should_split = true end
                end
            end
            -- 移动到下一个字符
            i = i + charLen
        end

        -- 如果前面判定为句末候选，再根据句内长度阈值决定是否真正分句
        if is_ender and not should_split then
            if mode == "en" then
                if space_count >= WordMinLimit then should_split = true end
            else
                if char_count >= WordMinLimit then should_split = true end
            end
        end

        -- 如果还没决定分段，再检查（对于英文：在遇到空格时已经计数；对于中文已经计数）
        -- （这里保持之前逻辑：若达到长度上限则强制分段）
        if not should_split then
            if mode == "en" then
                -- 在英文模式只在空格处统计并触发（上面已有处理），这里不需额外动作
            else
                -- 中文模式：如果当前 i 指向的是下一个字符且它不是标点/空格，我们已经在上面计数过
            end
        end

        -- 执行分段：插入 chunk 并重置计数、buffer
        if should_split then
            -- 跳过段首空格
            if i <= len and string.sub(text, i, i) == " " then
                i = i + 1
            end
            table.insert(chunks, buffer)
            buffer = ""
            space_count = 0
            char_count = 0
        end
        -- loop 继续
    end

    -- 添加尾部残余
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
		string.find(name, "pfChat") or
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
		IDUICamIn();

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
		IDUICamOut();
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