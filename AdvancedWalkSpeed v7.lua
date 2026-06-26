-- ============================================================
--  Advanced Walk Speed  |  Standalone Script for Roblox
--  Matches original UNScripts UI style exactly
-- ============================================================

local Players          = game:GetService("Players")
local TweenService     = game:GetService("TweenService")
local UserInputService = game:GetService("UserInputService")
local RunService       = game:GetService("RunService")
local GuiService       = game:GetService("GuiService")
local HttpService      = game:GetService("HttpService")

local LocalPlayer = Players.LocalPlayer
local Camera      = workspace.CurrentCamera

local uiParent
do
    local ok = pcall(function() return game:GetService("CoreGui"):IsA("DataModel") end)
    uiParent = ok and game:GetService("CoreGui") or LocalPlayer:WaitForChild("PlayerGui")
end

-- ============================================================
--  CONSTANTS & COLORS
-- ============================================================

local rgb  = Color3.fromRGB
local ud2  = UDim2.new
local ud   = UDim.new
local bold = Enum.Font.GothamBold
local reg  = Enum.Font.Gotham
local semi = Enum.Font.GothamSemibold

local C = {
    bg         = rgb(25, 25, 25),
    surface    = rgb(35, 35, 35),
    part_bg    = rgb(45, 45, 45),
    surfaceAlt = rgb(40, 40, 40),
    border     = rgb(45, 45, 52),
    accent     = rgb(50, 120, 255),
    textPri    = rgb(218, 218, 222),
    textSec    = rgb(115, 115, 128),
    dot_red    = rgb(220, 80,  70),
    dot_yel    = rgb(255, 215, 0),
    dot_grn    = rgb(60,  180, 90),
    toggle_off = rgb(55,  55,  62),
    toggle_on  = rgb(50, 120, 255),
    knob       = rgb(245, 245, 248),
    white      = rgb(255, 255, 255),
}

-- ============================================================
--  CONFIG PERSISTENCE
-- ============================================================

local CFG_FOLDER = "AdvancedWalkSpeed"
local CFG_FILE   = "settings"
local CFG_EXT    = ".cfg"

local function cfgSafely(fn, ...)
    if fn then
        local ok, res = pcall(fn, ...)
        if not ok then return nil end
        return res
    end
end

local function ensureCfgFolder()
    if isfolder and not cfgSafely(isfolder, CFG_FOLDER) then
        cfgSafely(makefolder, CFG_FOLDER)
    end
end

local function saveConfig(data)
    ensureCfgFolder()
    local ok, encoded = pcall(function() return HttpService:JSONEncode(data) end)
    if ok then cfgSafely(writefile, CFG_FOLDER .. "/" .. CFG_FILE .. CFG_EXT, encoded) end
end

local function loadConfig()
    local path = CFG_FOLDER .. "/" .. CFG_FILE .. CFG_EXT
    if not cfgSafely(isfile, path) then return nil end
    local content = cfgSafely(readfile, path)
    if not content then return nil end
    local ok, data = pcall(function() return HttpService:JSONDecode(content) end)
    return ok and data or nil
end

local savedCfg = loadConfig() or {}

-- ============================================================
--  SETTINGS VARIABLES
-- ============================================================

local cfgEnabled          = savedCfg.enabled ~= nil and savedCfg.enabled or true
local cfgSpeedIncrement   = savedCfg.speedIncrement or 1
local cfgMaxSpeedLimit    = savedCfg.maxSpeedLimit or 500
local cfgExtremeSpeed     = savedCfg.extremeSpeed or false
local cfgInstantStop      = savedCfg.instantStop or false
local cfgCFrameBypass     = savedCfg.cframeBypass or false
local cfgDefaultSpeed     = 16
local gameDefaultSpeed    = 16
local cfgSpeedUpKey       = savedCfg.speedUpKey or "Equals"
local cfgSpeedDownKey     = savedCfg.speedDownKey or "Minus"
local cfgPanicKey1        = savedCfg.panicKey1 or "LeftControl"
local cfgPanicKey2        = savedCfg.panicKey2 or "Backspace"
local cfgIsExpanded       = savedCfg.isExpanded or false
local cfgTransparency     = savedCfg.transparency or 0.25
local cfgLightMode        = savedCfg.lightMode or false
local cfgKeybind1Name     = savedCfg.keybind1 or "LeftControl"
local cfgKeybind2Name     = savedCfg.keybind2 or "Z"
local cfgFavorites        = savedCfg.favorites or {}

-- ============================================================
--  UTILITY FUNCTIONS (must be defined before use)
-- ============================================================

local function keycodeFromName(name)
    local ok, kc = pcall(function() return Enum.KeyCode[name] end)
    return (ok and kc) or Enum.KeyCode.Unknown
end

-- ============================================================
--  RUNTIME STATE
-- ============================================================

local currentSpeed       = cfgDefaultSpeed
local preToggleSpeed     = cfgDefaultSpeed
local isHoldingSpeedUp   = false
local isHoldingSpeedDown = false
local lastSpeedUpTime    = 0
local lastSpeedDownTime  = 0
local HOLD_REPEAT_RATE   = 0.12
local uiTransparency     = cfgTransparency
local isExpanded         = cfgIsExpanded

local activeKeybind = {
    keycodeFromName(cfgKeybind1Name),
    keycodeFromName(cfgKeybind2Name),
}

local panicKeybind = {
    keycodeFromName(cfgPanicKey1),
    keycodeFromName(cfgPanicKey2),
}

local function getSpeedLimit()
    return cfgExtremeSpeed and 99999 or cfgMaxSpeedLimit
end

local function applySpeedToCharacter(speed)
    currentSpeed = math.clamp(speed, 0, getSpeedLimit())
    if not cfgCFrameBypass then
        pcall(function()
            local char = LocalPlayer.Character
            if char then
                local hum = char:FindFirstChildOfClass("Humanoid")
                if hum then hum.WalkSpeed = currentSpeed end
            end
        end)
    end
end

local function resetSpeed()
    applySpeedToCharacter(gameDefaultSpeed)
end

    local function triggerAutoSave()
        saveConfig({
            enabled       = cfgEnabled,
            speedIncrement= cfgSpeedIncrement,
            maxSpeedLimit = cfgMaxSpeedLimit,
            extremeSpeed  = cfgExtremeSpeed,
            instantStop   = cfgInstantStop,
            cframeBypass  = cfgCFrameBypass,
            defaultSpeed  = cfgDefaultSpeed,
            speedUpKey    = cfgSpeedUpKey,
            speedDownKey  = cfgSpeedDownKey,
            panicKey1     = panicKeybind[1].Name,
            panicKey2     = panicKeybind[2].Name,
            isExpanded    = isExpanded,
            transparency  = uiTransparency,
            lightMode     = cfgLightMode,
            keybind1      = activeKeybind[1].Name,
            keybind2      = activeKeybind[2].Name,
            favorites     = cfgFavorites,
        })
    end

-- ============================================================
--  THEME SYSTEM
-- ============================================================

local themeRegistry = {}

local function applyTheme()
    if cfgLightMode then
        C.bg=rgb(240,240,240); C.surface=rgb(225,225,225); C.part_bg=rgb(215,215,215)
        C.surfaceAlt=rgb(200,200,200); C.border=rgb(180,180,180); C.textPri=rgb(30,30,30)
        C.textSec=rgb(90,90,90); C.toggle_off=rgb(170,170,170); C.knob=rgb(255,255,255)
        C.white=rgb(20,20,20)
    else
        C.bg=rgb(25,25,25); C.surface=rgb(35,35,35); C.part_bg=rgb(45,45,45)
        C.surfaceAlt=rgb(40,40,40); C.border=rgb(45,45,52); C.textPri=rgb(218,218,222)
        C.textSec=rgb(115,115,128); C.toggle_off=rgb(55,55,62); C.knob=rgb(245,245,248)
        C.white=rgb(255,255,255)
    end
    for _, r in ipairs(themeRegistry) do
        if r.obj and r.obj.Parent then
            for prop, cKey in pairs(r.tags) do
                if C[cKey] then r.obj[prop] = C[cKey] end
            end
        end
    end
end

-- ============================================================
--  UI BUILDER HELPERS
-- ============================================================

local function Make(className, props)
    local inst = Instance.new(className)
    local tags = {}
    for k, v in pairs(props) do
        inst[k] = v
        if typeof(v) == "Color3" then
            for cKey, cVal in pairs(C) do
                if v == cVal then tags[k] = cKey; break end
            end
        end
    end
    if next(tags) then table.insert(themeRegistry, {obj = inst, tags = tags}) end
    return inst
end

local transparencyFrames = {}
local function applyTransparency(t)
    uiTransparency = math.clamp(t, 0, 0.85)
    for _, e in ipairs(transparencyFrames) do
        if e.frame and e.frame.Parent then
            e.frame.BackgroundTransparency = math.clamp(e.base + uiTransparency * (1 - e.base), 0, 0.90)
        end
    end
end

local toggleTween = TweenInfo.new(0.2, Enum.EasingStyle.Quart, Enum.EasingDirection.Out)

local function makeToggle(parent, yPos, callback, initOn)
    local track = Instance.new("Frame")
    track.Size = ud2(0,36,0,18)
    track.Position = ud2(1,-46,0,yPos)
    track.BackgroundColor3 = initOn and C.toggle_on or C.toggle_off
    track.BorderSizePixel = 0
    track.Parent = parent
    Make("UICorner", {CornerRadius = ud(1,0), Parent = track})
    local knob = Make("Frame", {
        Size = ud2(0,14,0,14),
        Position = initOn and ud2(0,20,0,2) or ud2(0,2,0,2),
        BackgroundColor3 = C.knob, BorderSizePixel = 0, Parent = track,
    })
    Make("UICorner", {CornerRadius = ud(1,0), Parent = knob})
    Make("UIStroke", {Color = rgb(0,0,0), Thickness = 1, Transparency = 0.7, Parent = knob})
    local isOn = initOn == true
    local hitbox = Make("TextButton", {
        Size = ud2(1,0,1,0), BackgroundTransparency = 1, Text = "",
        ZIndex = knob.ZIndex + 1, Parent = track,
    })
    local function setOn(state, silent)
        isOn = state
        knob.Position = isOn and ud2(0,20,0,2) or ud2(0,2,0,2)
        track.BackgroundColor3 = isOn and C.toggle_on or C.toggle_off
        TweenService:Create(knob, toggleTween, {Position = isOn and ud2(0,20,0,2) or ud2(0,2,0,2)}):Play()
        TweenService:Create(track, toggleTween, {BackgroundColor3 = isOn and C.toggle_on or C.toggle_off}):Play()
        if callback and not silent then callback(isOn) end
    end
    hitbox.MouseButton1Click:Connect(function() setOn(not isOn, false) end)
    return {Track = track, Knob = knob, IsOn = function() return isOn end, SetOn = setOn}
end

local PART_H    = 32
local SECTION_H = 38

local function makeSlider(parent, label, minV, maxV, defaultV, callback, layoutOrder)
    local val = defaultV or minV
    local pill = Make("Frame", {
        Size = ud2(1,-8,0,48), BackgroundColor3 = C.part_bg,
        BackgroundTransparency = 0.3, BorderSizePixel = 0,
        LayoutOrder = layoutOrder or 0, Parent = parent,
    })
    pill:SetAttribute("SearchName", label)
    Make("UICorner", {CornerRadius = ud(1,0), Parent = pill})
    Make("TextLabel", {
        Size = ud2(0,110,0,20), Position = ud2(0,14,0,6),
        BackgroundTransparency = 1, Text = label,
        TextColor3 = C.textPri, TextSize = 11, Font = reg,
        TextXAlignment = Enum.TextXAlignment.Left, Parent = pill,
    })
    local valInput = Make("TextBox", {
        Size = ud2(0,42,0,20), Position = ud2(1,-56,0,6),
        BackgroundTransparency = 1, Text = tostring(val),
        TextColor3 = C.textSec, TextSize = 10, Font = bold,
        TextXAlignment = Enum.TextXAlignment.Right, Parent = pill,
        ClearTextOnFocus = false,
    })
    local track = Make("Frame", {
        Size = ud2(1,-28,0,6), Position = ud2(0,14,0,32),
        BackgroundColor3 = C.toggle_off, BackgroundTransparency = 0.2,
        BorderSizePixel = 0, Parent = pill,
    })
    Make("UICorner", {CornerRadius = ud(1,0), Parent = track})
    local frac = (val - minV) / (maxV - minV)
    local fill = Make("Frame", {
        Size = ud2(frac,0,1,0), BackgroundColor3 = C.accent,
        BackgroundTransparency = 0, BorderSizePixel = 0, Parent = track,
    })
    Make("UICorner", {CornerRadius = ud(1,0), Parent = fill})
    local knob = Make("TextButton", {
        Size = ud2(0,14,0,14), Position = ud2(frac,-7,0,-4),
        BackgroundColor3 = C.knob, BorderSizePixel = 0, Text = "", Parent = track,
    })
    Make("UICorner", {CornerRadius = ud(1,0), Parent = knob})
    Make("UIStroke", {Color = rgb(80,80,80), Thickness = 1, Transparency = 0.3, Parent = knob})
    local dragging = false
    local function setVal(v)
        v = math.clamp(math.floor(v + 0.5), minV, maxV)
        val = v; valInput.Text = tostring(v)
        local p = (v - minV) / (maxV - minV)
        TweenService:Create(fill, TweenInfo.new(0.1), {Size = ud2(p,0,1,0)}):Play()
        knob.Position = ud2(p,-7,0,-4)
        if callback then callback(val) end
    end
    valInput.FocusLost:Connect(function()
        local num = tonumber(valInput.Text)
        if num then setVal(num) else valInput.Text = tostring(val) end
    end)
    knob.InputBegan:Connect(function(input)
        if input.UserInputType == Enum.UserInputType.MouseButton1 then dragging = true end
    end)
    local hitbox = Make("TextButton", {
        Size = ud2(1,0,1,20), Position = ud2(0,0,0,-7),
        BackgroundTransparency = 1, Text = "", ZIndex = knob.ZIndex - 1, Parent = track,
    })
    hitbox.InputBegan:Connect(function(input)
        if input.UserInputType == Enum.UserInputType.MouseButton1 then
            dragging = true
            local rel = math.clamp((input.Position.X - track.AbsolutePosition.X) / track.AbsoluteSize.X, 0, 1)
            setVal(minV + (maxV - minV) * rel)
        end
    end)
    local ec = UserInputService.InputEnded:Connect(function(input)
        if input.UserInputType == Enum.UserInputType.MouseButton1 then dragging = false end
    end)
    local rc = UserInputService.InputChanged:Connect(function(input)
        if dragging and input.UserInputType == Enum.UserInputType.MouseMovement then
            local rel = math.clamp((input.Position.X - track.AbsolutePosition.X) / track.AbsoluteSize.X, 0, 1)
            setVal(minV + (maxV - minV) * rel)
        end
    end)
    pill.Destroying:Connect(function() ec:Disconnect(); rc:Disconnect() end)
    return pill, setVal
end

local function makeButton(parent, label, callback, layoutOrder)
    local pill = Make("Frame", {
        Size = ud2(1,-8,0,PART_H), BackgroundColor3 = C.surfaceAlt,
        BackgroundTransparency = 0.1, BorderSizePixel = 0,
        LayoutOrder = layoutOrder or 0, Parent = parent,
    })
    pill:SetAttribute("SearchName", label)
    Make("UICorner", {CornerRadius = ud(1,0), Parent = pill})
    Make("UIStroke", {Color = C.border, Thickness = 1, Transparency = 0.4, Parent = pill})
    Make("TextLabel", {
        Size = ud2(0,120,1,0), Position = ud2(0,14,0,0),
        BackgroundTransparency = 1, Text = label,
        TextColor3 = C.textPri, TextSize = 11, Font = semi,
        TextXAlignment = Enum.TextXAlignment.Left, Parent = pill,
    })
    local btn = Make("TextButton", {
        Size = ud2(0,70,0,22), Position = ud2(1,-80,0.5,-11),
        BackgroundColor3 = C.accent, BackgroundTransparency = 0.1,
        Text = "Apply", TextColor3 = C.white,
        TextSize = 10, Font = bold, Parent = pill,
    })
    Make("UICorner", {CornerRadius = ud(0,4), Parent = btn})
    btn.MouseButton1Click:Connect(function()
        if callback then callback() end
        btn.Text = "Done!"
        task.delay(0.8, function() btn.Text = "Apply" end)
    end)
    return pill
end

local function makeLabel(parent, text, layoutOrder)
    local lbl = Make("TextLabel", {
        Size = ud2(1,-8,0,22), BackgroundTransparency = 1,
        Text = " -- " .. text .. " --", TextColor3 = C.textSec,
        TextSize = 10, Font = bold, LayoutOrder = layoutOrder,
        TextXAlignment = Enum.TextXAlignment.Center, Parent = parent,
    })
    lbl:SetAttribute("SearchName", text)
    return lbl
end

-- Star / Favorite button helper
local starRefs = {}
local function makeStar(parent, uid, xPos, yPos, onToggle)
    local star = Make("TextButton", {
        Size = ud2(0,22,0,22), Position = ud2(1,xPos,0,yPos),
        BackgroundTransparency = 1, Text = "★",
        TextColor3 = cfgFavorites[uid] and C.dot_yel or C.textSec,
        TextSize = 18, Font = bold, Parent = parent,
    })
    star.MouseButton1Click:Connect(function()
        cfgFavorites[uid] = not cfgFavorites[uid]
        star.TextColor3 = cfgFavorites[uid] and C.dot_yel or C.textSec
        if onToggle then onToggle(cfgFavorites[uid]) end
        triggerAutoSave()
    end)
    starRefs[uid] = star
    return star
end

-- ============================================================
--  CREATE SCREEN GUI
-- ============================================================

local existingGui = uiParent:FindFirstChild("AdvancedWalkSpeedGUI")
if existingGui then existingGui:Destroy() end

local Gui = Make("ScreenGui", {
    Name = "AdvancedWalkSpeedGUI",
    ResetOnSpawn = false,
    ZIndexBehavior = Enum.ZIndexBehavior.Sibling,
    Parent = uiParent,
})

-- ============================================================
--  MAIN WINDOW
-- ============================================================

local NORMAL_W, NORMAL_H = 360, 480

local Main = Make("Frame", {
    Size = ud2(0,NORMAL_W,0,NORMAL_H), Position = ud2(0.5,0,0.5,0),
    AnchorPoint = Vector2.new(0.5,0.5), BackgroundColor3 = C.bg,
    BackgroundTransparency = uiTransparency, BorderSizePixel = 0,
    Active = true, ClipsDescendants = true, Parent = Gui,
})
Make("UICorner", {CornerRadius = ud(0,16), Parent = Main})
local MainScale = Make("UIScale", {Scale = isExpanded and 1.4 or 1, Parent = Main})
local BorderFrame = Make("Frame", {Size = ud2(1,0,1,0), BackgroundTransparency = 1, BorderSizePixel = 0, Parent = Main})
Make("UICorner", {CornerRadius = ud(0,16), Parent = BorderFrame})
Make("UIStroke", {Color = C.border, Thickness = 1, Transparency = 0.5, Parent = BorderFrame})

-- ============================================================
--  HEADER BAR
-- ============================================================

local HeaderBar = Make("Frame", {Size = ud2(1,0,0,42), BackgroundTransparency = 1, BorderSizePixel = 0, Parent = Main})

local function makeDot(xPos, color, parent)
    local dot = Make("TextButton", {
        Size = ud2(0,13,0,13), Position = ud2(0,xPos,0,15),
        Text = "", BackgroundColor3 = color, BorderSizePixel = 0, Parent = parent or HeaderBar,
    })
    Make("UICorner", {CornerRadius = ud(1,0), Parent = dot})
    return dot
end
local CloseBtn = makeDot(14, C.dot_red)
local MinBtn   = makeDot(32, C.dot_yel)
local MaxBtn   = makeDot(50, C.dot_grn)

local TitleLabel = Make("TextLabel", {
    Size = ud2(0,200,0,42), Position = ud2(0.5,-100,0,0),
    BackgroundTransparency = 1, Text = "Advanced Walk Speed",
    TextColor3 = C.textPri, TextSize = 13, Font = bold,
    TextXAlignment = Enum.TextXAlignment.Center,
    TextYAlignment = Enum.TextYAlignment.Center, Parent = HeaderBar,
})

local function makeHeaderIcon(xOffset, icon)
    return Make("TextButton", {
        Size = ud2(0,28,0,28), Position = ud2(1,xOffset,0,7),
        BackgroundTransparency = 1, Text = icon,
        TextColor3 = C.textSec, TextSize = 16, Font = bold, Parent = HeaderBar,
    })
end
local ToggleBtn = makeHeaderIcon(-36, "\u{2699}")
local SearchBtn = makeHeaderIcon(-66, "\u{1F50D}")

local SearchBarHolder = Make("Frame", {
    Size = ud2(0,190,0,26), Position = ud2(0.5,-95,0,-34),
    BackgroundColor3 = C.surfaceAlt, BackgroundTransparency = 0.3,
    BorderSizePixel = 0, ClipsDescendants = true, Parent = HeaderBar,
})
Make("UICorner", {CornerRadius = ud(0,7), Parent = SearchBarHolder})
Make("UIStroke", {Color = C.border, Thickness = 1, Transparency = 0.3, Parent = SearchBarHolder})
Make("TextLabel", {Size = ud2(0,24,1,0), BackgroundTransparency = 1, Text = "\u{1F50D}", TextSize = 11, Font = bold, TextColor3 = C.textSec, Parent = SearchBarHolder})
local SearchInput = Make("TextBox", {
    Size = ud2(1,-28,1,0), Position = ud2(0,26,0,0),
    BackgroundTransparency = 1, PlaceholderText = "Search...",
    PlaceholderColor3 = C.textSec, Text = "", TextColor3 = C.textPri,
    TextSize = 12, Font = reg, ClearTextOnFocus = false, Parent = SearchBarHolder,
})

-- ============================================================
--  PILL UI
-- ============================================================

local PillUI = Make("TextButton", {
    Size = ud2(0,110,0,34), Position = ud2(0.5,0,0,12),
    AnchorPoint = Vector2.new(0.5,0), BackgroundColor3 = C.bg,
    BackgroundTransparency = uiTransparency, Text = "Advanced Speed",
    TextColor3 = C.textPri, Font = bold, TextSize = 12,
    Active = true, Visible = false, Parent = Gui,
})
Make("UICorner", {CornerRadius = ud(1,0), Parent = PillUI})
Make("UIStroke", {Color = C.border, Thickness = 1, Transparency = 0.4, Parent = PillUI})
local PillScale = Make("UIScale", {Scale = 1, Parent = PillUI})

-- ============================================================
--  PAGES
-- ============================================================

local MainPage = Make("Frame", {Size = ud2(1,0,1,-42), Position = ud2(0,0,0,42), BackgroundTransparency = 1, ClipsDescendants = true, Parent = Main})
local SetPage  = Make("Frame", {Size = ud2(1,0,1,-42), Position = ud2(0,0,0,42), BackgroundTransparency = 1, ClipsDescendants = true, Visible = false, Parent = Main})

-- ============================================================
--  TAB BAR
-- ============================================================

local activeTab = "Home"
local tabs = {}
local tabSections = {Home = {}, Speed = {}}
local tabTween = TweenInfo.new(0.22, Enum.EasingStyle.Quart, Enum.EasingDirection.Out)
local sectionTween = TweenInfo.new(0.28, Enum.EasingStyle.Quart, Enum.EasingDirection.Out)

local TabBar = Make("Frame", {Size = ud2(1,-24,0,30), Position = ud2(0,12,0,8), BackgroundTransparency = 1, Parent = MainPage})
Make("UIListLayout", {FillDirection = Enum.FillDirection.Horizontal, HorizontalAlignment = Enum.HorizontalAlignment.Center, Padding = ud(0,6), Parent = TabBar})

local function makeTab(name)
    local btn = Make("TextButton", {
        Size = ud2(0,64,0,26), BackgroundColor3 = C.surfaceAlt,
        BackgroundTransparency = 0.5, Text = name,
        TextColor3 = C.textSec, TextSize = 12, Font = bold, Parent = TabBar,
    })
    Make("UICorner", {CornerRadius = ud(1,0), Parent = btn})
    local pill = Make("Frame", {
        Size = ud2(0,0,0,2), Position = ud2(0.5,0,1,-2),
        AnchorPoint = Vector2.new(0.5,0), BackgroundColor3 = C.accent,
        BorderSizePixel = 0, Parent = btn,
    })
    Make("UICorner", {CornerRadius = ud(1,0), Parent = pill})
    return {Button = btn, Pill = pill, Name = name}
end

tabs.Home  = makeTab("Home")
tabs.Speed = makeTab("Speed")

local CollapseAllBtn = Make("TextButton", {
    Size = ud2(0,26,0,26), BackgroundColor3 = C.surfaceAlt,
    BackgroundTransparency = 0.3, Text = "^", TextColor3 = C.textSec,
    TextSize = 14, Font = bold, LayoutOrder = 10, Visible = false, Parent = TabBar,
})
Make("UICorner", {CornerRadius = ud(0,6), Parent = CollapseAllBtn})
Make("UIStroke", {Color = C.border, Thickness = 1, Transparency = 0.4, Parent = CollapseAllBtn})

-- Tab Content
local TabContent = Make("Frame", {Size = ud2(1,-24,1,-44), Position = ud2(0,12,0,44), BackgroundTransparency = 1, ClipsDescendants = true, Parent = MainPage})
local SectionScroll = Make("ScrollingFrame", {
    Size = ud2(1,0,1,0), BackgroundTransparency = 1, BorderSizePixel = 0,
    ScrollBarThickness = 2, ScrollBarImageColor3 = C.border,
    CanvasSize = ud2(0,0,0,0), AutomaticCanvasSize = Enum.AutomaticSize.Y,
    Active = true, Parent = TabContent,
})
Make("UIListLayout", {SortOrder = Enum.SortOrder.LayoutOrder, Padding = ud(0,0), Parent = SectionScroll})

-- ============================================================
--  SECTION BUILDER (with visual distinction for headers)
-- ============================================================

local function updateCollapseAllVisibility()
    local n = 0
    for _, sec in ipairs(tabSections[activeTab] or {}) do
        if sec.IsOpen() then n = n + 1 end
    end
    CollapseAllBtn.Visible = (n > 1)
end

local function makeSection(sectionName, parentContainer, tabKey)
    local wrapper = Make("Frame", {Size = ud2(1,-16,0,SECTION_H), BackgroundTransparency = 1, ClipsDescendants = true, Parent = parentContainer})
    local header = Make("Frame", {Size = ud2(1,0,0,SECTION_H), BackgroundColor3 = C.surface,
        BackgroundTransparency = 0, BorderSizePixel = 0, Parent = wrapper})
    Make("UICorner", {CornerRadius = ud(1,0), Parent = header})
    local arrow = Make("TextLabel", {Size = ud2(0,28,1,0), Position = ud2(0,10,0,0), BackgroundTransparency = 1, Text = "+", TextColor3 = C.textSec, TextSize = 18, Font = bold, Parent = header})
    local titleLbl = Make("TextLabel", {Size = ud2(1,-50,1,0), Position = ud2(0,32,0,0), BackgroundTransparency = 1, Text = sectionName, TextColor3 = C.textPri, TextSize = 12, Font = bold, TextXAlignment = Enum.TextXAlignment.Left, Parent = header})
    local content = Make("Frame", {Size = ud2(1,0,0,0), Position = ud2(0,0,0,SECTION_H+4), BackgroundTransparency = 1, ClipsDescendants = true, Parent = wrapper})
    Make("UIListLayout", {SortOrder = Enum.SortOrder.LayoutOrder, Padding = ud(0,5), Parent = content})

    local isOpen = false
    local obj = {
        Wrapper = wrapper, Content = content, TitleLabel = titleLbl, Header = header,
        IsOpen = function() return isOpen end, Name = sectionName,
        resizeToContent = function()
            local layout = content:FindFirstChildOfClass("UIListLayout")
            local h = layout and layout.AbsoluteContentSize.Y or 0
            if h <= 0 then
                h = 0
                local pad = (layout and layout.Padding.Offset) or 5
                for _, child in ipairs(content:GetChildren()) do
                    if child:IsA("GuiObject") and child.Visible then
                        local sy = child.Size.Y.Offset
                        if sy <= 0 then
                            if child:IsA("Frame") then sy = PART_H
                            elseif child:IsA("TextLabel") then sy = 22
                            else sy = 32 end
                        end
                        h = h + sy + pad
                    end
                end
            end
            content.Size = ud2(1,0,0,h)
        end,
    }

    local function setOpen(state)
        isOpen = state
        arrow.Text = isOpen and "-" or "+"
        if isOpen then obj.resizeToContent() end
        local ch = content.Size.Y.Offset
        local totalH = SECTION_H + 4 + ch
        if isOpen then
            wrapper.Size = ud2(1,-16,0,totalH)
        else
            TweenService:Create(wrapper, sectionTween, {Size = ud2(1,-16,0,SECTION_H)}):Play()
        end
        if isOpen then
            task.delay(0.15, function()
                obj.resizeToContent()
                wrapper.Size = ud2(1,-16,0,SECTION_H+4+content.Size.Y.Offset)
            end)
        end
        updateCollapseAllVisibility()
    end
    obj.SetOpen = setOpen

    local hBtn = Make("TextButton", {Size = ud2(1,0,1,0), BackgroundTransparency = 1, Text = "", Parent = header})
    hBtn.MouseButton1Click:Connect(function() setOpen(not isOpen) end)

    table.insert(tabSections[tabKey], obj)
    return obj
end

-- ============================================================
--  CREATE TOGGLE PART (star outside toggle)
-- ============================================================

local function createTogglePart(parent, pName, uid, layoutOrder, callback, initState)
    local partPill = Make("Frame", {
        Size = ud2(1,-8,0,PART_H), BackgroundColor3 = C.part_bg,
        BackgroundTransparency = 0.3, BorderSizePixel = 0,
        LayoutOrder = layoutOrder, Parent = parent,
    })
    partPill:SetAttribute("SearchName", pName)
    Make("UICorner", {CornerRadius = ud(1,0), Parent = partPill})
    Make("TextLabel", {
        Size = ud2(1,-100,1,0), Position = ud2(0,14,0,0),
        BackgroundTransparency = 1, Text = pName,
        TextColor3 = C.textPri, TextSize = 11, Font = reg,
        TextXAlignment = Enum.TextXAlignment.Left, Parent = partPill,
    })
    local toggle = makeToggle(partPill, (PART_H-18)/2, function(state)
        if callback then callback(state) end
    end, initState or false)
    makeStar(partPill, uid, -74, 5, function()
        if rebuildFavorites then rebuildFavorites() end
    end)
    return partPill, toggle
end

-- ============================================================
--  HOME TAB: Active + Favorites
-- ============================================================

local homeContainer = Make("Frame", {Size = ud2(1,0,0,0), BackgroundTransparency = 1, AutomaticSize = Enum.AutomaticSize.Y, Visible = true, Parent = SectionScroll})
Make("UIListLayout", {SortOrder = Enum.SortOrder.LayoutOrder, Padding = ud(0,0), Parent = homeContainer})

local favSec    = makeSection("Favorites", homeContainer, "Home")

-- ============================================================
--  SPEED TAB: Advanced Walk Speed with sub-sections
-- ============================================================

local speedContainer = Make("Frame", {Size = ud2(1,0,0,0), BackgroundTransparency = 1, AutomaticSize = Enum.AutomaticSize.Y, Visible = false, Parent = SectionScroll})
Make("UIListLayout", {SortOrder = Enum.SortOrder.LayoutOrder, Padding = ud(0,0), Parent = speedContainer})

-- === SECTION: Main Toggle ===
local mainSec = makeSection("Main Toggle", speedContainer, "Speed")
local mc = mainSec.Content

local awsMainPill, awsMainToggle = createTogglePart(mc, "Advanced Walk Speed", "advwalkspeed_main", 1, function(state)
    cfgEnabled = state
    if not state then
        preToggleSpeed = currentSpeed
        pcall(function()
            local char = LocalPlayer.Character
            if char then
                local hum = char:FindFirstChildOfClass("Humanoid")
                if hum then hum.WalkSpeed = gameDefaultSpeed end
            end
        end)
    else
        currentSpeed = preToggleSpeed
        applySpeedToCharacter(currentSpeed)
        refreshSpeedSlider()
    end
    triggerAutoSave()
    rebuildFavorites()
end, cfgEnabled)

-- === SECTION: Speed Control (interactive drag slider) ===
local speedSec = makeSection("Speed Control", speedContainer, "Speed")
local sc = speedSec.Content

-- Current speed display with drag slider
local speedDisplayPill = Make("Frame", {
    Size = ud2(1,-8,0,52), BackgroundColor3 = C.surfaceAlt,
    BackgroundTransparency = 0.1, BorderSizePixel = 0,
    LayoutOrder = 1, Parent = sc,
})
speedDisplayPill:SetAttribute("SearchName", "Current Speed")
Make("UICorner", {CornerRadius = ud(1,0), Parent = speedDisplayPill})
Make("TextLabel", {
    Size = ud2(0,120,0,20), Position = ud2(0,14,0,4),
    BackgroundTransparency = 1, Text = "Current Speed",
    TextColor3 = C.textPri, TextSize = 11, Font = reg,
    TextXAlignment = Enum.TextXAlignment.Left, Parent = speedDisplayPill,
})
local speedValueLabel = Make("TextLabel", {
    Size = ud2(0,70,0,20), Position = ud2(1,-110,0,4),
    BackgroundTransparency = 1, Text = tostring(currentSpeed),
    TextColor3 = C.accent, TextSize = 14, Font = bold,
    TextXAlignment = Enum.TextXAlignment.Right, Parent = speedDisplayPill,
})
Make("TextLabel", {
    Size = ud2(0,30,0,20), Position = ud2(1,-40,0,4),
    BackgroundTransparency = 1, Text = "spd",
    TextColor3 = C.textSec, TextSize = 9, Font = reg,
    TextXAlignment = Enum.TextXAlignment.Left, Parent = speedDisplayPill,
})

local speedTrack = Make("Frame", {
    Size = ud2(1,-28,0,6), Position = ud2(0,14,0,32),
    BackgroundColor3 = C.toggle_off, BackgroundTransparency = 0.2,
    BorderSizePixel = 0, Parent = speedDisplayPill,
})
Make("UICorner", {CornerRadius = ud(1,0), Parent = speedTrack})

local function getSpeedFrac()
    local limit = getSpeedLimit()
    if limit <= 0 then return 0 end
    return math.clamp(currentSpeed / limit, 0, 1)
end

local speedFill = Make("Frame", {
    Size = ud2(getSpeedFrac(),0,1,0), BackgroundColor3 = C.accent,
    BackgroundTransparency = 0, BorderSizePixel = 0, Parent = speedTrack,
})
Make("UICorner", {CornerRadius = ud(1,0), Parent = speedFill})

local speedKnob = Make("TextButton", {
    Size = ud2(0,14,0,14), Position = ud2(math.clamp(getSpeedFrac(), 0, 1), -7, 0, -4),
    BackgroundColor3 = C.knob, BorderSizePixel = 0, Text = "", Parent = speedTrack,
})
Make("UICorner", {CornerRadius = ud(1,0), Parent = speedKnob})
Make("UIStroke", {Color = rgb(80,80,80), Thickness = 1, Transparency = 0.3, Parent = speedKnob})

local speedDragging = false

local function updateSpeedFromDrag(inputX)
    local rel = math.clamp((inputX - speedTrack.AbsolutePosition.X) / speedTrack.AbsoluteSize.X, 0, 1)
    local limit = getSpeedLimit()
    local newSpeed = math.floor(rel * limit + 0.5)
    applySpeedToCharacter(newSpeed)
    speedValueLabel.Text = tostring(currentSpeed)
    local p = getSpeedFrac()
    TweenService:Create(speedFill, TweenInfo.new(0.1), {Size = ud2(p,0,1,0)}):Play()
    speedKnob.Position = ud2(math.clamp(p, 0, 1), -7, 0, -4)
end

local function refreshSpeedSlider()
    local p = getSpeedFrac()
    TweenService:Create(speedFill, TweenInfo.new(0.15), {Size = ud2(p,0,1,0)}):Play()
    speedKnob.Position = ud2(math.clamp(p, 0, 1), -7, 0, -4)
    speedValueLabel.Text = tostring(currentSpeed)
end

speedKnob.InputBegan:Connect(function(input)
    if input.UserInputType == Enum.UserInputType.MouseButton1 then speedDragging = true end
end)

local speedHitbox = Make("TextButton", {
    Size = ud2(1,0,1,20), Position = ud2(0,0,0,-7),
    BackgroundTransparency = 1, Text = "", ZIndex = speedKnob.ZIndex - 1, Parent = speedTrack,
})
speedHitbox.InputBegan:Connect(function(input)
    if input.UserInputType == Enum.UserInputType.MouseButton1 then
        speedDragging = true
        updateSpeedFromDrag(input.Position.X)
    end
end)

UserInputService.InputEnded:Connect(function(input)
    if input.UserInputType == Enum.UserInputType.MouseButton1 and speedDragging then
        speedDragging = false
        triggerAutoSave()
    end
end)
UserInputService.InputChanged:Connect(function(input)
    if speedDragging and input.UserInputType == Enum.UserInputType.MouseMovement then
        updateSpeedFromDrag(input.Position.X)
    end
end)

makeLabel(sc, "Settings", 2)
makeSlider(sc, "Speed Increment", 1, 50, cfgSpeedIncrement, function(v)
    cfgSpeedIncrement = v; triggerAutoSave()
end, 3)
makeSlider(sc, "Speed Cap / Limit", 16, 500, cfgMaxSpeedLimit, function(v)
    cfgMaxSpeedLimit = v
    if not cfgExtremeSpeed and currentSpeed > v then
        applySpeedToCharacter(v)
        refreshSpeedSlider()
    end
    refreshSpeedSlider()
    triggerAutoSave()
end, 4)

-- === SECTION: Features ===
local featSec = makeSection("Features", speedContainer, "Speed")
local fc = featSec.Content

local _, instantStopToggle = createTogglePart(fc, "Instant Stop", "advwalkspeed_instantstop", 1, function(state)
    cfgInstantStop = state; triggerAutoSave()
end, cfgInstantStop)

-- EXTREME SPEED MODE
local extremePill = Make("Frame", {
    Size = ud2(1,-8,0,PART_H), BackgroundColor3 = C.part_bg,
    BackgroundTransparency = 0.3, BorderSizePixel = 0,
    LayoutOrder = 2, Parent = fc,
})
extremePill:SetAttribute("SearchName", "EXTREME SPEED MODE")
Make("UICorner", {CornerRadius = ud(1,0), Parent = extremePill})
Make("TextLabel", {
    Size = ud2(1,-100,1,0), Position = ud2(0,14,0,0),
    BackgroundTransparency = 1, Text = "EXTREME SPEED MODE",
    TextColor3 = C.dot_red, TextSize = 11, Font = bold,
    TextXAlignment = Enum.TextXAlignment.Left, Parent = extremePill,
})
makeToggle(extremePill, (PART_H-18)/2, function(state)
    cfgExtremeSpeed = state
    applySpeedToCharacter(currentSpeed)
    refreshSpeedSlider()
    triggerAutoSave()
end, cfgExtremeSpeed)
makeStar(extremePill, "advwalkspeed_extreme", -74, 5, function()
    if rebuildFavorites then rebuildFavorites() end
end)

-- CFRAME WALKING (ANTI-CHEAT BYPASS)
local cframePill = Make("Frame", {
    Size = ud2(1,-8,0,PART_H), BackgroundColor3 = C.part_bg,
    BackgroundTransparency = 0.3, BorderSizePixel = 0,
    LayoutOrder = 3, Parent = fc,
})
cframePill:SetAttribute("SearchName", "CFrame Walking (Anti-Cheat Bypass)")
Make("UICorner", {CornerRadius = ud(1,0), Parent = cframePill})
Make("TextLabel", {
    Size = ud2(1,-100,1,0), Position = ud2(0,14,0,0),
    BackgroundTransparency = 1, Text = "CFrame Walking (Bypass)",
    TextColor3 = C.dot_yel, TextSize = 11, Font = bold,
    TextXAlignment = Enum.TextXAlignment.Left, Parent = cframePill,
})
makeToggle(cframePill, (PART_H-18)/2, function(state)
    cfgCFrameBypass = state
    if not state then
        pcall(function()
            local char = LocalPlayer.Character
            if char then
                local hum = char:FindFirstChildOfClass("Humanoid")
                if hum then hum.WalkSpeed = currentSpeed end
            end
        end)
    end
    triggerAutoSave()
end, cfgCFrameBypass)
makeStar(cframePill, "advwalkspeed_cframe", -74, 5, function()
    if rebuildFavorites then rebuildFavorites() end
end)

-- === SECTION: Quick Presets ===
local presetSec = makeSection("Quick Presets", speedContainer, "Speed")
local pc = presetSec.Content

local presetConfigs = {
    {name = "Walk",   speed = 16,   order = 1},
    {name = "Sprint", speed = 32,   order = 2},
    {name = "Mach 1", speed = 100,  order = 3},
    {name = "Mach 2", speed = 200,  order = 4},
    {name = "Mach 3", speed = 500,  order = 5},
    {name = "Mach 5", speed = 1000, order = 6},
}

for i, preset in ipairs(presetConfigs) do
    local pName  = preset.name
    local pSpeed = preset.speed

    local pPill = Make("Frame", {
        Size = ud2(1,-8,0,36), BackgroundColor3 = C.part_bg,
        BackgroundTransparency = 0.3, BorderSizePixel = 0,
        LayoutOrder = preset.order, Parent = pc,
    })
    pPill:SetAttribute("SearchName", pName)
    Make("UICorner", {CornerRadius = ud(1,0), Parent = pPill})
    Make("TextLabel", {
        Size = ud2(0,80,1,0), Position = ud2(0,14,0,0),
        BackgroundTransparency = 1, Text = pName,
        TextColor3 = C.textPri, TextSize = 11, Font = reg,
        TextXAlignment = Enum.TextXAlignment.Left, Parent = pPill,
    })
    Make("TextLabel", {
        Size = ud2(0,50,1,0), Position = ud2(0,100,0,0),
        BackgroundTransparency = 1, Text = tostring(pSpeed) .. " spd",
        TextColor3 = C.accent, TextSize = 10, Font = bold,
        TextXAlignment = Enum.TextXAlignment.Left, Parent = pPill,
    })

    local pBtn = Make("TextButton", {
        Size = ud2(0,60,0,22), Position = ud2(1,-80,0.5,-11),
        BackgroundColor3 = C.accent, BackgroundTransparency = 0.1,
        Text = "Apply", TextColor3 = C.white,
        TextSize = 10, Font = bold, Parent = pPill,
    })
    Make("UICorner", {CornerRadius = ud(0,4), Parent = pBtn})
    pBtn.MouseButton1Click:Connect(function()
        applySpeedToCharacter(pSpeed)
        refreshSpeedSlider()
        pBtn.Text = tostring(currentSpeed)
        task.delay(0.8, function() pBtn.Text = "Apply" end)
    end)
    makeStar(pPill, "preset_"..i, -144, 7, function()
        if rebuildFavorites then rebuildFavorites() end
    end)
end

-- ============================================================
--  SETTINGS PAGE
-- ============================================================

Make("TextLabel", {
    Size = ud2(1,0,0,42), BackgroundTransparency = 1, Text = "Settings",
    TextColor3 = C.textPri, TextSize = 16, Font = bold,
    TextXAlignment = Enum.TextXAlignment.Center, Parent = SetPage,
})

local SettingsTabBar = Make("Frame", {Size = ud2(1,-24,0,30), Position = ud2(0,12,0,42), BackgroundTransparency = 1, Parent = SetPage})
Make("UIListLayout", {FillDirection = Enum.FillDirection.Horizontal, HorizontalAlignment = Enum.HorizontalAlignment.Center, Padding = ud(0,6), Parent = SettingsTabBar})

local function makeSettingsTab(name, width)
    local btn = Make("TextButton", {
        Size = ud2(0,width or 80,0,26), BackgroundColor3 = C.surfaceAlt,
        BackgroundTransparency = 0.5, Text = name,
        TextColor3 = C.textSec, TextSize = 10, Font = bold, Parent = SettingsTabBar,
    })
    Make("UICorner", {CornerRadius = ud(1,0), Parent = btn})
    local pill = Make("Frame", {Size = ud2(0,0,0,2), Position = ud2(0.5,0,1,-2), AnchorPoint = Vector2.new(0.5,0), BackgroundColor3 = C.accent, BorderSizePixel = 0, Parent = btn})
    Make("UICorner", {CornerRadius = ud(1,0), Parent = pill})
    return {Button = btn, Pill = pill}
end

local sTab = {}
sTab.Shortcuts = makeSettingsTab("Shortcuts")
sTab.Themes    = makeSettingsTab("Themes")

local function makeSetScroll(visible)
    local s = Make("ScrollingFrame", {
        Size = ud2(1,-24,1,-78), Position = ud2(0,12,0,78),
        BackgroundTransparency = 1, BorderSizePixel = 0,
        ScrollBarThickness = 2, ScrollBarImageColor3 = C.border,
        CanvasSize = ud2(0,0,0,0), AutomaticCanvasSize = Enum.AutomaticSize.Y,
        Active = true, Visible = visible, Parent = SetPage,
    })
    Make("UIListLayout", {SortOrder = Enum.SortOrder.LayoutOrder, Padding = ud(0,5), Parent = s})
    return s
end

local ScrollShortcuts = makeSetScroll(true)
local ScrollThemes    = makeSetScroll(false)

local activeSettingsTab = "Shortcuts"
local function switchSettingsTab(name)
    if activeSettingsTab == name then return end
    activeSettingsTab = name
    ScrollShortcuts.Visible = (name == "Shortcuts")
    ScrollThemes.Visible    = (name == "Themes")
    for key, tab in pairs(sTab) do
        local active = (key == name)
        TweenService:Create(tab.Pill, tabTween, {Size = active and ud2(0,40,0,2) or ud2(0,0,0,2)}):Play()
        TweenService:Create(tab.Button, tabTween, {TextColor3 = active and C.textPri or C.textSec, BackgroundTransparency = active and 0.2 or 0.5}):Play()
    end
end
sTab.Shortcuts.Button.MouseButton1Click:Connect(function() switchSettingsTab("Shortcuts") end)
sTab.Themes.Button.MouseButton1Click:Connect(function()    switchSettingsTab("Themes") end)

-- Settings Section Builder
local function makeSetSection(parent, title, contentH, startOpen)
    local wrapper = Make("Frame", {Size = ud2(1,-16,0,SECTION_H), BackgroundTransparency = 1, ClipsDescendants = true, Parent = parent})
    local header = Make("Frame", {Size = ud2(1,0,0,SECTION_H), BackgroundColor3 = C.surface, BackgroundTransparency = 0.3, BorderSizePixel = 0, Parent = wrapper})
    Make("UICorner", {CornerRadius = ud(1,0), Parent = header})
    local arrow = Make("TextLabel", {Size = ud2(0,28,1,0), Position = ud2(0,10,0,0), BackgroundTransparency = 1, Text = startOpen and "-" or "+", TextColor3 = C.textSec, TextSize = 18, Font = bold, Parent = header})
    Make("TextLabel", {Size = ud2(1,-50,1,0), Position = ud2(0,32,0,0), BackgroundTransparency = 1, Text = title, TextColor3 = C.textPri, TextSize = 12, Font = bold, TextXAlignment = Enum.TextXAlignment.Left, Parent = header})
    local isOpen = startOpen == true
    local content = Make("Frame", {Size = ud2(1,0,0,contentH), Position = ud2(0,0,0,SECTION_H+4), BackgroundTransparency = 1, ClipsDescendants = true, Parent = wrapper})
    local function getActualContentH()
        local layout = content:FindFirstChildOfClass("UIListLayout")
        local h = layout and layout.AbsoluteContentSize.Y or contentH
        return math.max(h, contentH)
    end
    local function updateWrapperSize()
        if isOpen then
            local ch = getActualContentH()
            wrapper.Size = ud2(1,-16,0, SECTION_H + 4 + ch)
        else
            wrapper.Size = ud2(1,-16,0, SECTION_H)
        end
    end
    if startOpen then
        content.Size = ud2(1,0,0,getActualContentH())
        updateWrapperSize()
    end
    local hBtn = Make("TextButton", {Size = ud2(1,0,1,0), BackgroundTransparency = 1, Text = "", Parent = header})
    hBtn.MouseButton1Click:Connect(function()
        isOpen = not isOpen
        arrow.Text = isOpen and "-" or "+"
        if isOpen then
            content.Size = ud2(1,0,0,getActualContentH())
        end
        TweenService:Create(wrapper, sectionTween, {Size = isOpen and ud2(1,-16,0, SECTION_H + 4 + getActualContentH()) or ud2(1,-16,0,SECTION_H)}):Play()
    end)
    return wrapper, content
end

-- === SHORTCUTS: UI Toggle (minimize keybind) ===
local _, ShortcutSecContent = makeSetSection(ScrollShortcuts, "Close and open UI", PART_H+5, false)
local ShortcutItemPill = Make("Frame", {Size = ud2(1,-8,0,PART_H), BackgroundColor3 = C.part_bg, BackgroundTransparency = 0.3, BorderSizePixel = 0, Parent = ShortcutSecContent})
Make("UICorner", {CornerRadius = ud(1,0), Parent = ShortcutItemPill})
Make("TextLabel", {Size = ud2(0,120,1,0), Position = ud2(0,14,0,0), BackgroundTransparency = 1, Text = "Toggle UI Keybind", TextColor3 = C.textPri, TextSize = 11, Font = reg, TextXAlignment = Enum.TextXAlignment.Left, Parent = ShortcutItemPill})
local KeybindBtn = Make("TextButton", {
    Size = ud2(0,110,0,22), Position = ud2(1,-124,0,5),
    BackgroundColor3 = C.surfaceAlt, BackgroundTransparency = 0.1,
    Text = "[ " .. activeKeybind[1].Name .. " + " .. activeKeybind[2].Name .. " ]",
    TextColor3 = C.textPri, TextSize = 11, Font = bold, Parent = ShortcutItemPill,
})
Make("UICorner", {CornerRadius = ud(0,4), Parent = KeybindBtn})
Make("UIStroke", {Color = C.border, Thickness = 1, Transparency = 0.4, Parent = KeybindBtn})

-- === SHORTCUTS: Speed Keybinds ===
local _, SpeedKeySec = makeSetSection(ScrollShortcuts, "Speed Keybinds", PART_H*3+10, false)
Make("UIListLayout", {SortOrder = Enum.SortOrder.LayoutOrder, Padding = ud(0,5), Parent = SpeedKeySec})

local speedUpSPill = Make("Frame", {Size = ud2(1,-8,0,PART_H), BackgroundColor3 = C.part_bg, BackgroundTransparency = 0.3, BorderSizePixel = 0, LayoutOrder = 1, Parent = SpeedKeySec})
Make("UICorner", {CornerRadius = ud(1,0), Parent = speedUpSPill})
Make("TextLabel", {Size = ud2(0,140,1,0), Position = ud2(0,14,0,0), BackgroundTransparency = 1, Text = "Increase Speed", TextColor3 = C.textPri, TextSize = 11, Font = reg, TextXAlignment = Enum.TextXAlignment.Left, Parent = speedUpSPill})
local SpeedUpKeyBtn = Make("TextButton", {
    Size = ud2(0,100,0,22), Position = ud2(1,-114,0,5),
    BackgroundColor3 = C.surfaceAlt, BackgroundTransparency = 0.1,
    Text = "[ " .. cfgSpeedUpKey .. " ]",
    TextColor3 = C.textPri, TextSize = 10, Font = bold, Parent = speedUpSPill,
})
Make("UICorner", {CornerRadius = ud(0,4), Parent = SpeedUpKeyBtn})
Make("UIStroke", {Color = C.border, Thickness = 1, Transparency = 0.4, Parent = SpeedUpKeyBtn})

local speedDownSPill = Make("Frame", {Size = ud2(1,-8,0,PART_H), BackgroundColor3 = C.part_bg, BackgroundTransparency = 0.3, BorderSizePixel = 0, LayoutOrder = 2, Parent = SpeedKeySec})
Make("UICorner", {CornerRadius = ud(1,0), Parent = speedDownSPill})
Make("TextLabel", {Size = ud2(0,140,1,0), Position = ud2(0,14,0,0), BackgroundTransparency = 1, Text = "Decrease Speed", TextColor3 = C.textPri, TextSize = 11, Font = reg, TextXAlignment = Enum.TextXAlignment.Left, Parent = speedDownSPill})
local SpeedDownKeyBtn = Make("TextButton", {
    Size = ud2(0,100,0,22), Position = ud2(1,-114,0,5),
    BackgroundColor3 = C.surfaceAlt, BackgroundTransparency = 0.1,
    Text = "[ " .. cfgSpeedDownKey .. " ]",
    TextColor3 = C.textPri, TextSize = 10, Font = bold, Parent = speedDownSPill,
})
Make("UICorner", {CornerRadius = ud(0,4), Parent = SpeedDownKeyBtn})
Make("UIStroke", {Color = C.border, Thickness = 1, Transparency = 0.4, Parent = SpeedDownKeyBtn})

local panicSPill = Make("Frame", {Size = ud2(1,-8,0,PART_H), BackgroundColor3 = C.part_bg, BackgroundTransparency = 0.3, BorderSizePixel = 0, LayoutOrder = 3, Parent = SpeedKeySec})
Make("UICorner", {CornerRadius = ud(1,0), Parent = panicSPill})
Make("TextLabel", {Size = ud2(0,140,1,0), Position = ud2(0,14,0,0), BackgroundTransparency = 1, Text = "Reset Speed", TextColor3 = C.textPri, TextSize = 11, Font = reg, TextXAlignment = Enum.TextXAlignment.Left, Parent = panicSPill})
local PanicKeyBtn = Make("TextButton", {
    Size = ud2(0,140,0,22), Position = ud2(1,-154,0,5),
    BackgroundColor3 = C.surfaceAlt, BackgroundTransparency = 0.1,
    Text = "[ " .. panicKeybind[1].Name .. " + " .. panicKeybind[2].Name .. " ]",
    TextColor3 = C.textPri, TextSize = 10, Font = bold, Parent = panicSPill,
})
Make("UICorner", {CornerRadius = ud(0,4), Parent = PanicKeyBtn})
Make("UIStroke", {Color = C.border, Thickness = 1, Transparency = 0.4, Parent = PanicKeyBtn})

-- === THEMES ===
local _, ThemeSecContent = makeSetSection(ScrollThemes, "Appearance", 90, false)
local ModePill = Make("Frame", {Size = ud2(1,-8,0,PART_H), BackgroundColor3 = C.part_bg, BackgroundTransparency = 0.3, BorderSizePixel = 0, Parent = ThemeSecContent})
Make("UICorner", {CornerRadius = ud(1,0), Parent = ModePill})
Make("TextLabel", {Size = ud2(0,120,1,0), Position = ud2(0,14,0,0), BackgroundTransparency = 1, Text = "Light Mode", TextColor3 = C.textPri, TextSize = 11, Font = reg, TextXAlignment = Enum.TextXAlignment.Left, Parent = ModePill})
makeToggle(ModePill, (PART_H-18)/2, function(on)
    cfgLightMode = on; applyTheme(); triggerAutoSave()
end, cfgLightMode)

local SliderPill = Make("Frame", {Size = ud2(1,-8,0,45), Position=ud2(0,0,0,PART_H+5), BackgroundColor3 = C.part_bg, BackgroundTransparency = 0.3, BorderSizePixel = 0, Parent = ThemeSecContent})
Make("UICorner", {CornerRadius = ud(1,0), Parent = SliderPill})
Make("TextLabel", {Size = ud2(0,120,0,20), Position = ud2(0,14,0,6), BackgroundTransparency = 1, Text = "Menu Transparency", TextColor3 = C.textPri, TextSize = 11, Font = reg, TextXAlignment = Enum.TextXAlignment.Left, Parent = SliderPill})
local SliderValueLbl = Make("TextLabel", {Size = ud2(0,36,0,20), Position = ud2(1,-50,0,6), BackgroundTransparency = 1, Text = math.floor(cfgTransparency/0.85*100+0.5).."%", TextColor3 = C.textSec, TextSize = 10, Font = bold, TextXAlignment = Enum.TextXAlignment.Right, Parent = SliderPill})
local SliderTrack = Make("Frame", {Size = ud2(1,-28,0,6), Position = ud2(0,14,0,32), BackgroundColor3 = C.toggle_off, BackgroundTransparency = 0.2, BorderSizePixel = 0, Parent = SliderPill})
Make("UICorner", {CornerRadius = ud(1,0), Parent = SliderTrack})
local initFrac = cfgTransparency / 0.85
local SliderFill = Make("Frame", {Size = ud2(initFrac,0,1,0), BackgroundColor3 = C.accent, BackgroundTransparency = 0, BorderSizePixel = 0, Parent = SliderTrack})
Make("UICorner", {CornerRadius = ud(1,0), Parent = SliderFill})
local SliderKnob = Make("TextButton", {Size = ud2(0,14,0,14), Position = ud2(initFrac,-7,0,-4), BackgroundColor3 = C.knob, BorderSizePixel = 0, Text = "", Parent = SliderTrack})
Make("UICorner", {CornerRadius = ud(1,0), Parent = SliderKnob})
Make("UIStroke", {Color = rgb(80,80,80), Thickness = 1, Transparency = 0.3, Parent = SliderKnob})
local sliderDragging = false
local function updateSlider(inputX)
    local relX = inputX - SliderTrack.AbsolutePosition.X
    local frac = math.clamp(relX / SliderTrack.AbsoluteSize.X, 0, 1)
    SliderFill.Size = ud2(frac,0,1,0)
    SliderKnob.Position = ud2(frac,-7,0,-4)
    SliderValueLbl.Text = math.floor(frac*100+0.5).."%"
    applyTransparency(frac * 0.85)
end
SliderKnob.InputBegan:Connect(function(input)
    if input.UserInputType == Enum.UserInputType.MouseButton1 then sliderDragging = true end
end)
local SliderHitbox = Make("TextButton", {Size = ud2(1,0,1,20), Position = ud2(0,0,0,-7), BackgroundTransparency = 1, Text = "", ZIndex = SliderKnob.ZIndex-1, Parent = SliderTrack})
SliderHitbox.InputBegan:Connect(function(input)
    if input.UserInputType == Enum.UserInputType.MouseButton1 then sliderDragging = true; updateSlider(input.Position.X) end
end)
UserInputService.InputEnded:Connect(function(input)
    if input.UserInputType == Enum.UserInputType.MouseButton1 then
        if sliderDragging then sliderDragging = false; triggerAutoSave() end
    end
end)
UserInputService.InputChanged:Connect(function(input)
    if sliderDragging and input.UserInputType == Enum.UserInputType.MouseMovement then updateSlider(input.Position.X) end
end)

-- ============================================================
--  TRAFFIC LIGHT DOTS + PILL + DRAGGING
-- ============================================================

transparencyFrames = {
    {frame = Main,   base = 0},
    {frame = PillUI, base = 0},
}
applyTransparency(cfgTransparency)
applyTheme()

local function makeDraggableReal(object, handle)
    local dragging = false
    local relative = Vector2.zero
    local insetOff = Vector2.zero
    local sg = object:FindFirstAncestorWhichIsA("ScreenGui")
    if sg and sg.IgnoreGuiInset then
        local ok, inset = pcall(function() return GuiService:GetGuiInset() end)
        if ok then insetOff = insetOff + inset end
    end
    handle.InputBegan:Connect(function(input, processed)
        if processed then return end
        if input.UserInputType == Enum.UserInputType.MouseButton1 or input.UserInputType == Enum.UserInputType.Touch then
            dragging = true
            relative = Vector2.new(object.AbsolutePosition.X, object.AbsolutePosition.Y)
                + Vector2.new(object.AbsoluteSize.X * object.AnchorPoint.X, object.AbsoluteSize.Y * object.AnchorPoint.Y)
                - UserInputService:GetMouseLocation()
        end
    end)
    local ec = UserInputService.InputEnded:Connect(function(input)
        if input.UserInputType == Enum.UserInputType.MouseButton1 or input.UserInputType == Enum.UserInputType.Touch then dragging = false end
    end)
    local rc = RunService.RenderStepped:Connect(function()
        if dragging then
            local pos = UserInputService:GetMouseLocation() + relative + insetOff
            object.Position = UDim2.fromOffset(pos.X, pos.Y)
        end
    end)
    object.Destroying:Connect(function() ec:Disconnect(); rc:Disconnect() end)
end

makeDraggableReal(Main, Main)
makeDraggableReal(PillUI, PillUI)

local tweenInfo   = TweenInfo.new(0.28, Enum.EasingStyle.Quart, Enum.EasingDirection.Out)
local pillUsed    = false
local lastMainPos = Main.Position
local isAnimating = false

local function shrinkToPill()
    if not Main.Visible or isAnimating then return end
    isAnimating = true
    lastMainPos = Main.Position
    PillUI.Size = ud2(0,0,0,34)
    if not pillUsed then PillUI.Position = ud2(0.5,0,0,12); pillUsed = true end
    PillUI.Visible = true
    PillScale.Scale = 0
    TweenService:Create(PillUI,    tweenInfo, {Size = ud2(0,110,0,34)}):Play()
    TweenService:Create(PillScale, tweenInfo, {Scale = 1}):Play()
    TweenService:Create(MainScale, tweenInfo, {Scale = 0}):Play()
    TweenService:Create(Main, tweenInfo, {
        Position = ud2(PillUI.Position.X.Scale, PillUI.Position.X.Offset,
            PillUI.Position.Y.Scale, PillUI.Position.Y.Offset + 17)
    }):Play()
    task.delay(0.32, function()
        if Main and Main.Parent then Main.Visible = false end
        isAnimating = false
    end)
end

local function expandFromPill()
    if not PillUI.Visible or isAnimating then return end
    isAnimating   = true
    Main.Position = lastMainPos
    Main.Visible  = true
    TweenService:Create(PillScale, tweenInfo, {Scale = 0}):Play()
    TweenService:Create(MainScale, tweenInfo, {Scale = isExpanded and 1.4 or 1}):Play()
    task.delay(0.32, function()
        if PillUI and PillUI.Parent then PillUI.Visible = false; PillScale.Scale = 1 end
        isAnimating = false
    end)
end

CloseBtn.MouseButton1Click:Connect(function() Gui:Destroy() end)
MinBtn.MouseButton1Click:Connect(shrinkToPill)
MaxBtn.MouseButton1Click:Connect(function()
    isExpanded = not isExpanded
    TweenService:Create(MainScale, tweenInfo, {Scale = isExpanded and 1.4 or 1}):Play()
    triggerAutoSave()
end)

local pillDragStart = nil
PillUI.InputBegan:Connect(function(input)
    if input.UserInputType == Enum.UserInputType.MouseButton1 or input.UserInputType == Enum.UserInputType.Touch then
        pillDragStart = input.Position
    end
end)
PillUI.InputEnded:Connect(function(input)
    if (input.UserInputType == Enum.UserInputType.MouseButton1 or input.UserInputType == Enum.UserInputType.Touch) and pillDragStart then
        if (input.Position - pillDragStart).Magnitude < 6 then expandFromPill() end
        pillDragStart = nil
    end
end)

-- Toggle Settings Page
ToggleBtn.MouseButton1Click:Connect(function()
    local inSettings = not SetPage.Visible
    ToggleBtn.Text   = inSettings and "\u{1F4C4}" or "\u{2699}"
    MainPage.Visible = not inSettings
    SetPage.Visible  = inSettings
    if inSettings then CollapseAllBtn.Visible = false else updateCollapseAllVisibility() end
end)

-- Search
SearchBtn.MouseButton1Click:Connect(function()
    local isSearching = SearchBarHolder.Position.Y.Offset == 8
    if not isSearching then
        if SetPage.Visible then ToggleBtn.Text = "\u{2699}"; SetPage.Visible = false; MainPage.Visible = true; updateCollapseAllVisibility() end
        TweenService:Create(SearchBarHolder, TweenInfo.new(0.2, Enum.EasingStyle.Quart, Enum.EasingDirection.Out), {Position = ud2(0.5,-95,0,8)}):Play()
        TweenService:Create(TitleLabel, TweenInfo.new(0.2, Enum.EasingStyle.Quart, Enum.EasingDirection.Out), {TextTransparency = 1}):Play()
        SearchInput:CaptureFocus()
    else
        TweenService:Create(SearchBarHolder, TweenInfo.new(0.2, Enum.EasingStyle.Quart, Enum.EasingDirection.Out), {Position = ud2(0.5,-95,0,-34)}):Play()
        TweenService:Create(TitleLabel, TweenInfo.new(0.2, Enum.EasingStyle.Quart, Enum.EasingDirection.Out), {TextTransparency = 0}):Play()
        SearchInput.Text = ""
    end
end)

SearchInput.FocusLost:Connect(function()
    if SearchInput.Text == "" then
        TweenService:Create(SearchBarHolder, TweenInfo.new(0.2, Enum.EasingStyle.Quart, Enum.EasingDirection.Out), {Position = ud2(0.5,-95,0,-34)}):Play()
        TweenService:Create(TitleLabel, TweenInfo.new(0.2, Enum.EasingStyle.Quart, Enum.EasingDirection.Out), {TextTransparency = 0}):Play()
    end
end)

SearchInput:GetPropertyChangedSignal("Text"):Connect(function()
    local query = string.lower(SearchInput.Text)
    for _, sec in pairs(tabSections) do
        for _, s in ipairs(sec) do
            for _, child in ipairs(s.Content:GetChildren()) do
                local sn = child:GetAttribute("SearchName")
                if sn then
                    child.Visible = (query == "" or string.find(string.lower(sn), query, 1, true))
                else
                    child.Visible = (query == "")
                end
            end
            s.resizeToContent()
            if query ~= "" and not s.IsOpen() then
                local hasVis = false
                for _, c in ipairs(s.Content:GetChildren()) do
                    if c:IsA("GuiObject") and c.Visible then hasVis = true; break end
                end
                if hasVis then s.SetOpen(true) end
            end
        end
    end
end)

-- Tab Switching
local function switchTab(tabName)
    if activeTab == tabName then return end
    activeTab = tabName
    for key, tab in pairs(tabs) do
        local active = (key == tabName)
        TweenService:Create(tab.Pill, tabTween, {Size = active and ud2(0,40,0,2) or ud2(0,0,0,2)}):Play()
        TweenService:Create(tab.Button, tabTween, {TextColor3 = active and C.textPri or C.textSec, BackgroundTransparency = active and 0.2 or 0.5}):Play()
    end
    homeContainer.Visible  = (tabName == "Home")
    speedContainer.Visible = (tabName == "Speed")
    updateCollapseAllVisibility()
end

tabs.Home.Button.MouseButton1Click:Connect(function() switchTab("Home") end)
tabs.Speed.Button.MouseButton1Click:Connect(function() switchTab("Speed") end)
switchTab("Home")

CollapseAllBtn.MouseButton1Click:Connect(function()
    for _, sec in ipairs(tabSections[activeTab] or {}) do
        if sec.IsOpen() then sec.SetOpen(false) end
    end
end)

-- ============================================================
--  FAVORITES REBUILD
-- ============================================================

function rebuildFavorites()
    if not favSec then return end
    for _, child in ipairs(favSec.Content:GetChildren()) do
        if child:IsA("Frame") then child:Destroy() end
    end

    local count = 0
    local favList = {}
    for uid, isFav in pairs(cfgFavorites) do
        if isFav == true and uid ~= "" then
            table.insert(favList, uid)
        end
    end
    table.sort(favList)

    for i, uid in ipairs(favList) do
        local rendered = false

        if uid == "advwalkspeed_main" then
            createTogglePart(favSec.Content, "Advanced Walk Speed", uid, i, function(state)
                cfgEnabled = state
                if not state then
                    preToggleSpeed = currentSpeed
                    pcall(function()
                        local char = LocalPlayer.Character
                        if char then
                            local hum = char:FindFirstChildOfClass("Humanoid")
                            if hum then hum.WalkSpeed = gameDefaultSpeed end
                        end
                    end)
                else
                    currentSpeed = preToggleSpeed
                    applySpeedToCharacter(currentSpeed)
                    refreshSpeedSlider()
                end
                triggerAutoSave()
            end, cfgEnabled)
            count = count + 1
            rendered = true
        end

        if uid == "advwalkspeed_instantstop" then
            createTogglePart(favSec.Content, "Instant Stop", uid, i, function(state)
                cfgInstantStop = state; triggerAutoSave()
            end, cfgInstantStop)
            count = count + 1
            rendered = true
        end

        if uid == "advwalkspeed_extreme" then
            local pill = Make("Frame", {
                Size = ud2(1,-8,0,PART_H), BackgroundColor3 = C.part_bg,
                BackgroundTransparency = 0.3, BorderSizePixel = 0,
                LayoutOrder = i, Parent = favSec.Content,
            })
            pill:SetAttribute("SearchName", "EXTREME SPEED MODE")
            Make("UICorner", {CornerRadius = ud(1,0), Parent = pill})
            Make("TextLabel", {
                Size = ud2(1,-100,1,0), Position = ud2(0,14,0,0),
                BackgroundTransparency = 1, Text = "EXTREME SPEED MODE",
                TextColor3 = C.dot_red, TextSize = 11, Font = bold,
                TextXAlignment = Enum.TextXAlignment.Left, Parent = pill,
            })
            makeToggle(pill, (PART_H-18)/2, function(state)
                cfgExtremeSpeed = state
                applySpeedToCharacter(currentSpeed)
                refreshSpeedSlider()
                triggerAutoSave()
            end, cfgExtremeSpeed)
            local favStar = Make("TextButton", {
                Size = ud2(0,22,0,22), Position = ud2(1,-74,0,5),
                BackgroundTransparency = 1, Text = "★",
                TextColor3 = C.dot_yel, TextSize = 18, Font = bold, Parent = pill,
            })
            favStar.MouseButton1Click:Connect(function()
                cfgFavorites[uid] = false
                if starRefs[uid] then starRefs[uid].TextColor3 = C.textSec end
                triggerAutoSave()
                rebuildFavorites()
            end)
            count = count + 1
            rendered = true
        end

        if uid == "advwalkspeed_cframe" then
            local pill = Make("Frame", {
                Size = ud2(1,-8,0,PART_H), BackgroundColor3 = C.part_bg,
                BackgroundTransparency = 0.3, BorderSizePixel = 0,
                LayoutOrder = i, Parent = favSec.Content,
            })
            pill:SetAttribute("SearchName", "CFrame Walking (Anti-Cheat Bypass)")
            Make("UICorner", {CornerRadius = ud(1,0), Parent = pill})
            Make("TextLabel", {
                Size = ud2(1,-100,1,0), Position = ud2(0,14,0,0),
                BackgroundTransparency = 1, Text = "CFrame Walking (Bypass)",
                TextColor3 = C.dot_yel, TextSize = 11, Font = bold,
                TextXAlignment = Enum.TextXAlignment.Left, Parent = pill,
            })
            makeToggle(pill, (PART_H-18)/2, function(state)
                cfgCFrameBypass = state
                if not state then
                    pcall(function()
                        local char = LocalPlayer.Character
                        if char then
                            local hum = char:FindFirstChildOfClass("Humanoid")
                            if hum then hum.WalkSpeed = currentSpeed end
                        end
                    end)
                end
                triggerAutoSave()
            end, cfgCFrameBypass)
            local favStar = Make("TextButton", {
                Size = ud2(0,22,0,22), Position = ud2(1,-74,0,5),
                BackgroundTransparency = 1,                 Text = "\u{2605}",
                TextColor3 = C.dot_yel, TextSize = 18, Font = bold, Parent = pill,
            })
            favStar.MouseButton1Click:Connect(function()
                cfgFavorites[uid] = false
                if starRefs[uid] then starRefs[uid].TextColor3 = C.textSec end
                triggerAutoSave()
                rebuildFavorites()
            end)
            count = count + 1
            rendered = true
        end

        if not rendered then
            local matchPreset = uid:match("^preset_(%d+)$")
            if matchPreset then
                local idx = tonumber(matchPreset)
                local presetDefaults = {16, 32, 100, 200, 500, 1000}
                local presetNames = {"Walk","Sprint","Mach 1","Mach 2","Mach 3","Mach 5"}
                local pName = presetNames[idx] or "Preset"
                local pSpeed = presetDefaults[idx] or 100

                local pill = Make("Frame", {
                    Size = ud2(1,-8,0,36), BackgroundColor3 = C.part_bg,
                    BackgroundTransparency = 0.3, BorderSizePixel = 0,
                    LayoutOrder = i, Parent = favSec.Content,
                })
                pill:SetAttribute("SearchName", pName)
                Make("UICorner", {CornerRadius = ud(1,0), Parent = pill})
                Make("TextLabel", {
                    Size = ud2(0,80,1,0), Position = ud2(0,14,0,0),
                    BackgroundTransparency = 1, Text = pName,
                    TextColor3 = C.textPri, TextSize = 11, Font = reg,
                    TextXAlignment = Enum.TextXAlignment.Left, Parent = pill,
                })
                Make("TextLabel", {
                    Size = ud2(0,50,1,0), Position = ud2(0,100,0,0),
                    BackgroundTransparency = 1, Text = tostring(pSpeed) .. " spd",
                    TextColor3 = C.accent, TextSize = 10, Font = bold,
                    TextXAlignment = Enum.TextXAlignment.Left, Parent = pill,
                })
                local pBtn = Make("TextButton", {
                    Size = ud2(0,60,0,22), Position = ud2(1,-80,0.5,-11),
                    BackgroundColor3 = C.accent, BackgroundTransparency = 0.1,
                    Text = "Apply", TextColor3 = C.white,
                    TextSize = 10, Font = bold, Parent = pill,
                })
                Make("UICorner", {CornerRadius = ud(0,4), Parent = pBtn})
                pBtn.MouseButton1Click:Connect(function()
                    applySpeedToCharacter(pSpeed)
                    refreshSpeedSlider()
                    pBtn.Text = tostring(currentSpeed)
                    task.delay(0.8, function() pBtn.Text = "Apply" end)
                end)
                local favStar = Make("TextButton", {
                    Size = ud2(0,22,0,22), Position = ud2(1,-144,0,7),
                    BackgroundTransparency = 1, Text = "★",
                    TextColor3 = C.dot_yel, TextSize = 18, Font = bold, Parent = pill,
                })
                favStar.MouseButton1Click:Connect(function()
                    cfgFavorites[uid] = false
                    if starRefs[uid] then starRefs[uid].TextColor3 = C.textSec end
                    triggerAutoSave()
                    rebuildFavorites()
                end)
                count = count + 1
                rendered = true
            end
        end
    end

    local emptyLabel = favSec.Content:FindFirstChild("FavEmptyLabel")
    if count == 0 then
        if not emptyLabel then
            Make("TextLabel", {
                Name = "FavEmptyLabel",
                Size = ud2(1,-8,0,28), BackgroundTransparency = 1,
                Text = "No favorites", TextColor3 = C.textSec,
                TextSize = 11, Font = reg, LayoutOrder = 0, Parent = favSec.Content,
            })
        end
    else
        if emptyLabel then emptyLabel:Destroy() end
    end

    favSec.resizeToContent()
    if favSec.IsOpen() then
        favSec.Wrapper.Size = ud2(1,-16,0, SECTION_H + 4 + favSec.Content.Size.Y.Offset)
    end
end

-- ============================================================
--  KEYBIND LISTENING (Settings page)
-- ============================================================

local isListeningFor = nil
local listeningBtn   = nil
local tempKeys       = {}

local function startListening(which, btn)
    isListeningFor = which
    listeningBtn   = btn
    btn.Text = "[ Press Key ]"
    btn.TextColor3 = C.dot_yel
end

local function stopListening()
    isListeningFor = nil
    listeningBtn   = nil
end

KeybindBtn.MouseButton1Click:Connect(function()
    if not isListeningFor then
        isListeningFor = "uiToggle1"
        tempKeys = {}
        KeybindBtn.Text = "[ Press 1st Key ]"
        KeybindBtn.TextColor3 = C.dot_yel
    end
end)

SpeedUpKeyBtn.MouseButton1Click:Connect(function()
    if not isListeningFor then startListening("speedUp", SpeedUpKeyBtn) end
end)
SpeedDownKeyBtn.MouseButton1Click:Connect(function()
    if not isListeningFor then startListening("speedDown", SpeedDownKeyBtn) end
end)
PanicKeyBtn.MouseButton1Click:Connect(function()
    if not isListeningFor then startListening("panic1", PanicKeyBtn) end
end)

-- ============================================================
--  INPUT HANDLING
-- ============================================================

local keybindConn
keybindConn = UserInputService.InputBegan:Connect(function(input, processed)
    if not Gui or not Gui.Parent then keybindConn:Disconnect(); return end

    -- Keybind listening
    if isListeningFor and input.UserInputType == Enum.UserInputType.Keyboard and input.KeyCode ~= Enum.KeyCode.Unknown then
        local keyName = input.KeyCode.Name

        if isListeningFor == "uiToggle1" then
            tempKeys[1] = input.KeyCode
            KeybindBtn.Text = "[ " .. keyName .. " + ? ]"
            isListeningFor = "uiToggle2"
            return
        elseif isListeningFor == "uiToggle2" then
            tempKeys[2] = input.KeyCode
            activeKeybind = {tempKeys[1], tempKeys[2]}
            isListeningFor = nil
            KeybindBtn.TextColor3 = C.textPri
            KeybindBtn.Text = "[ " .. tempKeys[1].Name .. " + " .. tempKeys[2].Name .. " ]"
            cfgKeybind1Name = tempKeys[1].Name
            cfgKeybind2Name = tempKeys[2].Name
            triggerAutoSave()
            return
        elseif isListeningFor == "speedUp" then
            cfgSpeedUpKey = keyName
            SpeedUpKeyBtn.Text = "[ " .. keyName .. " ]"
            SpeedUpKeyBtn.TextColor3 = C.textPri
        elseif isListeningFor == "speedDown" then
            cfgSpeedDownKey = keyName
            SpeedDownKeyBtn.Text = "[ " .. keyName .. " ]"
            SpeedDownKeyBtn.TextColor3 = C.textPri
        elseif isListeningFor == "panic1" then
            tempKeys[1] = input.KeyCode
            PanicKeyBtn.Text = "[ " .. keyName .. " + ? ]"
            isListeningFor = "panic2"
            return
        elseif isListeningFor == "panic2" then
            tempKeys[2] = input.KeyCode
            panicKeybind = {tempKeys[1], tempKeys[2]}
            isListeningFor = nil
            PanicKeyBtn.TextColor3 = C.textPri
            PanicKeyBtn.Text = "[ " .. tempKeys[1].Name .. " + " .. tempKeys[2].Name .. " ]"
            cfgPanicKey1 = tempKeys[1].Name
            cfgPanicKey2 = tempKeys[2].Name
            triggerAutoSave()
            return
        end
        stopListening()
        triggerAutoSave()
        return
    end

    -- UI Toggle keybind (hold first, press second)
    if not processed and not isListeningFor and input.UserInputType == Enum.UserInputType.Keyboard then
        if #activeKeybind == 2 then
            if (input.KeyCode == activeKeybind[2] and UserInputService:IsKeyDown(activeKeybind[1]))
            or (input.KeyCode == activeKeybind[1] and UserInputService:IsKeyDown(activeKeybind[2])) then
                if Main.Visible then shrinkToPill()
                elseif PillUI.Visible then expandFromPill() end
            end
        end
        -- Panic keybind (hold first, press second) - toggles Advanced Walk Speed
        if #panicKeybind == 2 then
            if (input.KeyCode == panicKeybind[2] and UserInputService:IsKeyDown(panicKeybind[1]))
            or (input.KeyCode == panicKeybind[1] and UserInputService:IsKeyDown(panicKeybind[2])) then
                cfgEnabled = not cfgEnabled
                if cfgEnabled then
                    currentSpeed = preToggleSpeed
                    applySpeedToCharacter(currentSpeed)
                    refreshSpeedSlider()
                else
                    preToggleSpeed = currentSpeed
                    pcall(function()
                        local char = LocalPlayer.Character
                        if char then
                            local hum = char:FindFirstChildOfClass("Humanoid")
                            if hum then hum.WalkSpeed = gameDefaultSpeed end
                        end
                    end)
                end
                awsMainToggle.SetOn(cfgEnabled, true)
                triggerAutoSave()
                rebuildFavorites()
            end
        end
    end

    -- Speed keys (only when enabled)
    if not cfgEnabled then return end
    if processed then return end
    if input.UserInputType ~= Enum.UserInputType.Keyboard then return end

    if input.KeyCode == keycodeFromName(cfgSpeedUpKey) then
        isHoldingSpeedUp = true
        applySpeedToCharacter(currentSpeed + cfgSpeedIncrement)
        lastSpeedUpTime = tick()
        refreshSpeedSlider()
    end
    if input.KeyCode == keycodeFromName(cfgSpeedDownKey) then
        isHoldingSpeedDown = true
        applySpeedToCharacter(currentSpeed - cfgSpeedIncrement)
        lastSpeedDownTime = tick()
        refreshSpeedSlider()
    end
end)

UserInputService.InputEnded:Connect(function(input)
    if input.UserInputType ~= Enum.UserInputType.Keyboard then return end
    if input.KeyCode == keycodeFromName(cfgSpeedUpKey) then isHoldingSpeedUp = false end
    if input.KeyCode == keycodeFromName(cfgSpeedDownKey) then isHoldingSpeedDown = false end
end)

-- ============================================================
--  HOLD-TO-REPEAT
-- ============================================================

task.spawn(function()
    while task.wait(0.05) do
        if not Gui or not Gui.Parent then break end
        if not cfgEnabled then continue end
        local now = tick()
        if isHoldingSpeedUp and (now - lastSpeedUpTime) >= HOLD_REPEAT_RATE then
            applySpeedToCharacter(currentSpeed + cfgSpeedIncrement)
            lastSpeedUpTime = now
            refreshSpeedSlider()
        end
        if isHoldingSpeedDown and (now - lastSpeedDownTime) >= HOLD_REPEAT_RATE then
            applySpeedToCharacter(currentSpeed - cfgSpeedIncrement)
            lastSpeedDownTime = now
            refreshSpeedSlider()
        end
    end
end)

-- ============================================================
--  INSTANT STOP
-- ============================================================

task.spawn(function()
    while task.wait(0.03) do
        if not Gui or not Gui.Parent then break end
        if not cfgEnabled or not cfgInstantStop then continue end
        local anyDown = UserInputService:IsKeyDown(Enum.KeyCode.W)
            or UserInputService:IsKeyDown(Enum.KeyCode.A)
            or UserInputService:IsKeyDown(Enum.KeyCode.S)
            or UserInputService:IsKeyDown(Enum.KeyCode.D)
        if not anyDown then
            pcall(function()
                local char = LocalPlayer.Character
                if char then
                    local hrp = char:FindFirstChild("HumanoidRootPart")
                    if hrp then
                        local vel = hrp.Velocity
                        if Vector3.new(vel.X, 0, vel.Z).Magnitude > 0.5 then
                            hrp.Velocity = Vector3.new(0, vel.Y, 0)
                        end
                    end
                end
            end)
        end
    end
end)

-- ============================================================
--  SPEED ENFORCEMENT (re-apply if game resets speed)
-- ============================================================

task.spawn(function()
    while task.wait(0.3) do
        if not Gui or not Gui.Parent then break end
        pcall(function()
            local char = LocalPlayer.Character
            if char then
                local hum = char:FindFirstChildOfClass("Humanoid")
                if hum then
                    if cfgEnabled then
                        if cfgCFrameBypass then
                            if hum.WalkSpeed ~= gameDefaultSpeed then
                                hum.WalkSpeed = gameDefaultSpeed
                            end
                        else
                            if hum.WalkSpeed ~= currentSpeed then
                                hum.WalkSpeed = currentSpeed
                            end
                        end
                    else
                        if hum.WalkSpeed ~= gameDefaultSpeed then
                            hum.WalkSpeed = gameDefaultSpeed
                        end
                    end
                end
            end
        end)
    end
end)

-- ============================================================
--  CFRAME WALKING (ANTI-CHEAT BYPASS)
--  Uses BodyVelocity to control speed while keeping WalkSpeed
--  at game default for animations and anti-cheat compatibility.
-- ============================================================

task.spawn(function()
    local RunService = game:GetService("RunService")
    local heartbeatConn = nil
    local currentBodyVel = nil

    local function createBodyVelocity(char)
        local hrp = char:FindFirstChild("HumanoidRootPart")
        if not hrp then return nil end
        local existing = hrp:FindFirstChild("AwsBodyVel")
        if existing then existing:Destroy() end
        local bv = Instance.new("BodyVelocity")
        bv.Name = "AwsBodyVel"
        bv.MaxForce = Vector3.new(math.huge, 0, math.huge)
        bv.Velocity = Vector3.zero
        bv.P = 10000
        bv.Parent = hrp
        return bv
    end

    local function destroyBodyVelocity(char)
        if not char then return end
        local hrp = char:FindFirstChild("HumanoidRootPart")
        if hrp then
            local bv = hrp:FindFirstChild("AwsBodyVel")
            if bv then bv:Destroy() end
        end
    end

    local function startCFrameLoop()
        if heartbeatConn then return end
        local char = LocalPlayer.Character
        if not char then return end
        currentBodyVel = createBodyVelocity(char)
        heartbeatConn = RunService.Heartbeat:Connect(function(dt)
            if not Gui or not Gui.Parent then
                if heartbeatConn then heartbeatConn:Disconnect(); heartbeatConn = nil end
                if currentBodyVel then currentBodyVel:Destroy(); currentBodyVel = nil end
                return
            end
            if not cfgCFrameBypass or not cfgEnabled then return end
            pcall(function()
                local ch = LocalPlayer.Character
                if not ch then return end
                local hum = ch:FindFirstChildOfClass("Humanoid")
                if not hum then return end
                if hum.WalkSpeed ~= gameDefaultSpeed then
                    hum.WalkSpeed = gameDefaultSpeed
                end
                local bv = ch:FindFirstChild("HumanoidRootPart") and ch:FindFirstChild("HumanoidRootPart"):FindFirstChild("AwsBodyVel")
                if not bv then
                    currentBodyVel = createBodyVelocity(ch)
                    bv = currentBodyVel
                end
                if bv then
                    local moveDir = hum.MoveDirection
                    if moveDir.Magnitude > 0.01 then
                        bv.Velocity = Vector3.new(moveDir.X, 0, moveDir.Z).Unit * currentSpeed
                    else
                        bv.Velocity = Vector3.new(0, 0, 0)
                    end
                end
            end)
        end)
    end

    local function stopCFrameLoop()
        if heartbeatConn then
            heartbeatConn:Disconnect()
            heartbeatConn = nil
        end
        pcall(function()
            local char = LocalPlayer.Character
            destroyBodyVelocity(char)
            currentBodyVel = nil
        end)
    end

    local lastBypassState = cfgCFrameBypass
    task.spawn(function()
        while task.wait(0.1) do
            if not Gui or not Gui.Parent then break end
            if cfgCFrameBypass and cfgEnabled then
                if not lastBypassState then
                    startCFrameLoop()
                end
            else
                if lastBypassState then
                    stopCFrameLoop()
                    pcall(function()
                        local char = LocalPlayer.Character
                        if char then
                            local hum = char:FindFirstChildOfClass("Humanoid")
                            if hum then
                                if cfgEnabled then
                                    hum.WalkSpeed = currentSpeed
                                else
                                    hum.WalkSpeed = gameDefaultSpeed
                                end
                            end
                        end
                    end)
                end
            end
            lastBypassState = cfgCFrameBypass and cfgEnabled
        end
    end)

    LocalPlayer.CharacterAdded:Connect(function(char)
        if not cfgCFrameBypass or not cfgEnabled then return end
        task.wait(1)
        pcall(function()
            destroyBodyVelocity(char)
            if heartbeatConn then
                currentBodyVel = createBodyVelocity(char)
            end
        end)
    end)

    if cfgCFrameBypass and cfgEnabled then
        startCFrameLoop()
    end
end)

-- ============================================================
--  RESPAWN AUTO-APPLY
-- ============================================================

LocalPlayer.CharacterAdded:Connect(function(char)
    task.wait(1.5)
    local hum = char:WaitForChild("Humanoid", 5)
    if hum then
        gameDefaultSpeed = hum.WalkSpeed
        if cfgEnabled then
            if cfgCFrameBypass then
                hum.WalkSpeed = gameDefaultSpeed
            else
                hum.WalkSpeed = currentSpeed
            end
        else
            hum.WalkSpeed = gameDefaultSpeed
        end
    end
end)

task.spawn(function()
    pcall(function()
        local char = LocalPlayer.Character
        if char then
            local hum = char:FindFirstChildOfClass("Humanoid")
            if hum then gameDefaultSpeed = hum.WalkSpeed end
        end
    end)
    if cfgEnabled then
        task.wait(0.5)
        applySpeedToCharacter(currentSpeed)
        refreshSpeedSlider()
    end
end)

-- ============================================================
--  INIT
-- ============================================================

pcall(function()
    local char = LocalPlayer.Character
    if char then
        local hum = char:FindFirstChildOfClass("Humanoid")
        if hum then
            gameDefaultSpeed = hum.WalkSpeed
        end
    end
end)

applyTheme()
rebuildFavorites()
print("[Advanced Walk Speed] Loaded - All features active")
