-- ================================================
-- AUTO PARKOUR v2 — Gravação + Reprodução
-- Cole no executor (exploit) enquanto estiver no jogo
-- ================================================

local Players              = game:GetService("Players")
local RunService           = game:GetService("RunService")
local UserInputService     = game:GetService("UserInputService")
local StarterGui           = game:GetService("StarterGui")
local ContextActionService = game:GetService("ContextActionService")
local CoreGui              = game:GetService("CoreGui")

local player    = Players.LocalPlayer
local character = player.Character or player.CharacterAdded:Wait()
local humanoid  = character:WaitForChild("Humanoid")
local rootPart  = character:WaitForChild("HumanoidRootPart")

local guiParent = gethui and gethui() or CoreGui

-- ================================================
-- CONFIGURAÇÕES
-- ================================================
local FRAME_RATE  = 20
local INPUT_BLOCK = "AutoParkourBlock"

-- ================================================
-- PARKOURS SALVOS (memória, persistem enquanto o script roda)
-- ================================================
local PARKOURS = {}

-- ================================================
-- ESTADO
-- ================================================
local reproduzindo   = false
local gravando       = false
local reproConn      = nil
local gravConn       = nil
local framesGravados = {}

-- ================================================
-- REFERÊNCIAS GUI (preenchidas em criarGui)
-- ================================================
local statusLabel, listaFrame, painel
local minimizado = false

-- ================================================
-- NOTIFICAÇÃO
-- ================================================
local function notify(titulo, msg, dur)
    StarterGui:SetCore("SendNotification", {Title=titulo, Text=msg, Duration=dur or 4})
end

-- ================================================
-- BLOQUEIA INPUT DURANTE REPRODUÇÃO
-- ================================================
local function bloquearInput()
    local noop = function() return Enum.ContextActionResult.Sink end
    ContextActionService:BindAction(INPUT_BLOCK, noop, false,
        Enum.PlayerActions.CharacterForward,
        Enum.PlayerActions.CharacterBackward,
        Enum.PlayerActions.CharacterLeft,
        Enum.PlayerActions.CharacterRight,
        Enum.PlayerActions.CharacterJump
    )
end

local function desbloquearInput()
    ContextActionService:UnbindAction(INPUT_BLOCK)
end

-- ================================================
-- UTILITÁRIOS
-- ================================================
local function rotToCF(r)
    return CFrame.new(0,0,0, r[1],r[2],r[3], r[4],r[5],r[6], r[7],r[8],r[9])
end

local function cfToRot(cf)
    local _,_,_,r1,r2,r3,r4,r5,r6,r7,r8,r9 = cf:GetComponents()
    return {r1,r2,r3,r4,r5,r6,r7,r8,r9}
end

-- ================================================
-- ATUALIZAR STATUS E LISTA (declaradas antes de uso)
-- ================================================
local atualizarStatus, atualizarLista

atualizarStatus = function()
    if not statusLabel then return end
    if gravando then
        statusLabel.Text       = "⏺ GRAVANDO"
        statusLabel.TextColor3 = Color3.fromRGB(220, 50, 50)
    elseif reproduzindo then
        statusLabel.Text       = "▶ REPRODUZINDO"
        statusLabel.TextColor3 = Color3.fromRGB(0, 200, 80)
    else
        statusLabel.Text       = "— PARADO"
        statusLabel.TextColor3 = Color3.fromRGB(60, 60, 80)
    end
end

-- ================================================
-- PARAR REPRODUÇÃO
-- ================================================
local function pararReproducao()
    if not reproduzindo then return end
    reproduzindo = false
    if reproConn then reproConn:Disconnect() reproConn = nil end
    desbloquearInput()
    rootPart.AssemblyLinearVelocity = Vector3.zero
    notify("⏹", "Reprodução parada.", 3)
    atualizarStatus()
end

-- ================================================
-- REPRODUÇÃO (forward declaration)
-- ================================================
local reproduzir

reproduzir = function(index)
    if reproduzindo then return end
    local pk = PARKOURS[index]
    if not pk then return end

    reproduzindo = true
    bloquearInput()
    notify("▶ " .. pk.nome, "Indo ao início...", 3)
    atualizarStatus()

    local frames   = pk.frames
    local interval = 1 / FRAME_RATE

    task.spawn(function()
        -- Anda até o início em vez de teleportar
        local destPos = frames[1].pos
        local hum     = character:FindFirstChildOfClass("Humanoid")
        local dist    = (Vector3.new(destPos.X, rootPart.Position.Y, destPos.Z) - rootPart.Position).Magnitude

        if hum and dist > 3 then
            hum:MoveTo(destPos)
            local t = 0
            repeat
                task.wait(0.1)
                t    = t + 0.1
                dist = (Vector3.new(destPos.X, rootPart.Position.Y, destPos.Z) - rootPart.Position).Magnitude
            until dist < 3 or t >= 15 or not reproduzindo
        end

        if not reproduzindo then return end

        -- Posiciona no ponto exato e começa reprodução
        rootPart.CFrame = CFrame.new(destPos) * rotToCF(frames[1].rot)
        rootPart.AssemblyLinearVelocity = frames[1].vel
        notify("▶ " .. pk.nome, "Reproduzindo!", 2)

        local i   = 1
        local acc = 0

        reproConn = RunService.Heartbeat:Connect(function(dt)
            if not reproduzindo then return end
            acc = acc + dt

            while acc >= interval and i <= #frames do
                acc = acc - interval
                local f = frames[i]

                rootPart.AssemblyLinearVelocity = f.vel
                rootPart.CFrame = CFrame.new(rootPart.Position) * rotToCF(f.rot)

                -- Corrige deriva horizontal
                local driftH = Vector3.new(f.pos.X - rootPart.Position.X, 0, f.pos.Z - rootPart.Position.Z)
                if driftH.Magnitude > 0.4 then
                    local corrH = driftH.Unit * math.min(driftH.Magnitude * 20, 50)
                    rootPart.AssemblyLinearVelocity = Vector3.new(
                        f.vel.X + corrH.X,
                        rootPart.AssemblyLinearVelocity.Y,
                        f.vel.Z + corrH.Z
                    )
                end

                -- Corrige deriva vertical
                local driftV = f.pos.Y - rootPart.Position.Y
                if math.abs(driftV) > 0.6 then
                    local corrV = math.clamp(driftV * 15, -40, 40)
                    rootPart.AssemblyLinearVelocity = Vector3.new(
                        rootPart.AssemblyLinearVelocity.X,
                        f.vel.Y + corrV,
                        rootPart.AssemblyLinearVelocity.Z
                    )
                end

                i = i + 1
            end

            if i > #frames then
                reproduzindo = false
                reproConn:Disconnect()
                reproConn = nil
                desbloquearInput()
                rootPart.AssemblyLinearVelocity = Vector3.zero
                notify("✅ Concluído", pk.nome .. " finalizado!", 3)
                atualizarStatus()
            end
        end)
    end)
end

-- ================================================
-- GRAVAÇÃO
-- ================================================
local function iniciarGravacao()
    if gravando or reproduzindo then return end
    framesGravados = {}
    gravando       = true
    notify("⏺ Gravando", "Faça o parkour! Toque SALVAR quando terminar.", 5)
    atualizarStatus()

    local acc      = 0
    local interval = 1 / FRAME_RATE

    gravConn = RunService.Heartbeat:Connect(function(dt)
        if not gravando then return end
        acc = acc + dt
        if acc >= interval then
            acc = acc - interval
            local cf  = rootPart.CFrame
            local vel = rootPart.AssemblyLinearVelocity
            table.insert(framesGravados, {
                pos = cf.Position,
                vel = vel,
                rot = cfToRot(cf),
            })
        end
    end)
end

local function pararGravacao()
    if not gravando then return end
    gravando = false
    if gravConn then gravConn:Disconnect() gravConn = nil end

    if #framesGravados < 5 then
        notify("⚠ Gravação", "Muito curto, descartado.", 3)
        atualizarStatus()
        return
    end

    local nome = "Parkour " .. tostring(#PARKOURS + 1)
    table.insert(PARKOURS, { nome = nome, frames = framesGravados })

    notify("💾 Salvo!", nome .. " — " .. #framesGravados .. " frames", 4)
    atualizarStatus()
    atualizarLista()
end

-- ================================================
-- ATUALIZAR LISTA
-- ================================================
atualizarLista = function()
    if not listaFrame then return end
    for _, c in ipairs(listaFrame:GetChildren()) do
        if c:IsA("Frame") or (c:IsA("TextLabel") and c.Name == "Vazio") then
            c:Destroy()
        end
    end

    if #PARKOURS == 0 then
        local v = Instance.new("TextLabel")
        v.Name               = "Vazio"
        v.Size               = UDim2.new(1,0,0,30)
        v.BackgroundTransparency = 1
        v.Text               = "nenhum parkour gravado"
        v.TextColor3         = Color3.fromRGB(40,40,55)
        v.TextSize           = 11
        v.Font               = Enum.Font.Gotham
        v.Parent             = listaFrame
        return
    end

    for i, pk in ipairs(PARKOURS) do
        local row = Instance.new("Frame")
        row.Size             = UDim2.new(1,0,0,38)
        row.BackgroundColor3 = Color3.fromRGB(10,10,16)
        row.BorderSizePixel  = 0
        row.Parent           = listaFrame
        Instance.new("UICorner", row).CornerRadius = UDim.new(0,6)

        local stroke = Instance.new("UIStroke")
        stroke.Color     = Color3.fromRGB(20,20,35)
        stroke.Thickness = 1
        stroke.Parent    = row

        local nome = Instance.new("TextLabel")
        nome.Size               = UDim2.new(1,-52,0,20)
        nome.Position           = UDim2.new(0,8,0,4)
        nome.BackgroundTransparency = 1
        nome.Text               = pk.nome
        nome.TextColor3         = Color3.fromRGB(140,140,180)
        nome.TextSize           = 11
        nome.Font               = Enum.Font.GothamBold
        nome.TextXAlignment     = Enum.TextXAlignment.Left
        nome.TextTruncate       = Enum.TextTruncate.AtEnd
        nome.Parent             = row

        local sub = Instance.new("TextLabel")
        sub.Size               = UDim2.new(1,-52,0,12)
        sub.Position           = UDim2.new(0,8,1,-14)
        sub.BackgroundTransparency = 1
        sub.Text               = #pk.frames.."f · "..math.floor(#pk.frames/FRAME_RATE).."s"
        sub.TextColor3         = Color3.fromRGB(40,40,60)
        sub.TextSize           = 9
        sub.Font               = Enum.Font.Gotham
        sub.TextXAlignment     = Enum.TextXAlignment.Left
        sub.Parent             = row

        local btnPlay = Instance.new("TextButton")
        btnPlay.Size             = UDim2.new(0,38,0,26)
        btnPlay.Position         = UDim2.new(1,-44,0.5,-13)
        btnPlay.BackgroundColor3 = Color3.fromRGB(0,120,50)
        btnPlay.BorderSizePixel  = 0
        btnPlay.Text             = "▶"
        btnPlay.TextColor3       = Color3.fromRGB(200,255,200)
        btnPlay.TextSize         = 14
        btnPlay.Font             = Enum.Font.GothamBold
        btnPlay.Parent           = row
        Instance.new("UICorner", btnPlay).CornerRadius = UDim.new(0,5)

        local idx = i
        btnPlay.MouseButton1Click:Connect(function()
            if gravando then return end
            if reproduzindo then pararReproducao() task.wait(0.05) end
            reproduzir(idx)
        end)
    end
end

-- ================================================
-- GUI
-- ================================================
local function criarGui()
    local antiga = guiParent:FindFirstChild("_sys_parkour")
    if antiga then antiga:Destroy() end

    local screen = Instance.new("ScreenGui")
    screen.Name           = "_sys_parkour"
    screen.IgnoreGuiInset = true
    screen.Parent         = guiParent

    painel = Instance.new("Frame")
    painel.Size             = UDim2.new(0,200,0,330)
    painel.Position         = UDim2.new(0,8,0.5,-165)
    painel.BackgroundColor3 = Color3.fromRGB(5,5,8)
    painel.BorderSizePixel  = 0
    painel.ClipsDescendants = true
    painel.Parent           = screen
    Instance.new("UICorner", painel).CornerRadius = UDim.new(0,10)

    Instance.new("UIStroke", painel).Color = Color3.fromRGB(15,15,25)

    -- Header
    local header = Instance.new("Frame")
    header.Size             = UDim2.new(1,0,0,32)
    header.BackgroundColor3 = Color3.fromRGB(7,7,12)
    header.BorderSizePixel  = 0
    header.Parent           = painel
    Instance.new("UICorner", header).CornerRadius = UDim.new(0,10)

    local hFix = Instance.new("Frame")
    hFix.Size             = UDim2.new(1,0,0,10)
    hFix.Position         = UDim2.new(0,0,1,-10)
    hFix.BackgroundColor3 = Color3.fromRGB(7,7,12)
    hFix.BorderSizePixel  = 0
    hFix.Parent           = header

    local titulo = Instance.new("TextLabel")
    titulo.Size               = UDim2.new(1,-60,1,0)
    titulo.Position           = UDim2.new(0,10,0,0)
    titulo.BackgroundTransparency = 1
    titulo.Text               = "AUTO PARKOUR"
    titulo.TextColor3         = Color3.fromRGB(50,50,70)
    titulo.TextSize           = 10
    titulo.Font               = Enum.Font.GothamBold
    titulo.TextXAlignment     = Enum.TextXAlignment.Left
    titulo.Parent             = header

    statusLabel = Instance.new("TextLabel")
    statusLabel.Size               = UDim2.new(0,80,1,0)
    statusLabel.Position           = UDim2.new(1,-108,0,0)
    statusLabel.BackgroundTransparency = 1
    statusLabel.Text               = "— PARADO"
    statusLabel.TextColor3         = Color3.fromRGB(60,60,80)
    statusLabel.TextSize           = 9
    statusLabel.Font               = Enum.Font.GothamBold
    statusLabel.TextXAlignment     = Enum.TextXAlignment.Right
    statusLabel.Parent             = header

    local btnMin = Instance.new("TextButton")
    btnMin.Size             = UDim2.new(0,24,0,18)
    btnMin.Position         = UDim2.new(1,-28,0.5,-9)
    btnMin.BackgroundColor3 = Color3.fromRGB(12,12,20)
    btnMin.BorderSizePixel  = 0
    btnMin.Text             = "—"
    btnMin.TextColor3       = Color3.fromRGB(50,50,70)
    btnMin.TextSize         = 12
    btnMin.Font             = Enum.Font.GothamBold
    btnMin.Parent           = header
    Instance.new("UICorner", btnMin).CornerRadius = UDim.new(0,4)

    -- Botão GRAVAR
    local btnGravar = Instance.new("TextButton")
    btnGravar.Name            = "BtnGravar"
    btnGravar.Size            = UDim2.new(1,-10,0,28)
    btnGravar.Position        = UDim2.new(0,5,0,36)
    btnGravar.BackgroundColor3 = Color3.fromRGB(120,20,20)
    btnGravar.BorderSizePixel = 0
    btnGravar.Text            = "⏺  GRAVAR"
    btnGravar.TextColor3      = Color3.fromRGB(255,160,160)
    btnGravar.TextSize        = 11
    btnGravar.Font            = Enum.Font.GothamBold
    btnGravar.Parent          = painel
    Instance.new("UICorner", btnGravar).CornerRadius = UDim.new(0,6)

    -- Botão SALVAR GRAVAÇÃO
    local btnSalvar = Instance.new("TextButton")
    btnSalvar.Name            = "BtnSalvar"
    btnSalvar.Size            = UDim2.new(1,-10,0,28)
    btnSalvar.Position        = UDim2.new(0,5,0,68)
    btnSalvar.BackgroundColor3 = Color3.fromRGB(50,50,10)
    btnSalvar.BorderSizePixel = 0
    btnSalvar.Text            = "💾  SALVAR GRAVAÇÃO"
    btnSalvar.TextColor3      = Color3.fromRGB(220,220,100)
    btnSalvar.TextSize        = 11
    btnSalvar.Font            = Enum.Font.GothamBold
    btnSalvar.Parent          = painel
    Instance.new("UICorner", btnSalvar).CornerRadius = UDim.new(0,6)

    -- Botão PARAR
    local btnParar = Instance.new("TextButton")
    btnParar.Name             = "BtnParar"
    btnParar.Size             = UDim2.new(1,-10,0,28)
    btnParar.Position         = UDim2.new(0,5,0,100)
    btnParar.BackgroundColor3 = Color3.fromRGB(60,10,10)
    btnParar.BorderSizePixel  = 0
    btnParar.Text             = "⏹  PARAR REPRODUÇÃO"
    btnParar.TextColor3       = Color3.fromRGB(180,80,80)
    btnParar.TextSize         = 11
    btnParar.Font             = Enum.Font.GothamBold
    btnParar.Parent           = painel
    Instance.new("UICorner", btnParar).CornerRadius = UDim.new(0,6)

    -- Divisória
    local div = Instance.new("Frame")
    div.Size             = UDim2.new(1,-10,0,1)
    div.Position         = UDim2.new(0,5,0,134)
    div.BackgroundColor3 = Color3.fromRGB(12,12,20)
    div.BorderSizePixel  = 0
    div.Parent           = painel

    -- Lista
    local scroll = Instance.new("ScrollingFrame")
    scroll.Size                 = UDim2.new(1,-10,1,-142)
    scroll.Position             = UDim2.new(0,5,0,140)
    scroll.BackgroundColor3     = Color3.fromRGB(5,5,8)
    scroll.BorderSizePixel      = 0
    scroll.ScrollBarThickness   = 2
    scroll.ScrollBarImageColor3 = Color3.fromRGB(20,20,35)
    scroll.CanvasSize           = UDim2.new(0,0,0,0)
    scroll.AutomaticCanvasSize  = Enum.AutomaticSize.Y
    scroll.Parent               = painel
    Instance.new("UICorner", scroll).CornerRadius = UDim.new(0,6)

    local layout = Instance.new("UIListLayout")
    layout.Padding = UDim.new(0,4)
    layout.Parent  = scroll

    local pad = Instance.new("UIPadding")
    pad.PaddingTop    = UDim.new(0,4)
    pad.PaddingLeft   = UDim.new(0,4)
    pad.PaddingRight  = UDim.new(0,4)
    pad.PaddingBottom = UDim.new(0,4)
    pad.Parent        = scroll

    listaFrame = scroll

    -- Arrastar
    local dragging, dragStart, startPos
    header.InputBegan:Connect(function(input)
        if input.UserInputType == Enum.UserInputType.MouseButton1
        or input.UserInputType == Enum.UserInputType.Touch then
            dragging  = true
            dragStart = input.Position
            startPos  = painel.Position
        end
    end)
    UserInputService.InputChanged:Connect(function(input)
        if not dragging then return end
        if input.UserInputType == Enum.UserInputType.MouseMovement
        or input.UserInputType == Enum.UserInputType.Touch then
            local d = input.Position - dragStart
            painel.Position = UDim2.new(
                startPos.X.Scale, startPos.X.Offset + d.X,
                startPos.Y.Scale, startPos.Y.Offset + d.Y
            )
        end
    end)
    UserInputService.InputEnded:Connect(function(input)
        if input.UserInputType == Enum.UserInputType.MouseButton1
        or input.UserInputType == Enum.UserInputType.Touch then
            dragging = false
        end
    end)

    -- Minimizar
    btnMin.MouseButton1Click:Connect(function()
        minimizado = not minimizado
        if minimizado then
            painel.Size = UDim2.new(0,200,0,32)
            btnMin.Text = "+"
            btnGravar.Visible = false
            btnSalvar.Visible = false
            btnParar.Visible  = false
            div.Visible       = false
            scroll.Visible    = false
        else
            painel.Size = UDim2.new(0,200,0,330)
            btnMin.Text = "—"
            btnGravar.Visible = true
            btnSalvar.Visible = true
            btnParar.Visible  = true
            div.Visible       = true
            scroll.Visible    = true
        end
    end)

    -- Ações dos botões
    btnGravar.MouseButton1Click:Connect(function()
        if gravando then return end
        if reproduzindo then pararReproducao() task.wait(0.05) end
        iniciarGravacao()
        btnGravar.BackgroundColor3 = Color3.fromRGB(180,20,20)
    end)

    btnSalvar.MouseButton1Click:Connect(function()
        pararGravacao()
        btnGravar.BackgroundColor3 = Color3.fromRGB(120,20,20)
    end)

    btnParar.MouseButton1Click:Connect(function()
        pararReproducao()
    end)
end

-- ================================================
-- INICIALIZAÇÃO
-- ================================================
criarGui()
atualizarLista()
atualizarStatus()

task.wait(1)
notify("AUTO PARKOUR v2", "Toque ⏺ GRAVAR, faça o parkour, depois SALVAR.", 6)

player.CharacterAdded:Connect(function(newChar)
    character = newChar
    humanoid  = newChar:WaitForChild("Humanoid")
    rootPart  = newChar:WaitForChild("HumanoidRootPart")
    if reproduzindo then pararReproducao() end
    if gravando     then pararGravacao()    end
    atualizarStatus()
end)
