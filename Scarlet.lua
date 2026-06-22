local OrionLib = loadstring(game:HttpGet("https://raw.githubusercontent.com/Luna-Vencorded/hyper/refs/heads/main/main.lua"))()

local Window = OrionLib:MakeWindow({
    Name = "Scarlet Hub",
    HidePremium = false,
    SaveConfig = false,
    ConfigFolder = "ScarletFTAPConfig",

    IntroText = "Scarlet Hub Load...",
    IntroIcon = ""
})

local Players = game:GetService("Players")
local LocalPlayer = Players.LocalPlayer
local Workspace = game:GetService("Workspace")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local Debris = game:GetService("Debris")
local UserInputService = game:GetService("UserInputService")
local Camera = Workspace.CurrentCamera

-- [Variables] Common / Blobman / Aura
local GrabEvents = ReplicatedStorage:WaitForChild("GrabEvents", 10)
local SetNetworkOwner = GrabEvents and GrabEvents:FindFirstChild("SetNetworkOwner")
local CreateGrabLine = GrabEvents and GrabEvents:FindFirstChild("CreateGrabLine")
local ExtendGrabLine = GrabEvents and GrabEvents:FindFirstChild("ExtendGrabLine")
local DestroyGrabLine = GrabEvents and GrabEvents:FindFirstChild("DestroyGrabLine")

local cachedCG, cachedCD, cachedCR = nil, nil, nil
local cachedR_Det, cachedR_Weld = nil, nil
local cachedL_Det, cachedL_Weld = nil, nil
local cachedBlobman = nil
local playerThreads = {}

local bmkAuraEnabled = false
local AURA_RADIUS = 35
local auraConn = nil
local auraInRange = {}

-- [Variables] Blobman Kick & Kick All
local currentBlob = nil
local isActive = false
local levitateRunning = false
local selectedActionTargetName = ""
local ExcludeFriends = false
local autoKillAllEnabled = false

-- [Variables] Drift Kick
local orbitRunning = false
local currentLoopId = 0
local driftRadius = 19
local driftSpeed = 12
local driftHeightOffset = 0
local driftAngle = 0
local playerMap = {}

-- [Variables] 20 Stack Mount Kill (New Logic)
local bm_currentBlobman = nil
local bm_originalCFrame = nil
local bm_isRunning = false
local bm_loopConn = nil
local bm_grabConn = nil
local bm_respawnConn = nil
local bm_localRespawnConn = nil
local bm_mountConn = nil
local bm_lastTargetPos = Vector3.zero
local BM_MY_HEIGHT = 20
local bm_angle = 0
local bm_circleRadius = 8
local bm_rotationSpeed = 14

-- [Variables] Object Aura (New System)
local Mouse = LocalPlayer:GetMouse()
local currentEffect = "None"
local collectionMethod = "Manual Tap"
local targetObjectName = "FireworkSparkler"
local auraTargetPlayerName = LocalPlayer.Name
local manualList = {}

local AuraObjConfig = {
    OrbitSpeed = 100,
    Radius = 15,
    Height = 5,
    Wing = { spacing = 1.5, spread = 3, flapSpeed = 5, flapAmp = 2.5 },
    UpDown = { speed = 5, amp = 5 }
}

local auraPlayerNames = {}
local auraNameMap = {}
local auraPlayerDropdown

-- [Variables] Reskill
local FlingForce = 99999999
local noclip_reskill = false
local reskillLooping = false
local lastFlungCharacter = nil
local reskillSelectedTargetName = ""
local reskillPlayerNames = {}
local reskillNameMap = {}
local reskillDropdown

-- [Variables] Grab
local throwStrength = 400
local throwEnabled = false
local GrabMode = {
    Kill = false,
    Sky = false,
    Down = false,
    Noclip = false
}

-- [Variables] Anti
local antiLagT = false
local isFlghtBackEnabled = false
local spamConnection = nil
local isHolding = false
local lastActionTime = 0
_G.Spamming = false

-- [Variables] New Anti System
local gucciRunId = 0
local antiGucciConnectionTrain
local safePositionTrain
local restoreFramesTrain = 0
local autoGucciActiveTrain = false
local antiActive = false
local antiTask = nil

-- [Variables] Server
local Go_g = 1
local PP_dd = 50
local running = false
local ragServer = false

-- [Variables] Visuals (ESP)
local ESP_Settings = { Enabled = false, Lines = false }

-- [Variables] Minimap / Teleport
local mapRp = RaycastParams.new()
mapRp.FilterType = Enum.RaycastFilterType.Exclude
local zoomLevel = 500
local gridRes = 12
local mapPixels = {}
local playerDots = {}
local lastScanPos = Vector3.new(0, 0, 0)
local mapOffset = Vector3.zero
local selectedTeleportTargetName = nil

-- ==========================================
-- Minimap UI Construction
-- ==========================================
local MapGui = Instance.new("ScreenGui")
MapGui.Name = "CustomMinimapGui"
pcall(function() MapGui.Parent = game:GetService("CoreGui") end)
if not MapGui.Parent then
    MapGui.Parent = LocalPlayer:WaitForChild("PlayerGui")
end

local MapFrame = Instance.new("Frame", MapGui)
MapFrame.Size = UDim2.new(0, 220, 0, 220)
MapFrame.Position = UDim2.new(0.01, 0, 0.02, 0)
MapFrame.BackgroundColor3 = Color3.fromRGB(15, 15, 15)
MapFrame.BorderColor3 = Color3.fromRGB(255, 105, 180)
MapFrame.BorderSizePixel = 2
MapFrame.ClipsDescendants = true
MapFrame.Visible = false
MapFrame.Active = true

for x = 1, gridRes do
    mapPixels[x] = {}
    for y = 1, gridRes do
        local p = Instance.new("Frame", MapFrame)
        p.Size = UDim2.new(1 / gridRes, 0, 1 / gridRes, 0)
        p.Position = UDim2.new((x - 1) / gridRes, 0, (y - 1) / gridRes, 0)
        p.BorderSizePixel = 0
        p.BackgroundColor3 = Color3.fromRGB(25, 25, 25)
        mapPixels[x][y] = p
    end
end

-- ==========================================
-- Core Logic & Helper Functions
-- ==========================================
local function HRP()
    return LocalPlayer.Character and LocalPlayer.Character:FindFirstChild("HumanoidRootPart")
end

local function getPlayerList()
    local names = {}
    playerMap = {}
    for _, player in ipairs(Players:GetPlayers()) do
        if player ~= LocalPlayer then
            local displayStr = player.DisplayName .. " (@" .. player.Name .. ")"
            table.insert(names, displayStr)
            playerMap[displayStr] = player.Name
        end
    end
    if #names == 0 then table.insert(names, "(None)") end
    return names
end

local function SendChat(msg)
    pcall(function()
        local TextChatService = game:GetService("TextChatService")
        if TextChatService.ChatVersion == Enum.ChatVersion.TextChatService then
            TextChatService.TextChannels.RBXGeneral:SendAsync(msg)
        else
            ReplicatedStorage.DefaultChatSystemChatEvents.SayMessageRequest:FireServer(msg, "All")
        end
    end)
end

local function FWC(Parent, Name, Time) 
    return Parent:FindFirstChild(Name) or Parent:WaitForChild(Name, Time or 3) 
end

-- ------------------------------------------
-- [Logic] Blobman / Aura
-- ------------------------------------------
local function refreshBlobman()
    local found = nil
    for _, v in ipairs(Workspace:GetDescendants()) do
        if v.Name == "CreatureBlobman" and v:FindFirstChild("VehicleSeat") then
            local seat = v.VehicleSeat
            local weld = seat and seat:FindFirstChild("SeatWeld")
            if weld and weld.Part1 and weld.Part1:IsDescendantOf(LocalPlayer.Character) then
                found = v
                break
            end
        end
    end
    cachedBlobman = found
    if not found then
        cachedCG, cachedCD, cachedCR = nil, nil, nil
        cachedR_Det, cachedR_Weld, cachedL_Det, cachedL_Weld = nil, nil, nil, nil
        return
    end

    local s1 = found:FindFirstChild("BlobmanSeatAndOwnerScript")
    local s2 = found:FindFirstChild("BlobmanSeatAndOwnerScript[old]")

    cachedCG = (s1 and s1:FindFirstChild("CreatureGrab")) or (s2 and s2:FindFirstChild("CreatureGrab")) or found:FindFirstChild("CreatureGrab", true)
    cachedCD = (s1 and s1:FindFirstChild("CreatureDrop")) or (s2 and s2:FindFirstChild("CreatureDrop")) or found:FindFirstChild("CreatureDrop", true)
    cachedCR = (s1 and s1:FindFirstChild("CreatureRelease")) or (s2 and s2:FindFirstChild("CreatureRelease")) or found:FindFirstChild("CreatureRelease", true)

    cachedR_Det = found:FindFirstChild("RightDetector")
    cachedR_Weld = cachedR_Det and (cachedR_Det:FindFirstChild("RightWeld") or cachedR_Det:FindFirstChildWhichIsA("Weld") or cachedR_Det:FindFirstChildWhichIsA("JointInstance"))

    cachedL_Det = found:FindFirstChild("LeftDetector")
    cachedL_Weld = cachedL_Det and (cachedL_Det:FindFirstChild("LeftWeld") or cachedL_Det:FindFirstChildWhichIsA("Weld") or cachedL_Det:FindFirstChildWhichIsA("JointInstance"))
end

pcall(refreshBlobman)
Workspace.DescendantAdded:Connect(function(d)
    if d.Name == "CreatureBlobman" or d.Name == "SeatWeld" then
        task.defer(refreshBlobman)
    end
end)
Workspace.DescendantRemoving:Connect(function(d)
    if d == cachedBlobman or d.Name == "SeatWeld" then
        task.defer(refreshBlobman)
    end
end)

local function stopThreads(userId)
    local st = playerThreads[userId]
    if st then
        st.active = false
        playerThreads[userId] = nil
    end
end

local function startThreads(player, userId)
    stopThreads(userId)
    local state = { active = true }
    playerThreads[userId] = state

    local grabConn
    grabConn = RunService.Heartbeat:Connect(function()
        if not state.active then grabConn:Disconnect(); return end
        if not cachedCG then return end
        local char = player.Character
        if not char then return end
        local pHRP = char:FindFirstChild("HumanoidRootPart")
        if not pHRP then return end
        
        pcall(function()
            if cachedR_Det then
                cachedCG:FireServer(cachedR_Det, pHRP, cachedR_Weld)
                cachedR_Weld = cachedR_Det:FindFirstChild("RightWeld") or cachedR_Det:FindFirstChildWhichIsA("Weld") or cachedR_Det:FindFirstChildWhichIsA("JointInstance")
                if cachedCR and cachedR_Weld then cachedCR:FireServer(cachedR_Weld) end
                if cachedCD and cachedR_Weld then cachedCD:FireServer(cachedR_Weld) end
            end
            if cachedL_Det then
                cachedCG:FireServer(cachedL_Det, pHRP, cachedL_Weld)
                cachedL_Weld = cachedL_Det:FindFirstChild("LeftWeld") or cachedL_Det:FindFirstChildWhichIsA("Weld") or cachedL_Det:FindFirstChildWhichIsA("JointInstance")
                if cachedCR and cachedL_Weld then cachedCR:FireServer(cachedL_Weld) end
                if cachedCD and cachedL_Weld then cachedCD:FireServer(cachedL_Weld) end
            end
        end)
    end)

    local killConn
    killConn = RunService.Heartbeat:Connect(function()
        if not state.active then killConn:Disconnect(); return end
        local char = player.Character
        if not char then return end
        local hum = char:FindFirstChildOfClass("Humanoid")
        if not hum then return end
        pcall(function()
            hum.Health = 0
            hum:ChangeState(Enum.HumanoidStateType.Dead)
        end)
    end)
end

-- ------------------------------------------
-- [Logic] 20 Stack Mount Kill Methods
-- ------------------------------------------
local function bm_SpawnBlobman()
    if bm_currentBlobman and bm_currentBlobman.Parent then
        pcall(function() bm_currentBlobman:Destroy() end)
    end
    bm_currentBlobman = nil

    local char = LocalPlayer.Character
    if not char or not char:FindFirstChild("HumanoidRootPart") then return false end
    local root = char.HumanoidRootPart
    bm_originalCFrame = root.CFrame

    local spawnPos = root.CFrame * CFrame.new(0, BM_MY_HEIGHT, -5)
    local success = pcall(function()
        ReplicatedStorage.MenuToys.SpawnToyRemoteFunction:InvokeServer("CreatureBlobman", spawnPos, Vector3.new(0, 127, 0))
    end)
    if not success then return false end

    for _ = 1, 20 do
        bm_currentBlobman = workspace:FindFirstChild(LocalPlayer.Name.."SpawnedInToys", true)
            and workspace[LocalPlayer.Name.."SpawnedInToys"]:FindFirstChild("CreatureBlobman")
        if bm_currentBlobman then break end
        task.wait(0.01)
    end
    if not bm_currentBlobman then return false end

    pcall(function()
        local seat = bm_currentBlobman:FindFirstChild("VehicleSeat") or Instance.new("VehicleSeat", bm_currentBlobman)
        seat.Name = "MyMountSeat"
        seat.CFrame = CFrame.new(0, BM_MY_HEIGHT, 0)
        seat.HeadOffset = Vector3.new(0, BM_MY_HEIGHT + 1, 0)
        seat.MaxSpeed = 0
        seat.Torque = 0

        local hum = char:FindFirstChildOfClass("Humanoid")
        if hum and hum.Health > 0 then
            seat:Sit(hum)
            hum.JumpPower = 0
            hum.PlatformStand = true
        end

        if bm_currentBlobman.PrimaryPart then
            bm_currentBlobman.PrimaryPart.CanCollide = false
            bm_currentBlobman.PrimaryPart.Anchored = false
            bm_currentBlobman.PrimaryPart.Massless = true
        end
    end)
    return true
end

local function bm_KeepMounted()
    if bm_mountConn then bm_mountConn:Disconnect() end
    bm_mountConn = RunService.RenderStepped:Connect(function()
        if not bm_isRunning or not bm_currentBlobman then return end
        local char = LocalPlayer.Character
        if not char then return end
        local hum = char:FindFirstChildOfClass("Humanoid")
        local seat = bm_currentBlobman:FindFirstChild("MyMountSeat")
        if hum and seat and not seat.Occupant then
            pcall(function() seat:Sit(hum) end)
        end
    end)
end

local function bm_StartContinuousGrab(targetRoot)
    if bm_grabConn then bm_grabConn:Disconnect() end
    bm_grabConn = RunService.RenderStepped:Connect(function()
        if not bm_isRunning or not bm_currentBlobman then return end

        local targetPlayer = Players:FindFirstChild(selectedActionTargetName)
        local validRoot = nil
        if targetPlayer and targetPlayer.Character then
            validRoot = targetPlayer.Character:FindFirstChild("HumanoidRootPart")
            if validRoot then bm_lastTargetPos = validRoot.Position end
        end

        pcall(function()
            local s = bm_currentBlobman:FindFirstChild("BlobmanSeatAndOwnerScript")
            local grab = s and s:FindFirstChild("CreatureGrab")
            local release = s and s:FindFirstChild("CreatureRelease")
            local det = bm_currentBlobman:FindFirstChild("LeftDetector")
            local weld = det and det:FindFirstChild("LeftWeld")

            if grab and release and det and weld then
                local sendTarget = validRoot or {
                    Position = bm_lastTargetPos,
                    Name = "TempTarget",
                    Parent = workspace
                }
                grab:FireServer(det, sendTarget, weld)
                release:FireServer(weld)
            end
        end)
    end)
end

local function bm_SetupRespawnMonitor(targetPlayer)
    if bm_respawnConn then bm_respawnConn:Disconnect() end
    if not targetPlayer then return end

    bm_respawnConn = targetPlayer.CharacterAdded:Connect(function(newChar)
        task.wait(0.3)
        if not bm_isRunning then return end
        local newRoot = newChar:WaitForChild("HumanoidRootPart", 10)
        if newRoot then
            bm_lastTargetPos = newRoot.Position
            if not bm_currentBlobman or not bm_currentBlobman.Parent then bm_SpawnBlobman() end
            bm_StartContinuousGrab(newRoot)
            OrionLib:MakeNotification({Name="Grab Recovered", Content="Continuing after death", Time=1})
        end
    end)

    if bm_localRespawnConn then bm_localRespawnConn:Disconnect() end
    bm_localRespawnConn = LocalPlayer.CharacterAdded:Connect(function()
        task.wait(0.5)
        if bm_isRunning then bm_SpawnBlobman(); bm_KeepMounted() end
    end)
end

local function bm_ProcessCycle()
    if not bm_isRunning or bm_rotationSpeed <= 0 then return end
    local targetPlayer = Players:FindFirstChild(selectedActionTargetName)

    if not bm_currentBlobman or not bm_currentBlobman.Parent then
        if bm_SpawnBlobman() then
            bm_StartContinuousGrab(targetPlayer and targetPlayer.Character and targetPlayer.Character:FindFirstChild("HumanoidRootPart") or nil)
            bm_KeepMounted()
        else return end
    end

    bm_angle += math.rad(bm_rotationSpeed * 0.8)
    local offsetX = math.sin(bm_angle) * bm_circleRadius
    local offsetZ = math.cos(bm_angle) * bm_circleRadius
    local newPosition = bm_lastTargetPos + Vector3.new(offsetX, 0, offsetZ)
    local lookDir = (bm_lastTargetPos - newPosition).Unit
    
    if lookDir.Magnitude > 0 then
        pcall(function()
            bm_currentBlobman:SetPrimaryPartCFrame(CFrame.new(newPosition, newPosition + lookDir))
        end)
    end

    if targetPlayer and targetPlayer.Character then
        local tHum = targetPlayer.Character:FindFirstChildOfClass("Humanoid")
        if tHum and tHum.Health > 0 then
            pcall(function()
                tHum.BreakJointsOnDeath = true
                tHum.MaxHealth = 1
                tHum.Health = -999999
                tHum:TakeDamage(9999)
                tHum:ChangeState(Enum.HumanoidStateType.Dead)
            end)
        end
    end
end

-- ------------------------------------------
-- [Logic] Kill Aura
-- ------------------------------------------
local function stopAura()
    bmkAuraEnabled = false
    if auraConn then auraConn:Disconnect(); auraConn = nil end
    for uid in pairs(auraInRange) do stopThreads(uid) end
    auraInRange = {}
end

local function startAura()
    if auraConn then auraConn:Disconnect(); auraConn = nil end
    auraInRange = {}
    
    auraConn = RunService.Heartbeat:Connect(function()
        if not bmkAuraEnabled then stopAura(); return end
        local myHRP = HRP()
        if not myHRP then return end
        local myPos = myHRP.Position
        
        local nowInRange = {}
        for _, p in ipairs(Players:GetPlayers()) do
            if p == LocalPlayer then continue end
            local char = p.Character
            local pHRP = char and char:FindFirstChild("HumanoidRootPart")
            if pHRP then
                if (myPos - pHRP.Position).Magnitude > AURA_RADIUS then
                    if auraInRange[p.UserId] then stopThreads(p.UserId) end
                    continue
                end
            elseif not auraInRange[p.UserId] then
                continue
            end
            
            nowInRange[p.UserId] = true
            if not auraInRange[p.UserId] then startThreads(p, p.UserId) end
        end
        
        for uid in pairs(auraInRange) do
            if not nowInRange[uid] then stopThreads(uid) end
        end
        auraInRange = nowInRange
    end)
end

-- ------------------------------------------
-- [Logic] Kick All
-- ------------------------------------------
local function KickAll()
    if isActive then return end
    isActive = true

    local allPlayers = {}
    for _, p in ipairs(Players:GetPlayers()) do
        if p ~= LocalPlayer then
            if ExcludeFriends and LocalPlayer:IsFriendsWith(p.UserId) then continue end
            table.insert(allPlayers, p)
        end
    end
    if #allPlayers == 0 then isActive = false; return end

    local rootPart = HRP()
    if rootPart then
        local spawnPos = rootPart.CFrame * CFrame.new(0, 0, -5)
        ReplicatedStorage.MenuToys.SpawnToyRemoteFunction:InvokeServer("CreatureBlobman", spawnPos, Vector3.new(0, 127, 0))
    end
    task.wait(0.5)

    currentBlob = Workspace:FindFirstChild(LocalPlayer.Name .. "SpawnedInToys") and Workspace:FindFirstChild(LocalPlayer.Name .. "SpawnedInToys"):FindFirstChild("CreatureBlobman")
    if not currentBlob then isActive = false; return end

    local vehicleSeat = currentBlob:FindFirstChild("VehicleSeat")
    if vehicleSeat and LocalPlayer.Character then
        vehicleSeat:Sit(LocalPlayer.Character:FindFirstChildOfClass("Humanoid"))
    end
    task.wait(0.3)

    local myRoot = HRP()
    if not myRoot then isActive = false; return end

    for _, targetPlayer in ipairs(allPlayers) do
        local targetRoot = targetPlayer.Character and targetPlayer.Character:FindFirstChild("HumanoidRootPart")
        if targetRoot then
            myRoot.CFrame = targetRoot.CFrame
            task.wait(0.02)
            for i = 1, 3 do
                pcall(function()
                    currentBlob.BlobmanSeatAndOwnerScript.CreatureGrab:FireServer(currentBlob.LeftDetector, targetRoot, currentBlob.LeftDetector.LeftWeld)
                    currentBlob.BlobmanSeatAndOwnerScript.CreatureRelease:FireServer(currentBlob.LeftDetector.LeftWeld)
                end)
                if i < 3 then task.wait(0.08) end
            end
        end
    end

    myRoot.CFrame = CFrame.new(0, 100, 0)
    task.wait(0.1)

    for _, part in ipairs(currentBlob:GetDescendants()) do
        if part:IsA("BasePart") then pcall(function() part.Anchored = true end) end
    end
    task.wait(0.1)

    local radius = 15
    for i, targetPlayer in ipairs(allPlayers) do
        local targetRoot = targetPlayer.Character and targetPlayer.Character:FindFirstChild("HumanoidRootPart")
        if targetRoot then
            local angle = math.rad((i - 1) * (360 / #allPlayers))
            local x = radius * math.cos(angle)
            local z = radius * math.sin(angle)
            targetRoot.CFrame = CFrame.new(x, 110, z)
        end
    end
    task.wait(0.1)

    for _ = 1, 2 do
        for _, targetPlayer in ipairs(allPlayers) do
            local targetRoot = targetPlayer.Character and targetPlayer.Character:FindFirstChild("HumanoidRootPart")
            if targetRoot then
                pcall(function()
                    if SetNetworkOwner then SetNetworkOwner:FireServer(targetRoot, CFrame.new(targetRoot.Position)) end
                    if DestroyGrabLine then DestroyGrabLine:FireServer(targetRoot) end
                end)
            end
        end
        task.wait(0.1)
    end
    task.wait(0.3)

    for _, targetPlayer in ipairs(allPlayers) do
        local targetRoot = targetPlayer.Character and targetPlayer.Character:FindFirstChild("HumanoidRootPart")
        if targetRoot then
            pcall(function()
                currentBlob.BlobmanSeatAndOwnerScript.CreatureGrab:FireServer(currentBlob.LeftDetector, targetRoot, currentBlob.LeftDetector.LeftWeld)
                currentBlob.BlobmanSeatAndOwnerScript.CreatureGrab:FireServer(currentBlob.RightDetector, targetRoot, currentBlob.RightDetector.RightWeld)
            end)
        end
    end

    for _, part in ipairs(currentBlob:GetDescendants()) do
        if part:IsA("BasePart") then pcall(function() part.Anchored = false end) end
    end

    isActive = false
end

-- ------------------------------------------
-- [Logic] Grab
-- ------------------------------------------
Workspace.ChildAdded:Connect(function(model)
    if model.Name == "GrabParts" then
        task.wait()
        local grabPart = model:FindFirstChild("GrabPart")
        local weld = grabPart and grabPart:FindFirstChild("WeldConstraint")
        local target = weld and weld.Part1
        if not target then return end

        local targetChar = target.Parent
        if GrabMode.Kill and targetChar:FindFirstChild("Humanoid") then
            targetChar:BreakJoints()
        end

        local bv = Instance.new("BodyVelocity")
        bv.MaxForce = Vector3.new(0, math.huge, 0)
        bv.Parent = target

        if GrabMode.Sky then
            bv.Velocity = Vector3.new(0, 20, 0)
        elseif GrabMode.Down then
            bv.Velocity = Vector3.new(0, -20, 0)
        else
            bv:Destroy()
        end

        if GrabMode.Noclip then
            for _, p in pairs(targetChar:GetChildren()) do
                if p:IsA("BasePart") then p.CanCollide = false end
            end
        end

        model.AncestryChanged:Connect(function(_, parent)
            if not parent then
                if bv and bv.Parent then bv:Destroy() end
                if throwEnabled and target and target.Parent then
                    local throwV = Instance.new("BodyVelocity")
                    throwV.Name = "ThrowForce"
                    throwV.MaxForce = Vector3.new(math.huge, math.huge, math.huge)
                    throwV.Velocity = Workspace.CurrentCamera.CFrame.LookVector * throwStrength
                    throwV.Parent = target
                    Debris:AddItem(throwV, 1)
                end
                if GrabMode.Noclip and targetChar then
                    for _, p in pairs(targetChar:GetChildren()) do
                        if p:IsA("BasePart") then p.CanCollide = true end
                    end
                end
            end
        end)
    end
end)

-- ------------------------------------------
-- [Logic] Anti Explosion
-- ------------------------------------------
local function setupAntiExplosion(char)
    if not char then return end
    local hum = char:WaitForChild("Humanoid", 5)
    if not hum then return end

    local ragdolled = hum:FindFirstChild("Ragdolled")
    if ragdolled and ragdolled:IsA("BoolValue") then
        if antiExplosionConn then antiExplosionConn:Disconnect() end
        antiExplosionConn = ragdolled:GetPropertyChangedSignal("Value"):Connect(function()
            local anchored = ragdolled.Value
            for _, part in ipairs(char:GetChildren()) do
                if part:IsA("BasePart") then part.Anchored = anchored end
            end
        end)
    end
end

-- ------------------------------------------
-- [Logic] Object Aura
-- ------------------------------------------
local function applyPhysics(part, pos, rot)
    if not part or not part.Parent then return end
    pcall(function()
        if SetNetworkOwner then SetNetworkOwner:FireServer(part, part.CFrame) end
    end)
    local bp = part:FindFirstChild("AuraPos") or Instance.new("BodyPosition", part)
    bp.Name = "AuraPos"
    bp.P = 150000
    bp.MaxForce = Vector3.new(math.huge, math.huge, math.huge)
    bp.Position = pos

    local bg = part:FindFirstChild("AuraGyro") or Instance.new("BodyGyro", part)
    bg.Name = "AuraGyro"
    bg.P = 50000
    bg.MaxTorque = Vector3.new(math.huge, math.huge, math.huge)
    bg.CFrame = rot

    part.Anchored = false
    part.CanCollide = false
end

Mouse.Button1Down:Connect(function()
    if collectionMethod ~= "Manual Tap" then return end
    local target = Mouse.Target
    if target and target:IsA("BasePart") then
        if target.Name == targetObjectName or (target.Parent and target.Parent.Name == targetObjectName) then
            if not table.find(manualList, target) then
                table.insert(manualList, target)
                OrionLib:MakeNotification({
                    Name = "Success",
                    Content = targetObjectName .. " added to manual list",
                    Time = 2
                })
            end
        end
    end
end)

local function getAutoItems()
    local found = {}
    if collectionMethod ~= "Auto Collect" then return found end
    for _, player in ipairs(Players:GetPlayers()) do
        local folder = Workspace:FindFirstChild(player.Name .. "SpawnedInToys")
        if folder then
            for _, toy in ipairs(folder:GetChildren()) do
                if toy.Name == targetObjectName then
                    local base = toy:FindFirstChildWhichIsA("BasePart")
                    if base then table.insert(found, base) end
                end
            end
        end
    end
    return found
end

task.spawn(function()
    while true do
        if currentEffect ~= "None" then
            local currentToys = {}
            if collectionMethod == "Auto Collect" then
                currentToys = getAutoItems()
            else
                for i = #manualList, 1, -1 do
                    local p = manualList[i]
                    if p and p.Parent then
                        table.insert(currentToys, p)
                    else
                        table.remove(manualList, i)
                    end
                end
            end

            local targetPlayerObj = Players:FindFirstChild(auraTargetPlayerName) or LocalPlayer
            local root = targetPlayerObj.Character and targetPlayerObj.Character:FindFirstChild("HumanoidRootPart")

            if root and #currentToys > 0 then
                local timeSec = os.clock()
                if currentEffect == "Ring" then
                    for i, part in ipairs(currentToys) do
                        local angle = math.rad((i / #currentToys) * 360 + (timeSec * AuraObjConfig.OrbitSpeed))
                        local targetPos = root.Position + Vector3.new(math.cos(angle) * AuraObjConfig.Radius, AuraObjConfig.Height, math.sin(angle) * AuraObjConfig.Radius)
                        applyPhysics(part, targetPos, root.CFrame)
                    end
                elseif currentEffect == "Wing" then
                    local maxSide = math.max(1, math.ceil(#currentToys / 2))
                    for i, part in ipairs(currentToys) do
                        local isLeft = (i % 2 == 0)
                        local sideIdx = math.ceil(i / 2)
                        local wave = math.sin(timeSec * AuraObjConfig.Wing.flapSpeed) * (AuraObjConfig.Wing.flapAmp * (sideIdx/maxSide))
                        local xOffset = (isLeft and -1 or 1) * (AuraObjConfig.Wing.spread + (sideIdx * AuraObjConfig.Wing.spacing))
                        local targetCF = root.CFrame * CFrame.new(xOffset, 2 + wave, 2)
                        applyPhysics(part, targetCF.Position, targetCF)
                    end
                elseif currentEffect == "UpDown" then
                    local wave = math.sin(timeSec * AuraObjConfig.UpDown.speed) * AuraObjConfig.UpDown.amp
                    for i, part in ipairs(currentToys) do
                        local angle = math.rad((i / #currentToys) * 360 + (timeSec * AuraObjConfig.OrbitSpeed))
                        local targetPos = root.Position + Vector3.new(math.cos(angle) * AuraObjConfig.Radius, AuraObjConfig.Height + wave, math.sin(angle) * AuraObjConfig.Radius)
                        applyPhysics(part, targetPos, root.CFrame)
                    end
                end
            end
        end
        task.wait()
    end
end)

-- ------------------------------------------
-- [Logic] Reskill (execute_sequence)
-- ------------------------------------------
RunService.Stepped:Connect(function()
    if noclip_reskill and LocalPlayer.Character then
        for _, p in pairs(LocalPlayer.Character:GetDescendants()) do
            if p:IsA("BasePart") then p.CanCollide = false end
        end
    end
end)

local function safe_release(targetPart)
    if not targetPart then return end
    for i = 1, 3 do
        if DestroyGrabLine then DestroyGrabLine:FireServer(targetPart) end
        task.wait(0.01)
    end
end

local function execute_sequence(target)
    pcall(function()
        if not target or not target.Character then return end
        local myChar = LocalPlayer.Character
        local myHRP = myChar and myChar:FindFirstChild("HumanoidRootPart")
        local targetChar = target.Character
        local targetPart = targetChar:FindFirstChild("Torso") or targetChar:FindFirstChild("HumanoidRootPart")
        local targetHum = targetChar:FindFirstChild("Humanoid")
        local targetHead = targetChar:FindFirstChild("Head")

        if myHRP and targetPart and targetHum and targetHum.Health > 0 then
            local originalPos = myHRP.CFrame
            noclip_reskill = true
            myHRP.Velocity = Vector3.zero
            myHRP.CFrame = targetPart.CFrame * CFrame.new(0, 0.5, -2)
            task.wait(0.15)
            
            if SetNetworkOwner and targetHead then SetNetworkOwner:FireServer(targetHead, myHRP.CFrame) end
            
            local grabOffset = CFrame.new(0.648761749, 0.748010159, -0.5, -0.580110908, 0, 0.814537942, 9.71004894e-08, 1, 6.91546092e-08, -0.814537942, 5.96046448e-08, -0.580110908)
            if CreateGrabLine then CreateGrabLine:FireServer(targetPart, grabOffset) end
            if ExtendGrabLine then ExtendGrabLine:FireServer(3.955392599105835) end
            
            targetChar:BreakJoints()
            task.wait(0.3)
            safe_release(targetPart)
            task.wait(0.1)
            
            myHRP.CFrame = originalPos
            noclip_reskill = false
        end
    end)
end

-- ------------------------------------------
-- [Logic] New Anti Systems (Gucci & Train & Blobman)
-- ------------------------------------------
local function grab_network(prt) 
    ReplicatedStorage.GrabEvents.SetNetworkOwner:FireServer(prt, prt.CFrame) 
end

local function toy_spawn_gucci(name, cframe, vector)
    local ToySpawn = ReplicatedStorage.MenuToys.SpawnToyRemoteFunction
    local InPlot = LocalPlayer:WaitForChild("InPlot")
    local InOwnerPlot = LocalPlayer:WaitForChild("InOwnedPlot")
    local CanSpawn = LocalPlayer:WaitForChild("CanSpawnToy")

    while InPlot.Value and not InOwnerPlot.Value and not CanSpawn.Value do
        task.wait(0.01)
    end

    task.spawn(function()
        ToySpawn:InvokeServer(name, cframe, vector or Vector3.new())
    end)
    
    local BackPack = Workspace:FindFirstChild(LocalPlayer.Name .. 'SpawnedInToys')
    if not BackPack then return nil end
    
    local SpawnedToy = nil
    local connection
    connection = BackPack.ChildAdded:Connect(function(toy)
        if toy.Name == name and toy:IsA("Model") then
            SpawnedToy = toy
            connection:Disconnect()
        end
    end)
    
    local startTick = tick()
    while not SpawnedToy do
        if tick() - startTick > 2 then
            if connection then connection:Disconnect() end
            return nil
        end
        task.wait(0.01)
    end
    return SpawnedToy
end

local function GucciAntiGrab()
    gucciRunId = gucciRunId + 1
    local MyId = gucciRunId
    
    local char = LocalPlayer.Character or LocalPlayer.CharacterAdded:Wait()
    local hum = FWC(char, "Humanoid")
    local hrp = FWC(char, "HumanoidRootPart")
    
    OrionLib:MakeNotification({
        Name = "GUCCI",
        Content = "Executing Gucci Anti-Grab...",
        Time = 2,
        Image = "rbxassetid://4483345998"
    })

    hum.Sit = true
    task.wait(0.02)
    hum.Sit = false
    
    task.spawn(function()
        local t = tick()
        while tick() - t < 0.8 do
            for _, v in pairs(char:GetChildren()) do
                if v:IsA('BasePart') then v.Velocity = Vector3.new() end
            end
            task.wait(0.01)
        end
    end)
    
    local Blob = toy_spawn_gucci(
        "CreatureBlobman",
        hrp.CFrame * CFrame.new(0, 0, -5),
        Vector3.new(0, -15.716, 0)
    )
    
    if not Blob then return end
    
    local BHead = FWC(Blob, "Head")
    local HitBox = FWC(Blob, "GrabbableHitbox")
    local Seat = FWC(Blob, "VehicleSeat")
    
    task.spawn(function()
        while MyId == gucciRunId and BHead and 
        (not BHead:FindFirstChild("PartOwner") or BHead.PartOwner.Value ~= LocalPlayer.Name) do
            grab_network(HitBox)
            task.wait(0.01)
        end
    end)
    
    local autoGucci = true
    task.spawn(function()
        local startTime = tick()
        while autoGucci and MyId == gucciRunId and tick() - startTime < 0.4 do
            if Blob and Blob.Parent then
                if Seat and Seat.Occupant ~= hum then
                    Seat:Sit(hum)
                end
            end
            task.wait(0.03)
            if char and hum then hum:ChangeState(Enum.HumanoidStateType.Jumping) end
        end
        autoGucci = false
    end)
    
    task.spawn(function()
        while autoGucci and MyId == gucciRunId do
            ReplicatedStorage.CharacterEvents.RagdollRemote:FireServer(hrp, 0.095)
            task.wait(0.01)
        end
    end)
    
    task.wait(0.5)
    if MyId ~= gucciRunId then return end
    
    hum.Sit = false
    Blob.Name = "Gucci"
    for _, v in pairs(Blob:GetChildren()) do
        if v:IsA("BasePart") then
            v.CanCollide = false
            v.CanTouch = false
            v.CanQuery = false
        end
    end
    
    task.spawn(function()
        while MyId == gucciRunId and Blob and BHead do
            BHead.CFrame = CFrame.new(BHead.Position.X, 1e5, BHead.Position.Z)
            task.wait(0.01)
        end
    end)
end

local function startAntiGucciTrain()
    local character = LocalPlayer.Character or LocalPlayer.CharacterAdded:Wait()
    local humanoid = character:WaitForChild("Humanoid")
    local rootPart = character:WaitForChild("HumanoidRootPart")
    safePositionTrain = rootPart.Position
    
    local folder = Workspace:FindFirstChild("Map") and Workspace.Map:FindFirstChild("AlwaysHereTweenedObjects")
    local train = folder and folder:FindFirstChild("Train")
    local seat
    if train then
        for _, d in ipairs(train:GetDescendants()) do
            if d:IsA("Seat") then
                seat = d
                break
            end
        end
    end
    
    if seat then
        rootPart.CFrame = seat.CFrame + Vector3.new(0, 2, 0)
        seat:Sit(humanoid)
    end
    
    humanoid:GetPropertyChangedSignal("Jump"):Connect(function()
        if humanoid.Jump and humanoid.Sit then
            restoreFramesTrain = 15
            safePositionTrain = rootPart.Position
        end
    end)
    
    if antiGucciConnectionTrain then
        antiGucciConnectionTrain:Disconnect()
    end
    
    antiGucciConnectionTrain = RunService.Heartbeat:Connect(function()
        if not rootPart or not humanoid then return end
        
        if ReplicatedStorage:FindFirstChild("CharacterEvents") and ReplicatedStorage.CharacterEvents:FindFirstChild("RagdollRemote") then
            ReplicatedStorage.CharacterEvents.RagdollRemote:FireServer(rootPart, 0)
        end
        
        if restoreFramesTrain > 0 then
            rootPart.CFrame = CFrame.new(safePositionTrain)
            restoreFramesTrain = restoreFramesTrain - 1
        end
    end)
    
    task.spawn(function()
        while humanoid.Sit do
            task.wait(1)
        end
        task.wait(0.5)
        rootPart.CFrame = CFrame.new(safePositionTrain)
    end)
end

local function stopAntiGucciTrain()
    if antiGucciConnectionTrain then
        antiGucciConnectionTrain:Disconnect()
        antiGucciConnectionTrain = nil
    end
    local trainFolder = Workspace:FindFirstChild("Map") and Workspace.Map:FindFirstChild("AlwaysHereTweenedObjects")
    if trainFolder and trainFolder:FindFirstChild("Train") then
        local character = LocalPlayer.Character
        if character and character:FindFirstChild("Humanoid") then
            character.Humanoid.Health = 0 
        end
    end
end

local function AntiBlobmanKill()
    while antiActive do
        local char = LocalPlayer.Character
        if char then
            local hum = char:FindFirstChild("Humanoid")
            local hrp = char:FindFirstChild("HumanoidRootPart")
            
            if hum and hrp and hum.Health > 0 then
                hum.Sit = true
                hum:ChangeState(Enum.HumanoidStateType.Running)
                
                local camera = workspace.CurrentCamera
                if camera then
                    local lookVec = camera.CFrame.LookVector
                    hrp.CFrame = CFrame.new(hrp.Position, hrp.Position + Vector3.new(lookVec.X, 0, lookVec.Z))
                end
            end
        end
        task.wait()
    end
end

-- ------------------------------------------
-- [Logic] Visuals (ESP / Tracers)
-- ------------------------------------------
local function CreateTracer(player)
    local line
    pcall(function() line = Drawing.new("Line") end)
    if not line then return end

    line.Visible = false
    line.Color = Color3.new(1, 0, 0)
    line.Thickness = 1
    line.Transparency = 1

    RunService.RenderStepped:Connect(function()
        if ESP_Settings.Enabled and ESP_Settings.Lines and player.Character and player.Character:FindFirstChild("HumanoidRootPart") then
            local hrp = player.Character.HumanoidRootPart
            local vector, onScreen = Camera:WorldToViewportPoint(hrp.Position)
            if onScreen then
                line.From = Vector2.new(Camera.ViewportSize.X / 2, Camera.ViewportSize.Y)
                line.To = Vector2.new(vector.X, vector.Y)
                line.Visible = true
            else
                line.Visible = false
            end
        else
            line.Visible = false
        end
    end)
end

local function CreateNameTag(player)
    if player == LocalPlayer then return end
    local function setup(char)
        local head = char:WaitForChild("Head", 10)
        if not head then return end

        local billboard = Instance.new("BillboardGui", head)
        billboard.Name = "ESP_UI"
        billboard.Size = UDim2.new(0, 100, 0, 50)
        billboard.StudsOffset = Vector3.new(0, 3, 0)
        billboard.AlwaysOnTop = true
        billboard.Enabled = ESP_Settings.Enabled

        local icon = Instance.new("ImageLabel", billboard)
        icon.Size = UDim2.new(0, 40, 0, 40)
        icon.Position = UDim2.new(0.5, -20, 0, -35)
        icon.BackgroundTransparency = 1
        
        task.spawn(function()
            local success, content = pcall(function()
                return Players:GetUserThumbnailAsync(player.UserId, Enum.ThumbnailType.HeadShot, Enum.ThumbnailSize.Size420x420)
            end)
            if success and content then icon.Image = content end
        end)

        local name = Instance.new("TextLabel", billboard)
        name.Size = UDim2.new(1, 0, 0, 20)
        name.Position = UDim2.new(0, 0, 0, 5)
        name.BackgroundTransparency = 1
        name.Text = player.DisplayName
        name.TextColor3 = Color3.new(1, 1, 1)
        name.TextStrokeTransparency = 0
        name.TextScaled = true
    end
    if player.Character then setup(player.Character) end
    player.CharacterAdded:Connect(setup)
end

-- ------------------------------------------
-- [Logic] Minimap & Teleport
-- ------------------------------------------
local activeTouches = 0
UserInputService.TouchStarted:Connect(function() activeTouches = activeTouches + 1 end)
UserInputService.TouchEnded:Connect(function() activeTouches = math.max(0, activeTouches - 1) end)

MapFrame.InputBegan:Connect(function(input)
    if input.UserInputType == Enum.UserInputType.MouseButton1 or input.UserInputType == Enum.UserInputType.Touch then
        if activeTouches > 1 then return end
        
        local dragging = true
        local uiMoving = false
        local mapScrolling = false
        local pressTime = tick()
        local dragStartPos = input.Position
        local uiStartPos = MapFrame.Position
        local mapOffsetStart = mapOffset
        local moveCon, endCon

        moveCon = UserInputService.InputChanged:Connect(function(inp)
            if (inp.UserInputType == Enum.UserInputType.MouseMovement or inp.UserInputType == Enum.UserInputType.Touch) and dragging then
                if activeTouches > 1 then dragging = false; return end
                
                local delta = inp.Position - dragStartPos
                local elapsed = tick() - pressTime
                
                if not uiMoving and not mapScrolling then
                    if delta.Magnitude > 5 then
                        if elapsed > 0.25 then
                            mapScrolling = true
                        else
                            uiMoving = true
                        end
                    end
                end
                
                if uiMoving then
                    MapFrame.Position = UDim2.new(uiStartPos.X.Scale, uiStartPos.X.Offset + delta.X, uiStartPos.Y.Scale, uiStartPos.Y.Offset + delta.Y)
                elseif mapScrolling then
                    local relX = delta.X / MapFrame.AbsoluteSize.X
                    local relY = delta.Y / MapFrame.AbsoluteSize.Y
                    mapOffset = mapOffsetStart - Vector3.new(relX * zoomLevel, 0, relY * zoomLevel)
                end
            end
        end)

        endCon = UserInputService.InputEnded:Connect(function(inp)
            if inp.UserInputType == Enum.UserInputType.MouseButton1 or inp.UserInputType == Enum.UserInputType.Touch then
                if dragging then
                    dragging = false
                    if not uiMoving and not mapScrolling and (inp.Position - dragStartPos).Magnitude < 15 and LocalPlayer.Character then
                        local root = LocalPlayer.Character:FindFirstChild("HumanoidRootPart")
                        if root then
                            local relX = (inp.Position.X - MapFrame.AbsolutePosition.X) / MapFrame.AbsoluteSize.X - 0.5
                            local relY = (inp.Position.Y - MapFrame.AbsolutePosition.Y) / MapFrame.AbsoluteSize.Y - 0.5
                            local centerPos = root.Position + mapOffset
                            local targetX = centerPos.X + (relX * zoomLevel)
                            local targetZ = centerPos.Z + (relY * zoomLevel)
                            
                            local rayRes = Workspace:Raycast(Vector3.new(targetX, 1000, targetZ), Vector3.new(0, -2000, 0), mapRp)
                            local finalY = rayRes and rayRes.Position.Y or root.Position.Y
                            root.CFrame = CFrame.new(targetX, finalY + 4, targetZ)
                        end
                    end
                end
                moveCon:Disconnect()
                endCon:Disconnect()
            end
        end)
    end
end)

MapFrame.InputChanged:Connect(function(input)
    if input.UserInputType == Enum.UserInputType.MouseWheel then
        zoomLevel = math.clamp(zoomLevel + (input.Position.Z * -100), 50, 1500)
    end
end)

local initialZoom = zoomLevel
UserInputService.TouchPinch:Connect(function(touchPositions, scale, velocity, state, gameProcessed)
    if not MapFrame.Visible then return end
    if state == Enum.UserInputState.Begin then
        initialZoom = zoomLevel
    elseif state == Enum.UserInputState.Change then
        zoomLevel = math.clamp(initialZoom / scale, 50, 1500)
    end
end)

Players.PlayerRemoving:Connect(function(p)
    if playerDots[p.Name] then
        playerDots[p.Name]:Destroy()
        playerDots[p.Name] = nil
    end
end)

local function initRenderStep()
    RunService.RenderStepped:Connect(function()
        local char = LocalPlayer.Character
        local hrp = char and char:FindFirstChild("HumanoidRootPart")
        if not hrp then return end

        local centerPos = hrp.Position + mapOffset
        
        if MapFrame.Visible and (centerPos - lastScanPos).Magnitude > 4 then
            lastScanPos = centerPos
            mapRp.FilterDescendantsInstances = {char}
            
            for x = 1, gridRes do
                for y = 1, gridRes do
                    local offX = ((x - 1) / (gridRes - 1) - 0.5) * zoomLevel
                    local offZ = ((y - 1) / (gridRes - 1) - 0.5) * zoomLevel
                    local ray = Workspace:Raycast(centerPos + Vector3.new(offX, 100, offZ), Vector3.new(0, -200, 0), mapRp)
                    
                    if ray and ray.Instance then
                        local partColor = ray.Instance.Color
                        local h = math.clamp((ray.Position.Y - centerPos.Y + 30) / 60, 0.3, 1.2)
                        local r = math.clamp(partColor.R * 255 * h, 0, 255)
                        local g = math.clamp(partColor.G * 255 * h, 0, 255)
                        local b = math.clamp(partColor.B * 255 * h, 0, 255)
                        mapPixels[x][y].BackgroundColor3 = Color3.fromRGB(r, g, b)
                    else
                        mapPixels[x][y].BackgroundColor3 = Color3.fromRGB(15, 15, 20)
                    end
                end
            end
        end
        
        if MapFrame.Visible then
            for _, p in pairs(Players:GetPlayers()) do
                local pr = p.Character and p.Character:FindFirstChild("HumanoidRootPart")
                if pr then
                    local d = playerDots[p.Name]
                    if not d then
                        d = Instance.new("Frame", MapFrame)
                        d.Size = UDim2.new(0, 26, 0, 26)
                        d.AnchorPoint = Vector2.new(0.5, 0.5)
                        d.BackgroundTransparency = 1
                        d.ZIndex = 10
                        
                        local iconBg = Instance.new("Frame", d)
                        iconBg.Size = UDim2.new(1, 0, 1, 0)
                        iconBg.BackgroundColor3 = (p == LocalPlayer) and Color3.fromRGB(0, 255, 255) or Color3.fromRGB(255, 50, 50)
                        Instance.new("UICorner", iconBg).CornerRadius = UDim.new(1, 0)
                        
                        local icon = Instance.new("ImageLabel", iconBg)
                        icon.Size = UDim2.new(1, -4, 1, -4)
                        icon.Position = UDim2.new(0, 2, 0, 2)
                        icon.BackgroundTransparency = 1
                        Instance.new("UICorner", icon).CornerRadius = UDim.new(1, 0)
                        icon.ClipsDescendants = true
                        
                        task.spawn(function()
                            local success, url = pcall(function() return Players:GetUserThumbnailAsync(p.UserId, Enum.ThumbnailType.HeadShot, Enum.ThumbnailSize.Size48x48) end)
                            if success and url then icon.Image = url end
                        end)
                        
                        local nameLbl = Instance.new("TextLabel", d)
                        nameLbl.Size = UDim2.new(0, 100, 0, 12)
                        nameLbl.Position = UDim2.new(0.5, -50, 1, 2)
                        nameLbl.BackgroundTransparency = 1
                        nameLbl.Text = p.DisplayName
                        nameLbl.TextColor3 = Color3.fromRGB(255, 255, 255)
                        nameLbl.TextStrokeTransparency = 0.3
                        nameLbl.TextStrokeColor3 = Color3.fromRGB(0, 0, 0)
                        nameLbl.TextSize = 10
                        nameLbl.Font = Enum.Font.GothamBold
                        nameLbl.ZIndex = 11
                        
                        playerDots[p.Name] = d
                    end
                    
                    local rx = (pr.Position.X - centerPos.X) / zoomLevel
                    local rz = (pr.Position.Z - centerPos.Z) / zoomLevel
                    d.Position = UDim2.new(0.5 + rx, 0, 0.5 + rz, 0)
                    d.Visible = math.abs(rx) < 0.5 and math.abs(rz) < 0.5
                end
            end
        end
    end)
end

--
------------------------------------------
-- [Tab 1] Grab
-- ------------------------------------------
local GrabTab = Window:MakeTab({
    Name = "Combat",
    Icon = "rbxassetid://7485051715",
    PremiumOnly = false
})




GrabTab:AddSection({Name = "Strength Settings"})
GrabTab:AddToggle({ Name = "Super Strength", Default = false, Callback = function(Value) throwEnabled = Value end })
GrabTab:AddSlider({
    Name = "Strength",
    Min = 300,
    Max = 4000,
    Default = 400,
    Color = Color3.fromRGB(255, 60, 60),
    Increment = 1,
    ValueName = "Strength",
    Callback = function(Value)
        throwStrength = Value
    end
})

GrabTab:AddSection({Name = "Grab Modes"})
GrabTab:AddToggle({ Name = "Kill Grab", Default = false, Callback = function(Value) GrabMode.Kill = Value end })
GrabTab:AddToggle({ Name = "Sky Grab", Default = false, Callback = function(Value) GrabMode.Sky = Value end })
GrabTab:AddToggle({ Name = "Down Grab", Default = false, Callback = function(Value) GrabMode.Down = Value end })
GrabTab:AddToggle({ Name = "Noclip Grab", Default = false, Callback = function(Value) GrabMode.Noclip = Value end })

-- ------------------------------------------
-- [Tab 2] Anti (Defense System)
-- ------------------------------------------
local AntiTab = Window:MakeTab({
    Name = "Defense",
    Icon = "rbxassetid://7734056608",
    PremiumOnly = false
})

AntiTab:AddSection({Name = "Gucci Functions"})

AntiTab:AddToggle({
    Name = "Anti Gucci",
    Default = false,
    Callback = function(Value)
        if Value then
            task.spawn(GucciAntiGrab)
        else
            gucciRunId = gucciRunId + 1
        end
    end    
})

AntiTab:AddToggle({
    Name = "Train Gocci",
    Default = false,
    Callback = function(Value)
        autoGucciActiveTrain = Value
        if Value then
            startAntiGucciTrain()
            OrionLib:MakeNotification({
                Name = "System",
                Content = "Gucci active (monitoring)",
                Time = 3,
                Image = "rbxassetid://4483362458"
            })
            
            task.spawn(function()
                while autoGucciActiveTrain do
                    local trainFolder = Workspace:FindFirstChild("Map") and Workspace.Map:FindFirstChild("AlwaysHereTweenedObjects")
                    local trainExists = trainFolder and trainFolder:FindFirstChild("Train")
                    
                    if not trainExists then
                        stopAntiGucciTrain()
                        OrionLib:MakeNotification({
                            Name = "System",
                            Content = "Train lost",
                            Time = 3,
                            Image = "rbxassetid://4483362458"
                        })
                        
                        local retries = 0
                        repeat
                            task.wait(0.2)
                            retries = retries + 1
                            trainFolder = Workspace:FindFirstChild("Map") and Workspace.Map:FindFirstChild("AlwaysHereTweenedObjects")
                        until (trainFolder and trainFolder:FindFirstChild("Train")) or retries > 25 or not autoGucciActiveTrain
                        
                        if autoGucciActiveTrain and trainFolder and trainFolder:FindFirstChild("Train") then
                            startAntiGucciTrain()
                            OrionLib:MakeNotification({
                                Name = "System",
                                Content = "Train restored.",
                                Time = 3,
                                Image = "rbxassetid://4483362458"
                            })
                        end
                    end
                    task.wait(0.5)
                end
            end)
        else
            autoGucciActiveTrain = false
            stopAntiGucciTrain()
            OrionLib:MakeNotification({
                Name = "System",
                Content = "Gucci disabled.",
                Time = 3,
                Image = "rbxassetid://4483362458"
            })
        end
    end    
})

AntiTab:AddSection({Name = "Blobman Defence"})

AntiTab:AddToggle({
    Name = "Anti Blobman Kill",
    Default = false,
    Callback = function(Value)
        antiActive = Value
        if Value then
            antiTask = task.spawn(AntiBlobmanKill)
        else
            if antiTask then
                task.cancel(antiTask)
                antiTask = nil
            end
        end
    end
})

AntiTab:AddSection({Name = "Server Defence"})

AntiTab:AddToggle({
    Name = "Anti Barrier",
    Default = false,

    Callback = function(Value)
        print("Anti Barrier:", Value)
    end
})

AntiTab:AddButton({
    Name = "Anti kick",
    Callback = function()

        local plr = LocalPlayer
        local char = plr.Character or plr.CharacterAdded:Wait()
        local root = char:WaitForChild("HumanoidRootPart")
        local hum = char:WaitForChild("Humanoid")

        local serverPos = CFrame.new(-272.2197265625, 10, 475.0108947753906)

        -- 落下対策（NaN禁止）
        workspace.FallenPartsDestroyHeight = -500

        local oldCFrame = root.CFrame
        local oldState = hum:GetState()

        -- 死亡防止
        hum:SetStateEnabled(Enum.HumanoidStateType.Dead, false)

        root.CFrame = serverPos

        local conn
        conn = RunService.Heartbeat:Connect(function()

            if not root.Parent then
                conn:Disconnect()
                return
            end

            root.AssemblyLinearVelocity = Vector3.zero
            root.AssemblyAngularVelocity = Vector3.zero

        end)

        task.delay(1,function()

            if conn then
                conn:Disconnect()
            end

            if root and root.Parent then
                root.CFrame = oldCFrame
            end

            hum:SetStateEnabled(Enum.HumanoidStateType.Dead,true)
            hum:ChangeState(oldState)

        end)


        OrionLib:MakeNotification({
            Name = "Success",
            Content = "Anti kick executed",
            Image = "rbxassetid://4483362458",
            Time = 3
        })

    end
})

AntiTab:AddSection({Name = "Defense Features"})

AntiTab:AddToggle({
    Name = "Anti Kill",
    Default = false,

    Callback = function(Value)

        if spamConnection then
            spamConnection:Disconnect()
            spamConnection = nil
        end

        isHolding = false
        lastActionTime = 0

        if Value then

            OrionLib:MakeNotification({
                Name = "Anti Kill",
                Content = "Anti Kill ON",
                Time = 3
            })


            spamConnection = RunService.Heartbeat:Connect(function()

                local character = LocalPlayer.Character
                if not character then return end

                local hum = character:FindFirstChildOfClass("Humanoid")
                local root = character:FindFirstChild("HumanoidRootPart")

                if not hum or not root then return end

                -- 死亡寸前なら処理停止
                if hum.Health <= 5 then
                    isHolding = false
                    return
                end


                local folder = workspace:FindFirstChild(
                    LocalPlayer.Name.."SpawnedInToys"
                )

                local burger = folder and folder:FindFirstChild(
                    "FoodHamburger"
                )


                if not burger then

                    if os.clock() - lastActionTime > 1 then

                        pcall(function()

                            ReplicatedStorage.MenuToys
                            .SpawnToyRemoteFunction:InvokeServer(
                                "FoodHamburger",
                                root.CFrame * CFrame.new(0,4,0),
                                Vector3.zero
                            )

                        end)

                        lastActionTime = os.clock()
                    end


                else

                    if burger:FindFirstChild("HoldPart") then

                        pcall(function()

                            if not isHolding then

                                burger.HoldPart
                                .HoldItemRemoteFunction
                                :InvokeServer(
                                    burger,
                                    character
                                )

                                isHolding = true


                            else

                                burger.HoldPart
                                .DropItemRemoteFunction
                                :InvokeServer(
                                    burger,
                                    root.CFrame,
                                    Vector3.new(0,5,0)
                                )

                                isHolding = false

                            end

                        end)

                    end

                end

            end)

        end
    end
})

AntiTab:AddToggle({
    Name = "Fight Back",
    Default = false,
    Callback = function(Value)
        isFlghtBackEnabled = Value
        if isFlghtBackEnabled then
            task.spawn(function()
                while isFlghtBackEnabled do
                    local character = LocalPlayer.Character
                    if character and character:FindFirstChild("Head") then
                        local head = character.Head
                        local partOwner = head:FindFirstChild("PartOwner")
                        if partOwner and partOwner.Value ~= "" then
                            local attacker = Players:FindFirstChild(partOwner.Value)
                            if attacker and attacker.Character then
                                pcall(function()
                                    ReplicatedStorage.CharacterEvents.Struggle:FireServer()
                                    local attackerChar = attacker.Character
                                    local targetPart = attackerChar:FindFirstChild("Torso") or attackerChar:FindFirstChild("UpperTorso") or attackerChar:FindFirstChild("Head")
                                    if targetPart then
                                        if SetNetworkOwner then SetNetworkOwner:FireServer(targetPart, targetPart.CFrame) end
                                        task.wait()
                                        local velocity = targetPart:FindFirstChild("l") or Instance.new("BodyVelocity")
                                        velocity.Name = "l"
                                        velocity.Velocity = Vector3.new(0, 2000, 0)
                                        velocity.MaxForce = Vector3.new(0, math.huge, 0)
                                        velocity.Parent = targetPart
                                        Debris:AddItem(velocity, 0.5)
                                    end
                                end)
                            end
                        end
                    end
                    task.wait(0.1)
                end
            end)
        end
    end
})

AntiTab:AddToggle({
    Name = "Anti Lag",
    Default = false,
    Callback = function(Value)
        antiLagT = Value
        if LocalPlayer:FindFirstChild("PlayerScripts") and LocalPlayer.PlayerScripts:FindFirstChild("CharacterAndBeamMove") then
            LocalPlayer.PlayerScripts.CharacterAndBeamMove.Disabled = antiLagT
        end
    end
})

AntiTab:AddToggle({
    Name = "Anti Grab",
    Default = false,
    Callback = function(Value)
        _G.AntiGrab = Value
        if Value then
            _G.GrabLoop = RunService.Heartbeat:Connect(function()
                local char = LocalPlayer.Character
                if char and char:FindFirstChild("Head") and char.Head:FindFirstChild("PartOwner") then
                    ReplicatedStorage.CharacterEvents.Struggle:FireServer()
                    for _, p in pairs(char:GetChildren()) do
                        if p:IsA("BasePart") then p.Anchored = true end
                    end
                    task.wait(0.3)
                    for _, p in pairs(char:GetChildren()) do
                        if p:IsA("BasePart") then p.Anchored = false end
                    end
                end
            end)
        else
            if _G.GrabLoop then _G.GrabLoop:Disconnect() end
        end
    end
})

AntiTab:AddToggle({
    Name = "Anti Blobman",
    Default = false,
    Callback = function(Value)
        _G.AntiBlob = Value
        task.spawn(function()
            while _G.AntiBlob do
                for _, p in ipairs(Players:GetPlayers()) do
                    local st = Workspace:FindFirstChild(p.Name .. "SpawnedInToys")
                    if st then
                        for _, toy in ipairs(st:GetChildren()) do
                            if toy.Name == "CreatureBlobman" then
                                pcall(function()
                                    if toy:FindFirstChild("LeftDetector") then toy.LeftDetector:Destroy() end
                                    if toy:FindFirstChild("RightDetector") then toy.RightDetector:Destroy() end
                                end)
                            end
                        end
                    end
                end
                task.wait(0.5)
            end
        end)
    end
})

AntiTab:AddToggle({
    Name = "Anti Fire",
    Default = false,
    Callback = function(Value)
        _G.AntiBurn = Value
        task.spawn(function()
            while _G.AntiBurn do
                local char = LocalPlayer.Character
                if char and char:FindFirstChild("HumanoidRootPart") and char.HumanoidRootPart:FindFirstChild("FireLight") then
                    local st = Workspace:FindFirstChild(LocalPlayer.Name .. "SpawnedInToys")
                    local ext = st and st:FindFirstChild("FireExtinguisher")
                    if ext then
                        ext.ExtinguishPart.Position = char.HumanoidRootPart.Position
                    else
                        ReplicatedStorage.MenuToys.SpawnToyRemoteFunction:InvokeServer("FireExtinguisher", char.HumanoidRootPart.CFrame, Vector3.zero)
                    end
                end
                task.wait(0.1)
            end
        end)
    end
})

AntiTab:AddToggle({
    Name = "Anti Void",
    Default = false,
    Callback = function(Value)
        if Value then
            Workspace.FallenPartsDestroyHeight = 0/0
        else
            Workspace.FallenPartsDestroyHeight = -100
        end
    end
})

AntiTab:AddToggle({
    Name = "Anti Ragdoll",
    Default = false,
    Callback = function(Value)
        _G.AntiRagdoll = Value
        task.spawn(function()
            while _G.AntiRagdoll do
                local char = LocalPlayer.Character
                if char and char:FindFirstChild("Humanoid") and char.Humanoid.PlatformStand then
                    char.Humanoid.PlatformStand = false
                end
                task.wait(0.1)
            end
        end)
    end
})

-- ------------------------------------------
-- [Tab 3] Aura
-- ------------------------------------------

local CharacterTab = Window:MakeTab({
    Name = "Movements",
    Icon = "rbxassetid://7743871002",
    PremiumOnly = false
})

-- FPS
local FpsSection = CharacterTab:AddSection({ Name = "FPS" })
CharacterTab:AddSlider({
    Name = "FPS Cap",
    Min = 2,
    Max = 2000,
    Default = 300,
    Increment = 1,
    Color = Color3.fromRGB(255, 60, 60),
    Callback = function(fpsCap1)
        setfpscap(fpsCap1)
    end
})

-- Third Person
CharacterTab:AddButton({
    Name = "Third Person",
    Callback = function()
        LocalPlayer.CameraMaxZoomDistance = 8000000
        LocalPlayer.CameraMode = Enum.CameraMode.Classic
    end
})

-- FOV
CharacterTab:AddSlider({
    Name = "FOV",
    Min = 0,
    Max = 120,
    Default = 80,
    Increment = 1,
    Color = Color3.fromRGB(255, 60, 60),
    Callback = function(value)
        workspace.CurrentCamera.FieldOfView = value
    end
})

-- WalkSpeed
local WalkSpeedEnabled = false
local wss = 20

CharacterTab:AddToggle({
    Name = "Walk Speed",
    Default = false,
    Callback = function(Value)
        WalkSpeedEnabled = Value
    end
})

RunService.Heartbeat:Connect(function()
    if WalkSpeedEnabled and LocalPlayer.Character and LocalPlayer.Character:FindFirstChild("HumanoidRootPart") then
        local root = LocalPlayer.Character.HumanoidRootPart
        local hum = LocalPlayer.Character:FindFirstChild("Humanoid")
        if hum and hum.MoveDirection.Magnitude > 0 then
            root.CFrame = root.CFrame + hum.MoveDirection * (wss / 10)
        end
    end
end)

CharacterTab:AddSlider({
    Name = "WalkSpeed Value",
    Min = 0,
    Max = 200,
    Default = 20,
    Increment = 10,
    Color = Color3.fromRGB(255, 60, 60),
    Callback = function(value)
        wss = value
    end
})

-- Jump Power
local JumpPowerEnabled = false
local jumpPowerValue = 50

CharacterTab:AddToggle({
    Name = "Jump Power",
    Default = false,
    Callback = function(Value)
        JumpPowerEnabled = Value
        local hum = LocalPlayer.Character and LocalPlayer.Character:FindFirstChild("Humanoid")
        if hum then
            hum.JumpPower = Value and jumpPowerValue or 24
        end
    end
})

CharacterTab:AddSlider({
    Name = "Jump Power Value",
    Min = 0,
    Max = 1000,
    Default = 50,
    Increment = 10,
    Color = Color3.fromRGB(255, 60, 60),
    Callback = function(Value)
        jumpPowerValue = Value
        local hum = LocalPlayer.Character and LocalPlayer.Character:FindFirstChild("Humanoid")
        if hum and JumpPowerEnabled then
            hum.JumpPower = Value
        end
    end
})

CharacterTab:AddSlider({
    Name = "Player Height",
    Min = -50,
    Max = 20,
    Default = 0,
    Increment = 0.1,
    Color = Color3.fromRGB(255, 60, 60),
    ValueName = ".",
    Save = false,
    Flag = "Charactertakasa",
    Callback = function(value)
        local hum = game:GetService("Players").LocalPlayer.Character
            and game:GetService("Players").LocalPlayer.Character:FindFirstChild("Humanoid")

        if hum then
            hum.HipHeight = value
        end
    end
})

InfiniteJumpEnabled = false
CharacterTab:AddToggle({
    Name = "infinity Jump",
    Default = false,
    Callback = function(value)
        InfiniteJumpEnabled = value
    end
})
UserInputService = game:GetService("UserInputService")
UserInputService.JumpRequest:Connect(function()
    if InfiniteJumpEnabled then
        local player = game.Players.LocalPlayer
        if player.Character and player.Character:FindFirstChildOfClass("Humanoid") then
            player.Character:FindFirstChildOfClass("Humanoid"):ChangeState(Enum.HumanoidStateType.Jumping)
        end
    end
end)

-- ------------------------------------------
-- [Tab 3] Aura
-- ------------------------------------------
local AuraTab = Window:MakeTab({
    Name = "Aura",
    Icon = "rbxassetid://4483345998",
    PremiumOnly = false
})

-- =========================
-- Void Aura（強力修正版）
-- =========================
local voidAuraEnabled = false
local voidStrength = 800
local auraReach = 35  -- 範囲（スライダーで調整可能）

local voidConn = nil

local function startVoidAura()
    if voidConn then voidConn:Disconnect() end
    
    voidConn = RunService.Heartbeat:Connect(function()
        if not voidAuraEnabled then return end
        
        local myChar = LocalPlayer.Character
        if not myChar then return end
        local myRoot = myChar:FindFirstChild("HumanoidRootPart")
        if not myRoot then return end

        for _, plr in ipairs(Players:GetPlayers()) do
            if plr == LocalPlayer or not plr.Character then continue end
            
            local targetRoot = plr.Character:FindFirstChild("HumanoidRootPart")
            if not targetRoot then continue end
            
            local distance = (targetRoot.Position - myRoot.Position).Magnitude
            if distance <= auraReach then
                pcall(function()
                    -- Network Ownership確保
                    if SetNetworkOwner then
                        SetNetworkOwner:FireServer(targetRoot, targetRoot.CFrame)
                    end
                    
                    -- Velocity適用（BodyVelocity使用）
                    local bv = targetRoot:FindFirstChild("VoidAuraVelocity") or Instance.new("BodyVelocity")
                    bv.Name = "VoidAuraVelocity"
                    bv.MaxForce = Vector3.new(0, math.huge, 0)
                    bv.Velocity = Vector3.new(0, voidStrength, 0)
                    bv.Parent = targetRoot
                    
                    Debris:AddItem(bv, 0.3)  -- 短時間で削除して連打
                end)
            end
        end
    end)
end

local function stopVoidAura()
    if voidConn then
        voidConn:Disconnect()
        voidConn = nil
    end
end

-- UI
AuraTab:AddToggle({
    Name = "Void Aura",
    Default = false,
    Callback = function(v)
        voidAuraEnabled = v
        if v then
            startVoidAura()
            OrionLib:MakeNotification({Name = "Void Aura", Content = "ON - 範囲内を吹き飛ばします", Time = 3})
        else
            stopVoidAura()
            OrionLib:MakeNotification({Name = "Void Aura", Content = "OFF", Time = 2})
        end
    end
})

AuraTab:AddSlider({
    Name = "Void Power",
    Min = 100,
    Max = 5000,
    Default = 800,
    Increment = 100,
    Callback = function(v)
        voidStrength = v
    end
})

AuraTab:AddSlider({
    Name = "Void Range",
    Min = 10,
    Max = 100,
    Default = 35,
    Increment = 5,
    Callback = function(v)
        auraReach = v
    end
})

-- =========================
-- Camera Track Throw Aura（強力投げ版）
-- =========================
local trackAuraEnabled = false
local trackedPlayers = {}
local trackStartTimes = {}
local trackAuraConn = nil

local function startTrackAura()
    if trackAuraConn then trackAuraConn:Disconnect() end
    
    trackAuraConn = RunService.Heartbeat:Connect(function()
        if not trackAuraEnabled then return end
        
        local myChar = LocalPlayer.Character
        local myRoot = myChar and myChar:FindFirstChild("HumanoidRootPart")
        if not myRoot then return end

        local camera = Workspace.CurrentCamera
        local lookDir = camera.CFrame.LookVector

        for _, plr in ipairs(Players:GetPlayers()) do
            if plr == LocalPlayer or not plr.Character then continue end
            
            local tRoot = plr.Character:FindFirstChild("HumanoidRootPart")
            local tHum = plr.Character:FindFirstChild("Humanoid")
            if not tRoot or not tHum or tHum.Health <= 0 then continue end

            local dist = (tRoot.Position - myRoot.Position).Magnitude
            if dist > 45 then continue end

            if not trackedPlayers[plr.UserId] then
                trackedPlayers[plr.UserId] = plr
                trackStartTimes[plr.UserId] = tick()
                
                pcall(function()
                    if SetNetworkOwner then
                        SetNetworkOwner:FireServer(tRoot, tRoot.CFrame)
                    end
                end)
            end

            local elapsed = tick() - trackStartTimes[plr.UserId]

            if elapsed < 5 then
                -- 視点方向に引き寄せ
                local targetPos = myRoot.Position + lookDir * 18 + Vector3.new(0, 12, 0)
                
                pcall(function()
                    tRoot.CFrame = CFrame.new(targetPos)
                    tRoot.AssemblyLinearVelocity = Vector3.zero
                    tRoot.AssemblyAngularVelocity = Vector3.zero
                    
                    if SetNetworkOwner then
                        SetNetworkOwner:FireServer(tRoot, CFrame.new(targetPos))
                    end
                    
                    tHum.PlatformStand = true
                    tHum.Sit = true
                end)
            else
                -- 5秒後：**強く前方にぶっ飛ばす**
                pcall(function()
                    -- 超強力投げ
                    local throwVelocity = lookDir * 450 + Vector3.new(0, 120, 0)  -- 前方向に450 + 上に120
                    
                    -- BodyVelocityで強制的に飛ばす
                    local bv = tRoot:FindFirstChild("TrackThrowBV") or Instance.new("BodyVelocity")
                    bv.Name = "TrackThrowBV"
                    bv.MaxForce = Vector3.new(math.huge, math.huge, math.huge)
                    bv.Velocity = throwVelocity
                    bv.Parent = tRoot
                    
                    Debris:AddItem(bv, 1.5)  -- 1.5秒間強く飛ばす
                    
                    OrionLib:MakeNotification({
                        Name = "Track Throw",
                        Content = plr.DisplayName .. " を前方にぶっ飛ばした！",
                        Time = 2
                    })
                end)
                
                trackedPlayers[plr.UserId] = nil
                trackStartTimes[plr.UserId] = nil
            end
        end
    end)
end

local function stopTrackAura()
    if trackAuraConn then trackAuraConn:Disconnect() end
    trackAuraConn = nil
    trackedPlayers = {}
    trackStartTimes = {}
end

-- =========================
-- UI
-- =========================
AuraTab:AddSection({ Name = "Camera Track Throw Aura" })

AuraTab:AddToggle({
    Name = "Camera Track Throw",
    Default = false,
    Callback = function(v)
        trackAuraEnabled = v
        if v then
            startTrackAura()
            OrionLib:MakeNotification({
                Name = "Track Throw Aura",
                Content = "ON\n視点で引き寄せ → 5秒後に前方へ超強力投げ",
                Time = 5
            })
        else
            stopTrackAura()
        end
    end
})

AuraTab:AddSlider({
    Name = "Throw Power",
    Min = 200,
    Max = 800,
    Default = 450,
    Increment = 50,
    Callback = function(v)
        -- コード内の 450 をこの値に変えたい場合は変数化できます
    end
})

AuraTab:AddSlider({
    Name = "Track Range",
    Min = 20,
    Max = 60,
    Default = 45,
    Increment = 5,
    Callback = function() end
})

-- =========================
-- UP DOWN AURA（優しく浮かせる）
-- =========================
local upDownEnabled = false
local upDownConn = nil

local function startUpDownAura()
    if upDownConn then upDownConn:Disconnect() end
    
    upDownConn = RunService.Heartbeat:Connect(function()
        if not upDownEnabled then return end
        
        local myRoot = LocalPlayer.Character and LocalPlayer.Character:FindFirstChild("HumanoidRootPart")
        if not myRoot then return end

        for _, plr in ipairs(Players:GetPlayers()) do
            if plr == LocalPlayer or not plr.Character then continue end
            
            local tRoot = plr.Character:FindFirstChild("HumanoidRootPart")
            local tHum = plr.Character:FindFirstChild("Humanoid")
            if not tRoot or not tHum or tHum.Health <= 0 then continue end

            local dist = (tRoot.Position - myRoot.Position).Magnitude
            if dist > 40 then continue end

            pcall(function()
                if SetNetworkOwner then
                    SetNetworkOwner:FireServer(tRoot, tRoot.CFrame)
                end

                -- 優しくゆったり上下
                local time = tick() * 1.8
                local upDownPower = math.sin(time) * 85   -- 優しい動き
                
                local bv = tRoot:FindFirstChild("GentleUpDownBV") or Instance.new("BodyVelocity")
                bv.Name = "GentleUpDownBV"
                bv.MaxForce = Vector3.new(0, math.huge, 0)
                bv.Velocity = Vector3.new(0, upDownPower + 20, 0)  -- 少し上昇寄り
                bv.Parent = tRoot
                Debris:AddItem(bv, 0.4)

                if tHum then
                    tHum.PlatformStand = true
                    tHum.Sit = true
                end
            end)
        end
    end)
end

local function stopUpDownAura()
    if upDownConn then
        upDownConn:Disconnect()
        upDownConn = nil
    end
end

-- =========================
-- UI
-- =========================
AuraTab:AddSection({ Name = "UP DOWN AURA" })

AuraTab:AddToggle({
    Name = "UP Down Aura",
    Default = false,
    Callback = function(v)
        upDownEnabled = v
        if v then
            startUpDownAura()
            OrionLib:MakeNotification({Name = "Gentle UP DOWN", Content = "ON\nオン", Time = 2})
        else
            stopUpDownAura()
        end
    end
})

AuraTab:AddSlider({
    Name = "Float Strength",
    Min = 30,
    Max = 150,
    Default = 85,
    Increment = 10,
    Callback = function() end
})

-- =========================
-- CHAOS AURA（激しく暴れる）
-- =========================
local chaosAuraEnabled = false
local chaosConn = nil

local function startChaosAura()
    if chaosConn then chaosConn:Disconnect() end
    
    chaosConn = RunService.Heartbeat:Connect(function()
        if not chaosAuraEnabled then return end
        
        local myRoot = LocalPlayer.Character and LocalPlayer.Character:FindFirstChild("HumanoidRootPart")
        if not myRoot then return end

        for _, plr in ipairs(Players:GetPlayers()) do
            if plr == LocalPlayer or not plr.Character then continue end
            
            local tRoot = plr.Character:FindFirstChild("HumanoidRootPart")
            local tHum = plr.Character:FindFirstChild("Humanoid")
            if not tRoot or not tHum or tHum.Health <= 0 then continue end

            local dist = (tRoot.Position - myRoot.Position).Magnitude
            if dist > 40 then continue end

            pcall(function()
                -- 掴み + Network Owner
                if SetNetworkOwner then
                    SetNetworkOwner:FireServer(tRoot, tRoot.CFrame)
                end

                -- 激しく暴れる動き
                local randomDir = Vector3.new(
                    math.random(-100, 100),
                    math.random(30, 120),   -- 上方向多め
                    math.random(-100, 100)
                ).Unit * math.random(180, 380)  -- 強さをランダムに

                local bv = tRoot:FindFirstChild("ChaosBV") or Instance.new("BodyVelocity")
                bv.Name = "ChaosBV"
                bv.MaxForce = Vector3.new(math.huge, math.huge, math.huge)
                bv.Velocity = randomDir
                bv.Parent = tRoot
                
                Debris:AddItem(bv, 0.4)  -- 短時間で次々に更新して激しく暴れる
                
                if tHum then
                    tHum.PlatformStand = true
                    tHum.Sit = true
                end
            end)
        end
    end)
end

local function stopChaosAura()
    if chaosConn then
        chaosConn:Disconnect()
        chaosConn = nil
    end
end

-- =========================
-- UI
-- =========================
AuraTab:AddSection({ Name = "CHAOS AURA" })

AuraTab:AddToggle({
    Name = "Chaos Aura",
    Default = false,
    Callback = function(v)
        chaosAuraEnabled = v
        if v then
            startChaosAura()
            OrionLib:MakeNotification({
                Name = "Chaos Aura",
                Content = "ON\n掴んで激しく暴れさせます！",
                Time = 4
            })
        else
            stopChaosAura()
            OrionLib:MakeNotification({Name = "Chaos Aura", Content = "OFF", Time = 2})
        end
    end
})

AuraTab:AddSlider({
    Name = "Chaos Range",
    Min = 20,
    Max = 60,
    Default = 40,
    Increment = 5,
    Callback = function() end  -- 必要なら変数化
})

AuraTab:AddSlider({
    Name = "Chaos Intensity",
    Min = 100,
    Max = 500,
    Default = 280,
    Increment = 20,
    Callback = function() end
})

-- =========================
-- BLACKHOLE AURA（自分が飛ばない版）
-- =========================
local blackholeEnabled = false
local blackholeConn = nil

local function startBlackhole()
    if blackholeConn then blackholeConn:Disconnect() end
    
    blackholeConn = RunService.Heartbeat:Connect(function()
        if not blackholeEnabled then return end
        
        local myChar = LocalPlayer.Character
        local myRoot = myChar and myChar:FindFirstChild("HumanoidRootPart")
        if not myRoot then return end

        for _, plr in ipairs(Players:GetPlayers()) do
            if plr == LocalPlayer or not plr.Character then continue end
            
            local tChar = plr.Character
            local tRoot = tChar:FindFirstChild("HumanoidRootPart")
            local tHum = tChar:FindFirstChild("Humanoid")
            if not tRoot or not tHum or tHum.Health <= 0 then continue end

            local dist = (tRoot.Position - myRoot.Position).Magnitude
            if dist > 40 then continue end

            pcall(function()
                if SetNetworkOwner then
                    SetNetworkOwner:FireServer(tRoot, tRoot.CFrame)
                end

                -- 強く吸い寄せる
                local pullForce = (myRoot.Position - tRoot.Position).Unit * (300 + (40 - dist) * 10)
                
                local bv = tRoot:FindFirstChild("BlackholeBV") or Instance.new("BodyVelocity")
                bv.Name = "BlackholeBV"
                bv.MaxForce = Vector3.new(math.huge, math.huge, math.huge)
                bv.Velocity = pullForce
                bv.Parent = tRoot
                Debris:AddItem(bv, 0.3)

                -- 近くに来たら少し暴らす
                if dist < 10 then
                    tHum.PlatformStand = true
                    tHum.Sit = true
                end
            end)
        end
    end)
end

local function stopBlackhole()
    if blackholeConn then
        blackholeConn:Disconnect()
        blackholeConn = nil
    end
end

-- =========================
-- UI
-- =========================
AuraTab:AddSection({ Name = "BLACKHOLE AURA" })

AuraTab:AddToggle({
    Name = "Blackhole Aura",
    Default = false,
    Callback = function(v)
        blackholeEnabled = v
        if v then
            startBlackhole()
            OrionLib:MakeNotification({Name = "Blackhole Aura", Content = "ON - 相手を吸い寄せます", Time = 4})
        else
            stopBlackhole()
        end
    end
})

AuraTab:AddSlider({
    Name = "Range",
    Min = 20,
    Max = 60,
    Default = 40,
    Increment = 5,
    Callback = function() end
})

-- =========================
-- うんこかけオーラ
-- =========================
local poopAuraEnabled = false
local poopConn = nil

local function startPoopAura()
    if poopConn then poopConn:Disconnect() end
    
    poopConn = RunService.Heartbeat:Connect(function()
        if not poopAuraEnabled then return end
        
        local myRoot = LocalPlayer.Character and LocalPlayer.Character:FindFirstChild("HumanoidRootPart")
        if not myRoot then return end

        for _, plr in ipairs(Players:GetPlayers()) do
            if plr == LocalPlayer or not plr.Character then continue end
            
            local tRoot = plr.Character:FindFirstChild("HumanoidRootPart")
            local tHum = plr.Character:FindFirstChild("Humanoid")
            if not tRoot or not tHum or tHum.Health <= 0 then continue end

            local dist = (tRoot.Position - myRoot.Position).Magnitude
            if dist > 35 then continue end

            pcall(function()
                if SetNetworkOwner then
                    SetNetworkOwner:FireServer(tRoot, tRoot.CFrame)
                end

                -- 自分の体の前に固定
                local frontPos = myRoot.Position
    + myRoot.CFrame.LookVector * 3
    + Vector3.new(0, 1, 0)
                
                tRoot.CFrame = CFrame.new(frontPos, myRoot.Position)
                tRoot.AssemblyLinearVelocity = Vector3.zero
                tRoot.AssemblyAngularVelocity = Vector3.zero

                if tHum then
                    tHum.PlatformStand = true
                    tHum.Sit = true
                end
            end)
        end
    end)
end

local function stopPoopAura()
    if poopConn then
        poopConn:Disconnect()
        poopConn = nil
    end
end

-- =========================
-- UI
-- =========================
AuraTab:AddSection({ Name = "うんこかけオーラ" })

AuraTab:AddLabel("うんこを掴んでオーラをオンにしうんこ食べよう")

AuraTab:AddToggle({
    Name = "うんこかけ Aura",
    Default = false,
    Callback = function(v)
        poopAuraEnabled = v
        if v then
            startPoopAura()
            OrionLib:MakeNotification({Name = "うんこかけ Aura", Content = "ON\nうんこかけよう！", Time = 3})
        else
            stopPoopAura()
        end
    end
})

AuraTab:AddSlider({
    Name = "範囲",
    Min = 15,
    Max = 40,
    Default = 35,
    Increment = 5,
    Callback = function() end
})

-- =========================
-- 竜巻オーラ（Tornado Aura）
-- =========================
local tornadoEnabled = false
local tornadoConn = nil
local tornadoAngle = 0

local function startTornadoAura()
    if tornadoConn then tornadoConn:Disconnect() end
    tornadoAngle = 0
    
    tornadoConn = RunService.Heartbeat:Connect(function(dt)
        if not tornadoEnabled then return end
        
        local myRoot = LocalPlayer.Character and LocalPlayer.Character:FindFirstChild("HumanoidRootPart")
        if not myRoot then return end

        tornadoAngle = tornadoAngle + dt * 18  -- 高速回転

        for _, plr in ipairs(Players:GetPlayers()) do
            if plr == LocalPlayer or not plr.Character then continue end
            
            local tRoot = plr.Character:FindFirstChild("HumanoidRootPart")
            local tHum = plr.Character:FindFirstChild("Humanoid")
            if not tRoot or not tHum or tHum.Health <= 0 then continue end

            local dist = (tRoot.Position - myRoot.Position).Magnitude
            if dist > 40 then continue end

            pcall(function()
                if SetNetworkOwner then
                    SetNetworkOwner:FireServer(tRoot, tRoot.CFrame)
                end

                -- 自分の頭の上に固定 + 竜巻回転
                local height = 18
                local radius = 6
                
                local angle = tornadoAngle + (plr.UserId % 5) * 1.2  -- 少し位相をずらす
                
                local x = math.cos(angle) * radius
                local z = math.sin(angle) * radius
                
                local targetPos = myRoot.Position + Vector3.new(x, height, z)
                
                tRoot.CFrame = CFrame.new(targetPos, myRoot.Position) * CFrame.Angles(0, angle * 2, 0)
                tRoot.AssemblyLinearVelocity = Vector3.zero
                tRoot.AssemblyAngularVelocity = Vector3.new(0, 30, 0)  -- 高速回転

                if tHum then
                    tHum.PlatformStand = true
                    tHum.Sit = true
                end
            end)
        end
    end)
end

local function stopTornadoAura()
    if tornadoConn then
        tornadoConn:Disconnect()
        tornadoConn = nil
    end
end

-- =========================
-- UI
-- =========================
AuraTab:AddSection({ Name = "Spin Aura" })

AuraTab:AddToggle({
    Name = "Spin Aura",
    Default = false,
    Callback = function(v)
        tornadoEnabled = v
        if v then
            startTornadoAura()
            OrionLib:MakeNotification({Name = "Spin Aura", Content = "ON\あいうえお", Time = 4})
        else
            stopTornadoAura()
        end
    end
})

AuraTab:AddSlider({
    Name = "回転速度",
    Min = 8,
    Max = 30,
    Default = 18,
    Increment = 1,
    Callback = function() end
})

AuraTab:AddSlider({
    Name = "範囲",
    Min = 20,
    Max = 50,
    Default = 40,
    Increment = 5,
    Callback = function() end
})

------------------------------------------
-- [Tab 4] Explosion
-- ------------------------------------------
local ExplosionTab = Window:MakeTab({
    Name = "Explosion",
    Icon = "rbxassetid://17837704089",
    PremiumOnly = false
})

local snowballRagdollActive = false
local targetName = "" -- 選択されたターゲット名が入る変数

-- サーバー内のプレイヤー名をリスト（テーブル）にする関数
local function getPlayerNames()
    local names = {}
    for _, player in pairs(Players:GetPlayers()) do
        -- 自分自身を除外したい場合は「if player ~= Players.LocalPlayer then」を追加してください
        table.insert(names, player.Name)
    end
    return names
end

-- 1. プレイヤー選択用ドロップダウン
local PlayerDropdown = ExplosionTab:AddDropdown({
    Name = "Select Target Player",
    Default = "None",
    Options = getPlayerNames(), -- 起動時にいるプレイヤー一覧
    Callback = function(selected)
        targetName = selected
        print("Target changed to: " .. targetName)
    end
})

-- 【オマケ】プレイヤーの入退室時にドロップダウンの選択肢を自動更新する処理
Players.PlayerAdded:Connect(function()
    PlayerDropdown:Refresh(getPlayerNames(), true)
end)
Players.PlayerRemoving:Connect(function()
    PlayerDropdown:Refresh(getPlayerNames(), true)
end)


-- 2. 雪玉をめっちゃ投げるトグルボタン
ExplosionTab:AddToggle({
    Name = "Fast Snowball Ragdoll",
    Default = false,
    Callback = function(state)
        snowballRagdollActive = state

        if state then
            -- ターゲットが選ばれていない、または「None」なら止める
            if targetName == "" or targetName == "None" then
                print("Error: Please select a target player from the dropdown!")
                return
            end

            coroutine.wrap(function()
                local Player = Players.LocalPlayer
                local SpawnRemote = ReplicatedStorage:WaitForChild("MenuToys"):WaitForChild("SpawnToyRemoteFunction")

                while snowballRagdollActive do
                    local target = Players:FindFirstChild(targetName)
                    if target and target.Character then
                        local tChar = target.Character
                        local torso = tChar:FindFirstChild("UpperTorso") or tChar:FindFirstChild("Torso")
                        
                        if torso then
                            -- 【修正点1】サーバー通信のラグでループが止まらないよう非同期化
                            task.spawn(function()
                                pcall(function()
                                    local offset = Vector3.new(
                                        math.random(-30, 30) / 100,
                                        math.random(-30, 30) / 100,
                                        math.random(-30, 30) / 100
                                    )
                                    local spawnCFrame = torso.CFrame * CFrame.new(offset)
                                    SpawnRemote:InvokeServer("BallSnowball", spawnCFrame, Vector3.zero)
                                end)
                            end)

                            -- 生成された雪玉の固定処理
                            local folder = Workspace:FindFirstChild(Player.Name .. "SpawnedInToys")
                            if folder then
                                for _, snowball in pairs(folder:GetChildren()) do
                                    if snowball.Name == "BallSnowball" and snowball.Parent then
                                        local part = snowball.PrimaryPart or snowball:FindFirstChildWhichIsA("BasePart")
                                        if part then
                                            local offset = Vector3.new(
                                                math.random(-30, 30) / 100,
                                                math.random(-30, 30) / 100,
                                                math.random(-30, 30) / 100
                                            )
                                            -- 【修正点2】相手の移動速度(Velocity)を足して、動いている先へ先回りして貼り付くように変更
                                            local prediction = torso.AssemblyLinearVelocity * 0.03
                                            part.CFrame = (torso.CFrame + prediction) * CFrame.new(offset)
                                            part.AssemblyLinearVelocity = Vector3.zero
                                            part.AssemblyAngularVelocity = Vector3.zero
                                        end
                                    end
                                end
                            end
                        end
                    end
                    task.wait()
                end
            end)()
        else
            -- オフにした時のクリーンアップ
            pcall(function()
                local Player = Players.LocalPlayer
                local folder = Workspace:FindFirstChild(Player.Name .. "SpawnedInToys")
                if folder then
                    for _, snowball in pairs(folder:GetChildren()) do
                        if snowball.Name == "BallSnowball" then
                            local part = snowball.PrimaryPart or snowball:FindFirstChildWhichIsA("BasePart")
                            if part then
                                part.CFrame = CFrame.new(0, -200, 0)
                            end
                        end
                    end
                end
            end)
        end
    end
})

-- ------------------------------------------
-- [Tab 4] FreezeA
-- ------------------------------------------
local freezeATab = Window:MakeTab({
    Name = "Invincible",
    Icon = "rbxassetid://4483345998",
    PremiumOnly = false
})

local Players = game:GetService("Players")
local playerNames = {}
local SelectedPlayer
local isFrozen = false
local PlayerDropdown
local currentCoroutine = nil
local bringPosition = Vector3.new(0, 50, 0)
local Players = game:GetService("Players")
local playerNames = {}
local nameMap = {}
local SelectedPlayer
local PlayerDropdown

local function RefreshList()
    playerNames = {}
    nameMap = {}
    for _, player in ipairs(Players:GetPlayers()) do
        local display = player.DisplayName .. " (" .. player.Name .. ")"
        table.insert(playerNames, display)
        nameMap[display] = player.Name
    end
    if PlayerDropdown then
        PlayerDropdown:Refresh(playerNames, true)
    end
end

PlayerDropdown = freezeATab:AddDropdown({
    Name = "Choose a player who can break through anywhere.",
    Options = playerNames,
    Callback = function(selectedDisplay)
        SelectedPlayer = nameMap[selectedDisplay]
    end
})

Players.PlayerAdded:Connect(function(player)
    player.CharacterAdded:Connect(function()
        if SelectedPlayer == player.Name then
            toggleFreezeAndBring(player)
        end
    end)
    RefreshList()
end)

Players.PlayerRemoving:Connect(RefreshList)
RefreshList()

function toggleFreezeAndBring(player)
    if player then
        local targetPlayer = player
        if targetPlayer and targetPlayer.Character then
            local humanoidRootPart = targetPlayer.Character:FindFirstChild("HumanoidRootPart")
            if humanoidRootPart then
                humanoidRootPart.CFrame = CFrame.new(bringPosition)
            end
            for _, part in pairs(targetPlayer.Character:GetChildren()) do
                if part:IsA("BasePart") then
                    part.Anchored = isFrozen
                end
            end
        end
    end
end
function infiniteLoop()
    while isFrozen do
        if SelectedPlayer then
            local targetPlayer = Players:FindFirstChild(SelectedPlayer)
            if targetPlayer then
                toggleFreezeAndBring(targetPlayer)
            end
        end
        wait(0.01)
    end
end
freezeATab:AddToggle({
    Name = "Breakthrough anywhere",
    Default = false,
    Callback = function(toggleState)

        isFrozen = toggleState

        if SelectedPlayer then
            local targetPlayer = Players:FindFirstChild(SelectedPlayer)
            if targetPlayer then
                toggleFreezeAndBring(targetPlayer)
            end
        end

        if isFrozen then
            if currentCoroutine then
                currentCoroutine = nil
            end
            currentCoroutine = coroutine.wrap(infiniteLoop)()
        else
            if currentCoroutine then
                currentCoroutine = nil
            end
            for _, playerName in ipairs(playerNames) do
                local targetPlayer = Players:FindFirstChild(playerName)
                if targetPlayer and targetPlayer.Character then
                    for _, part in pairs(targetPlayer.Character:GetChildren()) do
                        if part:IsA("BasePart") then
                            part.Anchored = false
                        end
                    end
                end
            end
        end
    end
})



freezeATab:AddButton({
    Name = "List update",
    Callback = RefreshList
})
RefreshList()
function esp(p, cr)
    if not ESPEnabled then
        return
    end
    local h = cr:WaitForChild("Humanoid")
    local hrp = cr:WaitForChild("HumanoidRootPart")
    local text = Drawing.new("Text")
    text.Visible = false
    text.Center = true
    text.Outline = true
    text.Font = 2
    text.Color = Color3.fromRGB(255, 255, 255)
    text.Size = 17
    local c1, c2, c3
    local function cleanup()
        text.Visible = false
        text:Remove()
        if c1 then
            c1:Disconnect()
            c1 = nil
        end
        if c2 then
            c2:Disconnect()
            c2 = nil
        end
        if c3 then
            c3:Disconnect()
            c3 = nil
        end
    end
    c1 = game:GetService("RunService").RenderStepped:Connect(function()
        if not ESPEnabled then
            cleanup()
            return
        end
        local hrp_pos, hrp_on_screen = workspace.CurrentCamera:WorldToViewportPoint(hrp.Position)
        if hrp_on_screen then
            text.Position = Vector2.new(hrp_pos.X, hrp_pos.Y)
            text.Text = string.format("%s (%.1f m)", p.Name,
                (hrp.Position - workspace.CurrentCamera.CFrame.Position).Magnitude)
            text.Visible = true
        else
            text.Visible = false
        end
    end)
    c2 = cr.AncestryChanged:Connect(function(_, parent)
        if not parent then
            cleanup()
        end
    end)
    c3 = h.HealthChanged:Connect(function(health)
        if health <= 0 then
            cleanup()
        end
    end)
end
function playerAdded(p)
    if p.Character then
        esp(p, p.Character)
    end
    p.CharacterAdded:Connect(function(cr)
        esp(p, cr)
    end)
end

-- ------------------------------------------
-- [Tab 4] Blobman
-- ------------------------------------------
local BlobmanTab = Window:MakeTab({
    Name = "Blobman",
    Icon = "rbxassetid://4483345998",
    PremiumOnly = false
})

BlobmanTab:AddSection({Name = "Target Settings"})
local targetDropdown = BlobmanTab:AddDropdown({
    Name = "Select Target",
    Default = "",
    Options = getPlayerList(),
    Callback = function(val) selectedActionTargetName = playerMap[val] or "" end
})

BlobmanTab:AddButton({
    Name = "Refresh Player List",
    Callback = function()
        targetDropdown:Refresh(getPlayerList(), true)
        OrionLib:MakeNotification({Name="Refresh List", Content="Player list updated", Time=2})
    end
})

-- ▼ Standard Blobman Kick ▼
BlobmanTab:AddToggle({
    Name = "Blobman Kick",
    Default = false,
    Callback = function(v)
        levitateRunning = v
        if not v then return end
        local target = Players:FindFirstChild(selectedActionTargetName)
        if target and target ~= LocalPlayer and target.Character and target.Character:FindFirstChild("HumanoidRootPart") and LocalPlayer.Character and LocalPlayer.Character:FindFirstChild("HumanoidRootPart") then
            local blobman = nil
            local spawned = Workspace:FindFirstChild(LocalPlayer.Name .. "SpawnedInToys")
            if spawned then blobman = spawned:FindFirstChild("CreatureBlobman") end
            
            if blobman then
                local lDet = blobman:FindFirstChild("LeftDetector")
                local rDet = blobman:FindFirstChild("RightDetector")
                local hasValidWeld = (lDet and (lDet:FindFirstChild("LeftWeld") or lDet:FindFirstChildWhichIsA("Weld") or lDet:FindFirstChildWhichIsA("JointInstance") or lDet:FindFirstChild("RigidConstraint"))) or
                                     (rDet and (rDet:FindFirstChild("RightWeld") or rDet:FindFirstChildWhichIsA("Weld") or rDet:FindFirstChildWhichIsA("JointInstance") or rDet:FindFirstChild("RigidConstraint")))
                if not hasValidWeld then
                    pcall(function() ReplicatedStorage.MenuToys.DestroyToy:FireServer(blobman) end)
                    blobman = nil
                    task.wait(0.3)
                end
            end

            if not blobman then
                local mt = ReplicatedStorage:FindFirstChild("MenuToys")
                local st = mt and mt:FindFirstChild("SpawnToyRemoteFunction")
                if st then
                    local myRoot = LocalPlayer.Character and LocalPlayer.Character:FindFirstChild("HumanoidRootPart")
                    local spawnCF = myRoot and (myRoot.CFrame + Vector3.new(0, 5, 0)) or CFrame.new(0, 50, 0)
                    st:InvokeServer("CreatureBlobman", spawnCF, Vector3.zero)
                    task.wait(0.5)
                    spawned = Workspace:FindFirstChild(LocalPlayer.Name .. "SpawnedInToys")
                    if spawned then blobman = spawned:FindFirstChild("CreatureBlobman") end
                end
            end

            if not blobman then
                for _, obj in ipairs(Workspace:GetChildren()) do
                    if obj.Name == "CreatureBlobman" and obj:FindFirstChild("VehicleSeat") then
                        blobman = obj
                        break
                    end
                end
            end

            if blobman then
                local scriptObj = blobman:FindFirstChild("BlobmanSeatAndOwnerScript") or blobman:FindFirstChild("BlobmanSeatAndOwnerScript[old]")
                local grabRemote = (scriptObj and scriptObj:FindFirstChild("CreatureGrab")) or blobman:FindFirstChild("CreatureGrab", true)
                local dropRemote = (scriptObj and scriptObj:FindFirstChild("CreatureDrop")) or blobman:FindFirstChild("CreatureDrop", true)
                local lDet = blobman:FindFirstChild("LeftDetector")
                local rDet = blobman:FindFirstChild("RightDetector")
                local lWeld = lDet and (lDet:FindFirstChild("LeftWeld") or lDet:FindFirstChildWhichIsA("Weld") or lDet:FindFirstChildWhichIsA("JointInstance") or lDet:FindFirstChild("RigidConstraint"))
                local rWeld = rDet and (rDet:FindFirstChild("RightWeld") or rDet:FindFirstChildWhichIsA("Weld") or rDet:FindFirstChildWhichIsA("JointInstance") or rDet:FindFirstChild("RigidConstraint"))
                
                local seat = blobman:FindFirstChild("VehicleSeat")
                local hum = LocalPlayer.Character:FindFirstChild("Humanoid")
                if seat and hum then
                    if seat.Occupant ~= hum then
                        LocalPlayer.Character.HumanoidRootPart.CFrame = seat.CFrame + Vector3.new(0, 2, 0)
                        seat:Sit(hum)
                        task.wait(0.3)
                    end
                end

                local GE = ReplicatedStorage:FindFirstChild("GrabEvents")
                if GE and grabRemote and dropRemote and ((lDet and lWeld) or (rDet and rWeld)) then
                    OrionLib:MakeNotification({ Name = "Execute", Content = "Blobman Kick Loop", Time = 3 })
                    task.spawn(function()
                        local blobRoot = blobman:FindFirstChild("HumanoidRootPart") or blobman.PrimaryPart
                        local SavedPos = blobRoot.CFrame
                        local Det = rDet or lDet
                        local Weld = rWeld or lWeld

                        local bringStart = tick()
                        while tick() - bringStart < 0.35 do
                            if not levitateRunning or not blobman or not blobman.Parent then break end
                            if target.Character and target.Character:FindFirstChild("HumanoidRootPart") then
                                local tRoot = target.Character.HumanoidRootPart
                                blobRoot.CFrame = tRoot.CFrame
                                blobRoot.AssemblyLinearVelocity = Vector3.zero
                                pcall(function()
                                    if Det then grabRemote:FireServer(Det, tRoot, Weld) end
                                    local CGL = GE:FindFirstChild("CreateGrabLine")
                                    local SNO = GE:FindFirstChild("SetNetworkOwner")
                                    if CGL then CGL:FireServer(tRoot, Vector3.zero, tRoot.Position, false) end
                                    if SNO then SNO:FireServer(tRoot, blobRoot.CFrame) end
                                end)
                            end
                            RunService.Heartbeat:Wait()
                        end

                        if blobRoot then
                            blobRoot.CFrame = SavedPos
                            blobRoot.AssemblyLinearVelocity = Vector3.zero
                            task.wait(0.05)
                        end

                        while levitateRunning and blobman and blobman.Parent do
                            if not target or not target.Parent or not target.Character then break end
                            local tChar = target.Character
                            local tRoot = tChar:FindFirstChild("HumanoidRootPart")
                            local tHum = tChar:FindFirstChild("Humanoid")
                            if tRoot and tHum and tHum.Health > 0 and blobRoot then
                                blobRoot.CFrame = SavedPos
                                blobRoot.AssemblyLinearVelocity = Vector3.zero
                                local lockPos = SavedPos * CFrame.new(0, 23, 0)
                                tRoot.CFrame = lockPos
                                tRoot.AssemblyLinearVelocity = Vector3.zero
                                tRoot.AssemblyAngularVelocity = Vector3.zero
                                pcall(function()
                                    tHum.PlatformStand = true
                                    tHum.Sit = true
                                    local SNO = GE:FindFirstChild("SetNetworkOwner")
                                    if SNO then SNO:FireServer(tRoot, lockPos) end
                                    local currentWeld = Det:FindFirstChild("RightWeld") or Det:FindFirstChild("LeftWeld") or Det:FindFirstChildWhichIsA("Weld") or Det:FindFirstChildWhichIsA("JointInstance") or Det:FindFirstChild("RigidConstraint")
                                    if currentWeld then dropRemote:FireServer(currentWeld) end
                                    local DGL = GE:FindFirstChild("DestroyGrabLine")
                                    local CGL = GE:FindFirstChild("CreateGrabLine")
                                    if DGL then DGL:FireServer(tRoot) end
                                    if Det then grabRemote:FireServer(Det, tRoot, Weld) end
                                    if CGL then CGL:FireServer(tRoot, Vector3.zero, tRoot.Position, false) end
                                end)
                            else
                                if blobRoot then
                                    blobRoot.CFrame = SavedPos
                                    blobRoot.AssemblyLinearVelocity = Vector3.zero
                                end
                            end
                            RunService.Heartbeat:Wait()
                        end
                        if blobRoot then
                            blobRoot.CFrame = SavedPos
                            blobRoot.AssemblyLinearVelocity = Vector3.zero
                        end
                    end)
                else
                    levitateRunning = false
                    local missing = {}
                    if not GE then table.insert(missing, "GrabEvents") end
                    if not grabRemote then table.insert(missing, "CreatureGrab") end
                    if not dropRemote then table.insert(missing, "CreatureDrop") end
                    if not (lDet or rDet) then table.insert(missing, "Detector") end
                    if not (lWeld or rWeld) then table.insert(missing, "Weld/Constraint") end
                    OrionLib:MakeNotification({ Name = "Error", Content = "Missing: " .. table.concat(missing, ", "), Time = 5 })
                end
            else
                levitateRunning = false
                OrionLib:MakeNotification({ Name = "Error", Content = "Blobman not found (Please spawn the toy)", Time = 3 })
            end
        end
    end
})

BlobmanTab:AddButton({
    Name = "Stop Blobman Kick",
    Callback = function()
        if levitateRunning then
            levitateRunning = false
            OrionLib:MakeNotification({ Name = "Stop", Content = "Blobman Kick stopped", Time = 3 })
        else
            OrionLib:MakeNotification({ Name = "Info", Content = "Blobman Kick is not running", Time = 3 })
        end
    end
})

-- ▼ Drift Kick ▼
BlobmanTab:AddToggle({
    Name = "drift kick",
    Default = false,
    Callback = function(v)
        orbitRunning = v
        currentLoopId = currentLoopId + 1
        local myLoopId = currentLoopId
        if not v then return end
        
        local target = Players:FindFirstChild(selectedActionTargetName)
        if target and target ~= LocalPlayer then
            
            local blobman = nil
            local spawned = Workspace:FindFirstChild(LocalPlayer.Name .. "SpawnedInToys")
            if spawned then blobman = spawned:FindFirstChild("CreatureBlobman") end
            
            if not blobman then
                local mt = ReplicatedStorage:FindFirstChild("MenuToys")
                local st = mt and mt:FindFirstChild("SpawnToyRemoteFunction")
                if st then
                    local myRoot = LocalPlayer.Character and LocalPlayer.Character:FindFirstChild("HumanoidRootPart")
                    local spawnCF = myRoot and (myRoot.CFrame + Vector3.new(0, 5, 0)) or CFrame.new(0, 50, 0)
                    st:InvokeServer("CreatureBlobman", spawnCF, Vector3.zero)
                    task.wait(0.8)
                    spawned = Workspace:FindFirstChild(LocalPlayer.Name .. "SpawnedInToys")
                    if spawned then blobman = spawned:FindFirstChild("CreatureBlobman") end
                end
            end

            if not blobman then
                for _, obj in ipairs(Workspace:GetChildren()) do
                    if obj.Name == "CreatureBlobman" and obj:FindFirstChild("VehicleSeat") then
                        blobman = obj
                        break
                    end
                end
            end
            
            if blobman then
                local scriptObj = blobman:FindFirstChild("BlobmanSeatAndOwnerScript") or blobman:FindFirstChild("BlobmanSeatAndOwnerScript[old]")
                local grabRemote = scriptObj and scriptObj:FindFirstChild("CreatureGrab") or blobman:FindFirstChild("CreatureGrab", true)
                local dropRemote = scriptObj and scriptObj:FindFirstChild("CreatureDrop") or blobman:FindFirstChild("CreatureDrop", true)

                local lDet = blobman:FindFirstChild("LeftDetector")
                local rDet = blobman:FindFirstChild("RightDetector")
                local lWeld = lDet and (lDet:FindFirstChild("LeftWeld") or lDet:FindFirstChildWhichIsA("Weld") or lDet:FindFirstChildWhichIsA("JointInstance") or lDet:FindFirstChild("RigidConstraint"))
                local rWeld = rDet and (rDet:FindFirstChild("RightWeld") or rDet:FindFirstChildWhichIsA("Weld") or rDet:FindFirstChildWhichIsA("JointInstance") or rDet:FindFirstChild("RigidConstraint"))
                
                local seat = blobman:FindFirstChild("VehicleSeat")
                local hum = LocalPlayer.Character and LocalPlayer.Character:FindFirstChild("Humanoid")
                
                if seat and hum then
                    if seat.Occupant ~= hum then
                        LocalPlayer.Character.HumanoidRootPart.CFrame = seat.CFrame + Vector3.new(0, 2, 0)
                        task.wait(0.2)
                        seat:Sit(hum)
                        task.wait(0.5)
                    end
                end
                
                local GE = ReplicatedStorage:FindFirstChild("GrabEvents")
                
                if GE and grabRemote and dropRemote and ((lDet and lWeld) or (rDet and rWeld)) then
                    OrionLib:MakeNotification({ Name = "実行", Content = "drift kick を開始します", Time = 3 })

                    task.spawn(function()
                        local blobRoot = blobman:FindFirstChild("HumanoidRootPart") or blobman.PrimaryPart
                        local Det = rDet or lDet
                        local Weld = rWeld or lWeld
                        
                        -- ▼ 全体を包む監視ループ（キャラリセット時にここに戻る） ▼
                        while orbitRunning do
                            if myLoopId ~= currentLoopId then break end
                            if not target or not target.Parent then break end
                            
                            local tChar = target.Character
                            local tHum = tChar and tChar:FindFirstChild("Humanoid")
                            local tRoot = tChar and tChar:FindFirstChild("HumanoidRootPart")

                            if tChar and tRoot and tHum and tHum.Health > 0 then
                            
                                -- Phase 1: 初回Capture
                                local bringStart = tick()
                                while tick() - bringStart < 0.35 do
                                    if myLoopId ~= currentLoopId or not orbitRunning or not blobman or not blobman.Parent then break end
                                    if target.Character and target.Character:FindFirstChild("HumanoidRootPart") then
                                        local currentTRoot = target.Character.HumanoidRootPart
                                        blobRoot.CFrame = currentTRoot.CFrame
                                        blobRoot.AssemblyLinearVelocity = Vector3.zero
                                        
                                        pcall(function()
                                            if Det then grabRemote:FireServer(Det, currentTRoot, Weld) end
                                            GE.CreateGrabLine:FireServer(currentTRoot, Vector3.zero, currentTRoot.Position, false)
                                            GE.SetNetworkOwner:FireServer(currentTRoot, blobRoot.CFrame)
                                        end)
                                    end
                                    RunService.Heartbeat:Wait()
                                end
                                
                                if myLoopId ~= currentLoopId or not orbitRunning or not blobman or not blobman.Parent then break end
                                
                                tChar = target.Character
                                tRoot = tChar and tChar:FindFirstChild("HumanoidRootPart")
                                tHum = tChar and tChar:FindFirstChild("Humanoid")
                                
                                if tChar and tRoot and tHum and tHum.Health > 0 then
                                    local SavedPos = tRoot.CFrame
                                    local targetCenterCFrame = SavedPos + Vector3.new(0, 30, 0)
                                    
                                    local lastTime = tick()
                                    local lastDropTime = tick()
                                    local dropCount = 0
                                    
                                    -- Phase 2: Lock & Orbit
                                    while orbitRunning and blobman and blobman.Parent do
                                        if myLoopId ~= currentLoopId then break end
                                        
                                        if not target or not target.Parent then break end
                                        tChar = target.Character
                                        tRoot = tChar and tChar:FindFirstChild("HumanoidRootPart")
                                        tHum = tChar and tChar:FindFirstChild("Humanoid")
                                        
                                        if not tChar or not tRoot or not tHum or tHum.Health <= 0 then
                                            break 
                                        end
                                        
                                        if dropCount < 2 and (tick() - lastDropTime) > 0.8 then
                                            dropCount = dropCount + 1
                                            
                                            pcall(function()
                                                local currentWeld = Det:FindFirstChild("RightWeld") or Det:FindFirstChild("LeftWeld") or Det:FindFirstChildWhichIsA("Weld") or Det:FindFirstChildWhichIsA("JointInstance") or Det:FindFirstChild("RigidConstraint")
                                                if currentWeld then dropRemote:FireServer(currentWeld) end
                                                GE.DestroyGrabLine:FireServer(tRoot)
                                            end)
                                            
                                            blobRoot.CFrame = SavedPos
                                            blobRoot.AssemblyLinearVelocity = Vector3.zero
                                            
                                            RunService.Heartbeat:Wait()
                                            
                                            if target.Character and target.Character:FindFirstChild("HumanoidRootPart") then
                                                local currentTRoot = target.Character.HumanoidRootPart
                                                blobRoot.CFrame = currentTRoot.CFrame
                                                blobRoot.AssemblyLinearVelocity = Vector3.zero
                                                
                                                pcall(function()
                                                    if Det then grabRemote:FireServer(Det, currentTRoot, Weld) end
                                                    GE.CreateGrabLine:FireServer(currentTRoot, Vector3.zero, currentTRoot.Position, false)
                                                    GE.SetNetworkOwner:FireServer(currentTRoot, blobRoot.CFrame)
                                                end)
                                            end
                                            
                                            lastTime = tick()
                                            lastDropTime = tick()
                                            continue
                                        end

                                        if tRoot and tHum and tHum.Health > 0 and blobRoot then
                                            local currentTime = tick()
                                            local dt = currentTime - lastTime
                                            lastTime = currentTime

                                            driftAngle = driftAngle + (driftSpeed * dt)
                                            local offsetX = math.cos(driftAngle) * driftRadius
                                            local offsetZ = math.sin(driftAngle) * driftRadius
                                            
                                            local blobPos = targetCenterCFrame.Position + Vector3.new(offsetX, driftHeightOffset, offsetZ)
                                            blobRoot.CFrame = CFrame.new(blobPos, targetCenterCFrame.Position)
                                            blobRoot.AssemblyLinearVelocity = Vector3.zero
                                            blobRoot.AssemblyAngularVelocity = Vector3.zero
                                            
                                            tRoot.CFrame = targetCenterCFrame
                                            tRoot.AssemblyLinearVelocity = Vector3.zero
                                            tRoot.AssemblyAngularVelocity = Vector3.zero

                                            pcall(function()
                                                tHum.PlatformStand = true
                                                tHum.Sit = true
                                                GE.SetNetworkOwner:FireServer(tRoot, targetCenterCFrame)
                                                
                                                local currentWeld = Det:FindFirstChild("RightWeld") or Det:FindFirstChild("LeftWeld") or Det:FindFirstChildWhichIsA("Weld") or Det:FindFirstChildWhichIsA("JointInstance") or Det:FindFirstChild("RigidConstraint")
                                                if currentWeld then dropRemote:FireServer(currentWeld) end
                                                
                                                GE.DestroyGrabLine:FireServer(tRoot)
                                                if Det then grabRemote:FireServer(Det, tRoot, Weld) end
                                                GE.CreateGrabLine:FireServer(tRoot, Vector3.zero, targetCenterCFrame.Position, false)
                                            end)
                                        else
                                            break 
                                        end
                                        RunService.Heartbeat:Wait()
                                    end
                                    
                                    if not orbitRunning or myLoopId ~= currentLoopId then
                                        if blobRoot and SavedPos then
                                            pcall(function()
                                                local currentWeld = Det:FindFirstChild("RightWeld") or Det:FindFirstChild("LeftWeld") or Det:FindFirstChildWhichIsA("Weld") or Det:FindFirstChildWhichIsA("JointInstance") or Det:FindFirstChild("RigidConstraint")
                                                if currentWeld then dropRemote:FireServer(currentWeld) end
                                                if target and target.Character and target.Character:FindFirstChild("HumanoidRootPart") then
                                                    GE.DestroyGrabLine:FireServer(target.Character.HumanoidRootPart)
                                                end
                                            end)
                                            blobRoot.CFrame = SavedPos
                                            blobRoot.AssemblyLinearVelocity = Vector3.zero
                                        end
                                        break
                                    end
                                end
                            end
                            RunService.Heartbeat:Wait()
                        end
                    end)
                else
                    OrionLib:MakeNotification({ Name = "エラー", Content = "必要なRemoteEventやDetectorが見つかりません", Time = 5 })
                    orbitRunning = false
                end
            else
                OrionLib:MakeNotification({ Name = "エラー", Content = "Blobmanの取得・生成に失敗しました", Time = 3 })
                orbitRunning = false
            end
        else
            OrionLib:MakeNotification({ Name = "エラー", Content = "ターゲットが無効です", Time = 3 })
            orbitRunning = false
        end
    end
})


BlobmanTab:AddSection({Name = "Blobman Features"})

-- ▼ Blobman kill (20 Stack Mount) ▼
BlobmanTab:AddToggle({
    Name = "Blobman kill (20 Stack Mount)",
    Default = false,
    Callback = function(state)
        bm_isRunning = state
        local targetPlayer = Players:FindFirstChild(selectedActionTargetName)
        
        if state then
            if not targetPlayer then
                OrionLib:MakeNotification({Name="Error", Content="Select a target first", Time=2})
                bm_isRunning = false
                return
            end

            if bm_loopConn then bm_loopConn:Disconnect() end
            if bm_grabConn then bm_grabConn:Disconnect() end
            if bm_mountConn then bm_mountConn:Disconnect() end
            pcall(function() if bm_currentBlobman then bm_currentBlobman:Destroy() end end)
            task.wait(0.05)

            if not bm_SpawnBlobman() then
                OrionLib:MakeNotification({Name="Failed", Content="Failed to spawn Blobman", Time=2})
                bm_isRunning = false
                return
            end

            bm_SetupRespawnMonitor(targetPlayer)
            bm_StartContinuousGrab(targetPlayer.Character and targetPlayer.Character:FindFirstChild("HumanoidRootPart") or nil)
            bm_KeepMounted()
            bm_angle = 0
            bm_loopConn = RunService.Heartbeat:Connect(bm_ProcessCycle)
            OrionLib:MakeNotification({Name="Started", Content="Mounted at 20 studs high", Time=2})
        else
            if bm_loopConn then bm_loopConn:Disconnect() end
            if bm_grabConn then bm_grabConn:Disconnect() end
            if bm_respawnConn then bm_respawnConn:Disconnect() end
            if bm_localRespawnConn then bm_localRespawnConn:Disconnect() end
            if bm_mountConn then bm_mountConn:Disconnect() end
            pcall(function() if bm_currentBlobman then bm_currentBlobman:Destroy() end end)
            bm_isRunning = false
            
            local char = LocalPlayer.Character
            if char then
                local hum = char:FindFirstChildOfClass("Humanoid")
                if hum then 
                    hum.PlatformStand = false
                    hum.Jump = true 
                end
            end
            OrionLib:MakeNotification({Name="Stopped", Content="Blobman removed and normal state restored", Time=2})
        end
    end
})

-- ▼ Auto Kill All ▼
BlobmanTab:AddToggle({
    Name = "Blobman Kill All",
    Default = false,
    Color = Color3.fromRGB(255,0,0),
    Callback = function(val)
        autoKillAllEnabled = val
        if val then
            OrionLib:MakeNotification({Name="Auto Kill", Content="Auto Kill All ON", Time=2})
            task.spawn(function()
                while autoKillAllEnabled do
                    local myHRP = HRP()
                    if myHRP and cachedBlobman then
                        for _, p in ipairs(Players:GetPlayers()) do
                            if not autoKillAllEnabled then break end
                            if p == LocalPlayer then continue end
                            if ExcludeFriends and LocalPlayer:IsFriendsWith(p.UserId) then continue end
                            local char = p.Character
                            local pHRP = char and char:FindFirstChild("HumanoidRootPart")
                            local hum = char and char:FindFirstChildOfClass("Humanoid")
                            if pHRP and hum and hum.Health > 0 then
                                myHRP.CFrame = pHRP.CFrame * CFrame.new(0, 2, -3)
                                startThreads(p, p.UserId)
                                task.wait(0.3)
                                stopThreads(p.UserId)
                            end
                        end
                    else
                        if not cachedBlobman and autoKillAllEnabled then
                            OrionLib:MakeNotification({Name="Error", Content="Please sit on Blobman", Time=2})
                            autoKillAllEnabled = false
                            break
                        end
                    end
                    task.wait(0.5)
                end
            end)
        else
            OrionLib:MakeNotification({Name="Blobman Kill All", Content="Auto Kill All OFF", Time=2})
            for _, p in ipairs(Players:GetPlayers()) do stopThreads(p.UserId) end
        end
    end
})

BlobmanTab:AddButton({ Name = "Blobman Kick All", Callback = KickAll })

BlobmanTab:AddToggle({
    Name = "White Friends",
    Default = false,
    Callback = function(Value) ExcludeFriends = Value end
})

-- ------------------------------------------
-- [Tab 5] Reskill (Kill)
-- ------------------------------------------
local KillTab = Window:MakeTab({
    Name = "Loop Kill",
    Icon = "rbxassetid://4483345998",
    PremiumOnly = false
})

local function updateReskillDropdown()
    reskillPlayerNames = {}
    reskillNameMap = {}
    for _, p in ipairs(Players:GetPlayers()) do
        if p ~= LocalPlayer then
            local n = p.DisplayName .. " (" .. p.Name .. ")"
            table.insert(reskillPlayerNames, n)
            reskillNameMap[n] = p
        end
    end
    if reskillDropdown then
        reskillDropdown:Refresh(reskillPlayerNames, true)
    end
end

reskillDropdown = KillTab:AddDropdown({
    Name = "Select Target",
    Options = reskillPlayerNames,
    Default = "",
    Callback = function(val)
        reskillSelectedTargetName = reskillNameMap[val] and reskillNameMap[val].Name or ""
    end
})

Players.PlayerAdded:Connect(updateReskillDropdown)
Players.PlayerRemoving:Connect(updateReskillDropdown)
updateReskillDropdown()

KillTab:AddButton({ Name = "Refresh List", Callback = function() updateReskillDropdown() end })

KillTab:AddToggle({
    Name = "Loop Kill",
    Default = false,
    Callback = function(state)
        reskillLooping = state
        if not state then lastFlungCharacter = nil end
        task.spawn(function()
            while reskillLooping do
                local selectedTarget = Players:FindFirstChild(reskillSelectedTargetName)
                if selectedTarget and selectedTarget.Character then
                    local currentCharacter = selectedTarget.Character
                    if currentCharacter ~= lastFlungCharacter then
                        local hum = currentCharacter:FindFirstChild("Humanoid")
                        if hum and hum.Health > 0 then
                            execute_sequence(selectedTarget)
                            lastFlungCharacter = currentCharacter
                        end
                    end
                end
                task.wait(0.5)
            end
        end)
    end
})

local killAllLoop = false
local processedAll = {}
KillTab:AddToggle({
    Name = "Kill All",
    Default = false,
    Callback = function(state)
        killAllLoop = state
        if state then
            task.spawn(function()
                while killAllLoop do
                    for _, p in ipairs(Players:GetPlayers()) do
                        if not killAllLoop then break end
                        if p ~= LocalPlayer and p.Character then
                            local char = p.Character
                            if processedAll[p] ~= char then
                                if char:FindFirstChild("Humanoid") and char.Humanoid.Health > 0 then
                                    execute_sequence(p)
                                    processedAll[p] = char
                                    task.wait(0.2)
                                end
                            end
                        end
                    end
                    task.wait(1)
                end
            end)
        else
            table.clear(processedAll)
        end
    end
})

-- ------------------------------------------
-- [Tab 6] Object Aura
-- ------------------------------------------
local AuraobjTab = Window:MakeTab({
    Name = "Toy Mods",
    Icon = "rbxassetid://117381520745599",
    PremiumOnly = false
})

local function updateAuraPlayerDropdown()
    auraPlayerNames = {}
    auraNameMap = {}
    local myDisplay = "Self (" .. LocalPlayer.Name .. ")"
    table.insert(auraPlayerNames, myDisplay)
    auraNameMap[myDisplay] = LocalPlayer.Name
    for _, player in ipairs(Players:GetPlayers()) do
        if player ~= LocalPlayer then
            local display = player.DisplayName .. " (" .. player.Name .. ")"
            table.insert(auraPlayerNames, display)
            auraNameMap[display] = player.Name
        end
    end
    if auraPlayerDropdown then
        auraPlayerDropdown:Refresh(auraPlayerNames, true)
    end
end

AuraobjTab:AddDropdown({
    Name = "1. Select Collection Method",
    Default = "Manual Tap",
    Options = {"Manual Tap", "Auto Collect"},
    Callback = function(v)
        collectionMethod = v
        manualList = {}
    end
})

AuraobjTab:AddDropdown({
    Name = "2. Select Target Object",
    Default = "FireworkSparkler",
    Options = {"FireworkSparkler", "PoopPile"},
    Callback = function(v) targetObjectName = v end
})

auraPlayerDropdown = AuraobjTab:AddDropdown({
    Name = "3. Select Player to Attach",
    Options = auraPlayerNames,
    Default = "Self (" .. LocalPlayer.Name .. ")",
    Callback = function(v) auraTargetPlayerName = auraNameMap[v] end
})

AuraobjTab:AddLabel("--- Effect Settings ---")
AuraobjTab:AddDropdown({
    Name = "Effect Style",
    Default = "None",
    Options = {"None", "Wing", "Ring", "UpDown"},
    Callback = function(v) currentEffect = v end
})
AuraobjTab:AddSlider({
    Name = "Orbit Speed", Min = 0, Max = 1000, Default = 100, Increment = 10,
    Callback = function(v) AuraObjConfig.OrbitSpeed = v end
})
AuraobjTab:AddSlider({
    Name = "Overall Radius", Min = 5, Max = 100, Default = 15,
    Callback = function(v) AuraObjConfig.Radius = v end
})
AuraobjTab:AddSlider({
    Name = "Ring Height", Min = -20, Max = 50, Default = 5,
    Callback = function(v) AuraObjConfig.Height = v end
})

AuraobjTab:AddLabel("--- Wing Settings ---")
AuraobjTab:AddSlider({
    Name = "Wing Spacing", Min = 0, Max = 10, Default = 1.5, Increment = 0.1,
    Callback = function(v) AuraObjConfig.Wing.spacing = v end
})
AuraobjTab:AddSlider({
    Name = "Wing Base Spread", Min = 0, Max = 10, Default = 3, Increment = 0.5,
    Callback = function(v) AuraObjConfig.Wing.spread = v end
})
AuraobjTab:AddSlider({
    Name = "Flap Speed", Min = 0, Max = 20, Default = 5, Increment = 1,
    Callback = function(v) AuraObjConfig.Wing.flapSpeed = v end
})
AuraobjTab:AddSlider({
    Name = "Flap Amplitude", Min = 0, Max = 50, Default = 2.5, Increment = 0.1,
    Callback = function(v) AuraObjConfig.Wing.flapAmp = v end
})

AuraobjTab:AddLabel("--- UpDown Settings ---")
AuraobjTab:AddSlider({
    Name = "Up/Down Speed", Min = 0, Max = 20, Default = 5, Increment = 1,
    Callback = function(v) AuraObjConfig.UpDown.speed = v end
})
AuraobjTab:AddSlider({
    Name = "Up/Down Amplitude", Min = 0, Max = 30, Default = 5, Increment = 1,
    Callback = function(v) AuraObjConfig.UpDown.amp = v end
})

AuraobjTab:AddButton({ Name = "Reset Manual List", Callback = function() manualList = {} end })
Players.PlayerAdded:Connect(updateAuraPlayerDropdown)
Players.PlayerRemoving:Connect(updateAuraPlayerDropdown)
updateAuraPlayerDropdown()

-- ------------------------------------------
-- [Tab 7] Teleport (Minimap)
-- ------------------------------------------
local TeleportTab = Window:MakeTab({ Name = "Teleport", Icon = "rbxassetid://4483345998" })

TeleportTab:AddToggle({ Name = "Toggle Minimap", Default = false, Callback = function(v) MapFrame.Visible = v end })
TeleportTab:AddButton({ Name = "Reset View", Callback = function() mapOffset = Vector3.zero; lastScanPos = Vector3.new(0,0,0) end })
TeleportTab:AddParagraph("Controls", "- Quick Swipe: Move UI\n- Long Press (0.25s) & Swipe: Scroll Map\n- Tap: Teleport\n- 2-Finger Pinch: Zoom In/Out")

TeleportTab:AddSection({ Name = "Player Teleport" })
local TeleportTargetDropdown = TeleportTab:AddDropdown({
    Name = "Select Target",
    Default = "",
    Options = getPlayerList(),
    Callback = function(Value) selectedTeleportTargetName = playerMap[Value] or "" end
})

TeleportTab:AddButton({
    Name = "Refresh Player List",
    Callback = function() TeleportTargetDropdown:Refresh(getPlayerList(), true) end
})

TeleportTab:AddButton({
    Name = "Execute Teleport",
    Callback = function()
        if selectedTeleportTargetName and selectedTeleportTargetName ~= "" then
            local targetPlayer = Players:FindFirstChild(selectedTeleportTargetName)
            if targetPlayer and targetPlayer.Character and targetPlayer.Character:FindFirstChild("HumanoidRootPart") then
                local myRoot = LocalPlayer.Character and LocalPlayer.Character:FindFirstChild("HumanoidRootPart")
                if myRoot then
                    myRoot.CFrame = targetPlayer.Character.HumanoidRootPart.CFrame * CFrame.new(0, 0, 3)
                    OrionLib:MakeNotification({ Name = "Teleport", Content = targetPlayer.DisplayName .. " teleported successfully", Time = 2 })
                end
            else
                OrionLib:MakeNotification({ Name = "Error", Content = "Target not found or not spawned yet", Time = 3 })
            end
        else
            OrionLib:MakeNotification({ Name = "Error", Content = "Please select a teleport target first", Time = 2 })
        end
    end
})

-- ------------------------------------------
-- [Tab 8] Visuals (ESP)
-- ------------------------------------------
local VisualsTab = Window:MakeTab({ Name = "Visuals", Icon = "rbxassetid://4483345998", PremiumOnly = false })
VisualsTab:AddToggle({
    Name = "Enable ESP",
    Default = false,
    Callback = function(v)
        ESP_Settings.Enabled = v
        for _, p in pairs(Players:GetPlayers()) do
            if p.Character and p.Character:FindFirstChild("Head") then
                local ui = p.Character.Head:FindFirstChild("ESP_UI")
                if ui then ui.Enabled = v end
            end
        end
    end
})
VisualsTab:AddToggle({ Name = "Show Red Lines", Default = false, Callback = function(v) ESP_Settings.Lines = v end })

-- ------------------------------------------
-- [Tab 9] Server
-- ------------------------------------------
local ServerTab = Window:MakeTab({ Name = "Server / Line", Icon = "rbxassetid://4483345998", PremiumOnly = false })

ServerTab:AddSection({Name = "Server Load & Lines"})
ServerTab:AddToggle({
    Name = "Crazy Line",
    Default = false,
    Callback = function(state)
        running = state
        if running then
            coroutine.wrap(function()
                while running do
                    for i = 1, Go_g do
                        local players = game:GetService("Players"):GetPlayers()
                        if #players > 0 then
                            local randomPlayer = players[math.random(1, #players)]
                            game:GetService("ReplicatedStorage").GrabEvents.CreateGrabLine:FireServer(randomPlayer.Character and randomPlayer.Character:FindFirstChild("HumanoidRootPart") or nil, CFrame.new(0, 0, 0))
                        end
                    end
                    task.wait()
                end
            end)()
        end
    end
})
ServerTab:AddSlider({
    Name = "Crazy Line Amount", Min = 1, Max = 25, Color = Color3.fromRGB(255, 255, 255), Increment = 1, Default = Go_g,
    Callback = function(value) Go_g = value end
})

ServerTab:AddToggle({
    Name = "Lag Server",
    Default = false,
    Callback = function(LagServer1)
        ragServer = LagServer1
        if ragServer then
            coroutine.wrap(function()
                while ragServer do
                    for i = 1, PP_dd do
                        game:GetService("ReplicatedStorage").GrabEvents.CreateGrabLine:FireServer(Workspace:FindFirstChildOfClass("Part"), CFrame.new(math.random(-0, 0), math.random(-0, 0), math.random(-0, 0)))
                    end
                    task.wait(0)
                end
            end)()
        end
    end
})
ServerTab:AddSlider({
    Name = "Lag Server Amount", Min = 50, Max = 5000, Color = Color3.fromRGB(255, 255, 255), Increment = 1, Default = PP_dd,
    Callback = function(value) PP_dd = value end
})

ServerTab:AddSection({Name = "Server Management"})
ServerTab:AddButton({
    Name = "Rejoin Server",
    Callback = function() game:GetService("TeleportService"):TeleportToPlaceInstance(game.PlaceId, game.JobId, LocalPlayer) end
})
ServerTab:AddButton({
    Name = "Break Barrier",
    Callback = function()
        local char = LocalPlayer.Character
        local rootPart = char and char:FindFirstChild("HumanoidRootPart")
        if not rootPart then return end
        
        local originalPos = rootPart.CFrame
        ReplicatedStorage.MenuToys.SpawnToyRemoteFunction:InvokeServer("InstrumentWoodwindOcarina", rootPart.CFrame * CFrame.new(0, 0, -3), Vector3.new(0, 34, 0))
        task.wait(0.3)
        
        local toyFolder = Workspace:FindFirstChild(LocalPlayer.Name .. "SpawnedInToys")
        local ocarina = toyFolder and toyFolder:FindFirstChild("InstrumentWoodwindOcarina")
        
        if ocarina then
            local holdRemote = ocarina:FindFirstChild("HoldPart") and ocarina.HoldPart:FindFirstChild("HoldItemRemoteFunction")
            if holdRemote then
                holdRemote:InvokeServer(ocarina, char)
                rootPart.CFrame = CFrame.new(268, -7, 440)
                task.wait(1)
                ReplicatedStorage.MenuToys.DestroyToy:FireServer(ocarina)
                rootPart.CFrame = originalPos
            end
        end
    end
})

ServerTab:AddSection({Name = "Train Control"})
ServerTab:AddButton({
    Name = "Launch vFly GUI",
    Callback = function()
        pcall(function() loadstring(game:HttpGet('https://raw.githubusercontent.com/makkurokurosukescript/VFly-gui/refs/heads/main/VFly%20gui'))() end)
    end
})

ServerTab:AddSection({Name = "Fake Typing"})

ServerTab:AddButton({
    Name = "Fake Typing",
    Callback = function()
        print("button pressed")
        game:GetService("ReplicatedStorage").CharacterEvents.ChatTyping:FireServer("begin")
    end
})

OrionLib:Init()
