local Players = game:GetService("Players")
local LocalPlayer = Players.LocalPlayer
local Camera = game:GetService("Workspace").CurrentCamera
local UserInputService = game:GetService("UserInputService")
local RunService = game:GetService("RunService")
local VirtualInputManager = game:GetService("VirtualInputManager")

local lastClickTime = 0
local isToggled = false
local TargetPlayer = nil

function Forlorn.mouse1click(x, y)
    VirtualInputManager:SendMouseButtonEvent(x, y, 0, true, game, false)
    VirtualInputManager:SendMouseButtonEvent(x, y, 0, false, game, false)
end

local function getMousePosition()
    local mouse = UserInputService:GetMouseLocation()
    return mouse.X, mouse.Y
end

local function isWithinBoxFOV(position)
    local screenPos = Camera:WorldToViewportPoint(position)
    local screenCenter = Vector2.new(Camera.ViewportSize.X / 2, Camera.ViewportSize.Y / 2)
    local fovHeight = getgenv().BoxFov.Height * 100
    local fovWidth = getgenv().BoxFov.Width * 100

    return (Vector2.new(screenPos.X, screenPos.Y) - screenCenter).Magnitude <= math.sqrt((fovHeight / 2)^2 + (fovWidth / 2)^2)
end

local function getPredictedPosition(character)
    local primaryPart = character:FindFirstChild("HumanoidRootPart") or character:FindFirstChild("Head")
    if primaryPart then
        local velocity = primaryPart.Velocity
        local timeToPredict = getgenv().TriggerBot.Settings.Preds.TimeToPredict or 0.08

        local predictedPosition = primaryPart.Position + (velocity * timeToPredict)

        if character.Humanoid:GetState() == Enum.HumanoidStateType.Freefall then
            predictedPosition = predictedPosition + Vector3.new(0, -0.5, 0)
        end
        
        return predictedPosition
    end
    return nil
end

local function syncBoxWithTarget(predictedPosition)
    local screenPosition, onScreen = Camera:WorldToViewportPoint(predictedPosition)
    if onScreen then
        local centerX = Camera.ViewportSize.X / 2
        local centerY = Camera.ViewportSize.Y / 2

        local offsetX = screenPosition.X - centerX
        local offsetY = screenPosition.Y - centerY

        VirtualInputManager:SendMouseMoveEvent(centerX + offsetX, centerY + offsetY, game)
    end
end

local function isPlayerKnocked(player)
    local humanoid = player.Character and player.Character:FindFirstChild("Humanoid")
    if humanoid then
        return humanoid.Health > 0 and humanoid.Health <= 7
    end
    return false
end

local function isIgnoringKnife()
    local currentTool = LocalPlayer.Character:FindFirstChildOfClass("Tool")
    if currentTool then
        local toolName = currentTool.Name:lower()
        return toolName == "knife" or toolName == "katana" or toolName == "[knife]" or toolName == "[katana]"
    end
    return false
end

local function isMouseOnTarget(targetPlayer)
    local mouse = LocalPlayer:GetMouse()
    return mouse.Target and mouse.Target:IsDescendantOf(targetPlayer.Character)
end

local function TriggerBotAction()
    if TargetPlayer and TargetPlayer.Character then
        local humanoid = TargetPlayer.Character:FindFirstChild("Humanoid")
        if humanoid and humanoid.Health > 0 and not isPlayerKnocked(TargetPlayer) then
            if isMouseOnTarget(TargetPlayer) then
                local predictedPosition = getPredictedPosition(TargetPlayer.Character)
                if predictedPosition and isWithinBoxFOV(predictedPosition) then
                    -- Sync the box with the target’s predicted position for precise aiming
                    syncBoxWithTarget(predictedPosition)

                    if os.clock() - lastClickTime >= 0.01 then  -- Cooldown time
                        lastClickTime = os.clock()
                        
                        local tool = LocalPlayer.Character:FindFirstChildOfClass("Tool")
                        if tool and tool:IsA("Tool") then
                            if not isIgnoringKnife() then
                                local shootFunction = tool:FindFirstChild("Fire")
                                if shootFunction and shootFunction:IsA("RemoteEvent") then
                                    shootFunction:FireServer(TargetPlayer.Character)
                                else
                                    local mouseX, mouseY = getMousePosition()
                                    Forlorn.mouse1click(mouseX, mouseY)
                                end
                            end
                        end
                    end
                end
            end
        end
    end
end

UserInputService.InputBegan:Connect(function(input, gameProcessed)
    if not gameProcessed and input.KeyCode == Enum.KeyCode[getgenv().KeyTrigger.TriggerBot:upper()] then
        isToggled = true
    end
end)

UserInputService.InputEnded:Connect(function(input, gameProcessed)
    if not gameProcessed and input.KeyCode == Enum.KeyCode[getgenv().KeyTrigger.TriggerBot:upper()] then
        isToggled = false
    end
end)

RunService.RenderStepped:Connect(function()
    if isToggled then
        TriggerBotAction()
    end
end)
