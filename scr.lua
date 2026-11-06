-- Neverlose Roblox UI v30: compact function rows and corrected right-column bounds
-- Preserves register-limit/search fixes and restores full-size control rows.
-- Neverlose uses Inter; BuilderSans is the closest built-in Roblox family.
-- Older clients without BuilderSans fall back to the previous SourceSans.
local FONT = Enum.Font.SourceSansSemibold
local FONT_BOLD = Enum.Font.SourceSansBold
pcall(function()
	-- Medium matches Neverlose's Inter weight better than Regular.
	FONT = Enum.Font.BuilderSansMedium
	FONT_BOLD = Enum.Font.BuilderSansBold
end)
local LoadAcrylic = function()
	local GuiSystem = {};
	local acrylicId = 0

	local Twen = game:GetService('TweenService');
	local RunService = game:GetService('RunService');

	function GuiSystem:Hash()
		acrylicId = acrylicId + 1
		return "NeverloseAcrylic_" .. tostring(acrylicId)
	end

	local function Hiter(planePos, planeNormal, rayOrigin, rayDirection)
		local n = planeNormal
		local d = rayDirection
		local v = rayOrigin - planePos

		local num = (n.x*v.x) + (n.y*v.y) + (n.z*v.z)
		local den = (n.x*d.x) + (n.y*d.y) + (n.z*d.z)
		if math.abs(den) < 0.000001 then
			return nil
		end
		local a = -num / den
		if a ~= a or math.abs(a) > 1e6 then
			return nil
		end

		return rayOrigin + (a * rayDirection), a
	end;

	local sharedDepthOfField = nil
	local function GetSharedDepthOfField()
		if sharedDepthOfField and sharedDepthOfField.Parent then return sharedDepthOfField end
		local ok, effect = pcall(function()
			return Instance.new('DepthOfFieldEffect', game:GetService('Lighting'))
		end)
		if ok and effect then
			effect.Enabled = true
			-- Acrylic trick: blur only the near range, where the Glass part sits in
			-- front of the camera; the world from ~1.6 studs on stays sharp. The old
			-- 500-stud focus radius kept everything in focus, so nothing blurred.
			effect.FarIntensity = 0
			effect.FocusDistance = 51.6
			effect.InFocusRadius = 50
			effect.NearIntensity = 1
			effect.Name = "NeverloseDepthOfField"
			sharedDepthOfField = effect
		end
		return sharedDepthOfField
	end

	function GuiSystem.new(frame,NoAutoBackground)
		local Part = Instance.new('Part',workspace);
		local DepthOfField = GetSharedDepthOfField()
		local SurfaceGui = Instance.new('SurfaceGui',Part);
		local BlockMesh = Instance.new("BlockMesh");

		BlockMesh.Parent = Part;

		Part.Material = Enum.Material.Glass;
		Part.Transparency = 1;
		Part.Reflectance = 0.1
		Part.CastShadow = false
		Part.Anchored = true
		Part.CanCollide = false
		Part.CanQuery = false
		pcall(function()
			local PhysicsService = game:GetService('PhysicsService')
			if PhysicsService:IsCollisionGroupRegistered('NeverloseGui') then
				Part.CollisionGroup = 'NeverloseGui'
			else
				PhysicsService:RegisterCollisionGroup('NeverloseGui')
				Part.CollisionGroup = 'NeverloseGui'
			end
		end)
		Part.Size = Vector3.new(1, 1, 1) * 0.01;
		Part.Color = Color3.fromRGB(0,0,0);

		if DepthOfField then
			DepthOfField.Enabled = true
			DepthOfField.FarIntensity = 0
			DepthOfField.FocusDistance = 51.6
			DepthOfField.InFocusRadius = 50
			DepthOfField.NearIntensity = 1
		end

		SurfaceGui.AlwaysOnTop = true;
		SurfaceGui.Adornee = Part;
		SurfaceGui.Active = true;
		SurfaceGui.Face = Enum.NormalId.Front;
		SurfaceGui.ZIndexBehavior = Enum.ZIndexBehavior.Global;

		if DepthOfField and not sharedDepthOfField then DepthOfField.Name = GuiSystem:Hash() end
		Part.Name = GuiSystem:Hash();
		SurfaceGui.Name = GuiSystem:Hash();

		local C4 = {
			Update = nil,
			Collection = SurfaceGui,
			Enabled = true,
			Instances = {
				BlockMesh = BlockMesh,
				Part = Part,
				DepthOfField = DepthOfField,
				SurfaceGui = SurfaceGui,
			},
			Signal = nil
		};

		local lastQuality = nil
		local lastTransparency = nil

		local function resolveQualityTransparency()
			local qualityLevel, target = nil, nil
			pcall(function()
				local userSettings = UserSettings():GetService("UserGameSettings")
				qualityLevel = userSettings.SavedQualityLevel.Value
				-- 0 is "Automatic", which usually renders at high quality; it used to
				-- count as low and switched the blur off for most players.
				target = (qualityLevel == 0 or qualityLevel >= 8) and 0.8 or 1
			end)
			if type(qualityLevel) ~= "number" or type(target) ~= "number" then return nil end
			return qualityLevel, target
		end

		local initialQuality, initialTarget = resolveQualityTransparency()
		lastQuality = initialQuality
		lastTransparency = initialTarget
		Part.Transparency = initialTarget or 0.8
		Part:SetAttribute("TargetTransparency", Part.Transparency)

		local function syncQualityTransparency()
			local qualityLevel, target = resolveQualityTransparency()
			if not qualityLevel then return end
			if lastQuality == qualityLevel and lastTransparency and math.abs(lastTransparency - target) < 0.001 then return end
			lastQuality = qualityLevel
			lastTransparency = target
			pcall(function() Part:SetAttribute("TargetTransparency", target) end)
			local ok, tween = pcall(function()
				return Twen:Create(Part,TweenInfo.new(1,Enum.EasingStyle.Quint,Enum.EasingDirection.Out),{Transparency = target})
			end)
			if ok and tween then pcall(function() tween:Play() end) end
		end

		local Update = function()
			local camera = workspace.CurrentCamera
			if not frame.Parent or not camera or not camera.Parent or frame.AbsoluteSize.X <= 0 or frame.AbsoluteSize.Y <= 0 then return end
			syncQualityTransparency()

			local ok, result0, result1 = pcall(function()
				local corner0 = frame.AbsolutePosition
				local corner1 = corner0 + frame.AbsoluteSize
				local ray0 = camera:ScreenPointToRay(corner0.X, corner0.Y, 1)
				local ray1 = camera:ScreenPointToRay(corner1.X, corner1.Y, 1)
				local planeOrigin = camera.CFrame.Position + camera.CFrame.LookVector * (0.05 - camera.NearPlaneZ)
				local planeNormal = camera.CFrame.LookVector
				local pos0 = Hiter(planeOrigin, planeNormal, ray0.Origin, ray0.Direction)
				local pos1 = Hiter(planeOrigin, planeNormal, ray1.Origin, ray1.Direction)
				if not pos0 or not pos1 then return nil end
				local a = camera.CFrame:PointToObjectSpace(pos0)
				local b = camera.CFrame:PointToObjectSpace(pos1)
				if a.X ~= a.X or a.Y ~= a.Y or a.Z ~= a.Z then return nil end
				if b.X ~= b.X or b.Y ~= b.Y or b.Z ~= b.Z then return nil end
				return a, b
			end)
			if not ok or not result0 or not result1 then return end
			local size = result1 - result0
			local center = (result0 + result1) / 2
			local scaleX = math.clamp(math.abs(size.X) / 0.0101, 0.01, 4000)
			local scaleY = math.clamp(math.abs(size.Y) / 0.0101, 0.01, 4000)
			local scaleZ = math.clamp(math.abs(size.Z) / 0.0101, 0.01, 4000)
			BlockMesh.Offset = center
			BlockMesh.Scale = Vector3.new(scaleX, scaleY, scaleZ)
			Part.CFrame = camera.CFrame
		end

		C4.Update = Update;

		pcall(function()
			C4.Signal2 = workspace:GetPropertyChangedSignal("CurrentCamera"):Connect(function()
				local camera = workspace.CurrentCamera
				if camera and camera.Parent then Part.CFrame = camera.CFrame end
			end)
		end)

		C4.Destroy = function()
			if C4.Signal then C4.Signal:Disconnect() end
			if C4.Signal2 then C4.Signal2:Disconnect() end
			C4.Signal = nil
			C4.Signal2 = nil
			C4.Update = function() end

			pcall(function()
				Twen:Create(Part,TweenInfo.new(1),{
					Transparency = 1
				}):Play()
			end)

			Part:Destroy()
		end;

		return C4;
	end;

	return GuiSystem;
end;

local TweenService = game:GetService("TweenService")
local UserInputService = game:GetService("UserInputService")
local Players = game:GetService("Players")
local LocalPlayer = Players.LocalPlayer or Players:GetPlayers()[1] or {Name = "Player", DisplayName = "Player", UserId = 0}
local RunService = game:GetService('RunService')

local _windowConfigCounter = 0

local function IsPrimaryInput(input)
	return input and (input.UserInputType == Enum.UserInputType.MouseButton1 or input.UserInputType == Enum.UserInputType.Touch)
end

local function GetPointerPosition()
	local ok, position = pcall(function() return UserInputService:GetMouseLocation() end)
	if ok and position then return position end
	return Vector2.new(0, 0)
end

local function GetInputPosition(input)
	if input and input.Position then return input.Position end
	return GetPointerPosition()
end

local function InvokeCallback(callback, ...)
	if type(callback) == "function" then pcall(callback, ...) end
end

local function IsAncestorVisible(object)
	local current = object and object.Parent
	while current do
		local ok, visible = pcall(function() return current.Visible end)
		if ok and visible == false then return false end
		current = current.Parent
	end
	return true
end

local function IsPointInside(object, point)
	if not object or not point then return false end
	local ok, isGui = pcall(function() return object:IsA("GuiObject") end)
	if not ok or not isGui or not object.Visible then return false end
	if not IsAncestorVisible(object) then return false end
	local size = object.AbsoluteSize
	if size.X <= 0 or size.Y <= 0 then return false end
	local position = object.AbsolutePosition
	return point.X >= position.X and point.X <= position.X + size.X
		and point.Y >= position.Y and point.Y <= position.Y + size.Y
end

local function IsPointInsideTree(object, point)
	if IsPointInside(object, point) then return true end
	if not object or not object.Parent then return false end
	local ok, descendants = pcall(function() return object:GetDescendants() end)
	if not ok then return false end
	for _, descendant in ipairs(descendants) do
		if IsPointInside(descendant, point) then return true end
	end
	return false
end

local function ClampRatio(value, maximum)
	if maximum == nil or maximum <= 0 then return 0 end
	return math.clamp(value / maximum, 0, 1)
end

local function NormalizeOptions(options)
	local result = {}
	if type(options) == "table" then
		for _, value in ipairs(options) do
			if value ~= nil then table.insert(result, tostring(value)) end
		end
	end
	if #result == 0 then table.insert(result, "Auto") end
	return result
end

local function NormalizeColor(value)
	if typeof(value) == "Color3" then
		return Color3.new(math.clamp(value.R, 0, 1), math.clamp(value.G, 0, 1), math.clamp(value.B, 0, 1))
	end
	return Color3.fromRGB(255, 255, 255)
end

local function ColorToHex(value)
	local c = NormalizeColor(value)
	return string.format("#%02X%02X%02X", math.clamp(math.round(c.R * 255), 0, 255), math.clamp(math.round(c.G * 255), 0, 255), math.clamp(math.round(c.B * 255), 0, 255))
end

local function NormalizeRange(min, max, default)
	min = type(min) == "number" and min or 0
	max = type(max) == "number" and max or 100
	if min ~= min then min = 0 end
	if max ~= max then max = 100 end
	if max <= min then max = min + 1 end
	local value = type(default) == "number" and default or min
	if value ~= value then value = min end
	return min, max, math.clamp(value, min, max)
end

local function GetValidOption(options, value)
	for _, option in ipairs(options) do
		if option == value then return value end
	end
	return options[1]
end

local function AddTextConstraint(object, minimum, maximum, force)
	if not object or not object:IsA("GuiObject") then return end
	if not (object:IsA("TextLabel") or object:IsA("TextButton") or object:IsA("TextBox")) then return end
	if not object.TextScaled then return end
	local constraint = object:FindFirstChild("ReadableTextConstraint")
	if constraint and not force then return end
	if not constraint then
		constraint = Instance.new("UITextSizeConstraint")
		constraint.Name = "ReadableTextConstraint"
		constraint.Parent = object
	end
	constraint.MinTextSize = minimum or 9
	constraint.MaxTextSize = maximum or 16
end

local function MakeReadableText(root, minimum, maximum)
	if not root then return end
	AddTextConstraint(root, minimum, maximum)
	for _, object in ipairs(root:GetDescendants()) do
		AddTextConstraint(object, minimum, maximum)
	end
end

local function SerializeValue(v)
	local t = type(v)
	if t == "boolean" or t == "number" or t == "string" then
		return v
	elseif typeof(v) == "Color3" then
		return { __type = "Color3", r = v.R, g = v.G, b = v.B }
	elseif t == "table" then
		-- Multi-select dropdowns: a plain list of strings/numbers/booleans.
		local items = {}
		for _, item in ipairs(v) do
			local it = type(item)
			if it == "string" or it == "number" or it == "boolean" then table.insert(items, item) end
		end
		return { __type = "List", v = items }
	end
	return nil
end

local function DeserializeValue(v)
	if type(v) == "table" and v.__type == "Color3" then
		local ok, color = pcall(Color3.new, tonumber(v.r) or 1, tonumber(v.g) or 1, tonumber(v.b) or 1)
		if ok then return color end
	elseif type(v) == "table" and v.__type == "List" then
		return type(v.v) == "table" and v.v or {}
	end
	return v
end

local function GetImageData(name, image)
	if not image then return end
	name = type(name) == "string" and name:lower() or "ads"
	local NigImage = "rbxassetid://3926305904"
	if name == "ads" then
		image.Image = NigImage; image.ImageRectOffset = Vector2.new(205,565); image.ImageRectSize = Vector2.new(35,35)
	elseif name == "list" then
		image.Image = NigImage; image.ImageRectOffset = Vector2.new(485,205); image.ImageRectSize = Vector2.new(35,35)
	elseif name == "folder" then
		image.Image = NigImage; image.ImageRectOffset = Vector2.new(805,45); image.ImageRectSize = Vector2.new(35,35)
	elseif name == "earth" then
		image.Image = NigImage; image.ImageRectOffset = Vector2.new(604,324); image.ImageRectSize = Vector2.new(35,35)
	elseif name == "locked" then
		image.Image = NigImage; image.ImageRectOffset = Vector2.new(524,644); image.ImageRectSize = Vector2.new(35,35)
	elseif name == "home" then
		image.Image = NigImage; image.ImageRectOffset = Vector2.new(964,205); image.ImageRectSize = Vector2.new(35,35)
	elseif name == "mouse" then image.Image = "rbxassetid://94866180901611"
	elseif name == "user" then image.Image = "rbxassetid://10494577250"
	elseif name == "cosmetics" then image.Image = "rbxassetid://111448140849101"
	elseif name == "sun" then image.Image = "rbxassetid://119948798441279"
	elseif name == "shop" then image.Image = "rbxassetid://97513888174732"
	elseif name == "farm" then image.Image = "rbxassetid://88262334591015"
	elseif name == "code" then image.Image = "rbxassetid://137998322875646"
	elseif name == "crosshair" then image.Image = "rbxassetid://107944169329467"
   elseif name == "image" then image.Image = "rbxassetid://111273759419615"
elseif name == "layers" then image.Image = "rbxassetid://99581501168713"
	elseif name == "side" then image.Image = "rbxassetid://109111534633587"
	elseif name == "grenade" then image.Image = "rbxassetid://106253651509472"
	elseif name == "bio" then image.Image = "rbxassetid://78652086695674"
	elseif name == "camera" then image.Image = "rbxassetid://103880096339912"
	elseif name == "car" then image.Image = "rbxassetid://116283987324457"
	elseif name == "run" then image.Image = "rbxassetid://117007794770586"
	elseif name == "box" then image.Image = "rbxassetid://140255234172865"
	elseif name == "carcolor" then image.Image = "rbxassetid://135983067514338"
	elseif name == "avacolor" then image.Image = "rbxassetid://88738565686900"
	elseif name == "locker" then image.Image = "rbxassetid://87534652127926"
	elseif name == "retry" then image.Image = "rbxassetid://85334730366974"
	elseif name == "gun" then image.Image = "rbxassetid://93001822915827"
	elseif name == "sword" then image.Image = "rbxassetid://82635240213192"
	elseif name == "knife" then image.Image = "rbxassetid://94102397172403"
	elseif name == "egg" then image.Image = "rbxassetid://110250017854460"
	elseif name == "sprinkler" then image.Image = "rbxassetid://139620040051222"
	elseif name == "gear" then image.Image = "rbxassetid://134488580093972"
	-- Semantic aliases keep common navigation names mapped to the same icon family.
	elseif name == "aimbot" or name == "rage" or name == "combat" then image.Image = "rbxassetid://107944169329467"
	elseif name == "legit" then image.Image = ""
	elseif name == "visuals" then image.Image = "rbxassetid://111273759419615"
	elseif name == "inventory" or name == "other" then image.Image = "rbxassetid://99581501168713"
	elseif name == "miscellaneous" or name == "settings" then image.Image = "rbxassetid://134488580093972"
	elseif name == "profile" or name == "account" then image.Image = "rbxassetid://10494577250"
	elseif name == "configs" or name == "config" then
		image.Image = NigImage; image.ImageRectOffset = Vector2.new(805,45); image.ImageRectSize = Vector2.new(35,35)
	end
end

local Library = {}
Library.__index = Library

-- Profile popover row icons. Several of the old IDs do not render in game, so
-- they live here and can be swapped before AddWindow:
--   Library.ProfileIcons.language = "rbxassetid://..."
-- Kept on Library instead of as locals: AddWindow is close to Luau's register cap.
Library.ProfileIcons = {
	language     = "rbxassetid://121978468376124",
	menuScale    = "rbxassetid://114499998778667",
	espScale     = "rbxassetid://127234874352422",
	windowsScale = "rbxassetid://114499998778667",
	units        = "rbxassetid://82464660673318",
	style        = "rbxassetid://109485777305919",
	safeMode     = "rbxassetid://127234874352422",
	sync         = "rbxassetid://104941258142372",
	about        = "rbxassetid://136533241128438",
	chat         = "rbxassetid://121978468376124",
	developer    = "rbxassetid://137998322875646",
}
-- nil = "Lifetime"; a number shows "N days left" and "Till: <date>" in the profile.
Library.DaysLeft = nil

-- Track running tweens by object/property so repeated hover and popup inputs do
-- not fight each other. Tweens for unrelated properties can still run in parallel.
local _liveTweensByObject = setmetatable({}, { __mode = "k" })
local function Tween(obj, props, t, style, dir, delay)
	if not obj or not obj.Parent or type(props) ~= "table" then return nil end
	style = style or Enum.EasingStyle.Quad
	dir = dir or Enum.EasingDirection.Out
	local bucket = _liveTweensByObject[obj]
	if not bucket then bucket = {}; _liveTweensByObject[obj] = bucket end
	local cancel = {}
	for property in pairs(props) do
		local running = bucket[property]
		if running then cancel[running] = true end
	end
	for running in pairs(cancel) do pcall(function() running:Cancel() end) end
	-- Cancelling a tween fires Completed(Cancelled), whose callback may remove the bucket.
	bucket = _liveTweensByObject[obj]
	if not bucket then bucket = {}; _liveTweensByObject[obj] = bucket end
	local ok, tween = pcall(function()
		return TweenService:Create(obj, TweenInfo.new(t or 0.2, style, dir, 0, false, delay or 0), props)
	end)
	if not ok or not tween then return nil end
	for property in pairs(props) do bucket[property] = tween end
	tween.Completed:Connect(function()
		local current = _liveTweensByObject[obj]
		if not current then return end
		for property in pairs(props) do
			if current[property] == tween then current[property] = nil end
		end
		if next(current) == nil then _liveTweensByObject[obj] = nil end
	end)
	tween:Play()
	return tween
end

local CenterElement
local SizeSliderChip

local STROKE = { Color = Color3.fromRGB(255, 255, 255), Transparency = 0.92, Thickness = 1 }
local strokeScale = 1
local function ApplyStrokeScale(stroke, scale)
	if not stroke or not stroke:IsA("UIStroke") then return end
	stroke.Thickness = STROKE.Thickness
end
local function Stroke(parent, name)
	local stroke = Instance.new("UIStroke")
	stroke.Name = name or "Stroke"
	stroke.Color = STROKE.Color
	stroke.Transparency = STROKE.Transparency
	stroke.Thickness = STROKE.Thickness
	stroke.ApplyStrokeMode = Enum.ApplyStrokeMode.Border
	if parent then stroke.Parent = parent end
	ApplyStrokeScale(stroke, strokeScale)
	return stroke
end
local function RescaleStrokes(root, scale)
	strokeScale = scale
	if not root then return end
	ApplyStrokeScale(root, scale)
	for _, d in ipairs(root:GetDescendants()) do ApplyStrokeScale(d, scale) end
end

local function New(class, props, parent)
	local obj = Instance.new(class)
	if obj:IsA("GuiObject") and obj.BorderSizePixel == 1 then obj.BorderSizePixel = 0 end
	for k, v in pairs(props or {}) do
		pcall(function() obj[k] = v end)
	end
	if obj:IsA("TextLabel") or obj:IsA("TextButton") or obj:IsA("TextBox") then
		obj.TextYAlignment = Enum.TextYAlignment.Center
		obj.TextScaled = false
		-- Sized for BuilderSans/Inter metrics (SourceSans needed ~2px more for the same look).
		-- One step up from the first BuilderSans pass: Neverlose text reads larger.
		local roleSizes = { Title = 17, GameTitle = 12, TabLabel = 12, TabText = 16, STLabel = 15, SectionLabel = 12,
			TextToggle = 15, TextDropdown = 15, TextDefault = 14, TopBar = 15, SliderValue = 13,
			Username = 15, Daysleft = 12, SaveText = 15, HeaderLabel = 12, SearchBox = 15 }
		obj.TextSize = roleSizes[obj.Name] or ((props and props.TextSize) or 13)
		obj.Font = (obj.Name == "Title" or obj.Name == "HeaderTitle" or obj.Name == "BadgeText" or obj.Name == "LoaderTitle") and FONT_BOLD or FONT
		if obj.Name == "SectionLabel" or obj.Name == "TabLabel" then
			obj.TextColor3 = Color3.fromRGB(92, 96, 106)
		elseif obj.Name == "GameTitle" or obj.Name == "Daysleft" or obj.Name == "HeaderLabel" or obj.Name == "SearchEmptyState" then
			obj.TextColor3 = Color3.fromRGB(112, 116, 138)
		elseif obj.Name == "TextToggle" or obj.Name == "TextDropdown" or obj.Name == "TextDefault" or obj.Name == "TopBar" or obj.Name == "SaveText" then
			obj.TextColor3 = Color3.fromRGB(226, 228, 236)
		end
		if obj.Name == "TextToggle" or obj.Name == "TextDropdown" or obj.Name == "TextDefault" or obj.Name == "TopBar" or obj.Name == "TabText" or obj.Name == "SaveText" then
			obj.TextTruncate = Enum.TextTruncate.AtEnd
		end
	end
	if parent then obj.Parent = parent end
	-- Neverlose control styling, applied by role so section, plate and accordion
	-- copies of a control all match: grey regular labels, value fields on a dark
	-- fill with a hairline border, muted "..." dots.
	if obj.Name == "TextToggle" and obj:IsA("TextLabel") then
		obj.TextColor3 = Color3.fromRGB(235, 236, 241)
	elseif obj.Name == "TopBarText" and obj:IsA("TextLabel") then
		obj.TextColor3 = Color3.fromRGB(205, 208, 218)
	elseif (obj.Name == "TopBar" or obj.Name == "SliderValue") and obj:IsA("GuiObject") then
		local isValue = obj.Name == "SliderValue"
		-- Slider readouts stay quiet in Neverlose: dimmer text and outline.
		obj.BackgroundColor3 = isValue and Color3.fromRGB(22, 22, 31) or Color3.fromRGB(26, 26, 36)
		obj.BackgroundTransparency = 0
		if obj:IsA("TextLabel") then
			obj.TextColor3 = isValue and Color3.fromRGB(176, 178, 188) or Color3.fromRGB(205, 208, 218)
			obj.TextTransparency = 0
		end
		local fieldStroke = Instance.new("UIStroke")
		fieldStroke.Name = "FieldOutline"
		fieldStroke.Color = Color3.fromRGB(255, 255, 255)
		fieldStroke.Transparency = isValue and 0.96 or 0.93
		fieldStroke.Thickness = 1
		fieldStroke.ApplyStrokeMode = Enum.ApplyStrokeMode.Border
		fieldStroke.Parent = obj
	elseif obj.Name == "TextDefault" and obj:IsA("TextLabel") and obj.Parent and obj.Parent.Name == "Selection" then
		-- Plate selects read "Label .... Value >" like Neverlose ("Scaling  Horizontal >").
		obj.AnchorPoint = Vector2.new(1, 0.5)
		obj.Position = UDim2.new(1, -24, 0.5, 0)
		obj.Size = UDim2.new(0.5, 0, 1, 0)
		obj.TextXAlignment = Enum.TextXAlignment.Right
		obj.TextColor3 = Color3.fromRGB(200, 203, 213)
	elseif obj.Name == "TextArrow" and obj:IsA("ImageLabel") and obj.Parent and obj.Parent.Name == "Selection" then
		obj.Position = UDim2.new(1, -8, 0.5, 0)
		obj.Rotation = -90
		obj.ImageTransparency = 0.3
	elseif obj.Name == "Arrow" and obj:IsA("ImageLabel") then
		-- Neverlose chevron: a touch larger and brighter, and it does not flip.
		obj.Size = UDim2.fromOffset(12, 12)
		obj.ImageTransparency = 0.15
	elseif obj.Name == "Line" and obj:IsA("Frame") then
		obj.BackgroundColor3 = Color3.fromRGB(40, 42, 54)
	elseif type(obj.Name) == "string" and obj.Name:match("^Dot%d$") and obj:IsA("Frame") then
		obj.BackgroundColor3 = Color3.fromRGB(150, 154, 166)
		-- Neverlose's "..." are round dots, not squares.
		local dotCorner = Instance.new("UICorner")
		dotCorner.CornerRadius = UDim.new(1, 0)
		dotCorner.Parent = obj
	end
	if obj:IsA("UIStroke") then
		obj.Color = STROKE.Color
		obj.Transparency = STROKE.Transparency
		obj.Thickness = STROKE.Thickness
		obj.ApplyStrokeMode = Enum.ApplyStrokeMode.Border
		ApplyStrokeScale(obj, strokeScale)
	end
	AddTextConstraint(obj, 7, 16)
	return obj
end

-- Rounded hover styling for function rows.
local function AttachRowHover(row)
	if not row or not row:IsA("GuiObject") or row:GetAttribute("NLRowHoverAttached") then return end
	local ok, baseTransparency = pcall(function() return row.BackgroundTransparency end)
	if not ok or type(baseTransparency) ~= "number" or baseTransparency < 0.98 then return end
	local baseColor = row.BackgroundColor3
	row:SetAttribute("NLRowHoverAttached", true)
	if not row:FindFirstChildOfClass("UICorner") then
		New("UICorner", { CornerRadius = UDim.new(0, 6) }, row)
	end
	row.MouseEnter:Connect(function()
		if not row.Parent then return end
		-- All hover tints share 0.97: Neverlose hover is a barely-there lift.
		Tween(row, { BackgroundColor3 = Color3.fromRGB(245, 247, 255), BackgroundTransparency = 0.97 }, 0.11, Enum.EasingStyle.Sine, Enum.EasingDirection.Out)
	end)
	row.MouseLeave:Connect(function()
		if not row.Parent then return end
		Tween(row, { BackgroundColor3 = baseColor, BackgroundTransparency = baseTransparency }, 0.14, Enum.EasingStyle.Sine, Enum.EasingDirection.Out)
	end)
end

local function CleanBorders(root)
	if not root then return end
	for _, d in ipairs(root:GetDescendants()) do
		if d:IsA("GuiObject") and d.BorderSizePixel ~= 0 then
			d.BorderSizePixel = 0
		end
	end
end

CenterElement = function(el)
	if not el or not el:IsA("GuiObject") then return end
	local function place(child, center, h)
		if not child or not child:IsA("GuiObject") then return end
		local top = center - h * (0.5 - child.AnchorPoint.Y)
		child.Position = UDim2.new(child.Position.X.Scale, child.Position.X.Offset, top, 0)
		child.Size = UDim2.new(child.Size.X.Scale, child.Size.X.Offset, h, 0)
	end
	local function placeText(child, center, h)
		if not child or not (child:IsA("TextLabel") or child:IsA("TextButton")) then return end
		child.TextYAlignment = Enum.TextYAlignment.Center
		-- Right-aligned values (plate selects) keep their alignment.
		if child.TextXAlignment ~= Enum.TextXAlignment.Right then child.TextXAlignment = Enum.TextXAlignment.Left end
		place(child, center, h)
	end
	for _, name in ipairs({ "TextToggle", "TextDefault", "TextAccordion", "TextDropdown", "TextAccordionLabel" }) do
		placeText(el:FindFirstChild(name), 0.5, 0.5)
	end
	local toggleLabel = el:FindFirstChild("TextToggle")
	if toggleLabel and toggleLabel:IsA("GuiObject") then
		toggleLabel.Size = UDim2.new(0.58, toggleLabel.Size.X.Offset, toggleLabel.Size.Y.Scale, toggleLabel.Size.Y.Offset)
	end
	local effect = el:FindFirstChild("Effect")
	local sliderEffect = effect and effect:IsA("GuiObject") and effect:FindFirstChild("Line") and effect:FindFirstChild("SliderValue")
	if effect and effect:IsA("GuiObject") then
		if effect:FindFirstChild("Icon") then
			effect.AnchorPoint = Vector2.new(1, 0.5)
			effect.Position = UDim2.new(1, -14, 0.5, 0)
			effect.Size = UDim2.fromOffset(33, 20)
		elseif sliderEffect then
			if SizeSliderChip then SizeSliderChip(effect, effect:FindFirstChild("Line"), effect:FindFirstChild("SliderValue")) end
		else
			place(effect, 0.5, 0.7)
		end
	end
	if not sliderEffect then
		place(el:FindFirstChild("Line"), 0.5, 0.24)
		place(el:FindFirstChild("SliderValue"), 0.5, 0.8)
	end
	local cp = el:FindFirstChild("colorpickerButton")
	if cp and cp:IsA("GuiObject") then
		local cpOffset = -14
		if el:FindFirstChild("TopBar") then
			cpOffset = -155
		elseif effect and effect:FindFirstChild("Icon") then
			cpOffset = -55 -- 8px left of the switch
		end
		cp.AnchorPoint = Vector2.new(1, 0.5)
		cp.Position = UDim2.new(1, cpOffset, 0.5, 0)
		cp.Size = UDim2.fromOffset(16, 16)
	end
	local rowLabel = el:FindFirstChild("TextToggle") or el:FindFirstChild("TextDropdown")
	if rowLabel and rowLabel:IsA("GuiObject") then
		local width = 0.55
		if el.Name == "Dropdown" or sliderEffect then width = 0.42 end
		if el:FindFirstChild("ColorpickerOpenButton") then width = 0.36 end
		if effect and effect:FindFirstChild("Icon") and cp then width = 0.36 end
		rowLabel.Size = UDim2.new(width, 0, 0.5, 0)
		rowLabel.TextTruncate = Enum.TextTruncate.AtEnd
	end
	place(el:FindFirstChild("DropdownArrow") or el:FindFirstChild("TextboxArrow"), 0.5, 0.5)
end

local ELLIPSIS = "..."
local TextService = game:GetService("TextService")
local MEASURE_SIZE = Vector2.new(10000, 10000)

local function MeasureText(text, fontSize, font)
	local ok, size = pcall(TextService.GetTextSize, TextService, text, fontSize or 14, font or FONT, MEASURE_SIZE)
	if ok and size then return size.X end
	return 0
end

SizeSliderChip = function(effect, line, value)
	if not effect or not line or not value or not effect.Parent then return end
	local textWidth = MeasureText(tostring(value.Text or ""), 14, FONT)
	local chipWidth = math.max(30, math.ceil(textWidth) + 10)
	value.AnchorPoint = Vector2.new(1, 0.5)
	value.Position = UDim2.new(1, 0, 0.5, 0)
	value.Size = UDim2.fromOffset(chipWidth, 22)
	-- Quiet readout, as in Neverlose (matches the New() SliderValue role).
	value.BackgroundColor3 = Color3.fromRGB(22, 22, 31)
	value.TextScaled = false
	value.TextSize = 13
	value.Font = FONT
	value.TextColor3 = Color3.fromRGB(176, 178, 188)
	value.TextTransparency = 0
	value.TextXAlignment = Enum.TextXAlignment.Center
	effect.AnchorPoint = Vector2.new(0, 0.5)
	-- Plates are narrow: start the slider earlier there so the track stays long.
	local inPlate = effect:FindFirstAncestor("SettingsFrame") or effect:FindFirstAncestor("AccordionFrame")
	if inPlate then
		effect.Position = UDim2.new(0, 104, 0.5, 0)
		effect.Size = UDim2.new(1, -116, 0, 22)
	else
		effect.Position = UDim2.new(0, 150, 0.5, 0)
		effect.Size = UDim2.new(1, -164, 0, 22)
	end
	line.AnchorPoint = Vector2.new(0, 0.5)
	line.Position = UDim2.new(0, 0, 0.5, 0)
	line.Size = UDim2.new(1, -(chipWidth + 10), 0, 3)
	line.BackgroundColor3 = Color3.fromRGB(45, 48, 64)
	line.BorderSizePixel = 0
	if not value:GetAttribute("NLSliderChipWatch") then
		value:SetAttribute("NLSliderChipWatch", true)
		value:GetPropertyChangedSignal("Text"):Connect(function()
			if value.Parent and effect.Parent then task.defer(function()
				if value.Parent and effect.Parent then SizeSliderChip(effect, line, value) end
			end) end
		end)
	end
end

local function BindKeyName(key)
	if not key then return "—" end
	local n
	if type(key) == "string" then
		n = key
	else
		local ok, keyName = pcall(function() return key.Name end)
		if ok then n = keyName end
	end
	if type(n) ~= "string" then return tostring(key) end
	if n == "MouseButton3" then return "Mouse 3" end
	if n == "MouseButton4" then return "Mouse 4" end
	if n == "MouseButton5" then return "Mouse 5" end
	if n == "MouseWheelUp" then return "Wheel Up" end
	if n == "MouseWheelDown" then return "Wheel Down" end
	return n
end

local function EllipsizeTo(label, maxWidth)
	if not label or not label:IsA("TextLabel") and not label:IsA("TextButton") then return end
	if type(maxWidth) ~= "number" or maxWidth <= 0 then return end
	local full = label:GetAttribute("FullText")
	if type(full) ~= "string" or full == "" then
		full = label.Text
		label:SetAttribute("FullText", full)
	end
	if full == "" then return end
	local fontSize = label.TextSize or 14
	local font = label.Font or FONT
	local unscaled = MeasureText(full, fontSize, font)
	if unscaled <= 0 then return end
	local scale = 1
	if label.TextScaled and label.TextBounds.X > 0 then
		scale = label.TextBounds.X / unscaled
		if scale <= 0 or scale ~= scale then scale = 1 end
	end
	local function rendered(text)
		return MeasureText(text, fontSize, font) * scale
	end
	if rendered(full) <= maxWidth then
		if label.Text ~= full then label.Text = full end
		return
	end
	local low, high, best = 1, #full, ""
	while low <= high do
		local mid = math.floor((low + high) / 2)
		local candidate = full:sub(1, mid) .. ELLIPSIS
		if rendered(candidate) <= maxWidth then
			best = candidate
			low = mid + 1
		else
			high = mid - 1
		end
	end
	label.Text = best ~= "" and best or ELLIPSIS
end



local Z_BASE = 10000

-- ============================================================================
-- PATCH 1: THEME tokens (from [G].txt §1)
-- ============================================================================
local THEME = {
	plate = Color3.fromRGB(20, 23, 34),
	row = Color3.fromRGB(28, 31, 45),
	stroke = Color3.fromRGB(255, 255, 255),
	strokeAlpha = 0.92,
	text = Color3.fromRGB(226, 228, 236),
	dim = Color3.fromRGB(112, 116, 138),
	danger = Color3.fromRGB(233, 90, 110),
	radius = 12,
}

local _popupZStep = 0

local function TweenShadowLayers(frame, show, dur, dir)
	for _, node in ipairs(frame:GetDescendants()) do
		if node:GetAttribute("IsShadowLayer") then
			local alpha = node:GetAttribute("ShadowAlpha") or 0.8
			Tween(node, { BackgroundTransparency = show and alpha or 1 }, dur or 0.2, Enum.EasingStyle.Quad, dir or Enum.EasingDirection.Out)
		end
	end
end

local Z_RUNG = 100
local function NextPopupZ()
	_popupZStep = _popupZStep + 1
	if _popupZStep > 40 then _popupZStep = 1 end
	return Z_BASE + _popupZStep * Z_RUNG
end

local function ApplyZIndexLadder(root, base)
	if not root or not root:IsA("GuiObject") then return end
	local queue = { { instance = root, depth = 0 } }
	local index = 0
	while index < #queue do
		local entry = queue[index + 1]
		index = index + 1
		local instance = entry.instance
		local depth = entry.depth
		if instance:IsA("GuiObject") then
			instance.ZIndex = base + depth
			if instance:GetAttribute("IsShadowLayer") then
				instance.ZIndex = base + depth - 2
			elseif instance.Name == "InputSink" then
				-- Same level as its popup, under the rows: on a reopen the sink
				-- shared the rows' level and, added last, swallowed their clicks.
				instance.ZIndex = base + depth - 1
			end
		end
		for _, child in ipairs(instance:GetChildren()) do
			table.insert(queue, { instance = child, depth = depth + 1 })
		end
	end
end

local function GetDragShield(frame)
	if not frame then return nil end
	local shield = frame:FindFirstChild("DragShield")
	if not shield then
		shield = New("TextButton", {
			Name = "DragShield",
			Size = UDim2.new(1, 0, 1, 0),
			BackgroundTransparency = 1,
			BorderSizePixel = 0,
			Text = "",
			AutoButtonColor = false,
			Active = true,
			Visible = false,
			ZIndex = 4990,
		}, frame)
	end
	return shield
end

-- Popups are mostly plain Frames, which let clicks fall through to whatever row
-- sits underneath (picking a profile setting toggled the function behind it).
-- An invisible button under the popup's content swallows those clicks.
local function AddInputSink(frame)
	if not frame or not frame:IsA("GuiObject") or frame:IsA("ScrollingFrame") then return end
	if frame:FindFirstChild("InputSink") then return end
	-- A layout would treat the sink as one more row; an Active frame sinks the
	-- clicks itself instead (color picker, laid-out lists).
	if frame:FindFirstChildOfClass("UIListLayout") or frame:FindFirstChildOfClass("UIGridLayout") then
		frame.Active = true
		return
	end
	New("TextButton", {
		Name = "InputSink",
		Size = UDim2.fromScale(1, 1),
		BackgroundTransparency = 1,
		BorderSizePixel = 0,
		Text = "",
		AutoButtonColor = false,
		Active = true,
		ZIndex = frame.ZIndex,
	}, frame)
end

-- Plate groups: Neverlose splits a settings plate into several cards (one per
-- feature, e.g. "Override FOV" + "Value"). The plate container starts as a single
-- card; the first group call turns it into a transparent stack of cards, moving
-- the rows added so far into the first card. Returns the card new rows go into.
local function StartPlateGroup(container)
	if not container:GetAttribute("NLGrouped") then
		container:SetAttribute("NLGrouped", true)
		container.BackgroundTransparency = 1
		local outline = container:FindFirstChild("CardOutline")
		if outline then outline.Enabled = false end
		local layout = container:FindFirstChildOfClass("UIListLayout")
		if layout then layout.Padding = UDim.new(0, 8) end
		local rows = {}
		for _, child in ipairs(container:GetChildren()) do
			if child:IsA("GuiObject") then table.insert(rows, child) end
		end
		if #rows > 0 then
			local first = StartPlateGroup(container)
			for _, row in ipairs(rows) do row.Parent = first end
		end
	end
	local order = (container:GetAttribute("NLGroupCount") or 0) + 1
	container:SetAttribute("NLGroupCount", order)
	local card = New("Frame", {
		Name = "PlateGroup" .. order,
		Size = UDim2.new(1, 0, 0, 0),
		AutomaticSize = Enum.AutomaticSize.Y,
		BackgroundColor3 = Color3.fromRGB(27, 27, 36),
		BackgroundTransparency = 1,
		BorderSizePixel = 0,
		LayoutOrder = order * 1000,
		ZIndex = container.ZIndex,
	}, container)
	New("UICorner", { CornerRadius = UDim.new(0, 10) }, card)
	Stroke(card, "CardOutline").Transparency = 0.955
	New("UIListLayout", { Padding = UDim.new(0, 0), SortOrder = Enum.SortOrder.LayoutOrder }, card)
	New("UIPadding", { PaddingTop = UDim.new(0, 4), PaddingBottom = UDim.new(0, 4), PaddingLeft = UDim.new(0, 6), PaddingRight = UDim.new(0, 6) }, card)
	return card
end

local function MeasureRowsHeight(container)
	local count = 0
	local total = 0
	for _, child in ipairs(container:GetChildren()) do
		if child:IsA("GuiObject") then
			local okSize, sizeValue = pcall(function() return child.AbsoluteSize end)
			if okSize and sizeValue and sizeValue.Y > 0 then total = total + sizeValue.Y end
			count = count + 1
		end
	end
	if count == 0 then return 0, 0 end
	local padding = 0
	local okLayout, layout = pcall(function() return container:FindFirstChildOfClass("UIListLayout") end)
	if okLayout and layout then padding = layout.Padding.Offset or 0 end
	return total + padding * (count - 1), count
end

local function EstimateRowsHeight(container, count, aspect)
	if count <= 0 then return 0 end
	local okSize, sizeValue = pcall(function() return container.AbsoluteSize end)
	if not okSize or not sizeValue or sizeValue.X <= 0 then return 0 end
	local padding = 0
	local okLayout, layout = pcall(function() return container:FindFirstChildOfClass("UIListLayout") end)
	if okLayout and layout then padding = layout.Padding.Offset or 0 end
	return count * (sizeValue.X / (aspect or 7.5)) + padding * (count - 1)
end

local function RefreshRowDividers(listFrame)
	if not listFrame or not listFrame.Parent then return end
	local rows = {}
	for _, child in ipairs(listFrame:GetChildren()) do
		if child:IsA("GuiObject") then
			if listFrame:GetAttribute("NLGroupOutlineInset") and not child:GetAttribute("NLGroupInsetApplied") then
				-- UIPadding already insets the row. An extra -4 offset squeezed
				-- controls and left uneven spacing along the card outline.
				child:SetAttribute("NLGroupInsetApplied", true)
			end
			local divider = child:FindFirstChild("Lines")
			if divider and divider:IsA("GuiObject") then
				divider.Visible = true
				divider.Position = UDim2.new(0, 14, 1, -1)
				divider.Size = UDim2.new(1, -28, 0, 1)
				divider.BackgroundColor3 = Color3.fromRGB(255, 255, 255)
				-- Neverlose row lines sit only ~7 levels above the card (28 on 21).
				divider.BackgroundTransparency = 0.965
				divider.BorderSizePixel = 0
				table.insert(rows, divider)
			end
		end
	end
	if #rows > 0 then
		rows[#rows].Visible = false
	end
end

local _watchedDividers = {}

local function WatchRowDividers(listFrame)
	if not listFrame or _watchedDividers[listFrame] then return end
	_watchedDividers[listFrame] = true
	RefreshRowDividers(listFrame)
	listFrame.ChildAdded:Connect(function() task.defer(RefreshRowDividers, listFrame) end)
	listFrame.ChildRemoved:Connect(function() task.defer(RefreshRowDividers, listFrame) end)
	table.insert(_watchedDividers, listFrame)
end

task.spawn(function()
	while true do
		task.wait(2)
		for i = #_watchedDividers, 1, -1 do
			local frame = _watchedDividers[i]
			if not frame or not frame.Parent then table.remove(_watchedDividers, i) end
		end
	end
end)

-- Preserve each widget's authored alpha and reveal real content rows with a
-- short, staggered fade. State is cached per instance so tab switches do not
-- overwrite intentionally muted labels, selected states, or control styling.
local _contentAlphaState = setmetatable({}, { __mode = "k" })
local _contentRevealTokens = setmetatable({}, { __mode = "k" })

local function ContentAlphaTargets(object)
    local state = _contentAlphaState[object]
    if state then return state end
    state = {}
    -- Only text and strokes are animated on rows. Background/image alpha can
    -- encode live states (checkboxes, toggles, previews), so they stay untouched.
    if (object:IsA("TextLabel") or object:IsA("TextButton") or object:IsA("TextBox")) and object.Text ~= "" then
        state.TextTransparency = object.TextTransparency
    end
    if object:IsA("UIStroke") and object.Name ~= "GroupOutline" then
        state.Transparency = object.Transparency
    end
    _contentAlphaState[object] = state
    return state
end

local function HasVisiblePath(object, root)
    local current = object
    while current and current ~= root do
        if current:IsA("GuiObject") and not current.Visible then return false end
        current = current.Parent
    end
    return current == root
end

local function RevealContentRows(elements)
    if not elements or not elements.Parent or not elements:IsA("GuiObject") or not elements.Visible then return end
    local token = (_contentRevealTokens[elements] or 0) + 1
    _contentRevealTokens[elements] = token
    local rows = {}
    for _, child in ipairs(elements:GetChildren()) do
        if child:IsA("GuiObject") then table.insert(rows, child) end
    end
    table.sort(rows, function(a, b) return a.LayoutOrder < b.LayoutOrder end)
    for index, row in ipairs(rows) do
        if row.Visible then
            local delaySeconds = math.min((index - 1) * 0.012, 0.10)
            task.delay(delaySeconds, function()
                if not elements.Parent or not row.Parent or _contentRevealTokens[elements] ~= token then return end
                local objects = { row }
                for _, descendant in ipairs(row:GetDescendants()) do
                    table.insert(objects, descendant)
                end
                for _, object in ipairs(objects) do
                    if object.Parent and HasVisiblePath(object, elements) then
                        local targets = ContentAlphaTargets(object)
                        local props = {}
                        for property, target in pairs(targets) do
                            if type(target) == "number" and target < 0.995 then
                                props[property] = target
                                pcall(function() object[property] = 1 end)
                            end
                        end
                        if next(props) then
                            Tween(object, props, 0.16, Enum.EasingStyle.Sine, Enum.EasingDirection.Out)
                        end
                    end
                end
            end)
        end
    end
end

local function AnimateSectionColumn(column)
    if not column or not column.Parent or not column.Visible then return end
    local token = (column:GetAttribute("NLSectionMotionToken") or 0) + 1
    column:SetAttribute("NLSectionMotionToken", token)
    -- Tab switch: the column rises into place. Columns sit in a UIListLayout,
    -- so Position is ignored; the top padding carries the motion instead.
    local columnPadding = column:FindFirstChildOfClass("UIPadding")
    if columnPadding then
        local delaySeconds = column.Name == "Right" and 0.035 or 0
        columnPadding.PaddingTop = UDim.new(0, 12)
        Tween(columnPadding, { PaddingTop = UDim.new(0, 0) }, 0.26, Enum.EasingStyle.Quint, Enum.EasingDirection.Out, delaySeconds)
    end
    local sections = {}
    for _, section in ipairs(column:GetChildren()) do
        if section:IsA("GuiObject") and section.Visible then
            table.insert(sections, section)
        end
    end
    table.sort(sections, function(a, b) return a.LayoutOrder < b.LayoutOrder end)
    for index, section in ipairs(sections) do
        local delaySeconds = math.min((index - 1) * 0.018, 0.054)
        task.delay(delaySeconds, function()
            if not column.Parent or not column.Visible or column:GetAttribute("NLSectionMotionToken") ~= token then return end
            if not section.Parent or not section.Visible then return end
            -- Keep text at its authored opacity. The former fade-to-transparent pass
            -- was responsible for one-frame label flashes on tab changes.
            -- Keep typography at native scale: fractional UIScale transitions can soften glyphs.
            local motionScale = section:FindFirstChild("SectionMotionScale")
            if motionScale and motionScale:IsA("UIScale") then motionScale.Scale = 1 end

            local list = section:FindFirstChild("Elements") or section:FindFirstChild("Container")
            if list and list:IsA("GuiObject") then
                local outline = list:FindFirstChild("GroupOutline")
                if outline and outline:IsA("UIStroke") then
                    local target = outline:GetAttribute("NLBaseTransparency")
                    if type(target) ~= "number" then
                        target = outline.Transparency
                        outline:SetAttribute("NLBaseTransparency", target)
                    end
                    outline.Transparency = math.min(0.84, target + 0.16)
                    Tween(outline, { Transparency = target }, 0.13, Enum.EasingStyle.Quint, Enum.EasingDirection.Out)
                end
            end
            local heading = section:FindFirstChild("SectionLabel", true)
            if heading and heading:IsA("TextLabel") then
                local baseColor = heading:GetAttribute("NLBaseTextColor")
                if typeof(baseColor) ~= "Color3" then
                    baseColor = heading.TextColor3
                    heading:SetAttribute("NLBaseTextColor", baseColor)
                end
                heading.TextColor3 = Color3.fromRGB(190, 199, 224)
                Tween(heading, { TextColor3 = baseColor }, 0.15, Enum.EasingStyle.Sine, Enum.EasingDirection.Out)
            end
        end)
    end
end

local function GetSliderStep(min, max)
	local span = max - min
	if span <= 0 then return 1 end
	if span >= 20 then return 1 end
	return 0.1
end

local function Quantize(value, min, max, step)
	local clamped = math.clamp(value, min, max)
	local snapped = min + math.round((clamped - min) / step) * step
	if math.abs(snapped - max) < step * 0.001 then snapped = max end
	if math.abs(snapped - math.round(snapped)) < 0.0001 then snapped = math.round(snapped) end
	return snapped
end

local function FormatSliderValue(value, suffix)
	suffix = tostring(suffix or ""):gsub("^%s+", ""):gsub("%s+$", "")
	local text
	if string.find(suffix, "°", 1, true) then
		text = string.format("%.1f", value)
	elseif math.abs(value - math.round(value)) < 0.0001 then
		text = tostring(math.round(value))
	else
		text = string.format("%.1f", value)
	end
	return text .. (suffix or "")
end

local RepositionOpenPopups
local function MakeDraggable(frame, handle)
	handle = handle or frame
	frame.Draggable = false
	local dragging = false
	local dragInput, pointerPos, framePos

	local function update(input)
		if not input or not input.Position then return end
		local delta = input.Position - pointerPos
		local position = UDim2.new(framePos.X.Scale, framePos.X.Offset + delta.X, framePos.Y.Scale, framePos.Y.Offset + delta.Y)
		local camera = workspace.CurrentCamera
		if camera and camera.ViewportSize.X > frame.AbsoluteSize.X and camera.ViewportSize.Y > frame.AbsoluteSize.Y then
			local anchor = frame.AnchorPoint
			local x = position.X.Scale * camera.ViewportSize.X + position.X.Offset
			local y = position.Y.Scale * camera.ViewportSize.Y + position.Y.Offset
			x = math.clamp(x, frame.AbsoluteSize.X * anchor.X, camera.ViewportSize.X - frame.AbsoluteSize.X * (1 - anchor.X))
			y = math.clamp(y, frame.AbsoluteSize.Y * anchor.Y, camera.ViewportSize.Y - frame.AbsoluteSize.Y * (1 - anchor.Y))
			position = UDim2.fromOffset(x, y)
		end
		frame.Position = position
		if RepositionOpenPopups then RepositionOpenPopups() end
	end

	handle.InputBegan:Connect(function(input)
		if IsPrimaryInput(input) then
			dragging = true
			dragInput = input
			pointerPos = input.Position
			framePos = frame.Position
			local shield = GetDragShield(frame)
			if shield then shield.Visible = true end
		end
	end)

	handle.InputChanged:Connect(function(input)
		if dragging and (input.UserInputType == Enum.UserInputType.MouseMovement or input.UserInputType == Enum.UserInputType.Touch) then
			dragInput = input
		end
	end)

	UserInputService.InputChanged:Connect(function(input)
		if dragging and input == dragInput then update(input) end
	end)

	UserInputService.InputEnded:Connect(function(input)
		if IsPrimaryInput(input) then
			dragging = false
			dragInput = nil
			local shield = frame:FindFirstChild("DragShield")
			if shield then shield.Visible = false end
		end
	end)
end


	local _openPopups = {}
	local _popupClipRestore = {}
	local _popupClipCounts = {}
	local UnregisterPopup
	local RestorePopupClipping

	local function IsPopupAncestor(ancestor, descendant)
		if not ancestor or not descendant or ancestor == descendant then return false end
		local ok, result = pcall(function() return descendant:IsDescendantOf(ancestor) end)
		return ok and result
	end

	local function RegisterPopup(frame, closeFn, trigger)
		if not frame or type(closeFn) ~= "function" then return end
		AddInputSink(frame)
		for i = #_openPopups, 1, -1 do
			local entry = _openPopups[i]
			if not entry.frame or not entry.frame.Parent then
				if entry.connection then pcall(function() entry.connection:Disconnect() end) end
				RestorePopupClipping(entry.frame)
				table.remove(_openPopups, i)
			elseif entry.frame == frame then
				entry.closeFn = closeFn
				entry.trigger = trigger
				return
			end
		end
		-- Logical parent: the open popup that holds the trigger. A color picker or
		-- list opened from a plate lives under MainFrame, not inside the plate, so
		-- the instance tree alone cannot tell they belong together.
		local parentFrame
		if trigger then
			for _, entry in ipairs(_openPopups) do
				if entry.frame ~= frame and IsPopupAncestor(entry.frame, trigger) then
					parentFrame = entry.frame
				end
			end
		end
		local connection
		if frame.Destroying and frame.Destroying.Connect then
			local ok, result = pcall(function()
				return frame.Destroying:Connect(function()
					UnregisterPopup(frame)
					if connection then pcall(function() connection:Disconnect() end) end
				end)
			end)
			if ok then connection = result end
		end
		table.insert(_openPopups, {frame = frame, closeFn = closeFn, trigger = trigger, parent = parentFrame, connection = connection})
	end

	-- True when `frame` was opened (directly or further down) from `root`.
	local function IsLogicalChild(frame, root)
		local guard = 0
		while frame and guard < 16 do
			guard = guard + 1
			local parentFrame
			for _, entry in ipairs(_openPopups) do
				if entry.frame == frame then parentFrame = entry.parent end
			end
			if parentFrame == root then return true end
			frame = parentFrame
		end
		return false
	end

	UnregisterPopup = function(frame)
		-- Close what was opened from this popup first (a list or picker opened
		-- from a plate must not outlive the plate).
		local copy = {}
		for i, entry in ipairs(_openPopups) do copy[i] = entry end
		for _, entry in ipairs(copy) do
			if entry.frame ~= frame and IsLogicalChild(entry.frame, frame) and type(entry.closeFn) == "function" then
				pcall(entry.closeFn)
			end
		end
		for i = #_openPopups, 1, -1 do
			if _openPopups[i].frame == frame then
				if _openPopups[i].connection then pcall(function() _openPopups[i].connection:Disconnect() end) end
				table.remove(_openPopups, i)
			end
		end
		-- Re-enable the column clipping only after the close animation; doing it
		-- at once cut the fading plate off behind the column edge.
		task.delay(0.22, function()
			for _, entry in ipairs(_openPopups) do
				if entry.frame == frame then return end
			end
			RestorePopupClipping(frame)
		end)
	end

	-- Marks every open popup that must stay because a kept popup was opened from it.
	local function KeepPopupChain(keep, frame)
		local guard = 0
		while frame and not keep[frame] and guard < 16 do
			keep[frame] = true
			guard = guard + 1
			local parentFrame
			for _, entry in ipairs(_openPopups) do
				if entry.frame == frame then parentFrame = entry.parent end
			end
			frame = parentFrame
		end
	end

	local function CloseAllPopupsExcept(exceptFrame)
		local copy = {}
		for i, entry in ipairs(_openPopups) do copy[i] = entry end
		-- The click that opens a popup comes from inside the popup holding its
		-- trigger; that popup (and its own parents) stays open.
		local keep = {}
		local pointer = GetPointerPosition()
		for _, entry in ipairs(copy) do
			if entry.frame and entry.frame.Parent and entry.frame.Visible and pointer and IsPointInsideTree(entry.frame, pointer) then
				KeepPopupChain(keep, entry.frame)
			end
		end
		for _, entry in ipairs(copy) do
			if entry.frame and entry.frame.Parent and entry.frame ~= exceptFrame and not keep[entry.frame]
				and not IsPopupAncestor(entry.frame, exceptFrame) and type(entry.closeFn) == "function" then
				pcall(entry.closeFn)
			end
		end
	end

	local function HideAllPopupsNow(instant)
		local copy = {}
		for i, entry in ipairs(_openPopups) do copy[i] = entry end
		for _, entry in ipairs(copy) do
			local frame = entry.frame
			if frame and frame.Parent then
				if entry.connection then pcall(function() entry.connection:Disconnect() end) end
				RestorePopupClipping(frame)
				if instant then
					frame.Visible = false
				else
					local token = (frame:GetAttribute("PopupToken") or 0) + 1
					frame:SetAttribute("PopupToken", token)
					Tween(frame, { BackgroundTransparency = 1 }, 0.18)
					TweenShadowLayers(frame, false, 0.18, Enum.EasingDirection.In)
					task.delay(0.19, function()
						if not frame.Parent or frame:GetAttribute("PopupToken") ~= token then return end
						frame.Visible = false
						local home = frame.Parent
						if home and home:IsA("GuiObject") then ApplyZIndexLadder(frame, home.ZIndex) end
					end)
				end
			end
		end
		table.clear(_openPopups)
	end

	local function ClosePopupsUnder(root)
		if not root then return end
		local copy = {}
		for i, entry in ipairs(_openPopups) do copy[i] = entry end
		for _, entry in ipairs(copy) do
			if entry.frame and entry.frame ~= root and (IsPopupAncestor(root, entry.frame) or IsLogicalChild(entry.frame, root))
				and type(entry.closeFn) == "function" then
				pcall(entry.closeFn)
			end
		end
	end

	UserInputService.InputBegan:Connect(function(input)
		if not IsPrimaryInput(input) then return end
		local point = GetInputPosition(input)
		local toClose = {}
		-- A click inside a child popup (color picker, list) counts as inside every
		-- popup it was opened from, so the parent plate stays open.
		local keep = {}
		for _, entry in ipairs(_openPopups) do
			local frame = entry.frame
			if frame and frame.Parent and frame.Visible then
				local inside = IsPointInsideTree(frame, point)
				if entry.trigger and entry.trigger.Parent then
					inside = inside or IsPointInsideTree(entry.trigger, point)
				end
				if inside then KeepPopupChain(keep, frame) end
			end
		end
		for _, entry in ipairs(_openPopups) do
			local frame = entry.frame
			if frame and frame.Parent and frame.Visible and not keep[frame] and type(entry.closeFn) == "function" then
				table.insert(toClose, entry.closeFn)
			end
		end
		for _, fn in ipairs(toClose) do pcall(fn) end
	end)

-- Tween instances cannot be stored as Roblox attributes; keep live popup tweens
-- in a weak-key table so destroyed frames do not remain referenced.
local _activePopupTweens = setmetatable({}, { __mode = "k" })

local function CancelPopupTween(frame)
	if not frame then return end
	local running = _activePopupTweens[frame]
	_activePopupTweens[frame] = nil
	if running then
		pcall(function() running:Cancel() end)
	end
end

local function PlayPopupTween(frame, info, props)
	if not frame or not frame.Parent then return end
	local ok, tween = pcall(function() return TweenService:Create(frame, info, props) end)
	if not ok or not tween then return end
	_activePopupTweens[frame] = tween
	tween.Completed:Connect(function()
		if _activePopupTweens[frame] == tween then
			_activePopupTweens[frame] = nil
		end
	end)
	tween:Play()
end

local function GetPopupScale(frame)
	if not frame or not frame.Parent then return nil end
	-- Reuse the animation scale on every opening. Checking for any UIScale first
	-- made _PopScale work once, then silently disabled future open/close motion.
	local pop = frame:FindFirstChild("_PopScale")
	if pop and pop:IsA("UIScale") then return pop end
	local existing = frame:FindFirstChildOfClass("UIScale")
	if existing then return nil end
	return New("UIScale", { Name = "_PopScale", Scale = 1 }, frame)
end

-- Fades a popup's text and icons with its background, so closing reads as one
-- fade instead of the text vanishing at the end. Each element's own
-- transparency is remembered while hidden and restored on the next open.
local function FadePopupContent(frame, show, dur)
	for _, d in ipairs(frame:GetDescendants()) do
		if not d:GetAttribute("IsShadowLayer") then
			local prop, key
			if d:IsA("TextLabel") or d:IsA("TextButton") or d:IsA("TextBox") then
				prop, key = "TextTransparency", "NLFadeText"
			elseif d:IsA("ImageLabel") or d:IsA("ImageButton") then
				prop, key = "ImageTransparency", "NLFadeImage"
			end
			if prop then
				if show then
					local base = d:GetAttribute(key)
					if type(base) ~= "number" then base = d[prop] end
					d:SetAttribute(key, nil)
					d[prop] = 1
					Tween(d, { [prop] = base }, dur, Enum.EasingStyle.Quad, Enum.EasingDirection.Out)
				else
					if d:GetAttribute(key) == nil then d:SetAttribute(key, d[prop]) end
					Tween(d, { [prop] = 1 }, dur, Enum.EasingStyle.Quad, Enum.EasingDirection.In)
				end
			end
		end
	end
end

local function SmoothOpen(frame, targetAlpha, dur, style, dir)
	if not frame or not frame.Parent then return end
	local token = (frame:GetAttribute("PopupToken") or 0) + 1
	frame:SetAttribute("PopupToken", token)
	CancelPopupTween(frame)
	frame.BackgroundTransparency = 1
	frame.Visible = true
	TweenShadowLayers(frame, true, dur or 0.2)
	FadePopupContent(frame, true, dur or 0.17)
	local scale = GetPopupScale(frame)
	if scale then
		scale.Scale = 0.965
		Tween(scale, { Scale = 1 }, dur or 0.17, Enum.EasingStyle.Quint, Enum.EasingDirection.Out)
	end
	PlayPopupTween(frame, TweenInfo.new(dur or 0.17, style or Enum.EasingStyle.Quint, dir or Enum.EasingDirection.Out), {BackgroundTransparency = targetAlpha})
end

local function SmoothClose(frame, dur, cb)
	if not frame or not frame.Parent then return end
	local token = (frame:GetAttribute("PopupToken") or 0) + 1
	frame:SetAttribute("PopupToken", token)
	CancelPopupTween(frame)
	TweenShadowLayers(frame, false, dur or 0.18, Enum.EasingDirection.In)
	FadePopupContent(frame, false, dur or 0.14)
	local scale = GetPopupScale(frame)
	if scale then
		Tween(scale, { Scale = 0.985 }, dur or 0.14, Enum.EasingStyle.Quad, Enum.EasingDirection.In)
	end
	PlayPopupTween(frame, TweenInfo.new(dur or 0.14, Enum.EasingStyle.Quad, Enum.EasingDirection.In), {BackgroundTransparency = 1})
	task.delay((dur or 0.14) + 0.01, function()
		if frame.Parent and frame:GetAttribute("PopupToken") == token then
			frame.Visible = false
			if scale then scale.Scale = 1 end
			local home = frame.Parent
			if home and home:IsA("GuiObject") then ApplyZIndexLadder(frame, home.ZIndex) end
			if cb then cb() end
		end
	end)
end

function Library:AddWindow(hubTitle, hubImage, gameTitle)
	hubTitle = tostring(hubTitle or "Neverlose")
	hubImage = tostring(hubImage or "")
	gameTitle = tostring(gameTitle or "Counter Strike 2")
	if string.lower(hubTitle) == "neverlose" and string.lower(gameTitle) == "blockstrike" then
		hubTitle, gameTitle = gameTitle, hubTitle
	end
	local daysLeft = tonumber(Library.DaysLeft) or "Lifetime"

	_windowConfigCounter = _windowConfigCounter + 1
	local windowConfigId = tostring(_windowConfigCounter)
	local _registeredElements = {}
	local configKeyCounts = {}
	local function RegisterConfigElement(prefix, label, object)
		local base = tostring(prefix) .. tostring(label or "item")
		local count = (configKeyCounts[base] or 0) + 1
		configKeyCounts[base] = count
		table.insert(_registeredElements, {key = base .. "#" .. count, obj = object})
	end

	local mainColor = Color3.fromRGB(78, 139, 255)
	local tabs = {}
	local activeTabIndex = nil
	local tabOrder = 0
	local WindowObj = {}
	-- Config extras: state that is not an element value (hotkeys, overlay
	-- positions). key -> { get = fn() -> json value, set = fn(value) }, saved
	-- as "__extra_<key>" next to the element values. A field, not a local:
	-- AddWindow is close to the register limit.
	WindowObj._configExtras = {}
	-- Set from the start so nothing (watermark, lists, toggle button) shows
	-- before the loader finishes.
	WindowObj._loaderActive = Library.ShowLoader ~= false
	local _coloredElements = {}
	local logoVisible = true
	local customization = {
		font = FONT,
		textColor = Color3.fromRGB(226, 228, 236),
		sectionTitleSize = 12,
		sectionTitleColor = Color3.fromRGB(92, 96, 106), -- Neverlose section caps: neutral grey
		sectionTitleTransparency = 0,
		watermarkText = "NEVERLOSE  •  UI",
		watermarkVisible = false,
		cornerRadius = 14, -- matches the window and panel UICorner
		showContextDots = false,
	}

	local screenGuiParent
	pcall(function() screenGuiParent = game.CoreGui end)
	if not screenGuiParent then
		local ok, coreGui = pcall(function() return game:GetService("CoreGui") end)
		if ok then screenGuiParent = coreGui end
	end
	if not screenGuiParent and LocalPlayer and LocalPlayer.FindFirstChildOfClass then
		local ok, playerGui = pcall(function() return LocalPlayer:FindFirstChildOfClass("PlayerGui") end)
		if ok then screenGuiParent = playerGui end
	end
	if not screenGuiParent then
		pcall(function() screenGuiParent = game:GetService("CoreGui") end)
	end

	local NeverloseCS2 = New("ScreenGui", {
		Name = "NeverloseCS2",
		ResetOnSpawn = false,
		ClipToDeviceSafeArea = false,
		DisplayOrder = 100,
		ZIndexBehavior = Enum.ZIndexBehavior.Global,
	}, screenGuiParent)





	local MainFrame = New("Frame", {
		Name = "MainFrame",
		Active = true,
		Draggable = false,
		AnchorPoint = Vector2.new(0.5, 0.43),
		Size = UDim2.new(0.78, 0, 0.78, 0),
		Position = UDim2.new(0.5, 0, 0.43, 0),
	-- Neverlose sidebar reads ~6,9,17: darker, cooler base under the glass.
	BackgroundColor3 = Color3.fromRGB(8, 10, 17),
	BackgroundTransparency = 0.25,
	BorderSizePixel = 0,
	ClipsDescendants = false,
	}, NeverloseCS2)
	local MainFrameUIScale
	local windowTargetSize = MainFrame.Size
	local windowAnimSize = UDim2.new(
		windowTargetSize.X.Scale * 0.97, windowTargetSize.X.Offset * 0.97,
		windowTargetSize.Y.Scale * 0.97, windowTargetSize.Y.Offset * 0.97
	)
	local _windowContextTargets = {}
	GetDragShield(MainFrame)
    local Watermark = New("TextLabel", {
	Name = "Watermark",
	Visible = false,
    Position = UDim2.new(0.982, 0, 0.984, 0),
    Size = UDim2.new(0.150, 0, 0.026, 0),
    AnchorPoint = Vector2.new(1, 1),
    BackgroundColor3 = Color3.fromRGB(255, 255, 255),
    BackgroundTransparency = 0.94,
		Text = "NEVERLOSE  •  UI",
		TextColor3 = Color3.fromRGB(255, 255, 255),
		TextTransparency = 0.35,
		TextScaled = false,
		TextSize = 11,
    Font = FONT,
    TextXAlignment = Enum.TextXAlignment.Center,
    TextYAlignment = Enum.TextYAlignment.Center,
    ZIndex = 6000,
    }, MainFrame)
	do local c = Instance.new("UICorner"); c.CornerRadius = UDim.new(1, 0); c.Parent = Watermark end
	local watermarkConstraint = Watermark:FindFirstChild("ReadableTextConstraint")
	if watermarkConstraint then
		watermarkConstraint.MinTextSize = 9
		watermarkConstraint.MaxTextSize = 11
	end
	customization.watermark = Watermark
	do local c = Instance.new("UICorner"); c.CornerRadius = UDim.new(0, 14); c.Parent = MainFrame end
	do local windowStroke = Stroke(MainFrame, "WindowOutline"); windowStroke.Transparency = 0.95 end
	local DragHandle = New("Frame", {
		Name = "DragHandle",
		Position = UDim2.new(0.2, 0, 0, 0),
		Size = UDim2.new(0.6, 0, 0, 54),
		BackgroundTransparency = 1,
		Active = true,
		ZIndex = 1,
	}, MainFrame)
	New("UISizeConstraint", {
		MinSize = Vector2.new(220, 180),
		MaxSize = Vector2.new(798, 610),
	}, MainFrame)

	local AcrylicLib = LoadAcrylic()
	local AcrylicBlur = AcrylicLib.new(MainFrame)

	-- Acrylic blur for small overlays (watermark, hotkey/spectator pills): one
	-- glass part per frame, shown only while the frame and its ancestors are
	-- visible. One RenderStepped drives them all.
	WindowObj._blurs = {}
	-- Drag `target` by `handle` (watermark, hotkey and spectator lists). Only
	-- while the menu is open, so game clicks are never taken. Sets the
	-- "Dragged" attribute so automatic placement leaves the frame alone.
	WindowObj._makeDraggable = function(handle, target, saveKey)
		if saveKey then
			WindowObj._configExtras["pos_" .. saveKey] = {
				get = function()
					if not target:GetAttribute("Dragged") then return nil end
					local p = target.Position
					return { p.X.Scale, p.X.Offset, p.Y.Scale, p.Y.Offset }
				end,
				set = function(v)
					if type(v) ~= "table" or type(v[4]) ~= "number" then return end
					target.Position = UDim2.new(v[1], v[2], v[3], v[4])
					target:SetAttribute("Dragged", true)
				end,
			}
		end
		local drag
		handle.InputBegan:Connect(function(input)
			if input.UserInputType ~= Enum.UserInputType.MouseButton1 and input.UserInputType ~= Enum.UserInputType.Touch then return end
			if not MainFrame.Visible then return end
			drag = { point = input.Position, pos = target.Position }
			target:SetAttribute("Dragged", true)
			input.Changed:Connect(function()
				if input.UserInputState == Enum.UserInputState.End then drag = nil end
			end)
		end)
		UserInputService.InputChanged:Connect(function(input)
			if not drag then return end
			if input.UserInputType ~= Enum.UserInputType.MouseMovement and input.UserInputType ~= Enum.UserInputType.Touch then return end
			local d = input.Position - drag.point
			target.Position = UDim2.new(drag.pos.X.Scale, drag.pos.X.Offset + d.X, drag.pos.Y.Scale, drag.pos.Y.Offset + d.Y)
		end)
		UserInputService.InputEnded:Connect(function(input)
			if input.UserInputType == Enum.UserInputType.MouseButton1 or input.UserInputType == Enum.UserInputType.Touch then drag = nil end
		end)
	end

	-- Soft drop shadow: the common 9-slice shadow image (rbxassetid 6014261993,
	-- slice 49..450), `spread` px larger than the frame and 2px lower. Its
	-- resting alpha is kept in "ImageAlpha" for fades.
	WindowObj._softShadow = function(frame, alpha, spread)
		spread = spread or 18
		local img = Instance.new("ImageLabel")
		img.Name = "SoftShadow"
		img.AnchorPoint = Vector2.new(0.5, 0.5)
		img.Position = UDim2.new(0.5, 0, 0.5, 2)
		img.Size = UDim2.new(1, spread, 1, spread)
		img.BackgroundTransparency = 1
		img.Image = "rbxassetid://6014261993"
		img.ImageColor3 = Color3.new(0, 0, 0)
		img.ImageTransparency = alpha or 0.5
		img.ScaleType = Enum.ScaleType.Slice
		img.SliceCenter = Rect.new(49, 49, 450, 450)
		img.SliceScale = spread / 60
		img.ZIndex = math.max(1, frame.ZIndex - 1)
		img:SetAttribute("ImageAlpha", img.ImageTransparency)
		img.Parent = frame
		return img
	end

	-- Neverlose capsule look: five faint capsule layers, each 1px wider,
	-- stacked under a nearly clear plate. Inside they add up to the plate's
	-- darkness; outside they thin out, so the plate's ends melt into the
	-- shadow instead of having a hard edge. Layers carry IsShadowLayer and
	-- ShadowAlpha for the fades.
	WindowObj._edgeShadow = function(host, z)
		for i = 1, 5 do
			local spread = i
			local layer = Instance.new("Frame")
			layer.Name = "ShadowLayer" .. i
			layer.Position = UDim2.new(0, -spread, 0, 1 - spread)
			layer.Size = UDim2.new(1, spread * 2, 1, spread * 2)
			layer.BackgroundColor3 = Color3.fromRGB(4, 5, 7)
			layer.BackgroundTransparency = 0.88
			layer.BorderSizePixel = 0
			layer.ZIndex = z
			layer:SetAttribute("IsShadowLayer", true)
			layer:SetAttribute("ShadowAlpha", 0.88)
			local c = Instance.new("UICorner"); c.CornerRadius = UDim.new(1, 0); c.Parent = layer
			layer.Parent = host
		end
	end

	-- Neverlose's logo is bold white "NL" with a lavender shade 1px left/down
	-- (as on the watermark). Text, so it never depends on an image loading;
	-- used whenever no custom hub image is given.
	WindowObj._textLogo = function(parent, textSize, z)
		local label = Instance.new("TextLabel")
		label.Name = "LogoText"
		label.Size = UDim2.fromScale(1, 1)
		label.BackgroundTransparency = 1
		label.Text = "NL"
		label.TextColor3 = Color3.fromRGB(240, 240, 250)
		label.TextSize = textSize
		label.Font = FONT_BOLD
		label.ZIndex = z + 1
		label.Parent = parent
		local shade = label:Clone()
		shade.Name = "LogoShade"
		shade.Position = UDim2.fromOffset(-1, 1)
		shade.TextColor3 = Color3.fromRGB(150, 164, 255)
		shade.ZIndex = z
		shade.Parent = label
		return label
	end

	-- Thumbnails (rbxthumb://) sometimes never load. Avatars get the URL from
	-- GetUserThumbnailAsync, which waits until the thumbnail is ready; any
	-- image still not loaded after 6s shows `fallbackText` instead.
	WindowObj._imageFallback = function(img, fallbackText, isAvatar)
		if not img then return end
		if isAvatar then
			task.spawn(function()
				local ok, url = pcall(function()
					return Players:GetUserThumbnailAsync(LocalPlayer.UserId, Enum.ThumbnailType.HeadShot, Enum.ThumbnailSize.Size150x150)
				end)
				if ok and type(url) == "string" and img.Parent then img.Image = url end
			end)
		end
		task.delay(6, function()
			if not img.Parent or img.IsLoaded then return end
			if img:FindFirstChild("ImageFallback") then return end
			local label = Instance.new("TextLabel")
			label.Name = "ImageFallback"
			label.Size = UDim2.fromScale(1, 1)
			label.BackgroundTransparency = 1
			label.Text = fallbackText
			label.TextColor3 = Color3.fromRGB(235, 236, 241)
			label.TextScaled = true
			label.Font = FONT_BOLD
			label.ZIndex = img.ZIndex + 1
			local pad = Instance.new("UIPadding")
			pad.PaddingTop = UDim.new(0.2, 0); pad.PaddingBottom = UDim.new(0.2, 0)
			pad.PaddingLeft = UDim.new(0.15, 0); pad.PaddingRight = UDim.new(0.15, 0)
			pad.Parent = label
			label.Parent = img
			-- A late load (thumbnails can take a while) replaces the letter.
			local function check()
				if img.IsLoaded and label.Parent then label:Destroy() end
			end
			img:GetPropertyChangedSignal("IsLoaded"):Connect(check)
			img:GetPropertyChangedSignal("Image"):Connect(function() task.delay(1, check) end)
			check()
		end)
	end

	-- Default NL logo: the logo image when it loads, the drawn "NL" under it
	-- until then (and for good if it never loads).
	WindowObj._logoWithFallback = function(parent, textSize, z, corner)
		local text = WindowObj._textLogo(parent, textSize, z)
		local img = Instance.new("ImageLabel")
		img.Name = "HubGlyph"
		img.Size = UDim2.fromScale(1, 1)
		img.BackgroundTransparency = 1
		img.Image = "rbxthumb://type=Asset&id=118608145176297&w=420&h=420"
		img.ImageRectOffset = Vector2.new(48, 48)
		img.ImageRectSize = Vector2.new(324, 324)
		img.ScaleType = Enum.ScaleType.Stretch
		img.ZIndex = z + 2
		img.Parent = parent
		local c = Instance.new("UICorner"); c.CornerRadius = UDim.new(0, corner or 8); c.Parent = img
		local function check()
			if img.IsLoaded then text.Visible = false end
		end
		img:GetPropertyChangedSignal("IsLoaded"):Connect(check)
		check()
		return img
	end

	-- The glass is rectangular: `inset` pulls it in from the left/right ends so
	-- it does not show past rounded capsule corners.
	WindowObj._attachBlur = function(frame, inset)
		local area = frame
		if inset and inset > 0 and not frame:FindFirstChildWhichIsA("UIGridStyleLayout") then
			area = Instance.new("Frame")
			area.Name = "BlurArea"
			area.BackgroundTransparency = 1
			area.Position = UDim2.fromOffset(inset, 0)
			area.Size = UDim2.new(1, -inset * 2, 1, 0)
			area.Parent = frame
		end
		local ok, blur = pcall(AcrylicLib.new, area)
		if not ok or not blur then return end
		-- Frames inside a CanvasGroup fade with the group, not their own alpha.
		table.insert(WindowObj._blurs, { frame = frame, blur = blur, group = frame:FindFirstAncestorWhichIsA("CanvasGroup") })
		if WindowObj._blurLoop then return end
		WindowObj._blurLoop = RunService.RenderStepped:Connect(function()
			local list = WindowObj._blurs
			for i = #list, 1, -1 do
				local e = list[i]
				local part = e.blur.Instances.Part
				if not e.frame.Parent or not part.Parent then
					pcall(e.blur.Destroy)
					table.remove(list, i)
				elseif e.frame.Visible and e.frame.BackgroundTransparency < 0.98 and IsAncestorVisible(e.frame)
					and not (e.group and e.group.GroupTransparency > 0.6) then
					pcall(e.blur.Update)
					part.Transparency = part:GetAttribute("TargetTransparency") or 0.8
				else
					part.Transparency = 1
				end
			end
		end)
	end

	local function GetMainFrameScale()
		local scale = MainFrameUIScale and MainFrameUIScale.Scale or 1
		if type(scale) ~= "number" or scale ~= scale or scale <= 0 then return 1 end
		return scale
	end

	local function GetVisualScale(object)
		local scale = 1
		local current = object
		while current do
			local ok, uiScale = pcall(function()
				return current:FindFirstChildOfClass("UIScale")
			end)
			if (not ok or not uiScale) and current == MainFrame then uiScale = MainFrameUIScale end
			if (ok or current == MainFrame) and uiScale and type(uiScale.Scale) == "number" and uiScale.Scale > 0 then
				scale = scale * uiScale.Scale
			end
			if current == MainFrame then break end
			current = current.Parent
		end
		if type(scale) ~= "number" or scale ~= scale or scale <= 0 then return 1, 1 end
		scale = math.clamp(scale, 0.01, 100)
		return scale, scale
	end

	local function GetPopupParentOrigin(popup)
		local parent = popup and popup.Parent
		if parent and parent:IsA("GuiObject") then
			return parent.AbsolutePosition.X, parent.AbsolutePosition.Y,
				parent.AbsoluteSize.X, parent.AbsoluteSize.Y
		end
		return 0, 0, 0, 0
	end

	local function AbsoluteFromPosition(popup)
		local baseX, baseY, sizeX, sizeY = GetPopupParentOrigin(popup)
		local scaleX, scaleY = GetVisualScale(popup)
		local position = popup.Position
		return baseX + (position.X.Scale * sizeX + position.X.Offset) * scaleX,
			baseY + (position.Y.Scale * sizeY + position.Y.Offset) * scaleY
	end

	local function MovePopupToAbsolute(popup, x, y)
		if not popup or not popup.Parent then return end
		if popup.AbsoluteSize.X <= 0 or popup.AbsoluteSize.Y <= 0 then return end
		local scaleX, scaleY = GetVisualScale(popup)
		local position = popup.Position
		local dx = (x - popup.AbsolutePosition.X) / scaleX
		local dy = (y - popup.AbsolutePosition.Y) / scaleY
		if math.abs(dx) < 0.5 and math.abs(dy) < 0.5 then return end
		popup.Position = UDim2.new(position.X.Scale, position.X.Offset + dx, position.Y.Scale, position.Y.Offset + dy)
	end

	-- Tooltips (Neverlose): hovering a function for 1.5s shows its description
	-- in a dark plate beside the cursor; leaving or clicking hides it. One
	-- shared plate, inside the window so it fades with the menu.
	WindowObj._tooltip = function(target, text)
		if not target or type(text) ~= "string" or text == "" then return end
		target:SetAttribute("Tooltip", text)
		if target:GetAttribute("TooltipHooked") then return end
		target:SetAttribute("TooltipHooked", true)
		local tip = WindowObj._tooltipFrame
		if not tip then
			tip = New("TextLabel", {
				Name = "Tooltip", Size = UDim2.fromOffset(0, 28), AutomaticSize = Enum.AutomaticSize.X,
				BackgroundColor3 = Color3.fromRGB(18, 18, 25), BackgroundTransparency = 1, Text = "", TextColor3 = Color3.fromRGB(235, 236, 241),
				TextTransparency = 1, TextSize = 13, Font = FONT, Visible = false, ZIndex = 9500,
			}, MainFrame)
			New("UICorner", { CornerRadius = UDim.new(0, 6) }, tip)
			local outline = Stroke(tip)
			outline:SetAttribute("Base", outline.Transparency)
			New("UIPadding", { PaddingLeft = UDim.new(0, 10), PaddingRight = UDim.new(0, 10) }, tip)
			WindowObj._tooltipFrame = tip
			WindowObj._tooltipToken = 0
		end
		local function hide()
			WindowObj._tooltipToken = WindowObj._tooltipToken + 1
			local token = WindowObj._tooltipToken
			Tween(tip, { BackgroundTransparency = 1, TextTransparency = 1 }, 0.1)
			task.delay(0.11, function() if token == WindowObj._tooltipToken then tip.Visible = false end end)
		end
		target.MouseEnter:Connect(function()
			WindowObj._tooltipToken = WindowObj._tooltipToken + 1
			local token = WindowObj._tooltipToken
			task.delay(1.5, function()
				if token ~= WindowObj._tooltipToken or not target.Parent or not MainFrame.Visible then return end
				tip.Text = target:GetAttribute("Tooltip") or ""
				local point = GetPointerPosition()
				local inset = WindowObj._topInset or 0
				tip.Visible = true
				ApplyZIndexLadder(tip, NextPopupZ())
				MovePopupToAbsolute(tip, point.X + 14, point.Y - inset + 10)
				Tween(tip, { BackgroundTransparency = 0.04, TextTransparency = 0 }, 0.14)
			end)
		end)
		target.MouseLeave:Connect(hide)
		target.InputBegan:Connect(function(input)
			if input.UserInputType == Enum.UserInputType.MouseButton1 then hide() end
		end)
	end

	local function PopupSafeArea()
		local gui = MainFrame and MainFrame.Parent
		if gui and gui:IsA("ScreenGui") and gui.AbsoluteSize.X > 0 and gui.AbsoluteSize.Y > 0 then
			return gui.AbsolutePosition, gui.AbsoluteSize
		end
		if MainFrame and MainFrame.AbsoluteSize.X > 0 and MainFrame.AbsoluteSize.Y > 0 then
			return MainFrame.AbsolutePosition, MainFrame.AbsoluteSize
		end
		return Vector2.new(0, 0), Vector2.new(0, 0)
	end

	local function ConstrainPopupToMainFrame(popup, margin, knownSize)
		margin = type(margin) == "number" and math.max(0, margin) or 6
		if not popup or not popup.Parent or not popup:IsA("GuiObject") then return end
		local size = knownSize or popup.AbsoluteSize
		if size.X <= 0 or size.Y <= 0 then return end
		local mainPosition, mainSize = PopupSafeArea()
		if mainSize.X <= 0 or mainSize.Y <= 0 then return end
		local minX = mainPosition.X + margin
		local minY = mainPosition.Y + margin
		local maxX = mainPosition.X + mainSize.X - size.X - margin
		local maxY = mainPosition.Y + mainSize.Y - size.Y - margin
		if maxX < minX then minX, maxX = mainPosition.X, mainPosition.X end
		local currentX, currentY = AbsoluteFromPosition(popup)
		local x = maxX < minX and minX or math.clamp(currentX, minX, maxX)
		local y = maxY < minY and minY or math.clamp(currentY, minY, maxY)
		MovePopupToAbsolute(popup, x, y)
	end
		local function FindClippingAncestors(popup)
			local ancestors = {}
			local current = popup and popup.Parent
			while current and current ~= MainFrame do
				local ok, clips = pcall(function() return current.ClipsDescendants end)
				if ok and clips == true then table.insert(ancestors, current) end
				current = current.Parent
			end
			return ancestors
		end

		local function ForceLiftClipping(popup)
			local current = popup and popup.Parent
			while current and current ~= MainFrame do
				pcall(function() current.ClipsDescendants = false end)
				current = current.Parent
			end
		end

		local function RememberPopupClipping(popup)
			if not popup or not popup.Parent or _popupClipRestore[popup] then return end
			local ancestors = FindClippingAncestors(popup)
			if #ancestors == 0 then return end
			local restored = {}
			for _, ancestor in ipairs(ancestors) do
				local okClip, wasClipping = pcall(function() return ancestor.ClipsDescendants end)
				table.insert(restored, { frame = ancestor, clipping = okClip and wasClipping == true })
				_popupClipCounts[ancestor] = (_popupClipCounts[ancestor] or 0) + 1
				ancestor.ClipsDescendants = false
			end
			_popupClipRestore[popup] = restored
		end

		RestorePopupClipping = function(popup)
			local ancestors = popup and _popupClipRestore[popup]
			if not ancestors then return end
			_popupClipRestore[popup] = nil
			for _, entry in ipairs(ancestors) do
				local ancestor = entry.frame
				local count = (_popupClipCounts[ancestor] or 1) - 1
				if count > 0 then
					_popupClipCounts[ancestor] = count
				else
					_popupClipCounts[ancestor] = nil
					if ancestor.Parent then ancestor.ClipsDescendants = entry.clipping == true end
				end
			end
		end


	local function positionPopupNow(popup, preferBelow, margin, anchorOverride, knownSize)
		if not popup or not popup.Parent then return end
		local parent = popup.Parent
		local anchor = anchorOverride or (parent and (parent:FindFirstChild("TopBar") or parent:FindFirstChild("OpenBtn") or parent:FindFirstChild("ScaleOpenBtn") or parent:FindFirstChild("LangOpenBtn")))
		local parentPosition = (anchor or parent).AbsolutePosition
		local parentSize = (anchor or parent).AbsoluteSize
		local mainPosition, mainSize = PopupSafeArea()
		if mainSize.X <= 0 or mainSize.Y <= 0 or parentSize.X <= 0 or parentSize.Y <= 0 then return end
		local popupSize = knownSize or popup.AbsoluteSize
		if popupSize.X <= 0 or popupSize.Y <= 0 then return end
		local edge = type(margin) == "number" and math.max(0, margin) or 6
		local minX = mainPosition.X + edge
		local minY = mainPosition.Y + edge
		local maxX = mainPosition.X + mainSize.X - popupSize.X - edge
		local maxY = mainPosition.Y + mainSize.Y - popupSize.Y - edge
		if maxX < minX then minX, maxX = mainPosition.X, mainPosition.X end
		local y = preferBelow and parentPosition.Y + parentSize.Y + edge or parentPosition.Y - popupSize.Y - edge
		if preferBelow and y > maxY then
			local flipped = parentPosition.Y - popupSize.Y - edge
			if flipped >= minY then y = flipped end
		elseif not preferBelow and y < minY then
			local flipped = parentPosition.Y + parentSize.Y + edge
			if flipped <= maxY then y = flipped end
		end
		local currentX = select(1, AbsoluteFromPosition(popup))
		local x = maxX < minX and minX or math.clamp(anchor and anchor.AbsolutePosition.X or currentX, minX, maxX)
		if maxY < minY then y = minY end
		MovePopupToAbsolute(popup, x, math.clamp(y, minY, math.max(minY, maxY)))
	end

	RepositionOpenPopups = function()
		local copy = {}
		for i, entry in ipairs(_openPopups) do copy[i] = entry end
		for _, entry in ipairs(copy) do
			local frame = entry.frame
			if frame and frame.Parent and frame.Visible then
				ConstrainPopupToMainFrame(frame, 6)
			end
		end
	end

	local function PositionPopupWithinMain(popup, preferBelow, margin, anchorOverride, knownSize)
		if not popup or not popup.Parent then return end
		RememberPopupClipping(popup)
		local wasVisible = popup.Visible
		local savedTransparency = popup.BackgroundTransparency
		if not wasVisible then
			popup.Visible = true
			popup.BackgroundTransparency = 1
		end
		positionPopupNow(popup, preferBelow, margin, anchorOverride, knownSize)
		ConstrainPopupToMainFrame(popup, margin, knownSize)
		if not wasVisible then
			popup.BackgroundTransparency = savedTransparency
			popup.Visible = false
			task.defer(function()
				if popup.Parent and popup.Visible then
					PositionPopupWithinMain(popup, preferBelow, margin, anchorOverride)
				end
			end)
		end
	end

	-- Neverlose option lists open instantly, centred on the field that opened
	-- them (overlapping it), not dropped below with a grow animation. Kept on
	-- WindowObj instead of a local: AddWindow is near Luau's register cap.
	-- Neverlose sidebar glyphs drawn on an 18x18 pixel grid (even sizes,
	-- whole-pixel positions, centred on 9) so they stay crisp; a UIScale fits
	-- the grid to the icon box (tabs and sub-tabs differ). The parts follow the
	-- ImageLabel's ImageColor3/ImageTransparency, so every tint tween drives them.
	-- Returns true when `kind` has a drawn glyph.
	WindowObj._drawTabGlyph = function(kind, icon)
		kind = string.lower(tostring(kind or ""))
		local isRage = kind == "crosshair" or kind == "rage" or kind == "aimbot"
		local isMouse = kind == "mouse" or kind == "legit"
		local isUser = kind == "user" or kind == "player" or kind == "players"
		-- World keeps its image icon; the drawn globe did not read well.
		local isGlobe = false
		local isMisc = kind == "gear" or kind == "misc" or kind == "miscellaneous" or kind == "settings"
		if not (isRage or isMouse or isUser or isGlobe or isMisc) then return false end

		local CUT = Color3.fromRGB(20, 22, 30)
		local grid = Instance.new("Frame")
		grid.Name = "GlyphGrid"
		grid.AnchorPoint = Vector2.new(0.5, 0.5)
		grid.Position = UDim2.fromScale(0.5, 0.5)
		grid.Size = UDim2.fromOffset(18, 18)
		grid.BackgroundTransparency = 1
		grid.ZIndex = icon.ZIndex + 1
		grid.Parent = icon
		local fit = Instance.new("UIScale")
		fit.Parent = grid
		-- Ratio of on-screen sizes, so the window's own UIScale is not applied twice.
		local function refit()
			local gw, iw = grid.AbsoluteSize.X, icon.AbsoluteSize.X
			if gw > 0 and iw > 0 then fit.Scale = fit.Scale * iw / gw end
		end
		icon:GetPropertyChangedSignal("AbsoluteSize"):Connect(refit)
		task.defer(refit)

		local fills, rings = {}, {}
		local function part(parent, x, y, w, h, radius, isCut)
			local f = Instance.new("Frame")
			f.Position = UDim2.fromOffset(x, y)
			f.Size = UDim2.fromOffset(w, h)
			f.BorderSizePixel = 0
			f.BackgroundColor3 = isCut and CUT or icon.ImageColor3
			f.ZIndex = icon.ZIndex + (isCut and 3 or 2)
			f.Parent = parent
			if radius then local c = Instance.new("UICorner"); c.CornerRadius = radius; c.Parent = f end
			if not isCut then table.insert(fills, f) end
			return f
		end
		local ROUND = UDim.new(1, 0)
		if isRage then
			local ring = Instance.new("Frame")
			ring.Position = UDim2.fromOffset(3, 3)
			ring.Size = UDim2.fromOffset(12, 12)
			ring.BackgroundTransparency = 1
			ring.ZIndex = icon.ZIndex + 2
			ring.Parent = grid
			local rc = Instance.new("UICorner"); rc.CornerRadius = ROUND; rc.Parent = ring
			local stroke = Instance.new("UIStroke"); stroke.Thickness = 2; stroke.Color = icon.ImageColor3; stroke.Parent = ring
			table.insert(rings, stroke)
			part(grid, 8, 0, 2, 5)      -- top tick
			part(grid, 8, 13, 2, 5)     -- bottom tick
			part(grid, 0, 8, 5, 2)      -- left tick
			part(grid, 13, 8, 5, 2)     -- right tick
			part(grid, 8, 8, 2, 2)      -- centre dot
		elseif isMouse then
			-- Neverlose mouse: an egg-shaped solid body (fully rounded ends), a
			-- thin line under the buttons and a thin divider between them.
			-- Odd width so the 1px divider sits exactly in the middle.
			local body = part(grid, 4, 1, 11, 16, UDim.new(0.5, 0))
			part(body, 0, 6, 11, 1, nil, true)   -- button split
			part(body, 5, 0, 1, 6, nil, true)    -- left/right button divider
		elseif isUser then
			part(grid, 5, 1, 8, 8, ROUND)                 -- head
			part(grid, 2, 10, 14, 7, UDim.new(0, 5))      -- shoulders
		elseif isGlobe then
			local globe = part(grid, 1, 1, 16, 16, ROUND)
			part(globe, 3, 3, 5, 4, ROUND, true)
			part(globe, 8, 10, 6, 3, ROUND, true)
			part(globe, 10, 3, 3, 3, ROUND, true)
		elseif isMisc then
			local plate = part(grid, 2, 2, 14, 14, UDim.new(0, 4))
			part(plate, 3, 4, 8, 2, nil, true)       -- upper slider line
			part(plate, 3, 8, 8, 2, nil, true)       -- lower slider line
			part(plate, 8, 3, 4, 4, ROUND, true)     -- upper knob (right)
			part(plate, 2, 7, 4, 4, ROUND, true)     -- lower knob (left)
		end
		icon.Image = ""
		local function sync()
			for _, f in ipairs(fills) do
				f.BackgroundColor3 = icon.ImageColor3
				f.BackgroundTransparency = icon.ImageTransparency
			end
			for _, r in ipairs(rings) do
				r.Color = icon.ImageColor3
				r.Transparency = icon.ImageTransparency
			end
		end
		icon:GetPropertyChangedSignal("ImageColor3"):Connect(sync)
		icon:GetPropertyChangedSignal("ImageTransparency"):Connect(sync)
		sync()
		return true
	end

	-- Small line icons drawn from frames (no image assets needed).
	WindowObj._drawGlyph = function(kind, host, color)
		local function bar(x, y, w, h, rot)
			local f = Instance.new("Frame")
			f.AnchorPoint = Vector2.new(0.5, 0.5)
			f.Position = UDim2.fromOffset(x, y)
			f.Size = UDim2.fromOffset(w, h)
			f.Rotation = rot or 0
			f.BackgroundColor3 = color
			f.BorderSizePixel = 0
			f.ZIndex = host.ZIndex + 1
			f.Parent = host
			return f
		end
		local function box(x, y, w, h)
			local f = Instance.new("Frame")
			f.Position = UDim2.fromOffset(x, y)
			f.Size = UDim2.fromOffset(w, h)
			f.BackgroundTransparency = 1
			f.ZIndex = host.ZIndex + 1
			f.Parent = host
			local c = Instance.new("UICorner"); c.CornerRadius = UDim.new(0, 2); c.Parent = f
			local o = Instance.new("UIStroke"); o.Color = color; o.Thickness = 1.4; o.Parent = f
			return f
		end
		-- Pixel-aligned shapes only (no rotation, whole-pixel sizes) so the small
		-- icons stay crisp; bin and restore use the image assets the bind menu
		-- already uses for Delete and Reset.
		local function pix(x, y, w, h)
			local f = Instance.new("Frame")
			f.Position = UDim2.fromOffset(x, y)
			f.Size = UDim2.fromOffset(w, h)
			f.BackgroundColor3 = color
			f.BorderSizePixel = 0
			f.ZIndex = host.ZIndex + 1
			f.Parent = host
			return f
		end
		local function image(asset)
			local img = Instance.new("ImageLabel")
			img.Size = UDim2.fromScale(1, 1)
			img.BackgroundTransparency = 1
			img.Image = asset
			img.ImageColor3 = color
			img.ScaleType = Enum.ScaleType.Fit
			img.ZIndex = host.ZIndex + 1
			img.Parent = host
			return img
		end
		if kind == "share" then
			-- box with an arrow leaving its top-right corner
			pix(1, 5, 2, 8); pix(1, 12, 8, 2); pix(7, 9, 2, 5); pix(1, 5, 4, 2)
			pix(8, 1, 5, 2); pix(11, 1, 2, 5)
			pix(9, 3, 2, 2); pix(7, 5, 2, 2); pix(5, 7, 2, 2)
		elseif kind == "copy" then
			box(1, 4, 8, 9)
			box(5, 1, 8, 9)
		elseif kind == "trash" then
			image("rbxassetid://116396312853810")
		elseif kind == "restore" then
			image("rbxassetid://106497040962250")
		end
	end

	WindowObj._centerPopupOnField = function(popup, field)
		if not popup or not popup.Parent or not field or not field.Parent then return end
		if WindowObj._styleListPopup then WindowObj._styleListPopup(popup) end
		RememberPopupClipping(popup)
		ForceLiftClipping(popup)
		local size = popup.AbsoluteSize
		local fieldPos, fieldSize = field.AbsolutePosition, field.AbsoluteSize
		if size.X <= 0 or size.Y <= 0 or fieldSize.X <= 0 then return end
		local x = fieldPos.X + (fieldSize.X - size.X) / 2
		local y = fieldPos.Y + (fieldSize.Y - size.Y) / 2
		MovePopupToAbsolute(popup, x, y)
		ConstrainPopupToMainFrame(popup, 6)
	end

	AcrylicBlur.CreateColorPicker = function(anchorButton, initialColor, onChange)
		local currentColor = NormalizeColor(initialColor)
		local hue, saturation, value = Color3.toHSV(currentColor)
		local dragPart = nil
		local isOpen = false

		local frame = New("Frame", {
			Name = "ColorPickerFrame",
			Position = UDim2.fromOffset(0, 0),
			Size = UDim2.fromOffset(212, 246),
			BackgroundColor3 = Color3.fromRGB(17, 19, 28),
			BackgroundTransparency = 0.02,
			BorderSizePixel = 0,
			Visible = false,
			ClipsDescendants = false,
			ZIndex = Z_BASE + 800,
		}, MainFrame)
		New("UICorner", { CornerRadius = UDim.new(0, 10) }, frame)
		Stroke(frame, "ColorPickerOutline")
		New("UIPadding", {
			PaddingLeft = UDim.new(0, 10),
			PaddingRight = UDim.new(0, 10),
			PaddingTop = UDim.new(0, 10),
			PaddingBottom = UDim.new(0, 10),
		}, frame)
		New("UIListLayout", {
			FillDirection = Enum.FillDirection.Vertical,
			Padding = UDim.new(0, 10),
			SortOrder = Enum.SortOrder.LayoutOrder,
		}, frame)

		local svSquare = New("ImageButton", {
			Name = "SVSquare",
			Size = UDim2.fromOffset(192, 136),
			BackgroundColor3 = Color3.fromHSV(hue, 1, 1),
			BorderSizePixel = 0,
			AutoButtonColor = false,
			Image = "",
			ClipsDescendants = true,
			LayoutOrder = 1,
			ZIndex = Z_BASE + 801,
		}, frame)
		New("UICorner", { CornerRadius = UDim.new(0, 6) }, svSquare)
		local svWhite = New("Frame", {
			Name = "SVWhite",
			Size = UDim2.new(1, 0, 1, 0),
			BackgroundColor3 = Color3.fromRGB(255, 255, 255),
			BorderSizePixel = 0,
			ZIndex = Z_BASE + 802,
		}, svSquare)
		New("UICorner", { CornerRadius = UDim.new(0, 6) }, svWhite)
		New("UIGradient", {
			Rotation = 0,
			Transparency = NumberSequence.new({
				NumberSequenceKeypoint.new(0, 0),
				NumberSequenceKeypoint.new(1, 1),
			}),
		}, svWhite)
		local svBlack = New("Frame", {
			Name = "SVBlack",
			Size = UDim2.new(1, 0, 1, 0),
			BackgroundColor3 = Color3.fromRGB(0, 0, 0),
			BorderSizePixel = 0,
			ZIndex = Z_BASE + 803,
		}, svSquare)
		New("UICorner", { CornerRadius = UDim.new(0, 6) }, svBlack)
		New("UIGradient", {
			Rotation = 90,
			Transparency = NumberSequence.new({
				NumberSequenceKeypoint.new(0, 1),
				NumberSequenceKeypoint.new(1, 0),
			}),
		}, svBlack)

		local svShadow = New("Frame", {
			Name = "SVCursorShadow",
			AnchorPoint = Vector2.new(0.5, 0.5),
			Position = UDim2.new(saturation, 0, 1 - value, 0),
			Size = UDim2.fromOffset(14, 14),
			BackgroundColor3 = Color3.fromRGB(10, 12, 18),
			BackgroundTransparency = 0,
			BorderSizePixel = 0,
			ZIndex = Z_BASE + 804,
		}, svSquare)
		New("UICorner", { CornerRadius = UDim.new(1, 0) }, svShadow)
		local svRing = New("Frame", {
			Name = "SVCursorRing",
			AnchorPoint = Vector2.new(0.5, 0.5),
			Position = UDim2.new(saturation, 0, 1 - value, 0),
			Size = UDim2.fromOffset(12, 12),
			BackgroundColor3 = Color3.fromRGB(255, 255, 255),
			BorderSizePixel = 0,
			ZIndex = Z_BASE + 805,
		}, svSquare)
		New("UICorner", { CornerRadius = UDim.new(1, 0) }, svRing)
		local svCursor = New("Frame", {
			Name = "SVCursor",
			AnchorPoint = Vector2.new(0.5, 0.5),
			Position = UDim2.new(saturation, 0, 1 - value, 0),
			Size = UDim2.fromOffset(8, 8),
			BackgroundColor3 = currentColor,
			BorderSizePixel = 0,
			ZIndex = Z_BASE + 806,
		}, svSquare)
		New("UICorner", { CornerRadius = UDim.new(1, 0) }, svCursor)

		local hueBar = New("ImageButton", {
			Name = "HueBar",
			Size = UDim2.fromOffset(192, 10),
			-- UIGradient multiplies the background: red here zeroed green/blue and
			-- turned the spectrum into red-black-red.
			BackgroundColor3 = Color3.fromRGB(255, 255, 255),
			BorderSizePixel = 0,
			AutoButtonColor = false,
			Image = "",
			ClipsDescendants = false,
			Active = true,
			LayoutOrder = 2,
			ZIndex = Z_BASE + 801,
		}, frame)
		New("UICorner", { CornerRadius = UDim.new(1, 0) }, hueBar)
		New("UIGradient", {
			Name = "HueSpectrum",
			Rotation = 0,
			Color = ColorSequence.new({
				ColorSequenceKeypoint.new(0, Color3.fromRGB(255, 0, 0)),
				ColorSequenceKeypoint.new(0.17, Color3.fromRGB(255, 255, 0)),
				ColorSequenceKeypoint.new(0.33, Color3.fromRGB(0, 255, 0)),
				ColorSequenceKeypoint.new(0.5, Color3.fromRGB(0, 255, 255)),
				ColorSequenceKeypoint.new(0.67, Color3.fromRGB(0, 0, 255)),
				ColorSequenceKeypoint.new(0.83, Color3.fromRGB(255, 0, 255)),
				ColorSequenceKeypoint.new(1, Color3.fromRGB(255, 0, 0)),
			}),
		}, hueBar)
		local hueThumb = New("Frame", {
			Name = "HueThumb",
			AnchorPoint = Vector2.new(0.5, 0.5),
			Position = UDim2.new(hue, 0, 0.5, 0),
			Size = UDim2.fromOffset(14, 14),
			BackgroundColor3 = Color3.fromRGB(17, 19, 28),
			BorderSizePixel = 0,
			ZIndex = Z_BASE + 805,
		}, hueBar)
		New("UICorner", { CornerRadius = UDim.new(1, 0) }, hueThumb)
		local hueThumbInner = New("Frame", {
			Name = "HueThumbInner",
			AnchorPoint = Vector2.new(0.5, 0.5),
			Position = UDim2.new(0.5, 0, 0.5, 0),
			Size = UDim2.fromOffset(12, 12),
			BackgroundColor3 = Color3.fromRGB(255, 255, 255),
			BorderSizePixel = 0,
			ZIndex = Z_BASE + 806,
		}, hueThumb)
		New("UICorner", { CornerRadius = UDim.new(1, 0) }, hueThumbInner)

		local hexRow = New("Frame", {
			Name = "HexRow",
			Size = UDim2.fromOffset(192, 28),
			BackgroundTransparency = 1,
			BorderSizePixel = 0,
			LayoutOrder = 3,
			ZIndex = Z_BASE + 801,
		}, frame)
		local hexField = New("Frame", {
			Name = "HexField",
			Position = UDim2.fromOffset(0, 0),
			Size = UDim2.fromOffset(156, 28),
			BackgroundColor3 = Color3.fromRGB(28, 31, 45),
			BorderSizePixel = 0,
			ZIndex = Z_BASE + 802,
		}, hexRow)
		New("UICorner", { CornerRadius = UDim.new(0, 6) }, hexField)
		local hexPreview = New("Frame", {
			Name = "HexPreview",
			Position = UDim2.fromOffset(8, 7),
			Size = UDim2.fromOffset(14, 14),
			BackgroundColor3 = currentColor,
			BorderSizePixel = 0,
			ZIndex = Z_BASE + 803,
		}, hexField)
		New("UICorner", { CornerRadius = UDim.new(0, 4) }, hexPreview)
		local hexLabel = New("TextLabel", {
			Name = "HexValue",
			Position = UDim2.fromOffset(30, 0),
			Size = UDim2.fromOffset(118, 28),
			BackgroundTransparency = 1,
			Text = ColorToHex(currentColor),
			TextColor3 = Color3.fromRGB(226, 228, 236),
			TextScaled = false,
			TextSize = 14,
			Font = FONT,
			TextXAlignment = Enum.TextXAlignment.Left,
			TextTruncate = Enum.TextTruncate.AtEnd,
			ZIndex = Z_BASE + 803,
		}, hexField)
		local copyButton = New("ImageButton", {
			Name = "CopyHex",
			Position = UDim2.fromOffset(164, 0),
			Size = UDim2.fromOffset(28, 28),
			BackgroundColor3 = Color3.fromRGB(28, 31, 45),
			BorderSizePixel = 0,
			AutoButtonColor = false,
			Image = "",
			ZIndex = Z_BASE + 802,
		}, hexRow)
		New("UICorner", { CornerRadius = UDim.new(0, 6) }, copyButton)
		local copyBack = New("Frame", {
			Name = "CopyIconBack",
			Position = UDim2.fromOffset(7, 6),
			Size = UDim2.fromOffset(9, 11),
			BackgroundTransparency = 1,
			BorderSizePixel = 1,
			BorderColor3 = Color3.fromRGB(226, 228, 236),
			ZIndex = Z_BASE + 803,
		}, copyButton)
		New("UICorner", { CornerRadius = UDim.new(0, 2) }, copyBack)
		local copyFront = New("Frame", {
			Name = "CopyIconFront",
			Position = UDim2.fromOffset(11, 10),
			Size = UDim2.fromOffset(9, 11),
			BackgroundColor3 = Color3.fromRGB(28, 31, 45),
			BorderSizePixel = 1,
			BorderColor3 = Color3.fromRGB(226, 228, 236),
			ZIndex = Z_BASE + 804,
		}, copyButton)
		New("UICorner", { CornerRadius = UDim.new(0, 2) }, copyFront)
		-- Borders do not draw on rounded frames, which left the copy button empty.
		for _, part in ipairs({ copyBack, copyFront }) do
			part.BorderSizePixel = 0
			local outline = Instance.new("UIStroke")
			outline.Color = Color3.fromRGB(226, 228, 236)
			outline.Thickness = 1
			outline.Parent = part
		end
		for _, field in ipairs({ hexField, copyButton }) do
			field.BackgroundColor3 = Color3.fromRGB(27, 28, 38)
			local outline = Instance.new("UIStroke")
			outline.Color = Color3.fromRGB(255, 255, 255)
			outline.Transparency = 0.93
			outline.Thickness = 1
			outline.ApplyStrokeMode = Enum.ApplyStrokeMode.Border
			outline.Parent = field
		end

		-- Recently picked colours, shared by every picker (Neverlose keeps a swatch
		-- row under the hex field). Click one to apply it.
		Library._recentColors = Library._recentColors or {}
		local swatchRow = New("Frame", {
			Name = "RecentSwatches",
			Size = UDim2.fromOffset(192, 22),
			BackgroundTransparency = 1,
			BorderSizePixel = 0,
			LayoutOrder = 4,
			ZIndex = Z_BASE + 801,
		}, frame)
		New("UIListLayout", { FillDirection = Enum.FillDirection.Horizontal, Padding = UDim.new(0, 6), SortOrder = Enum.SortOrder.LayoutOrder }, swatchRow)
		local swatchButtons = {}
		for i = 1, 7 do
			local swatch = New("TextButton", {
				Name = "Swatch" .. i,
				Size = UDim2.fromOffset(22, 22),
				BackgroundColor3 = Color3.fromRGB(27, 28, 38),
				BorderSizePixel = 0,
				AutoButtonColor = false,
				Text = "",
				LayoutOrder = i,
				ZIndex = Z_BASE + 802,
			}, swatchRow)
			New("UICorner", { CornerRadius = UDim.new(0, 5) }, swatch)
			swatchButtons[i] = swatch
		end

		local function refreshDisplay(notify)
			currentColor = Color3.fromHSV(hue, saturation, value)
			svSquare.BackgroundColor3 = Color3.fromHSV(hue, 1, 1)
			svShadow.Position = UDim2.new(saturation, 0, 1 - value, 0)
			svRing.Position = UDim2.new(saturation, 0, 1 - value, 0)
			svCursor.Position = UDim2.new(saturation, 0, 1 - value, 0)
			svCursor.BackgroundColor3 = currentColor
			hueThumb.Position = UDim2.new(hue, 0, 0.5, 0)
			hexPreview.BackgroundColor3 = currentColor
			hexLabel.Text = ColorToHex(currentColor)
			if anchorButton and anchorButton.Parent then anchorButton.BackgroundColor3 = currentColor end
			if notify then InvokeCallback(onChange, currentColor) end
		end

		local function setColor(color)
			currentColor = NormalizeColor(color)
			hue, saturation, value = Color3.toHSV(currentColor)
			refreshDisplay(false)
		end

		local function refreshSwatches()
			for i, swatch in ipairs(swatchButtons) do
				local color = Library._recentColors[i]
				swatch.BackgroundColor3 = color or Color3.fromRGB(27, 28, 38)
				swatch.Active = color ~= nil
			end
		end

		local function pushRecent(color)
			local list = Library._recentColors
			for i = #list, 1, -1 do
				if ColorToHex(list[i]) == ColorToHex(color) then table.remove(list, i) end
			end
			table.insert(list, 1, color)
			while #list > #swatchButtons do table.remove(list) end
			refreshSwatches()
		end

		for i, swatch in ipairs(swatchButtons) do
			swatch.MouseButton1Click:Connect(function()
				local color = Library._recentColors[i]
				if not color then return end
				setColor(color)
				InvokeCallback(onChange, currentColor)
			end)
		end

		local function updateSV(input)
			local point = GetInputPosition(input)
			local pos = svSquare.AbsolutePosition
			local size = svSquare.AbsoluteSize
			if size.X <= 0 or size.Y <= 0 then return end
			saturation = math.clamp((point.X - pos.X) / size.X, 0, 1)
			value = 1 - math.clamp((point.Y - pos.Y) / size.Y, 0, 1)
			refreshDisplay(true)
		end

		local function updateHue(input)
			local point = GetInputPosition(input)
			local pos = hueBar.AbsolutePosition
			local size = hueBar.AbsoluteSize
			if size.X <= 0 then return end
			hue = math.clamp((point.X - pos.X) / size.X, 0, 1)
			refreshDisplay(true)
		end

		local function positionFrame()
			if not frame.Parent or not anchorButton or not anchorButton.Parent then return end
			local safePos, safeSize = PopupSafeArea()
			if safeSize.X <= 0 or safeSize.Y <= 0 then return end
			local anchorPos, anchorSize = anchorButton.AbsolutePosition, anchorButton.AbsoluteSize
			local popupW = frame.AbsoluteSize.X > 0 and frame.AbsoluteSize.X or 212
			local popupH = frame.AbsoluteSize.Y > 0 and frame.AbsoluteSize.Y or 246
			local x = anchorPos.X + anchorSize.X - popupW
			local y = anchorPos.Y + anchorSize.Y + 6
			if y + popupH > safePos.Y + safeSize.Y - 6 then y = anchorPos.Y - popupH - 6 end
			x = math.clamp(x, safePos.X + 6, math.max(safePos.X + 6, safePos.X + safeSize.X - popupW - 6))
			y = math.clamp(y, safePos.Y + 6, math.max(safePos.Y + 6, safePos.Y + safeSize.Y - popupH - 6))
			MovePopupToAbsolute(frame, x, y)
		end

		local function closePicker()
			if not isOpen and not frame.Visible then return end
			isOpen = false
			UnregisterPopup(frame)
			SmoothClose(frame, 0.12)
		end

		local function openPicker()
			if isOpen then return end
			CloseAllPopupsExcept(frame)
			isOpen = true
			frame.Visible = true
			ApplyZIndexLadder(frame, NextPopupZ())
			positionFrame()
			refreshSwatches()
			SmoothOpen(frame, 0.02, 0.16)
			task.defer(function()
				if frame.Visible and isOpen then positionFrame() end
			end)
			RegisterPopup(frame, closePicker, anchorButton)
		end

		local picker = { frame = frame }
		function picker.Set(color) setColor(color) end
		function picker.Get() return currentColor end
		function picker.Close() closePicker() end
		function picker.Toggle()
			if isOpen then closePicker() else openPicker() end
		end

		anchorButton.MouseButton1Click:Connect(function() picker.Toggle() end)
		svSquare.InputBegan:Connect(function(input)
			if IsPrimaryInput(input) then dragPart = "sv"; updateSV(input) end
		end)
		hueBar.InputBegan:Connect(function(input)
			if IsPrimaryInput(input) then dragPart = "hue"; updateHue(input) end
		end)
		UserInputService.InputChanged:Connect(function(input)
			if not dragPart then return end
			if input.UserInputType == Enum.UserInputType.MouseMovement or input.UserInputType == Enum.UserInputType.Touch then
				if dragPart == "sv" then updateSV(input) else updateHue(input) end
			end
		end)
		UserInputService.InputEnded:Connect(function(input)
			if dragPart and IsPrimaryInput(input) then
				dragPart = nil
				pushRecent(currentColor)
			end
		end)
		copyButton.MouseButton1Click:Connect(function()
			if setclipboard then setclipboard(hexLabel.Text) end
		end)
		setColor(currentColor)
		return picker
	end



local Stats = game:GetService('Stats')

local FPSText, MSText, TimeText, RamText, SignalImage
local ACCENT = mainColor or Color3.fromRGB(78, 139, 255)
local GOOD = Color3.fromRGB(120, 220, 140)
local WARN = Color3.fromRGB(240, 180, 80)
local BAD = Color3.fromRGB(233, 90, 130)

do
local GameInfo = Instance.new('Frame')
GameInfo.Name = "GameInfo"
GameInfo.AnchorPoint = Vector2.new(1, 0)
GameInfo.Position = UDim2.new(1, -6, 0, 2)
-- Neverlose watermark: a thin, dark, see-through strip without outline or
-- dividers; small caps text, accent icons, avatar at the end.
GameInfo.Size = UDim2.fromOffset(0, 35)
-- Width and item positions come from WindowObj._wmRelayout (animated), not
-- from a list layout.
GameInfo.AutomaticSize = Enum.AutomaticSize.None
-- Neverlose watermark: a dark see-through capsule over the blur (the game
-- shows through tinted), no outline.
GameInfo.BackgroundColor3 = Color3.fromRGB(8, 9, 12)
GameInfo.BackgroundTransparency = 0.3
GameInfo.BorderSizePixel = 0
GameInfo.Active = true
GameInfo.Draggable = false
GameInfo.ClipsDescendants = false
GameInfo.Parent = NeverloseCS2
GameInfo.ZIndex = Z_BASE + 900
do local c = Instance.new("UICorner"); c.CornerRadius = UDim.new(1, 0); c.Parent = GameInfo end
if WindowObj._attachBlur then WindowObj._attachBlur(GameInfo) end
do local pd = Instance.new("UIPadding"); pd.PaddingLeft = UDim.new(0, 14); pd.PaddingRight = UDim.new(0, 5); pd.PaddingTop = UDim.new(0, 0); pd.PaddingBottom = UDim.new(0, 0); pd.Parent = GameInfo end

local ICON_LAYERS   = "rbxassetid://114499998778667"
local ICON_WIFI     = "rbxassetid://104941258142372"
local ICON_RAM      = "rbxassetid://82464660673318"
local ICON_CLOCK    = "rbxassetid://136533241128438"
local ICON_EYE      = "rbxassetid://127234874352422"
local ICON_KEYBOARD = "rbxassetid://121978468376124"

local function WMCell(name, order, iconAsset, text, iconSize, iconCorner)
	local cell = Instance.new("Frame")
	cell.Name = name .. "Cell"
	cell.LayoutOrder = order
	cell.Size = UDim2.fromOffset(0, 35)
	cell.AutomaticSize = Enum.AutomaticSize.X
	cell.BackgroundTransparency = 1
	cell.BorderSizePixel = 0
	cell.ZIndex = Z_BASE + 901
	cell.Parent = GameInfo
	do local ly = Instance.new("UIListLayout"); ly.FillDirection = Enum.FillDirection.Horizontal; ly.VerticalAlignment = Enum.VerticalAlignment.Center; ly.Padding = UDim.new(0, 7); ly.SortOrder = Enum.SortOrder.LayoutOrder; ly.Parent = cell end
	do local pd = Instance.new("UIPadding"); pd.PaddingLeft = UDim.new(0, 7); pd.PaddingRight = UDim.new(0, 7); pd.Parent = cell end
	local icon
	if iconAsset then
		icon = Instance.new("ImageLabel")
		icon.Name = name .. "Icon"
		icon.LayoutOrder = 1
		icon.Size = UDim2.fromOffset(iconSize or 15, iconSize or 15)
		icon.BackgroundTransparency = 1
		icon.BorderSizePixel = 0
		icon.Image = iconAsset
		icon.ImageColor3 = ACCENT
		icon.ImageTransparency = 0
		icon.ScaleType = Enum.ScaleType.Fit
		icon.ZIndex = Z_BASE + 901
		icon.Parent = cell
		if iconCorner then do local c = Instance.new("UICorner"); c.CornerRadius = iconCorner; c.Parent = icon end end
	end
	local label = Instance.new("TextLabel")
	label.Name = name
	label.LayoutOrder = 2
	label.Size = UDim2.fromOffset(0, 35)
	label.AutomaticSize = Enum.AutomaticSize.X
	label.BackgroundTransparency = 1
	label.BorderSizePixel = 0
	label.Text = text
	label.TextColor3 = Color3.fromRGB(180, 182, 188)
	label.TextTransparency = 0
	label.TextScaled = false
	label.TextSize = 15
	label.Font = FONT
	label.TextXAlignment = Enum.TextXAlignment.Left
	label.TextYAlignment = Enum.TextYAlignment.Center
	label.ZIndex = Z_BASE + 901
	label.Parent = cell
	return cell, icon, label
end

local function WMDivider()
	local d = Instance.new("Frame")
	d.Name = "Divider"
	d.Size = UDim2.fromOffset(1, 14)
	d.BackgroundColor3 = Color3.fromRGB(120, 126, 150)
	d.BackgroundTransparency = 0.58
	d.BorderSizePixel = 0
	d.Visible = false
	d.ZIndex = Z_BASE + 901
	d.Parent = GameInfo
	return d
end

local BrandCell = Instance.new("Frame")
BrandCell.Name = "BrandCell"
BrandCell.LayoutOrder = 2
BrandCell.Size = UDim2.fromOffset(0, 35)
BrandCell.AutomaticSize = Enum.AutomaticSize.X
BrandCell.BackgroundTransparency = 1
BrandCell.BorderSizePixel = 0
BrandCell.ZIndex = Z_BASE + 901
BrandCell.Parent = GameInfo
do local ly = Instance.new("UIListLayout"); ly.FillDirection = Enum.FillDirection.Horizontal; ly.VerticalAlignment = Enum.VerticalAlignment.Center; ly.Padding = UDim.new(0, 8); ly.SortOrder = Enum.SortOrder.LayoutOrder; ly.Parent = BrandCell end
do local pd = Instance.new("UIPadding"); pd.PaddingLeft = UDim.new(0, 0); pd.PaddingRight = UDim.new(0, 7); pd.Parent = BrandCell end

local NeverIcon = Instance.new("ImageLabel")
NeverIcon.Name = "NeverIcon"
NeverIcon.LayoutOrder = 1
NeverIcon.Size = UDim2.fromOffset(16, 16)
NeverIcon.BackgroundTransparency = 1
NeverIcon.BorderSizePixel = 0
NeverIcon.Image = hubImage ~= "" and hubImage or "rbxthumb://type=Asset&id=118608145176297&w=420&h=420"
NeverIcon.ImageColor3 = Color3.new(1, 1, 1)
NeverIcon.ScaleType = Enum.ScaleType.Fit
NeverIcon.ZIndex = Z_BASE + 901
NeverIcon.Parent = BrandCell
do local c = Instance.new("UICorner"); c.CornerRadius = UDim.new(0, 5); c.Parent = NeverIcon end
-- Neverlose writes "NL" as bold text with a cold tint; the image (with its dark
-- square) stays available as Watermark.logo but is hidden by default.
NeverIcon.Visible = false
do
	local brandText = Instance.new("TextLabel")
	brandText.Name = "BrandText"
	brandText.LayoutOrder = 2
	brandText.Size = UDim2.fromOffset(0, 35)
	brandText.AutomaticSize = Enum.AutomaticSize.X
	brandText.BackgroundTransparency = 1
	brandText.BorderSizePixel = 0
	brandText.Text = "NL"
	brandText.TextColor3 = Color3.fromRGB(240, 240, 250)
	brandText.TextSize = 18
	brandText.Font = FONT_BOLD
	brandText.ZIndex = Z_BASE + 901
	brandText.Parent = BrandCell
	-- Bold caps read 1px low next to the items: lift them by 1px.
	do local pd = Instance.new("UIPadding"); pd.PaddingBottom = UDim.new(0, 2); pd.Parent = brandText end
	-- Lavender copy 1px left/down under the white letters, as on Neverlose.
	brandText.ZIndex = Z_BASE + 903
	local brandShade = brandText:Clone()
	brandShade.Name = "BrandShade"
	brandShade.Position = UDim2.fromOffset(-1, 1)
	brandShade.Size = UDim2.fromScale(1, 1)
	brandShade.AutomaticSize = Enum.AutomaticSize.None
	brandShade.TextColor3 = Color3.fromRGB(150, 164, 255)
	brandShade.ZIndex = brandText.ZIndex - 1
	brandShade.Parent = brandText
end

local UserCell = WMCell("Username", 4, nil, LocalPlayer.DisplayName or "Player")
local UserIcon = Instance.new("ImageLabel")
UserIcon.Name = "UserIcon"
UserIcon.LayoutOrder = 1
UserIcon.Size = UDim2.fromOffset(24, 24)
UserIcon.BackgroundTransparency = 1
UserIcon.BorderSizePixel = 0
UserIcon.Image = "rbxthumb://type=AvatarHeadShot&id=" .. tostring(LocalPlayer.UserId or 0) .. "&w=150&h=150"
UserIcon.ZIndex = Z_BASE + 901
UserIcon.Parent = UserCell
do local c = Instance.new("UICorner"); c.CornerRadius = UDim.new(1, 0); c.Parent = UserIcon end
WindowObj._imageFallback(UserIcon, string.upper(string.sub(tostring(LocalPlayer.Name or "?"), 1, 1)), true)
local Username = UserCell:FindFirstChild("Username")
-- Neverlose shows only the avatar at the end of the strip; the name label stays
-- available through Watermark.user for scripts that want it back.
Username.Visible = false
do local pd = UserCell:FindFirstChildOfClass("UIPadding"); if pd then pd.PaddingRight = UDim.new(0, 0) end end

local FpsCell, FpsCellIcon
FpsCell, FpsCellIcon, FPSText = WMCell("FPS", 6, ICON_LAYERS, "0 FPS")
local PingCell
PingCell, SignalImage, MSText = WMCell("Ping", 8, ICON_WIFI, "VAR ±0 MS")
local RamCell, RamCellIcon
RamCell, RamCellIcon, RamText = WMCell("RAM", 10, ICON_RAM, "0 MB")
local TimeCell, TimeCellIcon
TimeCell, TimeCellIcon, TimeText = WMCell("Time", 12, ICON_CLOCK, os.date("%H:%M"))

do
	local cell, icon, text = WMCell("Speed", 5, ICON_LAYERS, "0 SPEED")
	WindowObj._wmSpeed = { cell = cell, icon = icon }
	WindowObj._wmSpeedText = text
end

-- Neverlose watermark glyphs drawn from frames on a 15px grid: gauge (speed),
-- rising bars (ping), clock (time). They follow the icon's ImageColor3 and
-- ImageTransparency, so SetWatermark's accent still recolours them.
WindowObj._wmGlyph = function(icon, kind)
	if not icon then return end
	icon.Image = ""
	local fills, rings = {}, {}
	local function part(x, y, w, h, round)
		local f = Instance.new("Frame")
		f.Position = UDim2.fromOffset(x, y)
		f.Size = UDim2.fromOffset(w, h)
		f.BorderSizePixel = 0
		f.ZIndex = icon.ZIndex + 1
		f.Parent = icon
		if round then local c = Instance.new("UICorner"); c.CornerRadius = UDim.new(1, 0); c.Parent = f end
		table.insert(fills, f)
		return f
	end
	local function ring(x, y, size, thickness)
		local f = Instance.new("Frame")
		f.Position = UDim2.fromOffset(x, y)
		f.Size = UDim2.fromOffset(size, size)
		f.BackgroundTransparency = 1
		f.ZIndex = icon.ZIndex + 1
		f.Parent = icon
		local c = Instance.new("UICorner"); c.CornerRadius = UDim.new(1, 0); c.Parent = f
		local st = Instance.new("UIStroke"); st.Thickness = thickness; st.Parent = f
		table.insert(rings, st)
	end
	if kind == "speed" then
		ring(1, 1, 13, 1.8)
		part(6, 6, 3, 3, true)
	elseif kind == "ping" then
		-- rising wedge
		for k = 0, 5 do part(1 + k * 2, 11 - k * 2, 2, 3 + k * 2) end
	elseif kind == "time" then
		ring(1, 1, 13, 1.6)
		part(7, 4, 1, 4); part(7, 7, 4, 1)
	end
	icon.ImageTransparency = 0.18
	local function sync()
		for _, f in ipairs(fills) do
			f.BackgroundColor3 = icon.ImageColor3
			f.BackgroundTransparency = icon.ImageTransparency
		end
		for _, r in ipairs(rings) do
			r.Color = icon.ImageColor3
			r.Transparency = icon.ImageTransparency
		end
	end
	icon:GetPropertyChangedSignal("ImageColor3"):Connect(sync)
	icon:GetPropertyChangedSignal("ImageTransparency"):Connect(sync)
	sync()
end
-- Lucide icons (Fluent UI uploads): gauge, signal, clock. The drawn glyphs
-- above stay available through WindowObj._wmGlyph.
WindowObj._wmSpeed.icon.Image = "rbxassetid://10723395708"
SignalImage.Image = "rbxassetid://10734949856" -- lucide server
TimeCellIcon.Image = "rbxassetid://10709805144"
for _, icon in ipairs({ WindowObj._wmSpeed.icon, TimeCellIcon }) do icon.ImageTransparency = 0.12 end

-- Neverlose strip: NL | user icon + name | server icon + "VAR ±N MS" | avatar.
-- Name in grey with a lavender icon, ping in salmon (icon and text).
do
	local cell, icon, text = WMCell("Name", 3, "rbxassetid://10747373176", LocalPlayer.DisplayName or "Player") -- lucide user
	icon.ImageColor3 = Color3.fromRGB(150, 164, 255)
	WindowObj._wmName = { cell = cell, icon = icon, text = text }
end
SignalImage.ImageColor3 = Color3.fromRGB(225, 165, 135)
MSText.TextColor3 = Color3.fromRGB(225, 165, 135)
local WMCells = { brand = BrandCell, name = WindowObj._wmName.cell, user = UserCell, speed = WindowObj._wmSpeed.cell, fps = FpsCell, ping = PingCell, ram = RamCell, time = TimeCell }
local WMDefaultOrder = { "brand", "name", "ping", "speed", "time", "fps", "user", "ram" }
local WMShowMap = { logo = true, name = true, user = true, speed = false, fps = false, ping = true, ram = false, time = false }
local WMDividers = {}
for key in pairs(WMCells) do WMDividers[key] = WMDivider() end

-- ============================================================================
-- PATCH 6: forward-declare WMShadowSync BEFORE ApplyWatermarkLayout
-- ============================================================================
local WMShadowSync

local WMLastOrder
local function ApplyWatermarkLayout(orderList, showMap)
	-- A re-apply without an order (e.g. after the loader) keeps the last one.
	if type(orderList) == "table" and #orderList > 0 then WMLastOrder = orderList else orderList = WMLastOrder end
	if type(showMap) == "table" then
		for key in pairs(WMShowMap) do
			if showMap[key] ~= nil then WMShowMap[key] = showMap[key] == true end
		end
	end
	local function normalize(k) return k == "logo" and "brand" or k end
	local order, seen = {}, {}
	local source = (type(orderList) == "table" and #orderList > 0) and orderList or WMDefaultOrder
	for _, raw in ipairs(source) do
		local key = normalize(raw)
		if WMCells[key] and not seen[key] then
			seen[key] = true
			table.insert(order, key)
		end
	end
	for _, key in ipairs(WMDefaultOrder) do
		if not seen[key] then table.insert(order, key) end
	end
	local shown = {}
	for i, key in ipairs(order) do
		local cell = WMCells[key]
		local hidden = WMShowMap[key] == false or (key == "brand" and WMShowMap.logo == false)
		cell.Visible = not hidden
		cell.LayoutOrder = i * 2
		if not hidden then table.insert(shown, { key = key, index = i }) end
	end
	-- No dividers: Neverlose separates the stats with spacing only.
	for _, divider in pairs(WMDividers) do divider.Visible = false end
	GameInfo.Visible = #shown > 0 and not WindowObj._loaderActive
	if WindowObj._wmRelayout then WindowObj._wmRelayout() end
	if WMShadowSync then WMShadowSync() end
end
ApplyWatermarkLayout(nil, nil)

-- (WMShadowSync local declaration removed here — moved above ApplyWatermarkLayout)
do
	local WMShadowHost = Instance.new("Frame")
	WMShadowHost.Name = "WMShadow"
	WMShadowHost.AnchorPoint = Vector2.new(1, 0)
	WMShadowHost.Position = UDim2.new(1, -6, 0, 2)
	WMShadowHost.Size = UDim2.fromOffset(10, 36)
	WMShadowHost.BackgroundTransparency = 1
	WMShadowHost.BorderSizePixel = 0
	WMShadowHost.ZIndex = Z_BASE + 899
	WMShadowHost.Parent = NeverloseCS2

	-- Watermark shadow on the sibling host (the strip itself owns a list
	-- layout, which would swallow the layers): the melting capsule edge.
	local layers = {}
	WindowObj._edgeShadow(WMShadowHost, Z_BASE + 898)

	WMShadowSync = function()
		local w, h = GameInfo.AbsoluteSize.X, GameInfo.AbsoluteSize.Y
		-- Keep the sibling shadow attached to the watermark for every position preset.
		WMShadowHost.AnchorPoint = GameInfo.AnchorPoint
		WMShadowHost.Position = GameInfo.Position
		WMShadowHost.Visible = GameInfo.Visible and w > 0 and h > 0
		if not WMShadowHost.Visible then return end
		WMShadowHost.Size = UDim2.fromOffset(w, h)
		for i, layer in ipairs(layers) do
			local s = i * 0.65
			-- Minimal near-field shade; keep the watermark crisp without a detached halo.
			layer.Position = UDim2.new(0, -s, 0, 1 - s)
			layer.Size = UDim2.new(1, s * 2, 1, s * 2 + 2)
		end
	end
	GameInfo:GetPropertyChangedSignal("AbsoluteSize"):Connect(WMShadowSync)
	GameInfo:GetPropertyChangedSignal("Visible"):Connect(WMShadowSync)
	GameInfo:GetPropertyChangedSignal("Position"):Connect(WMShadowSync)
	GameInfo:GetPropertyChangedSignal("AnchorPoint"):Connect(WMShadowSync)
	task.defer(WMShadowSync)
end

-- Watermark items, settings and reordering (Neverlose): right-click the strip
-- while the menu is open for its settings (Items, Additional Colors, Display
-- Avatar, Position); Items picks what the strip shows; dragging an item along
-- the strip (the NL logo too) reorders it, dragging the strip's ends moves it.
-- Built inside a function so its locals live in their own register frame
-- (AddWindow is close to Luau's register limit).
WindowObj._buildWatermarkUI = function()
	local ICON = {
		logo = "rbxassetid://10723407092", kd = "rbxassetid://10709818534", speed = "rbxassetid://10723395708",
		fps = "rbxassetid://10734896881", gpu = "rbxassetid://10723424505", cpu = "rbxassetid://10709813383",
		cpufreq = "rbxassetid://10709752035", ram = "rbxassetid://10709770317", latency = "rbxassetid://10734961133",
		ping = "rbxassetid://10734949856", loss = "rbxassetid://10747382268", issues = "rbxassetid://10709753149",
		server = "rbxassetid://10723404337", preset = "rbxassetid://10723387563", name = "rbxassetid://10747373176",
		time = "rbxassetid://10709805144",
	}
	local LAVENDER, SALMON = Color3.fromRGB(150, 164, 255), Color3.fromRGB(225, 165, 135)

	-- New stat cells (hidden until picked in Items).
	local extra = {}
	for _, def in ipairs({
		{ "kd", "KD", "0.00 KD" }, { "gpu", "GPU", "0% GPU" }, { "cpu", "CPU", "0% CPU" },
		{ "cpufreq", "CPUFreq", "0 HZ" }, { "latency", "Latency", "0 MS" }, { "loss", "Loss", "0% LOSS" },
		{ "issues", "Issues", "LAG" }, { "server", "Server", "LOCAL" }, { "preset", "Preset", "Default" },
	}) do
		local cell, icon, text = WMCell(def[2], 20, ICON[def[1]], def[3])
		icon.ImageColor3 = LAVENDER
		extra[def[1]] = { cell = cell, icon = icon, text = text }
		WMCells[def[1]] = cell
		table.insert(WMDefaultOrder, def[1])
		WMShowMap[def[1]] = false
	end
	extra.issues.icon.ImageColor3 = SALMON
	extra.issues.text.TextColor3 = SALMON
	extra.latency.icon.ImageColor3 = SALMON
	extra.latency.text.TextColor3 = SALMON

	-- Manual row layout: visible items left to right by LayoutOrder, each
	-- gliding to its slot (reorders, items shown/hidden, numbers changing
	-- width); an item that just appeared starts in place. The strip's width
	-- follows. 14 + 5 = the strip's UIPadding.
	local GLIDE = TweenInfo.new(0.25, Enum.EasingStyle.Quint, Enum.EasingDirection.Out)
	WindowObj._wmRelayout = function()
		local keys = {}
		for key, cell in pairs(WMCells) do
			if cell.Visible then table.insert(keys, key) else cell:SetAttribute("Placed", false) end
		end
		table.sort(keys, function(a, b) return WMCells[a].LayoutOrder < WMCells[b].LayoutOrder end)
		local x = 0
		for _, key in ipairs(keys) do
			local cell = WMCells[key]
			local slot = UDim2.fromOffset(x, 0)
			if cell:GetAttribute("Placed") and GameInfo.Visible then
				if cell.Position ~= slot then TweenService:Create(cell, GLIDE, { Position = slot }):Play() end
			else
				cell.Position = slot
				cell:SetAttribute("Placed", true)
			end
			x = x + cell.AbsoluteSize.X
		end
		local size = UDim2.fromOffset(x + 14 + 5, 35)
		if GameInfo.Visible and GameInfo.Size ~= size and GameInfo.AbsoluteSize.X > 0 then
			TweenService:Create(GameInfo, GLIDE, { Size = size }):Play()
		else
			GameInfo.Size = size
		end
	end
	for _, cell in pairs(WMCells) do
		cell:GetPropertyChangedSignal("AbsoluteSize"):Connect(function() WindowObj._wmRelayout() end)
	end
	do
		local jobId = tostring(game.JobId or "")
		extra.server.text.Text = jobId ~= "" and string.upper(string.sub(jobId, 1, 8)) or "LOCAL"
	end
	ApplyWatermarkLayout(nil, nil)

	-- Called once a second from the stats loop with the current frame rate.
	WindowObj._wmUpdateExtra = function(fps)
		local function stat(name)
			local ok, v = pcall(function() return Stats[name] end)
			if not ok or type(v) ~= "number" then return nil end
			return v < 0.5 and v * 1000 or v -- seconds or milliseconds
		end
		local frameMs = (fps and fps > 0) and (1000 / fps) or 16.7
		local gpuMs, cpuMs = stat("RenderGPUFrameTime"), stat("RenderCPUFrameTime")
		extra.gpu.text.Text = (gpuMs and math.clamp(math.floor(gpuMs / frameMs * 100 + 0.5), 0, 100) or 0) .. "% GPU"
		extra.cpu.text.Text = (cpuMs and math.clamp(math.floor(cpuMs / frameMs * 100 + 0.5), 0, 100) or 0) .. "% CPU"
		local okHz, hz = pcall(function() return workspace:GetRealPhysicsFPS() end)
		extra.cpufreq.text.Text = (okHz and math.floor(hz + 0.5) or 0) .. " HZ"
		local ping = WindowObj._lastPing or 0
		extra.latency.text.Text = tostring(ping) .. " MS"
		local stats = LocalPlayer:FindFirstChild("leaderstats")
		local kills = stats and (stats:FindFirstChild("Kills") or stats:FindFirstChild("K"))
		local deaths = stats and (stats:FindFirstChild("Deaths") or stats:FindFirstChild("D"))
		local k, d = kills and tonumber(kills.Value) or 0, deaths and tonumber(deaths.Value) or 0
		extra.kd.text.Text = string.format("%.2f KD", d > 0 and k / d or k)
		-- Roblox exposes no packet loss; a "Packet Loss" stat is read when present.
		local loss = 0
		pcall(function()
			local item = Stats.Network.ServerStatsItem["Packet Loss"]
			if item then loss = math.floor(item:GetValue() + 0.5) end
		end)
		extra.loss.text.Text = tostring(loss) .. "% LOSS"
		extra.preset.text.Text = tostring(WindowObj._activePresetName or "Default")
		-- Connectivity Issues shows only while the connection is bad.
		local hist, spread = WindowObj._pingHistory, 0
		if hist and #hist > 1 then
			local lo, hi = math.huge, -math.huge
			for _, v in ipairs(hist) do lo = math.min(lo, v); hi = math.max(hi, v) end
			spread = hi - lo
		end
		extra.issues.cell.Visible = WMShowMap.issues == true and GameInfo.Visible and (ping > 200 or spread > 80 or loss > 2)
	end

	-- ---------------------------------------------------------------- items
	local ITEMS = {
		{ "logo", "Logo" }, { "kd", "KD Ratio" }, { "speed", "Speed" }, { "fps", "Framerate" }, { "gpu", "GPU Load" },
		{ "cpu", "CPU Load" }, { "cpufreq", "CPU Frequency" }, { "ram", "Memory Load" }, { "latency", "Latency" },
		{ "ping", "Var" }, { "loss", "Loss" }, { "issues", "Connectivity Issues" }, { "server", "Server Address" },
		{ "preset", "Preset" }, { "name", "Username" }, { "time", "Time" },
	}
	local TEXT, MUTED = Color3.fromRGB(235, 236, 241), Color3.fromRGB(150, 152, 162)
	local settingsFrame, itemsFrame, colorSwatch, avatarSwitch, positionFrame, positionValue
	-- Position presets. The ScreenGui keeps Roblox's top-bar inset, so top
	-- presets subtract it: the strip sits 8px under the real screen edge.
	local PRESETS = { "Top Right", "Top Center", "Top Left", "Bottom Right", "Bottom Center", "Bottom Left", "Custom" }
	local function topInset()
		local ok, inset = pcall(function() return game:GetService("GuiService"):GetGuiInset() end)
		WindowObj._topInset = ok and inset and inset.Y or 0
		return WindowObj._topInset
	end
	WindowObj._wmPlace = function(name)
		local top = 8 - topInset()
		local spots = {
			["Top Right"] = { Vector2.new(1, 0), UDim2.new(1, -8, 0, top) },
			["Top Center"] = { Vector2.new(0.5, 0), UDim2.new(0.5, 0, 0, top) },
			["Top Left"] = { Vector2.new(0, 0), UDim2.new(0, 8, 0, top) },
			["Bottom Right"] = { Vector2.new(1, 1), UDim2.new(1, -8, 1, -8) },
			["Bottom Center"] = { Vector2.new(0.5, 1), UDim2.new(0.5, 0, 1, -8) },
			["Bottom Left"] = { Vector2.new(0, 1), UDim2.new(0, 8, 1, -8) },
		}
		-- Custom: the last dragged place (or stay put); dragging sets it.
		if name == "Custom" then
			local saved = WindowObj._wmCustom
			if saved then
				GameInfo.AnchorPoint = saved[1]
				GameInfo.Position = saved[2]
			end
			GameInfo:SetAttribute("Dragged", true)
			GameInfo:SetAttribute("Preset", "Custom")
			if positionValue then positionValue.Text = "Custom" end
			return
		end
		local spot = spots[name]
		if not spot then return end
		GameInfo.AnchorPoint = spot[1]
		GameInfo.Position = spot[2]
		GameInfo:SetAttribute("Dragged", false)
		GameInfo:SetAttribute("Preset", name)
		if positionValue then positionValue.Text = name end
	end
	WindowObj._wmPlace("Top Right")
	local wmColor = LAVENDER

	local function paintIcons(color)
		wmColor = color
		for key, cell in pairs(WMCells) do
			if key ~= "brand" and key ~= "user" and key ~= "issues" and key ~= "latency" and key ~= "ping" then
				for _, child in ipairs(cell:GetChildren()) do
					if child:IsA("ImageLabel") then child.ImageColor3 = color end
				end
			end
		end
		if colorSwatch then colorSwatch.BackgroundColor3 = color end
	end

	local function plate(name, w, h)
		local f = New("Frame", {
			Name = name, Size = UDim2.fromOffset(w, h), BackgroundColor3 = Color3.fromRGB(24, 25, 33),
			BorderSizePixel = 0, Visible = false, ZIndex = 9000, ClipsDescendants = false,
		}, MainFrame)
		New("UICorner", { CornerRadius = UDim.new(0, 10) }, f)
		Stroke(f)
		if WindowObj._attachShadow then WindowObj._attachShadow(f, { radius = 10, layers = 5, step = 1.6, bias = 3 }) end
		return f
	end
	local function closeFrame(frame)
		if not frame or not frame.Visible then return end
		UnregisterPopup(frame)
		SmoothClose(frame, 0.14)
	end
	local function openFrame(frame, x, y, trigger, closeFn, free)
		ApplyZIndexLadder(frame, NextPopupZ())
		SmoothOpen(frame, 0, 0.2)
		MovePopupToAbsolute(frame, x, y)
		-- free: placed exactly (the settings plate hugs the strip); the
		-- screen clamp pushed it down by the top-bar inset.
		if not free then ConstrainPopupToMainFrame(frame, 8) end
		local settled = frame.Position
		frame.Position = UDim2.new(settled.X.Scale, settled.X.Offset, settled.Y.Scale, settled.Y.Offset - 8)
		TweenService:Create(frame, TweenInfo.new(0.24, Enum.EasingStyle.Quint, Enum.EasingDirection.Out), { Position = settled }):Play()
		RegisterPopup(frame, closeFn, trigger)
	end

	local function setSwitch(track, on)
		Tween(track, { BackgroundColor3 = on and mainColor or Color3.fromRGB(8, 10, 16) }, 0.15)
		local knob = track:FindFirstChild("Knob")
		if knob then
			Tween(knob, {
				Position = on and UDim2.fromOffset(16, 2) or UDim2.fromOffset(2, 2),
				BackgroundColor3 = on and Color3.fromRGB(255, 255, 255) or Color3.fromRGB(139, 145, 157),
			}, 0.15, Enum.EasingStyle.Quint, Enum.EasingDirection.Out)
		end
	end

	local function buildItems()
		itemsFrame = plate("WatermarkItems", 180, 8 + #ITEMS * 22)
		local list = New("Frame", { Name = "List", Size = UDim2.fromScale(1, 1), BackgroundTransparency = 1, ZIndex = 9001 }, itemsFrame)
		New("UIPadding", { PaddingTop = UDim.new(0, 4), PaddingLeft = UDim.new(0, 4), PaddingRight = UDim.new(0, 4) }, list)
		New("UIListLayout", { SortOrder = Enum.SortOrder.LayoutOrder }, list)
		for i, item in ipairs(ITEMS) do
			local key, label = item[1], item[2]
			local row = New("TextButton", {
				Name = "Item_" .. key, LayoutOrder = i, Size = UDim2.new(1, 0, 0, 22), BackgroundColor3 = Color3.fromRGB(255, 255, 255),
				BackgroundTransparency = 1, AutoButtonColor = false, Text = "", ZIndex = 9002,
			}, list)
			New("UICorner", { CornerRadius = UDim.new(0, 5) }, row)
			local check = New("ImageLabel", {
				Name = "Check", AnchorPoint = Vector2.new(0, 0.5), Position = UDim2.new(0, 6, 0.5, 0), Size = UDim2.fromOffset(12, 12),
				BackgroundTransparency = 1, Image = "rbxassetid://10709790644", ImageColor3 = TEXT, ZIndex = 9003,
			}, row)
			New("ImageLabel", {
				Name = "Icon", AnchorPoint = Vector2.new(0, 0.5), Position = UDim2.new(0, 24, 0.5, 0), Size = UDim2.fromOffset(13, 13),
				BackgroundTransparency = 1, Image = ICON[key], ImageColor3 = MUTED, ZIndex = 9003,
			}, row)
			local text = New("TextLabel", {
				Name = "Label", Position = UDim2.fromOffset(44, 0), Size = UDim2.new(1, -48, 1, 0), BackgroundTransparency = 1,
				Text = label, TextColor3 = TEXT, TextSize = 13, Font = FONT, TextXAlignment = Enum.TextXAlignment.Left, ZIndex = 9003,
			}, row)
			local function paint()
				local on = WMShowMap[key] == true
				check.Visible = on
				text.TextColor3 = on and TEXT or MUTED
			end
			paint()
			row.MouseEnter:Connect(function() Tween(row, { BackgroundTransparency = 0.97 }, 0.08) end)
			row.MouseLeave:Connect(function() Tween(row, { BackgroundTransparency = 1 }, 0.12) end)
			row.MouseButton1Click:Connect(function()
				WMShowMap[key] = not (WMShowMap[key] == true)
				ApplyWatermarkLayout(nil, nil)
				paint()
			end)
		end
	end

	local function buildSettings()
		settingsFrame = plate("WatermarkSettings", 230, 36 + 4 * 30 + 8)
		New("TextLabel", {
			Name = "Title", Position = UDim2.fromOffset(14, 6), Size = UDim2.new(1, -28, 0, 26), BackgroundTransparency = 1,
			Text = "Watermark", TextColor3 = TEXT, TextSize = 14, Font = FONT, TextXAlignment = Enum.TextXAlignment.Left, ZIndex = 9001,
		}, settingsFrame)
		New("Frame", {
			Name = "TitleRule", Position = UDim2.fromOffset(10, 34), Size = UDim2.new(1, -20, 0, 1), BackgroundColor3 = Color3.fromRGB(255, 255, 255),
			BackgroundTransparency = 0.93, BorderSizePixel = 0, ZIndex = 9001,
		}, settingsFrame)
		local function row(order, icon, label)
			local r = New("TextButton", {
				Name = "Row" .. order, Position = UDim2.fromOffset(6, 38 + (order - 1) * 30), Size = UDim2.new(1, -12, 0, 30),
				BackgroundColor3 = Color3.fromRGB(255, 255, 255), BackgroundTransparency = 1, AutoButtonColor = false, Text = "", ZIndex = 9001,
			}, settingsFrame)
			New("UICorner", { CornerRadius = UDim.new(0, 6) }, r)
			New("ImageLabel", {
				Name = "Icon", AnchorPoint = Vector2.new(0, 0.5), Position = UDim2.new(0, 8, 0.5, 0), Size = UDim2.fromOffset(14, 14),
				BackgroundTransparency = 1, Image = icon, ImageColor3 = Color3.fromRGB(200, 201, 210), ZIndex = 9002,
			}, r)
			New("TextLabel", {
				Name = "Label", Position = UDim2.fromOffset(32, 0), Size = UDim2.new(0.6, -32, 1, 0), BackgroundTransparency = 1,
				Text = label, TextColor3 = TEXT, TextSize = 13, Font = FONT, TextXAlignment = Enum.TextXAlignment.Left, ZIndex = 9002,
			}, r)
			r.MouseEnter:Connect(function() Tween(r, { BackgroundTransparency = 0.97 }, 0.08) end)
			r.MouseLeave:Connect(function() Tween(r, { BackgroundTransparency = 1 }, 0.12) end)
			return r
		end

		local itemsRow = row(1, "rbxassetid://10723433811", "Items")
		New("TextLabel", {
			Name = "Value", AnchorPoint = Vector2.new(1, 0.5), Position = UDim2.new(1, -24, 0.5, 0), Size = UDim2.fromOffset(60, 20),
			BackgroundTransparency = 1, Text = "Select", TextColor3 = MUTED, TextSize = 13, Font = FONT,
			TextXAlignment = Enum.TextXAlignment.Right, ZIndex = 9002,
		}, itemsRow)
		New("ImageLabel", {
			Name = "Chevron", AnchorPoint = Vector2.new(1, 0.5), Position = UDim2.new(1, -8, 0.5, 0), Size = UDim2.fromOffset(12, 12),
			BackgroundTransparency = 1, Image = "rbxassetid://10709791437", ImageColor3 = MUTED, ZIndex = 9002,
		}, itemsRow)
		itemsRow.MouseButton1Click:Connect(function()
			if not itemsFrame then buildItems() end
			if itemsFrame.Visible then closeFrame(itemsFrame) return end
			openFrame(itemsFrame, settingsFrame.AbsolutePosition.X + settingsFrame.AbsoluteSize.X + 6, itemsRow.AbsolutePosition.Y - 4,
				itemsRow, function() closeFrame(itemsFrame) end)
		end)

		local colorRow = row(2, "rbxassetid://10734910430", "Additional Colors")
		colorSwatch = New("TextButton", {
			Name = "ColorSwatch", AnchorPoint = Vector2.new(1, 0.5), Position = UDim2.new(1, -8, 0.5, 0), Size = UDim2.fromOffset(16, 16),
			BackgroundColor3 = wmColor, Text = "", AutoButtonColor = false, ZIndex = 9003,
		}, colorRow)
		New("UICorner", { CornerRadius = UDim.new(0, 4) }, colorSwatch)
		if AcrylicBlur and AcrylicBlur.CreateColorPicker then
			AcrylicBlur.CreateColorPicker(colorSwatch, wmColor, function(c) paintIcons(c) end)
		end

		local avatarRow = row(3, "rbxassetid://10747373176", "Display Avatar")
		avatarSwitch = New("Frame", {
			Name = "Switch", AnchorPoint = Vector2.new(1, 0.5), Position = UDim2.new(1, -8, 0.5, 0), Size = UDim2.fromOffset(32, 18),
			BackgroundColor3 = Color3.fromRGB(8, 10, 16), BorderSizePixel = 0, ZIndex = 9002,
		}, avatarRow)
		New("UICorner", { CornerRadius = UDim.new(1, 0) }, avatarSwitch)
		local knob = New("Frame", {
			Name = "Knob", Position = UDim2.fromOffset(2, 2), Size = UDim2.fromOffset(14, 14),
			BackgroundColor3 = Color3.fromRGB(139, 145, 157), BorderSizePixel = 0, ZIndex = 9003,
		}, avatarSwitch)
		New("UICorner", { CornerRadius = UDim.new(1, 0) }, knob)
		setSwitch(avatarSwitch, WMShowMap.user == true)
		avatarRow.MouseButton1Click:Connect(function()
			WMShowMap.user = not (WMShowMap.user == true)
			ApplyWatermarkLayout(nil, nil)
			setSwitch(avatarSwitch, WMShowMap.user)
		end)

		local positionRow = row(4, "rbxassetid://10734900011", "Position")
		positionValue = New("TextLabel", {
			Name = "Value", AnchorPoint = Vector2.new(1, 0.5), Position = UDim2.new(1, -24, 0.5, 0), Size = UDim2.fromOffset(100, 20),
			BackgroundTransparency = 1, Text = GameInfo:GetAttribute("Preset") or "Custom", TextColor3 = MUTED, TextSize = 13, Font = FONT,
			TextXAlignment = Enum.TextXAlignment.Right, ZIndex = 9002,
		}, positionRow)
		New("ImageLabel", {
			Name = "Chevron", AnchorPoint = Vector2.new(1, 0.5), Position = UDim2.new(1, -8, 0.5, 0), Size = UDim2.fromOffset(12, 12),
			BackgroundTransparency = 1, Image = "rbxassetid://10709791437", ImageColor3 = MUTED, ZIndex = 9002,
		}, positionRow)
		positionRow.MouseButton1Click:Connect(function()
			if not positionFrame then
				positionFrame = plate("WatermarkPositions", 150, 8 + #PRESETS * 24)
				local list = New("Frame", { Name = "List", Size = UDim2.fromScale(1, 1), BackgroundTransparency = 1, ZIndex = 9001 }, positionFrame)
				New("UIPadding", { PaddingTop = UDim.new(0, 4), PaddingLeft = UDim.new(0, 4), PaddingRight = UDim.new(0, 4) }, list)
				New("UIListLayout", { SortOrder = Enum.SortOrder.LayoutOrder }, list)
				for i, name in ipairs(PRESETS) do
					local item = New("TextButton", {
						Name = "Preset_" .. i, LayoutOrder = i, Size = UDim2.new(1, 0, 0, 24), BackgroundColor3 = Color3.fromRGB(255, 255, 255),
						BackgroundTransparency = 1, AutoButtonColor = false, Text = name, TextColor3 = TEXT, TextSize = 13, Font = FONT,
						TextXAlignment = Enum.TextXAlignment.Left, ZIndex = 9002,
					}, list)
					New("UICorner", { CornerRadius = UDim.new(0, 5) }, item)
					New("UIPadding", { PaddingLeft = UDim.new(0, 10) }, item)
					item.MouseEnter:Connect(function() Tween(item, { BackgroundTransparency = 0.97 }, 0.08) end)
					item.MouseLeave:Connect(function() Tween(item, { BackgroundTransparency = 1 }, 0.12) end)
					item.MouseButton1Click:Connect(function()
						WindowObj._wmPlace(name)
						closeFrame(positionFrame)
					end)
				end
			end
			if positionFrame.Visible then closeFrame(positionFrame) return end
			openFrame(positionFrame, settingsFrame.AbsolutePosition.X + settingsFrame.AbsoluteSize.X + 6, positionRow.AbsolutePosition.Y - 4,
				positionRow, function() closeFrame(positionFrame) end)
		end)
	end

	local function openSettings(point)
		if not settingsFrame then buildSettings() end
		if settingsFrame.Visible then closeFrame(settingsFrame) return end
		setSwitch(avatarSwitch, WMShowMap.user == true)
		if positionValue then positionValue.Text = GameInfo:GetAttribute("Preset") or "Custom" end
		-- Opens under the strip at the click's x (kept on screen), sliding down.
		-- Below the strip, or above it when the strip sits in the lower half.
		local gui = GameInfo.Parent
		local low = gui and gui.AbsoluteSize.Y > 0 and GameInfo.AbsolutePosition.Y > gui.AbsoluteSize.Y / 2
		local y = low and (GameInfo.AbsolutePosition.Y - settingsFrame.AbsoluteSize.Y - 4) or (GameInfo.AbsolutePosition.Y + GameInfo.AbsoluteSize.Y + 4)
		openFrame(settingsFrame, point.X - 20, y, GameInfo, function()
				if itemsFrame then closeFrame(itemsFrame) end
				if positionFrame then closeFrame(positionFrame) end
				closeFrame(settingsFrame)
			end, true)
	end

	-- ------------------------------------------------- click / drag / reorder
	local drag
	local function cellAt(point)
		for key, cell in pairs(WMCells) do
			if cell.Visible and IsPointInside(cell, point) then return key end
		end
		return nil
	end
	local function currentOrder()
		local keys = {}
		for key in pairs(WMCells) do table.insert(keys, key) end
		table.sort(keys, function(a, b) return WMCells[a].LayoutOrder < WMCells[b].LayoutOrder end)
		return keys
	end
	local function reorder(key, x)
		local order = currentOrder()
		for i, k in ipairs(order) do if k == key then table.remove(order, i) break end end
		local index = 1
		for i, k in ipairs(order) do
			local cell = WMCells[k]
			if cell.Visible and x > cell.AbsolutePosition.X + cell.AbsoluteSize.X / 2 then index = i + 1 end
		end
		table.insert(order, index, key)
		ApplyWatermarkLayout(order, nil)
	end
	GameInfo.InputBegan:Connect(function(input)
		if not MainFrame.Visible then return end
		if input.UserInputType == Enum.UserInputType.MouseButton2 then
			openSettings(input.Position)
			return
		end
		if input.UserInputType ~= Enum.UserInputType.MouseButton1 and input.UserInputType ~= Enum.UserInputType.Touch then return end
		drag = { point = input.Position, pos = GameInfo.Position, key = cellAt(input.Position), moved = false }
	end)
	UserInputService.InputChanged:Connect(function(input)
		if not drag then return end
		if input.UserInputType ~= Enum.UserInputType.MouseMovement and input.UserInputType ~= Enum.UserInputType.Touch then return end
		local d = input.Position - drag.point
		if not drag.moved and d.Magnitude < 5 then return end
		drag.moved = true
		if drag.key then
			reorder(drag.key, input.Position.X)
		else
			GameInfo.Position = UDim2.new(drag.pos.X.Scale, drag.pos.X.Offset + d.X, drag.pos.Y.Scale, drag.pos.Y.Offset + d.Y)
			GameInfo:SetAttribute("Dragged", true)
			GameInfo:SetAttribute("Preset", "Custom")
			WindowObj._wmCustom = { GameInfo.AnchorPoint, GameInfo.Position }
		end
	end)
	UserInputService.InputEnded:Connect(function(input)
		if input.UserInputType ~= Enum.UserInputType.MouseButton1 and input.UserInputType ~= Enum.UserInputType.Touch then return end
		drag = nil
	end)

	-- Config: position (when moved), item order and visibility, icon colour.
	WindowObj._configExtras.pos_watermark = {
		get = function()
			local preset = GameInfo:GetAttribute("Preset")
			if preset and preset ~= "Custom" then return { preset = preset } end
			if not GameInfo:GetAttribute("Dragged") then return nil end
			local p, a = GameInfo.Position, GameInfo.AnchorPoint
			return { p.X.Scale, p.X.Offset, p.Y.Scale, p.Y.Offset, a.X, a.Y }
		end,
		set = function(v)
			if type(v) ~= "table" then return end
			if type(v.preset) == "string" then WindowObj._wmPlace(v.preset) return end
			if type(v[4]) ~= "number" then return end
			if type(v[6]) == "number" then GameInfo.AnchorPoint = Vector2.new(v[5], v[6]) end
			GameInfo.Position = UDim2.new(v[1], v[2], v[3], v[4])
			GameInfo:SetAttribute("Dragged", true)
			GameInfo:SetAttribute("Preset", "Custom")
			WindowObj._wmCustom = { GameInfo.AnchorPoint, GameInfo.Position }
		end,
	}
	WindowObj._configExtras.watermark = {
		get = function()
			local show = {}
			for k, v in pairs(WMShowMap) do show[k] = v == true end
			return { order = currentOrder(), show = show, color = { wmColor.R, wmColor.G, wmColor.B } }
		end,
		set = function(v)
			if type(v) ~= "table" then return end
			if type(v.show) == "table" then
				for k, on in pairs(v.show) do if WMShowMap[k] ~= nil then WMShowMap[k] = on == true end end
			end
			ApplyWatermarkLayout(type(v.order) == "table" and v.order or nil, nil)
			if type(v.color) == "table" and #v.color == 3 then paintIcons(Color3.new(v.color[1], v.color[2], v.color[3])) end
		end,
	}
	paintIcons(wmColor)
end
WindowObj._buildWatermarkUI()

WindowObj.Watermark = {
	frame = GameInfo,
	logo = NeverIcon,
	user = Username,
	avatar = UserIcon,
	fps = FPSText,
	time = TimeText,
	ping = MSText,
	ram = RamText,
	speed = WindowObj._wmSpeedText,
	icons = { NeverIcon, UserIcon, WindowObj._wmSpeed.icon, FpsCellIcon, SignalImage, RamCellIcon, TimeCellIcon },
	cells = WMCells,
	applyLayout = ApplyWatermarkLayout,
	isShown = function(key)
		key = key == "logo" and "logo" or key
		return WMShowMap[key] == true
	end,
	toggle = function(key, on)
		WMShowMap[key] = on == true
		ApplyWatermarkLayout(nil, nil)
	end,
}
end

function WindowObj:SetWatermark(options)
	local wm = WindowObj.Watermark
	if type(options) ~= "table" then return wm end
	if type(options.positionPreset) == "string" and WindowObj._wmPlace then
		WindowObj._wmPlace(options.positionPreset)
	elseif options.position then
		-- Preserve the current anchor when callers only change Position.
		-- Resetting it to (0, 0) here made top/right presets jump unexpectedly.
		if options.anchorPoint then
			wm.frame.AnchorPoint = options.anchorPoint
		end
		wm.frame.Position = options.position
	end
	if options.background then wm.frame.BackgroundColor3 = options.background end
	if type(options.backgroundTransparency) == "number" then
		wm.frame.BackgroundTransparency = options.backgroundTransparency
	end
	-- cornerRadius is ignored: the Neverlose strip is always a full capsule
	-- (old scripts passed 5 or 8 and squared its ends).
	if type(options.title) == "string" and wm.title then
		wm.title.Text = options.title
	end
	local keys = { "user", "speed", "fps", "ping", "ram", "time" }
	if type(options.textSize) == "number" then
		for _, key in ipairs(keys) do
			if wm[key] then wm[key].TextSize = options.textSize end
		end
	end
	if options.accent and typeof(options.accent) == "Color3" then
		for _, icon in ipairs(wm.icons) do
			if icon and icon:IsA("ImageLabel") and icon ~= wm.logo and icon ~= wm.avatar then
				icon.ImageColor3 = options.accent
				icon.ImageTransparency = 0.15
			end
		end
	end
	if type(options.show) == "table" or type(options.order) == "table" then
		wm.applyLayout(options.order, options.show)
	end
	return wm
end

local _smoothTextBaseTransparency = setmetatable({}, { __mode = "k" })

local function setTextSmooth(label, newText)
    if not label or not label.Parent then return end
    newText = tostring(newText or "")
    if label:GetAttribute("shownText") == newText then return end

    -- Keep each label's authored opacity. A hard-coded 0.15 made watermark
    -- values gradually settle to a different opacity than their initial style.
    if _smoothTextBaseTransparency[label] == nil then
        _smoothTextBaseTransparency[label] = label.TextTransparency
    end
    local targetTransparency = _smoothTextBaseTransparency[label]

    label:SetAttribute("shownText", newText)
    local token = (label:GetAttribute("SmoothTextToken") or 0) + 1
    label:SetAttribute("SmoothTextToken", token)

    -- The shared tween manager cancels overlapping fades on the same property.
    local fadeOut = Tween(label, {
        TextTransparency = math.max(targetTransparency, 0.82),
    }, 0.085, Enum.EasingStyle.Sine, Enum.EasingDirection.Out)

    if not fadeOut then
        label.Text = newText
        label.TextTransparency = targetTransparency
        return
    end

    fadeOut.Completed:Connect(function(playbackState)
        if playbackState ~= Enum.PlaybackState.Completed then return end
        if not label.Parent or label:GetAttribute("SmoothTextToken") ~= token then return end
        label.Text = newText
        Tween(label, {
            TextTransparency = targetTransparency,
        }, 0.12, Enum.EasingStyle.Sine, Enum.EasingDirection.Out)
    end)
end

-- (duplicate setTextSmooth removed)

local fpsBuffer = {}
local clockAcc = 0
local statAcc = 0
local lastFps
local lastMs
RunService.RenderStepped:Connect(function(dt)
if type(dt) ~= "number" or dt <= 0 then return end
table.insert(fpsBuffer, dt)
if #fpsBuffer > 20 then table.remove(fpsBuffer, 1) end
clockAcc = clockAcc + dt
if clockAcc >= 1 then
clockAcc = 0
setTextSmooth(TimeText, os.date("%H:%M"))
end
-- Horizontal speed of the local character (studs/s), a few times a second.
WindowObj._wmSpeedAcc = (WindowObj._wmSpeedAcc or 0) + dt
if WindowObj._wmSpeedAcc >= 0.2 and WindowObj._wmSpeedText then
WindowObj._wmSpeedAcc = 0
local char = LocalPlayer.Character
local root = char and char:FindFirstChild("HumanoidRootPart")
local speed = 0
if root then
local v = root.AssemblyLinearVelocity
speed = math.floor(Vector3.new(v.X, 0, v.Z).Magnitude + 0.5)
end
WindowObj._wmSpeedText.Text = tostring(speed) .. " SPEED"
end
statAcc = statAcc + dt
if statAcc < 1 then return end
statAcc = 0
local avg = 0
for _, v in ipairs(fpsBuffer) do avg = avg + v end
if avg > 0 then
local fps = math.round(#fpsBuffer / avg)
if fps ~= lastFps then
lastFps = fps
setTextSmooth(FPSText, tostring(fps) .. " FPS")
end
end
if WindowObj._wmUpdateExtra then pcall(WindowObj._wmUpdateExtra, lastFps) end
local ping = Stats and Stats.Network and Stats.Network.ServerStatsItem and Stats.Network.ServerStatsItem["Data Ping"]
if ping then
local ok, value = pcall(function() return ping:GetValue() end)
if ok and type(value) == "number" then
local ms = math.round(value)
lastMs = ms
WindowObj._lastPing = ms
-- Neverlose shows the ping variance: half the spread of recent samples.
local hist = WindowObj._pingHistory or {}
WindowObj._pingHistory = hist
table.insert(hist, ms)
if #hist > 6 then table.remove(hist, 1) end
local lo, hi = math.huge, -math.huge
for _, v in ipairs(hist) do lo = math.min(lo, v); hi = math.max(hi, v) end
setTextSmooth(MSText, "VAR ±" .. tostring(math.floor((hi - lo) / 2 + 0.5)) .. " MS")
end
end
local okMem, memMb = pcall(function() return game:GetTotalMemoryUsageMb() end)
if okMem and type(memMb) == "number" then
setTextSmooth(RamText, tostring(math.floor(memMb)) .. " MB")
end
end)

-- ============================================================================
-- PATCH 2: AttachShadow guards against layout parents
-- ============================================================================
local function AttachShadow(frame, opts)
	WindowObj._attachShadow = WindowObj._attachShadow or AttachShadow
	if not frame or not frame.Parent then return end
	if frame:FindFirstChildWhichIsA("UIListLayout") or frame:FindFirstChildWhichIsA("UIGridLayout") then
		warn("[ui] AttachShadow: " .. frame.Name .. " has a layout, shadow skipped")
		return
	end
	opts = opts or {}
	local layers = math.clamp(opts.layers or 6, 1, 8)
	local step = opts.step or 2.0
	local bias = opts.bias or 2
	local radius = opts.radius or 16
	for i = 1, layers do
		local spread = math.floor(i * step + 0.5)
		-- Keep the inner edge subtle; outer layers fade instead of forming a black halo.
		-- opts.strength sets the innermost alpha (lower = darker), default 0.76.
		local inner = opts.strength or 0.76
		local alpha = math.clamp(inner + (i - 1) * ((0.98 - inner) / math.max(1, layers - 1)), inner, 0.98)
		local shadow = New("Frame", {
			Name = "ShadowLayer" .. i,
			Position = UDim2.new(0, -spread, 0, bias - spread),
			Size = UDim2.new(1, spread * 2, 1, spread * 2),
			BackgroundColor3 = Color3.new(0, 0, 0),
			BackgroundTransparency = alpha,
			BorderSizePixel = 0,
			ZIndex = frame.ZIndex - 1,
		}, frame)
		shadow:SetAttribute("IsShadowLayer", true)
		shadow:SetAttribute("ShadowAlpha", alpha)
		New("UICorner", { CornerRadius = UDim.new(0, radius + spread) }, shadow)
	end
end
AttachShadow(MainFrame, { radius = 20, layers = 6, step = 2.0, bias = 2 })

-- Neverlose option list: 18,18,27 plate with a soft shadow. The plate must not
-- clip (the shadow and the scale-in sit outside it); its list frame clips rows.
WindowObj._styleListPopup = function(popup)
	if popup:GetAttribute("NLListStyled") then return end
	popup:SetAttribute("NLListStyled", true)
	popup.BackgroundColor3 = Color3.fromRGB(18, 18, 27)
	popup.ClipsDescendants = false
	if not popup:FindFirstChildWhichIsA("UIListLayout") then
		AttachShadow(popup, { radius = 10, layers = 5, step = 1.6, bias = 3 })
	end
end

local RefreshKeybindOverlay
do
local ICON_EYE = "rbxassetid://127234874352422"
local ICON_KEYBOARD = "rbxassetid://121978468376124"
local OverlayStack = New("Frame", {
	Name = "OverlayStack",
	AnchorPoint = Vector2.new(1, 0),
	Position = UDim2.new(1, -6, 0, 46),
	Size = UDim2.fromOffset(220, 0),
	AutomaticSize = Enum.AutomaticSize.Y,
	BackgroundTransparency = 1,
	BorderSizePixel = 0,
	Visible = false,
	ZIndex = Z_BASE + 880,
}, NeverloseCS2)
New("UIListLayout", {
	FillDirection = Enum.FillDirection.Vertical,
	HorizontalAlignment = Enum.HorizontalAlignment.Right,
	VerticalAlignment = Enum.VerticalAlignment.Top,
	Padding = UDim.new(0, 8),
	SortOrder = Enum.SortOrder.LayoutOrder,
}, OverlayStack)

-- Neverlose overlay lists (Hotkeys / Spectators) in the menu's own style:
-- solid popup plates (18,18,25 header, 23,23,31 entries), hairline outline,
-- layered shadow. A header (accent glyph | divider | bold title) over compact
-- entry pairs: value or state glyph on the left, name on the right. Entries
-- slide in and out; each list is dragged by its header while the menu is
-- open. Pills keep their resting alpha in "PillAlpha" for the fades.
-- Kept in one table: AddWindow is close to the Luau register limit.
-- Plates use the menu window's own recipe: its glass colour and
-- transparency over an acrylic blur, hairline outline, layered shadow.
-- OV.entry stays the dark knob colour of the switch glyph.
-- The menu reads as two glass layers (window 8,10,17 at 0.25 under the
-- content panel 15,17,24 at 0.5); one plate at their mix looks the same.
local OV = { h = 24, head = 32, header = 0.3, entryAlpha = 0.38, glass = Color3.fromRGB(8, 9, 12), entry = Color3.fromRGB(23, 23, 31) }
function OV.pill(name, parent, alpha, radius, height, flat)
	-- Same capsule as the watermark: nearly clear plate, melting edge shadow,
	-- blur behind. (`radius` only sets how far the blur pulls in.)
	local pill = New("Frame", {
		Name = name, Size = UDim2.fromOffset(height or OV.h, height or OV.h), BackgroundColor3 = OV.glass,
		BackgroundTransparency = alpha, BorderSizePixel = 0, ZIndex = Z_BASE + 891,
	}, parent)
	pill:SetAttribute("PillAlpha", alpha)
	New("UICorner", { CornerRadius = UDim.new(1, 0) }, pill)
	-- flat: entry pills under the header carry no shadow, as on Neverlose.
	if not flat then WindowObj._edgeShadow(pill, Z_BASE + 890) end
	if WindowObj._attachBlur then WindowObj._attachBlur(pill, math.floor(radius * 0.6)) end
	return pill
end

-- The panel is a CanvasGroup: showing/hiding is one GroupTransparency tween,
-- so header, rows, outlines and shadows fade together (and cheaply). A 12px
-- margin (OV.pad) keeps the soft shadows inside the group's clip.
OV.pad = 12
do
	local ok, inset = pcall(function() return game:GetService("GuiService"):GetGuiInset() end)
	OV.inset = ok and inset and inset.Y or 0
end
local function MakeOverlayPanel(name, iconAsset, title)
	local panel = New("CanvasGroup", {
		Name = name,
		AnchorPoint = Vector2.new(1, 0),
		-- Under the watermark (8px from the real top + 35px strip + 10px); the
		-- ScreenGui keeps the top-bar inset, so it is subtracted.
		Position = UDim2.new(1, -8 + OV.pad, 0, 53 - (OV.inset or 0) - OV.pad),
		Size = UDim2.fromOffset(120, OV.head + OV.pad * 2),
		BackgroundTransparency = 1,
		BorderSizePixel = 0,
		GroupTransparency = 1,
		Visible = false,
		ZIndex = Z_BASE + 890,
	}, NeverloseCS2)
	New("UIPadding", { PaddingLeft = UDim.new(0, OV.pad), PaddingRight = UDim.new(0, OV.pad), PaddingTop = UDim.new(0, OV.pad), PaddingBottom = UDim.new(0, OV.pad) }, panel)
	-- 8px under the header: its 5px shadow (1px lower) ends before the rows.
	New("UIListLayout", { FillDirection = Enum.FillDirection.Vertical, HorizontalAlignment = Enum.HorizontalAlignment.Left, Padding = UDim.new(0, 8), SortOrder = Enum.SortOrder.LayoutOrder }, panel)
	New("UIScale", { Name = "PopScale", Scale = 1 }, panel)

	local header = OV.pill("Header", panel, OV.header, 16, OV.head)
	header.LayoutOrder = 1
	header.Active = true
	-- Layout lives in a child so the shadow rings stay free of it.
	local content = New("Frame", { Name = "Content", Size = UDim2.fromScale(1, 1), BackgroundTransparency = 1, ZIndex = Z_BASE + 892 }, header)
	New("UIPadding", { PaddingLeft = UDim.new(0, 14), PaddingRight = UDim.new(0, 14) }, content)
	New("UIListLayout", { FillDirection = Enum.FillDirection.Horizontal, VerticalAlignment = Enum.VerticalAlignment.Center, Padding = UDim.new(0, 8), SortOrder = Enum.SortOrder.LayoutOrder }, content)
	New("ImageLabel", {
		Name = "HeaderIcon", Size = UDim2.fromOffset(15, 15), BackgroundTransparency = 1,
		Image = iconAsset, ImageColor3 = Color3.fromRGB(150, 164, 255), ScaleType = Enum.ScaleType.Fit, LayoutOrder = 1, ZIndex = Z_BASE + 892,
	}, content)
	local divider = New("Frame", {
		Name = "HeaderDivider", Size = UDim2.fromOffset(1, 14), BackgroundColor3 = Color3.fromRGB(255, 255, 255),
		BackgroundTransparency = 0.88, BorderSizePixel = 0, LayoutOrder = 2, ZIndex = Z_BASE + 892,
	}, content)
	divider:SetAttribute("PillAlpha", 0.88)
	New("TextLabel", {
		Name = "HeaderTitle", Size = UDim2.new(0, 0, 1, 0), AutomaticSize = Enum.AutomaticSize.X,
		BackgroundTransparency = 1, Text = title, TextColor3 = Color3.fromRGB(235, 236, 241), TextTransparency = 0,
		TextSize = 14, Font = FONT_BOLD, TextXAlignment = Enum.TextXAlignment.Left, LayoutOrder = 3, ZIndex = Z_BASE + 892,
	}, content)
	local headerW = math.ceil(14 + 15 + 8 + 1 + 8 + MeasureText(title, 14, FONT_BOLD) + 14)
	header.Size = UDim2.fromOffset(headerW, OV.head)
	panel:SetAttribute("HeaderWidth", headerW)
	-- Anchored by the left edge so new rows grow the list to the right instead
	-- of pushing it left; starts so the header ends 8px from the screen edge.
	panel.AnchorPoint = Vector2.new(0, 0)
	panel.Position = UDim2.new(1, -8 + OV.pad - (headerW + OV.pad * 2), panel.Position.Y.Scale, panel.Position.Y.Offset)
	if WindowObj._makeDraggable then WindowObj._makeDraggable(header, panel, name) end

	local rows = New("Frame", {
		Name = "Rows", Size = UDim2.new(1, 0, 0, 0), AutomaticSize = Enum.AutomaticSize.Y,
		BackgroundTransparency = 1, LayoutOrder = 2, ZIndex = Z_BASE + 891,
	}, panel)
	New("UIListLayout", { FillDirection = Enum.FillDirection.Vertical, Padding = UDim.new(0, 4), SortOrder = Enum.SortOrder.LayoutOrder }, rows)
	return panel, rows
end

-- Entry row: icon pill (value text, or a glyph drawn by the caller when
-- leftText is nil) and name pill, sized to their text. iconRight puts the
-- name first and the icon pill after it (hotkeys). Returns row, icon pill.
function OV.row(rows, order, text, leftText, iconRight)
	local leftW = leftText and math.max(OV.h, math.ceil(MeasureText(leftText, 12, FONT) + 14)) or OV.h
	local nameW = math.ceil(MeasureText(text, 12, FONT) + 24)
	local row = New("Frame", {
		Name = "OverlayRow", Size = UDim2.fromOffset(leftW + 4 + nameW, OV.h), BackgroundTransparency = 1,
		LayoutOrder = order, ZIndex = Z_BASE + 891,
	}, rows)
	local leftPill = OV.pill("IconPill", row, OV.entryAlpha, 12, nil, true)
	leftPill.Size = UDim2.fromOffset(leftW, OV.h)
	local iconX, nameX = 0, leftW + 4
	if iconRight then iconX, nameX = nameW + 4, 0 end
	leftPill.Position = UDim2.fromOffset(iconX, 0)
	if leftText then
		New("TextLabel", {
			Name = "EntryValue", Size = UDim2.fromScale(1, 1), BackgroundTransparency = 1, Text = leftText,
			TextColor3 = Color3.fromRGB(235, 236, 241), TextTransparency = 0, TextSize = 12, Font = FONT,
			ZIndex = Z_BASE + 892,
		}, leftPill)
	end
	local namePill = OV.pill("NamePill", row, OV.entryAlpha, 12, nil, true)
	namePill.Position = UDim2.fromOffset(nameX, 0)
	namePill.Size = UDim2.fromOffset(nameW, OV.h)
	New("TextLabel", {
		Name = "EntryName", Position = UDim2.fromOffset(12, 0), Size = UDim2.new(1, -24, 1, 0),
		BackgroundTransparency = 1, Text = text, TextColor3 = Color3.fromRGB(180, 182, 188), TextTransparency = 0,
		TextSize = 12, Font = FONT, TextXAlignment = Enum.TextXAlignment.Left, TextTruncate = Enum.TextTruncate.AtEnd,
		ZIndex = Z_BASE + 892,
	}, namePill)
	row:SetAttribute("NameX", nameX)
	row:SetAttribute("IconX", iconX)
	return row, leftPill
end

-- One easing for every list animation.
OV.ease = TweenInfo.new(0.26, Enum.EasingStyle.Quint, Enum.EasingDirection.Out)
-- Hiding matches the window's 0.2s close, so lists and menu go together.
OV.easeIn = TweenInfo.new(0.2, Enum.EasingStyle.Sine, Enum.EasingDirection.In)
local function FadeOverlayContents(root, show)
	local info = show and OV.ease or OV.easeIn
	local function go(node, props) TweenService:Create(node, info, props):Play() end
	for _, node in ipairs(root:GetDescendants()) do
		if node:IsA("TextLabel") then
			if show then node.TextTransparency = 1 end
			go(node, { TextTransparency = show and 0 or 1 })
		elseif node:IsA("ImageLabel") then
			if show then node.ImageTransparency = 1 end
			go(node, { ImageTransparency = show and (node:GetAttribute("ImageAlpha") or 0) or 1 })
		elseif node:IsA("UIStroke") then
			if show then node.Transparency = 1 end
			go(node, { Transparency = show and (node:GetAttribute("StrokeAlpha") or STROKE.Transparency) or 1 })
		elseif node:IsA("Frame") and node:GetAttribute("PillAlpha") then
			if show then node.BackgroundTransparency = 1 end
			go(node, { BackgroundTransparency = show and node:GetAttribute("PillAlpha") or 1 })
		elseif node:IsA("Frame") and node:GetAttribute("IsShadowLayer") then
			if show then node.BackgroundTransparency = 1 end
			go(node, { BackgroundTransparency = show and (node:GetAttribute("ShadowAlpha") or 0.9) or 1 })
		elseif node:IsA("Frame") and node:GetAttribute("NLOverlayAccentPart") then
			if show then node.BackgroundTransparency = 1 end
			go(node, { BackgroundTransparency = show and 0 or 1 })
		end
	end
end

-- Entry animation: the row opens from 0 to full height (rows below glide
-- instead of jumping) while both pills slide 12px in from the right and
-- fade in; leaving runs the same in reverse, then the row is removed.
function OV.animateRow(row, show, onGone)
	local icon, name = row:FindFirstChild("IconPill"), row:FindFirstChild("NamePill")
	local nameX = row:GetAttribute("NameX") or 0
	local iconX = row:GetAttribute("IconX") or 0
	local width = row.Size.X.Offset
	local info = show and OV.ease or OV.easeIn
	FadeOverlayContents(row, show)
	if show then
		row.Size = UDim2.fromOffset(width, 0)
		if icon then icon.Position = UDim2.fromOffset(iconX + 12, 0) end
		if name then name.Position = UDim2.fromOffset(nameX + 12, 0) end
	end
	TweenService:Create(row, info, { Size = UDim2.fromOffset(width, show and OV.h or 0) }):Play()
	if icon then TweenService:Create(icon, info, { Position = UDim2.fromOffset(iconX + (show and 0 or 12), 0) }):Play() end
	if name then TweenService:Create(name, info, { Position = UDim2.fromOffset(nameX + (show and 0 or 12), 0) }):Play() end
	if not show then
		task.delay(info.Time, function()
			if row.Parent then row:Destroy() end
			if onGone then onGone() end
		end)
	end
end

-- Panel width from header and live rows, height from the stack; the size
-- glides to its target. Spectators sit under Hotkeys until dragged away.
function OV.layout(panel, rows)
	local w, n = panel:GetAttribute("HeaderWidth") or 0, 0
	for _, row in ipairs(rows:GetChildren()) do
		if row:IsA("Frame") and not row:GetAttribute("Leaving") then
			w = math.max(w, row.Size.X.Offset)
			n = n + 1
		end
	end
	local h = OV.head + (n > 0 and (8 + n * OV.h + (n - 1) * 4) or 0)
	if panel:GetAttribute("TargetW") == w and panel:GetAttribute("TargetH") == h then return end
	panel:SetAttribute("TargetW", w)
	panel:SetAttribute("TargetH", h)
	local size = UDim2.fromOffset(w + OV.pad * 2, h + OV.pad * 2)
	-- Only if the wider list would leave the screen, step left just enough.
	local gui = panel.Parent
	if gui and gui.AbsoluteSize.X > 0 and panel.AbsoluteSize.X > 0 then
		local over = panel.AbsolutePosition.X + size.X.Offset - (gui.AbsoluteSize.X - 2)
		if over > 0 then
			local pos = panel.Position
			panel.Position = UDim2.new(pos.X.Scale, pos.X.Offset - over, pos.Y.Scale, pos.Y.Offset)
		end
	end
	if panel.Visible then TweenService:Create(panel, OV.ease, { Size = size }):Play() else panel.Size = size end
	if OV.place then OV.place(true) end
end

local function SetOverlayPanelShown(panel, shown)
	local pop = panel:FindFirstChild("PopScale")
	if shown then
		if panel.Visible and panel:GetAttribute("Shown") then return end
		panel:SetAttribute("Shown", true)
		if panel.GroupTransparency > 0.95 and pop then pop.Scale = 0.95 end
		panel.Visible = true
		TweenService:Create(panel, OV.ease, { GroupTransparency = 0 }):Play()
		if pop then TweenService:Create(pop, OV.ease, { Scale = 1 }):Play() end
	else
		if not panel:GetAttribute("Shown") then return end
		panel:SetAttribute("Shown", false)
		TweenService:Create(panel, OV.easeIn, { GroupTransparency = 1 }):Play()
		if pop then TweenService:Create(pop, OV.easeIn, { Scale = 0.97 }):Play() end
		task.delay(OV.easeIn.Time, function()
			if panel.Parent and not panel:GetAttribute("Shown") then panel.Visible = false end
		end)
	end
end

-- Keyed rows: new keys slide in, missing keys slide out, changed keys are
-- rebuilt in place. cache maps key -> { row = Frame, sig = string }.
function OV.sync(panel, rows, cache, entries, build)
	local seen = {}
	for i, entry in ipairs(entries) do
		seen[entry.id] = true
		local held = cache[entry.id]
		if held and held.row.Parent and held.sig == entry.sig then
			held.row.LayoutOrder = 10 + i
		else
			local fresh = held == nil or not held.row.Parent
			if held and held.row.Parent then held.row:Destroy() end
			local row = build(entry.data, 10 + i)
			cache[entry.id] = { row = row, sig = entry.sig }
			if fresh and panel.Visible then OV.animateRow(row, true) end
		end
	end
	for id, held in pairs(cache) do
		if not seen[id] then
			cache[id] = nil
			if held.row.Parent then
				held.row:SetAttribute("Leaving", true)
				if panel.Visible then OV.animateRow(held.row, false) else held.row:Destroy() end
			end
		end
	end
	OV.layout(panel, rows)
end

-- Icons: Lucide set as uploaded for the Fluent UI library.
OV.icons = {
	list = "rbxassetid://10723433811", eye = "rbxassetid://10723346959",
	toggleOn = "rbxassetid://10734985040", toggleOff = "rbxassetid://10734984834",
	hold = "rbxassetid://10723405649", always = "rbxassetid://10709797837",
}
local KBPanel, KBRows = MakeOverlayPanel("Keybinds", OV.icons.list, "Hotkeys")
local kbEnabled = true
local kbRowCache = {}

-- State glyph for binds without a value. Toggle: the Neverlose filled
-- switch (on: white track, dark knob on the right; off: grey track, knob
-- left). Hold and always use the hand and dot icons.
function OV.modeGlyph(pill, mode, off)
	if mode ~= "hold" and mode ~= "always" then
		local track = New("Frame", {
			Name = "SwitchTrack", AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.fromScale(0.5, 0.5),
			Size = UDim2.fromOffset(16, 10), BackgroundColor3 = off and Color3.fromRGB(96, 100, 112) or Color3.fromRGB(240, 240, 244),
			BackgroundTransparency = 0, BorderSizePixel = 0, ZIndex = Z_BASE + 892,
		}, pill)
		track:SetAttribute("NLOverlayAccentPart", true)
		New("UICorner", { CornerRadius = UDim.new(1, 0) }, track)
		local knob = New("Frame", {
			Name = "SwitchKnob", AnchorPoint = Vector2.new(0, 0.5), Position = UDim2.new(0, off and 2 or 8, 0.5, 0),
			Size = UDim2.fromOffset(6, 6), BackgroundColor3 = OV.entry, BackgroundTransparency = 0, BorderSizePixel = 0,
			ZIndex = Z_BASE + 893,
		}, track)
		knob:SetAttribute("NLOverlayAccentPart", true)
		New("UICorner", { CornerRadius = UDim.new(1, 0) }, knob)
		return
	end
	local asset = mode == "hold" and OV.icons.hold or OV.icons.always
	New("ImageLabel", {
		Name = "StateIcon", AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.fromScale(0.5, 0.5),
		Size = UDim2.fromOffset(16, 16), BackgroundTransparency = 1, Image = asset,
		ImageColor3 = off and Color3.fromRGB(120, 124, 136) or Color3.fromRGB(240, 240, 244),
		ScaleType = Enum.ScaleType.Fit, ZIndex = Z_BASE + 892,
	}, pill)
end

local function BuildBindRow(entry, order)
	local row, leftPill = OV.row(KBRows, order, entry.label, entry.value)
	row.Name = "BindRow"
	if not entry.value then OV.modeGlyph(leftPill, entry.mode, entry.on == false) end
	return row
end

RefreshKeybindOverlay = function()
	if not KBPanel.Parent then return end
	local snapshot = {}
	if WindowObj._bindSnapshot then
		local ok, result = pcall(WindowObj._bindSnapshot)
		if ok and type(result) == "table" then snapshot = result end
	end
	-- Shown while the menu is open, and without it while any bind is active.
	local menuShown = WindowObj._menuOpen
	if menuShown == nil then menuShown = MainFrame.Visible end
	local target = kbEnabled and not WindowObj._loaderActive and (menuShown or #snapshot > 0)
	local entries = {}
	for i, entry in ipairs(snapshot) do
		entries[i] = {
			id = entry.label .. "|" .. tostring(entry.key),
			sig = tostring(entry.mode) .. ":" .. tostring(entry.value) .. ":" .. tostring(entry.on),
			data = entry,
		}
	end
	OV.sync(KBPanel, KBRows, kbRowCache, entries, BuildBindRow)
	SetOverlayPanelShown(KBPanel, target)
end

WindowObj.KeybindList = {
	frame = KBPanel,
	setEnabled = function(enabled)
		kbEnabled = enabled == true
		RefreshKeybindOverlay()
	end,
	refresh = function() RefreshKeybindOverlay() end,
}

local SpecPanel, SpecRows = MakeOverlayPanel("Spectators", OV.icons.eye, "Spectators")
local specEnabled = true
local specAuto = true
local specList = {}
local specRowCache = {}

-- animated: glide (list resized); otherwise follow at once (Hotkeys dragged).
function OV.place(animated)
	-- Follows Hotkeys only until either list is moved by hand.
	if SpecPanel:GetAttribute("Dragged") or KBPanel:GetAttribute("Dragged") then return end
	local kb = KBPanel.Position
	local shown = KBPanel:GetAttribute("Shown") == true
	local below = shown and ((KBPanel:GetAttribute("TargetH") or OV.head) + 10) or 0
	local pos = UDim2.new(kb.X.Scale, kb.X.Offset, kb.Y.Scale, kb.Y.Offset + below)
	if animated == true and SpecPanel.Visible then
		TweenService:Create(SpecPanel, OV.ease, { Position = pos }):Play()
	else
		SpecPanel.Position = pos
	end
end
KBPanel:GetPropertyChangedSignal("Position"):Connect(function() OV.place(false) end)
KBPanel:GetAttributeChangedSignal("Shown"):Connect(function() OV.place(true) end)

local function BuildSpecRow(person, order)
	local row, leftPill = OV.row(SpecRows, order, person.name)
	row.Name = "SpecRow"
	if person.id and person.id > 0 then
		local avatar = New("ImageLabel", {
			Name = "SpecAvatar",
			AnchorPoint = Vector2.new(0.5, 0.5),
			Position = UDim2.fromScale(0.5, 0.5),
			Size = UDim2.fromOffset(16, 16),
			BackgroundTransparency = 1,
			Image = "rbxthumb://type=AvatarHeadShot&id=" .. tostring(person.id) .. "&w=150&h=150",
			ZIndex = Z_BASE + 892,
		}, leftPill)
		New("UICorner", { CornerRadius = UDim.new(1, 0) }, avatar)
	end
	return row
end

local function RefreshSpectatorOverlay()
	if not SpecPanel.Parent then return end
	local menuShown = WindowObj._menuOpen
	if menuShown == nil then menuShown = MainFrame.Visible end
	local target = specEnabled and not WindowObj._loaderActive and (menuShown or #specList > 0)
	local entries = {}
	for i, person in ipairs(specList) do
		entries[i] = { id = tostring(person.id) .. ":" .. person.name, sig = "", data = person }
	end
	OV.sync(SpecPanel, SpecRows, specRowCache, entries, BuildSpecRow)
	SetOverlayPanelShown(SpecPanel, target)
end

local function NormalizeSpectatorList(list)
	local out = {}
	if type(list) ~= "table" then return out end
	for _, item in ipairs(list) do
		if typeof(item) == "Instance" and item:IsA("Player") then
			table.insert(out, { id = item.UserId, name = item.DisplayName })
		elseif type(item) == "table" and item.name then
			table.insert(out, { id = tonumber(item.id) or 0, name = tostring(item.name) })
		elseif type(item) == "string" then
			table.insert(out, { id = 0, name = item })
		end
	end
	return out
end

local function UpdateAutoSpectators()
	if not specAuto then return end
	local list = {}
	for _, p in ipairs(Players:GetPlayers()) do
		if p ~= LocalPlayer then
			local char = p.Character
			local dead = false
			if char then
				local humanoid = char:FindFirstChildOfClass("Humanoid")
				dead = humanoid == nil or humanoid.Health <= 0
			end
			if not char or dead then
				table.insert(list, { id = p.UserId, name = p.DisplayName })
			end
		end
	end
	specList = list
end

WindowObj.SpectatorList = {
	frame = SpecPanel,
	setEnabled = function(enabled)
		specEnabled = enabled == true
		RefreshSpectatorOverlay()
	end,
	refresh = function()
		UpdateAutoSpectators()
		RefreshSpectatorOverlay()
	end,
}
function WindowObj:SetSpectators(list)
	specAuto = false
	specList = NormalizeSpectatorList(list)
	RefreshSpectatorOverlay()
	return SpecPanel
end
function WindowObj:SetSpectatorsAuto(enabled)
	specAuto = enabled == true
	if specAuto then UpdateAutoSpectators() end
	RefreshSpectatorOverlay()
	return specAuto
end

MainFrame:GetPropertyChangedSignal("Visible"):Connect(function()
	OverlayStack.Visible = true
	if RefreshKeybindOverlay then RefreshKeybindOverlay() end
	RefreshSpectatorOverlay()
end)

task.spawn(function()
	-- 0.3s so the hotkey list follows toggles clicked in the menu.
	while OverlayStack.Parent do
		task.wait(0.3)
		if not OverlayStack.Parent then break end
		pcall(function()
			if specAuto then UpdateAutoSpectators() end
		end)
		pcall(RefreshSpectatorOverlay)
		if RefreshKeybindOverlay then pcall(RefreshKeybindOverlay) end
	end
end)

task.defer(function()
	if RefreshKeybindOverlay then RefreshKeybindOverlay() end
	RefreshSpectatorOverlay()
end)
end

local Aspect = Instance.new("UIAspectRatioConstraint")
Aspect.Parent = MainFrame
Aspect.AspectRatio = 798 / 610

	-- Rounded badge: UICorner on the frame (backing) and on the image itself, so
	-- the logo's own dark square gets rounded corners too. The zoom is done with
	-- ImageRect instead of an oversized, clipped child (which cut the letters and
	-- could only clip to a hard rectangle).
	local HubIcon = New("Frame", {
		Name = "HubIcon",
		Position = UDim2.fromOffset(13, 7),
		Size = UDim2.fromOffset(38, 38),
		-- The logo image has a semi-transparent dark square. On the glass window
		-- the game showed through it; an opaque backing in the old window colour
		-- keeps the logo looking as it did on the solid window.
		BackgroundColor3 = Color3.fromRGB(13, 15, 22),
		BackgroundTransparency = 0,
		BorderSizePixel = 0,
	}, MainFrame)
	New("UICorner", { CornerRadius = UDim.new(0, 8) }, HubIcon)
	if hubImage ~= "" then
		New("ImageLabel", {
			Name = "HubGlyph",
			AnchorPoint = Vector2.new(0.5, 0.5),
			Position = UDim2.new(0.5, 0, 0.5, 0),
			Size = UDim2.fromScale(1, 1),
			BackgroundTransparency = 1,
			BorderSizePixel = 0,
			Image = hubImage,
			ScaleType = Enum.ScaleType.Stretch,
		}, HubIcon)
		New("UICorner", { CornerRadius = UDim.new(0, 8) }, HubIcon:FindFirstChild("HubGlyph"))
		WindowObj._imageFallback(HubIcon:FindFirstChild("HubGlyph"), "NL")
	else
		WindowObj._logoWithFallback(HubIcon, 19, HubIcon.ZIndex + 1, 8)
	end

	New("TextLabel", {
		Name = "Title",
		Position = UDim2.fromOffset(59, 10),
		Size = UDim2.fromOffset(110, 20),
		BackgroundColor3 = Color3.fromRGB(162, 162, 162),
		BackgroundTransparency = 1,
		Text = hubTitle,
		TextColor3 = Color3.fromRGB(255, 255, 255),
		TextTruncate = Enum.TextTruncate.AtEnd,
		TextScaled = false,
		Font = FONT,
      TextXAlignment = Enum.TextXAlignment.Left,
	}, MainFrame)

	New("TextLabel", {
		Name = "GameTitle",
		Position = UDim2.fromOffset(59, 30),
		Size = UDim2.fromOffset(110, 12),
		BackgroundColor3 = Color3.fromRGB(162, 162, 162),
		BackgroundTransparency = 1,
		Text = gameTitle,
		TextColor3 = Color3.fromRGB(112, 116, 138),
		TextTruncate = Enum.TextTruncate.AtEnd,
		TextScaled = false,
		TextSize = 11,
      TextTransparency = 0,
		Font = FONT,
      TextXAlignment = Enum.TextXAlignment.Left,
	}, MainFrame)
	local Info = Instance.new('Frame')
	Info.Name = "Info"
	-- Anchor to the bottom: with a top anchor the 30px block hung 17px below the
	-- window and the "days left" line was cut off.
	Info.AnchorPoint = Vector2.new(0, 1)
	Info.Position = UDim2.new(0, 15, 1, -13)
	Info.Size = UDim2.new(0, 150, 0, 30)
	Info.BackgroundColor3 = Color3.fromRGB(255, 255, 255)
	Info.BackgroundTransparency = 1
	Info.BorderSizePixel = 0
	Info.Active = true
	Info.Parent = MainFrame

	local UserImageEl = Instance.new('ImageLabel')
	UserImageEl.Name = "UserImage"
	UserImageEl.Position = UDim2.fromOffset(0, 0)
	UserImageEl.Size = UDim2.fromOffset(30, 30)
	UserImageEl.BackgroundColor3 = Color3.fromRGB(17, 19, 27)
	UserImageEl.Image = "rbxthumb://type=AvatarHeadShot&id=" .. LocalPlayer.UserId .. "&w=150&h=150"
	UserImageEl.Parent = Info
	New("UICorner", { CornerRadius = UDim.new(1,0) }, UserImageEl)
	New("UIAspectRatioConstraint", { AspectType = Enum.AspectType.ScaleWithParentSize }, UserImageEl)
	local UserImageStroke = Stroke(UserImageEl)
	WindowObj._imageFallback(UserImageEl, string.upper(string.sub(tostring(LocalPlayer.Name or "?"), 1, 1)), true)

	local User = Instance.new('TextLabel')
	User.Name = "Username"
	-- Two lines (15 + 12) with a 2px gap, centred on the 30px avatar.
	User.Position = UDim2.fromOffset(42, 0)
	User.Size = UDim2.fromOffset(88, 16)
	User.TextTruncate = Enum.TextTruncate.AtEnd
	User.BackgroundColor3 = Color3.fromRGB(162,162,162)
	User.BackgroundTransparency = 1
	User.Text = LocalPlayer.Name
	User.TextColor3 = Color3.fromRGB(255,255,255)
	User.TextScaled = false
	User.TextSize = 14
	User.Font = FONT
	User.TextTransparency = 0
	User.TextXAlignment = Enum.TextXAlignment.Left
	User.TextYAlignment = Enum.TextYAlignment.Center
	User.Parent = Info

	local DaysLeft = Instance.new('TextLabel')
	DaysLeft.Name = "Daysleft"
	DaysLeft.Position = UDim2.fromOffset(42, 17)
	DaysLeft.Size = UDim2.fromOffset(88, 13)
	DaysLeft.TextTruncate = Enum.TextTruncate.AtEnd
	DaysLeft.BackgroundColor3 = Color3.fromRGB(162,162,162)
	DaysLeft.BackgroundTransparency = 1
	DaysLeft.Text = type(daysLeft) == "number" and (tostring(daysLeft) .. " days left") or "Lifetime"
	DaysLeft.TextColor3 = Color3.fromRGB(255,255,255)
	DaysLeft.TextScaled = false
	DaysLeft.TextSize = 12
	DaysLeft.Font = FONT
	DaysLeft.TextTransparency = 0
	DaysLeft.TextColor3 = Color3.fromRGB(112, 116, 138)
	DaysLeft.TextXAlignment = Enum.TextXAlignment.Left
	DaysLeft.TextYAlignment = Enum.TextYAlignment.Center
	DaysLeft.Parent = Info

	local WindowSettings = Instance.new('TextButton')
	WindowSettings.Name = "WindowSettings"
	WindowSettings.Position = UDim2.new(0, 0, 0, 0)
	WindowSettings.Size = UDim2.new(1, 0, 1, 0)
	WindowSettings.BackgroundColor3 = Color3.fromRGB(255,255,255)
	WindowSettings.BackgroundTransparency = 1
	WindowSettings.Text = ""
	WindowSettings.TextColor3 = Color3.fromRGB(255,255,255)
	WindowSettings.TextScaled = false
	WindowSettings.TextXAlignment = Enum.TextXAlignment.Right
	WindowSettings.Parent = Info

local SettingsArrow = New("ImageLabel", {
	Name = "UserSettingsArrow",
	Position = UDim2.new(1, -9, 0.5, 0),
	Size = UDim2.fromOffset(12, 12),
	AnchorPoint = Vector2.new(1, 0.5),
	BackgroundTransparency = 1,
	-- 10709790990 does not render in game; the chevron-down turned -90 reads as ">".
	Image = "rbxassetid://10709790948",
	ImageTransparency = 0.3,
	ScaleType = Enum.ScaleType.Fit,
	Rotation = -90,
	ZIndex = 102,
}, WindowSettings)

	-- Hover plate: a rounded pill a few px larger than the block, instead of
	-- tinting the bare 150x30 frame into a hard rectangle. Kept in a do-block
	-- so it adds no live local to AddWindow (register cap).
	do
		-- Divider across the sidebar above the account block, as in Neverlose.
		New("Frame", {
			Name = "ProfileDivider",
			Position = UDim2.new(0, -3, 0, -14),
			Size = UDim2.new(1, 6, 0, 1),
			BackgroundColor3 = Color3.fromRGB(255, 255, 255),
			BackgroundTransparency = 0.93,
			BorderSizePixel = 0,
		}, Info)
		local hoverPlate = New("Frame", {
			Name = "HoverPlate",
			-- Stays inside the 170px sidebar (block starts at x=15, 150 wide);
			-- +12 width spilled over the content panel edge.
			Position = UDim2.new(0, -6, 0, -6),
			Size = UDim2.new(1, 6, 1, 12),
			-- Same plate and hover strength as the sidebar tabs.
			BackgroundColor3 = Color3.fromRGB(35, 38, 50),
			BackgroundTransparency = 1,
			BorderSizePixel = 0,
			ZIndex = 0,
		}, Info)
		New("UICorner", { CornerRadius = UDim.new(0, 8) }, hoverPlate)
		Info.MouseEnter:Connect(function()
			Tween(hoverPlate, {BackgroundTransparency = 0.8}, 0.11, Enum.EasingStyle.Sine, Enum.EasingDirection.Out)
			Tween(SettingsArrow, {ImageTransparency = 0}, 0.15)
		end)
		Info.MouseLeave:Connect(function()
			Tween(hoverPlate, {BackgroundTransparency = 1}, 0.11, Enum.EasingStyle.Sine, Enum.EasingDirection.Out)
			Tween(SettingsArrow, {ImageTransparency = 0.3}, 0.15)
		end)
	end

local UIAspectRatioConstraint = Instance.new('UIAspectRatioConstraint')
UIAspectRatioConstraint.Name = "UIAspectRatioConstraint"
UIAspectRatioConstraint.AspectRatio = 1
UIAspectRatioConstraint.AspectType = Enum.AspectType.ScaleWithParentSize
UIAspectRatioConstraint.Parent = SettingsArrow

	local WindowSettingsFrame = Instance.new('Frame')
	WindowSettingsFrame.Name = "WindowSettingsFrame"
	WindowSettingsFrame.AnchorPoint = Vector2.new(0, 1)
	WindowSettingsFrame.Position = UDim2.new(0, 168, 1, -13)
	WindowSettingsFrame.Size = UDim2.fromOffset(240, 0)
	WindowSettingsFrame.AutomaticSize = Enum.AutomaticSize.Y
	WindowSettingsFrame.ClipsDescendants = false
	WindowSettingsFrame.BackgroundColor3 = Color3.fromRGB(24, 25, 33) -- Neverlose profile popover
	WindowSettingsFrame.BackgroundTransparency = 0
	WindowSettingsFrame.ZIndex = 101
	do Stroke(WindowSettingsFrame) end
	WindowSettingsFrame.Visible = false
	WindowSettingsFrame.Parent = MainFrame
	do local c = Instance.new("UICorner"); c.CornerRadius = UDim.new(0, 10); c.Parent = WindowSettingsFrame end
	-- Same soft shadow as the other popups (option lists, "..." plates).
	AttachShadow(WindowSettingsFrame, { radius = 10, layers = 5, step = 1.6, bias = 3 })


	local WSScale = New("UIScale", { Scale = 1 }, WindowSettingsFrame)


	local UIScale = Instance.new("UIScale")
	MainFrameUIScale = UIScale
	UIScale.Scale = 0.9
	UIScale.Parent = MainFrame
	local manualScale = 0.9
	local automaticScale = true
	local syncScaleSelection
	local applyMainColorProxy
	local applyLogoProxy
	local scaleViewportConnection
	local function GetAutomaticScale()
		local camera = workspace.CurrentCamera
		local viewport = camera and camera.ViewportSize or Vector2.new(1280, 720)
		if viewport.X <= 0 or viewport.Y <= 0 then viewport = Vector2.new(1280, 720) end
		return math.clamp(math.min(viewport.X / 1280, viewport.Y / 760), 0.78, 1)
	end
	local function ApplyScale(value)
		if type(value) ~= "number" or value ~= value then return end
		UIScale.Scale = math.clamp(value, 0.5, 1.1)
		RescaleStrokes(MainFrame, UIScale.Scale)
		if RepositionOpenPopups then RepositionOpenPopups() end
	end
	local function UpdateScale()
		ApplyScale(automaticScale and GetAutomaticScale() or manualScale)
	end
	local function ConnectScaleCamera()
		if scaleViewportConnection then pcall(function() scaleViewportConnection:Disconnect() end) end
		scaleViewportConnection = nil
		local camera = workspace.CurrentCamera
		if camera and camera.GetPropertyChangedSignal then
			local ok, connection = pcall(function() return camera:GetPropertyChangedSignal("ViewportSize"):Connect(UpdateScale) end)
			if ok then scaleViewportConnection = connection end
		end
	end
	local function OnCurrentCameraChanged()
		ConnectScaleCamera()
		UpdateScale()
	end
	UpdateScale()
	ConnectScaleCamera()
	pcall(function() workspace:GetPropertyChangedSignal("CurrentCamera"):Connect(OnCurrentCameraChanged) end)

	local SettingsContainer = Instance.new("Frame")
	SettingsContainer.Name = "SettingsContainer"
	SettingsContainer.Position = UDim2.new(0,10,0,0)
	SettingsContainer.Size = UDim2.new(1,-20,0,50)
	SettingsContainer.BackgroundColor3 = Color3.fromRGB(162,162,162)
	SettingsContainer.BackgroundTransparency = 1
	SettingsContainer.ZIndex = 13
	SettingsContainer.AutomaticSize = Enum.AutomaticSize.Y
	SettingsContainer.Parent = WindowSettingsFrame
	-- The popover gets an explicit height from its content: with AutomaticSize
	-- the scale-sized shadow layers only measured the base height and covered
	-- just the top of the menu.
	WindowSettingsFrame.AutomaticSize = Enum.AutomaticSize.None
	SettingsContainer:GetPropertyChangedSignal("AbsoluteSize"):Connect(function()
		local frameWidth = WindowSettingsFrame.AbsoluteSize.X
		if frameWidth <= 0 then return end
		local unit = frameWidth / 240 -- on-screen pixels per layout pixel (width is 240)
		WindowSettingsFrame.Size = UDim2.fromOffset(240, math.ceil(SettingsContainer.AbsoluteSize.Y / unit))
	end)
	do
        local ll = Instance.new("UIListLayout")
        ll.Padding = UDim.new(0, 1)
        ll.SortOrder = Enum.SortOrder.LayoutOrder
        ll.Parent = SettingsContainer
        local pad = Instance.new("UIPadding")
        pad.PaddingTop = UDim.new(0, 8)
        pad.PaddingBottom = UDim.new(0, 8)
        pad.Parent = SettingsContainer
    end

	-- Compact account block matching the Neverlose profile popover reference.
		do
			local header = Instance.new("Frame")
			header.Name = "ProfileHeader"
			header.Size = UDim2.new(1, 0, 0, 58)
			header.BackgroundTransparency = 1
			header.BorderSizePixel = 0
			header.LayoutOrder = 0
			header.ZIndex = 120
			header.Parent = SettingsContainer

			local avatar = Instance.new("ImageLabel")
			avatar.Name = "ProfileAvatar"
			avatar.Position = UDim2.new(0, 7, 0, 12)
			avatar.Size = UDim2.fromOffset(34, 34)
			avatar.BackgroundColor3 = Color3.fromRGB(28, 31, 44)
			avatar.BackgroundTransparency = 0
			avatar.BorderSizePixel = 0
			avatar.Image = "rbxthumb://type=AvatarHeadShot&id=" .. tostring(LocalPlayer.UserId or 0) .. "&w=150&h=150"
			avatar.ScaleType = Enum.ScaleType.Crop
			avatar.ZIndex = 121
			avatar.Parent = header
			local avatarCorner = Instance.new("UICorner")
			avatarCorner.CornerRadius = UDim.new(1, 0)
			avatarCorner.Parent = avatar
			local avatarStroke = Stroke(avatar, "ProfileAvatarStroke")

			local name = Instance.new("TextLabel")
			name.Name = "ProfileName"
			name.Position = UDim2.new(0, 48, 0, 8)
			name.Size = UDim2.new(1, -56, 0, 17)
			name.BackgroundTransparency = 1
			name.BorderSizePixel = 0
			name.Text = tostring(LocalPlayer.Name or "Player")
			name.TextColor3 = Color3.fromRGB(232, 234, 242)
			name.TextSize = 14
			name.Font = FONT
			name.TextXAlignment = Enum.TextXAlignment.Left
			name.TextYAlignment = Enum.TextYAlignment.Center
			name.TextTruncate = Enum.TextTruncate.AtEnd
			name.ZIndex = 121
			name.Parent = header

			local plan = Instance.new("TextLabel")
			plan.Name = "ProfilePlan"
			plan.Position = UDim2.new(0, 48, 0, 26)
			plan.Size = UDim2.new(1, -56, 0, 14)
			plan.BackgroundTransparency = 1
			plan.BorderSizePixel = 0
			plan.Text = type(daysLeft) == "number" and ("Till: " .. os.date("%B %d %Y", os.time() + daysLeft * 86400)) or "Till: Lifetime"
			plan.TextColor3 = Color3.fromRGB(151, 157, 175)
			plan.TextSize = 12
			plan.Font = FONT
			plan.TextXAlignment = Enum.TextXAlignment.Left
			plan.TextYAlignment = Enum.TextYAlignment.Center
			plan.TextTruncate = Enum.TextTruncate.AtEnd
			plan.ZIndex = 121
			plan.Parent = header

			local renew = Instance.new("TextLabel")
			renew.Name = "RenewLabel"
			renew.Position = UDim2.new(0, 48, 0, 42)
			renew.Size = UDim2.new(1, -56, 0, 14)
			renew.BackgroundTransparency = 1
			renew.BorderSizePixel = 0
			renew.Text = "Renew"
			renew.TextColor3 = mainColor
			renew.TextSize = 12
			renew.Font = FONT
			renew.TextXAlignment = Enum.TextXAlignment.Left
			renew.TextYAlignment = Enum.TextYAlignment.Center
			renew.ZIndex = 121
			renew.Parent = header

			-- Neverlose separates row groups with spacing, not divider lines.
			for _, spacerOrder in ipairs({ 5, 55, 65, 85 }) do
				local gap = New("Frame", { Name = "ProfileGroupGap", Size = UDim2.new(1, 0, 0, 9), BackgroundTransparency = 1, BorderSizePixel = 0, LayoutOrder = spacerOrder }, SettingsContainer)
				-- Neverlose separates the groups with a hairline.
				New("Frame", { Name = "GroupLine", AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.fromScale(0.5, 0.5), Size = UDim2.new(1, -8, 0, 1), BackgroundColor3 = Color3.fromRGB(255, 255, 255), BackgroundTransparency = 0.93, BorderSizePixel = 0 }, gap)
			end
		end

		local menuBind = Enum.KeyCode.RightShift
		local menuBindProxy = function(key)
			if key == nil then return menuBind end
			menuBind = key
			return menuBind
		end

	local WSColorpicker = Instance.new("Frame")
	WSColorpicker.Name = "Colorpicker"
	-- Fixed row height prevents a circular AutoSize dependency with the popup.
	WSColorpicker.Size = UDim2.new(1, 0, 0, 31)
	WSColorpicker.BackgroundTransparency = 1
	WSColorpicker.BorderSizePixel = 0
	WSColorpicker.ZIndex = 130
	WSColorpicker.LayoutOrder = 60
	WSColorpicker.Parent = SettingsContainer
	do
		New("ImageLabel", { Name = "ProfileIcon", AnchorPoint = Vector2.new(0, 0.5), Position = UDim2.new(0, 8, 0.5, 0), Size = UDim2.fromOffset(14, 14), BackgroundTransparency = 1, Image = Library.ProfileIcons.style, ImageColor3 = Color3.fromRGB(200,200,206), ScaleType = Enum.ScaleType.Fit, ZIndex = 130 }, WSColorpicker)
		local lbl = Instance.new("TextLabel")
		lbl.Name = "colorpickerLabel"
		lbl.Position = UDim2.fromOffset(34, 0)
		lbl.Size = UDim2.new(1, -104, 1, 0)
		lbl.AnchorPoint = Vector2.new(0,0)
		lbl.BackgroundTransparency = 1
		lbl.Text = "Style"
		lbl.TextColor3 = Color3.fromRGB(205,205,211)
		lbl.TextScaled = false
		lbl.TextSize = 14
		lbl.Font = FONT
		lbl.TextTransparency = 0
		lbl.ZIndex = 130
		lbl.TextXAlignment = Enum.TextXAlignment.Left
		lbl.Parent = WSColorpicker
	end

	local wsColorBtn = New("ImageButton", {
		Name = "colorpickerButton",
		AnchorPoint = Vector2.new(1, 0.5),
		Position = UDim2.new(1, -8, 0.5, 0),
		Size = UDim2.fromOffset(14, 14),
		BackgroundColor3 = mainColor,
		BorderSizePixel = 0,
		Image = "",
		ZIndex = 130,
	}, WSColorpicker)
	New("UICorner", { CornerRadius = UDim.new(0, 5) }, wsColorBtn)
	Stroke(wsColorBtn, "ColorpickerButtonStroke")
	local wsPicker = AcrylicBlur.CreateColorPicker(wsColorBtn, mainColor, function(c)
		if applyMainColorProxy then applyMainColorProxy(c) end
	end)

	local WSScaleRow = Instance.new("Frame")
	WSScaleRow.Name = "Selection"
	WSScaleRow.Size = UDim2.new(1,0,0,31)
	WSScaleRow.BackgroundColor3 = Color3.fromRGB(162,162,162)
	WSScaleRow.BackgroundTransparency = 1
	WSScaleRow.ZIndex = 120
	WSScaleRow.LayoutOrder = 20
	WSScaleRow.Parent = SettingsContainer

	do
		New("ImageLabel", { Name = "ProfileIcon", AnchorPoint = Vector2.new(0, 0.5), Position = UDim2.new(0, 8, 0.5, 0), Size = UDim2.fromOffset(14, 14), BackgroundTransparency = 1, Image = Library.ProfileIcons.menuScale, ImageColor3 = Color3.fromRGB(200,200,206), ScaleType = Enum.ScaleType.Fit, ZIndex = 130 }, WSScaleRow)
		local lbl = Instance.new("TextLabel"); lbl.Name = "Text"
		lbl.Position = UDim2.fromOffset(34, 0)
		lbl.Size = UDim2.new(1, -104, 1, 0)
		lbl.AnchorPoint = Vector2.new(0,0)
		lbl.BackgroundTransparency = 1
		lbl.Text = "Menu Scale"; lbl.TextColor3 = Color3.fromRGB(205,205,211)
		lbl.TextScaled = false; lbl.TextSize = 14; lbl.Font = FONT
		lbl.TextTransparency = 0; lbl.ZIndex = 130
		lbl.TextXAlignment = Enum.TextXAlignment.Left; lbl.Parent = WSScaleRow
	end

	local ScaleArrow = Instance.new("ImageLabel")
	ScaleArrow.Name = "TextArrow"
	ScaleArrow.AnchorPoint = Vector2.new(1, 0.5)
	ScaleArrow.Position = UDim2.new(1, -4, 0.5, 0)
	ScaleArrow.Size = UDim2.fromOffset(10, 10)
	ScaleArrow.BackgroundTransparency = 1
	ScaleArrow.Image = "rbxassetid://10709790948"
	ScaleArrow.ImageTransparency = 0.4000000059604645
	ScaleArrow.ImageColor3 = Color3.fromRGB(255,255,255)
	ScaleArrow.ScaleType = Enum.ScaleType.Fit
	ScaleArrow.Rotation = -90
	ScaleArrow.ZIndex = 1000
	ScaleArrow.Parent = WSScaleRow

	local ScaleDefault = Instance.new("TextLabel")
	ScaleDefault.Name = "TextDefault"
	ScaleDefault.AnchorPoint = Vector2.new(1, 0.5)
	ScaleDefault.Position = UDim2.new(1, -18, 0.5, 0)
	ScaleDefault.Size = UDim2.new(0, 70, 1, 0)
	ScaleDefault.TextTruncate = Enum.TextTruncate.AtEnd
	ScaleDefault.BackgroundTransparency = 1
	ScaleDefault.Text = "Auto"
	ScaleDefault:SetAttribute("FullText", ScaleDefault.Text)
	
	ScaleDefault.TextColor3 = Color3.fromRGB(216,216,221)
	ScaleDefault.TextScaled = false
	ScaleDefault.TextSize = 13
	ScaleDefault.Font = FONT
	ScaleDefault.TextTransparency = 0
	ScaleDefault.ZIndex = 150
	ScaleDefault.TextXAlignment = Enum.TextXAlignment.Right
	ScaleDefault.Parent = WSScaleRow

	local ScaleDownBar = Instance.new("Frame")
	ScaleDownBar.Name = "Dropdown"
	ScaleDownBar.Position = UDim2.new(0.60, 0, 1, 4)
	ScaleDownBar.Size = UDim2.fromOffset(150, 0)
	ScaleDownBar.BackgroundColor3 = Color3.fromRGB(17, 19, 28)
	ScaleDownBar.BackgroundTransparency = 0
	ScaleDownBar.BorderSizePixel = 0
	ScaleDownBar.Visible = false
	ScaleDownBar.ZIndex = 1000
	ScaleDownBar.Parent = WSScaleRow
	do local c = Instance.new("UICorner"); c.CornerRadius = UDim.new(0,10); c.Parent = ScaleDownBar end
	do Stroke(ScaleDownBar) end
	local ScaleContainer = Instance.new("ScrollingFrame")
	ScaleContainer.Name = "Container"
	ScaleContainer.Position = UDim2.fromOffset(6, 6)
	ScaleContainer.Size = UDim2.new(1, -12, 1, -12)
	ScaleContainer.BackgroundTransparency = 1
	ScaleContainer.ZIndex = 1000
	ScaleContainer.Active = true
	ScaleContainer.AutomaticCanvasSize = Enum.AutomaticSize.Y
	ScaleContainer.CanvasSize = UDim2.new()
	ScaleContainer.ScrollingDirection = Enum.ScrollingDirection.Y
	ScaleContainer.ScrollBarThickness = 2
	ScaleContainer.ScrollBarImageTransparency = 0.5
	ScaleContainer.Parent = ScaleDownBar
		do local ll = Instance.new("UIListLayout"); ll.FillDirection = Enum.FillDirection.Vertical; ll.SortOrder = Enum.SortOrder.LayoutOrder; ll.Padding = UDim.new(0,2); ll.Parent = ScaleContainer end

	local ScaleOpenBtn = Instance.new("TextButton"); ScaleOpenBtn.Name = "OpenBtn"
	ScaleOpenBtn.Size = UDim2.new(1,0,1,0); ScaleOpenBtn.BackgroundTransparency = 1
	ScaleOpenBtn.Text = ""; ScaleOpenBtn.ZIndex = 500; ScaleOpenBtn.Parent = WSScaleRow

	local function SetLogoState(visible)
		logoVisible = visible == true
		HubIcon.Visible = logoVisible
	end
	applyLogoProxy = SetLogoState

	local WSLangRow = Instance.new("Frame")
	WSLangRow.Name = "Selection"
	WSLangRow.Size = UDim2.new(1,0,0,31)
	WSLangRow.BackgroundColor3 = Color3.fromRGB(162,162,162)
	WSLangRow.BackgroundTransparency = 1
	WSLangRow.ZIndex = 120
	WSLangRow.LayoutOrder = 10
	WSLangRow.Parent = SettingsContainer

	do
		New("ImageLabel", { Name = "ProfileIcon", AnchorPoint = Vector2.new(0, 0.5), Position = UDim2.new(0, 8, 0.5, 0), Size = UDim2.fromOffset(14, 14), BackgroundTransparency = 1, Image = Library.ProfileIcons.language, ImageColor3 = Color3.fromRGB(200,200,206), ScaleType = Enum.ScaleType.Fit, ZIndex = 130 }, WSLangRow)
		local lbl = Instance.new("TextLabel"); lbl.Name = "Text"
		lbl.Position = UDim2.fromOffset(34, 0)
		lbl.Size = UDim2.new(1, -104, 1, 0)
		lbl.AnchorPoint = Vector2.new(0,0)
		lbl.BackgroundTransparency = 1
		lbl.Text = "Language"; lbl.TextColor3 = Color3.fromRGB(205,205,211)
		lbl.TextScaled = false; lbl.TextSize = 14; lbl.Font = FONT
		lbl.TextTransparency = 0; lbl.ZIndex = 130
		lbl.TextXAlignment = Enum.TextXAlignment.Left; lbl.Parent = WSLangRow
	end

	local LangArrow = Instance.new("ImageLabel")
	LangArrow.Name = "TextArrow"
	LangArrow.AnchorPoint = Vector2.new(1, 0.5)
	LangArrow.Position = UDim2.new(1, -4, 0.5, 0)
	LangArrow.Size = UDim2.fromOffset(10, 10)
	LangArrow.BackgroundTransparency = 1
	LangArrow.Image = "rbxassetid://10709790948"
	LangArrow.ImageTransparency = 0.4000000059604645
	LangArrow.ImageColor3 = Color3.fromRGB(255,255,255)
	LangArrow.ScaleType = Enum.ScaleType.Fit
	LangArrow.Rotation = -90
	LangArrow.ZIndex = 1000
	LangArrow.Parent = WSLangRow

	local LangDefault = Instance.new("TextLabel")
	LangDefault.Name = "TextDefault"
	LangDefault.AnchorPoint = Vector2.new(1, 0.5)
	LangDefault.Position = UDim2.new(1, -18, 0.5, 0)
	LangDefault.Size = UDim2.new(0, 70, 1, 0)
	LangDefault.TextTruncate = Enum.TextTruncate.AtEnd
	LangDefault.BackgroundTransparency = 1
	LangDefault.Text = "English"
	LangDefault:SetAttribute("FullText", LangDefault.Text)
	
	LangDefault.TextColor3 = Color3.fromRGB(216,216,221)
	LangDefault.TextScaled = false
	LangDefault.TextSize = 13
	LangDefault.Font = FONT
	LangDefault.TextTransparency = 0
	LangDefault.ZIndex = 150
	LangDefault.TextXAlignment = Enum.TextXAlignment.Right
	LangDefault.Parent = WSLangRow

	local LangDownBar = Instance.new("Frame")
	LangDownBar.Name = "Dropdown"
	LangDownBar.Position = UDim2.new(0.60, 0, 1, 4)
	LangDownBar.Size = UDim2.fromOffset(150, 0)
	LangDownBar.BackgroundColor3 = Color3.fromRGB(17, 19, 28)
	LangDownBar.BackgroundTransparency = 0
	LangDownBar.BorderSizePixel = 0
	LangDownBar.Visible = false
	LangDownBar.ZIndex = 1000
	LangDownBar.Parent = WSLangRow
	do local c = Instance.new("UICorner"); c.CornerRadius = UDim.new(0,10); c.Parent = LangDownBar end
	do Stroke(LangDownBar) end
	local LangContainer = Instance.new("ScrollingFrame")
	LangContainer.Name = "Container"
	LangContainer.Position = UDim2.fromOffset(6, 6)
	LangContainer.Size = UDim2.new(1, -12, 1, -12)
	LangContainer.BackgroundTransparency = 1
	LangContainer.ZIndex = 1000
	LangContainer.Active = true
	LangContainer.AutomaticCanvasSize = Enum.AutomaticSize.Y
	LangContainer.CanvasSize = UDim2.new()
	LangContainer.ScrollingDirection = Enum.ScrollingDirection.Y
	LangContainer.ScrollBarThickness = 2
	LangContainer.ScrollBarImageTransparency = 0.5
	LangContainer.Parent = LangDownBar
		do local ll = Instance.new("UIListLayout"); ll.FillDirection = Enum.FillDirection.Vertical; ll.SortOrder = Enum.SortOrder.LayoutOrder; ll.Padding = UDim.new(0,2); ll.Parent = LangContainer end

	local LangOpenBtn = Instance.new("TextButton"); LangOpenBtn.Name = "OpenBtn"
	LangOpenBtn.Size = UDim2.new(1,0,1,0); LangOpenBtn.BackgroundTransparency = 1
	LangOpenBtn.Text = ""; LangOpenBtn.ZIndex = 500; LangOpenBtn.Parent = WSLangRow

	do
		local function wsApplyColor(c)
			c = NormalizeColor(c)
			for i, tabEntry in ipairs(tabs) do
				pcall(function()
					if i == activeTabIndex then
						tabEntry.icon.ImageColor3 = c
						tabEntry.icon.ImageTransparency = 0
					else
						tabEntry.icon.ImageColor3 = Color3.fromRGB(255, 255, 255)
						tabEntry.icon.ImageTransparency = 0.6
					end
				end)
			end
			-- Recolour only what currently shows the old accent. A dragged picker
			-- passes through white and greys: matching those recoloured every
			-- white title, name and arrow. So a match counts only when the old
			-- accent is a real colour, or when that property was recoloured as
			-- accent before ("AccentTint_<prop>").
			local old = mainColor
			local _, oldSat, oldVal = old:ToHSV()
			local oldIsColour = oldSat > 0.2 and oldVal > 0.2
			local function isAccent(color, object, prop)
				local same = math.abs(color.R - old.R) < 0.02 and math.abs(color.G - old.G) < 0.02 and math.abs(color.B - old.B) < 0.02
				if not same then return false end
				if oldIsColour or object:GetAttribute("AccentTint_" .. prop) then
					object:SetAttribute("AccentTint_" .. prop, true)
					return true
				end
				return false
			end
			for _, object in ipairs(NeverloseCS2:GetDescendants()) do
				-- Colour swatches show a user's chosen value, not the theme.
				local lowerName = string.lower(object.Name)
				local isSwatch = lowerName:find("colorpicker") or lowerName:find("swatch") or lowerName:find("preview") or lowerName:find("svcursor")
					or object:FindFirstAncestor("ColorPickerFrame")
				if not isSwatch then pcall(function()
					if object.Name == "InLine" and object:IsA("Frame") then
						object.BackgroundColor3 = c
					elseif object:IsA("GuiObject") and object.BackgroundTransparency < 1 and isAccent(object.BackgroundColor3, object, "Bg") then
						object.BackgroundColor3 = c
					end
					if (object:IsA("ImageLabel") or object:IsA("ImageButton")) and isAccent(object.ImageColor3, object, "Image") then
						object.ImageColor3 = c
					end
					if (object:IsA("TextLabel") or object:IsA("TextButton")) and isAccent(object.TextColor3, object, "Text") then
						object.TextColor3 = c
					end
					if object:IsA("UIStroke") and isAccent(object.Color, object, "Stroke") then object.Color = c end
				end) end
			end
			mainColor = c
			if wsPicker then wsPicker.Set(c) end
		end
		applyMainColorProxy = wsApplyColor
		wsPicker.Set(mainColor)
	end

		local scales = {"Auto", "100%", "90%", "80%", "70%", "60%", "50%"}
		local scaleVals = {nil, 1, 0.9, 0.8, 0.7, 0.6, 0.5}
		local scaleOpen = false
		local scaleSelectedBtns = {}
		syncScaleSelection = function(selectedLabel)
			selectedLabel = tostring(selectedLabel or "Auto")
			ScaleDefault.Text = selectedLabel
			ScaleDefault:SetAttribute("FullText", selectedLabel)
			for label, check in pairs(scaleSelectedBtns) do
				local isSelected = label == selectedLabel
				check.Visible = false
				local row = check.Parent
				if row then
					row.BackgroundTransparency = 1
					local optionLabel = row:FindFirstChild("Label")
					if optionLabel then optionLabel.TextColor3 = isSelected and Color3.fromRGB(228, 228, 229) or Color3.fromRGB(175, 175, 180) end
				end
			end
		end


		local function closeScaleDropdown()
			scaleOpen = false
			Tween(ScaleArrow, {ImageTransparency = 0.15, Rotation = -90}, 0.14, Enum.EasingStyle.Quint, Enum.EasingDirection.Out)
			UnregisterPopup(ScaleDownBar)
			SmoothClose(ScaleDownBar, 0.18)
		end

		for i, scaleLabel in ipairs(scales) do
			local sv = scaleVals[i]
			local BtnRow = Instance.new("Frame")
			BtnRow.Name = "Buttons"
			BtnRow.Size = UDim2.new(1, 0, 0, 28)
			BtnRow.BackgroundColor3 = Color3.fromRGB(255, 255, 255)
			BtnRow.BackgroundTransparency = 1
			BtnRow.BorderSizePixel = 0
			BtnRow.ZIndex = 1001
			BtnRow.LayoutOrder = i
			BtnRow.Parent = ScaleContainer
			New("UICorner", { CornerRadius = UDim.new(0, 6) }, BtnRow)

			local lbl = Instance.new("TextLabel")
			lbl.Name = "Label"
			lbl.Position = UDim2.new(0, 28, 0, 0)
			lbl.Size = UDim2.new(1, -36, 1, 0)
			lbl.BackgroundTransparency = 1
			lbl.Text = scaleLabel
			lbl.TextColor3 = Color3.fromRGB(200, 204, 218)
			lbl.TextScaled = false
			lbl.TextSize = 14
			lbl.Font = FONT
			lbl.TextTransparency = 0
			lbl.TextTruncate = Enum.TextTruncate.AtEnd
			lbl.ZIndex = 1002
			lbl.TextXAlignment = Enum.TextXAlignment.Left
			lbl.Parent = BtnRow

			local SelBtn = Instance.new("ImageLabel")
			SelBtn.Name = "Selected"
			SelBtn.AnchorPoint = Vector2.new(0, 0.5)
			SelBtn.Position = UDim2.new(0, 4, 0.5, 0)
			SelBtn.Size = UDim2.fromOffset(14, 14)
			SelBtn.BackgroundTransparency = 1
			SelBtn.BorderSizePixel = 0
			SelBtn.Image = "rbxassetid://138494545053627"
			SelBtn.ImageColor3 = mainColor
			SelBtn.Visible = false
			SelBtn.ZIndex = 1004
			SelBtn.Parent = BtnRow
			scaleSelectedBtns[scaleLabel] = SelBtn

			local RowBtn = Instance.new("TextButton")
			RowBtn.Name = "OptionHit"
			RowBtn.Size = UDim2.new(1, 0, 1, 0)
			RowBtn.BackgroundTransparency = 1
			RowBtn.Text = ""
			RowBtn.ZIndex = 1003
			RowBtn.Parent = BtnRow
			RowBtn.MouseEnter:Connect(function() Tween(BtnRow, { BackgroundTransparency = 0.97 }, 0.08) end)
			RowBtn.MouseLeave:Connect(function() Tween(BtnRow, { BackgroundTransparency = 1 }, 0.12) end)

			local function selectScale()
				syncScaleSelection(scaleLabel)
				if scaleLabel == "Auto" then
					automaticScale = true
					UpdateScale()
				else
					automaticScale = false
					manualScale = sv
					ApplyScale(sv)
				end
				closeScaleDropdown()
			end
			RowBtn.MouseButton1Click:Connect(selectScale)
		end


		syncScaleSelection("Auto")
		ScaleOpenBtn.MouseButton1Click:Connect(function()
			if scaleOpen then closeScaleDropdown()
			else
				CloseAllPopupsExcept(ScaleDownBar)
				scaleOpen = true
				local popupH = math.min(#scales, 8) * 30 + 10
				ScaleDownBar.Size = UDim2.fromOffset(150, popupH)
				ApplyZIndexLadder(ScaleDownBar, NextPopupZ())
				ScaleDownBar.Visible = true
				WindowObj._centerPopupOnField(ScaleDownBar, ScaleDefault)
				SmoothOpen(ScaleDownBar, 0.02, 0.16)
				Tween(ScaleArrow, {ImageTransparency = 0, Rotation = -90}, 0.13, Enum.EasingStyle.Quint, Enum.EasingDirection.Out)
				RegisterPopup(ScaleDownBar, closeScaleDropdown, ScaleOpenBtn)
			end
		end)

		local langs = {"English", "Filipino", "Chinese", "Russian", "Italian"}
		local langOpen = false
		local langSelectedBtns = {}
		local selectedLang = "English"
		-- Lost in 7d1b0ae, which left three calls to an undefined global. Stored on
		-- WindowObj rather than as a local: AddWindow sits near Luau's register cap.
		WindowObj._closeLangDropdown = function()
			langOpen = false
			Tween(LangArrow, {ImageTransparency = 0.15, Rotation = -90}, 0.14, Enum.EasingStyle.Quint, Enum.EasingDirection.Out)
			UnregisterPopup(LangDownBar)
			SmoothClose(LangDownBar, 0.18)
		end
		local function syncLangSelection()
			LangDefault.Text = selectedLang
			LangDefault:SetAttribute("FullText", selectedLang)
			for language, check in pairs(langSelectedBtns) do
				local isSelected = language == selectedLang
				check.Visible = false
				local row = check.Parent
				if row then
					row.BackgroundTransparency = 1
					local optionLabel = row:FindFirstChild("Label")
					if optionLabel then optionLabel.TextColor3 = isSelected and Color3.fromRGB(228, 228, 229) or Color3.fromRGB(175, 175, 180) end
				end
			end
		end


		for i, lang in ipairs(langs) do
			local BtnRow = Instance.new("Frame")
			BtnRow.Name = "Buttons"
			BtnRow.Size = UDim2.new(1, 0, 0, 28)
			BtnRow.BackgroundColor3 = Color3.fromRGB(255, 255, 255)
			BtnRow.BackgroundTransparency = 1
			BtnRow.BorderSizePixel = 0
			BtnRow.ZIndex = 1001
			BtnRow.LayoutOrder = i
			BtnRow.Parent = LangContainer
			New("UICorner", { CornerRadius = UDim.new(0, 6) }, BtnRow)

			local lbl = Instance.new("TextLabel")
			lbl.Name = "Label"
			lbl.Position = UDim2.new(0, 28, 0, 0)
			lbl.Size = UDim2.new(1, -36, 1, 0)
			lbl.BackgroundTransparency = 1
			lbl.Text = lang
			lbl.TextColor3 = Color3.fromRGB(200, 204, 218)
			lbl.TextScaled = false
			lbl.TextSize = 14
			lbl.Font = FONT
			lbl.TextTransparency = 0
			lbl.TextTruncate = Enum.TextTruncate.AtEnd
			lbl.ZIndex = 1002
			lbl.TextXAlignment = Enum.TextXAlignment.Left
			lbl.Parent = BtnRow

			local SelBtn = Instance.new("ImageLabel")
			SelBtn.Name = "Selected"
			SelBtn.AnchorPoint = Vector2.new(0, 0.5)
			SelBtn.Position = UDim2.new(0, 4, 0.5, 0)
			SelBtn.Size = UDim2.fromOffset(14, 14)
			SelBtn.BackgroundTransparency = 1
			SelBtn.BorderSizePixel = 0
			SelBtn.Image = "rbxassetid://138494545053627"
			SelBtn.ImageColor3 = mainColor
			SelBtn.Visible = false
			SelBtn.ZIndex = 1004
			SelBtn.Parent = BtnRow
			langSelectedBtns[lang] = SelBtn

			local RowBtn = Instance.new("TextButton")
			RowBtn.Name = "OptionHit"
			RowBtn.Size = UDim2.new(1, 0, 1, 0)
			RowBtn.BackgroundTransparency = 1
			RowBtn.Text = ""
			RowBtn.ZIndex = 1003
			RowBtn.Parent = BtnRow
			RowBtn.MouseEnter:Connect(function() Tween(BtnRow, { BackgroundTransparency = 0.97 }, 0.08) end)
			RowBtn.MouseLeave:Connect(function() Tween(BtnRow, { BackgroundTransparency = 1 }, 0.12) end)

			local function selectLang()
				selectedLang = lang
				syncLangSelection()
				WindowObj._closeLangDropdown()
			end
			RowBtn.MouseButton1Click:Connect(selectLang)
		end
local function AddProfileDisplayRow(order, name, title, value, iconAsset, kind)
	local row = New("Frame", { Name = "Profile_" .. name, Size = UDim2.new(1, 0, 0, 31), BackgroundTransparency = 1, BorderSizePixel = 0, LayoutOrder = order, ZIndex = 120 }, SettingsContainer)
	New("ImageLabel", { Name = "ProfileIcon", AnchorPoint = Vector2.new(0, 0.5), Position = UDim2.new(0, 8, 0.5, 0), Size = UDim2.fromOffset(14, 14), BackgroundTransparency = 1, Image = iconAsset, ImageColor3 = Color3.fromRGB(200,200,206), ScaleType = Enum.ScaleType.Fit, ZIndex = 130 }, row)
	local labelWidth = (kind == "switch-off" or kind == "switch-on") and UDim2.new(1, -72, 1, 0) or UDim2.new(1, -104, 1, 0)
	New("TextLabel", { Name = "ProfileLabel", Position = UDim2.fromOffset(34, 0), Size = labelWidth, BackgroundTransparency = 1, Text = title, TextColor3 = Color3.fromRGB(205,205,211), TextScaled = false, TextSize = 14, Font = FONT, TextXAlignment = Enum.TextXAlignment.Left, TextTruncate = Enum.TextTruncate.AtEnd, ZIndex = 130 }, row)
	if kind == "switch-off" or kind == "switch-on" then
		local on = kind == "switch-on"
		local track = New("Frame", { Name = "Switch", AnchorPoint = Vector2.new(1, 0.5), Position = UDim2.new(1, -8, 0.5, 0), Size = UDim2.fromOffset(32, 18), BackgroundColor3 = on and mainColor or Color3.fromRGB(8, 10, 16), BorderSizePixel = 0, ZIndex = 131 }, row)
		New("UICorner", { CornerRadius = UDim.new(1, 0) }, track)
		local knob = New("Frame", { Name = "Knob", Position = on and UDim2.fromOffset(16,2) or UDim2.fromOffset(2,2), Size = UDim2.fromOffset(14,14), BackgroundColor3 = on and Color3.fromRGB(255, 255, 255) or Color3.fromRGB(139, 145, 157), BorderSizePixel = 0, ZIndex = 132 }, track)
		New("UICorner", { CornerRadius = UDim.new(1, 0) }, knob)
	else
		if value and value ~= "" then
			New("TextLabel", { Name = "ProfileValue", AnchorPoint = Vector2.new(1, 0.5), Position = UDim2.new(1, kind == "arrow" and -18 or -8, 0.5, 0), Size = UDim2.fromOffset(70, 27), BackgroundTransparency = 1, Text = value, TextColor3 = Color3.fromRGB(216,216,221), TextScaled = false, TextSize = 14, Font = FONT, TextXAlignment = Enum.TextXAlignment.Right, TextTruncate = Enum.TextTruncate.AtEnd, ZIndex = 130 }, row)
		end
		if kind == "arrow" then
			New("ImageLabel", { Name = "Chevron", AnchorPoint = Vector2.new(1, 0.5), Position = UDim2.new(1, -4, 0.5, 0), Size = UDim2.fromOffset(10, 10), BackgroundTransparency = 1, Image = "rbxassetid://10709790948", ImageColor3 = Color3.fromRGB(255,255,255), ImageTransparency = 0.15, Rotation = -90, ScaleType = Enum.ScaleType.Fit, ZIndex = 131 }, row)
		end
	end
	return row
end

AddProfileDisplayRow(30, "ESPScale", "ESP Scale", "150%", Library.ProfileIcons.espScale, "arrow")
AddProfileDisplayRow(40, "WindowsScale", "Windows Scale", "Auto", Library.ProfileIcons.windowsScale, "arrow")
AddProfileDisplayRow(50, "Units", "Units", "Auto", Library.ProfileIcons.units, "arrow")
AddProfileDisplayRow(70, "SafeMode", "Safe Mode", "Automatic", Library.ProfileIcons.safeMode, "arrow")
AddProfileDisplayRow(80, "Synchronization", "Synchronization", nil, Library.ProfileIcons.sync, "switch-on")
AddProfileDisplayRow(82, "DeveloperMode", "Developer Mode", nil, Library.ProfileIcons.developer, "switch-off")
-- About and Chat have no chevron in the reference.
AddProfileDisplayRow(90, "About", "About", nil, Library.ProfileIcons.about, "plain")
AddProfileDisplayRow(100, "Chat", "Chat", nil, Library.ProfileIcons.chat, "plain")
-- Profile rows are live: arrow rows open a choice list on their value,
-- switches toggle, About/Chat fire an action. Values are readable through
-- Win:GetProfileSetting(key); Win:OnProfileSetting(fn) and
-- Win:OnProfileAction(fn) report changes. Windows Scale really scales the
-- on-screen overlays (hotkeys, spectators, watermark).
do
	local settings = { ESPScale = "150%", WindowsScale = "Auto", Units = "Auto", SafeMode = "Automatic", Synchronization = true, DeveloperMode = false }
	local choices = {
		ESPScale = { "50%", "75%", "100%", "125%", "150%", "200%" },
		WindowsScale = { "Auto", "75%", "100%", "125%", "150%" },
		Units = { "Auto", "Metric", "Imperial" },
		SafeMode = { "Automatic", "Enabled", "Disabled" },
	}
	local function notify(key, value)
		if type(WindowObj._onProfileSetting) == "function" then InvokeCallback(WindowObj._onProfileSetting, key, value) end
	end
	local function applyWindowsScale(value)
		local factor = tonumber(tostring(value):match("^(%d+)%%$"))
		factor = factor and factor / 100 or 1
		for _, name in ipairs({ "OverlayStack", "GameInfo", "WMShadow" }) do
			local target = NeverloseCS2:FindFirstChild(name)
			if target then
				local scale = target:FindFirstChild("ProfileWindowsScale") or New("UIScale", { Name = "ProfileWindowsScale" }, target)
				scale.Scale = factor
			end
		end
	end

	local openList
	local function closeList()
		if not openList then return end
		local list = openList
		openList = nil
		UnregisterPopup(list)
		SmoothClose(list, 0.1, function() list:Destroy() end)
	end
	local function openChoiceList(field, options, current, onPick)
		closeList()
		local list = New("Frame", {
			Name = "ProfileChoices", Size = UDim2.fromOffset(150, #options * 30 + 10), BackgroundColor3 = Color3.fromRGB(18, 18, 27),
			BorderSizePixel = 0, Visible = false, ZIndex = 9000,
		}, MainFrame)
		New("UICorner", { CornerRadius = UDim.new(0, 10) }, list)
		Stroke(list)
		local rows = New("Frame", { Name = "Rows", Position = UDim2.fromOffset(5, 5), Size = UDim2.new(1, -10, 1, -10), BackgroundTransparency = 1 }, list)
		New("UIListLayout", { SortOrder = Enum.SortOrder.LayoutOrder }, rows)
		for index, option in ipairs(options) do
			local item = New("TextButton", {
				Name = "Choice", LayoutOrder = index, Size = UDim2.new(1, 0, 0, 30), BackgroundColor3 = Color3.fromRGB(255, 255, 255),
				BackgroundTransparency = 1, AutoButtonColor = false, Text = option,
				TextColor3 = option == current and Color3.fromRGB(228, 228, 229) or Color3.fromRGB(175, 175, 180),
				TextSize = 14, TextXAlignment = Enum.TextXAlignment.Left,
			}, rows)
			New("UICorner", { CornerRadius = UDim.new(0, 6) }, item)
			New("UIPadding", { PaddingLeft = UDim.new(0, 12) }, item)
			item.MouseEnter:Connect(function() Tween(item, { BackgroundTransparency = 0.97 }, 0.08) end)
			item.MouseLeave:Connect(function() Tween(item, { BackgroundTransparency = 1 }, 0.1) end)
			if onPick then
				item.MouseButton1Click:Connect(function()
					closeList()
					onPick(option)
				end)
			end
		end
		openList = list
		ApplyZIndexLadder(list, NextPopupZ())
		list.Visible = true
		WindowObj._centerPopupOnField(list, field)
		SmoothOpen(list, 0, 0.14)
		RegisterPopup(list, closeList, field)
	end

	for key, options in pairs(choices) do
		local row = SettingsContainer:FindFirstChild("Profile_" .. key)
		local valueLabel = row and row:FindFirstChild("ProfileValue")
		if row and valueLabel then
			local hit = New("TextButton", { Name = "ProfileHit", Size = UDim2.fromScale(1, 1), BackgroundTransparency = 1, Text = "", ZIndex = 140 }, row)
			hit.MouseButton1Click:Connect(function()
				if openList then closeList() return end
				openChoiceList(valueLabel, options, settings[key], function(option)
					settings[key] = option
					valueLabel.Text = option
					if key == "WindowsScale" then applyWindowsScale(option) end
					notify(key, option)
				end)
			end)
		end
	end

	for _, key in ipairs({ "Synchronization", "DeveloperMode" }) do
		local row = SettingsContainer:FindFirstChild("Profile_" .. key)
		local track = row and row:FindFirstChild("Switch")
		local knob = track and track:FindFirstChild("Knob")
		if row and track and knob then
			local hit = New("TextButton", { Name = "ProfileHit", Size = UDim2.fromScale(1, 1), BackgroundTransparency = 1, Text = "", ZIndex = 140 }, row)
			hit.MouseButton1Click:Connect(function()
				local on = not settings[key]
				settings[key] = on
				Tween(track, { BackgroundColor3 = on and mainColor or Color3.fromRGB(8, 10, 16) }, 0.15)
				Tween(knob, {
					Position = on and UDim2.fromOffset(16, 2) or UDim2.fromOffset(2, 2),
					BackgroundColor3 = on and Color3.fromRGB(255, 255, 255) or Color3.fromRGB(139, 145, 157),
				}, 0.15, Enum.EasingStyle.Quint, Enum.EasingDirection.Out)
				notify(key, on)
			end)
		end
	end

	for _, key in ipairs({ "About", "Chat" }) do
		local row = SettingsContainer:FindFirstChild("Profile_" .. key)
		local label = row and row:FindFirstChild("ProfileLabel")
		if row and label then
			local hit = New("TextButton", { Name = "ProfileHit", Size = UDim2.fromScale(1, 1), BackgroundTransparency = 1, Text = "", ZIndex = 140 }, row)
			hit.MouseButton1Click:Connect(function()
				if type(WindowObj._onProfileAction) == "function" then
					InvokeCallback(WindowObj._onProfileAction, key)
				elseif key == "About" then
					-- Links: clicking one copies it (executors expose setclipboard).
					openChoiceList(label, { "t.me/neverlosewtf", "t.me/shizukuscripts" }, nil, function(choice)
						if type(setclipboard) == "function" then pcall(setclipboard, "https://" .. tostring(choice)) end
					end)
				else
					openChoiceList(label, { "Chat is not connected" }, nil, nil)
				end
			end)
		end
	end

	function WindowObj:GetProfileSetting(key) return settings[key] end
	function WindowObj:OnProfileSetting(callback) WindowObj._onProfileSetting = callback return self end
	function WindowObj:OnProfileAction(callback) WindowObj._onProfileAction = callback return self end
end
-- Rounded hover tint on every popover row, same as the menu rows.
for _, profileRow in ipairs(SettingsContainer:GetChildren()) do
	if profileRow:IsA("Frame") and profileRow.Name ~= "ProfileHeader" and profileRow.Name ~= "ProfileGroupGap" and profileRow.Name ~= "WatermarkRow" then
		AttachRowHover(profileRow)
	end
end
		syncLangSelection()




		LangOpenBtn.MouseButton1Click:Connect(function()
			if langOpen then WindowObj._closeLangDropdown()
			else
				CloseAllPopupsExcept(LangDownBar)
				langOpen = true
				local popupH = math.min(#langs, 8) * 30 + 10
				LangDownBar.Size = UDim2.fromOffset(150, popupH)
				ApplyZIndexLadder(LangDownBar, NextPopupZ())
				LangDownBar.Visible = true
				WindowObj._centerPopupOnField(LangDownBar, LangDefault)
				SmoothOpen(LangDownBar, 0.02, 0.16)
				Tween(LangArrow, {Rotation = -90, ImageTransparency = 0}, 0.13, Enum.EasingStyle.Quint, Enum.EasingDirection.Out)
				RegisterPopup(LangDownBar, WindowObj._closeLangDropdown, LangOpenBtn)
			end
		end)

		local wsOpen = false
		local function closeWS()
			wsOpen = false
			ClosePopupsUnder(WindowSettingsFrame)
			UnregisterPopup(WindowSettingsFrame)
			local anchorCenterX = Info.AbsolutePosition.X + Info.AbsoluteSize.X * 0.5
			local popupCenterX = WindowSettingsFrame.AbsolutePosition.X + WindowSettingsFrame.AbsoluteSize.X * 0.5
			local closeOffsetX = popupCenterX >= anchorCenterX and -6 or 6
			local closingPosition = WindowSettingsFrame.Position
			Tween(WindowSettingsFrame, {
				Position = UDim2.new(closingPosition.X.Scale, closingPosition.X.Offset + closeOffsetX, closingPosition.Y.Scale, closingPosition.Y.Offset + 2),
			}, 0.12, Enum.EasingStyle.Quad, Enum.EasingDirection.In)
			Tween(WSScale, { Scale = 0.975 }, 0.12, Enum.EasingStyle.Quad, Enum.EasingDirection.In)
			SmoothClose(WindowSettingsFrame, 0.14)
			Tween(SettingsArrow, { Rotation = -90 }, 0.16, Enum.EasingStyle.Sine, Enum.EasingDirection.Out)
		end
		WindowSettings.MouseButton1Click:Connect(function()
			wsOpen = not wsOpen
			if wsOpen then
				CloseAllPopupsExcept(WindowSettingsFrame)
				WindowSettingsFrame.BackgroundTransparency = 1
				WindowSettingsFrame.Visible = false
				WSScale.Scale = 1
				ApplyZIndexLadder(WindowSettingsFrame, NextPopupZ())

				-- Let AutomaticSize/UIListLayout finish before measuring. A hidden
				-- first-open popup otherwise reports a short height and jumps on open.
				task.spawn(function()
					task.wait()
					if not wsOpen or not WindowSettingsFrame.Parent then return end
					local popupSize = WindowSettingsFrame.AbsoluteSize
					if popupSize.X <= 0 or popupSize.Y <= 0 then
						-- The first layout pass may not have completed yet. Yield once more,
						-- still hidden, rather than flashing the panel at its default origin.
						task.wait()
						if not wsOpen or not WindowSettingsFrame.Parent then return end
						popupSize = WindowSettingsFrame.AbsoluteSize
					end
					if popupSize.X <= 0 or popupSize.Y <= 0 then
						-- Fallback for unusual GUI scale/layout timing.
						WindowSettingsFrame.Visible = true
						PositionPopupWithinMain(WindowSettingsFrame, false, 8, WindowSettings)
						popupSize = WindowSettingsFrame.AbsoluteSize
						WindowSettingsFrame.Visible = false
					end
					if not wsOpen or popupSize.X <= 0 or popupSize.Y <= 0 then return end

					local anchorPos = Info.AbsolutePosition
					local anchorSize = Info.AbsoluteSize
					local popupAppearsOnRight = true
					local gui = NeverloseCS2
					if gui and gui.AbsoluteSize.X > 0 and gui.AbsoluteSize.Y > 0 then
						local edge = 8
						local safeLeft = gui.AbsolutePosition.X + edge
						local safeTop = gui.AbsolutePosition.Y + edge
						local safeRight = gui.AbsolutePosition.X + gui.AbsoluteSize.X - edge
						local safeBottom = gui.AbsolutePosition.Y + gui.AbsoluteSize.Y - edge
						local x = anchorPos.X + anchorSize.X + edge
						if x + popupSize.X > safeRight then x = anchorPos.X - popupSize.X - edge end
						local maxX = math.max(safeLeft, safeRight - popupSize.X)
						local maxY = math.max(safeTop, safeBottom - popupSize.Y)
						x = math.clamp(x, safeLeft, maxX)
						popupAppearsOnRight = x >= (anchorPos.X + anchorSize.X * 0.5)
						local y = math.clamp(anchorPos.Y + anchorSize.Y - popupSize.Y, safeTop, maxY)
						MovePopupToAbsolute(WindowSettingsFrame, x, y)
					else
						WindowSettingsFrame.Position = UDim2.new(0, 168, 1, -13)
					end

					local settled = WindowSettingsFrame.Position
					local entranceOffsetX = popupAppearsOnRight and -7 or 7
					WindowSettingsFrame.Position = UDim2.new(settled.X.Scale, settled.X.Offset + entranceOffsetX, settled.Y.Scale, settled.Y.Offset + 3)
					WSScale.Scale = 0.955
					WindowSettingsFrame.Visible = true
					ApplyZIndexLadder(WindowSettingsFrame, NextPopupZ())
					SmoothOpen(WindowSettingsFrame, 0, 0.17, Enum.EasingStyle.Quint, Enum.EasingDirection.Out)
					Tween(WSScale, { Scale = 1 }, 0.17, Enum.EasingStyle.Quint, Enum.EasingDirection.Out)
					Tween(WindowSettingsFrame, { Position = settled }, 0.17, Enum.EasingStyle.Quint, Enum.EasingDirection.Out)
					RegisterPopup(WindowSettingsFrame, closeWS, WindowSettings)
					Tween(SettingsArrow, { Rotation = -90 }, 0.13, Enum.EasingStyle.Sine, Enum.EasingDirection.Out)
				end)
			else
				closeWS()
			end
		end)

	RegisterConfigElement("window_", "logo", {
		Get = function() return logoVisible end,
		Set = function(_, value) if applyLogoProxy then applyLogoProxy(value == true) end end,
	})
	RegisterConfigElement("window_", "scale", {
		Get = function() return automaticScale and "Auto" or UIScale.Scale end,
		Set = function(_, value)
			if value == "Auto" then
				automaticScale = true
				UpdateScale()
				if syncScaleSelection then syncScaleSelection("Auto") end
			elseif type(value) == "number" and value == value then
				automaticScale = false
				manualScale = math.clamp(value, 0.5, 1.1)
				ApplyScale(manualScale)
				if syncScaleSelection then syncScaleSelection(tostring(math.round(manualScale * 100)) .. "%") end
			end
		end,
	})
	RegisterConfigElement("window_", "mainColor", {
		Get = function() return mainColor end,
		Set = function(_, value)
			if applyMainColorProxy then applyMainColorProxy(NormalizeColor(value)) end
		end,
	})

	do
		local WMRow = Instance.new("Frame")
		WMRow.Name = "WatermarkRow"
		WMRow.Size = UDim2.new(1, 0, 0, 60)
		WMRow.BackgroundColor3 = Color3.fromRGB(162, 162, 162)
		WMRow.BackgroundTransparency = 1
		WMRow.ZIndex = 120
		WMRow.LayoutOrder = 50
		-- Hidden for now: not part of the Neverlose profile popover. Win:SetWatermark still works.
		WMRow.Visible = false
		WMRow.Parent = SettingsContainer

		local wmLabel = Instance.new("TextLabel")
		wmLabel.Name = "Text"
		wmLabel.Position = UDim2.new(0.05, 0, 0, 2)
		wmLabel.Size = UDim2.new(0.9, 0, 0, 14)
		wmLabel.BackgroundTransparency = 1
		wmLabel.Text = "Watermark"
		wmLabel.TextColor3 = Color3.fromRGB(255, 255, 255)
		wmLabel.TextTransparency = 0.1
		wmLabel.TextSize = 13
		wmLabel.Font = FONT
		wmLabel.TextXAlignment = Enum.TextXAlignment.Left
		wmLabel.ZIndex = 150
		wmLabel.Parent = WMRow

		local chipsHost = Instance.new("Frame")
		chipsHost.Name = "Chips"
		chipsHost.Position = UDim2.new(0, 12, 0, 20)
		chipsHost.Size = UDim2.new(1, -24, 0, 38)
		chipsHost.ClipsDescendants = true
		chipsHost.BackgroundTransparency = 1
		chipsHost.ZIndex = 150
		chipsHost.Parent = WMRow
		local chipsLayout = Instance.new("UIGridLayout")
		chipsLayout.FillDirection = Enum.FillDirection.Horizontal
		chipsLayout.FillDirectionMaxCells = 3
		chipsLayout.CellSize = UDim2.new(0.31, 0, 0, 17)
		chipsLayout.CellPadding = UDim2.fromOffset(4, 3)
		chipsLayout.SortOrder = Enum.SortOrder.LayoutOrder
		chipsLayout.Parent = chipsHost

		local chipDefs = { { "logo", "Logo" }, { "user", "User" }, { "fps", "FPS" }, { "ping", "Ping" }, { "ram", "RAM" }, { "time", "Time" } }
		for index, def in ipairs(chipDefs) do
			local key, caption = def[1], def[2]
			local chip = Instance.new("TextButton")
			chip.Name = "Chip_" .. caption
			chip.Size = UDim2.new(1, 0, 1, 0)
			chip.BackgroundColor3 = Color3.fromRGB(28, 31, 44)
			chip.BackgroundTransparency = 0.2
			chip.BorderSizePixel = 0
			chip.AutoButtonColor = false
			chip.Text = caption
			chip.TextColor3 = Color3.fromRGB(150, 154, 172)
			chip.TextSize = 11
			chip.Font = FONT
			chip.ZIndex = 151
			chip.LayoutOrder = index
			chip.Parent = chipsHost
			do local c = Instance.new("UICorner"); c.CornerRadius = UDim.new(0, 4); c.Parent = chip end
			do local p = Instance.new("UIPadding"); p.PaddingLeft = UDim.new(0, 5); p.PaddingRight = UDim.new(0, 5); p.Parent = chip end

			local hovered = false
			local function paintChip()
				local on = WindowObj.Watermark.isShown and WindowObj.Watermark.isShown(key)
				chip.BackgroundColor3 = on and mainColor or (hovered and Color3.fromRGB(40, 45, 62) or Color3.fromRGB(28, 31, 44))
				chip.BackgroundTransparency = on and 0.12 or (hovered and 0.08 or 0.2)
				chip.TextColor3 = on and Color3.fromRGB(255, 255, 255) or (hovered and Color3.fromRGB(224, 228, 239) or Color3.fromRGB(150, 154, 172))
			end
			chip.MouseEnter:Connect(function() hovered = true; Tween(chip, {BackgroundTransparency = 0.08}, 0.09, Enum.EasingStyle.Sine, Enum.EasingDirection.Out); paintChip() end)
			chip.MouseLeave:Connect(function() hovered = false; paintChip() end)
			paintChip()
			chip.MouseButton1Click:Connect(function()
				local on = WindowObj.Watermark.isShown and WindowObj.Watermark.isShown(key)
				if WindowObj.Watermark.toggle then
					WindowObj.Watermark.toggle(key, not on)
				end
				paintChip()
			end)
		end
	end

	local UsageContainer = Instance.new("Frame")
	UsageContainer.Name = "UsageContainer"
	UsageContainer.Position = UDim2.new(0,0,0,0)
	UsageContainer.Size = UDim2.new(1,0,0,0)
	UsageContainer.BackgroundColor3 = Color3.fromRGB(162,162,162)
	UsageContainer.BackgroundTransparency = 1
	UsageContainer.BorderSizePixel = 0
	UsageContainer.ZIndex = 120
	UsageContainer.LayoutOrder = 120
	UsageContainer.AutomaticSize = Enum.AutomaticSize.Y
	UsageContainer.Parent = SettingsContainer
	do
		local ll = Instance.new("UIListLayout")
		ll.Padding = UDim.new(0, 3)
		ll.SortOrder = Enum.SortOrder.LayoutOrder
		ll.Parent = UsageContainer
	end

	local UsageObj = {}
	local usageElemCount = 0

	function UsageObj:AddSelection(text, options, default, callback)
		if type(default) == "function" then callback = default; default = nil end
		options = NormalizeOptions(options)
		usageElemCount = usageElemCount + 1
		local selected = GetValidOption(options, default)
		local dropOpen = false
		local selectedBtns = {}

		local Row = Instance.new("Frame")
		Row.Name = "Selection"
		Row.Size = UDim2.new(1,0,0,28)
		Row.BackgroundColor3 = Color3.fromRGB(162,162,162)
		Row.BackgroundTransparency = 1
		Row.ZIndex = 120
		Row.LayoutOrder = usageElemCount
		Row.Parent = UsageContainer
		
		do
			local ln = Instance.new("Frame"); ln.Name = "Lines"
			ln.Position = UDim2.new(0.06,0,1,-1)
			ln.Size = UDim2.new(0.9,0,0,1)
			ln.BackgroundColor3 = Color3.fromRGB(162,162,162)
			ln.BackgroundTransparency = 0.9
			ln.BorderSizePixel = 0; ln.ZIndex = 150; ln.Parent = Row
		end
		do
			local lbl = Instance.new("TextLabel"); lbl.Name = "Text"
			lbl.Position = UDim2.new(0.04,0,0.5,0)
			lbl.Size = UDim2.new(0.65,0,0.5,0)
			lbl.AnchorPoint = Vector2.new(0,0.5)
			lbl.BackgroundTransparency = 1
			lbl.Text = text; lbl.TextColor3 = Color3.fromRGB(255,255,255)
			lbl.TextScaled = false; lbl.Font = FONT
			lbl.TextTransparency = 0.5; lbl.ZIndex = 130
			lbl.TextXAlignment = Enum.TextXAlignment.Left; lbl.Parent = Row
		end

		local Arrow = Instance.new("ImageLabel")
		Arrow.Name = "TextArrow"
		Arrow.AnchorPoint = Vector2.new(1, 0.5)
		Arrow.Position = UDim2.new(1, -12, 0.5, 0)
		Arrow.Size = UDim2.fromOffset(10, 10)
		Arrow.BackgroundTransparency = 1
		Arrow.Image = "rbxassetid://10709790948"
		Arrow.ImageTransparency = 0.4
		Arrow.ImageColor3 = Color3.fromRGB(255,255,255)
		Arrow.ScaleType = Enum.ScaleType.Fit
		Arrow.Rotation = 0
		Arrow.ZIndex = 1000
		Arrow.Parent = Row

		local TextDefault = Instance.new("TextLabel")
		TextDefault.Name = "TextDefault"
		TextDefault.Position = UDim2.new(0.60, 0, 0.17, 0)
		TextDefault.Size = UDim2.new(0.25, 0, 0.6, 0)
		TextDefault.TextTruncate = Enum.TextTruncate.AtEnd
		TextDefault.BackgroundTransparency = 1
		TextDefault.Text = selected
		
		TextDefault.TextColor3 = Color3.fromRGB(255,255,255)
		TextDefault.TextScaled = false
		TextDefault.Font = FONT
		TextDefault.TextTransparency = 0
		TextDefault.ZIndex = 150
		TextDefault.TextXAlignment = Enum.TextXAlignment.Left
		TextDefault.Parent = Row

		-- ============================================================================
		-- PATCH 4: Settings dropdown — THEME.plate, radius, stroke; no divider watcher
		-- ============================================================================
		local DropPopup = Instance.new("Frame")
		DropPopup.Name = "Dropdown"
		DropPopup.Position = UDim2.new(0.60, 0, 1, 4)
		DropPopup.Size = UDim2.fromOffset(150, 0)
		DropPopup.BackgroundColor3 = Color3.fromRGB(17, 19, 28)
		DropPopup.BackgroundTransparency = 0
		DropPopup.BorderSizePixel = 0
		DropPopup.Visible = false
		DropPopup.ZIndex = 1000
		DropPopup.Parent = Row
		do local c = Instance.new("UICorner"); c.CornerRadius = UDim.new(0, 10); c.Parent = DropPopup end
		do Stroke(DropPopup) end


		local DropContainer = Instance.new("ScrollingFrame")
		DropContainer.Name = "Container"
		DropContainer.Position = UDim2.fromOffset(6, 6)
		DropContainer.Size = UDim2.new(1, -12, 1, -12)
		DropContainer.BackgroundTransparency = 1
		DropContainer.ZIndex = 1000
		DropContainer.Active = true
		DropContainer.AutomaticCanvasSize = Enum.AutomaticSize.Y
		DropContainer.CanvasSize = UDim2.new()
		DropContainer.ScrollingDirection = Enum.ScrollingDirection.Y
		DropContainer.ScrollBarThickness = 2
		DropContainer.ScrollBarImageTransparency = 0.5
		DropContainer.Parent = DropPopup
		do local ll = Instance.new("UIListLayout"); ll.SortOrder = Enum.SortOrder.LayoutOrder; ll.Padding = UDim.new(0, 2); ll.Parent = DropContainer end

		local function closeDropdown()
			dropOpen = false
			Tween(Arrow, {ImageTransparency = 0.4, Rotation = 0}, 0.14, Enum.EasingStyle.Quint, Enum.EasingDirection.Out)
			UnregisterPopup(DropPopup)
			SmoothClose(DropPopup, 0.18)
		end

		local function updateCheckmarks()
			for opt, sb in pairs(selectedBtns) do
				local isSelected = opt == selected
				sb.Visible = false
				sb.ImageColor3 = mainColor
				local row = sb.Parent
				if row then
					row.BackgroundTransparency = 1
					local label = row:FindFirstChildWhichIsA("TextLabel")
					if label then label.TextColor3 = isSelected and Color3.fromRGB(228, 228, 229) or Color3.fromRGB(175, 175, 180) end
				end
			end
		end

		for i, opt in ipairs(options) do
			local BtnRow = Instance.new("Frame")
			BtnRow.Name = "Buttons"
			BtnRow.Size = UDim2.new(1, 0, 0, 28)
			BtnRow.BackgroundColor3 = Color3.fromRGB(255, 255, 255)
			BtnRow.BackgroundTransparency = 1
			BtnRow.ZIndex = 1001
			BtnRow.LayoutOrder = i
			BtnRow.Parent = DropContainer
			do local c = Instance.new("UICorner"); c.CornerRadius = UDim.new(0, 6); c.Parent = BtnRow end

			local lbl = Instance.new("TextLabel")
			lbl.Position = UDim2.new(0, 28, 0, 0)
			lbl.Size = UDim2.new(1, -36, 1, 0)
			lbl.BackgroundTransparency = 1
			lbl.Text = opt
			lbl.TextColor3 = Color3.fromRGB(200, 204, 218)
			lbl.TextScaled = false
			lbl.TextSize = 14
			lbl.Font = FONT
			lbl.TextTruncate = Enum.TextTruncate.AtEnd
			lbl.TextTransparency = 0
			lbl.ZIndex = 1002
			lbl.TextXAlignment = Enum.TextXAlignment.Left
			lbl.Parent = BtnRow

			local SelBtn = Instance.new("ImageButton")
			SelBtn.Name = "Selected"
			SelBtn.AnchorPoint = Vector2.new(0, 0.5)
			SelBtn.Position = UDim2.new(0, 4, 0.5, 0)
			SelBtn.Size = UDim2.fromOffset(14, 14)
			SelBtn.BackgroundTransparency = 1
			SelBtn.BorderSizePixel = 0
			SelBtn.Image = "rbxassetid://138494545053627"
			SelBtn.ImageColor3 = mainColor
			SelBtn.Visible = false
			SelBtn.ZIndex = 1006
			SelBtn.Parent = BtnRow
			selectedBtns[opt] = SelBtn

			local RowBtn = Instance.new("TextButton")
			RowBtn.Size = UDim2.new(1,0,1,0)
			RowBtn.BackgroundTransparency = 1
			RowBtn.Text = ""
			RowBtn.ZIndex = 1005
			RowBtn.Parent = BtnRow
			RowBtn.MouseEnter:Connect(function()
				Tween(BtnRow, { BackgroundTransparency = 0.97 }, 0.08)
			end)
			RowBtn.MouseLeave:Connect(function()
				Tween(BtnRow, { BackgroundTransparency = 1 }, 0.12)
			end)

			local function selectOpt()
				selected = opt
				TextDefault.Text = opt; 
				updateCheckmarks()
				closeDropdown()
				InvokeCallback(callback, opt)
			end
			RowBtn.MouseButton1Click:Connect(selectOpt)
			SelBtn.MouseButton1Click:Connect(selectOpt)
		end

		local OpenBtn = Instance.new("TextButton")
		OpenBtn.Name = "OpenBtn"
		OpenBtn.Size = UDim2.new(1,0,1,0)
		OpenBtn.BackgroundTransparency = 1
		OpenBtn.Text = ""
		OpenBtn.ZIndex = 500
		OpenBtn.Parent = Row

		OpenBtn.MouseButton1Click:Connect(function()
			if dropOpen then closeDropdown()
			else
				CloseAllPopupsExcept(DropPopup)
				dropOpen = true
				local popupH = math.min(#options, 8) * 30 + 10
				DropPopup.Size = UDim2.fromOffset(150, popupH)
				DropPopup.BackgroundTransparency = 0
						DropPopup.Visible = true
				Tween(Arrow, {ImageTransparency = 0}, 0.2)
				WindowObj._centerPopupOnField(DropPopup, TextDefault); SmoothOpen(DropPopup, 0, 0.14); RegisterPopup(DropPopup, closeDropdown, OpenBtn)
			end
		end)

		updateCheckmarks()

		local obj = {}
		function obj:Set(val, silent)
			val = GetValidOption(options, val)
			selected = val
			TextDefault.Text = val
			updateCheckmarks()
			if not silent then InvokeCallback(callback, val) end
		end
		function obj:Get() return selected end
		RegisterConfigElement("usage_selection_", text, obj)
		MakeReadableText(Row, 10, 18)
		return obj
	end

	function UsageObj:AddColorpicker(text, defaultColor, callback)
		usageElemCount = usageElemCount + 1
		local initialColor = NormalizeColor(defaultColor)
		local Row = New("Frame", {
			Name = "Colorpicker",
			Size = UDim2.new(1, 0, 0, 28),
			BackgroundTransparency = 1,
			BorderSizePixel = 0,
			LayoutOrder = usageElemCount,
			ZIndex = 130,
		}, UsageContainer)
		New("TextLabel", {
			Name = "TextToggle",
			Position = UDim2.new(0.04, 0, 0.5, 0),
			AnchorPoint = Vector2.new(0, 0.5),
			Size = UDim2.new(0.65, 0, 0, 18),
			BackgroundTransparency = 1,
			Text = text,
			TextColor3 = Color3.fromRGB(226, 228, 236),
			TextScaled = false,
			TextSize = 14,
			Font = FONT,
			TextXAlignment = Enum.TextXAlignment.Left,
			ZIndex = 130,
		}, Row)
		local cpBtn = New("ImageButton", {
			Name = "colorpickerButton",
			AnchorPoint = Vector2.new(1, 0.5),
			Position = UDim2.new(1, -14, 0.5, 0),
			Size = UDim2.fromOffset(20, 20),
			BackgroundColor3 = initialColor,
			BorderSizePixel = 0,
			Image = "",
			ZIndex = 131,
		}, Row)
		New("UICorner", { CornerRadius = UDim.new(0, 5) }, cpBtn)
		Stroke(cpBtn, "ColorpickerButtonStroke")
		local picker = AcrylicBlur.CreateColorPicker(cpBtn, initialColor, function(c)
			InvokeCallback(callback, c)
		end)
		local obj = {}
		function obj:Set(c)
			local normalized = NormalizeColor(c)
			picker.Set(normalized)
			InvokeCallback(callback, normalized)
		end
		function obj:Get() return picker.Get() end
		RegisterConfigElement("usage_colorpicker_", text, obj)
		MakeReadableText(Row, 10, 18)
		return obj
	end

	function WindowObj:GetUsage() return UsageObj end


	local Tab = New("ScrollingFrame", {
		Name = "Tab",
		Position = UDim2.fromOffset(0, 62),
		Size = UDim2.new(0, 170, 1, -115),
		BackgroundColor3 = Color3.fromRGB(162, 162, 162),
		BorderSizePixel = 0,
		BackgroundTransparency = 1,
		ScrollBarThickness = 0,
		ScrollBarImageTransparency = 0.35,
		Active = true,
		AutomaticCanvasSize = Enum.AutomaticSize.Y,
		CanvasSize = UDim2.new(),
		ScrollingDirection = Enum.ScrollingDirection.Y,
	}, MainFrame)
	New("UIPadding", { PaddingLeft = UDim.new(0, 9), PaddingRight = UDim.new(0, 11) }, Tab)
	New("UIListLayout", {
		Padding = UDim.new(0, 5),
		SortOrder = Enum.SortOrder.LayoutOrder,
	}, Tab)

	

	local Frame2 = New("Frame", {
		Name = "Frame2",
		Position = UDim2.fromOffset(170, 0),
		Size = UDim2.new(1, -170, 1, 0),
		BackgroundColor3 = Color3.fromRGB(15, 17, 24),
		BackgroundTransparency = 0.5,
		BorderSizePixel = 0,
		ClipsDescendants = true,
	}, MainFrame)

	do local c = Instance.new("UICorner"); c.CornerRadius = UDim.new(0, 14); c.Parent = Frame2 end
	-- Glass: the sidebar shows the blurred game through MainFrame (0.25); the
	-- content panel stacks 0.5 on top so it reads denser, as in Neverlose.
	do local panelStroke = Stroke(Frame2, "PanelOutline"); panelStroke.Transparency = 0.94 end
	New("Frame", { Name = "HeaderDivider", Position = UDim2.new(0, 11, 0, 53), Size = UDim2.new(1, -22, 0, 1), BackgroundColor3 = Color3.fromRGB(255, 255, 255), BackgroundTransparency = 0.95, BorderSizePixel = 0 }, Frame2)

	local Header = New("Frame", {
		Name = "Header",
		Size = UDim2.new(1, 0, 0, 54),
		BackgroundColor3 = Color3.fromRGB(162, 162, 162),
		BackgroundTransparency = 1,
		ClipsDescendants = false,
	}, Frame2)

	local SearchBtn = New("ImageButton", {
		Name = "Search",
		AnchorPoint = Vector2.new(1, 0.5),
		Position = UDim2.new(1, -20, 0.5, 0),
		Size = UDim2.fromOffset(18, 18),
		BackgroundColor3 = Color3.fromRGB(162, 162, 162),
		BackgroundTransparency = 1,
		Image = "rbxassetid://6031154871",
		ImageColor3 = Color3.fromRGB(200, 204, 218),
		ImageTransparency = 0.2,
	}, Header)

local asss = Instance.new("UIAspectRatioConstraint")
asss.Parent = SearchBtn


	local function SanitizeConfigName(name)
		name = tostring(name or "Default"):gsub("[^%w%-%_ ]", "_")
		name = name:gsub("^%s+", ""):gsub("%s+$", "")
		if #name == 0 then name = "Default" end
		return name:sub(1, 64)
	end

	local function GetConfigPath(name)
		return "NeverloseConfig_" .. windowConfigId .. "_" .. SanitizeConfigName(name) .. ".json"
	end

	local function SaveNamedConfig(name)
		if type(writefile) ~= "function" then return false end
		local data = {}
		for _, entry in ipairs(_registeredElements) do
			if entry.obj and type(entry.obj.Get) == "function" then
				local ok, value = pcall(function() return entry.obj:Get() end)
				if ok then
					local serialized = SerializeValue(value)
					if serialized ~= nil then data[entry.key] = serialized end
				end
			end
		end
		for key, extra in pairs(WindowObj._configExtras) do
			local okGet, value = pcall(extra.get)
			if okGet and value ~= nil then data["__extra_" .. key] = value end
		end
		local http = game:GetService("HttpService")
		local ok, encoded = pcall(http.JSONEncode, http, data)
		if not ok or type(encoded) ~= "string" then return false end
		local writeOk, writeResult = pcall(writefile, GetConfigPath(name), encoded)
		if writeOk and writeResult ~= false then
			pcall(writefile, "NeverloseConfig_" .. windowConfigId .. "__last.txt", SanitizeConfigName(name))
		end
		return writeOk and writeResult ~= false
	end

	local function LoadNamedConfig(name)
		if type(readfile) ~= "function" or type(isfile) ~= "function" then return false end
		local path = GetConfigPath(name)
		local existsOk, exists = pcall(isfile, path)
		if not existsOk or not exists then return false end
		local ok, content = pcall(readfile, path)
		if not ok or type(content) ~= "string" or #content > 2097152 then return false end
		local http = game:GetService("HttpService")
		local decodedOk, data = pcall(http.JSONDecode, http, content)
		if not decodedOk or type(data) ~= "table" then return false end
		pcall(writefile, "NeverloseConfig_" .. windowConfigId .. "__last.txt", SanitizeConfigName(name))
		local success = true
		for _, entry in ipairs(_registeredElements) do
			local saved = data[entry.key]
			if saved ~= nil then
				if not entry.obj or type(entry.obj.Set) ~= "function" then
					success = false
				else
					local setOk = pcall(function() entry.obj:Set(DeserializeValue(saved)) end)
					if not setOk then success = false end
				end
			end
		end
		-- Extras after the values, so hotkeys see the loaded functions.
		for key, extra in pairs(WindowObj._configExtras) do
			local saved = data["__extra_" .. key]
			if saved ~= nil then pcall(extra.set, saved) end
		end
		return success
	end

	-- Share codes: "NL1:" + base64 of {"name","data"}. Copied from a preset's
	-- menu; pasting one into the "+" name field imports it as a new preset.
	do
		local B64 = "ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz0123456789+/"
		local function encode(data)
			return ((data:gsub(".", function(x)
				local r, b = "", x:byte()
				for i = 8, 1, -1 do r = r .. (b % 2 ^ i - b % 2 ^ (i - 1) > 0 and "1" or "0") end
				return r
			end) .. "0000"):gsub("%d%d%d?%d?%d?%d?", function(x)
				if #x < 6 then return "" end
				local c = 0
				for i = 1, 6 do c = c + (x:sub(i, i) == "1" and 2 ^ (6 - i) or 0) end
				return B64:sub(c + 1, c + 1)
			end) .. ({ "", "==", "=" })[#data % 3 + 1])
		end
		local function decode(data)
			data = data:gsub("[^" .. B64 .. "=]", "")
			return (data:gsub(".", function(x)
				if x == "=" then return "" end
				local r, f = "", (B64:find(x, 1, true) - 1)
				for i = 6, 1, -1 do r = r .. (f % 2 ^ i - f % 2 ^ (i - 1) > 0 and "1" or "0") end
				return r
			end):gsub("%d%d%d?%d?%d?%d?%d?%d?", function(x)
				if #x ~= 8 then return "" end
				local c = 0
				for i = 1, 8 do c = c + (x:sub(i, i) == "1" and 2 ^ (8 - i) or 0) end
				return string.char(c)
			end))
		end
		local http = game:GetService("HttpService")
		WindowObj._makeShareCode = function(name)
			local data
			if type(readfile) == "function" and type(isfile) == "function" then
				local okExists, exists = pcall(isfile, GetConfigPath(name))
				if okExists and exists then
					local okRead, content = pcall(readfile, GetConfigPath(name))
					if okRead and type(content) == "string" then
						local okDecode, decoded = pcall(http.JSONDecode, http, content)
						if okDecode and type(decoded) == "table" then data = decoded end
					end
				end
			end
			if not data then return nil end
			local okEncode, json = pcall(http.JSONEncode, http, { name = name, data = data })
			if not okEncode then return nil end
			return "NL1:" .. encode(json)
		end
		-- Returns the imported preset name, or nil if the text is not a valid code.
		WindowObj._importShareCode = function(text)
			text = tostring(text or ""):gsub("^%s+", ""):gsub("%s+$", "")
			if string.sub(text, 1, 4) ~= "NL1:" or type(writefile) ~= "function" then return nil end
			local okDecode, payload = pcall(function() return http:JSONDecode(decode(string.sub(text, 5))) end)
			if not okDecode or type(payload) ~= "table" or type(payload.data) ~= "table" then return nil end
			local base = SanitizeConfigName(payload.name or "Shared")
			local finalName, n = base, 1
			while type(isfile) == "function" and select(2, pcall(isfile, GetConfigPath(finalName))) == true do
				n = n + 1
				finalName = base .. " (" .. n .. ")"
			end
			local okJson, json = pcall(http.JSONEncode, http, payload.data)
			if not okJson then return nil end
			local okWrite = pcall(writefile, GetConfigPath(finalName), json)
			return okWrite and finalName or nil
		end
	end

	local function ListConfigs()
		if type(listfiles) ~= "function" then return {} end
		local result = {}
		local ok, files = pcall(listfiles, "")
		if not ok or type(files) ~= "table" then return result end
		local prefix = "NeverloseConfig_" .. windowConfigId .. "_"
		for _, fileName in ipairs(files) do
			if type(fileName) == "string" and string.sub(fileName, 1, #prefix) == prefix then
				local name = fileName:match("^" .. prefix .. "(.+)%.json$")
				if name then table.insert(result, name) end
			end
		end
		return result
	end

	

	local GlobalPreset
	local Save = Instance.new("Frame")
	Save.Name = "Save"
	Save.Position = UDim2.fromOffset(11, 13)
	Save.Size = UDim2.fromOffset(150, 28)
	Save.BackgroundColor3 = Color3.fromRGB(20, 23, 34)
	Save.BackgroundTransparency = 0
	Save.BorderSizePixel = 0
	Save.Parent = Header
	do local c = Instance.new("UICorner"); c.CornerRadius = UDim.new(0, 8); c.Parent = Save end
	do Stroke(Save) end
	-- Save is its own square button left of the preset field (a field, not a
	-- local: AddWindow is near the register cap).
	-- Save and preset are one pill (Neverlose): a 32px save segment, a hairline
	-- divider, then the preset name. A field, not a local (register cap).
	WindowObj._saveBox = New("Frame", {
		Name = "SaveSegmentBox", Position = UDim2.fromOffset(0, 0), Size = UDim2.fromOffset(32, 28),
		BackgroundTransparency = 1, BorderSizePixel = 0, ZIndex = Save.ZIndex + 1,
	}, Save)
	New("Frame", {
		Name = "SaveDivider", Position = UDim2.fromOffset(32, 5), Size = UDim2.new(0, 1, 1, -10), BackgroundColor3 = Color3.fromRGB(255, 255, 255),
		BackgroundTransparency = 0.9, BorderSizePixel = 0,
	}, Save)

	local SaveIcon = Instance.new('ImageLabel')
SaveIcon.Name = "SaveIcon"
SaveIcon.AnchorPoint = Vector2.new(0.5, 0.5)
SaveIcon.Position = UDim2.fromScale(0.5, 0.5)
SaveIcon.Size = UDim2.fromOffset(13, 13)
SaveIcon.BackgroundTransparency = 1
SaveIcon.Image = "rbxassetid://6035067857"
SaveIcon.ImageTransparency = 0.20000000298023224
SaveIcon.Parent = WindowObj._saveBox

local UIAspectRatioConstraint = Instance.new('UIAspectRatioConstraint')
UIAspectRatioConstraint.Name = "UIAspectRatioConstraint"
UIAspectRatioConstraint.Parent = SaveIcon

	local SaveText = Instance.new('TextLabel')
	SaveText.Name = "SaveText"
	SaveText.Position = UDim2.fromOffset(43, 0)
	SaveText.Size = UDim2.new(1, -83, 1, 0)
	SaveText.BackgroundTransparency = 1
	SaveText.Text = "Default"
SaveText.TextColor3 = Color3.fromRGB(226, 228, 236)
SaveText.TextScaled = false
SaveText.TextSize = 14
SaveText.Font = FONT
SaveText.TextTransparency = 0.20000000298023224
SaveText.TextXAlignment = Enum.TextXAlignment.Left
SaveText.TextTruncate = Enum.TextTruncate.AtEnd
SaveText.Parent = Save

	local function UpdateSavePillWidth(textValue)
		local textWidth = MeasureText(tostring(textValue or SaveText.Text or "Default"), 15, FONT)
		local width = math.clamp(math.ceil(textWidth) + 43 + 40, 150, 266)
		Save.Size = UDim2.fromOffset(width, 28)
		Save.Position = UDim2.fromOffset(11, 13)
		SaveText.Size = UDim2.new(1, -83, 1, 0)
		if GlobalPreset then GlobalPreset.Position = UDim2.fromOffset(11 + width + 12, 13) end
	end
	UpdateSavePillWidth(SaveText.Text)

	-- Saved: an icon turns into a green check that pops in, holds, then the
	-- icon (and its colour) returns. Used by the header save button and the
	-- loaded preset's save button.
	WindowObj._savedCheck = function(icon)
		if not icon then return end
		local pop = icon:FindFirstChild("SavedPop") or New("UIScale", { Name = "SavedPop", Scale = 1 }, icon)
		local token = (icon:GetAttribute("SavedToken") or 0) + 1
		icon:SetAttribute("SavedToken", token)
		if token == 1 or not icon:GetAttribute("Checking") then
			icon:SetAttribute("RestImage", icon.Image)
			icon:SetAttribute("RestColor", icon.ImageColor3)
		end
		icon:SetAttribute("Checking", true)
		icon.Image = "rbxassetid://10709790644" -- lucide check
		icon.ImageColor3 = Color3.fromRGB(120, 220, 150)
		pop.Scale = 0.4
		Tween(pop, { Scale = 1 }, 0.32, Enum.EasingStyle.Back, Enum.EasingDirection.Out)
		task.delay(1.3, function()
			if icon:GetAttribute("SavedToken") ~= token then return end
			Tween(pop, { Scale = 0.6 }, 0.12, Enum.EasingStyle.Quad, Enum.EasingDirection.In)
			task.delay(0.12, function()
				if icon:GetAttribute("SavedToken") ~= token then return end
				icon.Image = icon:GetAttribute("RestImage")
				icon.ImageColor3 = icon:GetAttribute("RestColor")
				icon:SetAttribute("Checking", false)
				Tween(pop, { Scale = 1 }, 0.2, Enum.EasingStyle.Back, Enum.EasingDirection.Out)
			end)
		end)
	end
	local function FlashSaved()
		WindowObj._savedCheck(SaveIcon)
	end
	local function ShowSavedName()
		if not SaveText then return end
		SaveText.Text = activeConfigName or "Default"
		UpdateSavePillWidth(SaveText.Text)
	end

local Lines = Instance.new('Frame')
Lines.Name = "Lines"
Lines.Position = UDim2.new(0, -10, 0.15, 0)
Lines.Size = UDim2.new(0, 1, 0.70, 0)
Lines.BackgroundColor3 = Color3.fromRGB(255,255,255)
Lines.BackgroundTransparency = 0.92
Lines.BorderSizePixel = 0
Lines.Parent = SaveText
Lines.Visible = false

local Lines_2 = Instance.new('Frame')
Lines_2.Name = "Lines"
Lines_2.Position = UDim2.new(1,0,-0.19000010192394257,0)
Lines_2.Size = UDim2.new(-0.0010000000474974513,1,1.2000000476837158,3)
Lines_2.Visible = false
Lines_2.BackgroundColor3 = Color3.fromRGB(255,255,255)
Lines_2.BackgroundTransparency = 1
Lines_2.BorderSizePixel = 0
Lines_2.Parent = SaveText

local SaveArrow = Instance.new('ImageLabel')
SaveArrow.Name = "PresetArrow"
SaveArrow.AnchorPoint = Vector2.new(1, 0.5)
SaveArrow.Position = UDim2.new(1, -17, 0.5, 0)
-- Full white, 12px: at 10px the thin chevron read grey.
SaveArrow.Size = UDim2.fromOffset(12, 12)
SaveArrow.ImageTransparency = 0
SaveArrow.BackgroundTransparency = 1
SaveArrow.Image = "rbxassetid://10709790948"
SaveArrow.ImageColor3 = Color3.fromRGB(255,255,255)
SaveArrow.ScaleType = Enum.ScaleType.Fit
SaveArrow.Rotation = 0
SaveArrow.ZIndex = 15
SaveArrow.Parent = Save

GlobalPreset = New("Frame", {
	Name = "GlobalPreset",
	Position = UDim2.fromOffset(178, 13),
	Size = UDim2.fromOffset(83, 28),
	BackgroundColor3 = Color3.fromRGB(20, 23, 34),
	BackgroundTransparency = 0,
	BorderSizePixel = 0,
}, Header)
New("UICorner", { CornerRadius = UDim.new(0, 8) }, GlobalPreset)
Stroke(GlobalPreset)
New("TextLabel", {
	Name = "GlobalPresetLabel",
	Position = UDim2.fromOffset(11, 0),
	Size = UDim2.new(1, -34, 1, 0),
	BackgroundTransparency = 1,
	Text = "Global",
	TextColor3 = Color3.fromRGB(226, 228, 236),
	TextSize = 14,
	Font = FONT,
	TextXAlignment = Enum.TextXAlignment.Left,
	TextTruncate = Enum.TextTruncate.AtEnd,
}, GlobalPreset)
New("ImageLabel", {
	Name = "GlobalPresetArrow",
	AnchorPoint = Vector2.new(1, 0.5),
	Position = UDim2.new(1, -12, 0.5, 0),
	Size = UDim2.fromOffset(10, 10),
	BackgroundTransparency = 1,
	Image = "rbxassetid://10709790948",
	ImageColor3 = Color3.fromRGB(150, 155, 172),
	ScaleType = Enum.ScaleType.Fit,
	Rotation = 0,
}, GlobalPreset)
GlobalPreset.Visible = false
UpdateSavePillWidth(SaveText.Text)
local function ShouldShowGlobalPreset(tabName)
	local normalized = string.lower(tostring(tabName or ""))
	return string.find(normalized, "legit", 1, true) ~= nil
		or string.find(normalized, "rage", 1, true) ~= nil
end

local UIAspectRatioConstraint = Instance.new('UIAspectRatioConstraint')
UIAspectRatioConstraint.Name = "UIAspectRatioConstraint"
UIAspectRatioConstraint.AspectRatio = 1
UIAspectRatioConstraint.AspectType = Enum.AspectType.ScaleWithParentSize
UIAspectRatioConstraint.Parent = SaveArrow


	local TriggerSaveConfig = Instance.new("TextButton")
	TriggerSaveConfig.Name = "TriggerSaveConfig"
	TriggerSaveConfig.Size = UDim2.new(1, 0, 1, 0)
	TriggerSaveConfig.BackgroundTransparency = 1
	TriggerSaveConfig.Text = ""
	TriggerSaveConfig.ZIndex = 15
	TriggerSaveConfig.Parent = Save

	local ConfigMainFrame = Instance.new("Frame")
	ConfigMainFrame.Name = "ConfigMainFrame"
	ConfigMainFrame.Position = UDim2.fromOffset(11, 47)
	ConfigMainFrame.Size = UDim2.fromOffset(320, 104) -- Neverlose presets panel is ~320 wide
	ConfigMainFrame.BackgroundColor3 = Color3.fromRGB(18, 18, 26) -- Neverlose presets panel
	ConfigMainFrame.BackgroundTransparency = 0.045
	ConfigMainFrame.BorderSizePixel = 0
	ConfigMainFrame.ZIndex = 110
	ConfigMainFrame.AutomaticSize = Enum.AutomaticSize.None
	ConfigMainFrame.ClipsDescendants = false
	ConfigMainFrame.Active = true
	ConfigMainFrame.Visible = false
	ConfigMainFrame.Parent = Frame2
	local ConfigScale = Instance.new("UIScale")
	ConfigScale.Scale = 1
	ConfigScale.Parent = ConfigMainFrame
	do local c = Instance.new("UICorner"); c.CornerRadius = UDim.new(0, 10); c.Parent = ConfigMainFrame end
	do Stroke(ConfigMainFrame) end
	AttachShadow(ConfigMainFrame, { radius = 10, layers = 4, step = 1.25, bias = 2 })

	local CMHeader = Instance.new("Frame")
	CMHeader.Name = "Header"
	CMHeader.Size = UDim2.new(1, 0, 0, 44)
	CMHeader.BackgroundColor3 = Color3.fromRGB(17, 19, 27)
	-- Same surface as the panel: an opaque header read as a separate band.
	CMHeader.BackgroundTransparency = 1
	CMHeader.BorderSizePixel = 0
	CMHeader.ClipsDescendants = true
	CMHeader.ZIndex = 100
	CMHeader.Parent = ConfigMainFrame
	do local c = Instance.new("UICorner"); c.CornerRadius = UDim.new(0, 10); c.Parent = CMHeader end

	do
		local CMHeaderRule = Instance.new("Frame")
		CMHeaderRule.Name = "HeaderRule"
		CMHeaderRule.Position = UDim2.new(0, 14, 1, -1)
		CMHeaderRule.Size = UDim2.new(1, -28, 0, 1)
		CMHeaderRule.BackgroundColor3 = Color3.fromRGB(255, 255, 255)
		CMHeaderRule.BackgroundTransparency = 0.92
		CMHeaderRule.BorderSizePixel = 0
		CMHeaderRule.ZIndex = 1000
		CMHeaderRule.Parent = CMHeader
	end

	local CloudIcon = Instance.new("ImageLabel")
	CloudIcon.Name = "CloudIcon"
	CloudIcon.AnchorPoint = Vector2.new(0, 0.5)
	CloudIcon.Position = UDim2.new(0, 16, 0.5, 0)
	CloudIcon.Size = UDim2.fromOffset(18, 18)
	CloudIcon.BackgroundTransparency = 1
	CloudIcon.Image = "rbxassetid://97828544806816"
	CloudIcon.ImageColor3 = mainColor
	CloudIcon.ScaleType = Enum.ScaleType.Fit
	CloudIcon.ZIndex = 1000
	CloudIcon.Parent = CMHeader
	-- The asset reads as a folder; Neverlose's PRESETS tab has a cloud. Draw it
	-- from rounded frames instead (two puffs over a rounded base).
	CloudIcon.Image = ""
	do
		local tint = mainColor:Lerp(Color3.new(1, 1, 1), 0.35)
		for _, part in ipairs({
			{ UDim2.fromOffset(1, 8), UDim2.fromOffset(16, 7), UDim.new(0, 4) },
			{ UDim2.fromOffset(2, 5), UDim2.fromOffset(8, 8), UDim.new(1, 0) },
			{ UDim2.fromOffset(6, 2), UDim2.fromOffset(10, 10), UDim.new(1, 0) },
		}) do
			local piece = Instance.new("Frame")
			piece.Name = "CloudPart"
			piece.Position = part[1]
			piece.Size = part[2]
			piece.BackgroundColor3 = tint
			piece.BorderSizePixel = 0
			piece.ZIndex = 1001
			piece.Parent = CloudIcon
			local c = Instance.new("UICorner"); c.CornerRadius = part[3]; c.Parent = piece
		end
	end
	do
		local tabPill = Instance.new("Frame")
		tabPill.Name = "PresetsTabPill"
		tabPill.AnchorPoint = Vector2.new(0, 0.5)
		tabPill.Position = UDim2.new(0, 9, 0.5, 0)
		tabPill.Size = UDim2.fromOffset(104, 28)
		tabPill.BackgroundColor3 = mainColor
		tabPill.BackgroundTransparency = 0.86
		tabPill.BorderSizePixel = 0
		tabPill.ZIndex = 999
		tabPill.Parent = CMHeader
		local c = Instance.new("UICorner"); c.CornerRadius = UDim.new(0, 7); c.Parent = tabPill
	end

	local CMTitle = Instance.new("TextLabel")
	CMTitle.Name = "TitleLabel"
	CMTitle.Position = UDim2.new(0, 44, 0, 0)
	CMTitle.Size = UDim2.new(1, -154, 1, 0)
	CMTitle.BackgroundTransparency = 1
	-- Neverlose shows the active tab as an accent-tinted pill: cloud + "PRESETS".
	CMTitle.Text = "PRESETS"
	CMTitle.TextColor3 = mainColor:Lerp(Color3.new(1, 1, 1), 0.35)
	CMTitle.TextSize = 13
	CMTitle.Font = FONT_BOLD
	CMTitle.TextTransparency = 0.05
	CMTitle.ZIndex = 1000
	CMTitle.TextXAlignment = Enum.TextXAlignment.Left
	CMTitle.Parent = CMHeader

	local CMHeaderRight = Instance.new("Frame")
	CMHeaderRight.Name = "HeaderRight"
	CMHeaderRight.AnchorPoint = Vector2.new(1, 0)
	CMHeaderRight.Position = UDim2.new(1, -14, 0, 0)
	CMHeaderRight.Size = UDim2.fromOffset(96, 44)
	CMHeaderRight.BackgroundTransparency = 1
	CMHeaderRight.ZIndex = 1000
	CMHeaderRight.Parent = CMHeader
	do
		local ll = Instance.new("UIListLayout")
		ll.FillDirection = Enum.FillDirection.Horizontal
		ll.HorizontalAlignment = Enum.HorizontalAlignment.Right
		ll.VerticalAlignment = Enum.VerticalAlignment.Center
		ll.Padding = UDim.new(0, 10)
		ll.SortOrder = Enum.SortOrder.LayoutOrder
		ll.Parent = CMHeaderRight
	end

	local IDLE_ICON_TINT = Color3.fromRGB(176, 180, 198)
	local autoSaveEnabled = false
	local AutoSaveBtn, RecentlyDeletedBtn, InsertConfigBtn
	do
		local function HeaderIconButton(name, asset, order)
			local btn = Instance.new("ImageButton")
			btn.Name = name
			btn.Size = UDim2.fromOffset(18, 18)
			btn.BackgroundTransparency = 1
			btn.Image = asset
			btn.ImageColor3 = IDLE_ICON_TINT
			btn.ScaleType = Enum.ScaleType.Fit
			btn.ZIndex = 1000
			btn.LayoutOrder = order
			btn.Parent = CMHeaderRight
			btn.MouseEnter:Connect(function()
				Tween(btn, { ImageColor3 = Color3.fromRGB(255, 255, 255) }, 0.1)
			end)
			btn.MouseLeave:Connect(function()
				if btn:GetAttribute("Pinned") ~= true then
					Tween(btn, { ImageColor3 = IDLE_ICON_TINT }, 0.15)
				end
			end)
			return btn
		end

		AutoSaveBtn = HeaderIconButton("AutomaticSave", "rbxassetid://122894934359450", 1)
		RecentlyDeletedBtn = HeaderIconButton("RecentlyDeleted", "rbxassetid://3926305904", 2)
		RecentlyDeletedBtn.ImageRectOffset = Vector2.new(805, 45)
		RecentlyDeletedBtn.ImageRectSize = Vector2.new(35, 35)
		InsertConfigBtn = HeaderIconButton("InsertConfig", "rbxassetid://101123124881873", 3)
	end

	local SearchContainer = Instance.new("Frame")
	SearchContainer.Name = "SearchContainer"
	SearchContainer.Position = UDim2.new(0, 12, 0, 50)
	SearchContainer.Size = UDim2.new(1, -52, 0, 30) -- room for the sort button on the right
	SearchContainer.BackgroundColor3 = Color3.fromRGB(26, 26, 38)
	SearchContainer.BorderSizePixel = 0
	SearchContainer.ZIndex = 1000
	SearchContainer.Parent = ConfigMainFrame
	do local c = Instance.new("UICorner"); c.CornerRadius = UDim.new(0, 8); c.Parent = SearchContainer end
	do Stroke(SearchContainer) end

	local SearchIconImg = Instance.new("ImageLabel")
	SearchIconImg.Name = "SearchIcon"
	SearchIconImg.AnchorPoint = Vector2.new(0, 0.5)
	SearchIconImg.Position = UDim2.new(0, 10, 0.5, 0)
	SearchIconImg.Size = UDim2.fromOffset(16, 16)
	SearchIconImg.BackgroundTransparency = 1
	SearchIconImg.Image = "rbxassetid://6031154871"
	SearchIconImg.ImageColor3 = Color3.fromRGB(130, 134, 152)
	SearchIconImg.ScaleType = Enum.ScaleType.Fit
	SearchIconImg.ZIndex = 1000
	SearchIconImg.Parent = SearchContainer

	local ConfigSearchBox = Instance.new("TextBox")
	ConfigSearchBox.Name = "SearchBox"
	ConfigSearchBox.Position = UDim2.new(0, 34, 0, 0)
	ConfigSearchBox.Size = UDim2.new(1, -44, 1, 0)
	ConfigSearchBox.BackgroundTransparency = 1
	ConfigSearchBox.Text = ""
	ConfigSearchBox.PlaceholderText = "Search"
	ConfigSearchBox.PlaceholderColor3 = Color3.fromRGB(130, 134, 152)
	ConfigSearchBox.TextColor3 = Color3.fromRGB(228, 230, 238)
	ConfigSearchBox.TextSize = 14
	ConfigSearchBox.Font = FONT
	ConfigSearchBox.ZIndex = 1000
	ConfigSearchBox.TextXAlignment = Enum.TextXAlignment.Left
	ConfigSearchBox.ClearTextOnFocus = false
	ConfigSearchBox.Parent = SearchContainer

	local NameInputContainer = Instance.new("Frame")
	NameInputContainer.Name = "NameInputContainer"
	NameInputContainer.Position = UDim2.new(0, 12, 0, 50)
	NameInputContainer.Size = UDim2.new(1, -52, 0, 30)
	NameInputContainer.BackgroundColor3 = Color3.fromRGB(26, 26, 38)
	NameInputContainer.BorderSizePixel = 0
	NameInputContainer.ZIndex = 1001
	NameInputContainer.Visible = false
	NameInputContainer.Parent = ConfigMainFrame
	do local c = Instance.new("UICorner"); c.CornerRadius = UDim.new(0, 8); c.Parent = NameInputContainer end
	do Stroke(NameInputContainer) end

	local NameOfConfig = Instance.new("TextBox")
	NameOfConfig.Name = "NameOfConfig"
	NameOfConfig.Position = UDim2.new(0, 12, 0, 0)
	NameOfConfig.Size = UDim2.new(1, -96, 1, 0)
	NameOfConfig.BackgroundTransparency = 1
	NameOfConfig.Text = ""
	NameOfConfig.PlaceholderText = "Name or share code..."
	NameOfConfig.PlaceholderColor3 = Color3.fromRGB(130, 134, 152)
	NameOfConfig.TextColor3 = Color3.fromRGB(228, 230, 238)
	NameOfConfig.TextSize = 14
	NameOfConfig.Font = FONT
	NameOfConfig.ZIndex = 1001
	NameOfConfig.TextXAlignment = Enum.TextXAlignment.Left
	NameOfConfig.ClearTextOnFocus = false
	NameOfConfig.Parent = NameInputContainer

	local ConfirmAddBtn = Instance.new("TextButton")
	ConfirmAddBtn.Name = "ConfirmAdd"
	ConfirmAddBtn.AnchorPoint = Vector2.new(1, 0.5)
	ConfirmAddBtn.Position = UDim2.new(1, -14, 0.5, 0)
	ConfirmAddBtn.Size = UDim2.new(0, 72, 0, 24)
	ConfirmAddBtn.BackgroundColor3 = mainColor
	ConfirmAddBtn.BackgroundTransparency = 0.1
	ConfirmAddBtn.Text = "Create"
	ConfirmAddBtn.TextColor3 = Color3.fromRGB(255, 255, 255)
	ConfirmAddBtn.TextSize = 12
	ConfirmAddBtn.Font = FONT
	ConfirmAddBtn.ZIndex = 1002
	ConfirmAddBtn.Parent = NameInputContainer
	do local c = Instance.new("UICorner"); c.CornerRadius = UDim.new(0, 6); c.Parent = ConfirmAddBtn end

	local ListContainer = Instance.new("ScrollingFrame")
	ListContainer.Name = "ListContainer"
	ListContainer.Position = UDim2.new(0, 10, 0, 90)
	ListContainer.Size = UDim2.new(1, -16, 1, -98)
	ListContainer.BackgroundTransparency = 1
	ListContainer.BorderSizePixel = 0
	ListContainer.ZIndex = 100
	ListContainer.Active = true
	ListContainer.AutomaticCanvasSize = Enum.AutomaticSize.Y
	ListContainer.CanvasSize = UDim2.new()
	ListContainer.ScrollingDirection = Enum.ScrollingDirection.Y
	ListContainer.ScrollBarThickness = 2
	ListContainer.ScrollBarImageColor3 = Color3.fromRGB(110, 112, 124)
	ListContainer.ScrollBarImageTransparency = 0.3
	ListContainer.Parent = ConfigMainFrame
	ListContainer.ClipsDescendants = true
	do
		local ll = Instance.new("UIListLayout")
		ll.Name = "UIListLayout"
		ll.Padding = UDim.new(0, 4)
		ll.SortOrder = Enum.SortOrder.LayoutOrder
		ll.Parent = ListContainer
		-- Bottom padding: without it the last row's outline sat on the clip edge
		-- and was cut off.
		New("UIPadding", { PaddingRight = UDim.new(0, 8), PaddingTop = UDim.new(0, 2), PaddingLeft = UDim.new(0, 2), PaddingBottom = UDim.new(0, 6) }, ListContainer)
	end
	-- Sort button beside the search field (Neverlose has one): A-Z / Z-A by name.
	do
		local sortDesc = false
		local function applyConfigSort()
			local rows = {}
			for _, c in ipairs(ListContainer:GetChildren()) do
				if c:IsA("Frame") and string.sub(c.Name, 1, 10) == "ConfigRow_" then table.insert(rows, c) end
			end
			table.sort(rows, function(a, b)
				local x, y = string.lower(a.Name), string.lower(b.Name)
				if sortDesc then return x > y end
				return x < y
			end)
			for index, row in ipairs(rows) do row.LayoutOrder = index end
		end
		ListContainer.ChildAdded:Connect(function() task.defer(applyConfigSort) end)
		local sortBtn = New("TextButton", {
			Name = "SortButton",
			AnchorPoint = Vector2.new(1, 0),
			Position = UDim2.new(1, -10, 0, 50),
			Size = UDim2.fromOffset(30, 30),
			BackgroundTransparency = 1,
			Text = "⇅",
			TextColor3 = Color3.fromRGB(150, 154, 166),
			TextSize = 17,
			AutoButtonColor = false,
			ZIndex = 1000,
		}, ConfigMainFrame)
		sortBtn.MouseEnter:Connect(function() Tween(sortBtn, { TextColor3 = Color3.fromRGB(235, 236, 241) }, 0.1) end)
		sortBtn.MouseLeave:Connect(function() Tween(sortBtn, { TextColor3 = Color3.fromRGB(150, 154, 166) }, 0.12) end)
		sortBtn.MouseButton1Click:Connect(function()
			sortDesc = not sortDesc
			applyConfigSort()
		end)
	end

	local Space = Instance.new("Frame")
	Space.Name = "Space"
	Space.Size = UDim2.new(1, 0, 0, 0)
	Space.BackgroundTransparency = 1
	Space.ZIndex = 100
	Space.Parent = ListContainer

	local SAVE_ICON = "rbxassetid://122894934359450"
	local LOAD_ICON = "rbxassetid://109698732019071"

	local DELETED_FILE = "NeverloseDeleted_" .. windowConfigId .. ".json"
	local _deletedConfigs = {}

	local function LoadDeletedList()
		if type(readfile) ~= "function" or type(isfile) ~= "function" then return end
		local existsOk, exists = pcall(isfile, DELETED_FILE)
		if not existsOk or not exists then return end
		local ok, content = pcall(readfile, DELETED_FILE)
		if not ok or not content then return end
		local dok, data = pcall(game:GetService("HttpService").JSONDecode, game:GetService("HttpService"), content)
		if dok and type(data) == "table" then
			local safe = {}
			for _, entry in ipairs(data) do
				if type(entry) == "table" and type(entry.name) == "string" and type(entry.data) == "table" then
					table.insert(safe, {name = SanitizeConfigName(entry.name), data = entry.data})
				end
			end
			while #safe > 20 do table.remove(safe) end
			_deletedConfigs = safe
		end
	end

	local function SaveDeletedList()
		if type(writefile) ~= "function" then return end
		local ok, encoded = pcall(game:GetService("HttpService").JSONEncode, game:GetService("HttpService"), _deletedConfigs)
		if ok then pcall(writefile, DELETED_FILE, encoded) end
	end

	LoadDeletedList()

	local RecentlyDeletedPanel = Instance.new("Frame")
	RecentlyDeletedPanel.Name = "RecentlyDeletedPanel"
	RecentlyDeletedPanel.Position = UDim2.new(0.012, 0, 0.075, 0)
	RecentlyDeletedPanel.Size = UDim2.new(0.34, 0, 0.42, 0)
	RecentlyDeletedPanel.BackgroundColor3 = Color3.fromRGB(17, 19, 27)
	RecentlyDeletedPanel.BackgroundTransparency = 0.045
	RecentlyDeletedPanel.BorderSizePixel = 0
	RecentlyDeletedPanel.ZIndex = 120
	RecentlyDeletedPanel.AutomaticSize = Enum.AutomaticSize.None
	RecentlyDeletedPanel.ClipsDescendants = false
	RecentlyDeletedPanel.Active = true
	RecentlyDeletedPanel.Visible = false
	RecentlyDeletedPanel.Parent = Frame2
	do local c = Instance.new("UICorner"); c.CornerRadius = UDim.new(0, 10); c.Parent = RecentlyDeletedPanel end
	do Stroke(RecentlyDeletedPanel) end
	AttachShadow(RecentlyDeletedPanel, { radius = 10, layers = 4, step = 1.25, bias = 2 })

	local RDHeader = Instance.new("Frame")
	RDHeader.Name = "RDHeader"
	RDHeader.Size = UDim2.new(1, 0, 0, 46)
	RDHeader.BackgroundColor3 = Color3.fromRGB(17, 19, 27)
	RDHeader.BorderSizePixel = 0
	RDHeader.ClipsDescendants = true
	RDHeader.ZIndex = 121
	RDHeader.Parent = RecentlyDeletedPanel
	do local c = Instance.new("UICorner"); c.CornerRadius = UDim.new(0, 10); c.Parent = RDHeader end
	do
		local rule = Instance.new("Frame")
		rule.Name = "HeaderRule"
		rule.Position = UDim2.new(0, 14, 1, -1)
		rule.Size = UDim2.new(1, -28, 0, 1)
		rule.BackgroundColor3 = Color3.fromRGB(255, 255, 255)
		rule.BackgroundTransparency = 0.92
		rule.BorderSizePixel = 0
		rule.ZIndex = 122
		rule.Parent = RDHeader
	end

	local RDTitle = Instance.new("TextLabel")
	RDTitle.Name = "RDTitle"
	RDTitle.Position = UDim2.new(0, 16, 0, 0)
	RDTitle.Size = UDim2.new(1, -130, 1, 0)
	RDTitle.BackgroundTransparency = 1
	RDTitle.Text = "Recently Deleted"
	RDTitle.TextColor3 = Color3.fromRGB(255, 100, 100)
	RDTitle.TextSize = 14
	RDTitle.Font = FONT
	RDTitle.TextXAlignment = Enum.TextXAlignment.Left
	RDTitle.ZIndex = 122
	RDTitle.Parent = RDHeader

	local RDBackBtn = Instance.new("TextButton")
	RDBackBtn.Name = "RDBackBtn"
	RDBackBtn.AnchorPoint = Vector2.new(1, 0.5)
	RDBackBtn.Position = UDim2.new(1, -14, 0.5, 0)
	RDBackBtn.Size = UDim2.fromOffset(84, 26)
	RDBackBtn.BackgroundColor3 = Color3.fromRGB(28, 31, 44)
	RDBackBtn.BackgroundTransparency = 0.1
	RDBackBtn.Text = "← Back"
	RDBackBtn.TextColor3 = Color3.fromRGB(210, 212, 222)
	RDBackBtn.TextSize = 12
	RDBackBtn.Font = FONT
	RDBackBtn.ZIndex = 122
	RDBackBtn.Parent = RDHeader
	do local c = Instance.new("UICorner"); c.CornerRadius = UDim.new(0, 6); c.Parent = RDBackBtn end

	local RDList = Instance.new("ScrollingFrame")
	RDList.Name = "RDList"
	RDList.Position = UDim2.new(0, 14, 0, 60)
	RDList.Size = UDim2.new(1, -28, 1, -74)
	RDList.BackgroundTransparency = 1
	RDList.BorderSizePixel = 0
	RDList.ZIndex = 121
	RDList.Active = true
	RDList.AutomaticCanvasSize = Enum.AutomaticSize.Y
	RDList.CanvasSize = UDim2.new()
	RDList.ScrollingDirection = Enum.ScrollingDirection.Y
	RDList.ScrollBarThickness = 3
	RDList.ScrollBarImageTransparency = 0.35
	RDList.Parent = RecentlyDeletedPanel
	do local ll = Instance.new("UIListLayout"); ll.Padding = UDim.new(0, 6); ll.Parent = RDList end

	-- Neverlose recently-deleted list: plain cards with the name, a red bin
	-- (delete for good) and a restore arrow; no header bar.
	RDHeader.Visible = false
	RDList.Position = UDim2.fromOffset(8, 8)
	RDList.Size = UDim2.new(1, -16, 1, -16)
	RDList.ScrollBarThickness = 2
	RecentlyDeletedPanel.BackgroundColor3 = Color3.fromRGB(18, 18, 26)
	RecentlyDeletedPanel.BackgroundTransparency = 0
	local function RefreshDeletedList()
		for _, c in ipairs(RDList:GetChildren()) do
			if c:IsA("GuiObject") then c:Destroy() end
		end
		if #_deletedConfigs == 0 then
			New("TextLabel", {
				Name = "EmptyState", Size = UDim2.new(1, 0, 0, 38), BackgroundTransparency = 1,
				Text = "Nothing deleted", TextColor3 = Color3.fromRGB(130, 134, 148), TextSize = 14, ZIndex = 123,
			}, RDList)
		end
		for i = #_deletedConfigs, 1, -1 do
			local entry = _deletedConfigs[i]
			local drow = New("Frame", {
				Name = "DeletedRow", Size = UDim2.new(1, 0, 0, 38), BackgroundColor3 = Color3.fromRGB(21, 21, 29),
				BorderSizePixel = 0, ZIndex = 122,
			}, RDList)
			New("UICorner", { CornerRadius = UDim.new(0, 8) }, drow)
			Stroke(drow).Transparency = 0.95
			New("TextLabel", {
				Name = "DeletedName", Position = UDim2.fromOffset(14, 0), Size = UDim2.new(1, -80, 1, 0), BackgroundTransparency = 1,
				Text = entry.name, TextColor3 = Color3.fromRGB(214, 216, 224), TextSize = 14,
				TextXAlignment = Enum.TextXAlignment.Left, TextTruncate = Enum.TextTruncate.AtEnd, ZIndex = 123,
			}, drow)
			local function iconButton(kind, color, x)
				local btn = New("TextButton", {
					Name = kind, AnchorPoint = Vector2.new(1, 0.5), Position = UDim2.new(1, x, 0.5, 0), Size = UDim2.fromOffset(22, 22),
					BackgroundColor3 = Color3.fromRGB(255, 255, 255), BackgroundTransparency = 1, AutoButtonColor = false, Text = "", ZIndex = 124,
				}, drow)
				New("UICorner", { CornerRadius = UDim.new(0, 6) }, btn)
				local glyph = New("Frame", { Name = "Glyph", Position = UDim2.fromOffset(4, 4), Size = UDim2.fromOffset(14, 14), BackgroundTransparency = 1, ZIndex = 125 }, btn)
				WindowObj._drawGlyph(kind, glyph, color)
				btn.MouseEnter:Connect(function() Tween(btn, { BackgroundTransparency = 0.97 }, 0.08) end)
				btn.MouseLeave:Connect(function() Tween(btn, { BackgroundTransparency = 1 }, 0.1) end)
				return btn
			end
			local purgeBtn = iconButton("trash", Color3.fromRGB(233, 90, 110), -36)
			local restoreBtn = iconButton("restore", Color3.fromRGB(200, 203, 213), -10)

			local idx = i
			purgeBtn.MouseButton1Click:Connect(function()
				-- Already removed from disk on delete; this only forgets the backup.
				table.remove(_deletedConfigs, idx)
				SaveDeletedList()
				RefreshDeletedList()
			end)
			restoreBtn.MouseButton1Click:Connect(function()
				local restored = false
				local encodedOk, encoded = pcall(game:GetService("HttpService").JSONEncode, game:GetService("HttpService"), entry.data)
				if encodedOk and type(encoded) == "string" and type(writefile) == "function" then
					local writeOk, writeResult = pcall(writefile, GetConfigPath(entry.name), encoded)
					restored = writeOk and writeResult ~= false
				end
				if restored then
					table.remove(_deletedConfigs, idx)
					SaveDeletedList()
					RefreshDeletedList()
				end
			end)
		end

	end

	local closeConfigPanel
	local configOpen = false
	RDBackBtn.MouseButton1Click:Connect(function()
		UnregisterPopup(RecentlyDeletedPanel)
		Tween(RecentlyDeletedPanel, {BackgroundTransparency = 1}, 0.2)
		task.delay(0.22, function()
			if not configOpen then return end
			RecentlyDeletedPanel.Visible = false
			ConfigMainFrame.BackgroundTransparency = 1
			ConfigMainFrame.Visible = true
			ConstrainPopupToMainFrame(ConfigMainFrame); task.defer(function() ConstrainPopupToMainFrame(ConfigMainFrame) end); RegisterPopup(ConfigMainFrame, closeConfigPanel, TriggerSaveConfig)
			ConfigScale.Scale = 0.94
			Tween(ConfigScale, { Scale = 1 }, 0.16, Enum.EasingStyle.Quint, Enum.EasingDirection.Out)
			Tween(ConfigMainFrame, { BackgroundTransparency = 0.045 }, 0.15, Enum.EasingStyle.Quad, Enum.EasingDirection.Out)
		end)
	end)

	local activeRow = nil
	local activeLoadBtn = nil
	local activeConfigName = nil

	-- Header controls, Neverlose-style: the save icon is its own button (saves
	-- the loaded preset), every segment lights up on hover like the tabs, and
	-- "Global" opens the Weapon Presets list.
	do
		local function hoverPlate(parent, position, size)
			local plate = New("Frame", {
				Name = "HoverPlate", Position = position, Size = size, BackgroundColor3 = Color3.fromRGB(255, 255, 255),
				BackgroundTransparency = 1, BorderSizePixel = 0, ZIndex = 14,
			}, parent)
			New("UICorner", { CornerRadius = UDim.new(0, 8) }, plate)
			return plate
		end
		local function bindHover(target, plate)
			target.MouseEnter:Connect(function() Tween(plate, { BackgroundTransparency = 0.97 }, 0.1) end)
			target.MouseLeave:Connect(function() Tween(plate, { BackgroundTransparency = 1 }, 0.14) end)
		end

		local savePlate = hoverPlate(WindowObj._saveBox, UDim2.fromOffset(0, 0), UDim2.fromScale(1, 1))
		local namePlate = hoverPlate(Save, UDim2.fromOffset(33, 0), UDim2.new(1, -33, 1, 0))
		local saveButton = New("TextButton", {
			Name = "SaveSegment", Size = UDim2.fromScale(1, 1), BackgroundTransparency = 1, Text = "", ZIndex = 16,
		}, WindowObj._saveBox)
		bindHover(saveButton, savePlate)
		TriggerSaveConfig.MouseEnter:Connect(function() Tween(namePlate, { BackgroundTransparency = 0.97 }, 0.1) end)
		TriggerSaveConfig.MouseLeave:Connect(function() Tween(namePlate, { BackgroundTransparency = 1 }, 0.14) end)
		-- Saves into the selected preset; with none selected, into "Default".
		saveButton.MouseButton1Click:Connect(function()
			if SaveNamedConfig(activeConfigName or "Default") then
				FlashSaved()
			end
		end)

		-- Weapon Presets popup under "Global".
		local presets = { "Global" }
		local selectedPreset = "Global"
		local globalPlate = hoverPlate(GlobalPreset, UDim2.fromOffset(0, 0), UDim2.fromScale(1, 1))
		local globalHit = New("TextButton", {
			Name = "GlobalPresetHit", Size = UDim2.fromScale(1, 1), BackgroundTransparency = 1, Text = "", ZIndex = 16,
		}, GlobalPreset)
		bindHover(globalHit, globalPlate)

		local popup = New("Frame", {
			Name = "WeaponPresets", Position = UDim2.new(0, 0, 1, 6),
			Size = UDim2.fromOffset(230, 0), AutomaticSize = Enum.AutomaticSize.Y,
			BackgroundColor3 = Color3.fromRGB(18, 18, 27), BorderSizePixel = 0, Visible = false, ZIndex = 120,
		}, GlobalPreset)
		New("UICorner", { CornerRadius = UDim.new(0, 10) }, popup)
		Stroke(popup)
		AttachShadow(popup, { radius = 10, layers = 5, step = 1.6, bias = 3 })
		New("TextLabel", {
			Name = "PlateTitle", Position = UDim2.fromOffset(14, 10), Size = UDim2.new(1, -60, 0, 20), BackgroundTransparency = 1,
			Text = "Weapon Presets", TextColor3 = Color3.fromRGB(226, 227, 233), TextSize = 15,
			TextXAlignment = Enum.TextXAlignment.Left, ZIndex = 121,
		}, popup)
		local addBtn = New("TextButton", {
			Name = "AddPreset", AnchorPoint = Vector2.new(1, 0), Position = UDim2.new(1, -10, 0, 8), Size = UDim2.fromOffset(24, 24),
			BackgroundTransparency = 1, Text = "+", TextColor3 = Color3.fromRGB(200, 203, 213), TextSize = 20, ZIndex = 122,
		}, popup)
		local list = New("Frame", {
			Name = "PresetList", Position = UDim2.fromOffset(10, 38), Size = UDim2.new(1, -20, 0, 0),
			AutomaticSize = Enum.AutomaticSize.Y, BackgroundTransparency = 1, ZIndex = 121,
		}, popup)
		New("UIListLayout", { Padding = UDim.new(0, 4), SortOrder = Enum.SortOrder.LayoutOrder }, list)
		New("UIPadding", { PaddingBottom = UDim.new(0, 10) }, list)

		local function selectPreset(name)
			selectedPreset = name
			GlobalPreset.GlobalPresetLabel.Text = name
			for _, row in ipairs(list:GetChildren()) do
				if row:IsA("TextButton") then
					local isSel = row.Text == name
					row.BackgroundColor3 = isSel and Color3.fromRGB(27, 27, 35) or Color3.fromRGB(21, 21, 29)
					local outline = row:FindFirstChild("RowOutline")
					if outline then
						outline.Color = isSel and Color3.fromRGB(73, 79, 117) or Color3.fromRGB(255, 255, 255)
						outline.Transparency = isSel and 0 or 0.95
					end
				end
			end
			if type(WindowObj._onWeaponPreset) == "function" then InvokeCallback(WindowObj._onWeaponPreset, name) end
		end

		local function addRow(name)
			local row = New("TextButton", {
				Name = "Preset", Size = UDim2.new(1, 0, 0, 34), BackgroundColor3 = Color3.fromRGB(21, 21, 29),
				AutoButtonColor = false, Text = name, TextColor3 = Color3.fromRGB(214, 216, 224), TextSize = 14,
				TextXAlignment = Enum.TextXAlignment.Left, LayoutOrder = #list:GetChildren(), ZIndex = 122,
			}, list)
			New("UICorner", { CornerRadius = UDim.new(0, 8) }, row)
			New("UIPadding", { PaddingLeft = UDim.new(0, 12) }, row)
			local outline = Instance.new("UIStroke")
			outline.Name = "RowOutline"
			outline.Color = Color3.fromRGB(255, 255, 255)
			outline.Transparency = 0.95
			outline.ApplyStrokeMode = Enum.ApplyStrokeMode.Border
			outline.Parent = row
			row.MouseButton1Click:Connect(function() selectPreset(name) end)
			return row
		end
		for _, name in ipairs(presets) do addRow(name) end
		selectPreset(selectedPreset)

		-- "+" turns into an inline name field; Enter adds the preset.
		addBtn.MouseButton1Click:Connect(function()
			local input = New("TextBox", {
				Name = "NewPreset", Size = UDim2.new(1, 0, 0, 34), BackgroundColor3 = Color3.fromRGB(26, 26, 38),
				Text = "", PlaceholderText = "Preset name", PlaceholderColor3 = Color3.fromRGB(130, 134, 152),
				TextColor3 = Color3.fromRGB(228, 230, 238), TextSize = 14, TextXAlignment = Enum.TextXAlignment.Left,
				ClearTextOnFocus = false, LayoutOrder = 9999, ZIndex = 122,
			}, list)
			New("UICorner", { CornerRadius = UDim.new(0, 8) }, input)
			New("UIPadding", { PaddingLeft = UDim.new(0, 12) }, input)
			input:CaptureFocus()
			input.FocusLost:Connect(function(enter)
				local name = tostring(input.Text or ""):gsub("^%s+", ""):gsub("%s+$", "")
				input:Destroy()
				if enter and name ~= "" and not table.find(presets, name) then
					table.insert(presets, name)
					addRow(name)
					selectPreset(name)
				end
			end)
		end)

		local presetsOpen = false
		local function closePresets()
			presetsOpen = false
			UnregisterPopup(popup)
			SmoothClose(popup, 0.12)
		end
		globalHit.MouseButton1Click:Connect(function()
			if presetsOpen then closePresets() return end
			CloseAllPopupsExcept(popup)
			presetsOpen = true
			RememberPopupClipping(popup)
			ApplyZIndexLadder(popup, NextPopupZ())
			SmoothOpen(popup, 0, 0.16)
			local scale = popup:FindFirstChild("_PopScale")
			if scale then
				scale.Scale = 0.92
				Tween(scale, { Scale = 1 }, 0.22, Enum.EasingStyle.Back, Enum.EasingDirection.Out)
			end
			RegisterPopup(popup, closePresets, globalHit)
		end)

		function WindowObj:SetWeaponPresets(names)
			for _, row in ipairs(list:GetChildren()) do
				if row:IsA("TextButton") then row:Destroy() end
			end
			presets = {}
			for _, name in ipairs(type(names) == "table" and names or { "Global" }) do
				table.insert(presets, tostring(name))
				addRow(tostring(name))
			end
			selectPreset(presets[1] or "Global")
			return self
		end
		function WindowObj:OnWeaponPreset(callback)
			WindowObj._onWeaponPreset = callback
			return self
		end
		function WindowObj:GetWeaponPreset() return selectedPreset end
	end

	local function SetActiveConfigName(name)
		if type(name) == "string" and name ~= "" and name ~= "Save" then
			activeConfigName = name
		else
			activeConfigName = nil
		end
		WindowObj._activePresetName = activeConfigName
		SaveText.Text = activeConfigName or "Default"
		UpdateSavePillWidth(SaveText.Text)
	end

	-- Loads the preset saved or loaded last (remembered in "__last.txt") once
	-- the interface is up, so a re-run starts with the same settings.
	WindowObj._autoLoad = function()
		if WindowObj._autoLoaded or type(readfile) ~= "function" or type(isfile) ~= "function" then return end
		WindowObj._autoLoaded = true
		local path = "NeverloseConfig_" .. windowConfigId .. "__last.txt"
		local okExists, exists = pcall(isfile, path)
		if not okExists or not exists then return end
		local ok, name = pcall(readfile, path)
		if not ok or type(name) ~= "string" or name == "" then return end
		if LoadNamedConfig(name) and name ~= "Default" then SetActiveConfigName(name) end
	end

	local function ClearActiveConfig()
		activeRow = nil
		activeLoadBtn = nil
		SetActiveConfigName(nil)
	end

	-- Neverlose preset rows: 21,21,29 cards; the loaded one is lighter with an
	-- accent outline.
	-- (Literal colours, not locals: AddWindow is near Luau's register cap.)
	local function DeactivateRow(rowFrame, loadBtn)
		Tween(rowFrame, {BackgroundColor3 = Color3.fromRGB(21, 21, 29)}, 0.15)
		local outline = rowFrame:FindFirstChild("ConfigRowStroke")
		if outline then Tween(outline, { Color = STROKE.Color, Transparency = 0.95 }, 0.15) end
		loadBtn.Image = LOAD_ICON
		Tween(loadBtn, {ImageColor3 = Color3.fromRGB(128, 132, 146)}, 0.15)
	end

	local function MakeConfigButton(name)
		local row = Instance.new("Frame")
		row.Name = "ConfigRow_" .. name
		row.Size = UDim2.new(1, 0, 0, 38)
		row.BackgroundColor3 = Color3.fromRGB(21, 21, 29)
		row.BackgroundTransparency = 0
		row.BorderSizePixel = 0
		row.ZIndex = 1000
		row.Parent = ListContainer
		do local c = Instance.new("UICorner"); c.CornerRadius = UDim.new(0, 8); c.Parent = row end

		Stroke(row, "ConfigRowStroke").Transparency = 0.95
		row.MouseEnter:Connect(function()
			Tween(row, { BackgroundColor3 = Color3.fromRGB(27, 27, 35) }, 0.1, Enum.EasingStyle.Sine)
		end)
		row.MouseLeave:Connect(function()
			Tween(row, { BackgroundColor3 = activeRow == row and Color3.fromRGB(27, 27, 35) or Color3.fromRGB(21, 21, 29) }, 0.13, Enum.EasingStyle.Sine)
		end)

		local Rename = Instance.new("TextBox")
		Rename.Name = "Rename"
		Rename.Position = UDim2.new(0, 14, 0, 0)
		Rename.Size = UDim2.new(1, -84, 1, 0)
		Rename.BackgroundTransparency = 1
		Rename.Text = name
		Rename.PlaceholderText = "No Name"
		Rename.PlaceholderColor3 = Color3.fromRGB(130, 134, 152)
		Rename.TextColor3 = Color3.fromRGB(210, 212, 220)
		Rename.TextSize = 14
		Rename.Font = FONT
		Rename.ZIndex = 1000
		Rename.TextXAlignment = Enum.TextXAlignment.Left
		Rename.TextTruncate = Enum.TextTruncate.AtEnd
		Rename.ClearTextOnFocus = false
		pcall(function() Rename.ReadOnly = true end)
		Rename.Parent = row

		local SettingsBtn = Instance.new("TextButton")
		SettingsBtn.Name = "Settings"
		SettingsBtn.AnchorPoint = Vector2.new(1, 0)
		SettingsBtn.Position = UDim2.new(1, -36, 0, 0)
		SettingsBtn.Size = UDim2.fromOffset(26, 38)
		SettingsBtn.BackgroundTransparency = 1
		SettingsBtn.Text = ""
		SettingsBtn.ZIndex = 3000
		SettingsBtn.Parent = row
		do
			local dotsIcon = Instance.new("ImageLabel")
			dotsIcon.Name = "DotsIcon"
			dotsIcon.AnchorPoint = Vector2.new(0.5, 0.5)
			dotsIcon.Position = UDim2.new(0.5, 0, 0.5, 0)
			-- Neverlose keeps the row icons small and muted; only the label stands out.
			dotsIcon.Size = UDim2.fromOffset(14, 14)
			dotsIcon.BackgroundTransparency = 1
			dotsIcon.Image = "rbxassetid://95127553964880"
			dotsIcon.ImageColor3 = Color3.fromRGB(128, 132, 146)
			dotsIcon.ScaleType = Enum.ScaleType.Fit
			dotsIcon.ZIndex = 3001
			dotsIcon.Parent = SettingsBtn
		end

		local LoadConfigBtn = Instance.new("ImageButton")
		LoadConfigBtn.Name = "LoadConfig"
		LoadConfigBtn.AnchorPoint = Vector2.new(1, 0.5)
		LoadConfigBtn.Position = UDim2.new(1, -12, 0.5, 0)
		LoadConfigBtn.Size = UDim2.fromOffset(15, 15)
		LoadConfigBtn.BackgroundTransparency = 1
		LoadConfigBtn.Image = LOAD_ICON
		LoadConfigBtn.ImageColor3 = Color3.fromRGB(128, 132, 146)
		LoadConfigBtn.ScaleType = Enum.ScaleType.Fit
		LoadConfigBtn.ZIndex = 3000
		LoadConfigBtn.Parent = row

		-- Neverlose row menu: Share / Duplicate / divider / Delete, with icons,
		-- opening just right of the dots.
		local SettingsFrame = Instance.new("Frame")
		SettingsFrame.Name = "SettingsFrame"
		SettingsFrame.Position = UDim2.new(0, 0, 0, 0)
		SettingsFrame.Size = UDim2.fromOffset(160, 0)
		SettingsFrame.AutomaticSize = Enum.AutomaticSize.Y
		SettingsFrame.BackgroundColor3 = Color3.fromRGB(18, 18, 27)
		SettingsFrame.BackgroundTransparency = 0
		SettingsFrame.BorderSizePixel = 0
		SettingsFrame.ZIndex = 6000
		SettingsFrame.Visible = false
		SettingsFrame.ClipsDescendants = false
		SettingsFrame.Active = true
		SettingsFrame.Parent = row
		do local c = Instance.new("UICorner"); c.CornerRadius = UDim.new(0, 10); c.Parent = SettingsFrame end
		local SettingsFrameStroke = Stroke(SettingsFrame, "SettingsFrameStroke")
		local SettingsFrameItems = Instance.new("Frame")
		SettingsFrameItems.Name = "Items"
		SettingsFrameItems.Size = UDim2.new(1, 0, 0, 0)
		SettingsFrameItems.AutomaticSize = Enum.AutomaticSize.Y
		SettingsFrameItems.BackgroundTransparency = 1
		SettingsFrameItems.ZIndex = 6001
		SettingsFrameItems.Parent = SettingsFrame
		do
			local ll = Instance.new("UIListLayout")
			ll.Padding = UDim.new(0, 1)
			ll.SortOrder = Enum.SortOrder.LayoutOrder
			ll.Parent = SettingsFrameItems
			local pad = Instance.new("UIPadding")
			pad.PaddingTop = UDim.new(0, 5); pad.PaddingBottom = UDim.new(0, 5)
			pad.PaddingLeft = UDim.new(0, 5); pad.PaddingRight = UDim.new(0, 5)
			pad.Parent = SettingsFrameItems
		end
		AttachShadow(SettingsFrame, { radius = 10, layers = 5, step = 1.6, bias = 3 })

		local sfOpen = false
		local closeSfRow
		local sfOrder = 0
		local function MakeSettingBtn(text, textColor, iconKind, callback)
			sfOrder = sfOrder + 1
			local btn = Instance.new("TextButton")
			btn.Name = "MenuItem"
			btn.LayoutOrder = sfOrder
			btn.Size = UDim2.new(1, 0, 0, 30)
			btn.BackgroundColor3 = Color3.fromRGB(255, 255, 255)
			btn.BackgroundTransparency = 1
			btn.AutoButtonColor = false
			btn.Text = text
			btn.TextColor3 = textColor
			btn.TextSize = 14
			btn.Font = FONT
			btn.TextXAlignment = Enum.TextXAlignment.Left
			btn.ZIndex = 6002
			btn.Parent = SettingsFrameItems
			do local c = Instance.new("UICorner"); c.CornerRadius = UDim.new(0, 6); c.Parent = btn end
			do local pad = Instance.new("UIPadding"); pad.PaddingLeft = UDim.new(0, 34); pad.Parent = btn end
			local glyph = Instance.new("Frame")
			glyph.Name = "Glyph"
			glyph.AnchorPoint = Vector2.new(0, 0.5)
			glyph.Position = UDim2.new(0, -24, 0.5, 0) -- UIPadding shifts children too
			glyph.Size = UDim2.fromOffset(14, 14)
			glyph.BackgroundTransparency = 1
			glyph.ZIndex = 6003
			glyph.Parent = btn
			WindowObj._drawGlyph(iconKind, glyph, textColor)

			btn.MouseEnter:Connect(function()
				Tween(btn, {BackgroundTransparency = 0.97}, 0.1)
			end)
			btn.MouseLeave:Connect(function()
				Tween(btn, {BackgroundTransparency = 1}, 0.12)
			end)
			btn.MouseButton1Click:Connect(function()
				if closeSfRow then closeSfRow() else SettingsFrame.Visible = false end
				InvokeCallback(callback)
			end)
			return btn
		end

		MakeSettingBtn("Share", Color3.fromRGB(214, 216, 224), "share", function()
			-- Copies a share code; paste it into the "+" field to import.
			local code = WindowObj._makeShareCode and WindowObj._makeShareCode(name)
			if code and type(setclipboard) == "function" then
				pcall(setclipboard, code)
				local before = Rename.Text
				Rename.Text = "Share code copied"
				task.delay(1.2, function() if Rename.Parent then Rename.Text = before end end)
			end
		end)

		MakeSettingBtn("Duplicate", Color3.fromRGB(214, 216, 224), "copy", function()
			local dupName = name .. " (Copy)"
			local saved = false
			local path = GetConfigPath(name)
			if type(readfile) == "function" and type(isfile) == "function" and type(writefile) == "function" then
				local existsOk, exists = pcall(isfile, path)
				if existsOk then
					if exists then
						local readOk, content = pcall(readfile, path)
						if readOk and type(content) == "string" then
							local writeOk, writeResult = pcall(writefile, GetConfigPath(dupName), content)
							saved = writeOk and writeResult ~= false
						end
					else
						saved = SaveNamedConfig(dupName)
					end
				end
			else
				saved = SaveNamedConfig(dupName)
			end
			if saved then MakeConfigButton(dupName) end
		end)

		do
			sfOrder = sfOrder + 1
			local divider = Instance.new("Frame")
			divider.Name = "Divider"
			divider.LayoutOrder = sfOrder
			divider.Size = UDim2.new(1, -12, 0, 1)
			divider.Position = UDim2.fromOffset(6, 0)
			divider.BackgroundColor3 = Color3.fromRGB(255, 255, 255)
			divider.BackgroundTransparency = 0.93
			divider.BorderSizePixel = 0
			divider.ZIndex = 6002
			divider.Parent = SettingsFrameItems
		end

		MakeSettingBtn("Delete", Color3.fromRGB(233, 90, 110), "trash", function()
			local configData = {}
			for _, entry in ipairs(_registeredElements) do
				local ok, val = pcall(function() return entry.obj:Get() end)
				if ok then
					local s = SerializeValue(val)
					if s ~= nil then configData[entry.key] = s end
				end
			end
			local path = GetConfigPath(name)
			if type(readfile) == "function" and type(isfile) == "function" then
				local existsOk, exists = pcall(isfile, path)
				if existsOk and exists then
					local ok2, content = pcall(readfile, path)
					if ok2 and type(content) == "string" and #content <= 2097152 then
						local dok, data = pcall(game:GetService("HttpService").JSONDecode, game:GetService("HttpService"), content)
						if dok and type(data) == "table" then configData = data end
					end
					if type(delfile) == "function" then pcall(delfile, path) end
				end
			end
			table.insert(_deletedConfigs, { name = name, data = configData })
			if #_deletedConfigs > 20 then table.remove(_deletedConfigs, 1) end
			SaveDeletedList()
			if activeRow == row then
				ClearActiveConfig()
			end
			-- Fade and fold the row away so the list closes the gap smoothly.
			row.ClipsDescendants = true
			FadePopupContent(row, false, 0.18)
			Tween(row, {BackgroundTransparency = 1, Size = UDim2.new(1, 0, 0, 0)}, 0.22, Enum.EasingStyle.Quint, Enum.EasingDirection.In)
			task.delay(0.24, function() row:Destroy() end)
		end)

		closeSfRow = function()
			sfOpen = false
			UnregisterPopup(SettingsFrame)
			SmoothClose(SettingsFrame, 0.12)
			local menuScale = SettingsFrame:FindFirstChild("_PopScale")
			if menuScale then Tween(menuScale, { Scale = 0.94 }, 0.12) end
		end
		SettingsBtn.MouseButton1Click:Connect(function()
			sfOpen = not sfOpen
			if sfOpen then
				CloseAllPopupsExcept(SettingsFrame)
				RememberPopupClipping(SettingsFrame)
				ForceLiftClipping(SettingsFrame)
				ApplyZIndexLadder(SettingsFrame, NextPopupZ())
				SettingsFrame.Visible = true
				-- Right of the dots, top a little above them; kept inside the window.
				MovePopupToAbsolute(SettingsFrame,
					SettingsBtn.AbsolutePosition.X + SettingsBtn.AbsoluteSize.X + 4,
					SettingsBtn.AbsolutePosition.Y + 2)
				ConstrainPopupToMainFrame(SettingsFrame, 6)
				SmoothOpen(SettingsFrame, 0, 0.16)
				local menuScale = SettingsFrame:FindFirstChild("_PopScale")
				if menuScale then
					menuScale.Scale = 0.9
					Tween(menuScale, { Scale = 1 }, 0.22, Enum.EasingStyle.Back, Enum.EasingDirection.Out)
				end
				RegisterPopup(SettingsFrame, closeSfRow, SettingsBtn)
			else
				closeSfRow()
			end
		end)

		local RowOverlay = Instance.new("TextButton")
		RowOverlay.Name = "RowOverlay"
		RowOverlay.Size = UDim2.new(1, -72, 1, 0)
		RowOverlay.BackgroundTransparency = 1
		RowOverlay.Text = ""
		RowOverlay.ZIndex = 2500
		RowOverlay.Parent = row
		RowOverlay.MouseButton1Click:Connect(function()
			if sfOpen then closeSfRow() end
		end)

		LoadConfigBtn.MouseButton1Click:Connect(function()
			if activeRow == row then
				if SaveNamedConfig(name) then WindowObj._savedCheck(LoadConfigBtn) end
			else
				local loaded = LoadNamedConfig(name)
				if not loaded then
					Tween(LoadConfigBtn, {ImageColor3 = Color3.fromRGB(255, 80, 80)}, 0.2)
					return
				end
				if activeRow and activeLoadBtn then
					DeactivateRow(activeRow, activeLoadBtn)
				end
				activeRow = row
				activeLoadBtn = LoadConfigBtn
				SetActiveConfigName(name)
				Tween(row, {BackgroundColor3 = Color3.fromRGB(27, 27, 35)}, 0.2)
				-- Neverlose marks the loaded preset quietly: a muted lavender outline
				-- and a light save icon, not a bright accent ring.
				local outline = row:FindFirstChild("ConfigRowStroke")
				if outline then Tween(outline, { Color = Color3.fromRGB(73, 79, 117), Transparency = 0 }, 0.2) end
				LoadConfigBtn.Image = SAVE_ICON
				Tween(LoadConfigBtn, {ImageColor3 = Color3.fromRGB(205, 208, 218)}, 0.2)
			end
		end)

		local query = string.lower(tostring(ConfigSearchBox.Text or "")):gsub("^%s+", ""):gsub("%s+$", "")
		row.Visible = query == "" or string.lower(Rename.Text or ""):find(query, 1, true) ~= nil
		-- The selected preset keeps its mark when the list is rebuilt.
		if name == activeConfigName then
			activeRow = row
			activeLoadBtn = LoadConfigBtn
			row.BackgroundColor3 = Color3.fromRGB(27, 27, 35)
			local outline = row:FindFirstChild("ConfigRowStroke")
			if outline then outline.Color = Color3.fromRGB(73, 79, 117); outline.Transparency = 0 end
			LoadConfigBtn.Image = SAVE_ICON
			LoadConfigBtn.ImageColor3 = Color3.fromRGB(205, 208, 218)
		end
		return row
	end

	local function UpdateConfigPanelHeight()
		local frame2H = Frame2.AbsoluteSize.Y
		local maxH = math.min(400, math.max(104, (frame2H > 0 and frame2H or 480) - 53))
		local function countRows(container)
			local count = 0
			for _, c in ipairs(container:GetChildren()) do
				if c:IsA("Frame") and c.Name ~= "Space" and c.Visible then count = count + 1 end
			end
			return count
		end
		local cfgH = 106 + math.min(countRows(ListContainer), 7) * 42
		local rdH = 16 + math.max(countRows(RDList), 1) * 42
		ConfigMainFrame.Size = UDim2.fromOffset(320, math.clamp(cfgH, 104, maxH))
		if countRows(ListContainer) <= 7 then ListContainer.CanvasPosition = Vector2.new(0, 0) end
		RDList.CanvasPosition = Vector2.new(0, 0)
		RecentlyDeletedPanel.Size = UDim2.fromOffset(280, math.clamp(rdH, 54, maxH))
	end
	ListContainer.ChildAdded:Connect(function() task.defer(UpdateConfigPanelHeight) end)
	ListContainer.ChildRemoved:Connect(function() task.defer(UpdateConfigPanelHeight) end)
	RDList.ChildAdded:Connect(function() task.defer(UpdateConfigPanelHeight) end)
	-- Rows added while a panel is open were created at a low ZIndex and drew
	-- behind the panel (it sits on a popup z-ladder), so a new preset or the
	-- next deleted entry only showed after reopening. Lift them onto the
	-- panel's ladder and grow them in.
	do
		local function liftAndAnimate(panel, list, child)
			if not panel.Visible or not child:IsA("GuiObject") then return end
			task.defer(function()
				if not child.Parent or not panel.Visible then return end
				ApplyZIndexLadder(panel, panel.ZIndex)
				-- Grow only (no text fade): rows rebuilt while the panel opens were
				-- caught mid open-fade and stayed invisible. Rows built during the
				-- opening itself are not animated at all.
				local openedAt = panel:GetAttribute("NLOpenedAt") or 0
				if child:IsA("Frame") and child.Name ~= "Space" and os.clock() - openedAt > 0.35 then
					local full = child.Size
					child.ClipsDescendants = true
					child.Size = UDim2.new(full.X.Scale, full.X.Offset, 0, 0)
					Tween(child, { Size = full }, 0.22, Enum.EasingStyle.Quint, Enum.EasingDirection.Out)
					task.delay(0.24, function() if child.Parent then child.ClipsDescendants = false end end)
				end
			end)
		end
		ListContainer.ChildAdded:Connect(function(child) liftAndAnimate(ConfigMainFrame, ListContainer, child) end)
		RDList.ChildAdded:Connect(function(child) liftAndAnimate(RecentlyDeletedPanel, RDList, child) end)
	end
	RDList.ChildRemoved:Connect(function() task.defer(UpdateConfigPanelHeight) end)

	local function RefreshConfigList()
		-- Keep the selected preset's name; its row is rebuilt and re-marked.
		activeRow = nil
		activeLoadBtn = nil
		for _, c in ipairs(ListContainer:GetChildren()) do
			if c:IsA("Frame") and c.Name ~= "Space" then c:Destroy() end
		end
		local list = ListConfigs()
		for _, n in ipairs(list) do
			MakeConfigButton(n)
		end
		UpdateConfigPanelHeight()
	end

	local insertMode = false
	InsertConfigBtn.MouseButton1Click:Connect(function()
		insertMode = not insertMode
		SearchContainer.Visible = not insertMode
		NameInputContainer.Visible = insertMode
		if insertMode then
			InsertConfigBtn:SetAttribute("Pinned", true)
			Tween(InsertConfigBtn, {ImageColor3 = mainColor}, 0.2)
			task.spawn(function() NameOfConfig:CaptureFocus() end)
		else
			InsertConfigBtn:SetAttribute("Pinned", false)
			Tween(InsertConfigBtn, {ImageColor3 = IDLE_ICON_TINT}, 0.2)
		end
	end)

ConfirmAddBtn.MouseButton1Click:Connect(function()
		local n = NameOfConfig.Text
		local imported = WindowObj._importShareCode(n)
		if imported then
			n = imported
		else
			if n == "" then n = "Config " .. tostring(#ListContainer:GetChildren()) end
			if not SaveNamedConfig(n) then return end
		end
		NameOfConfig.Text = ""
		MakeConfigButton(n)
		insertMode = false
		SearchContainer.Visible = true
		NameInputContainer.Visible = false
		Tween(InsertConfigBtn, {ImageColor3 = Color3.fromRGB(200, 200, 220)}, 0.2)
	end)

	ConfigSearchBox:GetPropertyChangedSignal("Text"):Connect(function()
		-- Use the same whitespace normalization as row creation so a row does
		-- not flicker out when the query contains leading/trailing spaces.
		local query = string.lower(tostring(ConfigSearchBox.Text or "")):gsub("^%s+", ""):gsub("%s+$", "")
		for _, c in ipairs(ListContainer:GetChildren()) do
			if c:IsA("Frame") and c.Name ~= "Space" then
				local rename = c:FindFirstChild("Rename")
				if rename then
					local name = string.lower(tostring(rename.Text or ""))
					c.Visible = query == "" or name:find(query, 1, true) ~= nil
				end
			end
		end
		task.defer(UpdateConfigPanelHeight)
	end)

	local function SaveActiveConfig()
		if not autoSaveEnabled then return end
		if not activeRow or not activeLoadBtn then return end
		local n = activeConfigName
		if type(n) ~= "string" or n == "" or n == "Save" then return end
		SaveNamedConfig(n)
		ShowSavedName()
		FlashSaved()
	end

	AutoSaveBtn.MouseButton1Click:Connect(function()
		autoSaveEnabled = not autoSaveEnabled
		if autoSaveEnabled then
			AutoSaveBtn:SetAttribute("Pinned", true)
			Tween(AutoSaveBtn, {ImageColor3 = mainColor}, 0.2)
			SaveActiveConfig()
		else
			AutoSaveBtn:SetAttribute("Pinned", false)
			Tween(AutoSaveBtn, {ImageColor3 = IDLE_ICON_TINT}, 0.2)
		end
	end)

	if type(writefile) == "function" then
		task.spawn(function()
			while true do
				task.wait(30)
				SaveActiveConfig()
			end
		end)
	end

	if LocalPlayer and LocalPlayer.CharacterRemoving then
		LocalPlayer.CharacterRemoving:Connect(function()
			SaveActiveConfig()
		end)
	end

	-- Neverlose opens the recently-deleted list beside the presets panel (to
	-- its right) and keeps the presets panel open.
	do
		local function closeDeleted()
			UnregisterPopup(RecentlyDeletedPanel)
			SmoothClose(RecentlyDeletedPanel, 0.12)
		end
		RecentlyDeletedBtn.MouseButton1Click:Connect(function()
			if RecentlyDeletedPanel.Visible then closeDeleted() return end
			RefreshDeletedList()
			UpdateConfigPanelHeight()
			RecentlyDeletedPanel.Position = UDim2.fromOffset(
				ConfigMainFrame.Position.X.Offset + ConfigMainFrame.Size.X.Offset + 8,
				ConfigMainFrame.Position.Y.Offset)
			ApplyZIndexLadder(RecentlyDeletedPanel, NextPopupZ())
			RecentlyDeletedPanel:SetAttribute("NLOpenedAt", os.clock())
			RememberPopupClipping(RecentlyDeletedPanel)
			SmoothOpen(RecentlyDeletedPanel, 0, 0.16)
			local rdScale = GetPopupScale(RecentlyDeletedPanel)
			if rdScale then
				rdScale.Scale = 0.92
				Tween(rdScale, { Scale = 1 }, 0.22, Enum.EasingStyle.Back, Enum.EasingDirection.Out)
			end
			task.defer(function() ConstrainPopupToMainFrame(RecentlyDeletedPanel) end)
			RegisterPopup(RecentlyDeletedPanel, closeDeleted, RecentlyDeletedBtn)
		end)
	end

	closeConfigPanel = function()
		configOpen = false
		ClosePopupsUnder(ConfigMainFrame)
		ClosePopupsUnder(RecentlyDeletedPanel)
		UnregisterPopup(ConfigMainFrame)
		UnregisterPopup(RecentlyDeletedPanel)
		-- Panel, rows, icons, outlines and shadow fade out as one.
		Tween(ConfigMainFrame, { BackgroundTransparency = 1 }, 0.16, Enum.EasingStyle.Sine, Enum.EasingDirection.In)
		Tween(ConfigScale, { Scale = 0.96 }, 0.16, Enum.EasingStyle.Sine, Enum.EasingDirection.In)
		WindowObj._fadeTree(ConfigMainFrame, false, 0.16)
		Tween(RecentlyDeletedPanel, { BackgroundTransparency = 1 }, 0.13, Enum.EasingStyle.Quad, Enum.EasingDirection.In)
		local rdScale = RecentlyDeletedPanel:FindFirstChild("_PopScale")
		if rdScale and rdScale:IsA("UIScale") then Tween(rdScale, { Scale = 0.94 }, 0.13, Enum.EasingStyle.Quad, Enum.EasingDirection.In) end
		task.delay(0.22, function()
			if configOpen then return end
			ConfigMainFrame.Visible = false
			RecentlyDeletedPanel.Visible = false
		end)
	end
	TriggerSaveConfig.MouseButton1Click:Connect(function()
		configOpen = not configOpen
		if configOpen then
			CloseAllPopupsExcept(ConfigMainFrame)
			RecentlyDeletedPanel.Visible = false
			-- One motion: everything (rows rebuilt below included) starts clear
			-- and comes in together with the panel.
			WindowObj._fadeTree(ConfigMainFrame, true, 0)
			RefreshConfigList()
			WindowObj._fadeTree(ConfigMainFrame, false, 0)
			ConfigMainFrame.BackgroundTransparency = 1
			ConfigMainFrame.Visible = false
			ConfigMainFrame.ZIndex = 7000
			ApplyZIndexLadder(ConfigMainFrame, NextPopupZ())
			ConstrainPopupToMainFrame(ConfigMainFrame); task.defer(function() ConstrainPopupToMainFrame(ConfigMainFrame) end); RegisterPopup(ConfigMainFrame, closeConfigPanel, TriggerSaveConfig)
			task.delay(0.26, function()
				if not ConfigMainFrame.Visible then return end
				local safe = PopupSafeArea()
				local w = ConfigMainFrame.AbsoluteSize.X
				if w > 0 and safe.X > 0 and w > safe.X - 12 then
					ConfigScale.Scale = math.max(0.5, (safe.X - 12) / w)
				end
			end)
			ConfigMainFrame.Visible = true
			ConfigMainFrame:SetAttribute("NLOpenedAt", os.clock())
			ConfigScale.Scale = 0.95
			Tween(ConfigScale, { Scale = 1 }, 0.22, Enum.EasingStyle.Quint, Enum.EasingDirection.Out)
			WindowObj._fadeTree(ConfigMainFrame, true, 0.22)
			Tween(ConfigMainFrame, { BackgroundTransparency = 0.045 }, 0.22, Enum.EasingStyle.Quint, Enum.EasingDirection.Out)
			local cfgSettled = ConfigMainFrame.Position
			ConfigMainFrame.Position = UDim2.new(cfgSettled.X.Scale, cfgSettled.X.Offset, cfgSettled.Y.Scale, cfgSettled.Y.Offset - 6)
			Tween(ConfigMainFrame, { Position = cfgSettled }, 0.22, Enum.EasingStyle.Quint, Enum.EasingDirection.Out)
		else
			closeConfigPanel()
		end
	end)

	local SearchBox = New("TextBox", {
		Name = "SearchBox",
		-- Neverlose search takes over the whole header bar (selectors hidden under
		-- it) and the magnifier turns into a close cross at its right end.
		AnchorPoint = Vector2.new(1, 0.5),
		Position = UDim2.new(1, -11, 0.5, 0),
		Size = UDim2.new(0, 0, 0, 34),
		BackgroundColor3 = Color3.fromRGB(15, 17, 26),
		Text = "",
		PlaceholderText = "Search",
		PlaceholderColor3 = Color3.fromRGB(130, 134, 152),
		TextColor3 = Color3.fromRGB(228, 230, 238),
		TextScaled = false,
		TextSize = 14,
		Font = FONT,
		TextTransparency = 0.05,
		Visible = false,
		TextXAlignment = Enum.TextXAlignment.Left,
		ClipsDescendants = true,
		ZIndex = 20,
	}, Header)
	New("UICorner", { CornerRadius = UDim.new(0, 8) }, SearchBox)
	Stroke(SearchBox)
	New("UIPadding", { PaddingLeft = UDim.new(0, 12), PaddingRight = UDim.new(0, 36) }, SearchBox)
	SearchBtn.ZIndex = 22
	New("TextLabel", {
		Name = "CloseGlyph",
		AnchorPoint = Vector2.new(0.5, 0.5),
		Position = UDim2.new(0.5, 0, 0.5, 0),
		Size = UDim2.fromScale(1, 1),
		BackgroundTransparency = 1,
		Text = "×",
		TextColor3 = Color3.fromRGB(200, 204, 218),
		TextSize = 22,
		Visible = false,
		ZIndex = 23,
	}, SearchBtn)

	local ApplySearch

	local searchOpen = false
	local searchTransitionToken = 0
	SearchBtn.MouseButton1Click:Connect(function()
		searchOpen = not searchOpen
		searchTransitionToken = searchTransitionToken + 1
		local token = searchTransitionToken
		SearchBtn.ImageTransparency = searchOpen and 1 or 0.2
		SearchBtn.CloseGlyph.Visible = searchOpen
		if searchOpen then
			SearchBox.Visible = true
			SearchBox.BackgroundTransparency = 1
			SearchBox.Size = UDim2.new(0, 0, 0, 34)
			Tween(SearchBox, { BackgroundTransparency = 0 }, 0.13, Enum.EasingStyle.Quad, Enum.EasingDirection.Out)
			Tween(SearchBox, { Size = UDim2.new(1, -22, 0, 34) }, 0.18, Enum.EasingStyle.Quint, Enum.EasingDirection.Out)
			task.delay(0.16, function()
				if searchOpen and searchTransitionToken == token and SearchBox.Visible then pcall(function() SearchBox:CaptureFocus() end) end
			end)
		else
			pcall(function() SearchBox:ReleaseFocus() end)
			Tween(SearchBox, { Size = UDim2.new(0, 0, 0, 34), BackgroundTransparency = 1 }, 0.12, Enum.EasingStyle.Quint, Enum.EasingDirection.In)
			task.delay(0.13, function()
				if searchOpen or searchTransitionToken ~= token then return end
				SearchBox.Visible = false
				SearchBox.Text = ""
				if ApplySearch then ApplySearch("") end
			end)
		end
	end)

	local TabHose = New("Frame", {
		Name = "TabHose",
		Position = UDim2.new(0, 11, 0, 61),
		Size = UDim2.new(1, -22, 1, -71),
		BackgroundColor3 = Color3.fromRGB(162, 162, 161),
		BackgroundTransparency = 1,
		ClipsDescendants = false,
	}, Frame2)
	New("UIListLayout", {
		FillDirection = Enum.FillDirection.Horizontal,
		-- Responsive gutter: more breathing room on wide menus without overflowing
		-- the columns when the menu is scaled down.
		Padding = UDim.new(0, 12),
		SortOrder = Enum.SortOrder.LayoutOrder,
	}, TabHose)

	local SubTabHose = New("Frame", {
		Name = "SubTabHose",
		Position = UDim2.new(0, 11, 0, 61),
		Size = UDim2.new(1, -22, 1, -71),
		BackgroundColor3 = Color3.fromRGB(162, 162, 161),
		BackgroundTransparency = 1,
		ClipsDescendants = false,
	}, Frame2)
	New("UIListLayout", {
		FillDirection = Enum.FillDirection.Horizontal,
		Padding = UDim.new(0, 12),
		SortOrder = Enum.SortOrder.LayoutOrder,
	}, SubTabHose)

	New("TextLabel", {
		Name = "SearchEmptyState",
		AnchorPoint = Vector2.new(0.5, 0.5),
		Position = UDim2.new(0.5, 0, 0.54, 0),
		Size = UDim2.new(0.72, 0, 0, 44),
		BackgroundTransparency = 1,
		BorderSizePixel = 0,
		Text = "NO MATCHING SETTINGS",
		TextColor3 = Color3.fromRGB(126, 133, 154),
		TextSize = 12,
		Font = FONT,
		TextWrapped = true,
		TextXAlignment = Enum.TextXAlignment.Center,
		TextYAlignment = Enum.TextYAlignment.Center,
		Visible = false,
		Active = false,
		ZIndex = 5,
	}, Frame2)

	local function GetSearchText(object)
		local pieces = {}
		if not object then return "" end
		if object:IsA("TextLabel") or object:IsA("TextButton") or object:IsA("TextBox") then
			table.insert(pieces, object.Text or "")
		end
		local ok, descendants = pcall(function() return object:GetDescendants() end)
		if ok then
			for _, child in ipairs(descendants) do
				if child:IsA("TextLabel") or child:IsA("TextButton") or child:IsA("TextBox") then
					local childName = string.lower(child.Name)
					if childName == "text" or childName == "texttoggle" or childName == "textdefault" or childName == "label" or childName == "textdropdown" then
						table.insert(pieces, child.Text or "")
					end
				end
			end
		end
		return string.lower(table.concat(pieces, " "))
	end

	local function IsSearchColumnActive(column)
		local tabIndex = column:GetAttribute("TabIndex")
		if tabIndex ~= activeTabIndex then return false end
		local tab = tabs[tabIndex]
		if not tab then return false end
		local subTabIndex = column:GetAttribute("SubTabIndex")
		if tab.activeSubTabIndex ~= nil then return subTabIndex == tab.activeSubTabIndex end
		return subTabIndex == nil
	end

	local function SearchMatches(haystack, query)
		haystack = string.lower(tostring(haystack or ""))
		query = string.lower(tostring(query or "")):gsub("^%s+", ""):gsub("%s+$", "")
		if query == "" then return true end
		for word in query:gmatch("%S+") do
			if not haystack:find(word, 1, true) then return false end
		end
		return true
	end

	local function ColumnHasSearchMatch(column, query)
		if not column or query == "" then return query == "" end
		for _, section in ipairs(column:GetChildren()) do
			if section:IsA("Frame") and section.Name == "Section" then
				local elementsFrame = section:FindFirstChild("Elements")
				local sectionLabel = section:FindFirstChild("SectionLabel", true) or section:FindFirstChild("SectionTitle", true)
				if sectionLabel and SearchMatches(GetSearchText(sectionLabel), query) then return true end
				if elementsFrame then
					for _, element in ipairs(elementsFrame:GetChildren()) do
						if element:IsA("GuiObject") then
							local baseVisible = element:GetAttribute("NLSearchBaseVisible")
							if baseVisible == nil then baseVisible = element.Visible end
							if baseVisible and SearchMatches(GetSearchText(element), query) then return true end
						end
					end
				end
			end
		end
		return false
	end

	local function FindSearchTarget(query)
		if query == "" then return nil, nil, false end
		-- Prefer content in the actually active tab/subtab. Base-tab columns can
		-- remain in the tree while a subtab is selected; considering them first
		-- produced incorrect search hints for hidden content.
		for _, holder in ipairs({ TabHose, SubTabHose }) do
			for _, column in ipairs(holder:GetChildren()) do
				if column:IsA("ScrollingFrame")
					and column:GetAttribute("TabIndex") == activeTabIndex
					and IsSearchColumnActive(column)
					and ColumnHasSearchMatch(column, query) then
					return activeTabIndex, holder == SubTabHose and column:GetAttribute("SubTabIndex") or nil, false
				end
			end
		end
		-- Then search settings in other tabs and subtabs.
		for _, holder in ipairs({ TabHose, SubTabHose }) do
			for _, column in ipairs(holder:GetChildren()) do
				if column:IsA("ScrollingFrame") and ColumnHasSearchMatch(column, query) then
					return column:GetAttribute("TabIndex"), holder == SubTabHose and column:GetAttribute("SubTabIndex") or nil, false
				end
			end
		end
		-- Finally allow navigation labels (tab/subtab names) to be searched as well.
		for _, tab in ipairs(tabs) do
			if SearchMatches(tab.name, query) then return tab.tabIndex, nil, true end
			for _, subtab in ipairs(tab.subTabs or {}) do
				if SearchMatches(subtab.name, query) then return tab.tabIndex, subtab.index, true end
			end
		end
		return nil, nil, false
	end

	local function _applySearchImpl(query)
		query = string.lower(tostring(query or "")):gsub("^%s+", ""):gsub("%s+$", "")
		local targetTab, targetSubTab, navOnly
		if query ~= "" then
			targetTab, targetSubTab, navOnly = FindSearchTarget(query)
			-- Don't switch pages while the user is still typing. Matching pages and
			-- subtabs are exposed in navigation; the user chooses when to jump.
			if navOnly and targetTab == activeTabIndex then query = "" end
		end
		local columnHasMatch = false
		for _, holder in ipairs({ TabHose, SubTabHose }) do
		for _, column in ipairs(holder:GetChildren()) do
			if column:IsA("ScrollingFrame") and (column.Name == "Left" or column.Name == "Right" or string.sub(column.Name, 1, 6) == "STLeft" or string.sub(column.Name, 1, 7) == "STRight") then
				local activeColumn = IsSearchColumnActive(column)
				if not activeColumn then
					column.Visible = false
				else
					local columnMatch = query == ""
					for _, section in ipairs(column:GetChildren()) do
						if section:IsA("Frame") and section.Name == "Section" then
							local elementsFrame = section:FindFirstChild("Elements")
							local sectionLabel = section:FindFirstChild("SectionLabel", true) or section:FindFirstChild("SectionTitle", true)
							local sectionText = sectionLabel and GetSearchText(sectionLabel) or ""
							local sectionBaseVisible = section:GetAttribute("NLSearchBaseVisible")
							if sectionBaseVisible == nil then
								sectionBaseVisible = section.Visible
								section:SetAttribute("NLSearchBaseVisible", sectionBaseVisible)
							end
							local sectionMatch = query == "" or SearchMatches(sectionText, query)
							local anyVisible = false
							if elementsFrame then
								local elementsBaseVisible = elementsFrame:GetAttribute("NLSearchBaseVisible")
								if elementsBaseVisible == nil then
									elementsBaseVisible = elementsFrame.Visible
									elementsFrame:SetAttribute("NLSearchBaseVisible", elementsBaseVisible)
								end
								for _, element in ipairs(elementsFrame:GetChildren()) do
									if element:IsA("GuiObject") then
										local baseVisible = element:GetAttribute("NLSearchBaseVisible")
										if baseVisible == nil then
											baseVisible = element.Visible
											element:SetAttribute("NLSearchBaseVisible", baseVisible)
										end
										local elementText = GetSearchText(element)
										local matches = baseVisible and (query == "" or sectionMatch or SearchMatches(elementText, query))
										element.Visible = matches
										if matches then anyVisible = true end
									end
								end
								elementsFrame.Visible = elementsBaseVisible and anyVisible
							end
							if sectionLabel then
								local labelBaseVisible = sectionLabel:GetAttribute("NLSearchBaseVisible")
								if labelBaseVisible == nil then
									labelBaseVisible = sectionLabel.Visible
									sectionLabel:SetAttribute("NLSearchBaseVisible", labelBaseVisible)
								end
								sectionLabel.Visible = labelBaseVisible and anyVisible
							end
							section.Visible = sectionBaseVisible and anyVisible
							if anyVisible then columnMatch = true end
						end
					end
					column.Visible = columnMatch
					if columnMatch and query ~= "" then columnHasMatch = true end
				end
			end
		end
		end
		for _, row in ipairs(Tab:GetChildren()) do
			if row.Name == "TabButton" then
				local label = row:FindFirstChild("TabText")
				local matches = query == "" or (label and SearchMatches(label.Text, query)) or false
				if not matches and query ~= "" then
					local rowTabIndex = row:GetAttribute("TabIndex")
					for _, holder in ipairs({ TabHose, SubTabHose }) do
						for _, column in ipairs(holder:GetChildren()) do
							if column:IsA("ScrollingFrame") and column:GetAttribute("TabIndex") == rowTabIndex and ColumnHasSearchMatch(column, query) then
								matches = true; break
							end
						end
						if matches then break end
					end
				end
				row.Visible = matches
				local searchIndicator = row:FindFirstChild("SelectedIndicator")
				if searchIndicator and row:GetAttribute("TabIndex") ~= activeTabIndex then
					local matchedRail = query ~= "" and matches
					Tween(searchIndicator, { BackgroundTransparency = matchedRail and 0.42 or 1 }, 0.12, Enum.EasingStyle.Sine, Enum.EasingDirection.Out)
				end
			elseif row.Name == "SubTabContainer" then
				if row:GetAttribute("TabIndex") ~= activeTabIndex then
					row.Visible = false
				else
					local anyVisible = false
					for _, child in ipairs(row:GetChildren()) do
						if child:IsA("Frame") and string.sub(child.Name, 1, 6) == "STRow" then
							local label = child:FindFirstChild("STLabel")
							local matches = query == "" or (label and SearchMatches(label.Text, query)) or false
							if not matches and query ~= "" then
								local rowTabIndex = child:GetAttribute("TabIndex")
								local rowSubTabIndex = child:GetAttribute("SubTabIndex")
								for _, column in ipairs(SubTabHose:GetChildren()) do
									if column:IsA("ScrollingFrame") and column:GetAttribute("TabIndex") == rowTabIndex and column:GetAttribute("SubTabIndex") == rowSubTabIndex and ColumnHasSearchMatch(column, query) then
										matches = true; break
									end
								end
							end
							child.Visible = matches
							local subtabIndex = child:GetAttribute("SubTabIndex")
							local selectedSubtab = row:GetAttribute("TabIndex") == activeTabIndex and tabs[activeTabIndex] and tabs[activeTabIndex].activeSubTabIndex == subtabIndex
							local searchIndicator = child:FindFirstChild("SelectedIndicator")
							if searchIndicator and not selectedSubtab then
								local matchedRail = query ~= "" and matches
								Tween(searchIndicator, { BackgroundTransparency = matchedRail and 0.42 or 1 }, 0.12, Enum.EasingStyle.Sine, Enum.EasingDirection.Out)
							end
							if matches then anyVisible = true end
						end
					end
					row.Visible = query == "" or anyVisible
				end
			end
		end

		local emptyState = Frame2:FindFirstChild("SearchEmptyState")
		if emptyState and emptyState:IsA("TextLabel") then
			if query == "" or columnHasMatch then
				emptyState.Visible = false
			else
				if targetTab and tabs[targetTab] then
					if targetSubTab and tabs[targetTab].subTabs and tabs[targetTab].subTabs[targetSubTab] then
						emptyState.Text = "MATCH IN " .. string.upper(tostring(tabs[targetTab].name)) .. " / " .. string.upper(tostring(tabs[targetTab].subTabs[targetSubTab].name)) .. "\nSELECT THE HIGHLIGHTED TAB"
					else
						emptyState.Text = "MATCH IN " .. string.upper(tostring(tabs[targetTab].name)) .. "\nSELECT THE HIGHLIGHTED TAB"
					end
				else
					emptyState.Text = "NO MATCHING SETTINGS"
				end
				emptyState.Visible = true
			end
		end

		return columnHasMatch
	end

	ApplySearch = _applySearchImpl
	SearchBox:GetPropertyChangedSignal("Text"):Connect(function()
		-- Re-filter after a short pause so a whole word is searched, not every key.
		SearchBox:SetAttribute("SearchApplyToken", (SearchBox:GetAttribute("SearchApplyToken") or 0) + 1)
		local token = SearchBox:GetAttribute("SearchApplyToken")
		task.delay(0.075, function()
			if SearchBox.Parent and SearchBox:GetAttribute("SearchApplyToken") == token and ApplySearch then
				ApplySearch(SearchBox.Text)
			end
		end)
	end)


WindowObj._setupWindowToggle = function()
local Line9 = Instance.new('Frame')
Line9.Name = "Line9"
Line9.Position = UDim2.new(0.008, 0, 0, 53)
Line9.Size = UDim2.new(0.222, 0, 0, 1)
Line9.BackgroundColor3 = Color3.fromRGB(255, 255, 255)
Line9.BackgroundTransparency = 0.93
Line9.BorderSizePixel = 0
Line9.Parent = MainFrame
	Line9.Visible = false

	MakeDraggable(MainFrame, DragHandle)
	WindowObj._configExtras.pos_menu = {
		get = function()
			local pos, size = MainFrame.Position, windowTargetSize
			return { pos.X.Scale, pos.X.Offset, pos.Y.Scale, pos.Y.Offset, size.X.Scale, size.X.Offset, size.Y.Scale, size.Y.Offset }
		end,
		set = function(v)
			if type(v) ~= "table" or type(v[4]) ~= "number" then return end
			MainFrame.Position = UDim2.new(v[1], v[2], v[3], v[4])
			if type(v[8]) == "number" then
				windowTargetSize = UDim2.new(v[5], v[6], v[7], v[8])
				MainFrame.Size = windowTargetSize
			end
		end,
	}

	
	local ToggleBtn = Instance.new("TextButton")
	ToggleBtn.Name = "ToggleBtn"
	ToggleBtn.Position = UDim2.new(0, 10, 0, 10)
   ToggleBtn.BackgroundTransparency = 1
   ToggleBtn.Active = true
   ToggleBtn.Draggable = false
	ToggleBtn.Size = UDim2.new(0, 100, 0, 28)
	ToggleBtn.BackgroundColor3 = Color3.fromRGB(17, 19, 27)
	ToggleBtn.BorderSizePixel = 1
	ToggleBtn.Text = "Close  [RShift]"
	ToggleBtn.TextColor3 = Color3.fromRGB(255, 255, 255)
	ToggleBtn.TextScaled = false
	ToggleBtn.Font = FONT
	ToggleBtn.ZIndex = 999
	ToggleBtn.Parent = NeverloseCS2
	do local c = Instance.new("UICorner"); c.CornerRadius = UDim.new(0, 6); c.Parent = ToggleBtn end
	-- The loader (outside this function) hides it until loading ends.
	WindowObj._toggleBtn = ToggleBtn
	-- Not shown: RShift toggles the menu; the button stays for scripts.
	ToggleBtn.Visible = false
	



	local guiOpen = true

	-- Fades every descendant of `root` (backgrounds, text, images, outlines)
	-- together. Closing remembers each value ("FadeBase_<prop>") and tweens it
	-- to clear; opening tweens back to the remembered values.
	WindowObj._fadeTree = function(root, show, dur)
		if show == (root:GetAttribute("TreeFaded") ~= true) then return end
		root:SetAttribute("TreeFaded", not show)
		local info = TweenInfo.new(dur, Enum.EasingStyle.Sine, show and Enum.EasingDirection.Out or Enum.EasingDirection.In)
		for _, d in ipairs(root:GetDescendants()) do
			local props
			if d:IsA("GuiObject") then
				props = { "BackgroundTransparency" }
				if d:IsA("TextLabel") or d:IsA("TextButton") or d:IsA("TextBox") then table.insert(props, "TextTransparency") end
				if d:IsA("ImageLabel") or d:IsA("ImageButton") or d:IsA("ViewportFrame") then table.insert(props, "ImageTransparency") end
			elseif d:IsA("UIStroke") then
				props = { "Transparency" }
			end
			if props then
				local goal
				for _, prop in ipairs(props) do
					-- Keyed by root, so nested fades (menu over a panel) keep
					-- their own remembered values.
					local key = "FB_" .. root.Name .. "_" .. prop
					if show then
						local base = d:GetAttribute(key)
						if base ~= nil then
							goal = goal or {}
							goal[prop] = base
							d:SetAttribute(key, nil)
						end
					elseif d[prop] < 1 then
						d:SetAttribute(key, d[prop])
						goal = goal or {}
						goal[prop] = 1
					end
				end
				if goal then TweenService:Create(d, info, goal):Play() end
			end
		end
	end

	-- A column that just became visible fades in from clear (0.2s). Skipped
	-- while the window itself is fading, so the two fades never overlap.
	WindowObj._fadeColumn = function(column)
		if MainFrame:GetAttribute("TreeFaded") then return end
		WindowObj._fadeTree(column, true, 0)
		WindowObj._fadeTree(column, false, 0)
		WindowObj._fadeTree(column, true, 0.2)
	end

	-- Opening/closing: the window, everything in it (open plates, presets,
	-- profile, pickers) and the hotkey/spectator lists fade on one timeline.
	local function AnimateWindow(open)
		local dur = open and 0.3 or 0.2
		local part = AcrylicBlur and AcrylicBlur.Instances and AcrylicBlur.Instances.Part
		local dof = AcrylicBlur and AcrylicBlur.Instances and AcrylicBlur.Instances.DepthOfField
		WindowObj._menuOpen = open
		if WindowObj.KeybindList then pcall(WindowObj.KeybindList.refresh) end
		if WindowObj.SpectatorList then pcall(WindowObj.SpectatorList.refresh) end
		if open then
			-- Opening rises 14px into place while it grows and fades in.
			local rest = WindowObj._menuRestPos or MainFrame.Position
			WindowObj._menuRestPos = nil
			MainFrame.Position = UDim2.new(rest.X.Scale, rest.X.Offset, rest.Y.Scale, rest.Y.Offset + 14)
			Tween(MainFrame, { Position = rest }, dur, Enum.EasingStyle.Quint, Enum.EasingDirection.Out)
			MainFrame.Visible = true
			WindowObj._fadeTree(MainFrame, true, dur)
			MainFrame.BackgroundTransparency = 1
			MainFrame.Size = windowAnimSize
			Tween(MainFrame, { BackgroundTransparency = 0.25 }, dur, Enum.EasingStyle.Sine, Enum.EasingDirection.Out)
			Tween(MainFrame, { Size = windowTargetSize }, dur, Enum.EasingStyle.Quint, Enum.EasingDirection.Out)
		else
			-- Closing sinks 10px while it shrinks and fades; the place is kept.
			local rest = WindowObj._menuRestPos or MainFrame.Position
			WindowObj._menuRestPos = rest
			Tween(MainFrame, { Position = UDim2.new(rest.X.Scale, rest.X.Offset, rest.Y.Scale, rest.Y.Offset + 10) }, dur, Enum.EasingStyle.Quad, Enum.EasingDirection.In)
			WindowObj._fadeTree(MainFrame, false, dur)
			Tween(MainFrame, { BackgroundTransparency = 1 }, dur, Enum.EasingStyle.Sine, Enum.EasingDirection.In)
			Tween(MainFrame, { Size = windowAnimSize }, dur, Enum.EasingStyle.Quad, Enum.EasingDirection.In)
			task.delay(dur + 0.02, function()
				if guiOpen then return end
				-- Plates close only once everything has faded with the window.
				HideAllPopupsNow(true)
				if ConfigMainFrame then ConfigMainFrame.Visible = false end
				if WindowSettingsFrame then WindowSettingsFrame.Visible = false end
				if Save then Save.Visible = false end
				if RecentlyDeletedPanel then RecentlyDeletedPanel.Visible = false end
				MainFrame.Visible = false
				MainFrame.Size = windowTargetSize
				if WindowObj._menuRestPos then MainFrame.Position = WindowObj._menuRestPos end
				if part then part.Transparency = 1 end
				if dof and #WindowObj._blurs == 0 then dof.Enabled = false end
			end)
		end
		if part then
			local target = open and (part:GetAttribute("TargetTransparency") or 0.8) or 1
			Tween(part, { Transparency = target }, dur)
		end
		if dof then dof.Enabled = open or #WindowObj._blurs > 0 end
	end

	AcrylicBlur.toggleGui = function()
    guiOpen = not guiOpen
    ToggleBtn.Text = guiOpen and "Close [RShift]" or "Open  [RShift]"
    Tween(ToggleBtn, {
        BackgroundColor3 = guiOpen and Color3.fromRGB(17, 19, 27) or Color3.fromRGB(33,37,53)
    }, 0.1)
    	if guiOpen then
        if Save then Save.Visible = true end
        if AcrylicBlur.Signal then
            pcall(function() AcrylicBlur.Signal:Disconnect() end)
            AcrylicBlur.Signal = nil
        end
        AcrylicBlur.Signal = game:GetService("RunService").RenderStepped:Connect(AcrylicBlur.Update)
    else
        if AcrylicBlur.Signal then
            AcrylicBlur.Signal:Disconnect()
            AcrylicBlur.Signal = nil
        end
    end
    AnimateWindow(guiOpen)
end

	ToggleBtn.MouseButton1Click:Connect(AcrylicBlur.toggleGui)

	UserInputService.InputBegan:Connect(function(input, gameProcessed)
		if gameProcessed then return end
		if menuBind and input.KeyCode == menuBind then
			AcrylicBlur.toggleGui()
		end
	end)

	if Library.ShowLoader ~= false then
		-- The loader toast opens the window when it finishes (see below).
		guiOpen = false
		MainFrame.Visible = false
		local part = AcrylicBlur.Instances and AcrylicBlur.Instances.Part
		if part then part.Transparency = 1 end
		if AcrylicBlur.Instances and AcrylicBlur.Instances.DepthOfField then AcrylicBlur.Instances.DepthOfField.Enabled = false end
	else
		-- The glass part only tracks the window while this runs; it used to start
		-- on the first RShift toggle, so the blur showed up late.
		if not AcrylicBlur.Signal then
			AcrylicBlur.Signal = game:GetService("RunService").RenderStepped:Connect(AcrylicBlur.Update)
		end
		MainFrame.BackgroundTransparency = 1
		Tween(MainFrame, { BackgroundTransparency = 0.25 }, 0.18)
	end
end
WindowObj._setupWindowToggle()
WindowObj._setupWindowToggle = nil

-- Neverlose-style loader toast: NL badge, "neverlose", progress "k of 10" and an
-- accent gradient running around the border. Opens the window when done.
-- Set Library.ShowLoader = false before AddWindow to skip it.
if Library.ShowLoader ~= false then task.spawn(function()
	-- Loader in the watermark's look (dark see-through capsule over the blur)
	-- framed by the soft accent glow whose bright side slowly circles; NL
	-- badge, title, status and "k of 10".
	local toast = New("Frame", {
		Name = "NeverloseLoader",
		AnchorPoint = Vector2.new(1, 0),
		-- Top right like the watermark, 8px under the real screen top (the
		-- ScreenGui keeps the top-bar inset); starts off-screen, slides in.
		Position = UDim2.new(1, 360, 0, 8 - (WindowObj._topInset or 0)),
		Size = UDim2.fromOffset(320, 60),
		BackgroundColor3 = Color3.fromRGB(8, 9, 12),
		BackgroundTransparency = 0.3,
		BorderSizePixel = 0,
		ZIndex = Z_BASE + 990,
	}, NeverloseCS2)
	-- Rounded card, not a capsule (Neverlose loader).
	New("UICorner", { CornerRadius = UDim.new(0, 18) }, toast)
	if WindowObj._attachBlur then WindowObj._attachBlur(toast, 8) end
	-- Glow: faint capsule layers in the accent colour fading outwards, each
	-- with a gradient so one side is brighter; rotating it moves the light.
	local glowGradients = {}
	for i = 1, 10 do
		local spread = i * 2
		local layer = New("Frame", {
			Name = "LoaderGlow" .. i, Position = UDim2.fromOffset(-spread, -spread), Size = UDim2.new(1, spread * 2, 1, spread * 2),
			BackgroundColor3 = mainColor, BackgroundTransparency = 0.72 + i * 0.026, BorderSizePixel = 0, ZIndex = Z_BASE + 989 - i,
		}, toast)
		New("UICorner", { CornerRadius = UDim.new(0, 18 + spread) }, layer)
		local g = Instance.new("UIGradient")
		g.Transparency = NumberSequence.new({
			NumberSequenceKeypoint.new(0, 0), NumberSequenceKeypoint.new(0.5, 0.45), NumberSequenceKeypoint.new(1, 0.85),
		})
		g.Rotation = 120
		g.Parent = layer
		table.insert(glowGradients, g)
	end
	task.spawn(function()
		local angle = 120
		while toast.Parent do
			local dt = RunService.RenderStepped:Wait()
			angle = (angle + dt * 90) % 360
			for _, g in ipairs(glowGradients) do g.Rotation = angle end
		end
	end)

	local badge = New("Frame", {
		Name = "Badge", AnchorPoint = Vector2.new(0, 0.5), Position = UDim2.new(0, 10, 0.5, 0),
		Size = UDim2.fromOffset(38, 38), BackgroundColor3 = Color3.fromRGB(14, 17, 30), BorderSizePixel = 0, ZIndex = Z_BASE + 991,
	}, toast)
	New("UICorner", { CornerRadius = UDim.new(0, 11) }, badge)
	-- Same logo as the window badge: custom image, or the drawn "NL".
	if hubImage ~= "" then
		local badgeLogo = New("ImageLabel", {
			Name = "BadgeLogo", Size = UDim2.fromScale(1, 1), BackgroundTransparency = 1,
			Image = hubImage, ScaleType = Enum.ScaleType.Stretch, ZIndex = Z_BASE + 992,
		}, badge)
		New("UICorner", { CornerRadius = UDim.new(0, 10) }, badgeLogo)
	else
		WindowObj._logoWithFallback(badge, 17, Z_BASE + 992, 11)
	end
	New("TextLabel", {
		Name = "LoaderTitle", Position = UDim2.fromOffset(60, 11), Size = UDim2.new(1, -140, 0, 20), BackgroundTransparency = 1,
		Text = tostring(hubTitle), TextColor3 = Color3.fromRGB(240, 241, 246), TextSize = 16, Font = FONT_BOLD,
		TextXAlignment = Enum.TextXAlignment.Left, ZIndex = Z_BASE + 991,
	}, toast)
	local status = New("TextLabel", {
		Name = "LoaderStatus", Position = UDim2.fromOffset(60, 31), Size = UDim2.new(1, -84, 0, 16), BackgroundTransparency = 1,
		Text = "Initialization in progress", TextColor3 = Color3.fromRGB(160, 162, 172), TextSize = 13,
		TextXAlignment = Enum.TextXAlignment.Left, ZIndex = Z_BASE + 991,
	}, toast)
	local counter = New("TextLabel", {
		Name = "LoaderCounter", AnchorPoint = Vector2.new(1, 0), Position = UDim2.new(1, -24, 0, 11), Size = UDim2.fromOffset(70, 20),
		BackgroundTransparency = 1, Text = "0 of 10", TextColor3 = Color3.fromRGB(225, 227, 234), TextSize = 14, Font = FONT_BOLD,
		TextXAlignment = Enum.TextXAlignment.Right, ZIndex = Z_BASE + 991,
	}, toast)
	counter.Font = FONT_BOLD -- New() resets fonts by name; bold as on Neverlose

	-- The watermark waits for the loader, like Neverlose's.
	-- (Later SetWatermark calls stay hidden too: ApplyWatermarkLayout checks the flag.)
	WindowObj._loaderActive = true
	local watermarkFrame = WindowObj.Watermark and WindowObj.Watermark.frame
	if watermarkFrame then watermarkFrame.Visible = false end
	if WindowObj._toggleBtn then WindowObj._toggleBtn.Visible = false end

	-- Wait for the logo texture first (max ~1.5 s) so the toast never slides in
	-- with an empty badge.
	do
		local done = false
		task.spawn(function()
			pcall(function() game:GetService("ContentProvider"):PreloadAsync(badge:GetDescendants()) end)
			done = true
		end)
		local waited = 0
		while not done and waited < 1.5 do waited = waited + task.wait() end
	end
	-- Slides in from the right while everything on it fades in.
	WindowObj._fadeTree(toast, false, 0)
	local toastAlpha = toast.BackgroundTransparency
	toast.BackgroundTransparency = 1
	Tween(toast, { Position = UDim2.new(1, -8, 0, 8 - (WindowObj._topInset or 0)), BackgroundTransparency = toastAlpha }, 0.5, Enum.EasingStyle.Quint, Enum.EasingDirection.Out)
	WindowObj._fadeTree(toast, true, 0.4)
	-- Real work behind the counter: every image the interface uses is
	-- preloaded in batches (one step each), then fonts and configs.
	do
		local seen, assets = {}, {}
		for _, d in ipairs(NeverloseCS2:GetDescendants()) do
			if (d:IsA("ImageLabel") or d:IsA("ImageButton")) and d.Image ~= "" and not seen[d.Image] then
				seen[d.Image] = true
				table.insert(assets, d)
			end
		end
		local stepNames = { "Loading interface", "Loading icons", "Loading icons", "Loading icons", "Loading images",
			"Loading images", "Loading avatar", "Loading fonts", "Loading configs", "Finishing" }
		local per = math.max(1, math.ceil(#assets / 8))
		local ContentProvider = game:GetService("ContentProvider")
		for step = 1, 10 do
			status.Text = stepNames[step] .. "..."
			local started = os.clock()
			if step <= 8 then
				local batch = {}
				for i = (step - 1) * per + 1, math.min(step * per, #assets) do table.insert(batch, assets[i]) end
				if #batch > 0 then pcall(function() ContentProvider:PreloadAsync(batch) end) end
			elseif step == 9 and type(listfiles) == "function" then
				pcall(listfiles, "")
			end
			-- keep each step readable even when it finished instantly
			local left = 0.12 - (os.clock() - started)
			if left > 0 then task.wait(left) end
			counter.Text = tostring(step) .. " of 10"
		end
	end
	status.Text = "Initialization complete"
	task.wait(0.5)
	if AcrylicBlur.toggleGui then AcrylicBlur.toggleGui() end
	WindowObj._loaderActive = false
	if WindowObj._autoLoad then task.defer(WindowObj._autoLoad) end
	if watermarkFrame and WindowObj.Watermark.applyLayout then WindowObj.Watermark.applyLayout(nil, nil) end
	if WindowObj.KeybindList then WindowObj.KeybindList.refresh() end
	if WindowObj.SpectatorList then WindowObj.SpectatorList.refresh() end
	task.wait(0.8)
	Tween(toast, { Position = UDim2.new(1, 380, 0, 8 - (WindowObj._topInset or 0)), BackgroundTransparency = 1 }, 0.4, Enum.EasingStyle.Quint, Enum.EasingDirection.In)
	WindowObj._fadeTree(toast, false, 0.3)
	task.wait(0.42)
	toast:Destroy()
end) end


	function WindowObj:AddTabLabel(text)
		text = tostring(text or ""):gsub("^%s+", ""):gsub("%s+$", "")
		local hasPreviousCategory = false
		for _, child in ipairs(Tab:GetChildren()) do
			if child:IsA("TextLabel") and child.Name == "TabLabel" then
				hasPreviousCategory = true
				break
			end
		end

		-- Use a real spacer instead of vertical UIPadding inside a 22px label.
		-- The old padding consumed almost the whole label height, making
		-- "Aimbot" and "Common" headers appear cramped and visually merge.
		if hasPreviousCategory then
			tabOrder = tabOrder + 1
			New("Frame", {
				Name = "TabCategorySpacer",
				Size = UDim2.new(1, 0, 0, 7),
				BackgroundTransparency = 1,
				BorderSizePixel = 0,
				LayoutOrder = tabOrder,
			}, Tab)
		end

		tabOrder = tabOrder + 1
		local lbl = New("TextLabel", {
			Name = "TabLabel",
			Size = UDim2.new(1, 0, 0, 17),
			BackgroundTransparency = 1,
			BorderSizePixel = 0,
			Text = text:upper(),
			TextColor3 = Color3.fromRGB(112, 116, 138),
			TextScaled = false,
			TextSize = 11,
			Font = FONT,
			TextTransparency = 0.1,
			TextXAlignment = Enum.TextXAlignment.Left,
			TextYAlignment = Enum.TextYAlignment.Center,
			LayoutOrder = tabOrder,
		}, Tab)
		New("UIPadding", {
			PaddingLeft = UDim.new(0, 11),
		}, lbl)

		return lbl
	end

	-- Neverlose "Players" preview for the right column of a tab or sub-tab:
	-- Enemies / Teammates switch, ESP Items and expand buttons on top; below,
	-- your character standing idle, or the ESP Items picker (chips in Main,
	-- Flags and Weapon groups). Sections bound to a team show only while that
	-- team is open. Built in a function of its own (register budget).
	-- options: team ("Enemies"/"Teammates"), sections = { Enemies = {...},
	-- Teammates = {...} } (section objects), groups = { { "Main", {...} }, ... },
	-- onTeam(team), onItem(team, group, item, on).
	WindowObj._buildESPPreview = function(leftCol, rightCol, options)
		options = type(options) == "table" and options or {}
		local LAVENDER, MUTED, TEXT = Color3.fromRGB(150, 164, 255), Color3.fromRGB(176, 178, 188), Color3.fromRGB(235, 236, 241)
		local GROUPS = type(options.groups) == "table" and options.groups or {
			{ "Main", { "Bounding Box", "Name", "Distance", "Health Bar", "Ammo Bar", "Skeleton" } },
			{ "Flags", { "Unarmored", "Defuser", "Blind", "Scoped", "Reload", "Immunity", "Slowed", "Vulnerable", "Bomb",
				"Hostage", "Defuse", "Pin Pulled", "Money", "Order Priority", "Delay" } },
			{ "Weapon", { "Text", "Icon", "Readiness Bar", "Bomb", "Defuser", "Taser" } },
			{ "Aimbot", { "Hit Chance", "Hitboxes" } },
		}
		local TEAMS = { { "Enemies", "rbxassetid://10747373176" }, { "Teammates", "rbxassetid://10747372346" } }
		local team = options.team == "Teammates" and "Teammates" or "Enemies"
		local state = { Enemies = {}, Teammates = {} }
		local showItems, scaleTogether = false, options.scaleTogether ~= false

		local page = New("Frame", { Name = "ESPPreview", Size = UDim2.new(1, 0, 0, 420), BackgroundTransparency = 1, LayoutOrder = 100 }, rightCol)
		local function fit()
			local h = rightCol.AbsoluteSize.Y - 14
			if h > 100 then page.Size = UDim2.new(1, 0, 0, h) end
		end
		rightCol:GetPropertyChangedSignal("AbsoluteSize"):Connect(fit)
		task.defer(fit)

		-- ------------------------------------------------------------ top bar
		-- Not "TopBar": New() styles that name as a dropdown field (plate).
		local bar = New("Frame", { Name = "PreviewBar", Size = UDim2.new(1, 0, 0, 28), BackgroundTransparency = 1 }, page)
		local teamButtons, tools = {}, {}
		local function iconButton(name, icon)
			local b = New("TextButton", {
				Name = name, Size = UDim2.fromOffset(24, 24), BackgroundColor3 = Color3.fromRGB(35, 38, 50), BackgroundTransparency = 1,
				AutoButtonColor = false, Text = "", BorderSizePixel = 0, ClipsDescendants = true,
			}, bar)
			New("UICorner", { CornerRadius = UDim.new(0, 6) }, b)
			New("ImageLabel", {
				Name = "Icon", AnchorPoint = Vector2.new(0, 0.5), Position = UDim2.new(0, 5, 0.5, 0), Size = UDim2.fromOffset(14, 14),
				BackgroundTransparency = 1, Image = icon, ImageColor3 = MUTED, ScaleType = Enum.ScaleType.Fit,
			}, b)
			return b
		end
		for _, def in ipairs(TEAMS) do
			local b = iconButton("Team_" .. def[1], def[2])
			local title = New("TextLabel", {
				Name = "TeamTitle", Position = UDim2.fromOffset(25, 0), Size = UDim2.new(0, 90, 1, 0), BackgroundTransparency = 1,
				Text = def[1], TextColor3 = LAVENDER, TextSize = 14, Font = FONT, TextXAlignment = Enum.TextXAlignment.Left, TextTransparency = 1,
			}, b)
			teamButtons[def[1]] = { button = b, title = title, icon = b:FindFirstChild("Icon") }
		end
		tools.items = iconButton("ESPItems", "rbxassetid://10723424963") -- layout-list
		tools.expand = iconButton("ScaleItems", "rbxassetid://10734886496") -- maximize-2: scale ESP items together
		local function layoutBar(instant)
			local widths, total = {}, 0
			for _, def in ipairs(TEAMS) do
				local open = def[1] == team
				widths[def[1]] = open and math.ceil(25 + MeasureText(def[1], 14, FONT) + 8) or 24
				total = total + widths[def[1]] + 6
			end
			total = total + 10 + 24 + 6 + 24
			local x = math.max(0, math.floor((bar.AbsoluteSize.X - total) / 2))
			for _, def in ipairs(TEAMS) do
				local entry, open = teamButtons[def[1]], def[1] == team
				local goal = { Size = UDim2.fromOffset(widths[def[1]], 24), Position = UDim2.fromOffset(x, 2) }
				if instant then
					entry.button.Size, entry.button.Position = goal.Size, goal.Position
					entry.title.TextTransparency = open and 0 or 1
				else
					Tween(entry.button, goal, 0.24, Enum.EasingStyle.Quint, Enum.EasingDirection.Out)
					Tween(entry.title, { TextTransparency = open and 0 or 1 }, 0.18)
				end
				Tween(entry.icon, { ImageColor3 = open and LAVENDER or MUTED }, 0.15)
				x = x + widths[def[1]] + 6
			end
			x = x + 10
			for _, key in ipairs({ "items", "expand" }) do
				local b = tools[key]
				local goal = { Position = UDim2.fromOffset(x, 2) }
				if instant then b.Position = goal.Position else Tween(b, goal, 0.24, Enum.EasingStyle.Quint, Enum.EasingDirection.Out) end
				x = x + 30
			end
			Tween(tools.items, { BackgroundTransparency = showItems and 0 or 1 }, 0.15)
			Tween(tools.items.Icon, { ImageColor3 = showItems and TEXT or MUTED }, 0.15)
			Tween(tools.expand.Icon, { ImageColor3 = scaleTogether and LAVENDER or MUTED }, 0.15)
		end
		bar:GetPropertyChangedSignal("AbsoluteSize"):Connect(function() layoutBar(true) end)

		-- --------------------------------------------------------- model view
		local body = New("Frame", { Name = "Body", Position = UDim2.fromOffset(0, 34), Size = UDim2.new(1, 0, 1, -34), BackgroundTransparency = 1 }, page)
		local viewport = New("ViewportFrame", {
			Name = "PlayerView", Size = UDim2.fromScale(1, 1), BackgroundTransparency = 1,
			Ambient = Color3.fromRGB(150, 150, 165), LightColor = Color3.fromRGB(255, 255, 255), LightDirection = Vector3.new(-0.6, -1, -0.8),
		}, body)
		local world = Instance.new("WorldModel")
		world.Parent = viewport
		local camera = Instance.new("Camera")
		camera.FieldOfView = 30
		camera.Parent = viewport
		viewport.CurrentCamera = camera
		local model
		local function fitCamera()
			if not model then return end
			local cf, size = model:GetBoundingBox()
			local view = viewport.AbsoluteSize
			local aspect = (view.X > 0 and view.Y > 0) and view.X / view.Y or 0.75
			local span = math.max(size.Y, math.max(size.X, size.Z) / aspect)
			camera.CFrame = CFrame.new(cf.Position + Vector3.new(0, 0, span / 2 / math.tan(math.rad(15)) * 1.3), cf.Position)
		end
		viewport:GetPropertyChangedSignal("AbsoluteSize"):Connect(fitCamera)
		local function loadModel()
			world:ClearAllChildren()
			model = nil
			local char = LocalPlayer.Character
			if not char then return end
			local was = char.Archivable
			char.Archivable = true
			local ok, clone = pcall(function() return char:Clone() end)
			char.Archivable = was
			if not ok or not clone then return end
			local links = {}
			for _, d in ipairs(clone:GetDescendants()) do
				if d:IsA("BaseScript") or d:IsA("ModuleScript") or d:IsA("Sound") then
					d:Destroy()
				elseif d:IsA("BasePart") then
					d.Anchored = true
					d.CanCollide = false
				elseif (d:IsA("Motor6D") or d:IsA("Weld")) and d.Part0 and d.Part1 then
					table.insert(links, { a = d.Part0, b = d.Part1, rel = d.C0 * d.C1:Inverse() })
				elseif d:IsA("WeldConstraint") and d.Part0 and d.Part1 then
					table.insert(links, { a = d.Part0, b = d.Part1, rel = d.Part0.CFrame:ToObjectSpace(d.Part1.CFrame) })
				end
			end
			-- Idle: rebuild the body from the root through its joints at rest.
			local root = clone:FindFirstChild("HumanoidRootPart") or clone.PrimaryPart
			if root then
				local placed, progress = { [root] = true }, true
				while progress do
					progress = false
					for _, l in ipairs(links) do
						if l.a.Parent and l.b.Parent then
							if placed[l.a] and not placed[l.b] then
								l.b.CFrame = l.a.CFrame * l.rel
								placed[l.b], progress = true, true
							elseif placed[l.b] and not placed[l.a] then
								l.a.CFrame = l.b.CFrame * l.rel:Inverse()
								placed[l.a], progress = true, true
							end
						end
					end
				end
			end
			local humanoid = clone:FindFirstChildOfClass("Humanoid")
			if humanoid then humanoid.DisplayDistanceType = Enum.HumanoidDisplayDistanceType.None end
			clone.Parent = world
			clone:PivotTo(CFrame.Angles(0, math.pi, 0))
			model = clone
			fitCamera()
		end
		loadModel()
		LocalPlayer.CharacterAdded:Connect(function(char)
			char:WaitForChild("HumanoidRootPart", 10)
			task.wait(0.5)
			loadModel()
		end)

		-- ----------------------------------------------------------- ESP items
		local itemsCard = New("Frame", {
			Name = "ESPItems", Size = UDim2.fromScale(1, 1), BackgroundColor3 = Color3.fromRGB(18, 18, 25), BackgroundTransparency = 0.04,
			BorderSizePixel = 0, Visible = false,
		}, body)
		New("UICorner", { CornerRadius = UDim.new(0, 10) }, itemsCard)
		Stroke(itemsCard)
		New("TextLabel", {
			Name = "ItemsTitle", Position = UDim2.fromOffset(14, 0), Size = UDim2.new(1, -28, 0, 40), BackgroundTransparency = 1,
			Text = "ESP Items", TextColor3 = TEXT, TextSize = 15, Font = FONT, TextXAlignment = Enum.TextXAlignment.Left,
		}, itemsCard)
		New("Frame", {
			Name = "ItemsRule", Position = UDim2.fromOffset(0, 40), Size = UDim2.new(1, 0, 0, 1), BackgroundColor3 = Color3.fromRGB(255, 255, 255),
			BackgroundTransparency = 0.93, BorderSizePixel = 0,
		}, itemsCard)
		local scroller = New("ScrollingFrame", {
			Name = "ItemsList", Position = UDim2.fromOffset(6, 46), Size = UDim2.new(1, -12, 1, -52), BackgroundTransparency = 1,
			BorderSizePixel = 0, ScrollBarThickness = 2, AutomaticCanvasSize = Enum.AutomaticSize.Y, CanvasSize = UDim2.new(),
			ScrollingDirection = Enum.ScrollingDirection.Y,
		}, itemsCard)
		New("UIListLayout", { Padding = UDim.new(0, 8), SortOrder = Enum.SortOrder.LayoutOrder }, scroller)
		New("UIPadding", { PaddingBottom = UDim.new(0, 4), PaddingRight = UDim.new(0, 2) }, scroller)
		local chips = {}
		for g, group in ipairs(GROUPS) do
			local groupCard = New("Frame", {
				Name = "Group_" .. group[1], LayoutOrder = g, Size = UDim2.new(1, 0, 0, 0), AutomaticSize = Enum.AutomaticSize.Y,
				BackgroundColor3 = Color3.fromRGB(23, 23, 31), BackgroundTransparency = 0, BorderSizePixel = 0,
			}, scroller)
			New("UICorner", { CornerRadius = UDim.new(0, 8) }, groupCard)
			Stroke(groupCard)
			New("UIPadding", { PaddingLeft = UDim.new(0, 10), PaddingRight = UDim.new(0, 10), PaddingTop = UDim.new(0, 8), PaddingBottom = UDim.new(0, 10) }, groupCard)
			New("UIListLayout", { Padding = UDim.new(0, 8), SortOrder = Enum.SortOrder.LayoutOrder }, groupCard)
			New("TextLabel", {
				Name = "GroupTitle", LayoutOrder = 1, Size = UDim2.new(1, 0, 0, 18), BackgroundTransparency = 1,
				Text = group[1], TextColor3 = TEXT, TextSize = 14, Font = FONT, TextXAlignment = Enum.TextXAlignment.Left,
			}, groupCard)
			local wrap = New("Frame", { Name = "Chips", LayoutOrder = 2, Size = UDim2.new(1, 0, 0, 0), AutomaticSize = Enum.AutomaticSize.Y, BackgroundTransparency = 1 }, groupCard)
			New("UIListLayout", { FillDirection = Enum.FillDirection.Horizontal, Wraps = true, Padding = UDim.new(0, 6), SortOrder = Enum.SortOrder.LayoutOrder }, wrap)
			for i, item in ipairs(group[2]) do
				local chip = New("TextButton", {
					Name = "Chip", LayoutOrder = i, Size = UDim2.fromOffset(math.ceil(MeasureText(item, 13, FONT) + 18), 26),
					BackgroundColor3 = Color3.fromRGB(30, 32, 42), BackgroundTransparency = 0.2, AutoButtonColor = false,
					Text = item, TextColor3 = MUTED, TextSize = 13, Font = FONT, BorderSizePixel = 0,
				}, wrap)
				New("UICorner", { CornerRadius = UDim.new(0, 6) }, chip)
				Stroke(chip, "ChipOutline")
				local key = group[1] .. "/" .. item
				chips[key] = chip
				chip.MouseButton1Click:Connect(function()
					local on = not state[team][key]
					state[team][key] = on or nil
					Tween(chip, { BackgroundColor3 = on and Color3.fromRGB(44, 48, 66) or Color3.fromRGB(30, 32, 42), TextColor3 = on and TEXT or MUTED }, 0.12)
					local outline = chip:FindFirstChild("ChipOutline")
					if outline then Tween(outline, { Color = on and LAVENDER or STROKE.Color, Transparency = on and 0.35 or STROKE.Transparency }, 0.12) end
					if type(options.onItem) == "function" then pcall(options.onItem, team, group[1], item, on) end
				end)
			end
		end
		local function paintChips()
			for key, chip in pairs(chips) do
				local on = state[team][key] == true
				chip.BackgroundColor3 = on and Color3.fromRGB(44, 48, 66) or Color3.fromRGB(30, 32, 42)
				chip.TextColor3 = on and TEXT or MUTED
				local outline = chip:FindFirstChild("ChipOutline")
				if outline then
					outline.Color = on and LAVENDER or STROKE.Color
					outline.Transparency = on and 0.35 or STROKE.Transparency
				end
			end
		end

		-- ----------------------------------------------------- team & buttons
		local bound = { Enemies = {}, Teammates = {} }
		if type(options.sections) == "table" then
			for _, which in ipairs({ "Enemies", "Teammates" }) do
				for _, sec in ipairs(options.sections[which] or {}) do table.insert(bound[which], sec) end
			end
		end
		-- animated: the shown team's sections fade out, then the other team's
		-- fade in while the column rises (tab-switch motion).
		local swapToken = 0
		local function applySections(animated)
			local hide, show = {}, {}
			for which, list in pairs(bound) do
				for _, sec in ipairs(list) do
					local frame = type(sec) == "table" and sec.frame or sec
					if typeof(frame) == "Instance" then
						if which == team then table.insert(show, frame) else table.insert(hide, frame) end
					end
				end
			end
			if not animated then
				for _, f in ipairs(hide) do f.Visible = false end
				for _, f in ipairs(show) do f.Visible = true end
				return
			end
			swapToken = swapToken + 1
			local token = swapToken
			for _, f in ipairs(hide) do
				if f.Visible then WindowObj._fadeTree(f, false, 0.14) end
			end
			task.delay(0.14, function()
				if token ~= swapToken then return end
				for _, f in ipairs(hide) do
					f.Visible = false
					WindowObj._fadeTree(f, true, 0)
				end
				for _, f in ipairs(show) do
					f.Visible = true
					WindowObj._fadeTree(f, false, 0)
					WindowObj._fadeTree(f, true, 0.22)
				end
				AnimateSectionColumn(leftCol)
			end)
		end
		local api = { frame = page }
		function api:GetTeam() return team end
		function api:SetTeam(which)
			team = which == "Teammates" and "Teammates" or "Enemies"
			layoutBar(false)
			applySections(true)
			paintChips()
			if type(options.onTeam) == "function" then pcall(options.onTeam, team) end
			return self
		end
		function api:Bind(section, which)
			table.insert(bound[which == "Teammates" and "Teammates" or "Enemies"], section)
			applySections()
			return self
		end
		function api:IsItemOn(which, group, item) return state[which][group .. "/" .. item] == true end
		for which, entry in pairs(teamButtons) do
			entry.button.MouseButton1Click:Connect(function() if team ~= which then api:SetTeam(which) end end)
			entry.button.MouseEnter:Connect(function() if team ~= which then Tween(entry.button, { BackgroundTransparency = 0.6 }, 0.1) end end)
			entry.button.MouseLeave:Connect(function() Tween(entry.button, { BackgroundTransparency = 1 }, 0.14) end)
		end
		tools.items.MouseButton1Click:Connect(function()
			showItems = not showItems
			itemsCard.Visible = true
			if showItems then
				itemsCard.BackgroundTransparency = 1
				FadePopupContent(itemsCard, true, 0.18)
				Tween(itemsCard, { BackgroundTransparency = 0.04 }, 0.18)
				Tween(viewport, { ImageTransparency = 1 }, 0.18)
			else
				FadePopupContent(itemsCard, false, 0.16)
				Tween(itemsCard, { BackgroundTransparency = 1 }, 0.16)
				Tween(viewport, { ImageTransparency = 0 }, 0.18)
				task.delay(0.17, function() if not showItems then itemsCard.Visible = false end end)
			end
			layoutBar(false)
		end)
		-- Scale switch (Neverlose): on = ESP items scale together; hover shows
		-- what turning it off does.
		local tip = New("TextLabel", {
			Name = "ScaleTip", AnchorPoint = Vector2.new(0, 0.5), Size = UDim2.fromOffset(0, 26), AutomaticSize = Enum.AutomaticSize.X,
			BackgroundColor3 = Color3.fromRGB(18, 18, 25), BackgroundTransparency = 1, Text = "When disabled, ESP items are scaled individually",
			TextColor3 = TEXT, TextTransparency = 1, TextSize = 13, Font = FONT, Visible = false, ZIndex = 40,
		}, page)
		New("UICorner", { CornerRadius = UDim.new(0, 6) }, tip)
		New("UIPadding", { PaddingLeft = UDim.new(0, 10), PaddingRight = UDim.new(0, 10) }, tip)
		local tipToken = 0
		tools.expand.MouseEnter:Connect(function()
			tipToken = tipToken + 1
			local token = tipToken
			task.delay(0.35, function()
				if token ~= tipToken then return end
				local b = tools.expand
				tip.Position = UDim2.fromOffset(b.AbsolutePosition.X - page.AbsolutePosition.X + b.AbsoluteSize.X + 8, b.AbsolutePosition.Y - page.AbsolutePosition.Y + b.AbsoluteSize.Y / 2)
				tip.Visible = true
				Tween(tip, { BackgroundTransparency = 0.04, TextTransparency = 0 }, 0.14)
			end)
		end)
		tools.expand.MouseLeave:Connect(function()
			tipToken = tipToken + 1
			Tween(tip, { BackgroundTransparency = 1, TextTransparency = 1 }, 0.1)
			local token = tipToken
			task.delay(0.11, function() if token == tipToken then tip.Visible = false end end)
		end)
		tools.expand.MouseButton1Click:Connect(function()
			scaleTogether = not scaleTogether
			layoutBar(false)
			if type(options.onScale) == "function" then pcall(options.onScale, scaleTogether) end
		end)
		function api:GetScaleTogether() return scaleTogether end

		-- Saved with the config: open team and each team's ESP items.
		WindowObj._configExtras["esp_" .. tostring(options.id or "players")] = {
			get = function()
				local out = { team = team, scale = scaleTogether, Enemies = {}, Teammates = {} }
				for which, items in pairs(state) do for key in pairs(items) do table.insert(out[which], key) end end
				return out
			end,
			set = function(v)
				if type(v) ~= "table" then return end
				for _, which in ipairs({ "Enemies", "Teammates" }) do
					state[which] = {}
					for _, key in ipairs(type(v[which]) == "table" and v[which] or {}) do state[which][key] = true end
				end
				if type(v.scale) == "boolean" then scaleTogether = v.scale end
				api:SetTeam(v.team)
			end,
		}

		layoutBar(true)
		applySections()
		paintChips()
		return api
	end

	function WindowObj:AddTab(name, icon)
		local function TintTabIcon(iconObject, color, transparency, duration, style, direction)
			Tween(iconObject, { ImageColor3 = color, ImageTransparency = transparency }, duration, style, direction)
			-- Drawn glyphs follow ImageColor3 on their own (see _drawTabGlyph).
		end
		name = tostring(name or "Tab")
		if icon ~= nil and type(icon) ~= "string" then icon = "" end
		tabOrder = tabOrder + 1
		local tabIndex = #tabs + 1
		local isFirst = tabIndex == 1

		local TabButtonFrame = New("Frame", {
			Name = "TabButton",
			Size = UDim2.new(1, 0, 0, 32),
			-- Neverlose selected tab: a solid grey plate (~44,45,54). A faint white
			-- tint let the game behind the glass show through it.
			BackgroundColor3 = Color3.fromRGB(35, 38, 50),
			BackgroundTransparency = isFirst and 0.08 or 1,
			LayoutOrder = tabOrder,
		}, Tab)
		TabButtonFrame:SetAttribute("TabIndex", tabIndex)
		New("UICorner", { CornerRadius = UDim.new(0, 8) }, TabButtonFrame)
		local TabScale = New("UIScale", { Scale = 1 }, TabButtonFrame)
		local TabIndicator = New("Frame", {
			Name = "SelectedIndicator",
			AnchorPoint = Vector2.new(0, 0.5),
			Position = UDim2.new(0, 0, 0.5, 0),
			Size = UDim2.fromOffset(0, 0),
			BackgroundColor3 = mainColor,
			BackgroundTransparency = 1,
			BorderSizePixel = 0,
			ZIndex = 3,
		}, TabButtonFrame)
		New("UICorner", { CornerRadius = UDim.new(1, 0) }, TabIndicator)

		local TabIcon = New("ImageLabel", {
			Name = "TabIcon",
			Position = UDim2.new(0, 18, 0.5, 0),
			AnchorPoint = Vector2.new(0.5, 0.5),
			Size = UDim2.fromOffset(18, 18),
			BackgroundColor3 = Color3.fromRGB(255, 191, 255),
			BackgroundTransparency = 1,
			Image = "",
			ImageColor3 = isFirst and mainColor or Color3.fromRGB(150, 155, 172),
			ImageTransparency = 0,
		}, TabButtonFrame)
		if icon and icon ~= "" then
			GetImageData(icon, TabIcon)
		end
		-- Neverlose sidebar glyphs (Rage crosshair, Legit mouse, Misc...) drawn
		-- from frames; other names keep their image asset.
		WindowObj._drawTabGlyph(icon, TabIcon)
		table.insert(_coloredElements, { type = "tabicon", ref = TabIcon })
New("UIAspectRatioConstraint", {
			AspectRatio = 1,
		}, TabIcon)

		local TabText = New("TextLabel", {
			Name = "TabText",
			Position = UDim2.new(0, 38, 0, 0),
			Size = UDim2.new(1, -46, 1, 0),
			BackgroundColor3 = Color3.fromRGB(191, 255, 255),
			BackgroundTransparency = 1,
			Text = name,
			TextColor3 = isFirst and Color3.fromRGB(255, 255, 255) or Color3.fromRGB(150, 155, 172),
			TextScaled = false,
			TextSize = 14,
			Font = FONT,
			TextTransparency = 0,
			TextXAlignment = Enum.TextXAlignment.Left,
		}, TabButtonFrame)

		local ClickArea = New("TextButton", {
			Size = UDim2.new(1, 0, 1, 0),
			BackgroundTransparency = 1,
			Text = "",
			ZIndex = 5,
		}, TabButtonFrame)

		local Left = New("ScrollingFrame", {
			Name = "Left",
			Size = UDim2.new(0.49, 0, 1, 0),
			BackgroundColor3 = Color3.fromRGB(162, 162, 162),
			BackgroundTransparency = 1,
			ClipsDescendants = true,
			Active = true,
			AutomaticCanvasSize = Enum.AutomaticSize.Y,
			CanvasSize = UDim2.new(),
			ScrollingDirection = Enum.ScrollingDirection.Y,
			ScrollBarThickness = 0,
		}, TabHose)
		
		local Right = New("ScrollingFrame", {
			Name = "Right",
			Size = UDim2.new(0.49, 0, 1, 0),
			BackgroundColor3 = Color3.fromRGB(162, 162, 162),
			BackgroundTransparency = 1,
			LayoutOrder = 1,
			ClipsDescendants = true,
			Active = true,
			AutomaticCanvasSize = Enum.AutomaticSize.Y,
			CanvasSize = UDim2.new(),
			ScrollingDirection = Enum.ScrollingDirection.Y,
			ScrollBarThickness = 0,
		}, TabHose)
		Left:SetAttribute("SearchName", name)
		Right:SetAttribute("SearchName", name)
		Left:SetAttribute("TabIndex", tabIndex)
		Right:SetAttribute("TabIndex", tabIndex)
		New("UIPadding", { PaddingLeft = UDim.new(0, 2), PaddingRight = UDim.new(0, 2), PaddingTop = UDim.new(0, 0), PaddingBottom = UDim.new(0, 12) }, Left)
		New("UIPadding", { PaddingLeft = UDim.new(0, 2), PaddingRight = UDim.new(0, 2), PaddingTop = UDim.new(0, 0), PaddingBottom = UDim.new(0, 12) }, Right)
		New("UIListLayout", { Padding = UDim.new(0, 14), SortOrder = Enum.SortOrder.LayoutOrder }, Left)
		New("UIListLayout", { Padding = UDim.new(0, 14), SortOrder = Enum.SortOrder.LayoutOrder }, Right)

		if not isFirst then
			Left.Visible = false
			Right.Visible = false
		end

		local			function HideContent()
			Left.Visible = false
			Right.Visible = false
		end

		local function ShowContent()
			Left.Position = UDim2.new(0, 0, 0, 0)
			Right.Position = UDim2.new(0, 0, 0, 0)
			Left.Visible = true
			Right.Visible = true
			AnimateSectionColumn(Left)
			AnimateSectionColumn(Right)
			-- The new tab's content fades in while its columns rise.
			if WindowObj._fadeColumn then WindowObj._fadeColumn(Left); WindowObj._fadeColumn(Right) end
		end

		local function ActivateTab()
			CloseAllPopupsExcept(nil)
			for _, t in ipairs(tabs) do
				Tween(t.btn, {
					BackgroundColor3 = Color3.fromRGB(255, 255, 255),
					BackgroundTransparency = 1,
				}, 0.12, Enum.EasingStyle.Quad, Enum.EasingDirection.Out)
				if t.indicator then Tween(t.indicator, { BackgroundTransparency = 1 }, 0.12, Enum.EasingStyle.Quad, Enum.EasingDirection.Out) end
				t.hide()
				if t.btn ~= TabButtonFrame then
					TintTabIcon(t.icon, Color3.fromRGB(150, 155, 172), 0, 0.11, Enum.EasingStyle.Sine, Enum.EasingDirection.Out)
					t.txt.TextColor3 = Color3.fromRGB(150, 155, 172)
					Tween(t.txt, { TextTransparency = 0 }, 0.11, Enum.EasingStyle.Sine, Enum.EasingDirection.Out)
				end
			end
			Tween(TabButtonFrame, {
				BackgroundColor3 = Color3.fromRGB(35, 38, 50),
				BackgroundTransparency = 0.08,
			}, 0.13, Enum.EasingStyle.Quint, Enum.EasingDirection.Out)
			Tween(TabIndicator, { BackgroundTransparency = 1 }, 0.12, Enum.EasingStyle.Quint, Enum.EasingDirection.Out)
			TintTabIcon(TabIcon, mainColor, 0, 0.11, Enum.EasingStyle.Sine, Enum.EasingDirection.Out)
			TabText.TextColor3 = Color3.fromRGB(255, 255, 255)
			Tween(TabText, { TextTransparency = 0 }, 0.11, Enum.EasingStyle.Sine, Enum.EasingDirection.Out)
			TabScale.Scale = 0.985
			Tween(TabScale, { Scale = 1 }, 0.13, Enum.EasingStyle.Quint, Enum.EasingDirection.Out)
			activeTabIndex = tabIndex
			ShowContent()
			local tabState = tabs[tabIndex]
			GlobalPreset.Visible = ShouldShowGlobalPreset(name)
			if ApplySearch then task.defer(function() ApplySearch(SearchBox.Text) end) end
		end

		ClickArea.MouseButton1Click:Connect(ActivateTab)

		-- Hover feedback is limited to real navigation items. Transparent hit targets elsewhere stay inert.
		TabButtonFrame.MouseEnter:Connect(function()
			if activeTabIndex == tabIndex then return end
			-- Hover lights the plate only; the icon keeps its colour.
			Tween(TabButtonFrame, { BackgroundTransparency = 0.8 }, 0.11, Enum.EasingStyle.Sine)
		end)
		TabButtonFrame.MouseLeave:Connect(function()
			if activeTabIndex == tabIndex then return end
			Tween(TabButtonFrame, { BackgroundTransparency = 1 }, 0.14, Enum.EasingStyle.Sine)
		end)

		table.insert(tabs, {
			btn = TabButtonFrame,
			icon = TabIcon,
			indicator = TabIndicator,
			txt = TabText,
			hide = HideContent,
			show = ShowContent,
			tabIndex = tabIndex,
			name = name,
			activeSubTabIndex = nil,
			activate = ActivateTab,
		})

		if isFirst then
			activeTabIndex = 1
			GlobalPreset.Visible = ShouldShowGlobalPreset(name)
		end

		local TabObj = {}
		local sectionOrder = { left = 0, right = 0 }

		-- CS2-style loadout page for this tab (replaces its two columns): the
		-- team switch (CT / T Loadout) on top, your own character as the agent
		-- with six gear slots under it, and Pistols / Mid-Tier / Rifles columns
		-- of five weapon slots. Slots are see-through cards with the weapon
		-- name (no models). options.onSelect(team, category, index, name).
		-- Returns { frame, GetTeam(), SetTeam("CT" | "T") }.
		function TabObj:AddLoadout(options)
			options = type(options) == "table" and options or {}
			local WEAPONS = {
				CT = {
					Pistols = { "USP-S", "Dual Berettas", "P250", "Five-SeveN", "Desert Eagle" },
					["Mid-Tier"] = { "Nova", "XM1014", "MP9", "MP7", "P90" },
					Rifles = { "FAMAS", "M4A4", "SSG 08", "AUG", "AWP" },
				},
				T = {
					Pistols = { "Glock-18", "Dual Berettas", "P250", "Tec-9", "Desert Eagle" },
					["Mid-Tier"] = { "Nova", "Sawed-Off", "MAC-10", "MP7", "P90" },
					Rifles = { "Galil AR", "AK-47", "SSG 08", "SG 553", "AWP" },
				},
			}
			local CATEGORIES = { "Pistols", "Mid-Tier", "Rifles" }
			local GEAR = {
				{ "Agent", "rbxassetid://10747373176" }, { "Patch", "rbxassetid://10709769406" }, { "Music Kit", "rbxassetid://10734905958" },
				{ "Knife", "rbxassetid://10734975486" }, { "Gloves", "rbxassetid://10723405649" }, { "Zeus", "rbxassetid://10734951847" },
			}
			local TEAM_COLOR = { CT = Color3.fromRGB(110, 150, 255), T = Color3.fromRGB(230, 180, 90) }
			-- Team emblems: grey placeholder discs unless options.icons gives
			-- image ids ({ CT = "rbxassetid://...", T = "rbxassetid://..." }).
			local TEAM_ICON = type(options.icons) == "table" and options.icons or {}
			local CARD, MUTED, TEXT = Color3.fromRGB(23, 23, 31), Color3.fromRGB(150, 152, 162), Color3.fromRGB(235, 236, 241)
			local team = options.team == "T" and "T" or "CT"

			-- Full-width page: the left column takes the whole tab, the right one
			-- collapses.
			Left.Size = UDim2.new(1, -12, 1, 0)
			Right.Size = UDim2.new(0, 0, 1, 0)
			local page = New("Frame", { Name = "Loadout", Size = UDim2.new(1, 0, 0, 420), BackgroundTransparency = 1, LayoutOrder = 1 }, Left)
			local function fitHeight()
				local h = Left.AbsoluteSize.Y - 14
				if h > 100 then page.Size = UDim2.new(1, 0, 0, h) end
			end
			Left:GetPropertyChangedSignal("AbsoluteSize"):Connect(fitHeight)
			task.defer(fitHeight)

			-- Slot tile as on the Neverlose inventory: dark tile, faint outline,
			-- a grade bar along the bottom edge (neutral grey on templates).
			local function card(parent, name)
				local c = New("TextButton", {
					Name = name, BackgroundColor3 = Color3.fromRGB(16, 18, 25), BackgroundTransparency = 0.15, AutoButtonColor = false,
					Text = "", BorderSizePixel = 0,
				}, parent)
				New("UICorner", { CornerRadius = UDim.new(0, 6) }, c)
				Stroke(c).Transparency = 0.95
				local bar = New("Frame", {
					Name = "GradeBar", AnchorPoint = Vector2.new(0.5, 1), Position = UDim2.new(0.5, 0, 1, 0), Size = UDim2.new(1, -6, 0, 3),
					BackgroundColor3 = Color3.fromRGB(176, 180, 192), BackgroundTransparency = 0.25, BorderSizePixel = 0,
				}, c)
				New("UICorner", { CornerRadius = UDim.new(0, 2) }, bar)
				c.MouseEnter:Connect(function() Tween(c, { BackgroundColor3 = Color3.fromRGB(24, 27, 36) }, 0.1) end)
				c.MouseLeave:Connect(function() Tween(c, { BackgroundColor3 = Color3.fromRGB(16, 18, 25) }, 0.14) end)
				return c
			end

			-- Left side: team switch, agent, gear slots.
			local side = New("Frame", { Name = "AgentSide", Size = UDim2.new(0.32, 0, 1, 0), BackgroundTransparency = 1 }, page)
			-- Team switch as on CS2: CT on the left, T on the right, always. The
			-- open team's pill widens to show "X Loadout"; the other stays a
			-- round logo. Clicking the round one opens that team. 2px down so
			-- the outlines are not clipped by the column.
			local teamButtons = {}
			for index, which in ipairs({ "CT", "T" }) do
				-- 24px tall, centred on the 28px column headers (y 2..26).
				local b = New("TextButton", {
					Name = "Team_" .. which, Position = UDim2.fromOffset(0, 2), Size = UDim2.fromOffset(24, 24),
					BackgroundColor3 = Color3.fromRGB(32, 36, 50), BackgroundTransparency = 1, AutoButtonColor = false, Text = "", BorderSizePixel = 0,
					ClipsDescendants = true,
				}, side)
				New("UICorner", { CornerRadius = UDim.new(0, 6) }, b)
				local logo = New("Frame", {
					Name = "TeamLogo", AnchorPoint = Vector2.new(0, 0.5), Position = UDim2.new(0, 3, 0.5, 0), Size = UDim2.fromOffset(18, 18),
					BackgroundColor3 = Color3.fromRGB(92, 96, 110), BackgroundTransparency = 0.35, BorderSizePixel = 0,
				}, b)
				New("UICorner", { CornerRadius = UDim.new(1, 0) }, logo)
				if TEAM_ICON[which] then
					logo.BackgroundTransparency = 1
					New("ImageLabel", {
						Name = "TeamLogoIcon", Size = UDim2.fromScale(1, 1), BackgroundTransparency = 1, Image = TEAM_ICON[which],
						ScaleType = Enum.ScaleType.Fit,
					}, logo)
				end
				local title = New("TextLabel", {
					Name = "TeamTitle", Position = UDim2.fromOffset(26, 0), Size = UDim2.new(0, 90, 1, 0), BackgroundTransparency = 1,
					Text = which .. " Loadout", TextColor3 = TEAM_COLOR[which]:Lerp(Color3.new(1, 1, 1), 0.2), TextSize = 14, Font = FONT,
					TextXAlignment = Enum.TextXAlignment.Left, TextTransparency = 1,
				}, b)
				b.MouseEnter:Connect(function() if team ~= which then Tween(b, { BackgroundTransparency = 0.6 }, 0.1) end end)
				b.MouseLeave:Connect(function() if team ~= which then Tween(b, { BackgroundTransparency = 1 }, 0.14) end end)
				teamButtons[which] = { button = b, title = title, index = index }
			end
			-- The pair is centred over the agent (CT left, T right), as on Neverlose.
			local function layoutTeams(instant)
				local total = -8
				for _, which in ipairs({ "CT", "T" }) do
					total = total + (which == team and math.ceil(26 + MeasureText(which .. " Loadout", 14, FONT) + 10) or 24) + 8
				end
				local x = math.max(0, math.floor((side.AbsoluteSize.X - total) / 2))
				for _, which in ipairs({ "CT", "T" }) do
					local entry = teamButtons[which]
					local open = which == team
					local width = open and math.ceil(26 + MeasureText(which .. " Loadout", 14, FONT) + 10) or 24
					local size = UDim2.fromOffset(width, 24)
					local pos = UDim2.fromOffset(x, 2)
					local plate = open and 0 or 1
					if instant then
						entry.button.Size, entry.button.Position, entry.button.BackgroundTransparency = size, pos, plate
						entry.title.TextTransparency = open and 0 or 1
					else
						Tween(entry.button, { Size = size, Position = pos, BackgroundTransparency = plate }, 0.24, Enum.EasingStyle.Quint, Enum.EasingDirection.Out)
						Tween(entry.title, { TextTransparency = open and 0 or 1 }, 0.18)
					end
					x = x + width + 8
				end
			end
			layoutTeams(true)
			side:GetPropertyChangedSignal("AbsoluteSize"):Connect(function() layoutTeams(true) end)

			-- The agent stands free on the page (no plate behind it).
			local agent = New("Frame", { Name = "Agent", Position = UDim2.fromOffset(0, 38), BackgroundTransparency = 1, Active = true }, side)
			local viewport = New("ViewportFrame", {
				Name = "AgentView", Size = UDim2.fromScale(1, 1), BackgroundTransparency = 1,
				Ambient = Color3.fromRGB(150, 150, 165), LightColor = Color3.fromRGB(255, 255, 255), LightDirection = Vector3.new(-0.6, -1, -0.8),
			}, agent)
			local world = Instance.new("WorldModel")
			world.Parent = viewport
			local camera = Instance.new("Camera")
			camera.FieldOfView = 30
			camera.Parent = viewport
			viewport.CurrentCamera = camera

			local gear = New("Frame", { Name = "Gear", AnchorPoint = Vector2.new(0, 1), Position = UDim2.fromScale(0, 1), Size = UDim2.fromScale(1, 1), BackgroundTransparency = 1 }, side)
			New("UIAspectRatioConstraint", { AspectRatio = 1.5, DominantAxis = Enum.DominantAxis.Width }, gear)
			New("UIGridLayout", { CellSize = UDim2.new(1 / 3, -6, 0.5, -4), CellPadding = UDim2.fromOffset(8, 8), SortOrder = Enum.SortOrder.LayoutOrder }, gear)
			for i, item in ipairs(GEAR) do
				local slot = card(gear, "Gear_" .. item[1])
				slot.LayoutOrder = i
				slot.MouseButton1Click:Connect(function()
					if type(options.onSelect) == "function" then pcall(options.onSelect, team, "Gear", i, item[1]) end
				end)
			end
			-- Agent card fills the space between the switch and the gear slots.
			local function fitAgent()
				local gearH = gear.AbsoluteSize.Y
				if gearH > 0 then agent.Size = UDim2.new(1, 0, 1, -(38 + gearH + 8)) end
			end
			gear:GetPropertyChangedSignal("AbsoluteSize"):Connect(fitAgent)
			task.defer(fitAgent)

			-- Your character in the agent card: a clone of it, anchored, posed
			-- facing the camera; drag to turn it.
			local yaw, model = 0, nil
			local function pose()
				if not model then return end
				model:PivotTo(CFrame.Angles(0, math.pi + yaw, 0))
			end
			-- Fit the whole body with room around it: distance for the taller of
			-- height and (aspect-corrected) width, plus 25%; redone on resize.
			local function fitCamera()
				if not model then return end
				local cf, size = model:GetBoundingBox()
				local view = viewport.AbsoluteSize
				local aspect = (view.X > 0 and view.Y > 0) and view.X / view.Y or 0.75
				local span = math.max(size.Y, math.max(size.X, size.Z) / aspect)
				local distance = span / 2 / math.tan(math.rad(camera.FieldOfView / 2)) * 1.25
				camera.CFrame = CFrame.new(cf.Position + Vector3.new(0, 0, distance), cf.Position)
			end
			viewport:GetAttributeChangedSignal("Refit"):Connect(fitCamera)
			viewport:GetPropertyChangedSignal("AbsoluteSize"):Connect(fitCamera)
			local function loadAgent()
				world:ClearAllChildren()
				model = nil
				local char = LocalPlayer.Character
				if not char then return end
				local was = char.Archivable
				char.Archivable = true
				local ok, clone = pcall(function() return char:Clone() end)
				char.Archivable = was
				if not ok or not clone then return end
				for _, d in ipairs(clone:GetDescendants()) do
					if d:IsA("BaseScript") or d:IsA("ModuleScript") or d:IsA("Sound") then
						d:Destroy()
					elseif d:IsA("BasePart") then
						d.Anchored = true
						d.CanCollide = false
					end
				end
				local humanoid = clone:FindFirstChildOfClass("Humanoid")
				if humanoid then humanoid.DisplayDistanceType = Enum.HumanoidDisplayDistanceType.None end
				-- Idle pose: the clone carries the live animation frame (mid-step).
				-- Rebuild every part from the root through its joints at rest
				-- (Motor6D/Weld: C0 * C1^-1; WeldConstraint: the offset it had).
				do
					local root = clone:FindFirstChild("HumanoidRootPart") or clone.PrimaryPart
					local links = {}
					for _, j in ipairs(clone:GetDescendants()) do
						if (j:IsA("Motor6D") or j:IsA("Weld")) and j.Part0 and j.Part1 then
							table.insert(links, { a = j.Part0, b = j.Part1, rel = j.C0 * j.C1:Inverse() })
						elseif j:IsA("WeldConstraint") and j.Part0 and j.Part1 then
							table.insert(links, { a = j.Part0, b = j.Part1, rel = j.Part0.CFrame:ToObjectSpace(j.Part1.CFrame) })
						end
					end
					if root then
						local placed, progress = { [root] = true }, true
						while progress do
							progress = false
							for _, l in ipairs(links) do
								if placed[l.a] and not placed[l.b] then
									l.b.CFrame = l.a.CFrame * l.rel
									placed[l.b], progress = true, true
								elseif placed[l.b] and not placed[l.a] then
									l.a.CFrame = l.b.CFrame * l.rel:Inverse()
									placed[l.a], progress = true, true
								end
							end
						end
					end
				end
				clone.Parent = world
				model = clone
				pose()
				model:SetAttribute("Fit", true)
				viewport:SetAttribute("Refit", (viewport:GetAttribute("Refit") or 0) + 1)
			end
			loadAgent()
			LocalPlayer.CharacterAdded:Connect(function(char)
				char:WaitForChild("HumanoidRootPart", 10)
				task.wait(0.5)
				loadAgent()
			end)
			do
				local turning
				agent.InputBegan:Connect(function(input)
					if input.UserInputType == Enum.UserInputType.MouseButton1 or input.UserInputType == Enum.UserInputType.Touch then
						turning = { x = input.Position.X, yaw = yaw }
					end
				end)
				UserInputService.InputChanged:Connect(function(input)
					if not turning or input.UserInputType ~= Enum.UserInputType.MouseMovement and input.UserInputType ~= Enum.UserInputType.Touch then return end
					yaw = turning.yaw + (input.Position.X - turning.x) * 0.012
					pose()
				end)
				UserInputService.InputEnded:Connect(function(input)
					if input.UserInputType == Enum.UserInputType.MouseButton1 or input.UserInputType == Enum.UserInputType.Touch then turning = nil end
				end)
			end

			-- Right side: three columns of weapon slots.
			local grid = New("Frame", { Name = "Weapons", Position = UDim2.new(0.32, 12, 0, 0), Size = UDim2.new(0.68, -12, 1, 0), BackgroundTransparency = 1 }, page)
			for i, category in ipairs(CATEGORIES) do
				New("TextLabel", {
					Name = "Header_" .. category, Position = UDim2.new((i - 1) / 3, 0, 0, 0), Size = UDim2.new(1 / 3, -8, 0, 28),
					BackgroundTransparency = 1, Text = category, TextColor3 = TEXT, TextSize = 14, Font = FONT,
				}, grid)
			end
			local slots = New("Frame", { Name = "Slots", Position = UDim2.fromOffset(0, 36), Size = UDim2.new(1, 0, 1, -36), BackgroundTransparency = 1 }, grid)
			New("UIGridLayout", {
				CellSize = UDim2.new(1 / 3, -8, 0.2, -8), CellPadding = UDim2.fromOffset(8, 8),
				FillDirection = Enum.FillDirection.Vertical, FillDirectionMaxCells = 5, SortOrder = Enum.SortOrder.LayoutOrder,
			}, slots)
			for c, category in ipairs(CATEGORIES) do
				for i = 1, 5 do
					local slot = card(slots, category .. "_" .. i)
					slot.LayoutOrder = (c - 1) * 5 + i
					-- Light rule under each slot, as on the CS2 loadout.
					-- Blank template: the weapon is known (onSelect gets its name) but
					-- not written on the card.
					slot.MouseButton1Click:Connect(function()
						if type(options.onSelect) == "function" then
							pcall(options.onSelect, team, category, i, WEAPONS[team][category][i])
						end
					end)
				end
			end

			local api = { frame = page }
			function api:GetTeam() return team end
			function api:SetTeam(newTeam)
				team = newTeam == "T" and "T" or "CT"
				layoutTeams(false)
				if type(options.onTeam) == "function" then pcall(options.onTeam, team) end
				return self
			end
			for which, entry in pairs(teamButtons) do
				entry.button.MouseButton1Click:Connect(function() if team ~= which then api:SetTeam(which) end end)
			end
			return api
		end

		-- Players-style preview in this tab's right column (see _buildESPPreview).
		function TabObj:AddESPPreview(options)
			return WindowObj._buildESPPreview(Left, Right, options)
		end

		function TabObj:AddSection(title, side)
			title = tostring(title or "Section")
			side = side == "right" and "right" or "left"
			sectionOrder[side] = sectionOrder[side] + 1
			local col = side == "right" and Right or Left

			local Section = New("Frame", {
				Name = "Section",
				Size = UDim2.new(1, 0, 0, 0),
				BackgroundColor3 = Color3.fromRGB(162, 162, 162),
				BackgroundTransparency = 1,
				AutomaticSize = Enum.AutomaticSize.Y,
				LayoutOrder = sectionOrder[side],
			}, col)
			-- Read by the hotkey list to name generic functions ("Enabled").
			Section:SetAttribute("NLTabName", tostring(name))
			Section:SetAttribute("NLSectionName", title)
			New("UIListLayout", { Padding = UDim.new(0, 2), SortOrder = Enum.SortOrder.LayoutOrder }, Section)

local SectionTitle = Instance.new('Frame')
SectionTitle.Name = "SectionTitle"
SectionTitle.Size = UDim2.new(1, 0, 0, 22)
SectionTitle.BackgroundTransparency = 1
SectionTitle.ClipsDescendants = false
SectionTitle.Visible = true
SectionTitle.Parent = Section

local SectionLabel = Instance.new('TextLabel')
SectionLabel.Name = "SectionLabel"
SectionLabel.Position = UDim2.new(0,0,0,0)
SectionLabel.Size = UDim2.new(1,0,1,0)
SectionLabel.Visible = true
SectionLabel.ClipsDescendants = false
SectionLabel.BackgroundColor3 = Color3.fromRGB(162,162,162)
SectionLabel.BackgroundTransparency = 1
SectionLabel.BorderSizePixel = 0
SectionLabel.Text = tostring(title or "Section"):upper()
SectionLabel.TextColor3 = customization.sectionTitleColor or Color3.fromRGB(112, 116, 138)
SectionLabel.TextScaled = false
SectionLabel.TextSize = customization.sectionTitleSize or 11
SectionLabel.Font = FONT
SectionLabel.TextTransparency = customization.sectionTitleTransparency or 0.15
SectionLabel.TextXAlignment = Enum.TextXAlignment.Left
SectionLabel.TextYAlignment = Enum.TextYAlignment.Center
SectionLabel.Parent = SectionTitle
do
	local pad = Instance.new("UIPadding")
	pad.PaddingLeft = UDim.new(0, 13)
	pad.PaddingRight = UDim.new(0, 4)
	pad.Parent = SectionLabel
end
AddTextConstraint(SectionLabel, 10, 14, true)
do
	local limit = SectionLabel:FindFirstChild("ReadableTextConstraint")
	if not limit then
		limit = Instance.new("UITextSizeConstraint")
		limit.Name = "ReadableTextConstraint"
		limit.Parent = SectionLabel
	end
	limit.MinTextSize = 10
	limit.MaxTextSize = 14
end


			local Elements = New("Frame", {
				Name = "Elements",
				Size = UDim2.new(1, 0, 0, 0),
				Position = UDim2.new(0, 0, 0, 0),
				BackgroundColor3 = Color3.fromRGB(23, 23, 31),
				BackgroundTransparency = 0.1, -- Neverlose card: neutral (~21,21,28 on the panel), slightly see-through
				BorderSizePixel = 0,
				AutomaticSize = Enum.AutomaticSize.Y,
				LayoutOrder = 1,
				ClipsDescendants = false,
			}, Section)
			do local c = Instance.new("UICorner"); c.CornerRadius = UDim.new(0, 14); c.Parent = Elements end
			Elements:SetAttribute("NLGroupOutlineInset", true)
			do local groupStroke = Stroke(Elements, "GroupOutline"); groupStroke:SetAttribute("NLBaseTransparency", 0.92) end
			-- Inset rows slightly from the card edges. This keeps each side of the
			-- rounded outline visible even when a row uses an opaque background.
			New("UIPadding", {
				PaddingLeft = UDim.new(0, 1),
				PaddingRight = UDim.new(0, 1),
				PaddingTop = UDim.new(0, 0),
				PaddingBottom = UDim.new(0, 0),
			}, Elements)
			New("UIListLayout", {
				Padding = UDim.new(0, 0),
				SortOrder = Enum.SortOrder.LayoutOrder,
			}, Elements)
			WatchRowDividers(Elements)

			local SectionObj = {}
			SectionObj.frame = Section -- lets a preview show/hide whole sections
			local elemCount = 0
			local _openDropdown = nil
			local _openAccordion = nil
			local _openAccordionDropdown = nil
			local settingsCache = {}
			local BindElementContext

			local function MakeSettings(parentFrame, elementType, label)
				if settingsCache[parentFrame] then return settingsCache[parentFrame] end
				label = tostring(label or "")
				local settingsOpen = false
				local settingsLayoutConnection = nil

				local hasLeftControl = elementType == "slider" or elementType == "dropdown" or parentFrame.Name == "Selection"
				local SettingsBtn = New("Frame", {
					Name = "SettingsGear",
					AnchorPoint = Vector2.new(0.5, 0.5),
					Position = hasLeftControl and UDim2.new(0, 132, 0.5, 0) or UDim2.new(1, -65, 0.5, 0),
					Size = UDim2.fromOffset(20, 20),
					BackgroundColor3 = Color3.fromRGB(162, 162, 162),
					BackgroundTransparency = 1,
					ZIndex = 2000,
				}, parentFrame)

				for i = 0, 2 do
					New("Frame", {
						Name = "Dot" .. tostring(i + 1),
						AnchorPoint = Vector2.new(0.5, 0.5),
						Position = UDim2.new(0.5, (i - 1) * 5, 0.5, 0),
						Size = UDim2.new(0, 3, 0, 3),
						BackgroundColor3 = Color3.fromRGB(255, 255, 255),
						BackgroundTransparency = 1,
						BorderSizePixel = 0,
						ZIndex = 2001,
					}, SettingsBtn)
				end

				local SettingsHit = New("TextButton", {
					Name = "SettingsHit",
					Size = UDim2.new(1, 0, 1, 0),
					BackgroundTransparency = 1,
					Text = "",
					AutoButtonColor = false,
					ZIndex = 2002,
				}, SettingsBtn)
				for _, dot in ipairs(SettingsBtn:GetChildren()) do
					if dot:IsA("GuiObject") and string.sub(dot.Name, 1, 3) == "Dot" then
						dot.BackgroundTransparency = 1
					end
				end
				local function SetDotsTransparency(value)
					for _, dot in ipairs(SettingsBtn:GetChildren()) do
						if dot:IsA("GuiObject") and string.sub(dot.Name, 1, 3) == "Dot" then
							Tween(dot, { BackgroundTransparency = value }, 0.15)
						end
					end
				end
				SettingsHit.MouseEnter:Connect(function() SetDotsTransparency(0) end)
				SettingsHit.MouseLeave:Connect(function() SetDotsTransparency(0.1) end)
				SetDotsTransparency(0.1)

				local SettingsFrame = Instance.new('Frame')
				SettingsFrame.Name = "SettingsFrame"
				SettingsFrame.Position = UDim2.new(0.02, 0, 1, 4)
				SettingsFrame.Size = UDim2.new(0.96, 0, 0, 0)
				SettingsFrame.BackgroundColor3 = Color3.fromRGB(18, 18, 25) -- Neverlose plate
				SettingsFrame.BackgroundTransparency = 0.045
				SettingsFrame.BorderSizePixel = 0
				SettingsFrame.Visible = false
				SettingsFrame.ZIndex = 5000
				SettingsFrame.AutomaticSize = Enum.AutomaticSize.None
				SettingsFrame.ClipsDescendants = false
				local SFScale = New("UIScale", { Scale = 1 }, SettingsFrame)

				SettingsFrame.Parent = parentFrame

				local UICorner = Instance.new('UICorner')
				UICorner.Name = "UICorner"
				UICorner.CornerRadius = UDim.new(0, THEME.radius)
				UICorner.Parent = SettingsFrame

				local UIStroke = Stroke(SettingsFrame, "UIStroke")
				-- Solid plate with a soft shadow, like the option lists.
				AttachShadow(SettingsFrame, { radius = 12, layers = 5, step = 1.6, bias = 3 })

				-- PATCH 4: settings plate header + no divider watcher
				-- Neverlose plate title: regular weight, light grey, larger than rows.
				local PLATE_HEADER = 40
				New("TextLabel", {
					Name = "PlateTitle",
					Position = UDim2.new(0, 16, 0, 13),
					Size = UDim2.new(1, -32, 0, 20),
					BackgroundTransparency = 1,
					Text = label,
					TextColor3 = Color3.fromRGB(226, 227, 233),
					TextSize = 16,
					TextXAlignment = Enum.TextXAlignment.Left,
					TextTruncate = Enum.TextTruncate.AtEnd,
					ZIndex = 5001,
				}, SettingsFrame)

				local SFContainer = Instance.new('ScrollingFrame')
				SFContainer.Name = "Container"
				SFContainer.AnchorPoint = Vector2.new(0, 0)
				SFContainer.Position = UDim2.new(0.04, 0, 0, PLATE_HEADER + 3 / GetMainFrameScale())
				SFContainer.Size = UDim2.new(0.92, 0, 1, -(PLATE_HEADER + 10 / GetMainFrameScale()))
				-- Neverlose plates group their rows on an inner card, without dividers.
				SFContainer.BackgroundColor3 = Color3.fromRGB(27, 27, 36)
				-- The inner card is the plate colour with only a hairline border.
				SFContainer.BackgroundTransparency = 1
				SFContainer.LayoutOrder = 1
				SFContainer.ZIndex = 5001
				SFContainer.Active = true
				SFContainer.AutomaticCanvasSize = Enum.AutomaticSize.Y
				SFContainer.CanvasSize = UDim2.new()
				SFContainer.ScrollingEnabled = false
				SFContainer.ScrollingDirection = Enum.ScrollingDirection.Y
				SFContainer.ScrollBarThickness = 0
				SFContainer.ScrollBarImageTransparency = 1
				SFContainer.ClipsDescendants = false
				SFContainer.Parent = SettingsFrame

				local SFLayout = Instance.new('UIListLayout')
				SFLayout.Name = "UIListLayout"
				SFLayout.Padding = UDim.new(0, 0)
				SFLayout.SortOrder = Enum.SortOrder.LayoutOrder
				SFLayout.Parent = SFContainer

				SFContainer.DescendantAdded:Connect(function(d)
					if d.Name == "Lines" and d:IsA("GuiObject") then d.Visible = false end
				end)
				for _, d in ipairs(SFContainer:GetDescendants()) do
					if d.Name == "Lines" and d:IsA("GuiObject") then d.Visible = false end
				end

				do local c = Instance.new("UICorner"); c.CornerRadius = UDim.new(0, 10); c.Parent = SFContainer end
				Stroke(SFContainer, "CardOutline").Transparency = 0.955
				New("UIPadding", { PaddingTop = UDim.new(0, 4), PaddingBottom = UDim.new(0, 4), PaddingLeft = UDim.new(0, 6), PaddingRight = UDim.new(0, 6) }, SFContainer)

				local function UpdateSettingsLayout()
					local scale = GetMainFrameScale()
					SFContainer.Position = UDim2.new(0.04, 0, 0, PLATE_HEADER + 3 / scale)
					SFContainer.Size = UDim2.new(0.92, 0, 1, -(PLATE_HEADER + 10 / scale))
				end

				local function GetSettingsContentHeight()
					local measured = MeasureRowsHeight(SFContainer)
					if measured > 0 then return measured end
					local rowCount = 0
					for _, child in ipairs(SFContainer:GetChildren()) do
						if child:IsA("GuiObject") then rowCount = rowCount + 1 end
					end
					if rowCount <= 0 then return 0 end
					local estimated = EstimateRowsHeight(SFContainer, rowCount, 8.5)
					if estimated > 0 then return estimated end
					return rowCount * 34 * GetMainFrameScale()
				end

				local function getSettingsHeight()
					UpdateSettingsLayout()
					local scale = GetMainFrameScale()
					local contentVisual = GetSettingsContentHeight()
					local desiredVisual = math.max(34 * scale, contentVisual + (18 + PLATE_HEADER) * scale)
					return desiredVisual / scale
				end

				local function placeSettings(height)
					local scale = GetMainFrameScale()
					UpdateSettingsLayout()
					-- Bounded by the screen, not the window: plates may hang outside the menu.
					local mainPosition, mainSize = PopupSafeArea()
					local minHeight = 30
					local width = 280
					local edge = 5 * scale
					height = math.max(minHeight, type(height) == "number" and height == height and height or minHeight)
					local parentPosition = parentFrame.AbsolutePosition
					local parentSize = parentFrame.AbsoluteSize
					if mainSize.X <= 0 or mainSize.Y <= 0 or parentSize.X <= 0 or parentSize.Y <= 0 then return end
					local visualHeight = height * scale

					local mainLeft = mainPosition.X
					local mainRight = mainPosition.X + mainSize.X
					local mainTop = mainPosition.Y
					local mainBottom = mainPosition.Y + mainSize.Y

					local panelWidth = width * scale
					local leftX = SettingsBtn.AbsolutePosition.X + SettingsBtn.AbsoluteSize.X + 8 * scale
					leftX = math.clamp(leftX, mainLeft + edge, math.max(mainLeft + edge, mainRight - panelWidth - edge))

					-- Neverlose: the plate opens just right of the dots, its top a little
					-- above the row, and is pushed up only if it would leave the window.
					local y = parentPosition.Y - 6 * scale
					y = math.clamp(y, mainTop + edge, math.max(mainTop + edge, mainBottom - visualHeight - edge))

					SettingsFrame.Position = UDim2.new(0, (leftX - parentPosition.X) / scale, 0, (y - parentPosition.Y) / scale)
					SettingsFrame.Size = UDim2.fromOffset(width, height)
					task.defer(function()
						if SettingsFrame.Parent and SettingsFrame.Visible and visualHeight <= mainSize.Y then
							ConstrainPopupToMainFrame(SettingsFrame)
						end
					end)
				end

				local function closeSF()
					settingsOpen = false
					ClosePopupsUnder(SettingsFrame)
					UnregisterPopup(SettingsFrame)
					-- Fade out in place; shrinking the height used to cut the plate off.
					SmoothClose(SettingsFrame, 0.13)
					Tween(SFScale, {Scale = 0.94}, 0.13, Enum.EasingStyle.Quad, Enum.EasingDirection.In)
					Tween(SettingsBtn, { BackgroundTransparency = 1 }, 0.12)
				end
				local SettingsObj = {}
				SettingsHit.MouseButton1Click:Connect(function()
					if settingsOpen then closeSF() else SettingsObj:Open() end
				end)

				local settingsElemCount = 0
				local SettingsFrame_Container = SFContainer

				-- Starts a new card in the plate; following Add* calls land in it.
				function SettingsObj:AddGroup()
					SettingsFrame_Container = StartPlateGroup(SFContainer)
					return self
				end

				function SettingsObj:Open()
					if settingsOpen then return self end
					settingsOpen = true
					CloseAllPopupsExcept(SettingsFrame)
					RememberPopupClipping(SettingsFrame)
					ForceLiftClipping(SettingsFrame)
					SettingsFrame.Visible = false
					SFScale.Scale = 0.9
					ApplyZIndexLadder(SettingsFrame, NextPopupZ())
					placeSettings(getSettingsHeight())
					SmoothOpen(SettingsFrame, 0, 0.18)
					-- Pops out of the dots (UIScale grows from the plate's top-left).
					Tween(SFScale, {Scale = 1}, 0.26, Enum.EasingStyle.Back, Enum.EasingDirection.Out)
					-- The dots stay highlighted while their plate is open, as in Neverlose.
					if not SettingsBtn:FindFirstChildOfClass("UICorner") then New("UICorner", { CornerRadius = UDim.new(0, 5) }, SettingsBtn) end
					SettingsBtn.BackgroundColor3 = Color3.fromRGB(255, 255, 255)
					Tween(SettingsBtn, { BackgroundTransparency = 0.9 }, 0.12)
					RegisterPopup(SettingsFrame, closeSF, SettingsBtn)
					local function settle()
						if not settingsOpen or not SettingsFrame.Parent then return end
						placeSettings(getSettingsHeight())
					end
					task.defer(settle)
					task.delay(0.05, settle)
					-- Guarantee the solid end state even if another tween touched it.
					task.delay(0.25, function() if settingsOpen then SettingsFrame.BackgroundTransparency = 0 end end)
					if not settingsLayoutConnection then
						local okLayout, layout = pcall(function() return SFContainer:FindFirstChildOfClass("UIListLayout") end)
						if okLayout and layout then
							pcall(function()
								settingsLayoutConnection = layout:GetPropertyChangedSignal("AbsoluteContentSize"):Connect(function()
									if settingsOpen then task.defer(function() if settingsOpen then placeSettings(getSettingsHeight()) end end) end
								end)
							end)
						end
					end
					return self
				end

				function SettingsObj:Close()
					if settingsOpen then closeSF() end
					return self
				end

				function SettingsObj:AddToggle(text, default, callback)
					settingsElemCount = settingsElemCount + 1
					local enabled = default == true

					local Toggle = New("Frame", {
						Name = "Toggle",
						Size = UDim2.new(1, 0, 0, 34),
						BackgroundColor3 = Color3.fromRGB(162, 162, 162),
						BackgroundTransparency = 1,
						LayoutOrder = settingsElemCount,
					}, SettingsFrame_Container)

New("Frame", {
						Name = "Lines",
						Position = UDim2.new(0.06, 0, 1, -1),
						Size = UDim2.new(0.88, 0, 0, 1),
						BackgroundColor3 = Color3.fromRGB(162, 162, 162),
						BackgroundTransparency = 0.9,
						ZIndex = 1000,
						BorderSizePixel = 0,
					}, Toggle)

					New("TextLabel", {
						Name = "TextToggle",
						Position = UDim2.new(0.04800000086426735, 0, 0.30000001192092896, 0),
						Size = UDim2.new(0.7600000262260437, 0, 0.6000000238418579, 0),
						BackgroundColor3 = Color3.fromRGB(28,32,48),
						BackgroundTransparency = 1,
						Text = text,
						TextColor3 = Color3.fromRGB(255, 255, 255),
						TextScaled = false,
						Font = FONT,
						TextTransparency = 0.10000000149011612,
						TextXAlignment = Enum.TextXAlignment.Left,
						ZIndex = 1001,
					}, Toggle)

					local Effect = New("Frame", {
						Name = "Effect",
						Position = UDim2.new(1, -14, 0.5, 0),
						AnchorPoint = Vector2.new(1, 0.5),
						Size = UDim2.fromOffset(33, 20),
						BackgroundColor3 = enabled and mainColor or Color3.fromRGB(8, 10, 16),
						ZIndex = 1001,
					}, Toggle)
					New("UICorner", { CornerRadius = UDim.new(1, 0) }, Effect)

					local Icon = New("Frame", {
						Name = "Icon",
						Position = enabled and UDim2.fromOffset(15, 2) or UDim2.fromOffset(2, 2),
						Size = UDim2.fromOffset(16, 16),
						BackgroundColor3 = enabled and Color3.fromRGB(255, 255, 255) or Color3.fromRGB(139, 145, 157),
						BackgroundTransparency = 0,
						ZIndex = 1002,
					}, Effect)
					New("UICorner", { CornerRadius = UDim.new(1, 0) }, Icon)
					New("UIAspectRatioConstraint", {}, Icon)

					local Btn = New("TextButton", {
						Size = UDim2.new(1, 0, 1, 0),
						BackgroundTransparency = 1,
						Text = "",
						ZIndex = 1010,
					}, Toggle)


					local function Set(val)
						enabled = val == true
						Tween(Effect, { BackgroundColor3 = enabled and mainColor or Color3.fromRGB(8, 10, 16) }, 0.16, Enum.EasingStyle.Sine)
						Tween(Icon, { Position = enabled and UDim2.fromOffset(15, 2) or UDim2.fromOffset(2, 2), BackgroundColor3 = enabled and Color3.fromRGB(255, 255, 255) or Color3.fromRGB(139, 145, 157), BackgroundTransparency = 0 }, 0.16, Enum.EasingStyle.Quad)
						InvokeCallback(callback, enabled)
					end

					Btn.MouseButton1Click:Connect(function() Set(not enabled) end)

					local obj = {}
					function obj:Set(v) Set(v) end
					function obj:Get() return enabled end
					RegisterConfigElement("settings_toggle_", text, obj)
					return obj
				end

				function SettingsObj:AddCheckbox(text, default, callback)
					settingsElemCount = settingsElemCount + 1
					local enabled = default == true

					local CheckBoxToggle = New("Frame", {
						Name = "CheckBoxToggle",
						Size = UDim2.new(1, 0, 0, 34),
						BackgroundColor3 = Color3.fromRGB(162, 162, 162),
						BackgroundTransparency = 1,
						LayoutOrder = settingsElemCount,
					}, SettingsFrame_Container)
					local CheckBox = New("Frame", {
						Name = "CheckBox",
						Position = UDim2.new(0.04, 0, 0.3, 0),
						Size = UDim2.new(0.075, 0, 0.7, 0),
						BackgroundTransparency = 1,
						ZIndex = 1001,
					}, CheckBoxToggle)
					New("UICorner", {}, CheckBox)
					New("UIAspectRatioConstraint", {}, CheckBox)

					local Check = New("ImageLabel", {
						Name = "Check",
						Size = UDim2.new(1, 0, 1, 0),
						BackgroundTransparency = 1,
						Image = "rbxassetid://138494545053627",
						ImageTransparency = enabled and 0.1 or 1,
						ZIndex = 1001,
					}, CheckBox)

					New("TextLabel", {
						Name = "TextToggle",
						Position = UDim2.new(0.15, 0, 0.30000001192092896, 0),
						Size = UDim2.new(0.7600000262260437, 0, 0.6000000238418579, 0),
						BackgroundColor3 = Color3.fromRGB(28,32,48),
						BackgroundTransparency = 1,
						Text = text,
						TextColor3 = Color3.fromRGB(255, 255, 255),
						TextScaled = false,
						Font = FONT,
						TextTransparency = 0.10000000149011612,
						TextXAlignment = Enum.TextXAlignment.Left,
						ZIndex = 1001,
					}, CheckBoxToggle)

					local Btn = New("TextButton", {
						Size = UDim2.new(1, 0, 1, 0),
						BackgroundTransparency = 1,
						Text = "",
						ZIndex = 1010,
					}, CheckBoxToggle)


					local function Set(val)
						enabled = val == true
						Tween(Check, { ImageTransparency = enabled and 0.1 or 1 }, 0.2)
						InvokeCallback(callback, enabled)
					end

					Btn.MouseButton1Click:Connect(function() Set(not enabled) end)

					local obj = {}
					function obj:Set(v) Set(v) end
					function obj:Get() return enabled end
					RegisterConfigElement("settings_checkbox_", text, obj)
					return obj
				end

				function SettingsObj:AddSlider(text, min, max, default, callback, suffix)
					settingsElemCount = settingsElemCount + 1
					if type(suffix) ~= "string" then suffix = "" end
					local value
					min, max, value = NormalizeRange(min, max, default)
					value = Quantize(value, min, max, GetSliderStep(min, max))
					local initRatio = (value - min) / (max - min)
					local dragging = false

					local Slider = New("Frame", {
						Name = "Slider",
						Size = UDim2.new(1, 0, 0, 34),
						BackgroundColor3 = Color3.fromRGB(162, 162, 162),
						BackgroundTransparency = 1,
						LayoutOrder = settingsElemCount,
						ZIndex = 1000,
					}, SettingsFrame_Container)

New("Frame", {
						Name = "Lines",
						Position = UDim2.new(0.06, 0, 1, -1),
						Size = UDim2.new(0.88, 0, 0, 1),
						BackgroundColor3 = Color3.fromRGB(162, 162, 162),
						BackgroundTransparency = 0.9,
						ZIndex = 1002,
						BorderSizePixel = 0,
					}, Slider)

					New("TextLabel", {
						Name = "TextToggle",
						Position = UDim2.new(0.04800000086426735, 0, 0.30000001192092896, 0),
						Size = UDim2.new(0.36, 0, 0.6000000238418579, 0),
						BackgroundColor3 = Color3.fromRGB(28,32,48),
						BackgroundTransparency = 1,
						Text = text,
						TextColor3 = Color3.fromRGB(255, 255, 255),
						TextScaled = false,
						Font = FONT,
						TextTransparency = 0,
						TextXAlignment = Enum.TextXAlignment.Left,
						TextTruncate = Enum.TextTruncate.AtEnd,
						ZIndex = 1001,
					}, Slider)

					local Effect = New("Frame", {
						Name = "Effect",
						Position = UDim2.new(0.4980000042915344, 0, 0.25, 0),
						Size = UDim2.new(0.5, 0, 0.6990000009536743, 0),
						BackgroundColor3 = Color3.fromRGB(255, 255, 255),
						BackgroundTransparency = 1,
						ZIndex = 1001,
					}, Slider)

					local SliderValue = New("TextLabel", {
						Name = "SliderValue",
						Position = UDim2.new(0.6990000009536743, 0, 0.10000000149011612, 0),
						Size = UDim2.new(0.25, 0, 0.8080000281333923, 0),
						BackgroundColor3 = Color3.fromRGB(33,37,53),
						Text = FormatSliderValue(value, suffix),
						TextColor3 = Color3.fromRGB(255, 255, 255),
						TextScaled = false,
						Font = FONT,
						TextTransparency = 0.20000000298023224,
						ZIndex = 1002,
					}, Effect)
					New("UICorner", { CornerRadius = UDim.new(0, 5) }, SliderValue)

					local Line = New("Frame", {
						Name = "Line",
						Active = true,
						Position = UDim2.new(0.03999999910593033, 0, 0.3190000057220459, 0),
						Size = UDim2.new(0.6000000238418579, 0, 0.24, 0),
						BackgroundColor3 = Color3.fromRGB(33,37,53),
						ZIndex = 1001,
					}, Effect)
					New("UICorner", { CornerRadius = UDim.new(1, 0) }, Line)

					local InLine = New("Frame", {
						Name = "InLine",
						Size = UDim2.new(0, 0, 1, 0),
						BackgroundColor3 = mainColor,
						ZIndex = 1002,
					}, Line)
					New("UICorner", { CornerRadius = UDim.new(1, 0) }, InLine)
					SizeSliderChip(Effect, Line, SliderValue)
					Effect.AnchorPoint = Vector2.new(0, 0.5)
					Effect.Position = UDim2.new(0.45, 0, 0.5, 0)
					Effect.Size = UDim2.new(0.55, -14, 0, 22)
					Line.Size = UDim2.new(1, -(SliderValue.Size.X.Offset + 10), 0, 3)
					Line.Position = UDim2.new(0, 0, 0.5, 0)

					local Trigger = New("TextButton", {
						Name = "Trigger",
						Position = UDim2.new(0.10000000149011612, 0, -1.8000000715255737, 0),
						Size = UDim2.new(1.1999999284744263, 0, 4.200000286102295, 0),
						AnchorPoint = Vector2.new(0.800000011920929, 0),
						BackgroundColor3 = Color3.fromRGB(255, 255, 255),
						BackgroundTransparency = 1,
						Active = false,
						Text = "",
						ZIndex = 1003,
					}, Line)
					New("UICorner", { CornerRadius = UDim.new(1, 0) }, Trigger)
					New("UIAspectRatioConstraint", {}, Trigger)
					local Thumb = New("Frame", {
						Name = "Thumb",
						AnchorPoint = Vector2.new(0.5, 0.5),
						Position = UDim2.new(initRatio, 0, 0.5, 0),
						Size = UDim2.fromOffset(12, 12),
						BackgroundColor3 = Color3.fromRGB(248, 250, 255),
						BorderSizePixel = 0,
						ZIndex = Line.ZIndex + 3,
					}, Line)
					New("UICorner", { CornerRadius = UDim.new(1, 0) }, Thumb)
					Stroke(Thumb)
					Line.MouseEnter:Connect(function()
						Tween(Thumb, { Size = UDim2.fromOffset(14, 14) }, 0.11, Enum.EasingStyle.Sine, Enum.EasingDirection.Out)
					end)
					Line.MouseLeave:Connect(function()
						Tween(Thumb, { Size = UDim2.fromOffset(12, 12) }, 0.13, Enum.EasingStyle.Sine, Enum.EasingDirection.Out)
					end)
					local initialValue = value
					task.defer(function()
						if value ~= initialValue then return end
						InLine.Size = UDim2.fromScale(initRatio, 1)
						Thumb.Position = UDim2.new(initRatio, 0, 0.5, 0)
						Trigger.Position = UDim2.new(initRatio, 0, -1.8000000715255737, 0)
					end)

					local function update(input)
						local pointer = GetInputPosition(input)
						local lineSize = Line.AbsoluteSize.X
						if lineSize <= 0 then return end
						local sizeScale = ClampRatio(pointer.X - Line.AbsolutePosition.X, lineSize)
						local nextValue = Quantize(((max - min) * sizeScale) + min, min, max, GetSliderStep(min, max))
						local changed = nextValue ~= value
						value = nextValue
						local span = max - min
						local snappedRatio = span ~= 0 and math.clamp((value - min) / span, 0, 1) or 0
						InLine.Size = UDim2.fromScale(snappedRatio, 1)
						Trigger.Position = UDim2.new(snappedRatio, 0, -1.8000000715255737, 0)
						Thumb.Position = UDim2.new(snappedRatio, 0, 0.5, 0)
						SliderValue.Text = FormatSliderValue(value, suffix)
						if changed then InvokeCallback(callback, value) end
					end

					Line.InputBegan:Connect(function(input)
						if IsPrimaryInput(input) then
							dragging = true; update(input)
						end
					end)
					UserInputService.InputEnded:Connect(function(input)
						if IsPrimaryInput(input) then
							dragging = false
						end
					end)
					UserInputService.InputChanged:Connect(function(input)
						if dragging and (input.UserInputType == Enum.UserInputType.MouseMovement or input.UserInputType == Enum.UserInputType.Touch) then
							update(input)
						end
					end)

					local obj = {}
					function obj:Set(val)
						local numeric = type(val) == "number" and val == val and val or min
						value = math.clamp(numeric, min, max)
						value = Quantize(value, min, max, GetSliderStep(min, max))
					local span = max - min
					local ratio = span ~= 0 and math.clamp((value - min) / span, 0, 1) or 0
						Tween(InLine, { Size = UDim2.fromScale(ratio, 1) }, 0.14, Enum.EasingStyle.Sine, Enum.EasingDirection.Out)
						Trigger.Position = UDim2.new(ratio, 0, -1.8000000715255737, 0)
						Tween(Thumb, { Position = UDim2.new(ratio, 0, 0.5, 0) }, 0.14, Enum.EasingStyle.Sine, Enum.EasingDirection.Out)
						SliderValue.Text = FormatSliderValue(value, suffix)
						InvokeCallback(callback, value)
					end
					function obj:Get() return value end
					RegisterConfigElement("settings_slider_", text, obj)
					return obj
				end

				function SettingsObj:AddDropdown(text, options, default, callback)
					if type(default) == "function" then callback = default; default = nil end
					options = NormalizeOptions(options)
					settingsElemCount = settingsElemCount + 1
					local selected = GetValidOption(options, default)
					local dropOpen = false
					local selectedBtns = {}

					local Selection = New("Frame", {
						Name = "Selection",
						Size = UDim2.new(1, 0, 0, 34),
						BackgroundColor3 = Color3.fromRGB(162, 162, 162),
						BackgroundTransparency = 1,
						LayoutOrder = settingsElemCount,
						ClipsDescendants = false,
						ZIndex = 1000,
					}, SettingsFrame_Container)
					New("Frame", {
						Name = "Lines",
						Position = UDim2.new(0.05000000074505806, 0, 1, 0),
						Size = UDim2.new(0.8999999761581421, 0, 0, 1),
						BackgroundColor3 = Color3.fromRGB(162, 162, 162),
						BackgroundTransparency = 0.9,
						BorderSizePixel = 0,
						ZIndex = 1000,
					}, Selection)

					New("TextLabel", {
						Name = "TextToggle",
						Position = UDim2.new(0.04800000041723251, 0, 0.30000001192092896, 0),
						Size = UDim2.new(0.6000000238418579, 0, 0.6000000238418579, 0),
						BackgroundColor3 = Color3.fromRGB(28,32,48),
						BackgroundTransparency = 1,
						Text = text,
						TextColor3 = Color3.fromRGB(255, 255, 255),
						TextScaled = false,
						Font = FONT,
						TextTransparency = 0.10000000149011612,
						TextXAlignment = Enum.TextXAlignment.Left,
						ZIndex = 1001,
					}, Selection)

					local SelArrow = New("ImageLabel", {
						Name = "TextArrow",
						AnchorPoint = Vector2.new(1, 0.5),
						Position = UDim2.new(1, -12, 0.5, 0),
						Size = UDim2.fromOffset(10, 10),
						BackgroundColor3 = Color3.fromRGB(28,32,48),
						BackgroundTransparency = 1,
						Image = "rbxassetid://10709790948",
						ImageColor3 = Color3.fromRGB(255, 255, 255),
						ImageTransparency = 0.10000000149011612,
						ScaleType = Enum.ScaleType.Fit,
						Rotation = 0,
						ZIndex = 1000,
					}, Selection)

					local TextDefault = New("TextLabel", {
						Name = "TextDefault",
						Position = UDim2.new(0.60, 0, 0.25, 0),
						Size = UDim2.new(0.29, 0, 0.6, 0),
						TextTruncate = Enum.TextTruncate.AtEnd,
						BackgroundColor3 = Color3.fromRGB(28,32,48),
						BackgroundTransparency = 1,
						Text = options[1] or "Auto",
						TextColor3 = Color3.fromRGB(255, 255, 255),
						TextScaled = false,
						Font = FONT,
						TextTransparency = 0,
						TextTruncate = Enum.TextTruncate.AtEnd,
						TextSize = 14,
						ZIndex = 1001,
						TextXAlignment = Enum.TextXAlignment.Left,
					}, Selection)

					-- ============================================================================
					-- PATCH 4: settings-level dropdown uses THEME.plate
					-- ============================================================================
					local DropPopup = New("Frame", {
						Name = "Dropdown",
						Position = UDim2.new(0.60, 0, 1, 4),
						Size = UDim2.fromOffset(150, 0),
						BackgroundColor3 = Color3.fromRGB(17, 19, 28),
						BackgroundTransparency = 0,
						BorderSizePixel = 0,
						Visible = false,
						ZIndex = 5000,
					}, Selection)
					New("UICorner", { CornerRadius = UDim.new(0, 10) }, DropPopup)
						do Stroke(DropPopup) end

					
					local DropContainer = New("ScrollingFrame", {
						AutomaticCanvasSize = Enum.AutomaticSize.Y,
						Name = "Container",
						Position = UDim2.fromOffset(6, 6),
						Size = UDim2.new(1, -12, 1, -12),
						BackgroundColor3 = Color3.fromRGB(162, 162, 162),
						BackgroundTransparency = 1,
						ZIndex = 5000,
						Active = true,
						AutomaticCanvasSize = Enum.AutomaticSize.Y,
						CanvasSize = UDim2.new(),
						ScrollingDirection = Enum.ScrollingDirection.Y,
						ScrollBarThickness = 2,
						ScrollBarImageTransparency = 0.5,
					}, DropPopup)
					New("UIListLayout", { SortOrder = Enum.SortOrder.LayoutOrder, Padding = UDim.new(0, 2) }, DropContainer)

					local function closeDropdown()
						dropOpen = false
						Tween(SelArrow, {Rotation = -90}, 0.14, Enum.EasingStyle.Quint, Enum.EasingDirection.Out)
						UnregisterPopup(DropPopup)
						SmoothClose(DropPopup, 0.18)
					end

					local function updateCheckmarks()
						for opt, selBtn in pairs(selectedBtns) do
							local isSelected = opt == selected
							selBtn.Visible = isSelected
							selBtn.ImageColor3 = mainColor
							local row = selBtn.Parent
							if row then
								row.BackgroundTransparency = 1
								local label = row:FindFirstChild("Label") or row:FindFirstChildWhichIsA("TextLabel")
								if label then label.TextColor3 = isSelected and Color3.fromRGB(228, 228, 229) or Color3.fromRGB(175, 175, 180) end
							end
						end
					end

					for i, opt in ipairs(options) do
						local BtnRow = New("Frame", {
							Name = "Buttons",
							Size = UDim2.new(1, 0, 0, 28),
							BackgroundColor3 = Color3.fromRGB(255, 255, 255),
							BackgroundTransparency = 1,
							ZIndex = 5001,
							LayoutOrder = i,
						}, DropContainer)
						New("UICorner", { CornerRadius = UDim.new(0, 6) }, BtnRow)

						New("TextLabel", {
							Name = "Label",
							Position = UDim2.new(0, 28, 0, 0),
							Size = UDim2.new(1, -36, 1, 0),
							BackgroundColor3 = Color3.fromRGB(162, 162, 162),
							BackgroundTransparency = 1,
							Text = opt,
							TextColor3 = Color3.fromRGB(200, 204, 218),
							TextScaled = false,
							TextSize = 14,
							Font = FONT,
							TextTruncate = Enum.TextTruncate.AtEnd,
							TextTransparency = 0,
							ZIndex = 5002,
							TextXAlignment = Enum.TextXAlignment.Left,
						}, BtnRow)

						local SelBtn = New("ImageButton", {
						Name = "Selected",
						AnchorPoint = Vector2.new(0, 0.5),
						Position = UDim2.new(0, 4, 0.5, 0),
						Size = UDim2.fromOffset(14, 14),
						BackgroundTransparency = 1,
						BorderSizePixel = 0,
						Image = "rbxassetid://138494545053627",
						ImageColor3 = mainColor,
						Visible = false,
						ZIndex = 5006,
					}, BtnRow)
					selectedBtns[opt] = SelBtn

						local RowBtn = New("TextButton", {
							Size = UDim2.new(1, 0, 1, 0),
							BackgroundTransparency = 1,
							Text = "",
							ZIndex = 5005,
						}, BtnRow)
						RowBtn.MouseEnter:Connect(function()
							Tween(BtnRow, { BackgroundTransparency = 0.97 }, 0.08)
						end)
						RowBtn.MouseLeave:Connect(function()
							Tween(BtnRow, { BackgroundTransparency = 1 }, 0.12)
						end)
						RowBtn.MouseButton1Click:Connect(function()
							selected = opt
							TextDefault.Text = opt
							updateCheckmarks()
							closeDropdown()
							InvokeCallback(callback, opt)
						end)
						SelBtn.MouseButton1Click:Connect(function()
							selected = opt
							TextDefault.Text = opt
							updateCheckmarks()
							closeDropdown()
							InvokeCallback(callback, opt)
						end)
					end

					local OpenBtn = New("TextButton", {
						Name = "OpenBtn",
						Size = UDim2.new(1, 0, 1, 0),
						BackgroundTransparency = 1,
						Text = "",
						ZIndex = 1500,
					}, Selection)
					OpenBtn.MouseButton1Click:Connect(function()
						if dropOpen then closeDropdown()
						else
							CloseAllPopupsExcept(DropPopup)
							dropOpen = true
							local popupW = math.max(TextDefault.AbsoluteSize.X, 150)
							local popupH = math.min(#options, 8) * 30 + 10
							DropPopup.Size = UDim2.fromOffset(popupW, popupH)
							DropPopup.BackgroundTransparency = 0
							DropPopup.Visible = false
							ApplyZIndexLadder(DropPopup, NextPopupZ())
							DropPopup.Visible = true
							WindowObj._centerPopupOnField(DropPopup, TextDefault)
							SmoothOpen(DropPopup, 0, 0.14)
							RegisterPopup(DropPopup, closeDropdown, OpenBtn)
						end
					end)

					TextDefault.Text = selected; 
					updateCheckmarks()

					local obj = {}
					function obj:Set(val, silent)
			val = GetValidOption(options, val)
			selected = val
			TextDefault.Text = val
			updateCheckmarks()
			if not silent then InvokeCallback(callback, val) end
		end
					function obj:Get() return selected end
					RegisterConfigElement("settings_dropdown_", text, obj)
					return obj
				end

				function SettingsObj:AddColorpicker(text, defaultColor, callback)
					settingsElemCount = settingsElemCount + 1
					local initialColor = NormalizeColor(defaultColor)
					local Colorpicker = New("Frame", {
						Name = "Colorpicker",
						Size = UDim2.new(1, 0, 0, 34),
						BackgroundTransparency = 1,
						BorderSizePixel = 0,
						LayoutOrder = settingsElemCount,
						ClipsDescendants = false,
						ZIndex = 1000,
					}, SettingsFrame_Container)
					New("TextLabel", {
						Name = "TextToggle",
						Position = UDim2.fromOffset(15, 0),
						Size = UDim2.new(0.68, 0, 1, 0),
						BackgroundTransparency = 1,
						Text = text,
						TextColor3 = Color3.fromRGB(226, 228, 236),
						TextScaled = false,
						TextSize = 14,
						Font = FONT,
						TextXAlignment = Enum.TextXAlignment.Left,
						ZIndex = 1001,
					}, Colorpicker)
					local colorpickerButton = New("ImageButton", {
						Name = "colorpickerButton",
						AnchorPoint = Vector2.new(1, 0.5),
						Position = UDim2.new(1, -14, 0.5, 0),
						Size = UDim2.fromOffset(20, 20),
						BackgroundColor3 = initialColor,
						BorderSizePixel = 0,
						Image = "",
						ZIndex = 1010,
					}, Colorpicker)
					New("UICorner", { CornerRadius = UDim.new(0, 5) }, colorpickerButton)
					Stroke(colorpickerButton, "ColorpickerButtonStroke")
					local picker = AcrylicBlur.CreateColorPicker(colorpickerButton, initialColor, function(c)
						InvokeCallback(callback, c)
					end)
					local obj = {}
					function obj:Set(c)
						local normalized = NormalizeColor(c)
						picker.Set(normalized)
						InvokeCallback(callback, normalized)
					end
					function obj:Get() return picker.Get() end
					RegisterConfigElement("settings_colorpicker_", text, obj)
					return obj
				end

				MakeReadableText(SettingsFrame, 10, 18)
				settingsCache[parentFrame] = SettingsObj
				return SettingsObj
			end

			local _contextTargets = _windowContextTargets
			local _contextMenu
			local _contextOpen = false
			local _contextTarget
			local _bindTarget
			local _bindMenu
			local _keybinds = {}
			local _bindListener

			local function GetTargetBindLabel(target)
				if not target or not target.key then return "Not bound" end
				return BindKeyName(target.key)
			end

			-- A function (target) can carry many hotkeys: target.binds holds bind
			-- objects that read everything else (obj, row, label...) from their
			-- target through __index. _keybinds maps a key to its bind. The dots
			-- show the first bound key of the function.
			local function PaintBindDots(owner)
				if not owner or not owner.dots then return end
				owner.dots.Visible = true
				local indicator = owner.dots:FindFirstChild("BindLabel")
				if not indicator then return end
				local text = ""
				for _, b in ipairs(owner.binds or {}) do
					if b.key then text = BindKeyName(b.key) break end
				end
				indicator.Text = text
			end
			local function SetTargetBind(target, key)
				if not target or not target.obj then return end
				if target.key and _keybinds[target.key] == target then _keybinds[target.key] = nil end
				if key then
					local previous = _keybinds[key]
					if previous and previous ~= target then
						previous.key = nil
						PaintBindDots(previous.owner or previous)
					end
				end
				target.key = key
				if key then _keybinds[key] = target end
				PaintBindDots(target.owner or target)
				if RefreshKeybindOverlay then
					task.defer(RefreshKeybindOverlay)
				end
			end

			-- ============================================================================
			-- PATCH 5: hide hidden binds from the snapshot
			-- ============================================================================
			WindowObj._bindSnapshot = function()
				local out = {}
				for key, target in pairs(_keybinds) do
					if target and target.label and key and not target.hideInList then
						local value
						-- Number binds (Value set in the editor) are listed while
						-- active and show the value they set, with the slider's unit.
						local numberBind = rawget(target, "bindValue") ~= nil
						if numberBind then
							local n = rawget(target, "bindValue")
							value = (n % 1 == 0) and tostring(n) or string.format("%.1f", n)
							local readout = target.row and target.row:FindFirstChild("SliderValue", true)
							local unit = readout and readout:IsA("TextLabel") and string.gsub(readout.Text, "[%d%.%-%s]", "") or ""
							value = value .. unit
						elseif target.showValue and target.obj and type(target.obj.Get) == "function" then
							local ok, v = pcall(target.obj.Get, target.obj)
							if ok and type(v) == "number" then
								value = (v % 1 == 0) and tostring(v) or string.format("%.1f", v)
							elseif ok and type(v) == "string" and v ~= "" then
								value = #v > 12 and (v:sub(1, 11) .. "…") or v
							end
						end
						-- Switch functions are listed only while on; number binds only
						-- while their value is applied.
						local state, listed = nil, true
						if numberBind then
							listed = rawget(target, "active") == true
						elseif target.obj and type(target.obj.Get) == "function" then
							local ok, v = pcall(target.obj.Get, target.obj)
							if ok and type(v) == "boolean" then
								state = v
								listed = v
							end
						end
						-- A generic name ("Enabled") is shown as its function: the
						-- section title, or the tab name for Main/General sections.
						if not target.listLabel then
							local label = target.label
							local generic = { enabled = true, enable = true, active = true, on = true, toggle = true }
							if generic[string.lower(label)] then
								local node = target.row
								while node and not node:GetAttribute("NLTabName") do node = node.Parent end
								if node then
									local section = tostring(node:GetAttribute("NLSectionName") or "")
									local plain = { [""] = true, main = true, general = true, other = true, settings = true, misc = true }
									label = plain[string.lower(section)] and tostring(node:GetAttribute("NLTabName")) or section
								end
							end
							target.listLabel = label
						end
						if listed then
							table.insert(out, { label = target.listLabel, key = BindKeyName(key), mode = target.bindMode or "toggle", value = value, on = state })
						end
					end
				end
				table.sort(out, function(a, b) return a.label:lower() < b.label:lower() end)
				return out
			end

			-- Neverlose hotkey editor (opens right of the hotkey menu): Key chip,
			-- Mode chip with its glyph, Value and Visible switches, red Delete.
			-- Everything the editor needs lives in bindRefs (register budget).
			local bindRefs = {}
			local function CloseBindMenu()
				UnregisterPopup(_bindMenu)
				bindRefs.listening = false
				if not _bindMenu then return end
				if _bindMenu.Visible then SmoothClose(_bindMenu, 0.14) end
				_bindTarget = nil
			end

			local BIND_MODES = { "toggle", "hold", "always" }
			local function CurrentBindMode(target)
				return target and target.bindMode or "toggle"
			end


			local function BindValueText(target)
				if target and target.obj and type(target.obj.Get) == "function" then
					local ok, value = pcall(target.obj.Get, target.obj)
					if ok and value ~= nil then
						if typeof(value) == "Color3" then return ColorToHex(value) end
						if type(value) == "boolean" then return value and "On" or "Off" end
						if type(value) == "number" or type(value) == "string" then
							local text = tostring(value)
							return #text > 12 and (string.sub(text, 1, 11) .. "…") or text
						end
					end
				end
				return "—"
			end
			local function PaintBindMenu(target)
				local keyText = bindRefs.listening and "..." or (target.key and BindKeyName(target.key) or "-")
				bindRefs.key.Text = keyText
				bindRefs.key.Size = UDim2.fromOffset(math.max(20, math.ceil(MeasureText(keyText, 12, FONT) + 12)), 20)
				local mode = CurrentBindMode(target)
				bindRefs.modeText.Text = mode:sub(1, 1):upper() .. mode:sub(2)
				bindRefs.modeChip.Size = UDim2.fromOffset(math.ceil(MeasureText(bindRefs.modeText.Text, 13, FONT) + 34), 22)
				for name, glyph in pairs(bindRefs.modeGlyphs) do glyph.Visible = name == mode end
				local item = bindRefs.itemFor and bindRefs.itemFor[target]
				if item and item.Parent then item.Text = target.key and BindKeyName(target.key) or "None" end
				bindRefs.setSwitch("value", target.showValue == true)
				-- Slider functions show the number box instead of the switch.
				local numeric = target.min ~= nil and target.max ~= nil
				local valueSwitch = bindRefs.switches and bindRefs.switches.value
				if valueSwitch then valueSwitch.track.Visible = not numeric end
				if bindRefs.valueBox then
					bindRefs.valueBox.Visible = numeric
					if numeric then
						if rawget(target, "bindValue") == nil then
							local ok, v = pcall(target.obj.Get, target.obj)
							target.bindValue = ok and tonumber(v) or target.min
						end
						local n = target.bindValue
						bindRefs.valueBox.Text = (n % 1 == 0) and tostring(n) or string.format("%.1f", n)
					end
				end
				bindRefs.setSwitch("visible", not target.hideInList)
			end

			local function BuildBindMenu()
				if _bindMenu then return _bindMenu end
				local ICON = Color3.fromRGB(200, 201, 210)
				local TEXT = Color3.fromRGB(235, 236, 241)
				local RED = Color3.fromRGB(226, 96, 116)
				_bindMenu = New("Frame", {
					Name = "BindPrompt",
					Size = UDim2.fromOffset(196, 166),
					BackgroundColor3 = Color3.fromRGB(18, 18, 25),
					BackgroundTransparency = 0,
					BorderSizePixel = 0,
					Visible = false,
					ZIndex = Z_BASE + 950,
					ClipsDescendants = false,
				}, MainFrame)
				New("UICorner", { CornerRadius = UDim.new(0, 10) }, _bindMenu)
				Stroke(_bindMenu)
				AttachShadow(_bindMenu, { radius = 10, layers = 5, step = 1.6, bias = 3 })

				local body = New("Frame", { Name = "Body", Size = UDim2.new(1, 0, 1, 0), BackgroundTransparency = 1, ZIndex = Z_BASE + 951 }, _bindMenu)
				New("UIPadding", { PaddingTop = UDim.new(0, 6), PaddingBottom = UDim.new(0, 6), PaddingLeft = UDim.new(0, 6), PaddingRight = UDim.new(0, 6) }, body)
				New("UIListLayout", { Padding = UDim.new(0, 0), SortOrder = Enum.SortOrder.LayoutOrder }, body)

				local function makeRow(order, icon, text, color)
					local row = New("TextButton", {
						Name = "Row" .. order, LayoutOrder = order, Size = UDim2.new(1, 0, 0, 28),
						BackgroundColor3 = Color3.fromRGB(255, 255, 255), BackgroundTransparency = 1, AutoButtonColor = false, Text = "", ZIndex = Z_BASE + 952,
					}, body)
					New("UICorner", { CornerRadius = UDim.new(0, 6) }, row)
					if icon then
						New("ImageLabel", {
							Name = "Icon", AnchorPoint = Vector2.new(0, 0.5), Position = UDim2.new(0, 10, 0.5, 0), Size = UDim2.fromOffset(14, 14),
							BackgroundTransparency = 1, Image = icon, ImageColor3 = color == RED and RED or ICON, ScaleType = Enum.ScaleType.Fit, ZIndex = Z_BASE + 953,
						}, row)
					end
					New("TextLabel", {
						Name = "Label", Position = UDim2.new(0, 36, 0, 0), Size = UDim2.new(0, 70, 1, 0), BackgroundTransparency = 1,
						Text = text, TextColor3 = color, TextSize = 13, Font = FONT, TextXAlignment = Enum.TextXAlignment.Left, ZIndex = Z_BASE + 953,
					}, row)
					row.MouseEnter:Connect(function() Tween(row, { BackgroundTransparency = 0.97 }, 0.08) end)
					row.MouseLeave:Connect(function() Tween(row, { BackgroundTransparency = 1 }, 0.12) end)
					return row
				end
				local function gap(order)
					New("Frame", { Name = "Gap" .. order, LayoutOrder = order, Size = UDim2.new(1, 0, 0, 6), BackgroundTransparency = 1, ZIndex = Z_BASE + 952 }, body)
				end

				-- Key: small dark chip on the right; click it, then press a key.
				-- Icons: Lucide set as uploaded for the Fluent UI library.
				local keyRow = makeRow(1, "rbxassetid://10734974522", "Key", TEXT) -- sunrise
				bindRefs.key = New("TextLabel", {
					Name = "KeyChip", AnchorPoint = Vector2.new(1, 0.5), Position = UDim2.new(1, -8, 0.5, 0), Size = UDim2.fromOffset(20, 20),
					BackgroundColor3 = Color3.fromRGB(28, 29, 39), BackgroundTransparency = 0, Text = "-", TextColor3 = Color3.fromRGB(190, 192, 202),
					TextSize = 12, Font = FONT, ZIndex = Z_BASE + 953,
				}, keyRow)
				New("UICorner", { CornerRadius = UDim.new(0, 5) }, bindRefs.key)
				keyRow.MouseButton1Click:Connect(function()
					if not _bindTarget then return end
					bindRefs.listening = true
					PaintBindMenu(_bindTarget)
				end)

				-- Mode: dark chip with the mode glyph and accent text, then a small
				-- key-cap icon; both cycle Toggle / Hold / Always.
				local modeRow = makeRow(2, "rbxassetid://10723416765", "Mode", TEXT) -- keyboard
				bindRefs.modeChip = New("Frame", {
					Name = "ModeChip", AnchorPoint = Vector2.new(1, 0.5), Position = UDim2.new(1, -30, 0.5, 0), Size = UDim2.fromOffset(74, 22),
					BackgroundColor3 = Color3.fromRGB(28, 29, 39), BackgroundTransparency = 0, ZIndex = Z_BASE + 953,
				}, modeRow)
				New("UICorner", { CornerRadius = UDim.new(0, 6) }, bindRefs.modeChip)
				bindRefs.modeText = New("TextLabel", {
					Name = "ModeText", Position = UDim2.fromOffset(26, 0), Size = UDim2.new(1, -30, 1, 0), BackgroundTransparency = 1,
					Text = "Toggle", TextColor3 = mainColor, TextSize = 13, Font = FONT, TextXAlignment = Enum.TextXAlignment.Left, ZIndex = Z_BASE + 954,
				}, bindRefs.modeChip)
				bindRefs.modeGlyphs = {}
				for mode, asset in pairs({ toggle = "rbxassetid://10734985040", hold = "rbxassetid://10723405649", always = "rbxassetid://10709797837" }) do
					bindRefs.modeGlyphs[mode] = New("ImageLabel", {
						Name = "ModeGlyph_" .. mode, AnchorPoint = Vector2.new(0, 0.5), Position = UDim2.new(0, 6, 0.5, 0), Size = UDim2.fromOffset(15, 15),
						BackgroundTransparency = 1, Image = asset, ImageColor3 = mainColor, ScaleType = Enum.ScaleType.Fit,
						ZIndex = Z_BASE + 954, Visible = false,
					}, bindRefs.modeChip)
				end
				New("ImageLabel", {
					Name = "ModeMore", AnchorPoint = Vector2.new(1, 0.5), Position = UDim2.new(1, -8, 0.5, 0), Size = UDim2.fromOffset(14, 14),
					BackgroundTransparency = 1, Image = "rbxassetid://10709790948", ImageColor3 = ICON, ScaleType = Enum.ScaleType.Fit,
					ZIndex = Z_BASE + 953,
				}, modeRow)
				modeRow.MouseButton1Click:Connect(function()
					if not _bindTarget then return end
					local current, index = CurrentBindMode(_bindTarget), 1
					for i, m in ipairs(BIND_MODES) do if m == current then index = i break end end
					_bindTarget.bindMode = BIND_MODES[(index % #BIND_MODES) + 1]
					PaintBindMenu(_bindTarget)
					if RefreshKeybindOverlay then task.defer(RefreshKeybindOverlay) end
				end)

				gap(3)

				-- Switches in the menu's toggle style (off: dark track, grey knob).
				bindRefs.switches = {}
				bindRefs.setSwitch = function(name, on)
					local s = bindRefs.switches[name]
					if not s then return end
					Tween(s.track, { BackgroundColor3 = on and mainColor or Color3.fromRGB(8, 10, 16) }, 0.15)
					Tween(s.knob, {
						Position = on and UDim2.fromOffset(14, 2) or UDim2.fromOffset(2, 2),
						BackgroundColor3 = on and Color3.fromRGB(255, 255, 255) or Color3.fromRGB(139, 145, 157),
					}, 0.15, Enum.EasingStyle.Quint, Enum.EasingDirection.Out)
				end
				local function switchRow(order, icon, text, name, onClick)
					local row = makeRow(order, icon, text, TEXT)
					local track = New("Frame", {
						Name = "Switch", AnchorPoint = Vector2.new(1, 0.5), Position = UDim2.new(1, -8, 0.5, 0), Size = UDim2.fromOffset(28, 16),
						BackgroundColor3 = Color3.fromRGB(8, 10, 16), BorderSizePixel = 0, ZIndex = Z_BASE + 953,
					}, row)
					New("UICorner", { CornerRadius = UDim.new(1, 0) }, track)
					local knob = New("Frame", {
						Name = "Knob", Position = UDim2.fromOffset(2, 2), Size = UDim2.fromOffset(12, 12),
						BackgroundColor3 = Color3.fromRGB(139, 145, 157), BorderSizePixel = 0, ZIndex = Z_BASE + 954,
					}, track)
					New("UICorner", { CornerRadius = UDim.new(1, 0) }, knob)
					bindRefs.switches[name] = { track = track, knob = knob }
					row.MouseButton1Click:Connect(function()
						if not _bindTarget then return end
						onClick(_bindTarget)
						PaintBindMenu(_bindTarget)
						if RefreshKeybindOverlay then task.defer(RefreshKeybindOverlay) end
					end)
				end
				switchRow(4, "rbxassetid://10723426722", "Value", "value", function(t)
					if t.min ~= nil and t.max ~= nil then
						if bindRefs.valueBox then bindRefs.valueBox:CaptureFocus() end
						return
					end
					t.showValue = not t.showValue
				end)
				-- Slider functions: the bind sets a number, typed here.
				do
					local valueRow = body:FindFirstChild("Row4")
					local box = New("TextBox", {
						Name = "ValueBox", AnchorPoint = Vector2.new(1, 0.5), Position = UDim2.new(1, -8, 0.5, 0), Size = UDim2.fromOffset(52, 20),
						BackgroundColor3 = Color3.fromRGB(28, 29, 39), BackgroundTransparency = 0, Text = "", PlaceholderText = "0",
						TextColor3 = Color3.fromRGB(235, 236, 241), TextSize = 12, Font = FONT, ClearTextOnFocus = false,
						Visible = false, ZIndex = Z_BASE + 954,
					}, valueRow)
					New("UICorner", { CornerRadius = UDim.new(0, 5) }, box)
					bindRefs.valueBox = box
					box.FocusLost:Connect(function()
						local t = _bindTarget
						if not t or t.min == nil or t.max == nil then return end
						local n = tonumber((string.gsub(box.Text, "[^%d%.%-]", "")))
						if n then
							t.bindValue = math.clamp(n, t.min, t.max)
							if t.active then t.obj:Set(t.bindValue) end
						end
						PaintBindMenu(t)
						if RefreshKeybindOverlay then task.defer(RefreshKeybindOverlay) end
					end)
				end
				switchRow(5, "rbxassetid://10723346959", "Visible", "visible", function(t) t.hideInList = not t.hideInList end)

				gap(6)

				local delRow = makeRow(7, "rbxassetid://10747362241", "Delete", RED) -- trash-2
				delRow.MouseButton1Click:Connect(function()
					local t = _bindTarget
					CloseBindMenu()
					if t then bindRefs.removeBind(t) end
				end)
				return _bindMenu
			end

			-- anchor: the hotkey menu it was opened from (editor goes to its
			-- right and stays its child), or nil to open under the row.
			local function OpenBindMenu(target, anchor, trigger)
				if not anchor then CloseAllPopupsExcept(nil) end
				_bindTarget = target
				bindRefs.listening = false
				BuildBindMenu()
				PaintBindMenu(target)
				ApplyZIndexLadder(_bindMenu, NextPopupZ())
				SmoothOpen(_bindMenu, 0, 0.16)
				if anchor and anchor.Parent and anchor.Visible then
					MovePopupToAbsolute(_bindMenu, anchor.AbsolutePosition.X + anchor.AbsoluteSize.X + 6, anchor.AbsolutePosition.Y)
				else
					local row = target.row
					MovePopupToAbsolute(_bindMenu,
						row.AbsolutePosition.X + row.AbsoluteSize.X - _bindMenu.AbsoluteSize.X,
						row.AbsolutePosition.Y + row.AbsoluteSize.Y + 4)
				end
				ConstrainPopupToMainFrame(_bindMenu, 8)
				RegisterPopup(_bindMenu, CloseBindMenu, trigger)
			end

			local function CloseContextMenu()
				if not _contextMenu then return end
				_contextOpen = false
				_contextTarget = nil
				UnregisterPopup(_contextMenu)
				SmoothClose(_contextMenu, 0.15)
			end

			local function BuildContextMenu()
				if _contextMenu then return _contextMenu end
				_contextMenu = New("Frame", {
					Name = "ElementContextMenu",
					Position = UDim2.new(0.5, 0, 0.5, 0),
					Size = UDim2.fromOffset(136, 102),
					BackgroundColor3 = Color3.fromRGB(18, 18, 25),
					BackgroundTransparency = 0,
					BorderSizePixel = 0,
					Visible = false,
					ZIndex = 8000,
					ClipsDescendants = false,
				}, MainFrame)
				New("UICorner", { CornerRadius = UDim.new(0, 10) }, _contextMenu)
				Stroke(_contextMenu)
				AttachShadow(_contextMenu, { radius = 10, layers = 5, step = 1.6, bias = 3 })
				-- Rows live in a child so the shadow (skipped on layout frames) works.
				local list = New("Frame", { Name = "Items", Size = UDim2.fromScale(1, 1), BackgroundTransparency = 1, ZIndex = 8001 }, _contextMenu)
				New("UIListLayout", { Padding = UDim.new(0, 0), SortOrder = Enum.SortOrder.LayoutOrder }, list)
				New("UIPadding", { PaddingTop = UDim.new(0, 6), PaddingBottom = UDim.new(0, 6), PaddingLeft = UDim.new(0, 6), PaddingRight = UDim.new(0, 6) }, list)
				return _contextMenu
			end

			-- keepOpen: the menu stays (the hotkey editor opens to its right).
			local contextItemOrder = 0
			local function AddContextItem(labelText, iconAsset, callback, keepOpen)
				contextItemOrder = contextItemOrder + 1
				local isReset = labelText == "Reset"
				local list = _contextMenu:FindFirstChild("Items")
				local item = New("TextButton", {
					LayoutOrder = contextItemOrder,
					Name = "MenuItem",
					Size = UDim2.new(1, 0, 0, 28),
					BackgroundColor3 = Color3.fromRGB(255, 255, 255),
					BackgroundTransparency = 1,
					AutoButtonColor = false,
					Text = labelText,
					TextColor3 = isReset and Color3.fromRGB(226, 96, 116) or Color3.fromRGB(235, 236, 241),
					TextScaled = false,
					TextSize = 13,
					Font = FONT,
					TextXAlignment = Enum.TextXAlignment.Left,
					ZIndex = 8002,
				}, list)
				New("UICorner", { CornerRadius = UDim.new(0, 6) }, item)
				New("UIPadding", { PaddingLeft = UDim.new(0, 36) }, item)
				-- UIPadding shifts the icon too: offset it back by the padding.
				local icon = New("ImageLabel", {
					Name = "MenuIcon",
					AnchorPoint = Vector2.new(0, 0.5),
					Position = UDim2.new(0, -26, 0.5, 0),
					Size = UDim2.fromOffset(14, 14),
					BackgroundTransparency = 1,
					Image = iconAsset or "",
					ImageColor3 = isReset and Color3.fromRGB(226, 96, 116) or Color3.fromRGB(200, 201, 210),
					ScaleType = Enum.ScaleType.Fit,
					ZIndex = 8003,
				}, item)
				item.MouseEnter:Connect(function()
					Tween(item, { BackgroundTransparency = 0.97 }, 0.08)
				end)
				item.MouseLeave:Connect(function()
					Tween(item, { BackgroundTransparency = 1 }, 0.12)
				end)
				item.MouseButton1Click:Connect(function()
					local target = _contextTarget
					if not keepOpen then CloseContextMenu() end
					if target and callback then callback(target, item) end
				end)
				return item, icon
			end

			bindRefs.newBind = function(owner)
				local bind = setmetatable({ owner = owner }, { __index = owner })
				table.insert(owner.binds, bind)
				return bind
			end
			bindRefs.removeBind = function(bind)
				SetTargetBind(bind, nil)
				local owner = bind.owner
				if owner then
					for i, b in ipairs(owner.binds) do
						if b == bind then table.remove(owner.binds, i) break end
					end
					PaintBindDots(owner)
					if _contextOpen and _contextTarget == owner then bindRefs.fillContext(owner) end
				end
			end

			-- Neverlose hotkey menu: All Hotkeys, the function's hotkeys (each
			-- opens its editor), New Hotkey (adds one under the others and opens
			-- it), Reset. Rebuilt in place when the list changes.
			bindRefs.fillContext = function(target)
				local list = _contextMenu:FindFirstChild("Items")
				for _, child in ipairs(list:GetChildren()) do
					if child:IsA("GuiObject") then child:Destroy() end
				end
				contextItemOrder = 0
				bindRefs.itemFor = {}
				AddContextItem("All Hotkeys", "rbxassetid://10723433811", function()
					if WindowObj.KeybindList then WindowObj.KeybindList.setEnabled(true) end
				end)
				for _, bind in ipairs(target.binds) do
					local item = AddContextItem(bind.key and BindKeyName(bind.key) or "None", "rbxassetid://10723416765", function(_, it)
						OpenBindMenu(bind, _contextMenu, it)
					end, true)
					bindRefs.itemFor[bind] = item
				end
				AddContextItem("New Hotkey", "rbxassetid://10734923868", function(current)
					local bind = bindRefs.newBind(current)
					bindRefs.fillContext(current)
					OpenBindMenu(bind, _contextMenu, bindRefs.itemFor[bind])
				end, true)
				New("Frame", { Name = "Gap", LayoutOrder = contextItemOrder + 1, Size = UDim2.new(1, 0, 0, 6), BackgroundTransparency = 1, ZIndex = 8001 }, list)
				contextItemOrder = contextItemOrder + 1
				AddContextItem("Reset", "rbxassetid://10734940376", function(current)
					if current.obj and current.obj.Set and current.defaultValue ~= nil then
						current.obj:Set(current.defaultValue)
					end
				end)
				local count = 3 + #target.binds
				_contextMenu.Size = UDim2.fromOffset(136, 6 + 28 * count + 6 + 6)
				-- Items added after the popup was laddered would draw behind it.
				if _contextMenu.Visible then ApplyZIndexLadder(_contextMenu, _contextMenu.ZIndex) end
			end

			local function OpenContextMenu(target, point)
				BuildContextMenu()
				CloseAllPopupsExcept(_contextMenu)
				_contextTarget = target
				bindRefs.fillContext(target)
				ApplyZIndexLadder(_contextMenu, NextPopupZ())
				SmoothOpen(_contextMenu, 0, 0.15)
				-- Opens at the cursor, like Neverlose.
				MovePopupToAbsolute(_contextMenu, point.X + 4, point.Y + 4)
				ConstrainPopupToMainFrame(_contextMenu, 8)
				local settled = _contextMenu.Position
				_contextMenu.Position = UDim2.new(settled.X.Scale, settled.X.Offset, settled.Y.Scale, settled.Y.Offset - 6)
				Tween(_contextMenu, { Position = settled }, 0.2, Enum.EasingStyle.Quint, Enum.EasingDirection.Out)
				_contextOpen = true
				RegisterPopup(_contextMenu, CloseContextMenu, target.dots)
			end

			local function IsEditableTarget()
				local ok, focused = pcall(function() return UserInputService:GetFocusedTextBox() end)
				return not (ok and focused)
			end

			local function RunBoundFunction(target, phase)
				if not target or not target.obj then return end
				task.delay(0.05, function() if RefreshKeybindOverlay then pcall(RefreshKeybindOverlay) end end)
				local value = target.obj.Get and target.obj:Get()
				-- Number bind: toggle applies the bind's value and restores the
				-- previous one on the next press; hold applies it while held.
				if type(value) == "number" and rawget(target, "bindValue") ~= nil then
					local function apply(on)
						if on then
							target.prevValue = value
							target.obj:Set(target.bindValue)
						else
							target.obj:Set(target.prevValue or value)
						end
						target.active = on
					end
					if phase == "up" then
						if target.bindMode == "hold" and target.active then apply(false) end
					elseif target.bindMode == "hold" then
						if not target.active then apply(true) end
					else
						apply(not target.active)
					end
					return
				end
				if phase == "up" then
					if target.bindMode == "hold" and type(value) == "boolean" then
						target.obj:Set(false)
					end
					return
				end
				if target.bindMode == "hold" and type(value) == "boolean" then
					target.obj:Set(true)
					return
				end
				if type(value) == "boolean" then
					target.obj:Set(not value)
				elseif type(value) == "number" and target.min and target.max then
					local step = (target.max - target.min) / 10
					target.obj:Set(math.clamp(value + step, target.min, target.max))
				elseif type(value) == "string" and target.options then
					for index, option in ipairs(target.options) do
						if option == value then
							target.obj:Set(target.options[index % #target.options + 1] or target.options[1])
							break
						end
					end
				end
			end

			BindElementContext = function(row, kind, label, obj, defaultValue, options, min, max)
				if not row or not obj then return end
				CleanBorders(row)
				local target = {
					row = row,
					kind = kind,
					label = tostring(label or "Function"),
					obj = obj,
					defaultValue = defaultValue,
					options = options,
					min = min,
					max = max,
				}
				target.binds = {}
				-- Stable id for the config: kind + label + occurrence.
				bindRefs.keyCounts = bindRefs.keyCounts or {}
				do
					local base = tostring(kind) .. ":" .. target.label
					bindRefs.keyCounts[base] = (bindRefs.keyCounts[base] or 0) + 1
					target.cfgKey = base .. "#" .. bindRefs.keyCounts[base]
				end
				_contextTargets[row] = target
				local dots = row:FindFirstChild("ContextDots")
				target.dots = dots
				PaintBindDots(target)
				-- obj:SetTooltip(text): description shown after hovering ~1.5s.
				if not obj.SetTooltip then
					function obj:SetTooltip(text) WindowObj._tooltip(row, text) return self end
				end
				if obj.Bind then return end
				-- Script API works on the function's first hotkey.
				function obj:Bind(key)
					local normalized = type(key) == "string" and Enum.KeyCode[key] or key
					if normalized and normalized ~= Enum.KeyCode.Unknown then
						SetTargetBind(target.binds[1] or bindRefs.newBind(target), normalized)
					end
					return self:GetBind()
				end
				function obj:Unbind()
					while target.binds[1] do bindRefs.removeBind(target.binds[1]) end
					return self:GetBind()
				end
				function obj:GetBind() return target.binds[1] and target.binds[1].key end
			end

			-- Hotkeys in the config: per function, each hotkey's key ("Enum.KeyCode.F"
			-- or a wheel token), mode, Visible (h = hidden) and Value switches.
			WindowObj._configExtras.hotkeys = {
				get = function()
					local out = {}
					for _, target in pairs(_contextTargets) do
						if target.cfgKey and target.binds and #target.binds > 0 then
							local list = {}
							for _, b in ipairs(target.binds) do
								local k = rawget(b, "key")
								local text = typeof(k) == "EnumItem" and tostring(k) or (type(k) == "string" and k or nil)
								table.insert(list, { k = text, m = rawget(b, "bindMode"), h = rawget(b, "hideInList") == true, v = rawget(b, "showValue") == true, n = rawget(b, "bindValue") })
							end
							out[target.cfgKey] = list
						end
					end
					return out
				end,
				set = function(saved)
					if type(saved) ~= "table" then return end
					for _, target in pairs(_contextTargets) do
						while target.binds and target.binds[1] do bindRefs.removeBind(target.binds[1]) end
						local list = target.cfgKey and saved[target.cfgKey]
						if type(list) == "table" then
							for _, item in ipairs(list) do
								local b = bindRefs.newBind(target)
								b.bindMode = item.m
								b.hideInList = item.h == true
								b.showValue = item.v == true
								if type(item.n) == "number" then b.bindValue = item.n end
								local key
								if type(item.k) == "string" then
									local enumType, enumName = item.k:match("^Enum%.(%w+)%.(%w+)$")
									if enumType then
										pcall(function() key = Enum[enumType][enumName] end)
									else
										key = item.k
									end
								end
								if key then SetTargetBind(b, key) end
							end
						end
					end
					if RefreshKeybindOverlay then task.defer(RefreshKeybindOverlay) end
				end,
			}

			local function IsExtraMouseType(t)
				-- Roblox's standard enum only exposes MouseButton1/2/3.
				-- Read optional executor-provided side-button types by name instead
				-- of indexing unsupported Enum.UserInputType members.
				local name
				local ok = pcall(function() name = t and t.Name end)
				if not ok or type(name) ~= "string" then
					name = tostring(t):match("([^%.]+)$")
				end
				return name == "MouseButton4" or name == "MouseButton5"
			end

			UserInputService.InputBegan:Connect(function(input, gameProcessed)
				-- Key chip clicked: the next key (or side mouse button) becomes the
				-- bind; Backspace/Delete clears it, Escape cancels.
				if _bindTarget and bindRefs.listening then
					local isKeyboard = input.UserInputType == Enum.UserInputType.Keyboard
					if isKeyboard or IsExtraMouseType(input.UserInputType) then
						local key = isKeyboard and input.KeyCode or input.UserInputType
						if key == Enum.KeyCode.Backspace or key == Enum.KeyCode.Delete then
							SetTargetBind(_bindTarget, nil)
						elseif key ~= Enum.KeyCode.Escape and key ~= Enum.KeyCode.Unknown then
							SetTargetBind(_bindTarget, key)
						end
						bindRefs.listening = false
						PaintBindMenu(_bindTarget)
						return
					end
				end
				-- Middle (or right) click on any function opens the hotkey menu.
				-- No gameProcessed check: clicks over the menu's own buttons are
				-- always "processed", which used to swallow every one of them.
				if input.UserInputType == Enum.UserInputType.MouseButton2
					or input.UserInputType == Enum.UserInputType.MouseButton3 then
					if not MainFrame.Visible then return end
					local point = GetInputPosition(input)
					for _, entry in ipairs(_openPopups) do
						if entry.frame and entry.frame.Visible and IsPointInsideTree(entry.frame, point) then return end
					end
					for row, target in pairs(_contextTargets) do
						if row.Parent and row.Visible and IsPointInsideTree(row, point) then
							OpenContextMenu(target, point)
							return
						end
					end
				end
			end)

			UserInputService.InputBegan:Connect(function(input, gameProcessed)
				if bindRefs.listening then return end
				local key = input.KeyCode
				if key == nil or key == Enum.KeyCode.Unknown then
					local t = input.UserInputType
					if not IsExtraMouseType(t) then return end
					key = t
				end
				if not IsEditableTarget() then return end
				local target = _keybinds[key]
				-- Hold presses here and releases in InputEnded; Always ignores keys.
				if target and target.bindMode ~= "always" then
					RunBoundFunction(target, "down")
				end
			end)

			UserInputService.InputChanged:Connect(function(input, gameProcessed)
				-- Roblox exposes the wheel as MouseWheel; direction is input.Position.Z.
				local wheelType = input.UserInputType
				if wheelType ~= Enum.UserInputType.MouseWheel then return end
				local wheelKey = input.Position.Z > 0 and "MouseWheelUp" or "MouseWheelDown"
				if input.Position.Z == 0 then return end
				if _bindTarget and bindRefs.listening then
					-- Keep wheel direction as a string token; Roblox has no enum members for up/down.
					SetTargetBind(_bindTarget, wheelKey)
					bindRefs.listening = false
					PaintBindMenu(_bindTarget)
					return
				end
				if gameProcessed or not IsEditableTarget() then return end
				local target = _keybinds[wheelKey]
				if target then RunBoundFunction(target, "down") end
			end)

			UserInputService.InputEnded:Connect(function(input)
				if not IsEditableTarget() then return end
				local key = input.KeyCode
				if key == nil or key == Enum.KeyCode.Unknown then key = input.UserInputType end
				local target = key and _keybinds[key] or nil
				if target and target.bindMode == "hold" then
					RunBoundFunction(target, "up")
				end
			end)


			function SectionObj:AddToggle(text, default, callback)
				elemCount = elemCount + 1
				local enabled = default == true

				local Toggle = New("Frame", {
					Name = "Toggle",
					Size = UDim2.new(1, 0, 0, 39),
					BackgroundColor3 = Color3.fromRGB(162, 162, 162),
					BackgroundTransparency = 1,
					LayoutOrder = elemCount,
				}, Elements)
				New("Frame", {
					Name = "Lines",
					Position = UDim2.new(0.06, 0, 1, -1),
					Size = UDim2.new(0.88, 0, 0, 1),
					BackgroundColor3 = Color3.fromRGB(162, 162, 162),
					BackgroundTransparency = 0.9,
					ZIndex = 100,
					BorderSizePixel = 0,
				}, Toggle)

				New("TextLabel", {
					Name = "TextToggle",
					Position = UDim2.new(0.04800000086426735, 0, 0.3, 0),
					Size = UDim2.new(0.6600000262260437, 0, 0.5000000238418579, 0),
					BackgroundColor3 = Color3.fromRGB(28,32,48),
					BackgroundTransparency = 1,
					Text = text,
					TextColor3 = Color3.fromRGB(217, 219, 226),
					TextScaled = false,
					Font = FONT,
					TextTransparency = 0.10000000149011612,
					TextXAlignment = Enum.TextXAlignment.Left,
				}, Toggle)

				local Effect = New("Frame", {
					Name = "Effect",
					Position = UDim2.new(1, -14, 0.5, 0),
					AnchorPoint = Vector2.new(1, 0.5),
					Size = UDim2.fromOffset(33, 20),
					BackgroundColor3 = enabled and mainColor or Color3.fromRGB(8, 10, 16),
				}, Toggle)
				New("UICorner", { CornerRadius = UDim.new(1, 0) }, Effect)

				local Icon = New("Frame", {
					Name = "Icon",
					Position = enabled and UDim2.fromOffset(15, 2) or UDim2.fromOffset(2, 2),
					Size = UDim2.fromOffset(16, 16),
					BackgroundColor3 = enabled and Color3.fromRGB(255, 255, 255) or Color3.fromRGB(139, 145, 157),
					BackgroundTransparency = 0,
				}, Effect)
				New("UICorner", { CornerRadius = UDim.new(1, 0) }, Icon)
				New("UIAspectRatioConstraint", {}, Icon)

				local Btn = New("TextButton", {
					Size = UDim2.new(1, 0, 1, 0),
					BackgroundTransparency = 1,
					Text = "",
					ZIndex = 5,
				}, Toggle)


				local function Set(val)
					enabled = val == true
					Tween(Effect, { BackgroundColor3 = enabled and mainColor or Color3.fromRGB(8, 10, 16) }, 0.16, Enum.EasingStyle.Sine)
					Tween(Icon, { Position = enabled and UDim2.fromOffset(15, 2) or UDim2.fromOffset(2, 2), BackgroundColor3 = enabled and Color3.fromRGB(255, 255, 255) or Color3.fromRGB(139, 145, 157), BackgroundTransparency = 0 }, 0.16, Enum.EasingStyle.Quad)
					InvokeCallback(callback, enabled)
				end

				Btn.MouseButton1Click:Connect(function() Set(not enabled) end)

				local obj = {}
				function obj:Set(v) Set(v) end
				function obj:Get() return enabled end
				function obj:AddSettings() return MakeSettings(Toggle, nil, text) end
				RegisterConfigElement("toggle_", text, obj)
				CenterElement(Toggle)
				BindElementContext(Toggle, "toggle", text, obj, default)
				return obj
			end

			function SectionObj:AddCheckbox(text, default, callback)
				elemCount = elemCount + 1
				local enabled = default == true
				local CheckBoxToggle = New("Frame", {
					Name = "CheckBoxToggle",
					Size = UDim2.new(1, 0, 0, 39),
					BackgroundColor3 = Color3.fromRGB(162, 162, 162),
					BackgroundTransparency = 1,
					LayoutOrder = elemCount,
				}, Elements)
				New("Frame", {
					Name = "Lines",
					Position = UDim2.new(0.06, 0, 1, -1),
					Size = UDim2.new(0.88, 0, 0, 1),
					BackgroundColor3 = Color3.fromRGB(162, 162, 162),
					BackgroundTransparency = 0.9,
					BorderSizePixel = 0,
					ZIndex = 100,
				}, CheckBoxToggle)
				local CheckBox = New("Frame", {
					Name = "CheckBox",
					AnchorPoint = Vector2.new(0, 0.5),
					Position = UDim2.new(0, 15, 0.5, 0),
					Size = UDim2.fromOffset(12, 12),
					BackgroundTransparency = 1,
					ZIndex = 1001,
				}, CheckBoxToggle)
				New("UICorner", {}, CheckBox)
				New("UIAspectRatioConstraint", {}, CheckBox)
				local Check = New("ImageLabel", {
					Name = "Check",
					Size = UDim2.new(1, 0, 1, 0),
					BackgroundTransparency = 1,
					Image = "rbxassetid://138494545053627",
					ImageTransparency = enabled and 0.1 or 1,
					ZIndex = 1001,
				}, CheckBox)
				New("TextLabel", {
					Name = "TextToggle",
					Position = UDim2.fromOffset(34, 0),
					Size = UDim2.new(0.55, 0, 1, 0),
					BackgroundTransparency = 1,
					Text = text,
					TextColor3 = Color3.fromRGB(255, 255, 255),
					TextScaled = false,
					Font = FONT,
					TextTransparency = 0.1,
					TextXAlignment = Enum.TextXAlignment.Left,
					ZIndex = 1001,
				}, CheckBoxToggle)
				local Btn = New("TextButton", {
					Size = UDim2.new(1, 0, 1, 0),
					BackgroundTransparency = 1,
					Text = "",
					ZIndex = 1010,
				}, CheckBoxToggle)

				local function Set(val)
					enabled = val == true
					Tween(Check, {ImageTransparency = enabled and 0.1 or 1}, 0.2)
					InvokeCallback(callback, enabled)
				end
				Btn.MouseButton1Click:Connect(function() Set(not enabled) end)
				local obj = {}
				function obj:Set(v) Set(v) end
				function obj:Get() return enabled end
				function obj:AddSettings() return MakeSettings(CheckBoxToggle, nil, text) end
				RegisterConfigElement("checkbox_", text, obj)
				CenterElement(CheckBoxToggle)
				BindElementContext(CheckBoxToggle, "checkbox", text, obj, default)
				return obj
			end

			function SectionObj:AddColorToggle(text, defaultColor, defaultEnabled, callback)
				if type(defaultEnabled) == "function" then
					callback = defaultEnabled
					defaultEnabled = false
				end
				if type(callback) ~= "function" then callback = nil end
				local state = {
					enabled = defaultEnabled == true,
					color = NormalizeColor(defaultColor),
				}
				return SectionObj:AddToggleColorpicker(text, state.enabled, state.color,
					function(enabled)
						state.enabled = enabled
						if callback then callback(state.color, enabled) end
					end,
					function(newColor)
						state.color = newColor
						if callback then callback(newColor, state.enabled) end
					end)
			end

			function SectionObj:AddToggleColorpicker(text, defaultEnabled, defaultColor, callback, colorCallback)
				if type(callback) ~= "function" then callback = nil end
				if type(colorCallback) ~= "function" then colorCallback = nil end
				elemCount = elemCount + 1
				local enabled = defaultEnabled == true
				local color = NormalizeColor(defaultColor)
				local Toggle = New("Frame", {
					Name = "Toggle",
					Size = UDim2.new(1, 0, 0, 39),
					BackgroundTransparency = 1,
					LayoutOrder = elemCount,
				}, Elements)
				New("Frame", {
					Name = "Lines",
					Position = UDim2.new(0.06, 0, 1, -1),
					Size = UDim2.new(0.88, 0, 0, 1),
					BackgroundColor3 = Color3.fromRGB(162, 162, 162),
					BackgroundTransparency = 0.9,
					BorderSizePixel = 0,
					ZIndex = 3,
				}, Toggle)
				New("TextLabel", {
					Name = "TextToggle",
					Position = UDim2.fromOffset(15, 0),
					Size = UDim2.new(0.6, 0, 1, 0),
					BackgroundTransparency = 1,
					Text = text,
					TextColor3 = Color3.fromRGB(217, 219, 226),
					TextScaled = false,
					TextSize = 14,
					Font = FONT,
					TextTransparency = 0.1,
					TextXAlignment = Enum.TextXAlignment.Left,
					ZIndex = 5,
				}, Toggle)
				local Effect = New("Frame", {
					Name = "Effect",
					AnchorPoint = Vector2.new(1, 0.5),
					Position = UDim2.new(1, -14, 0.5, 0),
					Size = UDim2.fromOffset(33, 20),
					BackgroundColor3 = enabled and mainColor or Color3.fromRGB(8, 10, 16),
					ZIndex = 6,
				}, Toggle)
				New("UICorner", { CornerRadius = UDim.new(1, 0) }, Effect)
				local Icon = New("Frame", {
					Name = "Icon",
					Position = enabled and UDim2.fromOffset(15, 2) or UDim2.fromOffset(2, 2),
					Size = UDim2.fromOffset(16, 16),
					BackgroundColor3 = enabled and Color3.fromRGB(255, 255, 255) or Color3.fromRGB(139, 145, 157),
					BorderSizePixel = 0,
					ZIndex = 7,
				}, Effect)
				New("UICorner", { CornerRadius = UDim.new(1, 0) }, Icon)
				local cpBtn = New("ImageButton", {
					Name = "colorpickerButton",
					AnchorPoint = Vector2.new(1, 0.5),
					Position = UDim2.new(1, -55, 0.5, 0),
					Size = UDim2.fromOffset(20, 20),
					BackgroundColor3 = color,
					BorderSizePixel = 0,
					Image = "",
					ZIndex = 8,
				}, Toggle)
				New("UICorner", { CornerRadius = UDim.new(0, 5) }, cpBtn)
				Stroke(cpBtn, "ColorpickerButtonStroke")
				local Btn = New("TextButton", {
					Name = "ToggleHitArea",
					Position = UDim2.new(0, 0, 0, 0),
					Size = UDim2.new(1, 0, 1, 0),
					BackgroundTransparency = 1,
					Text = "",
					ZIndex = 4,
				}, Toggle)

				local function NotifyColor(c)
					color = NormalizeColor(c)
					if colorCallback then
						InvokeCallback(colorCallback, color)
					elseif callback then
						InvokeCallback(callback, color, enabled)
					end
				end
				local function NotifyEnabled()
					if colorCallback then
						if callback then InvokeCallback(callback, enabled) end
					elseif callback then
						InvokeCallback(callback, color, enabled)
					end
				end
				local picker = AcrylicBlur.CreateColorPicker(cpBtn, color, NotifyColor)

				local function SetEnabled(val)
					enabled = val == true
					Tween(Effect, { BackgroundColor3 = enabled and mainColor or Color3.fromRGB(8, 10, 16) }, 0.16, Enum.EasingStyle.Sine)
					Tween(Icon, { Position = enabled and UDim2.fromOffset(15, 2) or UDim2.fromOffset(2, 2), BackgroundColor3 = enabled and Color3.fromRGB(255, 255, 255) or Color3.fromRGB(139, 145, 157), BackgroundTransparency = 0 }, 0.16, Enum.EasingStyle.Quad)
					NotifyEnabled()
				end
				Btn.MouseButton1Click:Connect(function() SetEnabled(not enabled) end)

				local obj = {}
				function obj:Set(val) SetEnabled(val) end
				function obj:Get() return enabled end
				function obj:SetColor(c)
					local normalized = NormalizeColor(c)
					picker.Set(normalized)
					NotifyColor(normalized)
				end
				function obj:GetColor() return color end
				function obj:AddSettings() return MakeSettings(Toggle, nil, text) end
				RegisterConfigElement("togglecolorpicker_", text, obj)
				RegisterConfigElement("togglecolorpicker_color_", text, {
					Get = function() return obj:GetColor() end,
					Set = function(_, c) obj:SetColor(c) end,
				})
				CenterElement(Toggle)
				BindElementContext(Toggle, "togglecolorpicker", text, obj, defaultEnabled)
				return obj
			end

			function SectionObj:AddSlider(text, min, max, default, callback, suffix)
				elemCount = elemCount + 1
				if type(suffix) ~= "string" then suffix = "" end
				local value
				min, max, value = NormalizeRange(min, max, default)
				value = Quantize(value, min, max, GetSliderStep(min, max))
				local initRatio = (value - min) / (max - min)
				local dragging = false

				local Slider = New("Frame", {
					Name = "Slider",
					Size = UDim2.new(1, 0, 0, 39),
					BackgroundColor3 = Color3.fromRGB(162, 162, 162),
					BackgroundTransparency = 1,
					LayoutOrder = elemCount,
				}, Elements)
				New("Frame", {
					Name = "Lines",
					Position = UDim2.new(0.06, 0, 1, -1),
					Size = UDim2.new(0.88, 0, 0, 1),
					BackgroundColor3 = Color3.fromRGB(162, 162, 162),
					BackgroundTransparency = 0.9,
					ZIndex = 100,
					BorderSizePixel = 0,
				}, Slider)

				New("TextLabel", {
					Name = "TextToggle",
					Position = UDim2.fromOffset(15, 0),
					Size = UDim2.new(0.6600000262260437, 0, 0.5000000238418579, 0),
					BackgroundColor3 = Color3.fromRGB(28,32,48),
					BackgroundTransparency = 1,
					Text = text,
					TextColor3 = Color3.fromRGB(217, 219, 226),
					TextScaled = false,
					Font = FONT,
					TextTransparency = 0.10000000149011612,
					TextXAlignment = Enum.TextXAlignment.Left,
				}, Slider)

				local Effect = New("Frame", {
					Name = "Effect",
					Position = UDim2.new(0.4980000042915344, 0, 0.25, 0),
					Size = UDim2.new(0.5, 0, 0.6990000009536743, 0),
					BackgroundColor3 = Color3.fromRGB(255, 255, 255),
					BackgroundTransparency = 1,
				}, Slider)

				local SliderValue = New("TextLabel", {
					Name = "SliderValue",
					Position = UDim2.new(0.6990000009536743, 0, 0.10000000149011612, 0),
					Size = UDim2.new(0.25, 0, 0.8080000281333923, 0),
					BackgroundColor3 = Color3.fromRGB(24, 27, 37),
					Text = FormatSliderValue(value, suffix),
					TextColor3 = Color3.fromRGB(255, 255, 255),
					TextScaled = false,
					Font = FONT,
					TextTransparency = 0.20000000298023224,
				}, Effect)
				New("UICorner", { CornerRadius = UDim.new(0, 5) }, SliderValue)

				local Line = New("Frame", {
					Name = "Line",
					Active = true,
					Position = UDim2.new(0.03999999910593033, 0, 0.3190000057220459, 0),
					Size = UDim2.new(0.6000000238418579, 0, 0.15000000596046448, 0),
					BackgroundColor3 = Color3.fromRGB(33,37,53),
				}, Effect)
				New("UICorner", { CornerRadius = UDim.new(1, 0) }, Line)

				local InLine = New("Frame", {
					Name = "InLine",
					Size = UDim2.new(0, 0, 1, 0),
					BackgroundColor3 = mainColor,
					ZIndex = 2,
				}, Line)
				New("UICorner", { CornerRadius = UDim.new(1, 0) }, InLine)

				local Trigger = New("TextButton", {
					Name = "Trigger",
					Position = UDim2.new(0.10000000149011612, 0, -1.8000000715255737, 0),
					Size = UDim2.new(1.1999999284744263, 0, 4.200000286102295, 0),
					AnchorPoint = Vector2.new(0.800000011920929, 0),
					BackgroundColor3 = Color3.fromRGB(255, 255, 255),
					BackgroundTransparency = 1,
					Active = false,
					Text = "",
					ZIndex = 3,
				}, Line)
				New("UICorner", { CornerRadius = UDim.new(1, 0) }, Trigger)
				New("UIAspectRatioConstraint", {}, Trigger)
				local Thumb = New("Frame", {
					Name = "Thumb",
					AnchorPoint = Vector2.new(0.5, 0.5),
					Position = UDim2.new(initRatio, 0, 0.5, 0),
					Size = UDim2.fromOffset(12, 12),
					BackgroundColor3 = Color3.fromRGB(255, 255, 255),
					BorderSizePixel = 0,
					ZIndex = Line.ZIndex + 3,
				}, Line)
				New("UICorner", { CornerRadius = UDim.new(1, 0) }, Thumb)
				Stroke(Thumb)
				Line.MouseEnter:Connect(function()
					Tween(Thumb, { Size = UDim2.fromOffset(14, 14) }, 0.11, Enum.EasingStyle.Sine, Enum.EasingDirection.Out)
				end)
				Line.MouseLeave:Connect(function()
					Tween(Thumb, { Size = UDim2.fromOffset(12, 12) }, 0.13, Enum.EasingStyle.Sine, Enum.EasingDirection.Out)
				end)
				local initialValue = value
				task.defer(function()
					if value ~= initialValue then return end
					InLine.Size = UDim2.fromScale(initRatio, 1)
					Thumb.Position = UDim2.new(initRatio, 0, 0.5, 0)
					Trigger.Position = UDim2.new(initRatio, 0, -1.8000000715255737, 0)
				end)

					local function update(input)
						local pointer = GetInputPosition(input)
						local lineSize = Line.AbsoluteSize.X
						if lineSize <= 0 then return end
						local sizeScale = ClampRatio(pointer.X - Line.AbsolutePosition.X, lineSize)
						local nextValue = Quantize(((max - min) * sizeScale) + min, min, max, GetSliderStep(min, max))
						local changed = nextValue ~= value
						value = nextValue
						local span = max - min
						local snappedRatio = span ~= 0 and math.clamp((value - min) / span, 0, 1) or 0
						InLine.Size = UDim2.fromScale(snappedRatio, 1)
						Trigger.Position = UDim2.new(snappedRatio, 0, -1.8000000715255737, 0)
						Thumb.Position = UDim2.new(snappedRatio, 0, 0.5, 0)
						SliderValue.Text = FormatSliderValue(value, suffix)
						if changed then InvokeCallback(callback, value) end
					end

				local Hitbox = New("TextButton", {
					Name = "SliderHitbox",
					Position = UDim2.new(0.03999999910553033, 0, 0, -10),
					Size = UDim2.new(0.6000000238418579, 0, 1, 20),
					BackgroundTransparency = 1,
					Text = "",
					AutoButtonColor = false,
					ZIndex = 4,
				}, Effect)
				Hitbox.InputBegan:Connect(function(input)
					if IsPrimaryInput(input) then
						dragging = true
						update(input)
					end
				end)

				Line.InputBegan:Connect(function(input)
					if IsPrimaryInput(input) then
						dragging = true
						update(input)
					end
				end)

				UserInputService.InputEnded:Connect(function(input)
					if IsPrimaryInput(input) then
						dragging = false
					end
				end)

				UserInputService.InputChanged:Connect(function(input)
					if dragging then
						if input.UserInputType == Enum.UserInputType.MouseMovement or input.UserInputType == Enum.UserInputType.Touch then
							update(input)
						end
					end
				end)

				local obj = {}
				function obj:Set(val)
					local numeric = type(val) == "number" and val == val and val or min
						value = math.clamp(numeric, min, max)
					value = Quantize(value, min, max, GetSliderStep(min, max))
					local span = max - min
					local ratio = span ~= 0 and math.clamp((value - min) / span, 0, 1) or 0
					Tween(InLine, { Size = UDim2.fromScale(ratio, 1) }, 0.14, Enum.EasingStyle.Sine, Enum.EasingDirection.Out)
					Trigger.Position = UDim2.new(ratio, 0, -1.8000000715255737, 0)
					Tween(Thumb, { Position = UDim2.new(ratio, 0, 0.5, 0) }, 0.14, Enum.EasingStyle.Sine, Enum.EasingDirection.Out)
					SliderValue.Text = FormatSliderValue(value, suffix)
					InvokeCallback(callback, value)
				end
				function obj:Get() return value end
				function obj:AddSettings() return MakeSettings(Slider, "slider", text) end
				RegisterConfigElement("slider_", text, obj)
				CenterElement(Slider)
				BindElementContext(Slider, "slider", text, obj, value, nil, min, max)
				return obj
			end

			function SectionObj:AddDropdown(text, options, default, callback)
				if type(default) == "function" then
					callback = default
					default = nil
				end
				options = NormalizeOptions(options)
				elemCount = elemCount + 1
				local selected = GetValidOption(options, default)
				local dropOpen = false

				local Dropdown = New("Frame", {
					Name = "Dropdown",
					Size = UDim2.new(1, 0, 0, 39),
					BackgroundColor3 = Color3.fromRGB(162, 162, 162),
					BackgroundTransparency = 1,
					LayoutOrder = elemCount,
					ClipsDescendants = false,
				}, Elements)

				New("Frame", {
					Name = "Lines",
					Position = UDim2.new(0.06, 0, 1, -1),
					Size = UDim2.new(0.88, 0, 0, 1),
					BackgroundColor3 = Color3.fromRGB(162, 162, 162),
					BackgroundTransparency = 0.9,
					ZIndex = 100,
					BorderSizePixel = 0,
				}, Dropdown)

				New("TextLabel", {
					Name = "TextToggle",
					Position = UDim2.fromOffset(15, 0),
					Size = UDim2.new(0.6000000238418579, 0, 0.5000000238418579, 0),
					BackgroundColor3 = Color3.fromRGB(28,32,48),
					BackgroundTransparency = 1,
					Text = text,
					TextColor3 = Color3.fromRGB(217, 219, 226),
					TextScaled = false,
					Font = FONT,
					TextTransparency = 0.10000000149011612,
					TextXAlignment = Enum.TextXAlignment.Left,
				}, Dropdown)

				local TopBar = New("TextButton", {
					Name = "TopBar",
					Position = UDim2.new(1, -14, 0.5, 0),
					AnchorPoint = Vector2.new(1, 0.5),
					Size = UDim2.fromOffset(135, 26),
					BackgroundColor3 = Color3.fromRGB(30, 33, 47),
					BackgroundTransparency = 0,
					Text = "",
					TextColor3 = Color3.fromRGB(255, 255, 255),
					TextScaled = false,
					Font = FONT,
					ZIndex = 6,
				}, Dropdown)
				New("UICorner", { CornerRadius = UDim.new(0, 6) }, TopBar)
				local TopBarText = New("TextLabel", {
					Name = "TopBarText",
					Position = UDim2.new(0, 8, 0, 0),
					Size = UDim2.new(1, -36, 1, 0),
					BackgroundTransparency = 1,
					Text = selected or "Select",
					TextColor3 = Color3.fromRGB(255, 255, 255),
					TextScaled = false,
					TextSize = 14,
					Font = FONT,
					TextXAlignment = Enum.TextXAlignment.Left,
					TextTruncate = Enum.TextTruncate.AtEnd,
					ZIndex = 7,
				}, TopBar)

				local Arrow = New("ImageLabel", {
					Name = "Arrow",
					Position = UDim2.new(1, -10, 0.5, 0),
					Size = UDim2.fromOffset(10, 10),
					AnchorPoint = Vector2.new(1, 0.5),
					BackgroundColor3 = Color3.fromRGB(162, 162, 162),
					BackgroundTransparency = 1,
					Image = "rbxassetid://10709790948",
					ImageColor3 = Color3.fromRGB(255, 255, 255),
					ScaleType = Enum.ScaleType.Fit,
					Rotation = 0,
					ZIndex = 7,
				}, TopBar)

				local DownBar = New("Frame", {
					Name = "DownBar",
					Position = UDim2.new(0.02, 0, 1, 4),
					Size = UDim2.fromOffset(150, 0),
					BackgroundColor3 = Color3.fromRGB(17, 19, 28),
					BackgroundTransparency = 0,
					Visible = false,
					ZIndex = 5000,
					ClipsDescendants = true,
				}, Dropdown)
				New("UICorner", { CornerRadius = UDim.new(0, 10) }, DownBar)
				local PopupStroke = Stroke(DownBar)

				local Scrolls = New("ScrollingFrame", {
					Name = "Scrolls",
					Position = UDim2.fromOffset(6, 6),
					Size = UDim2.new(1, -12, 1, -12),
					ScrollingEnabled = true,
					BackgroundColor3 = Color3.fromRGB(162, 162, 162),
					BackgroundTransparency = 1,
					BorderSizePixel = 0,
					ScrollBarThickness = 2,
					Active = true,
					AutomaticCanvasSize = Enum.AutomaticSize.Y,
					CanvasSize = UDim2.new(),
					ScrollingDirection = Enum.ScrollingDirection.Y,
					ClipsDescendants = false,
					ZIndex = 5001,
				}, DownBar)
				New("UIListLayout", {
					Padding = UDim.new(0, 2),
					SortOrder = Enum.SortOrder.LayoutOrder,
				}, Scrolls)

				local function closeDropdown()
					if not dropOpen and not DownBar.Visible then return end
					dropOpen = false
					UnregisterPopup(DownBar)
					DownBar:SetAttribute("CloseToken", (DownBar:GetAttribute("CloseToken") or 0) + 1)
					SmoothClose(DownBar, 0.1)
					if _openDropdown == closeDropdown then _openDropdown = nil end
				end

				local optionRows = {}
				for _, opt in ipairs(options) do
					local Buttons = New("TextButton", {
						Name = "Buttons",
						Size = UDim2.new(1, 0, 0, 28),
						ClipsDescendants = false,
						BackgroundColor3 = Color3.fromRGB(255, 255, 255),
						BackgroundTransparency = 1,
						Text = opt,
						TextColor3 = selected == opt and Color3.fromRGB(228, 228, 229) or Color3.fromRGB(175, 175, 180),
						TextScaled = false,
						TextSize = 14,
						Font = FONT,
						TextTransparency = 0,
						TextXAlignment = Enum.TextXAlignment.Left,
						TextTruncate = Enum.TextTruncate.AtEnd,
						AutoButtonColor = false,
						ZIndex = 5002,
					}, Scrolls)
					New("UICorner", { CornerRadius = UDim.new(0, 6) }, Buttons)
					New("UIPadding", { PaddingLeft = UDim.new(0, 16), PaddingRight = UDim.new(0, 8) }, Buttons)
					New("ImageLabel", { Name = "SelectedCheck", AnchorPoint = Vector2.new(0, 0.5), Position = UDim2.new(0, -22, 0.5, 0), Size = UDim2.fromOffset(14, 14), BackgroundTransparency = 1, Image = "rbxassetid://138494545053627", ImageColor3 = Color3.fromRGB(255, 255, 255), Visible = false, ZIndex = 5003 }, Buttons)
					optionRows[opt] = Buttons

					Buttons.MouseEnter:Connect(function()
						Tween(Buttons, { BackgroundTransparency = 0.97 }, 0.09, Enum.EasingStyle.Sine)
					end)
					Buttons.MouseLeave:Connect(function()
						Tween(Buttons, { BackgroundTransparency = 1 }, 0.12, Enum.EasingStyle.Sine)
					end)
					Buttons.MouseButton1Click:Connect(function()
						selected = opt
						TopBarText.Text = opt; 
						for option, row in pairs(optionRows) do
							Tween(row, { BackgroundTransparency = 1 }, 0.12, Enum.EasingStyle.Sine)
							local check = row:FindFirstChild("SelectedCheck")
							if check then check.Visible = false end
							row.TextColor3 = option == selected and Color3.fromRGB(228, 228, 229) or Color3.fromRGB(175, 175, 180)
						end
						InvokeCallback(callback, opt)
						closeDropdown()
					end)
				end

				TopBar.MouseButton1Click:Connect(function()
					if dropOpen then
						closeDropdown()
					else
						CloseAllPopupsExcept(DownBar)
						if _openDropdown then _openDropdown() end
						dropOpen = true
						_openDropdown = closeDropdown
						DownBar:SetAttribute("CloseToken", (DownBar:GetAttribute("CloseToken") or 0) + 1)
						DownBar.Visible = false
						ApplyZIndexLadder(DownBar, NextPopupZ())
						local h = math.min(#options, 8) * 30 + 10
						local popupWidth = math.max(TopBar.AbsoluteSize.X, 150)
						local finalSize = UDim2.fromOffset(popupWidth, h)
						local knownSize = Vector2.new(popupWidth, math.min(h, math.max(MainFrame.AbsoluteSize.Y, 1)))
						DownBar.Size = finalSize
						DownBar.BackgroundTransparency = 0
						DownBar.Visible = true
						WindowObj._centerPopupOnField(DownBar, TopBar)
						SmoothOpen(DownBar, 0, 0.14)
						RegisterPopup(DownBar, closeDropdown, TopBar)
					end
				end)

				local obj = {}
				function obj:Set(val, silent)
					val = GetValidOption(options, val)
					selected = val
					TopBarText.Text = val
					
					for option, row in pairs(optionRows) do
						Tween(row, { BackgroundTransparency = 1 }, 0.1, Enum.EasingStyle.Sine, Enum.EasingDirection.Out)
						local check = row:FindFirstChild("SelectedCheck")
						if check then check.Visible = false end
						row.TextColor3 = option == selected and Color3.fromRGB(228, 228, 229) or Color3.fromRGB(175, 175, 180)
					end
					if not silent then InvokeCallback(callback, val) end
				end
				function obj:Get() return selected end
				function obj:AddSettings() return MakeSettings(Dropdown, "dropdown", text) end
				
				RegisterConfigElement("dropdown_", text, obj)
				if default ~= nil then obj:Set(GetValidOption(options, default), true) end
				CenterElement(Dropdown)
				BindElementContext(Dropdown, "dropdown", text, obj, selected, options)
				return obj

			end


			function SectionObj:AddDropdownColorpicker(text, options, defaultColor, callback, colorCallback)
				options = NormalizeOptions(options)
				if type(callback) ~= "function" then callback = nil end
				if type(colorCallback) ~= "function" then colorCallback = nil end
				elemCount = elemCount + 1
				local selected = GetValidOption(options, options[1])
				local currentColor = NormalizeColor(defaultColor)
				local dropOpen = false

				local Dropdown = New("Frame", {
					Name = "Dropdown",
					Size = UDim2.new(1, 0, 0, 39),
					BackgroundTransparency = 1,
					LayoutOrder = elemCount,
					ClipsDescendants = false,
				}, Elements)
				New("Frame", {
					Name = "Lines",
					Position = UDim2.new(0.05, 0, 1, -1),
					Size = UDim2.new(0.9, 0, 0, 1),
					BackgroundColor3 = Color3.fromRGB(162, 162, 162),
					BackgroundTransparency = 0.9,
					BorderSizePixel = 0,
					ZIndex = 3,
				}, Dropdown)
				New("TextLabel", {
					Name = "TextDropdown",
					Position = UDim2.fromOffset(15, 0),
					Size = UDim2.new(0.6, 0, 1, 0),
					BackgroundTransparency = 1,
					Text = text,
					TextColor3 = Color3.fromRGB(217, 219, 226),
					TextScaled = false,
					TextSize = 14,
					Font = FONT,
					TextTransparency = 0.1,
					TextXAlignment = Enum.TextXAlignment.Left,
					ZIndex = 5,
				}, Dropdown)

				local cpBtn = New("ImageButton", {
					Name = "colorpickerButton",
					AnchorPoint = Vector2.new(1, 0.5),
					Position = UDim2.new(1, -155, 0.5, 0),
					Size = UDim2.fromOffset(20, 20),
					BackgroundColor3 = currentColor,
					BorderSizePixel = 0,
					Image = "",
					ZIndex = 8,
				}, Dropdown)
				New("UICorner", { CornerRadius = UDim.new(0, 5) }, cpBtn)
				Stroke(cpBtn, "ColorpickerButtonStroke")

				local TopBar = New("TextButton", {
					Name = "TopBar",
					AnchorPoint = Vector2.new(1, 0.5),
					Position = UDim2.new(1, -14, 0.5, 0),
					Size = UDim2.fromOffset(135, 26),
					BackgroundColor3 = Color3.fromRGB(30, 33, 47),
					BackgroundTransparency = 0,
					Text = "",
					TextColor3 = Color3.fromRGB(255, 255, 255),
					TextScaled = false,
					Font = FONT,
					ZIndex = 6,
				}, Dropdown)
				New("UICorner", { CornerRadius = UDim.new(0, 6) }, TopBar)
				local TopBarText = New("TextLabel", {
					Name = "TopBarText",
					Position = UDim2.new(0, 8, 0, 0),
					Size = UDim2.new(1, -36, 1, 0),
					BackgroundTransparency = 1,
					Text = selected,
					TextColor3 = Color3.fromRGB(255, 255, 255),
					TextScaled = false,
					TextSize = 14,
					Font = FONT,
					TextTransparency = 0,
					TextXAlignment = Enum.TextXAlignment.Left,
					TextTruncate = Enum.TextTruncate.AtEnd,
					ZIndex = 7,
				}, TopBar)
				local Arrow = New("ImageLabel", {
					Name = "Arrow",
					AnchorPoint = Vector2.new(1, 0.5),
					Position = UDim2.new(1, -10, 0.5, 0),
					Size = UDim2.fromOffset(10, 10),
					BackgroundTransparency = 1,
					Image = "rbxassetid://10709790948",
					ImageColor3 = Color3.fromRGB(255, 255, 255),
					ImageTransparency = 0,
					ScaleType = Enum.ScaleType.Fit,
					Rotation = 0,
					ZIndex = 8,
				}, TopBar)

				local DownBar = New("Frame", {
					Name = "DownBar",
					Position = UDim2.new(0, 0, 1, 4),
					Size = UDim2.fromOffset(150, 0),
					BackgroundColor3 = Color3.fromRGB(17, 19, 28),
					BackgroundTransparency = 0,
					BorderSizePixel = 0,
					ClipsDescendants = true,
					Visible = false,
					ZIndex = Z_BASE + 500,
				}, Dropdown)
				New("UICorner", { CornerRadius = UDim.new(0, 10) }, DownBar)
				Stroke(DownBar, "DropdownPopupStroke")
				local Scrolls = New("ScrollingFrame", {
					Name = "Scrolls",
					Position = UDim2.fromOffset(6, 6),
					Size = UDim2.new(1, -12, 1, -12),
					BackgroundTransparency = 1,
					BorderSizePixel = 0,
					CanvasSize = UDim2.new(),
					ScrollBarThickness = 2,
					Active = true,
					ScrollingEnabled = true,
					AutomaticCanvasSize = Enum.AutomaticSize.Y,
					ScrollingDirection = Enum.ScrollingDirection.Y,
					ZIndex = Z_BASE + 501,
				}, DownBar)
				New("UIPadding", {
					PaddingLeft = UDim.new(0, 0),
					PaddingRight = UDim.new(0, 0),
					PaddingTop = UDim.new(0, 0),
					PaddingBottom = UDim.new(0, 0),
				}, Scrolls)
				New("UIListLayout", {
					Padding = UDim.new(0, 2),
					SortOrder = Enum.SortOrder.LayoutOrder,
				}, Scrolls)

				local optionRows = {}
				local function updateSelected()
					TopBarText.Text = selected
					for option, row in pairs(optionRows) do
						local isSelected = option == selected
						row.BackgroundTransparency = 1
						row.TextColor3 = isSelected and Color3.fromRGB(228, 228, 229) or Color3.fromRGB(175, 175, 180)
						local check = row:FindFirstChild("SelectedCheck")
						if check then check.Visible = false end
					end
				end
				local function closeDropdown()
					dropOpen = false
					SmoothClose(DownBar, 0.1)
					UnregisterPopup(DownBar)
					if _openDropdown == closeDropdown then _openDropdown = nil end
				end
				local function CurrentColor() return currentColor end
				local function NotifySelection(value)
					if colorCallback then
						if callback then InvokeCallback(callback, value) end
					elseif callback then
						InvokeCallback(callback, value, CurrentColor())
					end
				end
				local function NotifyColor(c)
					currentColor = NormalizeColor(c)
					if colorCallback then
						InvokeCallback(colorCallback, currentColor)
					elseif callback then
						InvokeCallback(callback, selected, currentColor)
					end
				end

				for _, opt in ipairs(options) do
					local row = New("TextButton", {
						Name = "Option",
						Size = UDim2.new(1, 0, 0, 28),
						BackgroundColor3 = Color3.fromRGB(255, 255, 255),
						BackgroundTransparency = 1,
						Text = opt,
						TextColor3 = opt == selected and Color3.fromRGB(228, 228, 229) or Color3.fromRGB(175, 175, 180),
						TextScaled = false,
						TextSize = 14,
						Font = FONT,
						TextTransparency = 0,
						TextXAlignment = Enum.TextXAlignment.Left,
						TextTruncate = Enum.TextTruncate.AtEnd,
						ZIndex = Z_BASE + 502,
					}, Scrolls)
					New("UICorner", { CornerRadius = UDim.new(0, 6) }, row)
					New("UIPadding", { PaddingLeft = UDim.new(0, 16), PaddingRight = UDim.new(0, 8) }, row)
					New("ImageLabel", {
						Name = "SelectedCheck",
						AnchorPoint = Vector2.new(0, 0.5),
						Position = UDim2.new(0, -22, 0.5, 0), -- UIPadding (28) shifts children too
						Size = UDim2.fromOffset(14, 14),
						BackgroundTransparency = 1,
						Image = "rbxassetid://138494545053627",
						ImageColor3 = Color3.fromRGB(255, 255, 255),
						Visible = opt == selected,
						ZIndex = Z_BASE + 503,
					}, row)
					optionRows[opt] = row
					row.MouseEnter:Connect(function() Tween(row, { BackgroundTransparency = 0.97 }, 0.09, Enum.EasingStyle.Sine) end)
					row.MouseLeave:Connect(function() Tween(row, { BackgroundTransparency = 1 }, 0.12, Enum.EasingStyle.Sine) end)
					row.MouseButton1Click:Connect(function()
						selected = opt
						updateSelected()
						NotifySelection(opt)
						closeDropdown()
					end)
				end
				local function openDropdown()
					if dropOpen then closeDropdown(); return end
					CloseAllPopupsExcept(DownBar)
					if _openDropdown then _openDropdown() end
					dropOpen = true
					_openDropdown = closeDropdown
					local popupWidth = math.max(TopBar.AbsoluteSize.X, 150)
					local h = math.min(#options, 8) * 30 + 10
					local finalSize = UDim2.fromOffset(popupWidth, h)
					local knownSize = Vector2.new(popupWidth, math.min(h, math.max(MainFrame.AbsoluteSize.Y, 1)))
					DownBar.Size = finalSize
					DownBar.Visible = true
					ApplyZIndexLadder(DownBar, NextPopupZ())
					WindowObj._centerPopupOnField(DownBar, TopBar)
					SmoothOpen(DownBar, 0, 0.14)
					RegisterPopup(DownBar, closeDropdown, TopBar)
				end
				TopBar.MouseButton1Click:Connect(openDropdown)

				local picker = AcrylicBlur.CreateColorPicker(cpBtn, currentColor, NotifyColor)
				updateSelected()
				local obj = {}
				function obj:Set(val)
					selected = GetValidOption(options, val)
					updateSelected()
					NotifySelection(selected)
				end
				function obj:Get() return selected end
				function obj:SetColor(c)
					currentColor = NormalizeColor(c)
					picker.Set(currentColor)
					NotifyColor(currentColor)
				end
				function obj:GetColor() return currentColor end
				function obj:AddSettings() return MakeSettings(Dropdown, "dropdown", text) end
				RegisterConfigElement("dropdowncolorpicker_", text, obj)
				RegisterConfigElement("dropdowncolorpicker_color_", text, {
					Get = function() return obj:GetColor() end,
					Set = function(_, c) obj:SetColor(c) end,
				})
				CenterElement(Dropdown)
				BindElementContext(Dropdown, "dropdowncolorpicker", text, obj, selected, options)
				return obj
			end

			function SectionObj:AddColorpicker(text, defaultColor, callback)
				elemCount = elemCount + 1
				local initialColor = NormalizeColor(defaultColor)
				local Colorpicker = New("Frame", {
					Name = "Colorpicker",
					Size = UDim2.new(1, 0, 0, 39),
					BackgroundTransparency = 1,
					BorderSizePixel = 0,
					LayoutOrder = elemCount,
					ClipsDescendants = false,
					ZIndex = 2,
				}, Elements)
				New("Frame", {
					Name = "Lines",
					Position = UDim2.new(0.06, 0, 1, -1),
					Size = UDim2.new(0.89, 0, 0, 1),
					BackgroundColor3 = Color3.fromRGB(162, 162, 162),
					BackgroundTransparency = 0.9,
					BorderSizePixel = 0,
					ZIndex = 3,
				}, Colorpicker)
				New("TextLabel", {
					Name = "TextToggle",
					Position = UDim2.fromOffset(15, 0),
					Size = UDim2.new(0.6, 0, 1, 0),
					BackgroundTransparency = 1,
					Text = text,
					TextColor3 = Color3.fromRGB(217, 219, 226),
					TextScaled = false,
					TextSize = 14,
					Font = FONT,
					TextTransparency = 0.1,
					TextXAlignment = Enum.TextXAlignment.Left,
					ZIndex = 5,
				}, Colorpicker)
				local colorpickerButton = New("ImageButton", {
					Name = "colorpickerButton",
					AnchorPoint = Vector2.new(1, 0.5),
					Position = UDim2.new(1, -14, 0.5, 0),
					Size = UDim2.fromOffset(20, 20),
					BackgroundColor3 = initialColor,
					BorderSizePixel = 0,
					Image = "",
					ZIndex = 30,
				}, Colorpicker)
				New("UICorner", { CornerRadius = UDim.new(0, 5) }, colorpickerButton)
				Stroke(colorpickerButton, "ColorpickerButtonStroke")
				local picker = AcrylicBlur.CreateColorPicker(colorpickerButton, initialColor, function(c)
					InvokeCallback(callback, c)
				end)
				local obj = {}
				function obj:Set(c)
					local normalized = NormalizeColor(c)
					picker.Set(normalized)
					InvokeCallback(callback, normalized)
				end
				function obj:Get() return picker.Get() end
				function obj:AddSettings() return MakeSettings(Colorpicker, nil, text) end
				RegisterConfigElement("colorpicker_", text, obj)
				CenterElement(Colorpicker)
				BindElementContext(Colorpicker, "colorpicker", text, obj, initialColor)
				return obj
			end

			function SectionObj:AddAccordion(text)
				text = tostring(text or "Accordion")
				elemCount = elemCount + 1

				local DropdownSection = Instance.new('Frame')
				DropdownSection.Name = "Accordion"
				-- Same height as every other row; 0 squashed the header text into a smear.
				DropdownSection.Size = UDim2.new(1, 0, 0, 39)
				DropdownSection.BackgroundColor3 = Color3.fromRGB(17, 19, 27)
				DropdownSection.BackgroundTransparency = 1
				DropdownSection.LayoutOrder = elemCount
				DropdownSection.Parent = Elements

				local TextArrow = Instance.new('ImageLabel')
				TextArrow.Name = "TextArrow"
				TextArrow.Position = UDim2.new(1, -12, 0.5, 0)
				TextArrow.AnchorPoint = Vector2.new(1, 0.5)
				TextArrow.Size = UDim2.fromOffset(10, 10)
				TextArrow.BackgroundTransparency = 1
				TextArrow.Image = "rbxassetid://10709790948"
				TextArrow.ImageColor3 = Color3.fromRGB(255, 255, 255)
				TextArrow.ImageTransparency = 0.3
				TextArrow.ScaleType = Enum.ScaleType.Fit
				-- Neverlose marks these rows with ">" and opens a plate beside the row.
				TextArrow.Rotation = -90
				TextArrow.Parent = DropdownSection

				local Text = Instance.new('TextLabel')
				Text.Name = "Text"
				Text.Position = UDim2.new(0.04800000041723251, 0, 0.30000001192092896, 0)
				Text.Size = UDim2.new(0.6600000262260437, 0, 0.5000000238418579, 0)
				Text.BackgroundColor3 = Color3.fromRGB(28,32,48)
				Text.BackgroundTransparency = 1
				Text.Text = text
				-- Built without New(), so it missed the row text size (16) and stayed tiny.
				Text.TextColor3 = Color3.fromRGB(226, 228, 236)
				Text.TextScaled = false
				Text.TextSize = 15
				Text.TextYAlignment = Enum.TextYAlignment.Center
				Text.TextTruncate = Enum.TextTruncate.AtEnd
				Text.Font = FONT
				Text.TextTransparency = 0.10000000149011612
				Text.TextXAlignment = Enum.TextXAlignment.Left
				Text.Parent = DropdownSection

				local Open = Instance.new('TextButton')
				Open.Name = "Open"
				Open.Size = UDim2.new(1, 0, 1, 0)
				Open.BackgroundColor3 = Color3.fromRGB(255, 255, 255)
				Open.BackgroundTransparency = 1
				Open.Text = ""
				Open.ZIndex = 10
				Open.Parent = DropdownSection

				local Section2Frame = Instance.new('Frame')
				Section2Frame.Name = "AccordionFrame"
				Section2Frame.Position = UDim2.new(0.02, 0, 1, 2 / GetMainFrameScale())
				Section2Frame.Size = UDim2.new(0.96, 0, 0, 0)
				Section2Frame.BackgroundColor3 = Color3.fromRGB(18, 18, 25)
				Section2Frame.BackgroundTransparency = 0
				Section2Frame.BorderSizePixel = 0
				Section2Frame.Visible = false
				Section2Frame.ZIndex = 5000
				Section2Frame.ClipsDescendants = false
				Section2Frame.AutomaticSize = Enum.AutomaticSize.None
				local S2Scale = New("UIScale", { Scale = 1 }, Section2Frame)
				Section2Frame.Parent = DropdownSection

				local UICorner = Instance.new('UICorner')
				UICorner.Name = "UICorner"
				UICorner.CornerRadius = UDim.new(0, 14)
				UICorner.Parent = Section2Frame

				local UIStroke = Stroke(Section2Frame, "UIStroke")
				AttachShadow(Section2Frame, { radius = 12, layers = 5, step = 1.6, bias = 3 })

				-- Plate header like the "..." settings plate: title, then the rows.
				local ACC_HEADER = 40
				local ACC_WIDTH = 280
				New("TextLabel", {
					Name = "PlateTitle",
					Position = UDim2.new(0, 16, 0, 13),
					Size = UDim2.new(1, -32, 0, 20),
					BackgroundTransparency = 1,
					Text = text,
					TextColor3 = Color3.fromRGB(226, 227, 233),
					TextSize = 16,
					TextXAlignment = Enum.TextXAlignment.Left,
					TextTruncate = Enum.TextTruncate.AtEnd,
					ZIndex = 5001,
				}, Section2Frame)

				local Container = Instance.new('ScrollingFrame')
				Container.Name = "Container"
				Container.Position = UDim2.new(0.04, 0, 0, ACC_HEADER + 3 / GetMainFrameScale())
				Container.Size = UDim2.new(0.92, 0, 1, -(ACC_HEADER + 10 / GetMainFrameScale()))
				-- Same inner card as the "..." plate: rows grouped, no dividers.
				Container.BackgroundColor3 = Color3.fromRGB(27, 27, 36)
				Container.BackgroundTransparency = 1
				Container.AnchorPoint = Vector2.new(0, 0)
				Container.LayoutOrder = 1
				Container.ZIndex = 5001
				Container.Active = true
				Container.AutomaticCanvasSize = Enum.AutomaticSize.Y
				Container.CanvasSize = UDim2.new()
				Container.ScrollingEnabled = false
				Container.ScrollingDirection = Enum.ScrollingDirection.Y
				Container.ScrollBarThickness = 0
				Container.ScrollBarImageTransparency = 0.5
				Container.ClipsDescendants = true
				Container.Parent = Section2Frame

				local UIListLayout = Instance.new('UIListLayout')
				UIListLayout.Name = "UIListLayout"
				UIListLayout.Padding = UDim.new(0, 3)
				UIListLayout.SortOrder = Enum.SortOrder.LayoutOrder
				UIListLayout.Parent = Container
				do local c = Instance.new("UICorner"); c.CornerRadius = UDim.new(0, 10); c.Parent = Container end
				Stroke(Container, "CardOutline").Transparency = 0.955
				New("UIPadding", { PaddingTop = UDim.new(0, 4), PaddingBottom = UDim.new(0, 4), PaddingLeft = UDim.new(0, 6), PaddingRight = UDim.new(0, 6) }, Container)
				Container.DescendantAdded:Connect(function(d)
					if d.Name == "Lines" and d:IsA("GuiObject") then d.Visible = false end
				end)

				local function GetAccordionContentHeight()
					local measured = MeasureRowsHeight(Container)
					if measured > 0 then return measured end
					local rowCount = 0
					for _, child in ipairs(Container:GetChildren()) do
						if child:IsA("GuiObject") then rowCount = rowCount + 1 end
					end
					if rowCount <= 0 then return 0 end
					local estimated = EstimateRowsHeight(Container, rowCount, 7.5)
					if estimated > 0 then return estimated end
					return rowCount * 28 * GetMainFrameScale()
				end

				local function UpdateAccordionLayout()
					local scale = GetMainFrameScale()
					Container.Position = UDim2.new(0.04, 0, 0, ACC_HEADER + 3 / scale)
					Container.Size = UDim2.new(0.92, 0, 1, -(ACC_HEADER + 10 / scale))
				end

				-- Beside the row, not below it: from the row's middle, top aligned a
				-- little above the row, kept inside the window (same rules as placeSettings).
				local function placeAccordion(height)
					local scale = GetMainFrameScale()
					local rowPosition = DropdownSection.AbsolutePosition
					local rowSize = DropdownSection.AbsoluteSize
					-- Bounded by the screen, not the window: plates may hang outside the menu.
					local mainPosition, mainSize = PopupSafeArea()
					if rowSize.X <= 0 or mainSize.X <= 0 or mainSize.Y <= 0 then return end
					local edge = 5 * scale
					local panelWidth = ACC_WIDTH * scale
					local visualHeight = height * scale
					local x = rowPosition.X + rowSize.X * 0.48
					x = math.clamp(x, mainPosition.X + edge, math.max(mainPosition.X + edge, mainPosition.X + mainSize.X - panelWidth - edge))
					local y = rowPosition.Y - 6 * scale
					y = math.clamp(y, mainPosition.Y + edge, math.max(mainPosition.Y + edge, mainPosition.Y + mainSize.Y - visualHeight - edge))
					Section2Frame.Position = UDim2.new(0, (x - rowPosition.X) / scale, 0, (y - rowPosition.Y) / scale)
				end

				New("Frame", {
					Name = "Lines",
					Position = UDim2.new(0.06, 0, 1, -1),
					Size = UDim2.new(0.88, 0, 0, 1),
					BackgroundColor3 = Color3.fromRGB(162, 162, 162),
					BackgroundTransparency = 0.9,
					ZIndex = 100,
					BorderSizePixel = 0,
				}, DropdownSection)

				local accordionOpen = false
				local accordionLayoutConnection = nil
				local accordionRefitConnection = nil
				local function getAccordionHeight()
					UpdateAccordionLayout()
					local scale = GetMainFrameScale()
					local contentVisual = GetAccordionContentHeight()
					local desiredVisual = math.max((ACC_HEADER + 34) * scale, contentVisual + (ACC_HEADER + 20) * scale)
					local maxVisual = math.max(34 * scale, MainFrame.AbsoluteSize.Y * 0.92)
					return math.min(desiredVisual, maxVisual) / scale
				end

				local function fitAccordionHeight()
					if not accordionOpen or not Section2Frame.Parent then return end
					local height = getAccordionHeight()
					Section2Frame.Size = UDim2.fromOffset(ACC_WIDTH, height)
					placeAccordion(height)
				end

				local function closeAccordion()
					accordionOpen = false
					if _openAccordionDropdown then _openAccordionDropdown() end
					ClosePopupsUnder(Section2Frame)
					UnregisterPopup(Section2Frame)
					SmoothClose(Section2Frame, 0.14)
					Tween(TextArrow, {ImageTransparency = 0.3}, 0.14, Enum.EasingStyle.Quad, Enum.EasingDirection.Out)
					if _openAccordion == closeAccordion then _openAccordion = nil end
				end

				Open.MouseButton1Click:Connect(function()
					if accordionOpen then
						closeAccordion()
					else
						if _openAccordion then _openAccordion() end
						CloseAllPopupsExcept(Section2Frame)
						accordionOpen = true
						_openAccordion = closeAccordion
						-- The plate sits outside the clipping column, like the settings plate.
						RememberPopupClipping(Section2Frame)
						ForceLiftClipping(Section2Frame)
						ApplyZIndexLadder(Section2Frame, NextPopupZ())
						local accordionHeight = getAccordionHeight()
						Section2Frame.Size = UDim2.fromOffset(ACC_WIDTH, accordionHeight)
						placeAccordion(accordionHeight)
						SmoothOpen(Section2Frame, 0, 0.17)
						Tween(TextArrow, {ImageTransparency = 0}, 0.14, Enum.EasingStyle.Quint, Enum.EasingDirection.Out)
						RegisterPopup(Section2Frame, closeAccordion, Open)
						local function settle()
							if not accordionOpen or not Section2Frame.Parent then return end
							fitAccordionHeight()
						end
						task.defer(function()
							if not accordionOpen or not Section2Frame.Parent then return end
							fitAccordionHeight()
							Tween(S2Scale, {Scale = 1}, 0.28, Enum.EasingStyle.Quint, Enum.EasingDirection.Out)
						end)
						task.delay(0.05, settle)
						if not accordionRefitConnection then
							local frames = 0
							accordionRefitConnection = RunService.RenderStepped:Connect(function()
								frames = frames + 1
								if not accordionOpen then
									accordionRefitConnection:Disconnect()
									accordionRefitConnection = nil
									return
								end
								fitAccordionHeight()
								if frames >= 4 then
									accordionRefitConnection:Disconnect()
									accordionRefitConnection = nil
								end
							end)
						end
						if not accordionLayoutConnection then
							local okLayout, layout = pcall(function() return Container:FindFirstChildOfClass("UIListLayout") end)
							if okLayout and layout then
								pcall(function()
									accordionLayoutConnection = layout:GetPropertyChangedSignal("AbsoluteContentSize"):Connect(function()
										task.defer(settle)
									end)
								end)
							end
						end
					end
				end)

				local AccordionObj = {}
				-- Rows go into the plate card; AddGroup starts a new card (see StartPlateGroup).
				local AccordionTarget = Container
				function AccordionObj:AddGroup()
					AccordionTarget = StartPlateGroup(Container)
					return self
				end
				local accordionElemCount = 0

				function AccordionObj:AddToggle(text2, default, callback)
					accordionElemCount = accordionElemCount + 1
					local enabled = default == true

					local Toggle = New("Frame", {
						Name = "Toggle",
						Size = UDim2.new(1, 0, 0, 34),
						BackgroundColor3 = Color3.fromRGB(162, 162, 162),
						BackgroundTransparency = 1,
						LayoutOrder = accordionElemCount,
					}, AccordionTarget)

New("Frame", {
						Name = "Lines",
						Position = UDim2.new(0.06, 0, 1, -1),
						Size = UDim2.new(0.88, 0, 0, 1),
						BackgroundColor3 = Color3.fromRGB(162, 162, 162),
						BackgroundTransparency = 0.9,
						ZIndex = 100,
						BorderSizePixel = 0,
					}, Toggle)

					New("TextLabel", {
						Name = "TextToggle",
						Position = UDim2.fromOffset(15, 0),
						Size = UDim2.new(0.7600000262260437, 0, 0.6000000238418579, 0),
						BackgroundColor3 = Color3.fromRGB(28,32,48),
						BackgroundTransparency = 1,
						Text = text2,
						TextColor3 = Color3.fromRGB(217, 219, 226),
						TextScaled = false,
						Font = FONT,
						TextTransparency = 0.10000000149011612,
						TextXAlignment = Enum.TextXAlignment.Left,
						ZIndex = 101,
					}, Toggle)

					local Effect = New("Frame", {
						Name = "Effect",
						Position = UDim2.new(1, -14, 0.5, 0),
						AnchorPoint = Vector2.new(1, 0.5),
						Size = UDim2.fromOffset(33, 20),
						BackgroundColor3 = enabled and mainColor or Color3.fromRGB(8, 10, 16),
						ZIndex = 101,
					}, Toggle)
					New("UICorner", { CornerRadius = UDim.new(1, 0) }, Effect)

					local Icon = New("Frame", {
						Name = "Icon",
						Position = enabled and UDim2.fromOffset(15, 2) or UDim2.fromOffset(2, 2),
						Size = UDim2.fromOffset(16, 16),
						BackgroundColor3 = enabled and Color3.fromRGB(255, 255, 255) or Color3.fromRGB(139, 145, 157),
						BackgroundTransparency = 0,
						ZIndex = 102,
					}, Effect)
					New("UICorner", { CornerRadius = UDim.new(1, 0) }, Icon)
					New("UIAspectRatioConstraint", {}, Icon)

					local Btn = New("TextButton", {
						Size = UDim2.new(1, 0, 1, 0),
						BackgroundTransparency = 1,
						Text = "",
						ZIndex = 110,
					}, Toggle)


					local function Set(val)
						enabled = val == true
						Tween(Effect, { BackgroundColor3 = enabled and mainColor or Color3.fromRGB(8, 10, 16) }, 0.16, Enum.EasingStyle.Sine)
						Tween(Icon, { Position = enabled and UDim2.fromOffset(15, 2) or UDim2.fromOffset(2, 2), BackgroundColor3 = enabled and Color3.fromRGB(255, 255, 255) or Color3.fromRGB(139, 145, 157), BackgroundTransparency = 0 }, 0.16, Enum.EasingStyle.Quad)
						InvokeCallback(callback, enabled)
					end

					Btn.MouseButton1Click:Connect(function() Set(not enabled) end)

					local obj = {}
					function obj:Set(v) Set(v) end
				function obj:Get() return enabled end
				function obj:AddSettings() return MakeSettings(Toggle, nil, text2) end
				RegisterConfigElement("accordion_toggle_", text2, obj)
				CenterElement(Toggle)
				BindElementContext(Toggle, "accordion_toggle", text2, obj, default)
					return obj
				end

				function AccordionObj:AddCheckbox(text2, default, callback)
					accordionElemCount = accordionElemCount + 1
					local enabled = default == true

					local CheckBoxToggle = New("Frame", {
						Name = "CheckBoxToggle",
						Size = UDim2.new(1, 0, 0, 34),
						BackgroundColor3 = Color3.fromRGB(162, 162, 162),
						BackgroundTransparency = 1,
						LayoutOrder = accordionElemCount,
					}, AccordionTarget)
					local CheckBox = New("Frame", {
						Name = "CheckBox",
						Position = UDim2.new(0.04, 0, 0.3, 0),
						Size = UDim2.new(0.075, 0, 0.7, 0),
						BackgroundTransparency = 1,
						ZIndex = 101,
					}, CheckBoxToggle)
					New("UICorner", {}, CheckBox)
					New("UIAspectRatioConstraint", {}, CheckBox)

					local Check = New("ImageLabel", {
						Name = "Check",
						Size = UDim2.new(1, 0, 1, 0),
						BackgroundTransparency = 1,
						Image = "rbxassetid://138494545053627",
						ImageTransparency = enabled and 0.1 or 1,
						ZIndex = 101,
					}, CheckBox)

					New("TextLabel", {
						Name = "TextToggle",
						Position = UDim2.new(0.15, 0, 0.30000001192092896, 0),
						Size = UDim2.new(0.7600000262260437, 0, 0.6000000238418579, 0),
						BackgroundColor3 = Color3.fromRGB(28,32,48),
						BackgroundTransparency = 1,
						Text = text2,
						TextColor3 = Color3.fromRGB(255, 255, 255),
						TextScaled = false,
						Font = FONT,
						TextTransparency = 0.10000000149011612,
						TextXAlignment = Enum.TextXAlignment.Left,
						ZIndex = 101,
					}, CheckBoxToggle)

					local Btn = New("TextButton", {
						Size = UDim2.new(1, 0, 1, 0),
						BackgroundTransparency = 1,
						Text = "",
						ZIndex = 110,
					}, CheckBoxToggle)


					local function Set(val)
						enabled = val == true
						Tween(Check, { ImageTransparency = enabled and 0.1 or 1 }, 0.2)
						InvokeCallback(callback, enabled)
					end

					Btn.MouseButton1Click:Connect(function() Set(not enabled) end)

					local obj = {}
					function obj:Set(v) Set(v) end
				function obj:Get() return enabled end
				function obj:AddSettings() return MakeSettings(CheckBoxToggle, nil, text2) end
				RegisterConfigElement("accordion_checkbox_", text2, obj)
				CenterElement(CheckBoxToggle)
				BindElementContext(CheckBoxToggle, "accordion_checkbox", text2, obj, default)
					return obj
				end

				function AccordionObj:AddDropdown(text2, options, default, callback)
					if type(default) == "function" then
						callback = default
						default = nil
					end
					options = NormalizeOptions(options)
					accordionElemCount = accordionElemCount + 1
					local selected = GetValidOption(options, default)
					local dropOpen = false
					local selectedBtns = {}

					local Selection = New("Frame", {
						Name = "Selection",
						Size = UDim2.new(1, 0, 0, 34),
						BackgroundColor3 = Color3.fromRGB(162, 162, 162),
						BackgroundTransparency = 1,
						LayoutOrder = accordionElemCount,
						ClipsDescendants = false,
						ZIndex = 100,
					}, AccordionTarget)
					New("Frame", {
						Name = "Lines",
						Position = UDim2.new(0.05000000074505806, 0, 1, 0),
						Size = UDim2.new(0.8999999761581421, 0, 0, 1),
						BackgroundColor3 = Color3.fromRGB(162, 162, 162),
						BackgroundTransparency = 0.9,
						BorderSizePixel = 0,
						ZIndex = 100,
					}, Selection)

					New("TextLabel", {
						Name = "TextToggle",
						Position = UDim2.new(0.04800000041723251, 0, 0.30000001192092896, 0),
						Size = UDim2.new(0.6000000238418579, 0, 0.6000000238418579, 0),
						BackgroundColor3 = Color3.fromRGB(28,32,48),
						BackgroundTransparency = 1,
						Text = text2,
						TextColor3 = Color3.fromRGB(217, 219, 226),
						TextScaled = false,
						Font = FONT,
						TextTransparency = 0.10000000149011612,
						TextXAlignment = Enum.TextXAlignment.Left,
						ZIndex = 101,
					}, Selection)

					local SelArrow = New("ImageLabel", {
						Name = "TextArrow",
						AnchorPoint = Vector2.new(1, 0.5),
						Position = UDim2.new(1, -12, 0.5, 0),
						Size = UDim2.fromOffset(10, 10),
						BackgroundColor3 = Color3.fromRGB(28,32,48),
						BackgroundTransparency = 1,
						Image = "rbxassetid://10709790948",
						ImageColor3 = Color3.fromRGB(255, 255, 255),
						ImageTransparency = 0.10000000149011612,
						ScaleType = Enum.ScaleType.Fit,
						Rotation = 0,
						ZIndex = 1000,
					}, Selection)

					local TextDefault = New("TextLabel", {
						Name = "TextDefault",
						Position = UDim2.new(0.60, 0, 0.25, 0),
						Size = UDim2.new(0.29, 0, 0.6, 0),
						TextTruncate = Enum.TextTruncate.AtEnd,
						BackgroundColor3 = Color3.fromRGB(28,32,48),
						BackgroundTransparency = 1,
						Text = options[1] or "Auto",
						TextColor3 = Color3.fromRGB(255, 255, 255),
						TextScaled = false,
						Font = FONT,
						TextTransparency = 0,
						TextTruncate = Enum.TextTruncate.AtEnd,
						TextSize = 14,
						ZIndex = 101,
						TextXAlignment = Enum.TextXAlignment.Left,
					}, Selection)

					local DropPopup = New("Frame", {
						Name = "Dropdown",
						Position = UDim2.new(0.60, 0, 1, 4),
						Size = UDim2.fromOffset(150, 0),
						BackgroundColor3 = Color3.fromRGB(17, 19, 28),
						BackgroundTransparency = 0,
						BorderSizePixel = 0,
						Visible = false,
						ZIndex = 5000,
					}, Selection)
					New("UICorner", { CornerRadius = UDim.new(0, 10) }, DropPopup)
					do Stroke(DropPopup) end

					
					local DropContainer = New("ScrollingFrame", {
						Name = "Container",
						Position = UDim2.fromOffset(6, 6),
						Size = UDim2.new(1, -12, 1, -12),
						BackgroundColor3 = Color3.fromRGB(162, 162, 162),
						BackgroundTransparency = 1,
						ZIndex = 5000,
						Active = true,
						AutomaticCanvasSize = Enum.AutomaticSize.Y,
						CanvasSize = UDim2.new(),
						ScrollingDirection = Enum.ScrollingDirection.Y,
						ScrollBarThickness = 2,
						ScrollBarImageTransparency = 0.5,
					}, DropPopup)
					New("UIListLayout", { SortOrder = Enum.SortOrder.LayoutOrder, Padding = UDim.new(0, 2) }, DropContainer)

					local function closeDropdown2()
						dropOpen = false
						Tween(SelArrow, { Rotation = -90 }, 0.16, Enum.EasingStyle.Sine, Enum.EasingDirection.Out)
						UnregisterPopup(DropPopup)
						SmoothClose(DropPopup, 0.18)
						if _openAccordionDropdown == closeDropdown2 then _openAccordionDropdown = nil end
					end

					local function updateCheckmarks()
						for opt, selBtn in pairs(selectedBtns) do
							local isSelected = opt == selected
							selBtn.Visible = isSelected
							selBtn.ImageColor3 = mainColor
							local row = selBtn.Parent
							if row then
								row.BackgroundTransparency = 1
								local label = row:FindFirstChild("Label") or row:FindFirstChildWhichIsA("TextLabel")
								if label then label.TextColor3 = isSelected and Color3.fromRGB(228, 228, 229) or Color3.fromRGB(175, 175, 180) end
							end
						end
					end

						for i, opt in ipairs(options) do
							local BtnRow = New("Frame", {
								Name = "Buttons",
								Size = UDim2.new(1, 0, 0, 28),
								BackgroundColor3 = Color3.fromRGB(255, 255, 255),
								BackgroundTransparency = 1,
								ZIndex = 1001,
								LayoutOrder = i,
							}, DropContainer)
							New("UICorner", { CornerRadius = UDim.new(0, 6) }, BtnRow)

							local Label = New("TextLabel", {
								Name = "Label",
								Position = UDim2.new(0, 28, 0, 0),
								Size = UDim2.new(1, -36, 1, 0),
								BackgroundColor3 = Color3.fromRGB(162, 162, 162),
								BackgroundTransparency = 1,
								Text = opt,
								TextColor3 = Color3.fromRGB(200, 204, 218),
								TextScaled = false,
								TextSize = 14,
								Font = FONT,
								TextTruncate = Enum.TextTruncate.AtEnd,
								TextTransparency = 0,
								ZIndex = 1002,
								TextXAlignment = Enum.TextXAlignment.Left,
							}, BtnRow)

							local SelBtn = New("ImageButton", {
						Name = "Selected",
						AnchorPoint = Vector2.new(0, 0.5),
						Position = UDim2.new(0, 4, 0.5, 0),
						Size = UDim2.fromOffset(14, 14),
						BackgroundTransparency = 1,
						BorderSizePixel = 0,
						Image = "rbxassetid://138494545053627",
						ImageColor3 = mainColor,
						Visible = false,
						ZIndex = 1006,
					}, BtnRow)
					selectedBtns[opt] = SelBtn

							local RowBtn = New("TextButton", {
								Size = UDim2.new(1, 0, 1, 0),
								BackgroundTransparency = 1,
								Text = "",
								ZIndex = 1005,
							}, BtnRow)
							RowBtn.MouseEnter:Connect(function()
								Tween(BtnRow, { BackgroundTransparency = 0.97 }, 0.08)
							end)
							RowBtn.MouseLeave:Connect(function()
								Tween(BtnRow, { BackgroundTransparency = 1 }, 0.12)
							end)
						RowBtn.MouseButton1Click:Connect(function()
							selected = opt
							TextDefault.Text = opt; 
							updateCheckmarks()
							closeDropdown2()
							InvokeCallback(callback, opt)
						end)
						SelBtn.MouseButton1Click:Connect(function()
							selected = opt
							TextDefault.Text = opt; 
							updateCheckmarks()
							closeDropdown2()
							InvokeCallback(callback, opt)
						end)
					end

					local OpenBtn = New("TextButton", {
						Name = "OpenBtn",
						Size = UDim2.new(1, 0, 1, 0),
						BackgroundTransparency = 1,
						Text = "",
						ZIndex = 500,
					}, Selection)

					OpenBtn.MouseButton1Click:Connect(function()
						if dropOpen then
							closeDropdown2()
						else
							CloseAllPopupsExcept(DropPopup)
							if _openAccordionDropdown then _openAccordionDropdown() end
							dropOpen = true
							_openAccordionDropdown = closeDropdown2
							local knownH = math.min(#options, 8) * 30 + 10
							local knownW = math.max(TextDefault.AbsoluteSize.X, 150)
							DropPopup.Size = UDim2.fromOffset(knownW, knownH)
							DropPopup.BackgroundTransparency = 0
							DropPopup.Visible = false
							ApplyZIndexLadder(DropPopup, NextPopupZ())
							DropPopup.Visible = true
							WindowObj._centerPopupOnField(DropPopup, TextDefault)
							SmoothOpen(DropPopup, 0, 0.14)
							RegisterPopup(DropPopup, closeDropdown2, OpenBtn)
						end
					end)

					local obj = {}
					function obj:Set(val, silent)
						val = GetValidOption(options, val)
						selected = val
						TextDefault.Text = val; 
						updateCheckmarks()
						if not silent then InvokeCallback(callback, val) end
					end
					function obj:Get() return selected end
					function obj:AddSettings() return MakeSettings(Selection, "dropdown", text2) end
				if default ~= nil then obj:Set(GetValidOption(options, default), true) end
					RegisterConfigElement("accordion_dropdown_", text2, obj)
					CenterElement(Selection)
				BindElementContext(Selection, "accordion_dropdown", text2, obj, selected, options)
					return obj
				end

				function AccordionObj:AddSlider(text2, min, max, default, callback, suffix)
					accordionElemCount = accordionElemCount + 1
					if type(suffix) ~= "string" then suffix = "" end
					local value
					min, max, value = NormalizeRange(min, max, default)
					value = Quantize(value, min, max, GetSliderStep(min, max))
					local initRatio = (value - min) / (max - min)
					local dragging = false

					local Slider = New("Frame", {
						Name = "Slider",
						Size = UDim2.new(1, 0, 0, 39),
						BackgroundColor3 = Color3.fromRGB(162, 162, 162),
						BackgroundTransparency = 1,
						LayoutOrder = accordionElemCount,
						ZIndex = 100,
					}, AccordionTarget)

New("Frame", {
						Name = "Lines",
						Position = UDim2.new(0.06, 0, 1, -1),
						Size = UDim2.new(0.88, 0, 0, 1),
						BackgroundColor3 = Color3.fromRGB(162, 162, 162),
						BackgroundTransparency = 0.9,
						ZIndex = 1002,
						BorderSizePixel = 0,
					}, Slider)

					New("TextLabel", {
						Name = "TextToggle",
						Position = UDim2.fromOffset(15, 0),
						Size = UDim2.new(0.7600000262260437, 0, 0.6000000238418579, 0),
						BackgroundColor3 = Color3.fromRGB(28,32,48),
						BackgroundTransparency = 1,
						Text = text2,
						TextColor3 = Color3.fromRGB(217, 219, 226),
						TextScaled = false,
						Font = FONT,
						TextTransparency = 0.10000000149011612,
						TextXAlignment = Enum.TextXAlignment.Left,
						ZIndex = 101,
					}, Slider)

					local Effect = New("Frame", {
						Name = "Effect",
						Position = UDim2.new(0.4980000042915344, 0, 0.25, 0),
						Size = UDim2.new(0.5, 0, 0.6990000009536743, 0),
						BackgroundColor3 = Color3.fromRGB(255, 255, 255),
						BackgroundTransparency = 1,
						ZIndex = 101,
					}, Slider)

					local SliderValue = New("TextLabel", {
						Name = "SliderValue",
						Position = UDim2.new(0.6990000009536743, 0, 0.10000000149011612, 0),
						Size = UDim2.new(0.25, 0, 0.8080000281333923, 0),
						BackgroundColor3 = Color3.fromRGB(33,37,53),
						Text = FormatSliderValue(value, suffix),
						TextColor3 = Color3.fromRGB(255, 255, 255),
						TextScaled = false,
						Font = FONT,
						TextTransparency = 0.20000000298023224,
						ZIndex = 102,
					}, Effect)
					New("UICorner", { CornerRadius = UDim.new(0, 5) }, SliderValue)

					local Line = New("Frame", {
						Name = "Line",
						Active = true,
						Position = UDim2.new(0.03999999910593033, 0, 0.3190000057220459, 0),
						Size = UDim2.new(0.6000000238418579, 0, 0.24, 0),
						BackgroundColor3 = Color3.fromRGB(33,37,53),
						ZIndex = 101,
					}, Effect)
					New("UICorner", { CornerRadius = UDim.new(1, 0) }, Line)

					local InLine = New("Frame", {
						Name = "InLine",
						Size = UDim2.new(0, 0, 1, 0),
						BackgroundColor3 = mainColor,
						ZIndex = 102,
					}, Line)
					New("UICorner", { CornerRadius = UDim.new(1, 0) }, InLine)
					SizeSliderChip(Effect, Line, SliderValue)

					local Trigger = New("TextButton", {
						Name = "Trigger",
						Position = UDim2.new(0.10000000149011612, 0, -1.8000000715255737, 0),
						Size = UDim2.new(1.1999999284744263, 0, 4.200000286102295, 0),
						AnchorPoint = Vector2.new(0.800000011920929, 0),
						BackgroundColor3 = Color3.fromRGB(255, 255, 255),
                     BackgroundTransparency = 1,
						Active = false,
						Text = "",
						ZIndex = 103,
					}, Line)
					New("UICorner", { CornerRadius = UDim.new(1, 0) }, Trigger)
					New("UIAspectRatioConstraint", {}, Trigger)
					local Thumb = New("Frame", {
						Name = "Thumb",
						AnchorPoint = Vector2.new(0.5, 0.5),
						Position = UDim2.new(initRatio, 0, 0.5, 0),
						Size = UDim2.fromOffset(12, 12),
						BackgroundColor3 = Color3.fromRGB(255, 255, 255),
						BorderSizePixel = 0,
						ZIndex = Line.ZIndex + 3,
					}, Line)
					New("UICorner", { CornerRadius = UDim.new(1, 0) }, Thumb)
					Stroke(Thumb)
					Line.MouseEnter:Connect(function()
						Tween(Thumb, { Size = UDim2.fromOffset(14, 14) }, 0.11, Enum.EasingStyle.Sine, Enum.EasingDirection.Out)
					end)
					Line.MouseLeave:Connect(function()
						Tween(Thumb, { Size = UDim2.fromOffset(12, 12) }, 0.13, Enum.EasingStyle.Sine, Enum.EasingDirection.Out)
					end)
					local initialValue = value
					task.defer(function()
						if value ~= initialValue then return end
						InLine.Size = UDim2.fromScale(initRatio, 1)
						Thumb.Position = UDim2.new(initRatio, 0, 0.5, 0)
						Trigger.Position = UDim2.new(initRatio, 0, -1.8000000715255737, 0)
					end)

					local function update(input)
						local pointer = GetInputPosition(input)
						local lineSize = Line.AbsoluteSize.X
						if lineSize <= 0 then return end
						local sizeScale = ClampRatio(pointer.X - Line.AbsolutePosition.X, lineSize)
						local nextValue = Quantize(((max - min) * sizeScale) + min, min, max, GetSliderStep(min, max))
						local changed = nextValue ~= value
						value = nextValue
						local span = max - min
						local snappedRatio = span ~= 0 and math.clamp((value - min) / span, 0, 1) or 0
						InLine.Size = UDim2.fromScale(snappedRatio, 1)
						Trigger.Position = UDim2.new(snappedRatio, 0, -1.8000000715255737, 0)
						Thumb.Position = UDim2.new(snappedRatio, 0, 0.5, 0)
						SliderValue.Text = FormatSliderValue(value, suffix)
						if changed then InvokeCallback(callback, value) end
					end

					Line.InputBegan:Connect(function(input)
						if IsPrimaryInput(input) then
							dragging = true; update(input)
						end
					end)
					UserInputService.InputEnded:Connect(function(input)
						if IsPrimaryInput(input) then
							dragging = false
						end
					end)
					UserInputService.InputChanged:Connect(function(input)
						if dragging and (input.UserInputType == Enum.UserInputType.MouseMovement or input.UserInputType == Enum.UserInputType.Touch) then
							update(input)
						end
					end)

					local obj = {}
					function obj:Set(val)
						local numeric = type(val) == "number" and val == val and val or min
						value = math.clamp(numeric, min, max)
						value = Quantize(value, min, max, GetSliderStep(min, max))
					local span = max - min
					local ratio = span ~= 0 and math.clamp((value - min) / span, 0, 1) or 0
						Tween(InLine, { Size = UDim2.fromScale(ratio, 1) }, 0.14, Enum.EasingStyle.Sine, Enum.EasingDirection.Out)
						Trigger.Position = UDim2.new(ratio, 0, -1.8000000715255737, 0)
						Tween(Thumb, { Position = UDim2.new(ratio, 0, 0.5, 0) }, 0.14, Enum.EasingStyle.Sine, Enum.EasingDirection.Out)
						SliderValue.Text = FormatSliderValue(value, suffix)
						InvokeCallback(callback, value)
					end
				function obj:Get() return value end
				function obj:AddSettings() return MakeSettings(Slider, "slider", text2) end
				RegisterConfigElement("accordion_slider_", text2, obj)
				CenterElement(Slider)
				BindElementContext(Slider, "accordion_slider", text2, obj, value, nil, min, max)
					return obj
				end

				function AccordionObj:AddColorpicker(text2, defaultColor, callback)
					accordionElemCount = accordionElemCount + 1
					local initialColor = NormalizeColor(defaultColor)
					local Colorpicker = New("Frame", {
						Name = "Colorpicker",
						Size = UDim2.new(1, 0, 0, 34),
						BackgroundTransparency = 1,
						BorderSizePixel = 0,
						LayoutOrder = accordionElemCount,
						ClipsDescendants = false,
						ZIndex = 100,
					}, AccordionTarget)
					New("Frame", {
						Name = "Lines",
						Position = UDim2.new(0.06, 0, 1, -1),
						Size = UDim2.new(0.89, 0, 0, 1),
						BackgroundColor3 = Color3.fromRGB(162, 162, 162),
						BackgroundTransparency = 0.9,
						BorderSizePixel = 0,
						ZIndex = 101,
					}, Colorpicker)
					New("TextLabel", {
						Name = "TextToggle",
						Position = UDim2.fromOffset(15, 0),
						Size = UDim2.new(0.66, 0, 1, 0),
						BackgroundTransparency = 1,
						Text = text2,
						TextColor3 = Color3.fromRGB(217, 219, 226),
						TextScaled = false,
						TextSize = 14,
						Font = FONT,
						TextTransparency = 0.1,
						TextXAlignment = Enum.TextXAlignment.Left,
						ZIndex = 101,
					}, Colorpicker)
					local colorpickerButton = New("ImageButton", {
						Name = "colorpickerButton",
						AnchorPoint = Vector2.new(1, 0.5),
						Position = UDim2.new(1, -14, 0.5, 0),
						Size = UDim2.fromOffset(20, 20),
						BackgroundColor3 = initialColor,
						BorderSizePixel = 0,
						Image = "",
						ZIndex = 110,
					}, Colorpicker)
					New("UICorner", { CornerRadius = UDim.new(0, 5) }, colorpickerButton)
					Stroke(colorpickerButton, "ColorpickerButtonStroke")
					local picker = AcrylicBlur.CreateColorPicker(colorpickerButton, initialColor, function(c)
						InvokeCallback(callback, c)
					end)
					local obj = {}
					function obj:Set(c)
						local normalized = NormalizeColor(c)
						picker.Set(normalized)
						InvokeCallback(callback, normalized)
					end
					function obj:Get() return picker.Get() end
					function obj:AddSettings() return MakeSettings(Colorpicker, nil, text2) end
					RegisterConfigElement("accordion_colorpicker_", text2, obj)
					CenterElement(Colorpicker)
					BindElementContext(Colorpicker, "accordion_colorpicker", text2, obj, initialColor)
					return obj
				end

				MakeReadableText(Section2Frame, 10, 18)
				return AccordionObj
			end

			MakeReadableText(Section, 10, 18)
			return SectionObj
		end

		local subTabs = {}
		local activeSubTabIndex = nil
		local subTabContainer = nil
		tabs[tabIndex].subTabs = subTabs

		local function EnsureSubTabContainer()
			if subTabContainer then return end

			tabOrder = tabOrder + 0.5
			subTabContainer = New("Frame", {
				Name = "SubTabContainer",
				Size = UDim2.new(1, 0, 0, 20),
				BackgroundTransparency = 1,
            AutomaticSize = Enum.AutomaticSize.Y,
				Visible = false,
				LayoutOrder = TabButtonFrame.LayoutOrder + 1,
			}, Tab)
			subTabContainer:SetAttribute("TabIndex", tabIndex)
			New("UIListLayout", {
				Padding = UDim.new(0, 4),
				SortOrder = Enum.SortOrder.LayoutOrder,
				HorizontalAlignment = Enum.HorizontalAlignment.Right,
			}, subTabContainer)

			local origHide = HideContent
			local origShow = ShowContent

			HideContent = function()
				origHide()
				subTabContainer.Visible = false
				for _, st in ipairs(subTabs) do
					st.left.Visible = false
					st.right.Visible = false
				end
			end

			ShowContent = function()
				Left.Visible = false
				Right.Visible = false
				subTabContainer.Visible = true
				-- Do not fade the parent tab back to its inactive state here.
				-- ActivateTab() has just selected it; running the opposite tweens
				-- in the same frame caused a visible flash on every tab switch.
				if activeTabIndex == tabIndex then
					-- With sub-tabs, Neverlose highlights the sub-tab, not the parent.
					Tween(TabButtonFrame, {
						BackgroundColor3 = Color3.fromRGB(35, 38, 50),
						BackgroundTransparency = 1,
					}, 0.12, Enum.EasingStyle.Quint, Enum.EasingDirection.Out)
					Tween(TabIcon, { ImageColor3 = mainColor, ImageTransparency = 0 }, 0.11, Enum.EasingStyle.Sine, Enum.EasingDirection.Out)
					Tween(TabText, { TextTransparency = 0 }, 0.11, Enum.EasingStyle.Sine, Enum.EasingDirection.Out)
				end
				for i, st in ipairs(subTabs) do
					if st.scale then
						local delay = math.min((i - 1) * 0.04, 0.3)
						task.delay(delay, function()
							if not subTabContainer.Visible then return end
							st.scale.Scale = 0.985
							Tween(st.scale, { Scale = 1 }, 0.13, Enum.EasingStyle.Quint, Enum.EasingDirection.Out)
						end)
					end
				end
				if activeSubTabIndex then
					local st = subTabs[activeSubTabIndex]
					if st then
					st.left.Position  = UDim2.new(0, 0, 0, 0)
					st.right.Position = UDim2.new(0, 0, 0, 0)
					st.left.Visible  = true
					st.right.Visible = true
					AnimateSectionColumn(st.left)
					AnimateSectionColumn(st.right)
					if WindowObj._fadeColumn then WindowObj._fadeColumn(st.left); WindowObj._fadeColumn(st.right) end
					end
				elseif #subTabs > 0 then
					subTabs[1].activate()
				end
			end

			tabs[tabIndex].hide = HideContent
			tabs[tabIndex].show = ShowContent

		end

		function TabObj:AddSubTab(name, icon)
			name = tostring(name or "Subtab")
			if icon ~= nil and type(icon) ~= "string" then icon = "" end
			EnsureSubTabContainer()

			local stIndex = #subTabs + 1
			local isFirstST = stIndex == 1

			local stLeft = New("ScrollingFrame", {
				Name = "STLeft_" .. name,
				Size = UDim2.new(0.49, 0, 1, 0),
				BackgroundTransparency = 1,
				Visible = false,
				ClipsDescendants = true,
				Active = true,
				AutomaticCanvasSize = Enum.AutomaticSize.Y,
				CanvasSize = UDim2.new(),
				ScrollingDirection = Enum.ScrollingDirection.Y,
				ScrollBarThickness = 0,
			}, SubTabHose)
			New("UIListLayout", { Padding = UDim.new(0, 14), SortOrder = Enum.SortOrder.LayoutOrder }, stLeft)

			local stRight = New("ScrollingFrame", {
				Name = "STRight_" .. name,
				Size = UDim2.new(0.49, 0, 1, 0),
				BackgroundTransparency = 1,
				LayoutOrder = 1,
				Visible = false,
				ClipsDescendants = true,
				Active = true,
				AutomaticCanvasSize = Enum.AutomaticSize.Y,
				CanvasSize = UDim2.new(),
				ScrollingDirection = Enum.ScrollingDirection.Y,
				ScrollBarThickness = 0,
			}, SubTabHose)
			stLeft:SetAttribute("SearchName", name)
			stRight:SetAttribute("SearchName", name)
			stLeft:SetAttribute("TabIndex", tabIndex)
			stRight:SetAttribute("TabIndex", tabIndex)
			stLeft:SetAttribute("SubTabIndex", stIndex)
			stRight:SetAttribute("SubTabIndex", stIndex)
			New("UIPadding", { PaddingLeft = UDim.new(0, 2), PaddingRight = UDim.new(0, 2), PaddingTop = UDim.new(0, 0), PaddingBottom = UDim.new(0, 12) }, stLeft)
			New("UIPadding", { PaddingLeft = UDim.new(0, 2), PaddingRight = UDim.new(0, 2), PaddingTop = UDim.new(0, 0), PaddingBottom = UDim.new(0, 12) }, stRight)
			New("UIListLayout", { Padding = UDim.new(0, 14), SortOrder = Enum.SortOrder.LayoutOrder }, stRight)

			local STRow = New("Frame", {
				Name = "STRow_" .. name,
				Size = UDim2.new(0.92, 0, 1, 0),
				-- Sub-tabs use the same plate, grey idle text/icon and accent icon as
				-- the main tabs (Neverlose "Players / World"), not a side bar.
				BackgroundColor3 = Color3.fromRGB(35, 38, 50),
				BackgroundTransparency = isFirstST and 0.08 or 1,
				LayoutOrder = stIndex,
			}, subTabContainer)
			STRow:SetAttribute("TabIndex", tabIndex)
			STRow:SetAttribute("SubTabIndex", stIndex)
			New("UICorner", { CornerRadius = UDim.new(0, 8) }, STRow)
			New("UIAspectRatioConstraint", {
				AspectRatio = 4.6,
				AspectType = Enum.AspectType.ScaleWithParentSize,
			}, STRow)
			local STScale = New("UIScale", { Scale = 1 }, STRow)
			local STIndicator = New("Frame", {
				Name = "SelectedIndicator",
				AnchorPoint = Vector2.new(0, 0.5),
				Position = UDim2.new(0, 0, 0.5, 0),
				Size = UDim2.new(0, 2, 0.58, 0),
				BackgroundColor3 = mainColor,
				BackgroundTransparency = 1,
				BorderSizePixel = 0,
				Visible = false,
				ZIndex = 3,
			}, STRow)
			New("UICorner", { CornerRadius = UDim.new(1, 0) }, STIndicator)

			local iconRef = nil
			if icon and icon ~= "" then
				iconRef = New("ImageLabel", {
					Name = "STIcon",
					Position = UDim2.new(0.1, 0, 0.5, 0),
					AnchorPoint = Vector2.new(0.5, 0.5),
					Size = UDim2.new(0.20000000298023224, 0, 0.6500000011920929, 0),
					BackgroundTransparency = 1,
					ImageColor3 = isFirstST and mainColor or Color3.fromRGB(150, 155, 172),
					ImageTransparency = 0,
				}, STRow)
				New("UIAspectRatioConstraint", { AspectRatio = 1 }, iconRef)
				GetImageData(icon, iconRef)
				WindowObj._drawTabGlyph(icon, iconRef)
			end

			local STLabel = New("TextLabel", {
				Name = "STLabel",
				Position = UDim2.new(0.23000000417232513, 0, 0.235, 0),
				Size = UDim2.new(0.7070000171661377, 0, 0.510000011920929, 0),
				BackgroundTransparency = 1,
				Text = name,
				TextColor3 = isFirstST and Color3.fromRGB(255, 255, 255) or Color3.fromRGB(150, 155, 172),
				TextScaled = false,
				Font = FONT,
				TextTransparency = 0,
				TextXAlignment = Enum.TextXAlignment.Left,
			}, STRow)

			local STClick = New("TextButton", {
				Size = UDim2.new(1, 0, 1, 0),
				BackgroundTransparency = 1,
				Text = "",
				ZIndex = 5,
			}, STRow)

			local function ActivateSubTab()
				CloseAllPopupsExcept(nil)
				for _, st in ipairs(subTabs) do
					Tween(st.row, { BackgroundTransparency = 1 }, 0.12, Enum.EasingStyle.Quad, Enum.EasingDirection.Out)
					if st.row ~= STRow then
						Tween(st.lbl, { TextColor3 = Color3.fromRGB(150, 155, 172), TextTransparency = 0 }, 0.10, Enum.EasingStyle.Sine, Enum.EasingDirection.Out)
					end
					if st.icon then
						Tween(st.icon, { ImageColor3 = Color3.fromRGB(150, 155, 172), ImageTransparency = 0 }, 0.10, Enum.EasingStyle.Sine, Enum.EasingDirection.Out)
					end
					st.left.Visible  = false
					st.right.Visible = false
				end
				Tween(STRow, { BackgroundTransparency = 0.08 }, 0.13, Enum.EasingStyle.Quint, Enum.EasingDirection.Out)
				Tween(STLabel, { TextColor3 = Color3.fromRGB(255, 255, 255), TextTransparency = 0 }, 0.10, Enum.EasingStyle.Sine, Enum.EasingDirection.Out)
				if iconRef then
					Tween(iconRef, { ImageColor3 = mainColor, ImageTransparency = 0 }, 0.10, Enum.EasingStyle.Sine, Enum.EasingDirection.Out)
				end
				STScale.Scale = 0.985
				Tween(STScale, { Scale = 1 }, 0.13, Enum.EasingStyle.Quint, Enum.EasingDirection.Out)

				for otherIndex, other in ipairs(subTabs) do
					local rank = otherIndex == stIndex and 0 or 100 + otherIndex
					other.left.LayoutOrder  = rank
					other.right.LayoutOrder = rank
				end
				stLeft.Visible  = true
				stRight.Visible = true
				AnimateSectionColumn(stLeft)
				AnimateSectionColumn(stRight)
				if WindowObj._fadeColumn then WindowObj._fadeColumn(stLeft); WindowObj._fadeColumn(stRight) end

				activeSubTabIndex = stIndex
				if tabs[tabIndex] then
					tabs[tabIndex].activeSubTabIndex = stIndex
					tabs[tabIndex].activeSubTabName = name
				end
				GlobalPreset.Visible = ShouldShowGlobalPreset(tabs[tabIndex] and tabs[tabIndex].name or "")
				if ApplySearch then task.defer(function() ApplySearch(SearchBox.Text) end) end
			end

			table.insert(subTabs, {
				row  = STRow,
				lbl  = STLabel,
				indicator = STIndicator,
				icon = iconRef,
				scale = STScale,
				left = stLeft,
				right = stRight,
				activate = ActivateSubTab,
				index = stIndex,
				name = name,
			})

			STClick.MouseButton1Click:Connect(ActivateSubTab)
			STRow.MouseEnter:Connect(function()
				if activeSubTabIndex == stIndex then return end
				Tween(STRow, { BackgroundTransparency = 0.8 }, 0.11, Enum.EasingStyle.Sine)
			end)
			STRow.MouseLeave:Connect(function()
				if activeSubTabIndex == stIndex then return end
				Tween(STRow, { BackgroundTransparency = 1 }, 0.14, Enum.EasingStyle.Sine)
			end)

			if isFirstST and activeTabIndex == tabIndex then
				Left.Visible = false
				Right.Visible = false
				subTabContainer.Visible = true
				ActivateSubTab()
			elseif not isFirstST then
				STRow.BackgroundTransparency = 1
				STLabel.TextTransparency = 0.55
				STScale.Scale = 0.985
				if iconRef then iconRef.ImageTransparency = 0.6 end
				task.defer(function()
					if not STRow.Parent then return end
					Tween(STScale, { Scale = 1 }, 0.15, Enum.EasingStyle.Quint, Enum.EasingDirection.Out)
				end)
			end

			local SubTabObj = {}
			local stSectionOrder = { left = 0, right = 0 }

			function SubTabObj:AddESPPreview(options)
				return WindowObj._buildESPPreview(stLeft, stRight, options)
			end

			function SubTabObj:AddSection(title, side)
				side = side == "right" and "right" or "left"
				local savedLeft  = Left
				local savedRight = Right
				local savedOrder = { left = sectionOrder.left, right = sectionOrder.right }

				Left  = stLeft
				Right = stRight
				sectionOrder.left  = stSectionOrder.left
				sectionOrder.right = stSectionOrder.right

				local sec = TabObj:AddSection(title, side)

				stSectionOrder.left  = sectionOrder.left
				stSectionOrder.right = sectionOrder.right
				Left  = savedLeft
				Right = savedRight
				sectionOrder.left  = savedOrder.left
				sectionOrder.right = savedOrder.right
				return sec
			end

			return SubTabObj
		end

		return TabObj
	end

	function WindowObj:SetScale(value)
		if value == "Auto" then
			automaticScale = true
			UpdateScale()
			if syncScaleSelection then syncScaleSelection("Auto") end
			return UIScale.Scale
		end
		if type(value) ~= "number" or value ~= value then return UIScale.Scale end
		automaticScale = false
		manualScale = math.clamp(value, 0.5, 1.1)
		ApplyScale(manualScale)
		if syncScaleSelection then syncScaleSelection(tostring(math.round(manualScale * 100)) .. "%") end
		return UIScale.Scale
	end

	function WindowObj:GetScale()
		return UIScale.Scale
	end

	function WindowObj:SetLogoVisible(visible)
		if applyLogoProxy then applyLogoProxy(visible == true) end
		return logoVisible
	end

	function WindowObj:GetLogoVisible()
		return logoVisible
	end

	function WindowObj:GetMainFrame()
		return MainFrame
	end

	function WindowObj:GetMenuBind()
		if menuBindProxy then return menuBindProxy() end
		return nil
	end

	function WindowObj:SetMenuBind(key)
		if menuBindProxy then menuBindProxy(key) end
		return self
	end



	WindowObj._applyCustomization = function()
		-- A delayed customization call must not traverse a destroyed GUI tree.
		if not MainFrame or not MainFrame.Parent then return end
		local function eachText(root, fn)
			for _, d in ipairs(root:GetDescendants()) do
				if d:IsA("TextLabel") or d:IsA("TextButton") or d:IsA("TextBox") then fn(d) end
			end
		end
		-- Only touch text that still has the previous customization colour: this
		-- pass used to paint every label one colour (grey values, accent "Renew",
		-- the NL row grey) and drop the bold font from titles.
		local previousText = customization._appliedTextColor or Color3.fromRGB(226, 228, 236)
		local function isPreviousText(color)
			return math.abs(color.R - previousText.R) < 0.01 and math.abs(color.G - previousText.G) < 0.01 and math.abs(color.B - previousText.B) < 0.01
		end
		eachText(MainFrame, function(t)
			if t.Font ~= FONT_BOLD then t.Font = customization.font or FONT end
			t.TextScaled = false
			if t.Name ~= "GameTitle" and t.Name ~= "TabLabel" and t.Name ~= "SectionLabel"
				and t.Name ~= "Daysleft" and t.Name ~= "HeaderLabel" and t.Name ~= "SearchEmptyState"
				and t.Name ~= "TabText" and t.Name ~= "Watermark" and isPreviousText(t.TextColor3) then t.TextColor3 = customization.textColor end
		end)
		customization._appliedTextColor = customization.textColor
		for _, d in ipairs(MainFrame:GetDescendants()) do
			if d:IsA("TextLabel") and d.Name == "SectionLabel" then
				d.TextScaled = false
				d.TextSize = customization.sectionTitleSize or 11
				d.TextColor3 = customization.sectionTitleColor or Color3.fromRGB(150, 158, 190)
				d.TextTransparency = customization.sectionTitleTransparency or 0
			end
		end
		if Watermark then
			Watermark.Text = customization.watermarkText
			Watermark.Visible = customization.watermarkVisible == true
		end
		for _, d in ipairs(MainFrame:GetDescendants()) do
			if d:IsA("UICorner") and d.Parent and d.Parent:IsA("GuiObject") then
				local name = d.Parent.Name
				if name == "Frame2" or name == "MainFrame" or name == "WindowSettingsFrame"
					or name == "ConfigMainFrame" or name == "RecentlyDeletedPanel" then
					d.CornerRadius = UDim.new(0, customization.cornerRadius)
				end
			end
		end
		for _, row in pairs(_windowContextTargets) do
			if row.dots then row.dots.Visible = customization.showContextDots == true end
		end
	end

	function WindowObj:SetCustomization(options)
		if type(options) ~= "table" then return customization end
		if options.accentColor and typeof(options.accentColor) == "Color3" then
			customization.accentColor = options.accentColor
			if applyMainColorProxy then applyMainColorProxy(options.accentColor) end
		end
		if options.font and typeof(options.font) == "EnumItem" then customization.font = options.font end
		if options.textColor and typeof(options.textColor) == "Color3" then customization.textColor = options.textColor end
		if type(options.sectionTitleSize) == "number" then
			customization.sectionTitleSize = math.clamp(options.sectionTitleSize, 8, 40)
		end
		if type(options.elementTextSize) == "number" then
			customization.elementTextSize = math.clamp(options.elementTextSize, 8, 40)
		end
		if type(options.watermarkText) == "string" then customization.watermarkText = options.watermarkText end
		if options.watermarkVisible ~= nil then customization.watermarkVisible = options.watermarkVisible == true end
		if type(options.cornerRadius) == "number" then
			customization.cornerRadius = math.clamp(options.cornerRadius, 0, 30)
		end
		if options.showContextDots ~= nil then customization.showContextDots = options.showContextDots == true end
		WindowObj._applyCustomization()
		return customization
	end

	function WindowObj:GetCustomization()
		return customization
	end

	-- Keep this collection on WindowObj rather than allocating another AddWindow local.
	-- AddWindow is deliberately large and Luau enforces a 200-local-register limit.
	WindowObj._customMenus = {}

	function WindowObj:AddCustomMenu(name, builder, options)
		options = type(options) == "table" and options or {}
		name = tostring(name or "Custom")
		local panel = New("Frame", {
			Name = "CustomMenu_" .. name,
			Position = options.position or UDim2.new(0, 0, 0, 0),
			Size = options.size or UDim2.new(1, 0, 1, 0),
			BackgroundColor3 = options.backgroundColor or Color3.fromRGB(15, 17, 26),
			BackgroundTransparency = options.backgroundTransparency or 0.8,
			BorderSizePixel = 0,
			Visible = false,
			Active = true,
			ClipsDescendants = options.clipsDescendants == true,
		}, options.parent or Frame2)
		New("UICorner", { CornerRadius = UDim.new(0, options.cornerRadius or customization.cornerRadius) }, panel)

		local api = {
			name = name,
			frame = panel,
			visible = false,
		}

		function api:Show()
			self.frame.Visible = true
			self.visible = true
			self.frame.BackgroundTransparency = 1
			Tween(self.frame, { BackgroundTransparency = (type(options.backgroundTransparency) == "number" and options.backgroundTransparency or 0.8) }, 0.2)
			return self
		end

		function api:Hide()
			self.visible = false
			Tween(self.frame, { BackgroundTransparency = 1 }, 0.18)
			task.delay(0.19, function()
				if not self.visible then self.frame.Visible = false end
			end)
			return self
		end

		function api:SetVisible(state)
			if state then return self:Show() end
			return self:Hide()
		end

		function api:IsVisible() return self.visible end

		function api:Destroy()
			if self.frame.Parent then self.frame:Destroy() end
			for i = #WindowObj._customMenus, 1, -1 do
				if WindowObj._customMenus[i] == self then table.remove(WindowObj._customMenus, i) end
			end
		end

		if type(builder) == "function" then
			local ok, err = pcall(builder, panel, api)
			if not ok then warn("[scr] AddCustomMenu(" .. name .. ") builder error: " .. tostring(err)) end
		end
		table.insert(WindowObj._customMenus, api)
		return api
	end

	WindowObj.AddCustomPanel = WindowObj.AddCustomMenu

	function WindowObj:GetCustomMenus()
		return WindowObj._customMenus
	end

	MakeReadableText(NeverloseCS2, 9, 16)
	CleanBorders(MainFrame)

	task.defer(function()
		local preloadAssets = {
			"rbxassetid://97828544806816", "rbxassetid://122894934359450",
			"rbxassetid://126010725826757", "rbxassetid://101123124881873",
			"rbxassetid://109698732019071", "rbxassetid://95127553964880",
			"rbxassetid://109485777305919", "rbxassetid://106497040962250",
			"rbxassetid://116396312853810", "rbxassetid://121978468376124",
			"rbxassetid://127234874352422", "rbxassetid://104941258142372",
			"rbxassetid://82464660673318", "rbxassetid://136533241128438",
			"rbxassetid://114499998778667", "rbxassetid://6031154871",
			hubImage ~= "" and hubImage or "rbxthumb://type=Asset&id=118608145176297&w=420&h=420",
			"rbxthumb://type=AvatarHeadShot&id=" .. tostring(LocalPlayer.UserId or 0) .. "&w=150&h=150",
		}
		local preloader = New("Frame", {
			Name = "TexturePreloader",
			Position = UDim2.new(0, -50, 0, -50),
			Size = UDim2.fromOffset(1, 1),
			BackgroundTransparency = 1,
		}, NeverloseCS2)
		for i, asset in ipairs(preloadAssets) do
			New("ImageLabel", {
				Name = "P" .. tostring(i),
				Size = UDim2.fromOffset(1, 1),
				BackgroundTransparency = 1,
				Image = asset,
				ImageTransparency = 0.01,
				ScaleType = Enum.ScaleType.Fit,
			}, preloader)
		end
		task.delay(4, function()
			if preloader.Parent then preloader:Destroy() end
		end)
	end)

	if Library.ShowLoader == false then
		task.delay(1, function() if WindowObj._autoLoad then WindowObj._autoLoad() end end)
	end

	return WindowObj
end

return Library
