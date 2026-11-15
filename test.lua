--==================================================================
-- 1THANGNGU - MM2 KAITUN (Ultimate 100 Tabs Performance)
-- Tự động BẬT mọi chức năng không có trong Config
--==================================================================

local Players           = game:GetService("Players")
local TweenService      = game:GetService("TweenService")
local RunService        = game:GetService("RunService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local VirtualUser       = game:GetService("VirtualUser")
local TeleportService   = game:GetService("TeleportService")
local HttpService       = game:GetService("HttpService")
local Lighting          = game:GetService("Lighting")
local StarterGui        = game:GetService("StarterGui")

local LocalPlayer = Players.LocalPlayer

--==================================================================
-- BẬT CHẾ ĐỘ MÀN HÌNH ĐEN TUYỆT ĐỐI (KHÔNG RENDER 3D)
--==================================================================
pcall(function() RunService:Set3dRenderingEnabled(false) end)

local blackoutGui = Instance.new("ScreenGui")
blackoutGui.Name = "BlackScreenOverlay"
blackoutGui.IgnoreGuiInset = true
blackoutGui.DisplayOrder = 999998
blackoutGui.Parent = LocalPlayer:WaitForChild("PlayerGui")

local blackFrame = Instance.new("Frame")
blackFrame.Size = UDim2.fromScale(1, 1)
blackFrame.BackgroundColor3 = Color3.new(0, 0, 0)
blackFrame.BorderSizePixel = 0
blackFrame.ZIndex = 1
blackFrame.Parent = blackoutGui

--==================================================================
-- PARSE CONFIG (Các chức năng khác auto ON nếu không có)
--==================================================================
local USER_CFG = (getgenv and getgenv().Config) or {}
local function get(t, k, def)
    if type(t) == "table" and t[k] ~= nil then return t[k] end
    return def
end

local cfg = {
    autoFarm         = get(USER_CFG, "AutoFarm",         true),
    antiAFK          = get(USER_CFG, "AntiAFK",          true),
    autoHop          = get(USER_CFG, "AutoHop",          true),
    lagFix           = get(USER_CFG, "LagFix",           true),
    spinBot          = get(USER_CFG, "SpinBot",          true),
    spinSpeed        = get(USER_CFG, "SpinSpeed",        90),
    farmSpeed        = get(USER_CFG, "FarmSpeed",        30),
    collectDelay     = get(USER_CFG, "CollectDelay",     0.1),
    maxFarmDist      = get(USER_CFG, "MaxFarmDist",      80), 
    fpsCap           = get(USER_CFG, "FpsCap",           10), 
    hopMinCoins      = get(USER_CFG, "HopMinCoins",      150),
    hopWindow        = get(USER_CFG, "HopWindow",        600),
    coinStep         = 1000,
    coinCycle        = get(USER_CFG, "CoinCycle",        50),
    cycleFlashDur    = get(USER_CFG, "CycleFlashDur",    3),
}

-- Parse Webhook
local WH_CFG = USER_CFG.Webhook or {}
local WH_ROLL = {
    enabled  = get(WH_CFG.Roll or {}, "Enabled",  true),
    url      = get(WH_CFG.Roll or {}, "URL",      ""),
    rarities = get(WH_CFG.Roll or {}, "Notify Rarity", { "Godly", "Ancient", "Legendary" }),
}
local WH_COIN = {
    enabled = get(WH_CFG.Coin or {}, "Enabled", true),
    url     = get(WH_CFG.Coin or {}, "URL",     ""),
    step    = get(WH_CFG.Coin or {}, "Step",    1000),
}

-- Parse AutoCrate
local CRATE_CFG = USER_CFG.AutoCrate or {}
local cfg_crate = {
    enabled    = get(CRATE_CFG, "Enabled", true),
    boxName    = get(CRATE_CFG, "BoxName", "Halloween2026Box"),
    category   = get(CRATE_CFG, "Category", "MysteryBox"),
    keys       = get(CRATE_CFG, "Keys", { "Candies2026", "HalloweenKey2026" }),
    interval   = get(CRATE_CFG, "Interval", 600), 
    burstTime  = get(CRATE_CFG, "BurstTime", 5),  
    spamStep   = get(CRATE_CFG, "SpamStep", 0.1),
}

local stats = {
    coins           = 0,
    sessionCoins    = 0,
    cycleCoins      = 0,
    cycles          = 0,
    lastCoinInRound = 0,
    hops            = 0,
    cratesOpened    = 0,
    crateErrors     = 0,
    started         = os.clock(),
    sessionStart    = os.clock(),
}

-- Biến trạng thái
local roundActive = false
local isTweening = false
local cycleReset = false
local waitingForNewRound = false
local cachedContainer = nil

--==================================================================
-- HUD LIBRARY
--==================================================================
local function clamp(x,a,b) return math.max(a, math.min(b, x)) end
local function rgb(t) return Color3.fromRGB(t[1], t[2], t[3]) end
local function rich(text, c3)
    return string.format('<font color="rgb(%d,%d,%d)">%s</font>',
        math.floor(c3.R*255), math.floor(c3.G*255), math.floor(c3.B*255), tostring(text))
end
local function richJoin(parts)
    local out = {}
    for _, p in ipairs(parts or {}) do out[#out+1] = rich(p[1], rgb(p[2])) end
    return table.concat(out)
end
local function fmtTime(sec)
    sec = math.max(0, math.floor(sec))
    return string.format("%d Hours, %d Minutes, %d Seconds",
        math.floor(sec/3600), math.floor((sec%3600)/60), sec%60)
end
local function mkLabel(parent, name, props, useShadow)
    local lbl = Instance.new("TextLabel")
    lbl.Name = name; lbl.Parent = parent
    lbl.BackgroundTransparency = 1
    lbl.TextXAlignment = Enum.TextXAlignment.Center
    lbl.TextYAlignment = Enum.TextYAlignment.Center
    lbl.RichText = true; lbl.Font = Enum.Font.GothamBlack
    lbl.TextStrokeTransparency = 0.15
    lbl.TextStrokeColor3 = Color3.fromRGB(0,0,0)
    lbl.ZIndex = 20; lbl.Text = ""
    for k,v in pairs(props or {}) do lbl[k] = v end
    if not useShadow then return { Main = lbl, Shadow = nil } end
    local sh = lbl:Clone()
    sh.Name = name.."_Shadow"; sh.TextColor3 = Color3.fromRGB(0,0,0)
    sh.TextTransparency = 0.25; sh.TextStrokeTransparency = 1
    sh.Position = lbl.Position + UDim2.fromOffset(2, 2)
    sh.ZIndex = lbl.ZIndex - 1; sh.Parent = parent
    return { Main = lbl, Shadow = sh }
end
local function setPairText(p, t) p.Main.Text = t; if p.Shadow then p.Shadow.Text = t end end
local function setPairVisible(p, v) p.Main.Visible = v; if p.Shadow then p.Shadow.Visible = v end end
local function setPairPos(p, pos) p.Main.Position = pos; if p.Shadow then p.Shadow.Position = pos + UDim2.fromOffset(2,2) end end

local DEFAULT = {
    Name = "OverdexHUD", DimAlpha = 0, CenterY = 0.62,
    ScaleMin = 0.70, ScaleMax = 1.20, Shadow = false,
    Title  = { Text = "Overdex - Kaitun", Color = {70,255,90}, Size = 60, Y = 0.10 },
    Status = { Text = "Status: ...", Color = {255,170,40}, Size = 40, Y = 0.20 },
    Timer  = { Size = 30, Y = 0.40, Enable = true },
    Lines  = { Info1 = { Size = 30, Y = 0.50 } },
    DefaultText = {},
}
local function newHUD(userConfig)
    local cfgH = table.clone(DEFAULT)
    for k, v in pairs(userConfig or {}) do
        if type(v) == "table" and type(cfgH[k]) == "table" then
            for kk, vv in pairs(v) do cfgH[k][kk] = vv end
        else cfgH[k] = v end
    end
    if userConfig and userConfig.Lines ~= nil then cfgH.Lines = userConfig.Lines end
    if userConfig and userConfig.DefaultText ~= nil then cfgH.DefaultText = userConfig.DefaultText end

    local PG = LocalPlayer:WaitForChild("PlayerGui")
    pcall(function() local old = PG:FindFirstChild(cfgH.Name); if old then old:Destroy() end end)

    local gui = Instance.new("ScreenGui")
    gui.Name = cfgH.Name; gui.IgnoreGuiInset = true
    gui.ResetOnSpawn = false; gui.DisplayOrder = 999999
    gui.ZIndexBehavior = Enum.ZIndexBehavior.Sibling; gui.Parent = PG

    local dim = Instance.new("Frame")
    dim.Size = UDim2.fromScale(1,1); dim.BackgroundColor3 = Color3.fromRGB(0,0,0)
    dim.BackgroundTransparency = cfgH.DimAlpha; dim.BorderSizePixel = 0; dim.Parent = gui

    local root = Instance.new("Frame")
    root.Size = UDim2.fromScale(1,1); root.BackgroundTransparency = 1; root.Parent = gui

    local group = Instance.new("Frame")
    group.AnchorPoint = Vector2.new(0.5, 0.5)
    group.Position = UDim2.fromScale(0.5, cfgH.CenterY)
    group.Size = UDim2.fromOffset(1100, 520)
    group.BackgroundTransparency = 1; group.Parent = root

    local uiScale = Instance.new("UIScale"); uiScale.Parent = group
    local function updateScale()
        local cam = workspace.CurrentCamera; if not cam then return end
        local vp = cam.ViewportSize
        uiScale.Scale = clamp(math.min(vp.X/1400, vp.Y/800), cfgH.ScaleMin, cfgH.ScaleMax)
    end
    updateScale()
    local scaleConn = RunService.RenderStepped:Connect(updateScale)

    local title = mkLabel(group, "Title", {
        AnchorPoint = Vector2.new(0.5,0),
        Position = UDim2.fromScale(0.5, cfgH.Title.Y),
        Size = UDim2.fromOffset(1100, 70),
        TextSize = cfgH.Title.Size,
    }, cfgH.Shadow)
    setPairText(title, rich(cfgH.Title.Text, rgb(cfgH.Title.Color)))

    local status = mkLabel(group, "Status", {
        AnchorPoint = Vector2.new(0.5,0),
        Position = UDim2.fromScale(0.5, cfgH.Status.Y),
        Size = UDim2.fromOffset(1100, 70),
        TextSize = cfgH.Status.Size,
    }, cfgH.Shadow)
    setPairText(status, rich(cfgH.Status.Text, rgb(cfgH.Status.Color)))

    local timer = mkLabel(group, "Timer", {
        AnchorPoint = Vector2.new(0.5,0),
        Position = UDim2.fromScale(0.5, cfgH.Timer.Y),
        Size = UDim2.fromOffset(1100, 60),
        TextSize = cfgH.Timer.Size,
        TextColor3 = Color3.fromRGB(255,255,255),
    }, cfgH.Shadow)
    timer.Main.RichText = false
    if timer.Shadow then timer.Shadow.RichText = false end
    setPairText(timer, "0 Hours, 0 Minutes, 0 Seconds")
    setPairVisible(timer, cfgH.Timer.Enable ~= false)

    local lines = {}
    local function ensureLine(key)
        local lc = cfgH.Lines[key]; if not lc then return nil end
        if not lines[key] then
            lines[key] = mkLabel(group, key, {
                AnchorPoint = Vector2.new(0.5,0),
                Position = UDim2.fromScale(0.5, lc.Y),
                Size = UDim2.fromOffset(1100, 55),
                TextSize = lc.Size,
                TextColor3 = Color3.fromRGB(255,255,255),
                Text = "",
            }, cfgH.Shadow)
            setPairVisible(lines[key], false)
        end
        setPairPos(lines[key], UDim2.fromScale(0.5, lc.Y))
        lines[key].Main.TextSize = lc.Size
        if lines[key].Shadow then lines[key].Shadow.TextSize = lc.Size end
        return lines[key]
    end
    for key in pairs(cfgH.Lines) do ensureLine(key) end
    for key, parts in pairs(cfgH.DefaultText or {}) do
        local p = ensureLine(key)
        if p then setPairText(p, richJoin(parts)); setPairVisible(p, true) end
    end

    local t0 = os.clock()
    if timer.Main.Visible then
        RunService.RenderStepped:Connect(function()
            local txt = fmtTime(os.clock() - t0)
            timer.Main.Text = txt
            if timer.Shadow then timer.Shadow.Text = txt end
        end)
    end

    local HUD = {}
    function HUD:SetTitle(text, colorRGB)
        if text ~= nil then cfgH.Title.Text = text end
        if colorRGB then cfgH.Title.Color = colorRGB end
        setPairText(title, rich(cfgH.Title.Text, rgb(cfgH.Title.Color)))
    end
    function HUD:SetStatus(text, colorRGB)
        if text ~= nil then cfgH.Status.Text = text end
        if colorRGB then cfgH.Status.Color = colorRGB end
        setPairText(status, rich(cfgH.Status.Text, rgb(cfgH.Status.Color)))
    end
    function HUD:SetLineParts(key, parts)
        local p = ensureLine(key)
        if p then setPairText(p, richJoin(parts)); setPairVisible(p, true) end
    end
    function HUD:Destroy()
        pcall(function() scaleConn:Disconnect() end)
        pcall(function() gui:Destroy() end)
    end
    return HUD
end

--==================================================================
-- HUD INIT
--==================================================================
local HUD = newHUD({
    Name = "1THANGNGU_MM2_KAITUN",
    DimAlpha = 0, CenterY = 0.50, Shadow = false,
    Title  = { Text = "1THANGNGU - MM2 KAITUN", Color = {255,118,20}, Size = 40, Y = 0.05 },
    Status = { Text = "Status: Đang khởi động...", Color = {255,170,40}, Size = 26, Y = 0.13 },
    Timer  = { Size = 20, Y = 0.21, Enable = true },
    Lines  = {
        Coins   = { Size = 20, Y = 0.29 },
        Server  = { Size = 20, Y = 0.36 },
        Crates  = { Size = 20, Y = 0.43 },
        Extra   = { Size = 20, Y = 0.50 },
        Discord = { Size = 16, Y = 0.98 },
    },
    DefaultText = {
        Discord = { {"discord.gg/", {255,255,255}}, {"DarM5yD9Xh", {255,118,20}} },
    },
})

--==================================================================
-- STATUS OVERRIDE
--==================================================================
local statusOverrideUntil = 0
local function setStatus(text, color)
    if os.clock() < statusOverrideUntil then return end
    HUD:SetStatus("Status: " .. text, color or {255,170,40})
end
local function flashStatus(text, color, duration)
    statusOverrideUntil = os.clock() + (duration or cfg.cycleFlashDur)
    HUD:SetStatus("Status: " .. text, color or {255,170,40})
end

--==================================================================
-- REFRESH HUD
--==================================================================
local function refreshStats()
    HUD:SetLineParts("Coins", {
        {"Coins: ", {255,255,255}}, {tostring(stats.coins), {255,118,20}},
        {"  Cycle: ", {255,255,255}}, {stats.cycleCoins.."/"..cfg.coinCycle, {70,255,90}},
        {"  x", {255,255,255}}, {tostring(stats.cycles), {255,176,64}},
    })
    HUD:SetLineParts("Server", {
        {"Server: ", {255,255,255}}, {string.sub(game.JobId,1,8), {70,255,90}},
        {"  Hops: ", {255,255,255}}, {tostring(stats.hops), {70,255,90}},
    })
    HUD:SetLineParts("Crates", {
        {"Crates: ", {255,255,255}}, {tostring(stats.cratesOpened), {255,190,55}},
        {"  Err: ", {255,255,255}}, {tostring(stats.crateErrors), {255,80,80}},
    })
    HUD:SetLineParts("Extra", {
        {"FPS: ", {255,255,255}}, {tostring(cfg.fpsCap), {255,190,55}},
    })
end
task.spawn(function() while task.wait(0.5) do refreshStats() end end)

--==================================================================
-- WEBHOOK SENDER
--==================================================================
local function sendWebhook(url, title, desc, color, fields, mention)
    if not url or url == "" or url == "DÁN_LINK_WEBHOOK_ROLL_VÀO_ĐÂY" or url == "DÁN_LINK_WEBHOOK_COIN_VÀO_ĐÂY" then return end
    local body = {
        username = "1THANGNGU - MM2 KAITUN", content = mention,
        embeds = {{
            title = title, description = desc, color = color or 0xFF7620,
            timestamp = DateTime.now():ToIsoDate(),
            footer = { text = "JobId: "..string.sub(game.JobId,1,8).." · "..LocalPlayer.Name },
            fields = fields,
        }},
    }
    pcall(function()
        local req = request or (syn and syn.request) or (http and http.request) or http_request
        if not req then return end
        req({ Url = url, Method = "POST",
              Headers = { ["Content-Type"] = "application/json" },
              Body = HttpService:JSONEncode(body) })
    end)
end

--==================================================================
-- COIN COLLECTED + CYCLE
--==================================================================
local lastCoinMilestone = 0

local function handleCoinCollected(_, current)
    if typeof(current) == "number" then
        if current < stats.lastCoinInRound then
            stats.lastCoinInRound = 0
            stats.cycleCoins = 0
        end
        
        local diff = current - stats.lastCoinInRound
        if diff > 0 then
            stats.coins        += diff
            stats.sessionCoins += diff
            stats.cycleCoins   += diff
        end
        stats.lastCoinInRound = current
    else
        stats.coins        += 1
        stats.sessionCoins += 1
        stats.cycleCoins   += 1
    end

    if stats.cycleCoins >= cfg.coinCycle then
        stats.cycleCoins = 0
        stats.cycles     += 1
        cycleReset = true
        flashStatus(
            string.format("✅ Đủ %d coin! Reset nhân vật chờ round mới (x%d)",
                cfg.coinCycle, stats.cycles),
            {70,255,90}, cfg.cycleFlashDur)
    end

    if WH_COIN.enabled then
        local m = math.floor(stats.coins / WH_COIN.step) * WH_COIN.step
        if m > 0 and m > lastCoinMilestone then
            lastCoinMilestone = m
            sendWebhook(WH_COIN.url,
                "💰 Coin Milestone: "..m,
                "Tổng coin session: **"..stats.coins.."**", 0x46FF5A,
                { { name="Server", value="`"..string.sub(game.JobId,1,8).."`", inline=true },
                  { name="Hops",   value="`"..stats.hops.."`", inline=true },
                  { name="Cycles", value="`"..stats.cycles.."`", inline=true } })
        end
    end
end

--==================================================================
-- ROLL SCANNER
--==================================================================
local seenItems = {}
local function fetchInventoryRaw()
    local remotes = ReplicatedStorage:FindFirstChild("Remotes")
    if remotes then
        for _, n in ipairs({"GetInventory","GetInv","GetItems","Inventory","FetchInv"}) do
            local r = remotes:FindFirstChild(n, true)
            if r and r:IsA("RemoteFunction") then
                local ok, res = pcall(function() return r:InvokeServer() end)
                if ok and type(res) == "table" then return res end
            end
        end
    end
    for _, path in ipairs({{"Inventory"},{"Data","Inventory"},{"PlayerData","Inventory"}}) do
        local obj, ok = LocalPlayer, true
        for _, seg in ipairs(path) do
            obj = obj:FindFirstChild(seg)
            if not obj then ok = false; break end
        end
        if ok and obj then
            local arr = {}
            for _, ch in ipairs(obj:GetChildren()) do
                local rar = ch:FindFirstChild("Rarity")
                if rar then arr[#arr+1] = { name=ch.Name, rarity=rar.Value or rar.Name, uid=ch.Name } end
            end
            if #arr > 0 then return arr end
        end
    end
    return {}
end
local function normalizeItems(raw)
    local out = {}
    if type(raw) ~= "table" then return out end
    for k, v in pairs(raw) do
        if type(v) == "table" then
            out[#out+1] = {
                name = v.name or v.Name or v.ItemName or tostring(k),
                rarity = v.rarity or v.Rarity or v.RarityName or "Common",
                uid = v.uid or v.UUID or (tostring(k).."|"..tostring(v.name or v.Name)),
            }
        elseif type(v) == "string" then
            out[#out+1] = { name=v, rarity="Common", uid=tostring(k).."|"..v }
        end
    end
    return out
end
task.spawn(function()
    if not WH_ROLL.enabled or WH_ROLL.url == "" or WH_ROLL.url == "DÁN_LINK_WEBHOOK_ROLL_VÀO_ĐÂY" then return end
    task.wait(3)
    for _, it in ipairs(normalizeItems(fetchInventoryRaw())) do seenItems[it.uid] = true end
    while task.wait(5) do
        for _, it in ipairs(normalizeItems(fetchInventoryRaw())) do
            if not seenItems[it.uid] then
                seenItems[it.uid] = true
                if table.find(WH_ROLL.rarities, it.rarity) then
                    sendWebhook(WH_ROLL.url, "🎲 Roll: "..it.name,
                        "Rarity: **"..it.rarity.."**", 0xFF5050,
                        { { name="Server", value="`"..string.sub(game.JobId,1,8).."`", inline=true },
                          { name="Player", value="`"..LocalPlayer.Name.."`", inline=true } })
                end
            end
        end
    end
end)

--==================================================================
-- LAG FIX
--==================================================================
local function applyLagFix()
    if not cfg.lagFix then return end
    setStatus("Đang bật lag fix...", {255,80,80})
    task.wait(0.1)
    pcall(function() if setfpscap then setfpscap(cfg.fpsCap) end end)
    pcall(function() settings().Rendering.QualityLevel = Enum.QualityLevel.Level01 end)
    pcall(function()
        UserSettings():GetService("UserGameSettings").SavedQualityLevel =
            Enum.SavedQualitySetting.QualityLevel1
    end)
    pcall(function()
        for _, t in ipairs({Enum.CoreGuiType.PlayerList, Enum.CoreGuiType.Health,
            Enum.CoreGuiType.Backpack, Enum.CoreGuiType.EmotesMenu}) do
            StarterGui:SetCoreGuiEnabled(t, false)
        end
    end)
    task.spawn(function()
        for _, v in ipairs(workspace:GetDescendants()) do
            pcall(function()
                if v:IsA("ParticleEmitter") or v:IsA("Smoke") or v:IsA("Fire")
                or v:IsA("Sparkles") or v:IsA("Beam") or v:IsA("Trail")
                or v:IsA("PointLight") or v:IsA("SpotLight") or v:IsA("SurfaceLight") then
                    v.Enabled = false
                elseif v:IsA("Sound") then v.Volume = 0; v.Playing = false end
            end)
        end
    end)
end
task.spawn(function() while task.wait(30) do pcall(function() collectgarbage("collect") end) end end)

--==================================================================
-- ANTI AFK
--==================================================================
LocalPlayer.Idled:Connect(function()
    if cfg.antiAFK then
        pcall(function()
            VirtualUser:CaptureController()
            VirtualUser:ClickButton2(Vector2.new())
        end)
    end
end)

--==================================================================
-- AUTO HOP
--==================================================================
local lastHopAt = 0
local function hopServer(reason)
    if os.clock() - lastHopAt < 15 then return end
    lastHopAt = os.clock()
    stats.hops += 1
    setStatus("Đổi server: "..tostring(reason), {255,80,80})
    pcall(function()
        local servers = {}
        pcall(function()
            local url = "https://games.roblox.com/v1/games/"..game.PlaceId..
                "/servers/Public?sortOrder=Asc&limit=100"
            local data = HttpService:JSONDecode(game:HttpGet(url))
            if data and data.data then servers = data.data end
        end)
        local cands = {}
        for _, s in ipairs(servers) do
            if s.id and s.id ~= game.JobId then
                local p  = tonumber(s.playing) or 0
                local mx = tonumber(s.maxPlayers) or 100
                if p < mx then table.insert(cands, s) end
            end
        end
        if #cands > 0 then
            TeleportService:TeleportToPlaceInstance(game.PlaceId,
                cands[math.random(1, #cands)].id, LocalPlayer)
        else
            TeleportService:Teleport(game.PlaceId, LocalPlayer)
        end
    end)
    task.wait(2)
    stats.sessionStart = os.clock()
    stats.sessionCoins = stats.coins
end
if cfg.autoHop then
    task.spawn(function()
        while task.wait(5) do
            local el = os.clock() - stats.sessionStart
            if el >= cfg.hopWindow then
                local gained = stats.coins - stats.sessionCoins
                if gained < cfg.hopMinCoins then
                    hopServer(string.format("%d coins/%dmin", gained, math.floor(el/60)))
                else
                    stats.sessionStart = os.clock()
                    stats.sessionCoins = stats.coins
                end
            end
        end
    end)
end

--==================================================================
-- AUTO CRATE (Mở hòm theo Config)
--==================================================================
local function findCrateRemote()
    return ReplicatedStorage:FindFirstChild("OpenCrate", true)
        or ReplicatedStorage:FindFirstChild("BuyCrate", true)
end

if cfg_crate.enabled then
    task.spawn(function()
        local remote
        for _ = 1, 30 do remote = findCrateRemote(); if remote then break end; task.wait(0.5) end
        while true do
            remote = findCrateRemote()
            if remote and remote:IsA("RemoteFunction") then
                setStatus("Spam mở hòm ("..cfg_crate.burstTime.."s)...", {255,190,55})
                local tEnd = os.clock() + cfg_crate.burstTime
                while os.clock() < tEnd do
                    for _, key in ipairs(cfg_crate.keys) do
                        local ok = pcall(function() remote:InvokeServer(cfg_crate.boxName, cfg_crate.category, key) end)
                        if ok then stats.cratesOpened += 1 else stats.crateErrors += 1 end
                        task.wait(cfg_crate.spamStep)
                    end
                end
            else
                setStatus("Không thấy OpenCrate remote, chờ...", {255,80,80})
            end
            setStatus(string.format("Crate nghỉ %d phút...", math.floor(cfg_crate.interval/60)),
                {255,170,40})
            task.wait(cfg_crate.interval)
        end
    end)
end

--==================================================================
-- ROUND STATE
--==================================================================
local function isAlive()
    local char = LocalPlayer.Character
    if not char then return false end
    local hum = char:FindFirstChild("Humanoid")
    return hum and hum.Health > 0
end

task.spawn(function()
    local gp = ReplicatedStorage:WaitForChild("Remotes", 30); if not gp then return end
    gp = gp:WaitForChild("Gameplay", 10); if not gp then return end
    local coinEv  = gp:WaitForChild("CoinCollected", 10)
    local startEv = gp:WaitForChild("RoundStart", 10)
    local endEv   = gp:WaitForChild("RoundEndFade", 10)

    if coinEv then
        coinEv.OnClientEvent:Connect(function(...) handleCoinCollected(...) end)
    end

    if startEv then
        startEv.OnClientEvent:Connect(function()
            roundActive = true
            waitingForNewRound = false
            stats.cycleCoins = 0
            stats.lastCoinInRound = 0
        end)
    end

    if endEv then
        endEv.OnClientEvent:Connect(function()
            roundActive = false
            stats.cycleCoins = 0
            stats.lastCoinInRound = 0
        end)
    end
end)

--==================================================================
-- SPIN BOT
--==================================================================
RunService.RenderStepped:Connect(function(dt)
    if cfg.spinBot and not isTweening and isAlive() then
        local char = LocalPlayer.Character
        local hrp = char and char:FindFirstChild("HumanoidRootPart")
        if hrp then
            hrp.CFrame = hrp.CFrame * CFrame.Angles(0, math.rad(cfg.spinSpeed) * dt, 0)
        end
    end
end)

--==================================================================
-- FARM LOOP
--==================================================================
local function getNearestCoin()
    local char = LocalPlayer.Character
    local hrp = char and char:FindFirstChild("HumanoidRootPart")
    if not hrp then return nil end
    
    if not cachedContainer or not cachedContainer.Parent then
        cachedContainer = nil
        for _, m in ipairs(workspace:GetChildren()) do
            local c = m:FindFirstChild("CoinContainer")
            if c then
                cachedContainer = c
                break
            end
        end
    end
    
    if not cachedContainer then return nil end
    
    local myPos = hrp.Position
    local best, bestDist = nil, math.huge
    local hasFarCoin = false
    
    for _, coin in ipairs(cachedContainer:GetChildren()) do
        if coin:IsA("BasePart") and coin:FindFirstChild("TouchInterest") then
            local d = (myPos - coin.Position).Magnitude
            if d > cfg.maxFarmDist then
                hasFarCoin = true
            elseif d < bestDist then
                best, bestDist = coin, d
            end
        end
    end
    
    return best, bestDist, hasFarCoin
end

task.spawn(function()
    while true do
        if cycleReset then
            cycleReset = false
            waitingForNewRound = true
            local char = LocalPlayer.Character
            local hum = char and char:FindFirstChild("Humanoid")
            if hum and hum.Health > 0 then
                hum.Health = 0 
            end
            setStatus("Đã đủ 50 coin, chờ round mới...", {255,80,80})
        end

        if waitingForNewRound then
            setStatus("Chờ round mới (đã reset nhân vật)...", {255,170,40})
            task.wait(0.5)
        elseif cfg.autoFarm and isAlive() then
            local coin, dist, hasFarCoin = getNearestCoin()
            if coin then
                local char = LocalPlayer.Character
                local hrp = char and char:FindFirstChild("HumanoidRootPart")
                if hrp then
                    roundActive = true
                    isTweening = true
                    
                    if dist <= 15 then
                        setStatus(string.format("TP Farm (%.0f studs)", dist), {255,190,55})
                        hrp.CFrame = coin.CFrame
                        task.wait(0.1)
                    else
                        setStatus(string.format("Tween Farm (%.0f studs)", dist), {70,255,90})
                        local t = TweenService:Create(
                            hrp,
                            TweenInfo.new((dist or 10) / math.max(cfg.farmSpeed, 1), Enum.EasingStyle.Linear),
                            { CFrame = coin.CFrame }
                        )
                        t:Play()
                        t.Completed:Wait()
                        t:Cancel()
                    end
                    
                    isTweening = false
                    task.wait(cfg.collectDelay)
                end
            elseif hasFarCoin then
                setStatus("IDLE", {255,170,40})
            else
                setStatus(roundActive and "Chờ coin xuất hiện..." or "Chờ round mới...", {255,170,40})
            end
        else
            if not cfg.autoFarm then
                setStatus("Farm tắt", {255,80,80})
            elseif not isAlive() then
                setStatus("Đang chờ hồi sinh...", {255,80,80})
            end
            task.wait(0.5)
        end
        task.wait(0.1)
    end
end)

--==================================================================
-- BOOT
--==================================================================
applyLagFix()
refreshStats()
setStatus("Sẵn sàng!", {70,255,90})

if WH_ROLL.url ~= "" or WH_COIN.url ~= "" then
    sendWebhook(WH_ROLL.url ~= "" and WH_ROLL.url or WH_COIN.url,
        "✅ Script Started",
        "Player: `"..LocalPlayer.Name.."`\nPlace: `"..game.PlaceId.."`\nJobId: `"..string.sub(game.JobId,1,8).."`",
        0x46FF5A,
        { { name="Farm",  value="`ON`", inline=true },
          { name="Hop",   value=cfg.autoHop and "`ON`" or "`OFF`", inline=true },
          { name="Crate", value=cfg_crate.enabled and "`ON`" or "`OFF`", inline=true } })
end
