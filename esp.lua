local ESP = {
    Enabled = false,
    Boxes = true,
    BoxShift = CFrame.new(0, -1.5, 0),
    BoxSize = Vector3.new(4, 6, 0),
    Color = Color3.fromRGB(255, 170, 0),
    Thickness = 2,
    AttachShift = 1,
    
    Objects = setmetatable({}, {__mode="kv"}),
    Overrides = {}
}

local cam = workspace.CurrentCamera
local plrs = game:GetService("Players")
local plr = plrs.LocalPlayer
local mouse = plr:GetMouse()

local V3new = Vector3.new
local WorldToViewportPoint = cam.WorldToViewportPoint

local function Draw(obj, props)
    local success, new = pcall(Drawing.new, obj)
    if not success then
        warn("Failed to create Drawing object: ", new)
        return nil
    end
    
    props = props or {}
    for i, v in pairs(props) do
        new[i] = v
    end
    return new
end

function ESP:GetColor(obj)
    local ov = self.Overrides.GetColor
    if ov then
        return ov(obj)
    end
    local p = self:GetPlrFromChar(obj)
    return p and self.Color
end

function ESP:GetPlrFromChar(char)
    local ov = self.Overrides.GetPlrFromChar
    if ov then
        return ov(char)
    end
    return plrs:GetPlayerFromCharacter(char)
end

function ESP:Toggle(bool)
    self.Enabled = bool
    if not bool then
        for i, v in pairs(self.Objects) do
            if v.Type == "Box" then
                if v.Temporary then
                    v:Remove()
                else
                    for i, v in pairs(v.Components) do
                        v.Visible = false
                    end
                end
            end
        end
    end
end

function ESP:GetBox(obj)
    return self.Objects[obj]
end

function ESP:AddObjectListener(parent, options)
    if not parent then
        warn("Parent is nil. Ensure the folder or object exists before adding a listener.")
        return
    end

    local function NewListener(c)
        if (type(options.Type) == "string" and c:IsA(options.Type)) or options.Type == nil then
            if type(options.Name) == "string" and c.Name == options.Name or options.Name == nil then
                if not options.Validator or options.Validator(c) then
                    if c.Parent and workspace:IsAncestorOf(c) then
                        local box = ESP:Add(c, {
                            PrimaryPart = type(options.PrimaryPart) == "string" and c:WaitForChild(options.PrimaryPart) or type(options.PrimaryPart) == "function" and options.PrimaryPart(c),
                            Color = type(options.Color) == "function" and options.Color(c) or options.Color,
                            ColorDynamic = options.ColorDynamic,
                            IsEnabled = options.IsEnabled,
                            RenderInNil = options.RenderInNil
                        })
                        if options.OnAdded then
                            coroutine.wrap(options.OnAdded)(box)
                        end
                    else
                        warn(c.Name .. " has no parent, skipping ESP addition.")
                    end
                end
            end
        end
    end
    
    if options.Recursive then
        parent.DescendantAdded:Connect(NewListener)
        for i, v in pairs(parent:GetDescendants()) do
            NewListener(v)
        end
    else
        parent.ChildAdded:Connect(NewListener)
        for i, v in pairs(parent:GetChildren()) do
            NewListener(v)
        end
    end
end

local boxBase = {}
boxBase.__index = boxBase

function boxBase:Remove()
    ESP.Objects[self.Object] = nil
    for i, v in pairs(self.Components) do
        if v then
            v.Visible = false
            v:Remove()
            self.Components[i] = nil
        end
    end
end

function boxBase:Update()
    if not self.PrimaryPart then
        return self:Remove()
    end

    local allow = true

    if ESP.Overrides.UpdateAllow and not ESP.Overrides.UpdateAllow(self) then
        allow = false
    end
    if self.IsEnabled and (type(self.IsEnabled) == "string" and not ESP[self.IsEnabled] or type(self.IsEnabled) == "function" and not self:IsEnabled()) then
        allow = false
    end
    if not workspace:IsAncestorOf(self.PrimaryPart) and not self.RenderInNil then
        allow = false
    end

    if not allow then
        for i, v in pairs(self.Components) do
            if v then
                v.Visible = false
            end
        end
        return
    end

    local size = self.Size
    local cf = self.PrimaryPart.CFrame

    local locs = {
        TopLeft = WorldToViewportPoint(cam, (cf * ESP.BoxShift * CFrame.new(size.X / 2, size.Y / 2, 0)).Position),
        TopRight = WorldToViewportPoint(cam, (cf * ESP.BoxShift * CFrame.new(-size.X / 2, size.Y / 2, 0)).Position),
        BottomLeft = WorldToViewportPoint(cam, (cf * ESP.BoxShift * CFrame.new(size.X / 2, -size.Y / 2, 0)).Position),
        BottomRight = WorldToViewportPoint(cam, (cf * ESP.BoxShift * CFrame.new(-size.X / 2, -size.Y / 2, 0)).Position)
    }

    if self.Components.Quad then
        if locs.TopRight.Z > 0 and locs.TopLeft.Z > 0 and locs.BottomLeft.Z > 0 and locs.BottomRight.Z > 0 then
            self.Components.Quad.Visible = true
            self.Components.Quad.PointA = Vector2.new(locs.TopRight.X, locs.TopRight.Y)
            self.Components.Quad.PointB = Vector2.new(locs.TopLeft.X, locs.TopLeft.Y)
            self.Components.Quad.PointC = Vector2.new(locs.BottomLeft.X, locs.BottomLeft.Y)
            self.Components.Quad.PointD = Vector2.new(locs.BottomRight.X, locs.BottomRight.Y)
            self.Components.Quad.Color = self.Color or ESP.Color
        else
            self.Components.Quad.Visible = false
        end
        self.Components.Quad.Color = self.Color or ESP.Color
    end
end

function ESP:Add(obj, options)
    if not obj.Parent and not options.RenderInNil then
        warn(obj.Name .. " has no parent, skipping ESP addition.")
        return
    end

    local box = setmetatable({
        Type = "Box",
        Color = options.Color,
        Size = options.Size or self.BoxSize,
        Object = obj,
        Player = options.Player or plrs:GetPlayerFromCharacter(obj),
        PrimaryPart = options.PrimaryPart or obj.ClassName == "Model" and (obj.PrimaryPart or obj:FindFirstChild("HumanoidRootPart") or obj:FindFirstChildWhichIsA("BasePart")) or obj:IsA("BasePart") and obj,
        Components = {},
        IsEnabled = options.IsEnabled,
        Temporary = options.Temporary,
        ColorDynamic = options.ColorDynamic,
        RenderInNil = options.RenderInNil
    }, boxBase)

    if not box.PrimaryPart then
        warn("PrimaryPart not found for object:", obj.Name)
        return
    end

    if self:GetBox(obj) then
        self:GetBox(obj):Remove()
    end

    box.Components["Quad"] = Draw("Quad", {
        Thickness = self.Thickness,
        Color = box.Color,
        Transparency = 1,
        Filled = false,
        Visible = self.Enabled and self.Boxes
    })

    if not box.Components["Quad"] then
        warn("Failed to create Quad for object:", obj.Name)
        return
    end

    self.Objects[obj] = box

    obj.AncestryChanged:Connect(function(_, parent)
        if parent == nil and ESP.AutoRemove ~= false then
            box:Remove()
        end
    end)
    obj:GetPropertyChangedSignal("Parent"):Connect(function()
        if obj.Parent == nil and ESP.AutoRemove ~= false then
            box:Remove()
        end
    end)

    local hum = obj:FindFirstChildOfClass("Humanoid")
    if hum then
        hum.Died:Connect(function()
            if ESP.AutoRemove ~= false then
                box:Remove()
            end
        end)
    end

    return box
end

local function CharAdded(char)
    local p = plrs:GetPlayerFromCharacter(char)
    if not char:FindFirstChild("HumanoidRootPart") then
        local ev
        ev = char.ChildAdded:Connect(function(c)
            if c.Name == "HumanoidRootPart" then
                ev:Disconnect()
                print("Adding ESP for character:", char.Name)
                ESP:Add(char, {
                    Player = p,
                    PrimaryPart = c
                })
            end
        end)
    else
        print("Adding ESP for character:", char.Name)
        ESP:Add(char, {
            Player = p,
            PrimaryPart = char.HumanoidRootPart
        })
    end
end

local function PlayerAdded(p)
    p.CharacterAdded:Connect(CharAdded)
    if p.Character then
        coroutine.wrap(CharAdded)(p.Character)
    end
end
plrs.PlayerAdded:Connect(PlayerAdded)
for i, v in pairs(plrs:GetPlayers()) do
    if v ~= plr then
        PlayerAdded(v)
    end
end

game:GetService("RunService").RenderStepped:Connect(function()
    cam = workspace.CurrentCamera
    for i, v in pairs(ESP.Objects) do
        if v.Update then
            local s, e = pcall(v.Update, v)
            if not s then
                warn("[ESP Update Error]", e)
            end
        end
    end
end)

-- GUI with Key System
local Players = game:GetService("Players")
local UserInputService = game:GetService("UserInputService")
local StarterGui = game:GetService("StarterGui")

-- Create ScreenGui
local ScreenGui = Instance.new("ScreenGui")
ScreenGui.Name = "ESPMenu"
ScreenGui.ResetOnSpawn = false
ScreenGui.Enabled = true
ScreenGui.Parent = Players.LocalPlayer:WaitForChild("PlayerGui")

-- Key Input Frame
local KeyFrame = Instance.new("Frame")
KeyFrame.Size = UDim2.new(0, 300, 0, 150)
KeyFrame.Position = UDim2.new(0.5, -150, 0.5, -75)
KeyFrame.BackgroundColor3 = Color3.fromRGB(30, 30, 30)
KeyFrame.BorderSizePixel = 0
KeyFrame.Parent = ScreenGui

local KeyTitle = Instance.new("TextLabel")
KeyTitle.Size = UDim2.new(1, 0, 0, 30)
KeyTitle.BackgroundColor3 = Color3.fromRGB(50, 50, 50)
KeyTitle.Text = "Активация"
KeyTitle.TextColor3 = Color3.fromRGB(255, 255, 255)
KeyTitle.TextSize = 16
KeyTitle.Font = Enum.Font.SourceSansBold
KeyTitle.Parent = KeyFrame

local KeyInput = Instance.new("TextBox")
KeyInput.Size = UDim2.new(0.9, 0, 0, 30)
KeyInput.Position = UDim2.new(0.05, 0, 0, 40)
KeyInput.BackgroundColor3 = Color3.fromRGB(70, 70, 70)
KeyInput.Text = ""
KeyInput.PlaceholderText = "Введите пароль (который получили при оплате)"
KeyInput.TextColor3 = Color3.fromRGB(255, 255, 255)
KeyInput.TextSize = 14
KeyInput.Font = Enum.Font.SourceSans
KeyInput.Parent = KeyFrame

local SubmitKeyButton = Instance.new("TextButton")
SubmitKeyButton.Size = UDim2.new(0.9, 0, 0, 30)
SubmitKeyButton.Position = UDim2.new(0.05, 0, 0, 80)
SubmitKeyButton.BackgroundColor3 = Color3.fromRGB(100, 100, 100)
SubmitKeyButton.Text = "Подтвердить ключ"
SubmitKeyButton.TextColor3 = Color3.fromRGB(255, 255, 255)
SubmitKeyButton.TextSize = 14
SubmitKeyButton.Font = Enum.Font.SourceSans
SubmitKeyButton.Parent = KeyFrame

local KeyErrorLabel = Instance.new("TextLabel")
KeyErrorLabel.Size = UDim2.new(0.9, 0, 0, 30)
KeyErrorLabel.Position = UDim2.new(0.05, 0, 0, 110)
KeyErrorLabel.BackgroundTransparency = 1
KeyErrorLabel.Text = ""
KeyErrorLabel.TextColor3 = Color3.fromRGB(255, 50, 50)
KeyErrorLabel.TextSize = 12
KeyErrorLabel.Font = Enum.Font.SourceSans
KeyErrorLabel.Parent = KeyFrame

-- Main GUI Frame (Initially Hidden)
local MainFrame = Instance.new("Frame")
MainFrame.Size = UDim2.new(0, 300, 0, 350)
MainFrame.Position = UDim2.new(0.5, -150, 0.5, -175)
MainFrame.BackgroundColor3 = Color3.fromRGB(30, 30, 30)
MainFrame.BorderSizePixel = 0
MainFrame.Active = true
MainFrame.Draggable = true
MainFrame.Visible = false
MainFrame.Parent = ScreenGui

local Title = Instance.new("TextLabel")
Title.Size = UDim2.new(1, 0, 0, 30)
Title.BackgroundColor3 = Color3.fromRGB(50, 50, 50)
Title.Text = "ESP MOD"
Title.TextColor3 = Color3.fromRGB(255, 255, 255)
Title.TextSize = 16
Title.Font = Enum.Font.SourceSansBold
Title.Parent = MainFrame

local ToggleESP = Instance.new("TextButton")
ToggleESP.Size = UDim2.new(0.9, 0, 0, 30)
ToggleESP.Position = UDim2.new(0.05, 0, 0, 40)
ToggleESP.Text = "ESP: Включён"
ToggleESP.TextColor3 = Color3.fromRGB(255, 255, 255)
ToggleESP.BackgroundColor3 = Color3.fromRGB(70, 70, 70)
ToggleESP.TextSize = 14
ToggleESP.Font = Enum.Font.SourceSans
ToggleESP.Parent = MainFrame

local ToggleBoxes = Instance.new("TextButton")
ToggleBoxes.Size = UDim2.new(0.9, 0, 0, 30)
ToggleBoxes.Position = UDim2.new(0.05, 0, 0, 80)
ToggleBoxes.Text = "Boxes: Включён"
ToggleBoxes.TextColor3 = Color3.fromRGB(255, 255, 255)
ToggleBoxes.BackgroundColor3 = Color3.fromRGB(70, 70, 70)
ToggleBoxes.TextSize = 14
ToggleBoxes.Font = Enum.Font.SourceSans
ToggleBoxes.Parent = MainFrame

local ColorLabel = Instance.new("TextLabel")
ColorLabel.Size = UDim2.new(0.9, 0, 0, 20)
ColorLabel.Position = UDim2.new(0.05, 0, 0, 120)
ColorLabel.Text = "Редактор цвета ESP"
ColorLabel.TextColor3 = Color3.fromRGB(255, 255, 255)
ColorLabel.BackgroundTransparency = 1
ColorLabel.TextSize = 14
ColorLabel.Font = Enum.Font.SourceSans
ColorLabel.Parent = MainFrame

local ColorR = Instance.new("TextBox")
ColorR.Size = UDim2.new(0.3, -5, 0, 30)
ColorR.Position = UDim2.new(0.05, 0, 0, 145)
ColorR.Text = tostring(math.floor(ESP.Color.R * 255))
ColorR.TextColor3 = Color3.fromRGB(255, 255, 255)
ColorR.BackgroundColor3 = Color3.fromRGB(70, 70, 70)
ColorR.TextSize = 14
ColorR.Font = Enum.Font.SourceSans
ColorR.PlaceholderText = "R (0-255)"
ColorR.Parent = MainFrame

local ColorG = Instance.new("TextBox")
ColorG.Size = UDim2.new(0.3, -5, 0, 30)
ColorG.Position = UDim2.new(0.35, 0, 0, 145)
ColorG.Text = tostring(math.floor(ESP.Color.G * 255))
ColorG.TextColor3 = Color3.fromRGB(255, 255, 255)
ColorG.BackgroundColor3 = Color3.fromRGB(70, 70, 70)
ColorG.TextSize = 14
ColorG.Font = Enum.Font.SourceSans
ColorG.PlaceholderText = "G (0-255)"
ColorG.Parent = MainFrame

local ColorB = Instance.new("TextBox")
ColorB.Size = UDim2.new(0.3, -5, 0, 30)
ColorB.Position = UDim2.new(0.65, 0, 0, 145)
ColorB.Text = tostring(math.floor(ESP.Color.B * 255))
ColorB.TextColor3 = Color3.fromRGB(255, 255, 255)
ColorB.BackgroundColor3 = Color3.fromRGB(70, 70, 70)
ColorB.TextSize = 14
ColorB.Font = Enum.Font.SourceSans
ColorB.PlaceholderText = "B (0-255)"
ColorB.Parent = MainFrame

local ThicknessLabel = Instance.new("TextLabel")
ThicknessLabel.Size = UDim2.new(0.9, 0, 0, 20)
ThicknessLabel.Position = UDim2.new(0.05, 0, 0, 185)
ThicknessLabel.Text = "Толщина линии Boxes"
ThicknessLabel.TextColor3 = Color3.fromRGB(255, 255, 255)
ThicknessLabel.BackgroundTransparency = 1
ThicknessLabel.TextSize = 14
ThicknessLabel.Font = Enum.Font.SourceSans
ThicknessLabel.Parent = MainFrame

local ThicknessBox = Instance.new("TextBox")
ThicknessBox.Size = UDim2.new(0.9, 0, 0, 30)
ThicknessBox.Position = UDim2.new(0.05, 0, 0, 210)
ThicknessBox.Text = tostring(ESP.Thickness)
ThicknessBox.TextColor3 = Color3.fromRGB(255, 255, 255)
ThicknessBox.BackgroundColor3 = Color3.fromRGB(70, 70, 70)
ThicknessBox.TextSize = 14
ThicknessBox.Font = Enum.Font.SourceSans
ThicknessBox.PlaceholderText = "Thickness (1-10)"
ThicknessBox.Parent = MainFrame

local CloseButton = Instance.new("TextButton")
CloseButton.Size = UDim2.new(0.9, 0, 0, 30)
CloseButton.Position = UDim2.new(0.05, 0, 0, 250)
CloseButton.BackgroundColor3 = Color3.fromRGB(200, 50, 50)
CloseButton.Text = "Закрыть скрипт"
CloseButton.TextColor3 = Color3.fromRGB(255, 255, 255)
CloseButton.TextSize = 14
CloseButton.Font = Enum.Font.SourceSans
CloseButton.Parent = MainFrame

-- Add Corner Radius
local UICorner = Instance.new("UICorner")
UICorner.CornerRadius = UDim.new(0, 5)
UICorner.Parent = KeyFrame
UICorner:Clone().Parent = MainFrame
UICorner:Clone().Parent = KeyTitle
UICorner:Clone().Parent = Title
UICorner:Clone().Parent = ToggleESP
UICorner:Clone().Parent = ToggleBoxes
UICorner:Clone().Parent = ColorR
UICorner:Clone().Parent = ColorG
UICorner:Clone().Parent = ColorB
UICorner:Clone().Parent = ThicknessBox
UICorner:Clone().Parent = SubmitKeyButton
UICorner:Clone().Parent = CloseButton

-- Key System Logic
local correctKey = "S2JE5-Q9RUT-ESP"
SubmitKeyButton.MouseButton1Click:Connect(function()
    if KeyInput.Text == correctKey then
        KeyFrame.Visible = false
        MainFrame.Visible = true
        StarterGui:SetCore("SendNotification", {
            Title = "Доступ предоставлен",
            Text = " ESP разблокирован. Спасибо за покупку скрипта.",
            Duration = 5
        })
        -- Initialize ESP
        ESP:Toggle(true)
        ESP.Boxes = true
    else
        KeyErrorLabel.Text = "Недействительный ключ! Пробуйте снова."
        KeyInput.Text = ""
    end
end)

KeyInput.FocusLost:Connect(function(enterPressed)
    if enterPressed then
        SubmitKeyButton:Activate()
    end
end)

-- GUI Functionality
ToggleESP.MouseButton1Click:Connect(function()
    local success, err = pcall(function()
        ESP:Toggle(not ESP.Enabled)
        ToggleESP.Text = "ESP: " .. (ESP.Enabled and "Включен" or "Выключен")
    end)
    if not success then
        warn("Error toggling ESP: ", err)
        StarterGui:SetCore("SendNotification", {
            Title = "ESP Error",
            Text = "Failed to toggle ESP: " .. err,
            Duration = 5
        })
    end
end)

ToggleBoxes.MouseButton1Click:Connect(function()
    local success, err = pcall(function()
        ESP.Boxes = not ESP.Boxes
        ToggleBoxes.Text = "Boxes: " .. (ESP.Boxes and "Включен" or "Выключено")
        for i, v in pairs(ESP.Objects) do
            if v.Components.Quad then
                v.Components.Quad.Visible = ESP.Enabled and ESP.Boxes
            end
        end
    end)
    if not success then
        warn("Error toggling Boxes: ", err)
        StarterGui:SetCore("SendNotification", {
            Title = "ESP Error",
            Text = "Failed to toggle Boxes: " .. err,
            Duration = 5
        })
    end
end)

local function UpdateColor()
    local success, err = pcall(function()
        local r = tonumber(ColorR.Text) or 255
        local g = tonumber(ColorG.Text) or 170
        local b = tonumber(ColorB.Text) or 0
        r = math.clamp(r, 0, 255)
        g = math.clamp(g, 0, 255)
        b = math.clamp(b, 0, 255)
        ColorR.Text = tostring(r)
        ColorG.Text = tostring(g)
        ColorB.Text = tostring(b)
        ESP.Color = Color3.fromRGB(r, g, b)
        for i, v in pairs(ESP.Objects) do
            if v.Components.Quad then
                v.Components.Quad.Color = ESP.Color
            end
        end
    end)
    if not success then
        warn("Error updating color: ", err)
        StarterGui:SetCore("SendNotification", {
            Title = "ESP Error",
            Text = "Failed to update color: " .. err,
            Duration = 5
        })
    end
end

ColorR.FocusLost:Connect(UpdateColor)
ColorG.FocusLost:Connect(UpdateColor)
ColorB.FocusLost:Connect(UpdateColor)

ThicknessBox.FocusLost:Connect(function()
    local success, err = pcall(function()
        local thickness = tonumber(ThicknessBox.Text) or ESP.Thickness
        thickness = math.clamp(thickness, 1, 10)
        ESP.Thickness = thickness
        ThicknessBox.Text = tostring(thickness)
        for i, v in pairs(ESP.Objects) do
            if v.Components.Quad then
                v.Components.Quad.Thickness = thickness
            end
        end
    end)
    if not success then
        warn("Error updating thickness: ", err)
        StarterGui:SetCore("SendNotification", {
            Title = "ESP Error",
            Text = "Failed to update thickness: " .. err,
            Duration = 5
        })
    end
end)

CloseButton.MouseButton1Click:Connect(function()
    MainFrame.Visible = false
end)

-- Toggle GUI Visibility with Keybind (Right Control)
UserInputService.InputBegan:Connect(function(input, gameProcessed)
    if gameProcessed then return end
    if input.KeyCode == Enum.KeyCode.RightControl and MainFrame.Visible then
        MainFrame.Visible = not MainFrame.Visible
    end
end)

-- Initialize ESP Folder
local charBodies
for _, folder in pairs(workspace:GetChildren()) do
    if folder:IsA("Folder") then
        local humanoidFound = false
        for _, model in pairs(folder:GetDescendants()) do
            if model:IsA("Humanoid") then
                humanoidFound = true
                break
            end
        end
        if humanoidFound then
            charBodies = folder
            break
        end
    end
end

if charBodies then 
    print("Есть папка esp: ", charBodies.Name)
else
    warn("Не удалось получить папку esp. Убедитесь, что в рабочей области существует папка с моделями .")
end

if charBodies then
    ESP:AddObjectListener(charBodies, {
        Type = "Model",
        Color = Color3.fromRGB(255, 0, 4),
        PrimaryPart = function(obj)
            return obj:FindFirstChild("HumanoidRootPart") or obj:FindFirstChildOfClass("BasePart")
        end, 
        Validator = function(obj)
            task.wait(1)
            return obj:FindFirstChildOfClass("Humanoid") ~= nil
        end, 
        IsEnabled = "player"
    })
    ESP.player = true
end

-- Initial Notification
StarterGui:SetCore("SendNotification", {
    Title = "Система активации продукта",
    Text = "Введите ключ, чтобы разблокировать графический интерфейс ESP.",
    Duration = 5
})
