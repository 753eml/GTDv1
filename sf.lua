-- Linoria Sunflower Collector (short & integrated)
local repo = "https://raw.githubusercontent.com/violin-suzutsuki/LinoriaLib/main/"
local Library = loadstring(game:HttpGet(repo .. "Library.lua"))()
local ThemeManager = loadstring(game:HttpGet(repo .. "addons/ThemeManager.lua"))()
local SaveManager = loadstring(game:HttpGet(repo .. "addons/SaveManager.lua"))()

-- Window (notifications on right)
local Window = Library:CreateWindow({
    Title = "Green Hub | Sunflower Collector",
    Center = true,
    AutoShow = true,
    NotifySide = "Right",
    ShowCustomCursor = true,
})

-- Managers
ThemeManager:SetLibrary(Library)
SaveManager:SetLibrary(Library)
ThemeManager:SetFolder("GreenHub")
SaveManager:SetFolder("GreenHub")

-- Tabs / Groups
local Tabs = {
    Main = Window:AddTab("Main", "user"),
    Settings = Window:AddTab("Settings", "settings")
}
local CollectorGroup = Tabs.Main:AddLeftGroupbox("Collector")
local CameraGroup = Tabs.Main:AddRightGroupbox("Camera")
local SettingsGroup = Tabs.Settings:AddLeftGroupbox("Misc Settings")

-- Services & player
local Players = game:GetService("Players")
local TweenService = game:GetService("TweenService")
local RunService = game:GetService("RunService")
local player = Players.LocalPlayer
local character = player.Character or player.CharacterAdded:Wait()
local root = character:WaitForChild("HumanoidRootPart")
local effectHolder = workspace:WaitForChild("EffectHolder")

-- Collector state
local SunflowerCollector = {
    Status = "Idle",
    Enabled = false,
    SunflowerQueue = {},
    Processing = false,
    SafeCFrame = root.CFrame,
    LastTime = 0
}

-- Defaults
getgenv().WaitBefore = 0.7
getgenv().WaitAt = 0.7

local RETURN_TIME = 0.1
local RETURN_CHECK = 0.2

-- safe notify helper (tries library notify, falls back to simple GUI toast)
local function notify(title, desc, dur)
    dur = dur or 3
    pcall(function()
        if Library.Notify then
            -- Linoria historically accepts a table in :Notify
            Library:Notify({Title = title, Description = desc, Duration = dur})
        else
            -- fallback toast (top-right)
            local screen = Instance.new("ScreenGui")
            screen.Name = "CollectorNotify"
            screen.ResetOnSpawn = false
            screen.Parent = game.CoreGui
            local frame = Instance.new("Frame", screen)
            frame.Size = UDim2.new(0, 260, 0, 56)
            frame.Position = UDim2.new(1, -270, 0, 12)
            frame.BackgroundTransparency = 0.12
            frame.BackgroundColor3 = Color3.fromRGB(60, 30, 90)
            frame.BorderSizePixel = 0
            local t = Instance.new("TextLabel", frame)
            t.Size = UDim2.new(1, -10, 0, 22); t.Position = UDim2.new(0, 8, 0, 4)
            t.BackgroundTransparency = 1; t.Font = Enum.Font.GothamBold; t.TextSize = 16
            t.TextColor3 = Color3.fromRGB(255,255,255); t.Text = title
            local d = Instance.new("TextLabel", frame)
            d.Size = UDim2.new(1, -10, 0, 28); d.Position = UDim2.new(0, 8, 0, 24)
            d.BackgroundTransparency = 1; d.Font = Enum.Font.Gotham; d.TextSize = 14
            d.TextColor3 = Color3.fromRGB(230,230,230); d.Text = desc
            task.delay(dur, function() pcall(function() screen:Destroy() end) end)
        end
    end)
end

-- helpers
local function tweenTo(cf, dur)
    if not root or not root.Parent then return end
    local tw = TweenService:Create(root, TweenInfo.new(dur, Enum.EasingStyle.Sine), {CFrame = cf})
    tw:Play(); tw.Completed:Wait()
end

local function waitForPrimaryPart(model)
    if model.PrimaryPart then return model.PrimaryPart end
    local bp = model:FindFirstChildWhichIsA("BasePart", true)
    if bp then pcall(function() model.PrimaryPart = bp end); return bp end
end

-- main collector
local function processSunflowers()
    if SunflowerCollector.Processing or not SunflowerCollector.Enabled then return end
    SunflowerCollector.Processing = true
    SunflowerCollector.SafeCFrame = root.CFrame

    while SunflowerCollector.Enabled do
        while #SunflowerCollector.SunflowerQueue > 0 and SunflowerCollector.Enabled do
            local model = table.remove(SunflowerCollector.SunflowerQueue, 1)
            if model and model.Name == "Sunflower" then
                local primary = waitForPrimaryPart(model)
                if primary and primary.Parent then
                    for _, d in ipairs(model:GetDescendants()) do
                        if d:IsA("BasePart") then
                            pcall(function() d.CanCollide = false end)
                        end
                    end

                    SunflowerCollector.Status = "Idle"
                    task.wait(getgenv().WaitBefore or 0.7)
                    if not SunflowerCollector.Enabled then break end

                    SunflowerCollector.Status = "Collecting"
                    notify("🌿 Collector", "Teleporting to Sunflower", 1.5)
                    tweenTo(primary.CFrame, 0.3) -- fixed tween duration
                    task.wait(getgenv().WaitAt or 0.7)
                end
            end
        end

        if tick() - (SunflowerCollector.LastTime or 0) > RETURN_CHECK then
            if SunflowerCollector.Enabled then
                SunflowerCollector.Status = "Returning"
                tweenTo(SunflowerCollector.SafeCFrame, RETURN_TIME)
                SunflowerCollector.Status = "Idle"
            end
            break
        end
        RunService.Heartbeat:Wait()
    end

    SunflowerCollector.Processing = false
end

-- effect holder hooks
effectHolder.ChildAdded:Connect(function(model)
    if model and model.Name == "Sunflower" then
        table.insert(SunflowerCollector.SunflowerQueue, model)
        SunflowerCollector.LastTime = tick()
        if SunflowerCollector.Enabled then task.spawn(processSunflowers) end
    end
end)

for _, v in ipairs(effectHolder:GetChildren()) do
    if v and v.Name == "Sunflower" then
        table.insert(SunflowerCollector.SunflowerQueue, v)
        SunflowerCollector.LastTime = tick()
    end
end

-- save idle pos continuously (and export to getgenv)
task.spawn(function()
    while true do
        if root and root.Parent and not SunflowerCollector.Processing then
            SunflowerCollector.SafeCFrame = root.CFrame
            getgenv().LastIdleCFrame = SunflowerCollector.SafeCFrame
        end
        task.wait(1/60)
    end
end)

player.CharacterAdded:Connect(function(c)
    character = c; root = character:WaitForChild("HumanoidRootPart")
end)

-- UI : Collector Group
local StatusLabel = CollectorGroup:AddLabel("Status: " .. SunflowerCollector.Status)

CollectorGroup:AddToggle("CollectorToggle", {
    Text = "Enable Collector",
    Default = false,
    Callback = function(val)
        SunflowerCollector.Enabled = val
        if val then
            StatusLabel:SetText("Status: Idle")
            notify("🌿 Collector", "Enabled", 2)
            task.spawn(processSunflowers)
        else
            StatusLabel:SetText("Status: Disabled")
            notify("🌿 Collector", "Disabled", 2)
        end
    end
})

CollectorGroup:AddSlider("WaitBefore", {
    Text = "Wait Before",
    Min = 0,
    Max = 1,
    Default = getgenv().WaitBefore,
    Rounding = 1,
    Callback = function(v) getgenv().WaitBefore = v end
})

CollectorGroup:AddSlider("WaitAt", {
    Text = "Wait At",
    Min = 0.4,
    Max = 1,
    Default = getgenv().WaitAt,
    Rounding = 1,
    Callback = function(v) getgenv().WaitAt = v end
})

-- Camera Group (only Lock camera)
CameraGroup:AddToggle("CameraLock", {
    Text = "Lock Camera",
    Default = false,
    Callback = function(v)
        getgenv().CameraLock = v
        notify("Camera", v and "Locked" or "Unlocked", 2)
    end
})

-- Settings group: color + save idle pos + unload
SettingsGroup:AddLabel("UI Theme Color"):AddColorPicker("UIColor", {
    Default = Color3.fromRGB(153, 102, 255),
    Title = "Theme Color",
    Callback = function(Value) Library.Scheme.Color = Value end
})

SettingsGroup:AddButton({
    Text = "Save Idle Position",
    Func = function()
        if root and root.Parent then
            SunflowerCollector.SafeCFrame = root.CFrame
            getgenv().LastIdleCFrame = SunflowerCollector.SafeCFrame
            notify("🌿 Collector", "Idle position saved", 2)
        else
            notify("🌿 Collector", "Can't save: no character", 2)
        end
    end
})

SettingsGroup:AddButton({
    Text = "Unload Script",
    Func = function()
        SunflowerCollector.Enabled = false
        getgenv().CameraLock = false
        notify("🌿 Collector", "Unloaded", 2)
        Library:Unload()
    end
})

-- status updater
RunService.RenderStepped:Connect(function()
    StatusLabel:SetText("Status: " .. SunflowerCollector.Status)
end)

-- Build save/theme UI
SaveManager:BuildConfigSection(Tabs.Settings)
ThemeManager:ApplyToTab(Tabs.Settings)
