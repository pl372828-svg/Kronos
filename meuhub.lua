(function()
    repeat
        wait()
    until game:IsLoaded()

    -- === SERVICES ===
    local Players = game:GetService('Players')
    local TweenService = game:GetService('TweenService')
    local Lighting = game:GetService('Lighting')
    local HttpService = game:GetService('HttpService')
    local UserInputService = game:GetService('UserInputService')
    local TeleportService = game:GetService('TeleportService')
    local ReplicatedStorage = game:GetService('ReplicatedStorage')

    local player = Players.LocalPlayer
    local pg = player:WaitForChild('PlayerGui')

    -- === CONSTANTS ===
    local PLACE_ID = game.PlaceId
    local MIN_MONEY_PER_SEC = 2
    local WEBSOCKET_URL = 'ws://127.0.0.1:1488'
    local HTTP_FALLBACK_URL = 'http://127.0.0.1:1488/latest'

    -- === THEME COLORS ===
    local COLORS = {
        ACCENT = Color3.fromRGB(0, 120, 255),
        ACCENT2 = Color3.fromRGB(150, 50, 200),
        BG_GLASS = Color3.fromRGB(20, 20, 40),
        SUCCESS = Color3.fromRGB(46, 204, 113),
        ERROR = Color3.fromRGB(231, 76, 60),
        WARNING = Color3.fromRGB(241, 196, 15)
    }

    -- === GLOBAL VARIABLES ===
    local running = false
    local currentConnection = nil

    -- === UTILITY FUNCTIONS ===
    local function safeLog(message, level)
        level = level or "INFO"
        local timestamp = os.date("%H:%M:%S")
        print(string.format("[%s - KronosHub]: %s", timestamp, message))
    end

    local function parseMoneyValue(moneyString)
        if not moneyString or type(moneyString) ~= "string" then
            return 0
        end
        
        local number = tonumber(moneyString:match('%d+%.?%d*')) or 0
        local multiplier = 1
        
        if moneyString:lower():find('m') then
            multiplier = 1000000
        elseif moneyString:lower():find('k') then
            multiplier = 1000
        elseif moneyString:lower():find('b') then
            multiplier = 1000000000
        end
        
        return number * multiplier
    end

    -- === CHILLI HUB GUI DETECTION ===
    local function findChilliHubGui()
        local searchContainers = {
            game:GetService("CoreGui"),
            pg
        }
        
        for _, container in ipairs(searchContainers) do
            if not container then continue end
            
            for _, gui in ipairs(container:GetChildren()) do
                if gui:IsA("ScreenGui") then
                    -- Look for Chilli Hub specific elements
                    local chilliHubFound = false
                    
                    for _, obj in ipairs(gui:GetDescendants()) do
                        if obj:IsA("TextLabel") and obj.Text then
                            if obj.Text:find("Chilli Hub") or obj.Text:find("Server Hop") or obj.Text:find("Job-ID Input") then
                                chilliHubFound = true
                                break
                            end
                        end
                    end
                    
                    if chilliHubFound then
                        safeLog("Chilli Hub GUI found: " .. gui.Name)
                        return gui
                    end
                    
                    -- Fallback: check for server hopping elements
                    local hasJobInput = false
                    local hasJoinButton = false
                    
                    for _, obj in ipairs(gui:GetDescendants()) do
                        if obj:IsA("TextBox") then
                            hasJobInput = true
                        end
                        if obj:IsA("TextButton") and obj.Text and obj.Text:lower():find("join") then
                            hasJoinButton = true
                        end
                    end
                    
                    if hasJobInput and hasJoinButton then
                        safeLog("Compatible GUI found: " .. gui.Name)
                        return gui
                    end
                end
            end
        end
        
        safeLog("No compatible GUI found", "WARNING")
        return nil
    end

    local function setJobIDText(targetGui, jobId)
        if not targetGui then 
            safeLog("No target GUI provided", "ERROR")
            return nil 
        end
        
        safeLog("Looking for Job ID input field...")
        
        for _, obj in ipairs(targetGui:GetDescendants()) do
            if obj:IsA("TextBox") and obj.Visible then
                local isJobIdBox = false
                
                -- Check various indicators
                if obj.PlaceholderText and (obj.PlaceholderText:lower():find("job") or obj.PlaceholderText:lower():find("server")) then
                    isJobIdBox = true
                end
                
                if obj.Name:lower():find("job") or obj.Name:lower():find("input") then
                    isJobIdBox = true
                end
                
                -- Check parent context
                local parent = obj.Parent
                while parent and not parent:IsA("ScreenGui") do
                    if parent.Name:lower():find("server") or parent.Name:lower():find("hop") then
                        isJobIdBox = true
                        break
                    end
                    parent = parent.Parent
                end
                
                if isJobIdBox or not obj.PlaceholderText then -- Try any TextBox if no specific one found
                    safeLog("Trying to set Job ID in: " .. obj.Name)
                    
                    pcall(function()
                        obj.Text = jobId
                        wait(0.1)
                        
                        if obj.CaptureFocus then
                            obj:CaptureFocus()
                            wait(0.1)
                            obj:ReleaseFocus()
                        end
                    end)
                    
                    if obj.Text == jobId then
                        safeLog("Job ID set successfully!")
                        return obj
                    end
                end
            end
        end
        
        safeLog("Failed to set Job ID", "ERROR")
        return nil
    end

    local function clickJoinButton(targetGui)
        if not targetGui then 
            safeLog("No target GUI provided", "ERROR")
            return nil 
        end
        
        safeLog("Looking for Join button...")
        
        local bestButton = nil
        local highestPriority = 0
        
        for _, obj in ipairs(targetGui:GetDescendants()) do
            if obj:IsA("TextButton") and obj.Visible then
                local priority = 0
                local buttonText = obj.Text and obj.Text:lower() or ""
                
                -- Priority scoring
                if buttonText:find("join job-id") or buttonText:find("join job id") then
                    priority = 10
                elseif buttonText:find("join") then
                    priority = 8
                elseif buttonText:find("hop") or buttonText:find("teleport") then
                    priority = 6
                elseif obj.Name:lower():find("join") then
                    priority = 4
                else
                    priority = 1
                end
                
                if priority > highestPriority then
                    highestPriority = priority
                    bestButton = obj
                end
            end
        end
        
        if bestButton then
            safeLog("Found join button: " .. bestButton.Name .. " with text: " .. (bestButton.Text or "N/A"))
            
            -- Try multiple click methods
            pcall(function() bestButton.MouseButton1Click:Fire() end)
            wait(0.1)
            pcall(function() bestButton.Activated:Fire() end)
            
            return bestButton
        end
        
        safeLog("No join button found", "ERROR")
        return nil
    end

    local function performGuiJoin(jobId)
        safeLog("Starting GUI join for Job ID: " .. jobId)
        
        local targetGui = findChilliHubGui()
        if not targetGui then
            safeLog("GUI not found", "ERROR")
            return false
        end
        
        local textBox = setJobIDText(targetGui, jobId)
        if not textBox then
            safeLog("Could not set Job ID", "ERROR")
            return false
        end
        
        wait(0.3)
        
        local joinButton = clickJoinButton(targetGui)
        if not joinButton then
            safeLog("Could not click join button", "ERROR")
            return false
        end
        
        safeLog("GUI join completed successfully")
        return true
    end

    local function attemptTeleport(jobId)
        safeLog("Attempting to join server with Job ID: " .. jobId)
        
        -- Try GUI method first (best for Chilli Hub)
        if performGuiJoin(jobId) then
            safeLog("Successfully initiated GUI join")
            return true
        end
        
        -- Fallback to TeleportService
        pcall(function()
            local teleportOptions = Instance.new("TeleportOptions")
            teleportOptions.ServerInstanceId = jobId
            TeleportService:TeleportToPlaceInstance(PLACE_ID, jobId, player, nil, teleportOptions)
        end)
        
        return false
    end

    -- === CONNECTION FUNCTIONS ===
    local function processServerData(data)
        if not running then return false end
        
        if not data or not data.jobid or not data.money then
            safeLog("Invalid server data", "WARNING")
            return false
        end
        
        local moneyValue = parseMoneyValue(data.money)
        local threshold = MIN_MONEY_PER_SEC * 1000000
        
        safeLog(string.format("Server found - Money: %s, Job ID: %s", data.money, data.jobid))
        
        if moneyValue >= threshold then
            safeLog("Server meets criteria, attempting to join...")
            updateStatus("Joining server...", COLORS.WARNING)
            return attemptTeleport(data.jobid)
        else
            safeLog("Server rejected - insufficient money")
            return false
        end
    end

    local function startConnection()
        if currentConnection then
            safeLog("Connection already active")
            return
        end
        
        safeLog("Starting connection to: " .. WEBSOCKET_URL)
        
        -- Try WebSocket first
        local WebSocketLib = getgenv().WebSocket or WebSocket or websocket or syn.websocket
        
        if WebSocketLib then
            pcall(function()
                local socket = WebSocketLib.connect(WEBSOCKET_URL)
                currentConnection = socket
                
                safeLog("WebSocket connected")
                updateStatus("Connected (WebSocket)", COLORS.SUCCESS)
                
                socket.OnMessage:Connect(function(message)
                    if not running then return end
                    
                    local success, data = pcall(function()
                        return HttpService:JSONDecode(message)
                    end)
                    
                    if success then
                        processServerData(data)
                    end
                end)
                
                socket.OnClose:Connect(function()
                    currentConnection = nil
                    if running then
                        safeLog("Connection lost, reconnecting...")
                        wait(2)
                        startConnection()
                    end
                end)
            end)
        else
            -- HTTP Fallback
            safeLog("Using HTTP fallback")
            updateStatus("Connected (HTTP)", COLORS.WARNING)
            
            spawn(function()
                while running do
                    pcall(function()
                        local response = HttpService:GetAsync(HTTP_FALLBACK_URL)
                        if response and response ~= "" then
                            local data = HttpService:JSONDecode(response)
                            processServerData(data)
                        end
                    end)
                    wait(1)
                end
            end)
        end
    end

    local function stopConnection()
        running = false
        if currentConnection and currentConnection.Close then
            pcall(function()
                currentConnection:Close()
            end)
        end
        currentConnection = nil
        safeLog("Connection stopped")
    end

    -- === UI CREATION ===
    local blur = Instance.new('BlurEffect')
    blur.Size = 0
    blur.Enabled = false
    blur.Parent = Lighting

    local gui = Instance.new('ScreenGui')
    gui.Name = 'PeakHubAutojoiner'
    gui.ResetOnSpawn = false
    gui.IgnoreGuiInset = true
    gui.Parent = pg

    -- Shadow
    local shadow = Instance.new('Frame')
    shadow.BackgroundColor3 = Color3.new(0, 0, 0)
    shadow.BackgroundTransparency = 0.5
    shadow.Size = UDim2.fromOffset(320, 180)
    shadow.AnchorPoint = Vector2.new(0.5, 0.5)
    shadow.Position = UDim2.fromScale(0.5, 0.5)
    shadow.ZIndex = 0
    shadow.Parent = gui
    local shadowCorner = Instance.new('UICorner', shadow)
    shadowCorner.CornerRadius = UDim.new(0, 16)

    -- Main card
    local card = Instance.new('Frame')
    card.Size = UDim2.fromOffset(320, 180)
    card.AnchorPoint = Vector2.new(0.5, 0.5)
    card.Position = UDim2.fromScale(0.5, 0.5)
    card.BackgroundColor3 = COLORS.BG_GLASS
    card.BackgroundTransparency = 0.15
    card.BorderSizePixel = 0
    card.ClipsDescendants = true
    card.Parent = gui

    local corner = Instance.new('UICorner', card)
    corner.CornerRadius = UDim.new(0, 16)

    local stroke = Instance.new('UIStroke')
    stroke.Thickness = 1.5
    stroke.Color = Color3.fromRGB(100, 150, 255)
    stroke.Transparency = 0.6
    stroke.ApplyStrokeMode = Enum.ApplyStrokeMode.Border
    stroke.Parent = card

    local grad = Instance.new('UIGradient')
    grad.Color = ColorSequence.new({
        ColorSequenceKeypoint.new(0, COLORS.ACCENT),
        ColorSequenceKeypoint.new(1, COLORS.ACCENT2),
    })
    grad.Rotation = 30
    grad.Transparency = NumberSequence.new({
        NumberSequenceKeypoint.new(0, 0.25),
        NumberSequenceKeypoint.new(1, 0.25),
    })
    grad.Parent = card

    local padding = Instance.new('UIPadding', card)
    padding.PaddingTop = UDim.new(0, 14)
    padding.PaddingBottom = UDim.new(0, 14)
    padding.PaddingLeft = UDim.new(0, 14)
    padding.PaddingRight = UDim.new(0, 14)

    -- Title bar
    local titleBar = Instance.new('Frame')
    titleBar.Name = 'TitleBar'
    titleBar.BackgroundTransparency = 1
    titleBar.Size = UDim2.new(1, 0, 0, 30)
    titleBar.Parent = card

    local title = Instance.new('TextLabel')
    title.BackgroundTransparency = 1
    title.Size = UDim2.new(1, -30, 1, 0)
    title.Position = UDim2.fromOffset(2, 0)
    title.Font = Enum.Font.GothamBold
    title.Text = 'Peak Hub - Chilli Compatible'
    title.TextColor3 = Color3.fromRGB(180, 200, 255)
    title.TextSize = 16
    title.TextXAlignment = Enum.TextXAlignment.Left
    title.Parent = titleBar

    -- Status indicator
    local statusIndicator = Instance.new('Frame')
    statusIndicator.Size = UDim2.fromOffset(8, 8)
    statusIndicator.Position = UDim2.new(1, -40, 0.5, -4)
    statusIndicator.BackgroundColor3 = COLORS.ERROR
    statusIndicator.BorderSizePixel = 0
    statusIndicator.Parent = titleBar
    local statusCorner = Instance.new('UICorner', statusIndicator)
    statusCorner.CornerRadius = UDim.new(0.5, 0)

    local minimizeBtn = Instance.new('TextButton')
    minimizeBtn.Text = '−'
    minimizeBtn.Font = Enum.Font.GothamBold
    minimizeBtn.TextSize = 14
    minimizeBtn.BackgroundColor3 = Color3.fromRGB(100, 150, 255)
    minimizeBtn.TextColor3 = Color3.fromRGB(20, 20, 20)
    minimizeBtn.AutoButtonColor = false
    minimizeBtn.Size = UDim2.fromOffset(24, 24)
    minimizeBtn.Position = UDim2.new(1, -24, 0.5, -12)
    minimizeBtn.Parent = titleBar
    local minimizeCorner = Instance.new('UICorner', minimizeBtn)
    minimizeCorner.CornerRadius = UDim.new(0, 8)

    -- Control button
    local button = Instance.new('TextButton')
    button.Size = UDim2.new(0, 140, 0, 46)
    button.AutoButtonColor = false
    button.Text = 'Start Autojoiner'
    button.Font = Enum.Font.GothamBold
    button.TextSize = 16
    button.TextColor3 = Color3.fromRGB(255, 255, 255)
    button.BackgroundColor3 = COLORS.ACCENT
    button.Position = UDim2.fromScale(0.5, 0.55)
    button.AnchorPoint = Vector2.new(0.5, 0.5)
    button.Parent = card

    local buttonCorner = Instance.new('UICorner', button)
    buttonCorner.CornerRadius = UDim.new(0, 14)

    local buttonGrad = Instance.new('UIGradient', button)
    buttonGrad.Color = ColorSequence.new({
        ColorSequenceKeypoint.new(0, COLORS.ACCENT),
        ColorSequenceKeypoint.new(1, COLORS.ACCENT2),
    })

    -- Status label
    local statusLabel = Instance.new('TextLabel')
    statusLabel.BackgroundTransparency = 1
    statusLabel.Size = UDim2.new(1, -28, 0, 20)
    statusLabel.Position = UDim2.fromOffset(14, 40)
    statusLabel.Font = Enum.Font.Gotham
    statusLabel.Text = 'Status: Ready'
    statusLabel.TextColor3 = Color3.fromRGB(150, 170, 200)
    statusLabel.TextSize = 12
    statusLabel.TextXAlignment = Enum.TextXAlignment.Left
    statusLabel.Parent = card

    -- Discord link
    local discordLabel = Instance.new('TextLabel')
    discordLabel.BackgroundTransparency = 1
    discordLabel.Size = UDim2.new(0, 120, 0, 14)
    discordLabel.Position = UDim2.new(1, -134, 1, -26)
    discordLabel.Font = Enum.Font.Gotham
    discordLabel.TextSize = 12
    discordLabel.TextColor3 = Color3.fromRGB(180, 200, 255)
    discordLabel.Text = 'jpzin08377'
    discordLabel.TextXAlignment = Enum.TextXAlignment.Right
    discordLabel.Parent = card

    -- === STATUS UPDATE FUNCTION ===
    function updateStatus(text, color)
        statusLabel.Text = "Status: " .. text
        statusIndicator.BackgroundColor3 = color or COLORS.WARNING
    end

    -- === DRAGGING LOGIC ===
    local dragging, dragStart, startPos
    titleBar.InputBegan:Connect(function(input)
        if input.UserInputType == Enum.UserInputType.MouseButton1 then
            dragging = true
            dragStart = input.Position
            startPos = card.Position
            input.Changed:Connect(function()
                if input.UserInputState == Enum.UserInputState.End then
                    dragging = false
                end
            end)
        end
    end)

    UserInputService.InputChanged:Connect(function(input)
        if dragging and input.UserInputType == Enum.UserInputType.MouseMovement then
            local delta = input.Position - dragStart
            card.Position = UDim2.new(
                startPos.X.Scale,
                startPos.X.Offset + delta.X,
                startPos.Y.Scale,
                startPos.Y.Offset + delta.Y
            )
            shadow.Position = card.Position
        end
    end)

    -- === MINIMIZE/RESTORE LOGIC ===
    local minimized = false
    local reopenBtn = Instance.new('TextButton')
    reopenBtn.Text = '+'
    reopenBtn.Font = Enum.Font.GothamBold
    reopenBtn.TextSize = 16
    reopenBtn.BackgroundColor3 = COLORS.BG_GLASS
    reopenBtn.TextColor3 = Color3.fromRGB(255, 255, 255)
    reopenBtn.AutoButtonColor = false
    reopenBtn.Size = UDim2.fromOffset(30, 30)
    reopenBtn.AnchorPoint = Vector2.new(0.5, 0.5)
    reopenBtn.Position = UDim2.fromScale(0.5, 0.9)
    reopenBtn.Visible = false
    reopenBtn.Parent = gui
    local reopenCorner = Instance.new('UICorner', reopenBtn)
    reopenCorner.CornerRadius = UDim.new(0, 8)

    local function openUI()
        gui.Enabled = true
        card.Visible = true
        shadow.Visible = true
        reopenBtn.Visible = false
        minimized = false
        TweenService:Create(card, TweenInfo.new(0.22, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), {
            Size = UDim2.fromOffset(320, 180),
            Position = UDim2.fromScale(0.5, 0.5),
        }):Play()
        blur.Enabled = true
        TweenService:Create(blur, TweenInfo.new(0.25), { Size = 4 }):Play()
    end

    local function minimizeUI()
        TweenService:Create(card, TweenInfo.new(0.18, Enum.EasingStyle.Quad, Enum.EasingDirection.In), { Size = UDim2.fromOffset(320, 0) }):Play()
        TweenService:Create(blur, TweenInfo.new(0.2), { Size = 0 }):Play()
        wait(0.18)
        blur.Enabled = false
        shadow.Visible = false
        card.Visible = false
        reopenBtn.Visible = true
        minimized = true
    end

    openUI()
    minimizeBtn.MouseButton1Click:Connect(minimizeUI)
    reopenBtn.MouseButton1Click:Connect(function()
        if not gui.Enabled then gui.Enabled = true end
        openUI()
    end)

    -- === MAIN CONTROL LOGIC ===
    button.MouseButton1Click:Connect(function()
        if running then
            stopConnection()
            button.Text = 'Start Autojoiner'
            buttonGrad.Color = ColorSequence.new({
                ColorSequenceKeypoint.new(0, COLORS.ACCENT),
                ColorSequenceKeypoint.new(1, COLORS.ACCENT2),
            })
            updateStatus("Stopped", COLORS.ERROR)
        else
            running = true
            button.Text = 'Stop Autojoiner'
            buttonGrad.Color = ColorSequence.new({
                ColorSequenceKeypoint.new(0, COLORS.WARNING),
                ColorSequenceKeypoint.new(1, COLORS.ERROR),
            })
            updateStatus("Starting...", COLORS.WARNING)
            startConnection()
        end
    end)

    -- === HOVER ANIMATIONS ===
    button.MouseEnter:Connect(function()
        TweenService:Create(button, TweenInfo.new(0.12), { Size = UDim2.new(0, 144, 0, 48) }):Play()
    end)
    button.MouseLeave:Connect(function()
        TweenService:Create(button, TweenInfo.new(0.12), { Size = UDim2.new(0, 140, 0, 46) }):Play()
    end)

    minimizeBtn.MouseEnter:Connect(function()
        TweenService:Create(minimizeBtn, TweenInfo.new(0.12), { BackgroundTransparency = 0.1 }):Play()
    end)
    minimizeBtn.MouseLeave:Connect(function()
        TweenService:Create(minimizeBtn, TweenInfo.new(0.12), { BackgroundTransparency = 0 }):Play()
    end)

    -- === INITIALIZATION ===
    updateStatus("Ready", COLORS.SUCCESS)
    safeLog("Kronos Autojoiner initialized!")
    safeLog("Chilli Hub compatibility enabled")
    safeLog("WebSocket URL: " .. WEBSOCKET_URL)
    safeLog("Minimum threshold: " .. MIN_MONEY_PER_SEC .. "M per second")
    
    -- Auto-detect Chilli Hub on start
    spawn(function()
        wait(2)
        local chilliGui = findChilliHubGui()
        if chilliGui then
            safeLog("Chilli Hub detected and ready!")
            updateStatus("Chilli Hub detected", COLORS.SUCCESS)
        else
            safeLog("Chilli Hub not detected - make sure it's open")
            updateStatus("Waiting for Chilli Hub", COLORS.WARNING)
        end
    end)

end)()
