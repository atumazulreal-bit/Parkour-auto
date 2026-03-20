-- ╔══════════════════════════════════════════════════════════════╗
-- ║           PARKOUR RECORDER - Script por Claude              ║
-- ║  Coloque como LocalScript em: StarterPlayer > StarterPlayerScripts ║
-- ╚══════════════════════════════════════════════════════════════╝

local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local UserInputService = game:GetService("UserInputService")
local TweenService = game:GetService("TweenService")
local PathfindingService = game:GetService("PathfindingService")

local player = Players.LocalPlayer
local character = player.Character or player.CharacterAdded:Wait()
local humanoid = character:WaitForChild("Humanoid")
local rootPart = character:WaitForChild("HumanoidRootPart")

-- ══════════════════════════════════════
--           DATASTORES (DataStore)
-- Precisamos usar RemoteEvents p/ salvar
-- no servidor. Aqui usamos apenas local
-- via script (funciona em Studio/jogos
-- com DataStore via servidor).
-- Nesta versão: salvo em _G p/ persistir
-- entre respawns na mesma sessão.
-- ══════════════════════════════════════
if not _G.ParkourRecordings then
    _G.ParkourRecordings = {}
end
if not _G.ParkourStartPoints then
    _G.ParkourStartPoints = {}
end

local recordings = _G.ParkourRecordings
local startPoints = _G.ParkourStartPoints

-- ══════════════════════════════════════
--              ESTADO
-- ══════════════════════════════════════
local isRecording = false
local isReplaying = false
local isWalkingToParkour = false
local currentRecording = {}
local recordingName = "Parkour_" .. tostring(#recordings + 1)
local recordInterval = 0.1 -- segundos entre frames
local replaySpeed = 1.0
local selectedReplayIndex = nil
local recordingTimer = 0
local replayConnection = nil
local walkConnection = nil

-- ══════════════════════════════════════
--           GUI - CoreGui
-- ══════════════════════════════════════
local CoreGui = game:GetService("CoreGui")

-- Remove GUI antiga se existir
if CoreGui:FindFirstChild("ParkourRecorderGui") then
    CoreGui:FindFirstChild("ParkourRecorderGui"):Destroy()
end

local ScreenGui = Instance.new("ScreenGui")
ScreenGui.Name = "ParkourRecorderGui"
ScreenGui.ResetOnSpawn = false
ScreenGui.ZIndexBehavior = Enum.ZIndexBehavior.Sibling
ScreenGui.Parent = CoreGui

-- ─────────────────────────────────────
-- Frame principal (painel lateral)
-- ─────────────────────────────────────
local MainFrame = Instance.new("Frame")
MainFrame.Name = "MainFrame"
MainFrame.Size = UDim2.new(0, 280, 0, 520)
MainFrame.Position = UDim2.new(0, 16, 0.5, -260)
MainFrame.BackgroundColor3 = Color3.fromRGB(10, 10, 18)
MainFrame.BorderSizePixel = 0
MainFrame.ClipsDescendants = true
MainFrame.Parent = ScreenGui

local MainCorner = Instance.new("UICorner")
MainCorner.CornerRadius = UDim.new(0, 14)
MainCorner.Parent = MainFrame

-- Borda neon
local MainStroke = Instance.new("UIStroke")
MainStroke.Color = Color3.fromRGB(0, 200, 255)
MainStroke.Thickness = 1.5
MainStroke.Transparency = 0.3
MainStroke.Parent = MainFrame

-- Gradient de fundo
local MainGradient = Instance.new("UIGradient")
MainGradient.Color = ColorSequence.new({
    ColorSequenceKeypoint.new(0, Color3.fromRGB(14, 14, 28)),
    ColorSequenceKeypoint.new(1, Color3.fromRGB(8, 8, 20))
})
MainGradient.Rotation = 135
MainGradient.Parent = MainFrame

-- ─────────────────────────────────────
-- Header
-- ─────────────────────────────────────
local Header = Instance.new("Frame")
Header.Size = UDim2.new(1, 0, 0, 52)
Header.BackgroundColor3 = Color3.fromRGB(0, 170, 230)
Header.BorderSizePixel = 0
Header.Parent = MainFrame

local HeaderGrad = Instance.new("UIGradient")
HeaderGrad.Color = ColorSequence.new({
    ColorSequenceKeypoint.new(0, Color3.fromRGB(0, 200, 255)),
    ColorSequenceKeypoint.new(1, Color3.fromRGB(80, 0, 200))
})
HeaderGrad.Rotation = 90
HeaderGrad.Parent = Header

local HeaderCorner = Instance.new("UICorner")
HeaderCorner.CornerRadius = UDim.new(0, 14)
HeaderCorner.Parent = Header

-- Corrigir cantos inferiores do header
local HeaderFix = Instance.new("Frame")
HeaderFix.Size = UDim2.new(1, 0, 0, 14)
HeaderFix.Position = UDim2.new(0, 0, 1, -14)
HeaderFix.BackgroundColor3 = Color3.fromRGB(0, 200, 255)
HeaderFix.BorderSizePixel = 0
HeaderFix.Parent = Header

local HeaderFixGrad = Instance.new("UIGradient")
HeaderFixGrad.Color = ColorSequence.new({
    ColorSequenceKeypoint.new(0, Color3.fromRGB(0, 200, 255)),
    ColorSequenceKeypoint.new(1, Color3.fromRGB(80, 0, 200))
})
HeaderFixGrad.Rotation = 90
HeaderFixGrad.Parent = HeaderFix

local TitleLabel = Instance.new("TextLabel")
TitleLabel.Size = UDim2.new(1, -12, 1, 0)
TitleLabel.Position = UDim2.new(0, 12, 0, 0)
TitleLabel.BackgroundTransparency = 1
TitleLabel.Text = "⬡ PARKOUR RECORDER"
TitleLabel.TextColor3 = Color3.fromRGB(255, 255, 255)
TitleLabel.TextSize = 15
TitleLabel.Font = Enum.Font.GothamBold
TitleLabel.TextXAlignment = Enum.TextXAlignment.Left
TitleLabel.Parent = Header

-- Botão minimizar/maximizar
local MinBtn = Instance.new("TextButton")
MinBtn.Size = UDim2.new(0, 32, 0, 32)
MinBtn.Position = UDim2.new(1, -42, 0, 10)
MinBtn.BackgroundColor3 = Color3.fromRGB(255, 255, 255)
MinBtn.BackgroundTransparency = 0.8
MinBtn.Text = "—"
MinBtn.TextColor3 = Color3.fromRGB(255, 255, 255)
MinBtn.TextSize = 14
MinBtn.Font = Enum.Font.GothamBold
MinBtn.BorderSizePixel = 0
MinBtn.Parent = Header

local MinCorner = Instance.new("UICorner")
MinCorner.CornerRadius = UDim.new(0, 8)
MinCorner.Parent = MinBtn

-- ─────────────────────────────────────
-- Conteúdo (área abaixo do header)
-- ─────────────────────────────────────
local Content = Instance.new("Frame")
Content.Name = "Content"
Content.Size = UDim2.new(1, 0, 1, -52)
Content.Position = UDim2.new(0, 0, 0, 52)
Content.BackgroundTransparency = 1
Content.Parent = MainFrame

local ContentPad = Instance.new("UIPadding")
ContentPad.PaddingLeft = UDim.new(0, 12)
ContentPad.PaddingRight = UDim.new(0, 12)
ContentPad.PaddingTop = UDim.new(0, 10)
ContentPad.Parent = Content

local ContentLayout = Instance.new("UIListLayout")
ContentLayout.SortOrder = Enum.SortOrder.LayoutOrder
ContentLayout.Padding = UDim.new(0, 8)
ContentLayout.Parent = Content

-- ─────────────────────────────────────
-- Helper: criar botão estilizado
-- ─────────────────────────────────────
local function makeButton(text, color1, color2, layoutOrder)
    local btn = Instance.new("TextButton")
    btn.Size = UDim2.new(1, 0, 0, 40)
    btn.BackgroundColor3 = color1
    btn.Text = ""
    btn.BorderSizePixel = 0
    btn.AutoButtonColor = false
    btn.LayoutOrder = layoutOrder
    btn.Parent = Content

    local bg = Instance.new("UIGradient")
    bg.Color = ColorSequence.new({
        ColorSequenceKeypoint.new(0, color1),
        ColorSequenceKeypoint.new(1, color2)
    })
    bg.Rotation = 90
    bg.Parent = btn

    local corner = Instance.new("UICorner")
    corner.CornerRadius = UDim.new(0, 10)
    corner.Parent = btn

    local stroke = Instance.new("UIStroke")
    stroke.Color = color1
    stroke.Thickness = 1
    stroke.Transparency = 0.5
    stroke.Parent = btn

    local label = Instance.new("TextLabel")
    label.Size = UDim2.new(1, 0, 1, 0)
    label.BackgroundTransparency = 1
    label.Text = text
    label.TextColor3 = Color3.fromRGB(255, 255, 255)
    label.TextSize = 13
    label.Font = Enum.Font.GothamBold
    label.Parent = btn

    -- Hover effect
    btn.MouseEnter:Connect(function()
        TweenService:Create(btn, TweenInfo.new(0.15), {BackgroundTransparency = 0.15}):Play()
    end)
    btn.MouseLeave:Connect(function()
        TweenService:Create(btn, TweenInfo.new(0.15), {BackgroundTransparency = 0}):Play()
    end)

    return btn, label
end

-- ─────────────────────────────────────
-- Helper: label de seção
-- ─────────────────────────────────────
local function makeSection(txt, layoutOrder)
    local lbl = Instance.new("TextLabel")
    lbl.Size = UDim2.new(1, 0, 0, 18)
    lbl.BackgroundTransparency = 1
    lbl.Text = txt
    lbl.TextColor3 = Color3.fromRGB(0, 200, 255)
    lbl.TextSize = 11
    lbl.Font = Enum.Font.GothamBold
    lbl.TextXAlignment = Enum.TextXAlignment.Left
    lbl.LayoutOrder = layoutOrder
    lbl.Parent = Content
    return lbl
end

-- ─────────────────────────────────────
-- Status label
-- ─────────────────────────────────────
local StatusLabel = Instance.new("TextLabel")
StatusLabel.Size = UDim2.new(1, 0, 0, 28)
StatusLabel.BackgroundColor3 = Color3.fromRGB(20, 20, 36)
StatusLabel.TextColor3 = Color3.fromRGB(180, 255, 200)
StatusLabel.Text = "● Pronto"
StatusLabel.TextSize = 12
StatusLabel.Font = Enum.Font.Gotham
StatusLabel.LayoutOrder = 1
StatusLabel.BorderSizePixel = 0
StatusLabel.Parent = Content

local StatusCorner = Instance.new("UICorner")
StatusCorner.CornerRadius = UDim.new(0, 8)
StatusCorner.Parent = StatusLabel

-- ─────────────────────────────────────
-- Seção: Gravação
-- ─────────────────────────────────────
makeSection("── GRAVAÇÃO ──────────────────", 2)

local RecBtn, RecLabel = makeButton("⬤  Iniciar Gravação", Color3.fromRGB(200, 40, 40), Color3.fromRGB(140, 0, 60), 3)

-- Input nome da gravação
local NameBox = Instance.new("TextBox")
NameBox.Size = UDim2.new(1, 0, 0, 34)
NameBox.BackgroundColor3 = Color3.fromRGB(20, 20, 36)
NameBox.TextColor3 = Color3.fromRGB(255, 255, 255)
NameBox.PlaceholderText = "Nome da gravação..."
NameBox.PlaceholderColor3 = Color3.fromRGB(100, 100, 130)
NameBox.Text = recordingName
NameBox.TextSize = 12
NameBox.Font = Enum.Font.Gotham
NameBox.LayoutOrder = 4
NameBox.BorderSizePixel = 0
NameBox.ClearTextOnFocus = false
NameBox.Parent = Content

local NameCorner = Instance.new("UICorner")
NameCorner.CornerRadius = UDim.new(0, 8)
NameCorner.Parent = NameBox

local NameStroke = Instance.new("UIStroke")
NameStroke.Color = Color3.fromRGB(0, 200, 255)
NameStroke.Thickness = 1
NameStroke.Transparency = 0.7
NameStroke.Parent = NameBox

local NamePad = Instance.new("UIPadding")
NamePad.PaddingLeft = UDim.new(0, 10)
NamePad.Parent = NameBox

-- ─────────────────────────────────────
-- Seção: Parkour
-- ─────────────────────────────────────
makeSection("── PARKOUR ────────────────────", 5)

local ParkourBtn, ParkourLabel = makeButton("▶  Iniciar Parkour", Color3.fromRGB(0, 160, 255), Color3.fromRGB(80, 0, 200), 6)

-- ─────────────────────────────────────
-- Seção: Lista de Gravações
-- ─────────────────────────────────────
makeSection("── GRAVAÇÕES SALVAS ───────────", 7)

local ListContainer = Instance.new("Frame")
ListContainer.Size = UDim2.new(1, 0, 0, 120)
ListContainer.BackgroundColor3 = Color3.fromRGB(15, 15, 28)
ListContainer.BorderSizePixel = 0
ListContainer.ClipsDescendants = true
ListContainer.LayoutOrder = 8
ListContainer.Parent = Content

local ListCorner = Instance.new("UICorner")
ListCorner.CornerRadius = UDim.new(0, 10)
ListCorner.Parent = ListContainer

local ListStroke = Instance.new("UIStroke")
ListStroke.Color = Color3.fromRGB(0, 200, 255)
ListStroke.Thickness = 1
ListStroke.Transparency = 0.7
ListStroke.Parent = ListContainer

local ScrollFrame = Instance.new("ScrollingFrame")
ScrollFrame.Size = UDim2.new(1, -8, 1, -8)
ScrollFrame.Position = UDim2.new(0, 4, 0, 4)
ScrollFrame.BackgroundTransparency = 1
ScrollFrame.BorderSizePixel = 0
ScrollFrame.ScrollBarThickness = 3
ScrollFrame.ScrollBarImageColor3 = Color3.fromRGB(0, 200, 255)
ScrollFrame.CanvasSize = UDim2.new(0, 0, 0, 0)
ScrollFrame.AutomaticCanvasSize = Enum.AutomaticSize.Y
ScrollFrame.Parent = ListContainer

local ScrollLayout = Instance.new("UIListLayout")
ScrollLayout.SortOrder = Enum.SortOrder.LayoutOrder
ScrollLayout.Padding = UDim.new(0, 4)
ScrollLayout.Parent = ScrollFrame

local ScrollPad = Instance.new("UIPadding")
ScrollPad.PaddingLeft = UDim.new(0, 4)
ScrollPad.PaddingRight = UDim.new(0, 4)
ScrollPad.PaddingTop = UDim.new(0, 2)
ScrollPad.Parent = ScrollFrame

-- ─────────────────────────────────────
-- Seção: Reprodução
-- ─────────────────────────────────────
makeSection("── REPRODUÇÃO ─────────────────", 9)

local ReplayBtn, ReplayLabel = makeButton("▷  Reproduzir Selecionada", Color3.fromRGB(0, 200, 100), Color3.fromRGB(0, 120, 60), 10)
local DeleteBtn, DeleteLabel = makeButton("✕  Excluir Selecionada", Color3.fromRGB(180, 60, 60), Color3.fromRGB(100, 20, 20), 11)

-- ══════════════════════════════════════
--       FUNÇÕES DE GRAVAÇÃO
-- ══════════════════════════════════════

local function setStatus(text, color)
    StatusLabel.Text = text
    StatusLabel.TextColor3 = color or Color3.fromRGB(180, 255, 200)
end

local function updateRecordingsList()
    -- Limpa lista
    for _, child in ipairs(ScrollFrame:GetChildren()) do
        if child:IsA("TextButton") then
            child:Destroy()
        end
    end

    if #recordings == 0 then
        local emptyLabel = Instance.new("TextLabel")
        emptyLabel.Size = UDim2.new(1, 0, 0, 28)
        emptyLabel.BackgroundTransparency = 1
        emptyLabel.Text = "Nenhuma gravação salva"
        emptyLabel.TextColor3 = Color3.fromRGB(80, 80, 100)
        emptyLabel.TextSize = 11
        emptyLabel.Font = Enum.Font.Gotham
        emptyLabel.LayoutOrder = 1
        emptyLabel.Parent = ScrollFrame
        return
    end

    for i, rec in ipairs(recordings) do
        local item = Instance.new("TextButton")
        item.Size = UDim2.new(1, 0, 0, 30)
        item.BackgroundColor3 = (selectedReplayIndex == i)
            and Color3.fromRGB(0, 80, 140)
            or Color3.fromRGB(20, 20, 38)
        item.Text = ""
        item.BorderSizePixel = 0
        item.LayoutOrder = i
        item.Parent = ScrollFrame

        local itemCorner = Instance.new("UICorner")
        itemCorner.CornerRadius = UDim.new(0, 6)
        itemCorner.Parent = item

        local nameL = Instance.new("TextLabel")
        nameL.Size = UDim2.new(0.7, 0, 1, 0)
        nameL.Position = UDim2.new(0, 8, 0, 0)
        nameL.BackgroundTransparency = 1
        nameL.Text = rec.name
        nameL.TextColor3 = Color3.fromRGB(220, 220, 255)
        nameL.TextSize = 11
        nameL.Font = Enum.Font.GothamBold
        nameL.TextXAlignment = Enum.TextXAlignment.Left
        nameL.Parent = item

        local frameCount = Instance.new("TextLabel")
        frameCount.Size = UDim2.new(0.3, -8, 1, 0)
        frameCount.Position = UDim2.new(0.7, 0, 0, 0)
        frameCount.BackgroundTransparency = 1
        frameCount.Text = #rec.frames .. " frames"
        frameCount.TextColor3 = Color3.fromRGB(0, 200, 255)
        frameCount.TextSize = 10
        frameCount.Font = Enum.Font.Gotham
        frameCount.TextXAlignment = Enum.TextXAlignment.Right
        frameCount.Parent = item

        local idx = i
        item.MouseButton1Click:Connect(function()
            selectedReplayIndex = idx
            updateRecordingsList()
            setStatus("▸ Selecionado: " .. recordings[idx].name, Color3.fromRGB(200, 200, 255))
        end)
    end
end

local function startRecording()
    if isRecording or isReplaying then return end
    isRecording = true
    currentRecording = {}
    recordingName = NameBox.Text ~= "" and NameBox.Text or ("Parkour_" .. tostring(#recordings + 1))
    recordingTimer = 0

    -- Salva ponto inicial
    local startPos = rootPart.CFrame
    startPoints[recordingName] = startPos.Position

    RecLabel.Text = "■  Parar Gravação"
    RecBtn.BackgroundColor3 = Color3.fromRGB(220, 100, 0)
    setStatus("⬤ Gravando: " .. recordingName, Color3.fromRGB(255, 100, 100))

    -- Piscar indicador
    local blinkConnection
    blinkConnection = RunService.Heartbeat:Connect(function(dt)
        if not isRecording then
            blinkConnection:Disconnect()
            return
        end
        recordingTimer += dt
        if recordingTimer >= recordInterval then
            recordingTimer -= recordInterval
            -- Grava frame: posição + orientação
            table.insert(currentRecording, {
                cf = rootPart.CFrame,
                moveDir = humanoid.MoveDirection
            })
        end
        -- Piscar status
        local t = tick() % 1
        StatusLabel.TextTransparency = t > 0.5 and 0.4 or 0
    end)
end

local function stopRecording()
    if not isRecording then return end
    isRecording = false
    StatusLabel.TextTransparency = 0

    if #currentRecording > 0 then
        table.insert(recordings, {
            name = recordingName,
            frames = currentRecording,
            startPos = startPoints[recordingName]
        })
        _G.ParkourRecordings = recordings
        _G.ParkourStartPoints = startPoints
        setStatus("✓ Salvo: " .. recordingName .. " (" .. #currentRecording .. " frames)", Color3.fromRGB(100, 255, 150))
        recordingName = "Parkour_" .. tostring(#recordings + 1)
        NameBox.Text = recordingName
        updateRecordingsList()
    else
        setStatus("⚠ Gravação vazia, descartada.", Color3.fromRGB(255, 200, 0))
    end

    RecLabel.Text = "⬤  Iniciar Gravação"
end

-- ══════════════════════════════════════
--       FUNÇÕES DE REPRODUÇÃO
-- ══════════════════════════════════════

local function stopReplay()
    isReplaying = false
    if replayConnection then
        replayConnection:Disconnect()
        replayConnection = nil
    end
    humanoid.WalkSpeed = 16 -- restaura velocidade
    ReplayLabel.Text = "▷  Reproduzir Selecionada"
    setStatus("● Reprodução finalizada.", Color3.fromRGB(180, 255, 200))
end

local function replayRecording(rec)
    if isRecording or isReplaying then return end
    if not rec or #rec.frames == 0 then
        setStatus("⚠ Nenhum frame para reproduzir.", Color3.fromRGB(255, 200, 0))
        return
    end

    isReplaying = true
    ReplayLabel.Text = "■  Parar Reprodução"
    setStatus("▶ Reproduzindo: " .. rec.name, Color3.fromRGB(100, 200, 255))

    local frameIndex = 1
    local timer = 0

    replayConnection = RunService.Heartbeat:Connect(function(dt)
        if not isReplaying then return end
        timer += dt * replaySpeed
        if timer >= recordInterval then
            timer -= recordInterval
            if frameIndex > #rec.frames then
                stopReplay()
                return
            end
            local frame = rec.frames[frameIndex]
            -- Move o personagem para a posição gravada
            rootPart.CFrame = frame.cf
            frameIndex += 1
        end
    end)
end

-- ══════════════════════════════════════
--       SISTEMA "INICIAR PARKOUR"
--  Pathfinding até o ponto mais próximo
-- ══════════════════════════════════════

local function findNearestStartPoint()
    local nearest = nil
    local nearestDist = math.huge
    local nearestRecIndex = nil

    for i, rec in ipairs(recordings) do
        if rec.startPos then
            local dist = (rootPart.Position - rec.startPos).Magnitude
            if dist < nearestDist then
                nearestDist = dist
                nearest = rec.startPos
                nearestRecIndex = i
            end
        end
    end

    return nearest, nearestRecIndex, nearestDist
end

local function stopWalkToParkour()
    isWalkingToParkour = false
    if walkConnection then
        walkConnection:Disconnect()
        walkConnection = nil
    end
    ParkourLabel.Text = "▶  Iniciar Parkour"
    humanoid:MoveTo(rootPart.Position) -- para o movimento
end

local function walkToParkour()
    if isRecording or isReplaying or isWalkingToParkour then
        if isWalkingToParkour then
            stopWalkToParkour()
            setStatus("■ Caminhada cancelada.", Color3.fromRGB(255, 200, 0))
        end
        return
    end

    if #recordings == 0 then
        setStatus("⚠ Nenhuma gravação com ponto inicial.", Color3.fromRGB(255, 200, 0))
        return
    end

    local targetPos, recIndex, dist = findNearestStartPoint()

    if not targetPos then
        setStatus("⚠ Nenhum ponto inicial encontrado.", Color3.fromRGB(255, 200, 0))
        return
    end

    isWalkingToParkour = true
    ParkourLabel.Text = "■  Cancelar Caminhada"
    setStatus("🚶 Indo para: " .. recordings[recIndex].name .. " (" .. math.floor(dist) .. " studs)", Color3.fromRGB(100, 200, 255))
 
    -- Pathfinding
    local path = PathfindingService:CreatePath({
        AgentRadius = 2,
        AgentHeight = 5,
        AgentCanJump = true,
        AgentJumpHeight = 7.2,
        AgentMaxSlope = 45,
        Costs = {
            Water = 20,
        }
    })
 
    local success, err = pcall(function()
        path:ComputeAsync(rootPart.Position, targetPos)
    end)
 
    if not success or path.Status ~= Enum.PathStatus.Success then
        -- Fallback: MoveTo direto
        setStatus("↝ Caminhando diretamente (sem rota)...", Color3.fromRGB(255, 200, 0))
        humanoid:MoveTo(targetPos)
        walkConnection = RunService.Heartbeat:Connect(function()
            if not isWalkingToParkour then return end
            local distNow = (rootPart.Position - targetPos).Magnitude
            if distNow < 5 then
                stopWalkToParkour()
                setStatus("✓ Chegou! Iniciando gravação automática...", Color3.fromRGB(100, 255, 150))
                task.wait(0.5)
                startRecording()
            end
        end)
        return
    end
 
    local waypoints = path:GetWaypoints()
    local waypointIndex = 1
 
    -- Avança pelos waypoints
    local function moveToNextWaypoint()
        if not isWalkingToParkour then return end
        if waypointIndex > #waypoints then
            stopWalkToParkour()
            setStatus("✓ Chegou! Iniciando gravação automática...", Color3.fromRGB(100, 255, 150))
            task.wait(0.5)
            startRecording()
            return
        end
 
        local wp = waypoints[waypointIndex]
        if wp.Action == Enum.PathWaypointAction.Jump then
            humanoid.Jump = true
        end
        humanoid:MoveTo(wp.Position)
        waypointIndex += 1
    end
 
    -- Conecta evento de chegada ao waypoint
    local moveReachedConn
    moveReachedConn = humanoid.MoveToFinished:Connect(function(reached)
        if not isWalkingToParkour then
            moveReachedConn:Disconnect()
            return
        end
        if reached then
            moveToNextWaypoint()
        else
            -- Tenta de novo o mesmo waypoint
            if waypointIndex <= #waypoints then
                humanoid:MoveTo(waypoints[waypointIndex].Position)
            end
        end
    end)
 
    walkConnection = moveReachedConn
    moveToNextWaypoint()
end
 
-- ══════════════════════════════════════
--       BOTÕES - EVENTOS
-- ══════════════════════════════════════
 
RecBtn.MouseButton1Click:Connect(function()
    if isRecording then
        stopRecording()
        RecLabel.Text = "⬤  Iniciar Gravação"
    else
        startRecording()
    end
end)
 
ReplayBtn.MouseButton1Click:Connect(function()
    if isReplaying then
        stopReplay()
        return
    end
    if not selectedReplayIndex or not recordings[selectedReplayIndex] then
        setStatus("⚠ Selecione uma gravação primeiro!", Color3.fromRGB(255, 200, 0))
        return
    end
    replayRecording(recordings[selectedReplayIndex])
end)
 
DeleteBtn.MouseButton1Click:Connect(function()
    if not selectedReplayIndex or not recordings[selectedReplayIndex] then
        setStatus("⚠ Selecione uma gravação para excluir!", Color3.fromRGB(255, 200, 0))
        return
    end
    local name = recordings[selectedReplayIndex].name
    table.remove(recordings, selectedReplayIndex)
    _G.ParkourRecordings = recordings
    selectedReplayIndex = nil
    updateRecordingsList()
    setStatus("✕ Excluído: " .. name, Color3.fromRGB(255, 100, 100))
end)
 
ParkourBtn.MouseButton1Click:Connect(function()
    walkToParkour()
end)
 
-- ══════════════════════════════════════
--       MINIMIZAR / MAXIMIZAR
-- ══════════════════════════════════════
local isMinimized = false
MinBtn.MouseButton1Click:Connect(function()
    isMinimized = not isMinimized
    if isMinimized then
        TweenService:Create(MainFrame, TweenInfo.new(0.25, Enum.EasingStyle.Quart), {
            Size = UDim2.new(0, 280, 0, 52)
        }):Play()
        MinBtn.Text = "+"
    else
        TweenService:Create(MainFrame, TweenInfo.new(0.25, Enum.EasingStyle.Quart), {
            Size = UDim2.new(0, 280, 0, 520)
        }):Play()
        MinBtn.Text = "—"
    end
end)
 
-- ══════════════════════════════════════
--       DRAG (arrastar GUI)
-- ══════════════════════════════════════
local dragging = false
local dragInput, dragStart, startPos2
 
Header.InputBegan:Connect(function(input)
    if input.UserInputType == Enum.UserInputType.MouseButton1 or
       input.UserInputType == Enum.UserInputType.Touch then
        dragging = true
        dragStart = input.Position
        startPos2 = MainFrame.Position
 
        input.Changed:Connect(function()
            if input.UserInputState == Enum.UserInputState.End then
                dragging = false
            end
        end)
    end
end)
 
Header.InputChanged:Connect(function(input)
    if input.UserInputType == Enum.UserInputType.MouseMovement or
       input.UserInputType == Enum.UserInputType.Touch then
        dragInput = input
    end
end)
 
UserInputService.InputChanged:Connect(function(input)
    if input == dragInput and dragging then
        local delta = input.Position - dragStart
        MainFrame.Position = UDim2.new(
            startPos2.X.Scale,
            startPos2.X.Offset + delta.X,
            startPos2.Y.Scale,
            startPos2.Y.Offset + delta.Y
        )
    end
end)
 
-- ══════════════════════════════════════
--       RESPAWN - recarregar referências
-- ══════════════════════════════════════
player.CharacterAdded:Connect(function(newChar)
    character = newChar
    humanoid = newChar:WaitForChild("Humanoid")
    rootPart = newChar:WaitForChild("HumanoidRootPart")
    isRecording = false
    isReplaying = false
    isWalkingToParkour = false
    -- Recupera gravações salvas em _G
    recordings = _G.ParkourRecordings or {}
    startPoints = _G.ParkourStartPoints or {}
    RecLabel.Text = "⬤  Iniciar Gravação"
    ReplayLabel.Text = "▷  Reproduzir Selecionada"
    ParkourLabel.Text = "▶  Iniciar Parkour"
    setStatus("● Pronto (personagem respawnado)", Color3.fromRGB(180, 255, 200))
    updateRecordingsList()
end)
 
-- ══════════════════════════════════════
--            INICIALIZAÇÃO
-- ══════════════════════════════════════
updateRecordingsList()
setStatus("● Sistema carregado! Pronto para gravar.", Color3.fromRGB(100, 255, 150))
 
print("[ParkourRecorder] Script carregado com sucesso!")
print("[ParkourRecorder] Gravações existentes: " .. #recordings)
