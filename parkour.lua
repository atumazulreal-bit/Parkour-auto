-- ╔══════════════════════════════════════════════════════╗
-- ║         PARKOUR RECORDER v2 - Corrigido             ║
-- ║  LocalScript > StarterPlayer > StarterPlayerScripts ║
-- ╚══════════════════════════════════════════════════════╝

-- Aguarda o jogo carregar completamente
if not game:IsLoaded() then
    game.Loaded:Wait()
end

local Players         = game:GetService("Players")
local RunService      = game:GetService("RunService")
local UserInputService = game:GetService("UserInputService")
local TweenService    = game:GetService("TweenService")
local PathfindingService = game:GetService("PathfindingService")

-- Aguarda o player e personagem
local player = Players.LocalPlayer
local character = player.Character or player.CharacterAdded:Wait()

-- Aguarda partes do personagem com timeout seguro
local function waitForChild(parent, name, timeout)
    local t = timeout or 10
    local start = tick()
    while not parent:FindFirstChild(name) do
        if tick() - start > t then
            warn("[ParkourRecorder] Timeout esperando: " .. name)
            return nil
        end
        task.wait(0.05)
    end
    return parent[name]
end

local humanoid = waitForChild(character, "Humanoid")
local rootPart = waitForChild(character, "HumanoidRootPart")

if not humanoid or not rootPart then
    warn("[ParkourRecorder] ERRO: Personagem não encontrado. Verifique se é um LocalScript!")
    return
end

-- ══════════════════════════════════════
--   Persistência via _G (dura a sessão)
-- ══════════════════════════════════════
if not _G.PR_Recordings then _G.PR_Recordings = {} end
if not _G.PR_StartPoints then _G.PR_StartPoints = {} end

local recordings  = _G.PR_Recordings
local startPoints = _G.PR_StartPoints

-- ══════════════════════════════════════
--            ESTADO GLOBAL
-- ══════════════════════════════════════
local isRecording        = false
local isReplaying        = false
local isWalkingToParkour = false
local currentFrames      = {}
local recName            = "Parkour_1"
local RECORD_INTERVAL    = 0.1
local selectedIndex      = nil
local replayConn         = nil
local walkConn           = nil
local frameTimer         = 0
local blinkConn          = nil

-- ══════════════════════════════════════
--         CRIAR GUI NO COREGUI
-- ══════════════════════════════════════
local CoreGui = game:GetService("CoreGui")

-- Remove instância antiga
local old = CoreGui:FindFirstChild("PRGui")
if old then old:Destroy() end

local ScreenGui = Instance.new("ScreenGui")
ScreenGui.Name              = "PRGui"
ScreenGui.ResetOnSpawn      = false
ScreenGui.ZIndexBehavior    = Enum.ZIndexBehavior.Sibling
ScreenGui.IgnoreGuiInset    = true
ScreenGui.Parent            = CoreGui

-- ──────────────────────────────────────
-- Painel principal
-- ──────────────────────────────────────
local Panel = Instance.new("Frame")
Panel.Name              = "Panel"
Panel.Size              = UDim2.new(0, 270, 0, 510)
Panel.Position          = UDim2.new(0, 12, 0.5, -255)
Panel.BackgroundColor3  = Color3.fromRGB(12, 12, 22)
Panel.BorderSizePixel   = 0
Panel.ClipsDescendants  = true
Panel.Parent            = ScreenGui

Instance.new("UICorner", Panel).CornerRadius = UDim.new(0, 14)

local panelStroke = Instance.new("UIStroke", Panel)
panelStroke.Color       = Color3.fromRGB(0, 180, 255)
panelStroke.Thickness   = 1.5
panelStroke.Transparency = 0.3

-- ──────────────────────────────────────
-- Header
-- ──────────────────────────────────────
local Header = Instance.new("Frame", Panel)
Header.Size             = UDim2.new(1, 0, 0, 48)
Header.BackgroundColor3 = Color3.fromRGB(0, 140, 220)
Header.BorderSizePixel  = 0

local hCorner = Instance.new("UICorner", Header)
hCorner.CornerRadius = UDim.new(0, 14)

-- Corrige cantos inferiores do header
local hFix = Instance.new("Frame", Header)
hFix.Size            = UDim2.new(1, 0, 0, 14)
hFix.Position        = UDim2.new(0, 0, 1, -14)
hFix.BackgroundColor3 = Color3.fromRGB(0, 140, 220)
hFix.BorderSizePixel = 0

local hGrad = Instance.new("UIGradient", Header)
hGrad.Color    = ColorSequence.new(Color3.fromRGB(0, 200, 255), Color3.fromRGB(100, 0, 220))
hGrad.Rotation = 90

local hGrad2 = Instance.new("UIGradient", hFix)
hGrad2.Color    = ColorSequence.new(Color3.fromRGB(0, 200, 255), Color3.fromRGB(100, 0, 220))
hGrad2.Rotation = 90

local TitleLbl = Instance.new("TextLabel", Header)
TitleLbl.Size              = UDim2.new(1, -50, 1, 0)
TitleLbl.Position          = UDim2.new(0, 12, 0, 0)
TitleLbl.BackgroundTransparency = 1
TitleLbl.Text              = "⬡ PARKOUR RECORDER"
TitleLbl.TextColor3        = Color3.fromRGB(255, 255, 255)
TitleLbl.TextSize          = 14
TitleLbl.Font              = Enum.Font.GothamBold
TitleLbl.TextXAlignment    = Enum.TextXAlignment.Left

local MinBtn = Instance.new("TextButton", Header)
MinBtn.Size              = UDim2.new(0, 30, 0, 30)
MinBtn.Position          = UDim2.new(1, -40, 0.5, -15)
MinBtn.BackgroundColor3  = Color3.fromRGB(255, 255, 255)
MinBtn.BackgroundTransparency = 0.75
MinBtn.Text              = "—"
MinBtn.TextColor3        = Color3.fromRGB(255, 255, 255)
MinBtn.TextSize          = 13
MinBtn.Font              = Enum.Font.GothamBold
MinBtn.BorderSizePixel   = 0
Instance.new("UICorner", MinBtn).CornerRadius = UDim.new(0, 8)

-- ──────────────────────────────────────
-- Área de conteúdo com scroll
-- ──────────────────────────────────────
local Content = Instance.new("Frame", Panel)
Content.Name             = "Content"
Content.Size             = UDim2.new(1, 0, 1, -48)
Content.Position         = UDim2.new(0, 0, 0, 48)
Content.BackgroundTransparency = 1

local cLayout = Instance.new("UIListLayout", Content)
cLayout.SortOrder = Enum.SortOrder.LayoutOrder
cLayout.Padding   = UDim.new(0, 7)

local cPad = Instance.new("UIPadding", Content)
cPad.PaddingLeft   = UDim.new(0, 10)
cPad.PaddingRight  = UDim.new(0, 10)
cPad.PaddingTop    = UDim.new(0, 10)
cPad.PaddingBottom = UDim.new(0, 8)

-- ──────────────────────────────────────
-- Helpers
-- ──────────────────────────────────────
local function secLabel(txt, order)
    local l = Instance.new("TextLabel", Content)
    l.Size              = UDim2.new(1, 0, 0, 16)
    l.BackgroundTransparency = 1
    l.Text              = txt
    l.TextColor3        = Color3.fromRGB(0, 200, 255)
    l.TextSize          = 10
    l.Font              = Enum.Font.GothamBold
    l.TextXAlignment    = Enum.TextXAlignment.Left
    l.LayoutOrder       = order
    return l
end

local function makeBtn(txt, c1, c2, order)
    local b = Instance.new("TextButton", Content)
    b.Size             = UDim2.new(1, 0, 0, 38)
    b.BackgroundColor3 = c1
    b.BorderSizePixel  = 0
    b.Text             = ""
    b.AutoButtonColor  = false
    b.LayoutOrder      = order

    Instance.new("UICorner", b).CornerRadius = UDim.new(0, 10)

    local g = Instance.new("UIGradient", b)
    g.Color    = ColorSequence.new(c1, c2)
    g.Rotation = 90

    local lbl = Instance.new("TextLabel", b)
    lbl.Size              = UDim2.new(1, 0, 1, 0)
    lbl.BackgroundTransparency = 1
    lbl.Text              = txt
    lbl.TextColor3        = Color3.fromRGB(255, 255, 255)
    lbl.TextSize          = 12
    lbl.Font              = Enum.Font.GothamBold

    b.MouseEnter:Connect(function()
        TweenService:Create(b, TweenInfo.new(0.12), {BackgroundTransparency = 0.2}):Play()
    end)
    b.MouseLeave:Connect(function()
        TweenService:Create(b, TweenInfo.new(0.12), {BackgroundTransparency = 0}):Play()
    end)

    return b, lbl
end

-- ──────────────────────────────────────
-- Status bar
-- ──────────────────────────────────────
local StatusBar = Instance.new("TextLabel", Content)
StatusBar.Size             = UDim2.new(1, 0, 0, 26)
StatusBar.BackgroundColor3 = Color3.fromRGB(18, 18, 32)
StatusBar.TextColor3       = Color3.fromRGB(150, 255, 180)
StatusBar.Text             = "● Pronto"
StatusBar.TextSize         = 11
StatusBar.Font             = Enum.Font.Gotham
StatusBar.LayoutOrder      = 1
StatusBar.BorderSizePixel  = 0
Instance.new("UICorner", StatusBar).CornerRadius = UDim.new(0, 8)

local function setStatus(msg, color)
    StatusBar.Text       = msg
    StatusBar.TextColor3 = color or Color3.fromRGB(150, 255, 180)
    StatusBar.TextTransparency = 0
end

-- ──────────────────────────────────────
-- Seção Gravação
-- ──────────────────────────────────────
secLabel("── GRAVAÇÃO ─────────────────", 2)

local RecBtn, RecLbl = makeBtn("⬤  Iniciar Gravação",
    Color3.fromRGB(200, 30, 30), Color3.fromRGB(130, 0, 50), 3)

local NameBox = Instance.new("TextBox", Content)
NameBox.Size              = UDim2.new(1, 0, 0, 32)
NameBox.BackgroundColor3  = Color3.fromRGB(18, 18, 32)
NameBox.TextColor3        = Color3.fromRGB(230, 230, 255)
NameBox.PlaceholderText   = "Nome da gravação..."
NameBox.PlaceholderColor3 = Color3.fromRGB(90, 90, 120)
NameBox.Text              = "Parkour_1"
NameBox.TextSize          = 12
NameBox.Font              = Enum.Font.Gotham
NameBox.LayoutOrder       = 4
NameBox.BorderSizePixel   = 0
NameBox.ClearTextOnFocus  = false
Instance.new("UICorner", NameBox).CornerRadius = UDim.new(0, 8)
local nbStroke = Instance.new("UIStroke", NameBox)
nbStroke.Color = Color3.fromRGB(0, 180, 255)
nbStroke.Thickness = 1
nbStroke.Transparency = 0.65
local nbPad = Instance.new("UIPadding", NameBox)
nbPad.PaddingLeft = UDim.new(0, 8)

-- ──────────────────────────────────────
-- Seção Parkour
-- ──────────────────────────────────────
secLabel("── PARKOUR ───────────────────", 5)

local ParkBtn, ParkLbl = makeBtn("▶  Iniciar Parkour",
    Color3.fromRGB(0, 140, 240), Color3.fromRGB(80, 0, 200), 6)

-- ──────────────────────────────────────
-- Seção Lista
-- ──────────────────────────────────────
secLabel("── GRAVAÇÕES SALVAS ──────────", 7)

local ListFrame = Instance.new("Frame", Content)
ListFrame.Size             = UDim2.new(1, 0, 0, 110)
ListFrame.BackgroundColor3 = Color3.fromRGB(14, 14, 26)
ListFrame.BorderSizePixel  = 0
ListFrame.ClipsDescendants = true
ListFrame.LayoutOrder      = 8
Instance.new("UICorner", ListFrame).CornerRadius = UDim.new(0, 10)
local lStroke = Instance.new("UIStroke", ListFrame)
lStroke.Color = Color3.fromRGB(0, 180, 255)
lStroke.Thickness = 1
lStroke.Transparency = 0.65

local Scroll = Instance.new("ScrollingFrame", ListFrame)
Scroll.Size                  = UDim2.new(1, -6, 1, -6)
Scroll.Position              = UDim2.new(0, 3, 0, 3)
Scroll.BackgroundTransparency = 1
Scroll.BorderSizePixel       = 0
Scroll.ScrollBarThickness    = 3
Scroll.ScrollBarImageColor3  = Color3.fromRGB(0, 180, 255)
Scroll.CanvasSize            = UDim2.new(0, 0, 0, 0)
Scroll.AutomaticCanvasSize   = Enum.AutomaticSize.Y

local sLayout = Instance.new("UIListLayout", Scroll)
sLayout.SortOrder = Enum.SortOrder.LayoutOrder
sLayout.Padding   = UDim.new(0, 3)

local sPad = Instance.new("UIPadding", Scroll)
sPad.PaddingLeft   = UDim.new(0, 3)
sPad.PaddingRight  = UDim.new(0, 3)
sPad.PaddingTop    = UDim.new(0, 2)

-- ──────────────────────────────────────
-- Seção Reprodução
-- ──────────────────────────────────────
secLabel("── REPRODUÇÃO ────────────────", 9)

local RepBtn, RepLbl = makeBtn("▷  Reproduzir Selecionada",
    Color3.fromRGB(0, 180, 90), Color3.fromRGB(0, 100, 50), 10)

local DelBtn, DelLbl = makeBtn("✕  Excluir Selecionada",
    Color3.fromRGB(170, 50, 50), Color3.fromRGB(90, 15, 15), 11)

-- ══════════════════════════════════════
--         ATUALIZAR LISTA
-- ══════════════════════════════════════
local function refreshList()
    for _, c in ipairs(Scroll:GetChildren()) do
        if not c:IsA("UIListLayout") and not c:IsA("UIPadding") then
            c:Destroy()
        end
    end

    if #recordings == 0 then
        local empty = Instance.new("TextLabel", Scroll)
        empty.Size              = UDim2.new(1, 0, 0, 28)
        empty.BackgroundTransparency = 1
        empty.Text              = "Nenhuma gravação salva"
        empty.TextColor3        = Color3.fromRGB(70, 70, 90)
        empty.TextSize          = 11
        empty.Font              = Enum.Font.Gotham
        empty.LayoutOrder       = 1
        return
    end

    for i, rec in ipairs(recordings) do
        local item = Instance.new("TextButton", Scroll)
        item.Size             = UDim2.new(1, 0, 0, 28)
        item.BackgroundColor3 = (selectedIndex == i)
            and Color3.fromRGB(0, 70, 130)
            or  Color3.fromRGB(20, 20, 36)
        item.Text             = ""
        item.BorderSizePixel  = 0
        item.LayoutOrder      = i
        Instance.new("UICorner", item).CornerRadius = UDim.new(0, 6)

        local nL = Instance.new("TextLabel", item)
        nL.Size            = UDim2.new(0.65, 0, 1, 0)
        nL.Position        = UDim2.new(0, 7, 0, 0)
        nL.BackgroundTransparency = 1
        nL.Text            = rec.name
        nL.TextColor3      = Color3.fromRGB(210, 210, 255)
        nL.TextSize        = 11
        nL.Font            = Enum.Font.GothamBold
        nL.TextXAlignment  = Enum.TextXAlignment.Left
        nL.TextTruncate    = Enum.TextTruncate.AtEnd

        local fL = Instance.new("TextLabel", item)
        fL.Size            = UDim2.new(0.35, -7, 1, 0)
        fL.Position        = UDim2.new(0.65, 0, 0, 0)
        fL.BackgroundTransparency = 1
        fL.Text            = #rec.frames .. "f"
        fL.TextColor3      = Color3.fromRGB(0, 180, 255)
        fL.TextSize        = 10
        fL.Font            = Enum.Font.Gotham
        fL.TextXAlignment  = Enum.TextXAlignment.Right

        local idx = i
        item.MouseButton1Click:Connect(function()
            selectedIndex = idx
            refreshList()
            setStatus("▸ " .. recordings[idx].name, Color3.fromRGB(180, 180, 255))
        end)
    end
end

-- ══════════════════════════════════════
--         LÓGICA DE GRAVAÇÃO
-- ══════════════════════════════════════
local function startRec()
    if isRecording or isReplaying then return end
    isRecording  = true
    currentFrames = {}
    frameTimer   = 0
    recName = (NameBox.Text ~= "") and NameBox.Text or ("Parkour_" .. (#recordings + 1))

    -- Salva ponto inicial
    startPoints[recName] = rootPart.Position

    RecLbl.Text = "■  Parar Gravação"
    setStatus("⬤ Gravando: " .. recName, Color3.fromRGB(255, 90, 90))

    blinkConn = RunService.Heartbeat:Connect(function(dt)
        if not isRecording then
            blinkConn:Disconnect()
            blinkConn = nil
            StatusBar.TextTransparency = 0
            return
        end
        frameTimer += dt
        if frameTimer >= RECORD_INTERVAL then
            frameTimer -= RECORD_INTERVAL
            table.insert(currentFrames, rootPart.CFrame)
        end
        StatusBar.TextTransparency = (tick() % 1 > 0.5) and 0.45 or 0
    end)
end

local function stopRec()
    if not isRecording then return end
    isRecording = false
    StatusBar.TextTransparency = 0

    if #currentFrames > 0 then
        table.insert(recordings, {
            name     = recName,
            frames   = currentFrames,
            startPos = startPoints[recName]
        })
        _G.PR_Recordings  = recordings
        _G.PR_StartPoints = startPoints
        setStatus("✓ Salvo: " .. recName .. " (" .. #currentFrames .. " frames)", Color3.fromRGB(100, 255, 140))
        NameBox.Text = "Parkour_" .. (#recordings + 1)
        refreshList()
    else
        setStatus("⚠ Gravação vazia.", Color3.fromRGB(255, 200, 0))
    end

    RecLbl.Text = "⬤  Iniciar Gravação"
end

-- ══════════════════════════════════════
--         LÓGICA DE REPRODUÇÃO
-- ══════════════════════════════════════
local function stopReplay()
    isReplaying = false
    if replayConn then replayConn:Disconnect() replayConn = nil end
    humanoid.WalkSpeed = 16
    RepLbl.Text = "▷  Reproduzir Selecionada"
    setStatus("● Reprodução finalizada.", Color3.fromRGB(150, 255, 180))
end

local function startReplay(rec)
    if isRecording or isReplaying then return end
    if not rec or #rec.frames == 0 then
        setStatus("⚠ Sem frames.", Color3.fromRGB(255, 200, 0))
        return
    end

    isReplaying = true
    RepLbl.Text = "■  Parar Reprodução"
    setStatus("▶ Reproduzindo: " .. rec.name, Color3.fromRGB(100, 200, 255))

    local fi    = 1
    local timer = 0

    replayConn = RunService.Heartbeat:Connect(function(dt)
        if not isReplaying then return end
        timer += dt
        if timer >= RECORD_INTERVAL then
            timer -= RECORD_INTERVAL
            if fi > #rec.frames then stopReplay() return end
            -- Usa pcall para evitar crash se personagem morrer
            pcall(function()
                rootPart.CFrame = rec.frames[fi]
            end)
            fi += 1
        end
    end)
end

-- ══════════════════════════════════════
--       INICIAR PARKOUR (Pathfinding)
-- ══════════════════════════════════════
local function nearestRecording()
    local best, bestDist, bestIdx = nil, math.huge, nil
    for i, rec in ipairs(recordings) do
        if rec.startPos then
            local d = (rootPart.Position - rec.startPos).Magnitude
            if d < bestDist then
                bestDist = d
                best     = rec.startPos
                bestIdx  = i
            end
        end
    end
    return best, bestIdx, bestDist
end

local function cancelWalk()
    isWalkingToParkour = false
    if walkConn then walkConn:Disconnect() walkConn = nil end
    pcall(function() humanoid:MoveTo(rootPart.Position) end)
    ParkLbl.Text = "▶  Iniciar Parkour"
end

local function goToParkour()
    -- Toggle: cancela se já estiver andando
    if isWalkingToParkour then
        cancelWalk()
        setStatus("■ Caminhada cancelada.", Color3.fromRGB(255, 200, 0))
        return
    end

    if isRecording or isReplaying then
        setStatus("⚠ Pare a gravação/reprodução primeiro!", Color3.fromRGB(255, 200, 0))
        return
    end

    if #recordings == 0 then
        setStatus("⚠ Grave um parkour primeiro!", Color3.fromRGB(255, 200, 0))
        return
    end

    local targetPos, recIdx, dist = nearestRecording()
    if not targetPos then
        setStatus("⚠ Nenhum ponto inicial salvo.", Color3.fromRGB(255, 200, 0))
        return
    end

    isWalkingToParkour = true
    ParkLbl.Text = "■  Cancelar"
    setStatus("🚶 Indo para: " .. recordings[recIdx].name .. " (~" .. math.floor(dist) .. " studs)", Color3.fromRGB(100, 200, 255))

    -- Tenta pathfinding, com fallback para MoveTo direto
    local usePathfinding = true
    local path, waypoints

    local ok = pcall(function()
        path = PathfindingService:CreatePath({
            AgentRadius    = 2,
            AgentHeight    = 5,
            AgentCanJump   = true,
            AgentJumpHeight = 7.2,
            AgentMaxSlope  = 45,
        })
        path:ComputeAsync(rootPart.Position, targetPos)
        if path.Status ~= Enum.PathStatus.Success then
            usePathfinding = false
        else
            waypoints = path:GetWaypoints()
        end
    end)

    if not ok then usePathfinding = false end

    -- ── Fallback: MoveTo direto ──
    if not usePathfinding then
        setStatus("↝ Caminhando direto (sem rota)...", Color3.fromRGB(255, 200, 0))
        pcall(function() humanoid:MoveTo(targetPos) end)

        walkConn = RunService.Heartbeat:Connect(function()
            if not isWalkingToParkour then return end
            local ok2, d = pcall(function()
                return (rootPart.Position - targetPos).Magnitude
            end)
            if ok2 and d < 6 then
                cancelWalk()
                setStatus("✓ Chegou! Iniciando gravação...", Color3.fromRGB(100, 255, 140))
                task.wait(0.4)
                startRec()
            end
        end)
        return
    end

    -- ── Pathfinding por waypoints ──
    local wpIdx = 1

    local function nextWP()
        if not isWalkingToParkour then return end
        if wpIdx > #waypoints then
            cancelWalk()
            setStatus("✓ Chegou! Iniciando gravação...", Color3.fromRGB(100, 255, 140))
            task.wait(0.4)
            startRec()
            return
        end
        local wp = waypoints[wpIdx]
        if wp.Action == Enum.PathWaypointAction.Jump then
            pcall(function() humanoid.Jump = true end)
        end
        pcall(function() humanoid:MoveTo(wp.Position) end)
        wpIdx += 1
    end

    -- Verifica chegada a cada waypoint
    local arrived
    arrived = humanoid.MoveToFinished:Connect(function(reached)
        if not isWalkingToParkour then
            arrived:Disconnect()
            return
        end
        if reached then
            nextWP()
        else
            -- Tenta repetir o waypoint atual
            if wpIdx <= #waypoints then
                pcall(function() humanoid:MoveTo(waypoints[wpIdx].Position) end)
            end
        end
    end)

    walkConn = arrived
    nextWP()
end

-- ══════════════════════════════════════
--           EVENTOS DOS BOTÕES
-- ══════════════════════════════════════
RecBtn.MouseButton1Click:Connect(function()
    if isRecording then stopRec() else startRec() end
end)

RepBtn.MouseButton1Click:Connect(function()
    if isReplaying then
        stopReplay()
        return
    end
    if not selectedIndex or not recordings[selectedIndex] then
        setStatus("⚠ Selecione uma gravação!", Color3.fromRGB(255, 200, 0))
        return
    end
    startReplay(recordings[selectedIndex])
end)

DelBtn.MouseButton1Click:Connect(function()
    if not selectedIndex or not recordings[selectedIndex] then
        setStatus("⚠ Selecione uma gravação!", Color3.fromRGB(255, 200, 0))
        return
    end
    local n = recordings[selectedIndex].name
    table.remove(recordings, selectedIndex)
    _G.PR_Recordings = recordings
    selectedIndex = nil
    refreshList()
    setStatus("✕ Excluído: " .. n, Color3.fromRGB(255, 100, 100))
end)

ParkBtn.MouseButton1Click:Connect(function()
    goToParkour()
end)

-- ══════════════════════════════════════
--         MINIMIZAR / ARRASTAR
-- ══════════════════════════════════════
local minimized = false
MinBtn.MouseButton1Click:Connect(function()
    minimized = not minimized
    local targetSize = minimized
        and UDim2.new(0, 270, 0, 48)
        or  UDim2.new(0, 270, 0, 510)
    TweenService:Create(Panel, TweenInfo.new(0.2, Enum.EasingStyle.Quart), {Size = targetSize}):Play()
    MinBtn.Text = minimized and "+" or "—"
end)

-- Drag
local dragging, dragStart, frameStart = false, nil, nil

local function onInputBegan(input)
    if input.UserInputType == Enum.UserInputType.MouseButton1
    or input.UserInputType == Enum.UserInputType.Touch then
        dragging   = true
        dragStart  = input.Position
        frameStart = Panel.Position
        input.Changed:Connect(function()
            if input.UserInputState == Enum.UserInputState.End then
                dragging = false
            end
        end)
    end
end

Header.InputBegan:Connect(onInputBegan)
TitleLbl.InputBegan:Connect(onInputBegan)

UserInputService.InputChanged:Connect(function(input)
    if dragging and (input.UserInputType == Enum.UserInputType.MouseMovement
                  or input.UserInputType == Enum.UserInputType.Touch) then
        local d = input.Position - dragStart
        Panel.Position = UDim2.new(
            frameStart.X.Scale, frameStart.X.Offset + d.X,
            frameStart.Y.Scale, frameStart.Y.Offset + d.Y
        )
    end
end)

-- ══════════════════════════════════════
--       RESPAWN - Reconectar referências
-- ══════════════════════════════════════
player.CharacterAdded:Connect(function(newChar)
    character  = newChar
    humanoid   = waitForChild(newChar, "Humanoid")
    rootPart   = waitForChild(newChar, "HumanoidRootPart")
    isRecording        = false
    isReplaying        = false
    isWalkingToParkour = false
    recordings  = _G.PR_Recordings  or {}
    startPoints = _G.PR_StartPoints or {}
    RecLbl.Text  = "⬤  Iniciar Gravação"
    RepLbl.Text  = "▷  Reproduzir Selecionada"
    ParkLbl.Text = "▶  Iniciar Parkour"
    setStatus("● Pronto (respawnado)", Color3.fromRGB(150, 255, 180))
    refreshList()
end)

-- ══════════════════════════════════════
--           INICIALIZAÇÃO
-- ══════════════════════════════════════
refreshList()
setStatus("● Script carregado! " .. #recordings .. " gravação(ões).", Color3.fromRGB(100, 255, 140))
print("[ParkourRecorder v2] OK - Gravações: " .. #recordings)
