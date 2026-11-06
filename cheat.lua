--[[
    BloxStrike cheat на базе Neverlose UI.
    Инжект: loadstring(game:HttpGet("https://.../cheat.lua"))()
    Меню: RShift. Бинды функций: ПКМ по функции -> New Hotkey.
]]

-- =========================================================================
-- СОСТОЯНИЕ
-- =========================================================================
local CFG = {
	aim = {
		enabled = false, method = "Camera", fov = 140, priority = "FOV",
		hitbox = "Head", smoothing = 35, visibleOnly = true, teamCheck = true,
		showFov = true, fovColor = Color3.fromRGB(255, 255, 255), maxDist = 2500,
	},
	legit = {
		enabled = false, fov = 60, priority = "FOV", hitbox = "Nearest",
		smoothing = 75, visibleOnly = true, teamCheck = true,
		showFov = false, fovColor = Color3.fromRGB(120, 255, 160), maxDist = 1500,
	},
	silent = {
		enabled = false, chance = 100, hitbox = "Head",
		visibleOnly = true, teamCheck = true, maxDist = 1500,
	},
	trigger = {
		enabled = false, delay = 80, chance = 100, hitbox = "All", teamCheck = true,
	},
	esp = {
		enabled = false, maxDist = 2000, box = "Default", teammates = false,
		name = true, health = true, distance = true, tracer = false, arrow = false,
		boxColor = Color3.fromRGB(255, 255, 255),
		tracerColor = Color3.fromRGB(255, 255, 255),
		arrowColor = Color3.fromRGB(255, 80, 80),
		visMode = "Disabled", visColor = Color3.fromRGB(120, 150, 255),
		wallMode = "Disabled", wallColor = Color3.fromRGB(80, 255, 200),
	},
	teamEsp = {
		enabled = false, color = Color3.fromRGB(220, 225, 255),
		visMode = "Disabled", visColor = Color3.fromRGB(220, 225, 255),
		wallMode = "Disabled", wallColor = Color3.fromRGB(255, 210, 180),
	},
	world = {
		fov = 90, forceFov = false, fullbright = false, removeFog = false,
		removeBlur = false, removeSun = false, thirdPerson = false, tpDist = 120,
	},
	misc = {
		bhop = false, speed = false, speedVal = 24, jump = false, jumpVal = 50,
		noclip = false, noFall = false, antiafk = false,
	},
	freecam = { enabled = false, speed = 45 },
	crosshair = { enabled = false, style = "Cross", color = Color3.fromRGB(0, 255, 0), size = 10, thickness = 2 },
}

-- =========================================================================
-- СЕРВИСЫ / ХЕЛПЕРЫ
-- =========================================================================
local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local UserInputService = game:GetService("UserInputService")
local Lighting = game:GetService("Lighting")
local LocalPlayer = Players.LocalPlayer
local Win -- объявлено заранее: движки читают Win._menuOpen

local function getCam() return workspace.CurrentCamera end
local function getChar() return LocalPlayer.Character end
local function getHum() local c = getChar() return c and c:FindFirstChildOfClass("Humanoid") end

local function mk(class, props, parent)
	local o = Instance.new(class)
	for k, v in pairs(props or {}) do pcall(function() o[k] = v end) end
	if parent then o.Parent = parent end
	return o
end

local function rayParams(exclude)
	local p = Instance.new("RaycastParams")
	p.FilterType = Enum.RaycastFilterType.Exclude
	p.FilterDescendantsInstances = exclude or {}
	return p
end

local function isVisible(targetPos, targetChar)
	local cam = getCam()
	if not cam then return false end
	local exclude = {}
	local myChar = getChar()
	if myChar then table.insert(exclude, myChar) end
	local res = workspace:Raycast(cam.CFrame.Position, targetPos - cam.CFrame.Position, rayParams(exclude))
	if not res then return true end
	return res.Instance ~= nil and res.Instance:IsDescendantOf(targetChar)
end

local function isEnemy(plr)
	local mine = LocalPlayer.Team
	if mine and plr.Team == mine then return false end
	return true
end

local function resolveHitbox(mode, char, center, cam)
	local head = char:FindFirstChild("Head")
	local torso = char:FindFirstChild("UpperTorso") or char:FindFirstChild("Torso")
	local root = char:FindFirstChild("HumanoidRootPart")
	if mode == "Chest" then return torso or head or root end
	if mode == "Stomach" then return char:FindFirstChild("LowerTorso") or torso or head or root end
	if mode == "Nearest" then
		local best, bestD = nil, math.huge
		for _, p in ipairs({ head, torso, root }) do
			if p then
				local sp = cam:WorldToViewportSize(p.Position)
				local d = (Vector2.new(sp.X, sp.Y) - center).Magnitude
				if d < bestD then bestD = d; best = p end
			end
		end
		return best
	end
	return head or torso or root
end

local function collectTargets(cfg, needFov)
	local cam = getCam()
	if not cam then return end
	local vp = cam.ViewportSize
	local center = Vector2.new(vp.X * 0.5, vp.Y * 0.5)
	local list = {}
	for _, plr in ipairs(Players:GetPlayers()) do
		if plr ~= LocalPlayer then
			local char = plr.Character
			local hum = char and char:FindFirstChildOfClass("Humanoid")
			local root = char and char:FindFirstChild("HumanoidRootPart")
			if char and hum and root and hum.Health > 0 then
				if not (cfg.teamCheck and not isEnemy(plr)) then
					local part = resolveHitbox(cfg.hitbox, char, center, cam)
					if part then
						local pos = part.Position
						local depth = (pos - cam.CFrame.Position):Dot(cam.CFrame.LookVector)
						if depth > 0 then
							local dist = (pos - cam.CFrame.Position).Magnitude
							if dist <= (cfg.maxDist or 3000) then
								local sp = cam:WorldToViewportSize(pos)
								local screenPos = Vector2.new(sp.X, sp.Y)
								local fovDist = (screenPos - center).Magnitude
								if not needFov or fovDist <= cfg.fov then
									local visible = not cfg.visibleOnly or isVisible(pos, char)
									if visible then
										list[#list + 1] = {
											player = plr, char = char, hum = hum, part = part,
											pos = pos, dist = dist, fovDist = fovDist,
											screenPos = screenPos, center = center,
										}
									end
								end
							end
						end
					end
				end
			end
		end
	end
	if #list == 0 then return nil end
	local best = list[1]
	if cfg.priority == "Distance" then
		for _, e in ipairs(list) do if e.dist < best.dist then best = e end end
	elseif cfg.priority == "Health" then
		for _, e in ipairs(list) do if e.hum.Health < best.hum.Health then best = e end end
	else
		for _, e in ipairs(list) do if e.fovDist < best.fovDist then best = e end end
	end
	return best
end

-- =========================================================================
-- ЗАГРУЗКА БИБЛИОТЕКИ
-- =========================================================================
local LIBRARY_URL = "https://raw.githubusercontent.com/robert2289top-maker/nl-menu-rb/main/scr.lua"

local function stripComments(src)
	local out, i, n = {}, 1, #src
	while i <= n do
		local c = src:sub(i, i)
		local two = src:sub(i, i + 1)
		if two == "--" then
			local eq = src:match("^%-%-%[(=*)%[", i)
			if eq then
				local close = "]" .. eq .. "]"
				local stop = src:find(close, i, true)
				i = stop and (stop + #close) or (n + 1)
			else
				local nl = src:find("\n", i, true)
				i = nl or (n + 1)
			end
		elseif c == '"' or c == "'" then
			local quote, start = c, i
			i = i + 1
			while i <= n do
				local ch = src:sub(i, i)
				if ch == "\\" then i = i + 2
				elseif ch == quote then i = i + 1; break
				elseif ch == "\n" then break
				else i = i + 1 end
			end
			out[#out + 1] = src:sub(start, i - 1)
		elseif c == "[" then
			local eq = src:match("^%[(=*)%[", i)
			if eq then
				local closeToken = "]" .. eq .. "]"
				local contentStart = i + #eq + 2
				local closeStart = src:find(closeToken, contentStart, true)
				local stop = closeStart and (closeStart + #closeToken - 1) or n
				out[#out + 1] = src:sub(i, stop)
				i = stop + 1
			else
				local nl = src:find("\n", i, true)
				local stop = nl and (nl - 1) or n
				local line = src:sub(i, stop):match("^[ \t]*(.-)[ \t]*$")
				if line ~= "" then out[#out + 1] = line end
				if nl then out[#out + 1] = "\n"; i = nl + 1 else i = n + 1 end
			end
		else
			local nl = src:find("\n", i, true)
			local stop = nl and (nl - 1) or n
			local line = src:sub(i, stop):match("^[ \t]*(.-)[ \t]*$")
			if line ~= "" then out[#out + 1] = line end
			if nl then out[#out + 1] = "\n"; i = nl + 1 else i = n + 1 end
		end
	end
	return table.concat(out)
end

local function loadLibrary()
	if type(readfile) == "function" and type(isfile) == "function" and isfile("scr.lua") then
		local fn, err = loadstring(stripComments(readfile("scr.lua")), "scr.lua")
		if fn then
			local ok, lib = pcall(fn)
			if ok and type(lib) == "table" and type(lib.AddWindow) == "function" then return lib end
		end
	end
	local ok, body = pcall(function() return game:HttpGet(LIBRARY_URL .. "?v=" .. tostring(os.time())) end)
	if not ok or type(body) ~= "string" then error("[cheat] не удалось загрузить библиотеку") end
	local fn, err = loadstring(stripComments(body), "scr.lua")
	if not fn then error("[cheat] compile: " .. tostring(err)) end
	local ok2, lib = pcall(fn)
	if not ok2 or type(lib) ~= "table" or type(lib.AddWindow) ~= "function" then
		error("[cheat] библиотека не вернулась")
	end
	return lib
end

local Library = loadLibrary()
Library.DaysLeft = nil

-- =========================================================================
-- СЛОЙ ОТРИСОВКИ (ESP / FOV / прицел)
-- =========================================================================
local FONT = Enum.Font.SourceSansSemibold
pcall(function() FONT = Enum.Font.BuilderSansMedium end)

local drawGui
local function getDrawGui()
	if drawGui and drawGui.Parent then return drawGui end
	drawGui = mk("ScreenGui", {
		Name = "NL_Cheat", ResetOnSpawn = false, IgnoreGuiInset = true,
		DisplayOrder = 99999, ZIndexBehavior = Enum.ZIndexBehavior.Sibling,
	})
	local done = false
	if type(gethui) == "function" then
		pcall(function() drawGui.Parent = gethui(); done = drawGui.Parent ~= nil end)
	end
	if not done then pcall(function() drawGui.Parent = game:GetService("CoreGui"); done = drawGui.Parent ~= nil end) end
	if not done then drawGui.Parent = LocalPlayer:FindFirstChild("PlayerGui") end
	return drawGui
end

-- FOV circle
local fovRing = nil
local fovStroke = nil
local function ensureFovRing()
	if fovRing and fovRing.Parent then return end
	fovRing = mk("Frame", {
		AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.fromScale(0.5, 0.5),
		BackgroundTransparency = 1, Visible = false, ZIndex = 5,
	}, getDrawGui())
	mk("UICorner", { CornerRadius = UDim.new(1, 0) }, fovRing)
	fovStroke = mk("UIStroke", { Thickness = 1.5, Color = CFG.aim.fovColor, Transparency = 0.15 }, fovRing)
end

-- Кастомный прицел
local crossRoot = nil
local crossLines = {}
local crossRing = nil
local function ensureCrosshair()
	if crossRoot and crossRoot.Parent then return end
	crossRoot = mk("Frame", {
		AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.fromScale(0.5, 0.5),
		Size = UDim2.fromOffset(1, 1), BackgroundTransparency = 1, Visible = false, ZIndex = 6,
	}, getDrawGui())
	for i = 1, 4 do
		crossLines[i] = mk("Frame", { BackgroundColor3 = Color3.new(1, 1, 1), Visible = false, ZIndex = 6 }, crossRoot)
	end
	crossRing = mk("Frame", {
		BackgroundTransparency = 1, Visible = false, ZIndex = 6,
	}, crossRoot)
	mk("UICorner", { CornerRadius = UDim.new(1, 0) }, crossRing)
	mk("UIStroke", { Color = Color3.new(1, 1, 1), Thickness = 1 }, crossRing)
end

-- =========================================================================
-- ESP
-- =========================================================================
local FONT_ESP = Enum.Font.SourceSansSemibold
pcall(function() FONT_ESP = Enum.Font.BuilderSansMedium end)

local espCache = {}

local function destroyEntry(plr)
	local e = espCache[plr]
	if not e then return end
	for _, obj in ipairs({ e.box, e.name, e.dist, e.hpBg, e.hpFill, e.tracer, e.arrow }) do
		if obj and obj.Parent then obj:Destroy() end
	end
	if e.corners then for _, o in ipairs(e.corners) do if o.Parent then o:Destroy() end end end
	if e.hVis and e.hVis.Parent then e.hVis:Destroy() end
	if e.hWall and e.hWall.Parent then e.hWall:Destroy() end
	espCache[plr] = nil
end

local function newEntry(plr)
	local gui = getDrawGui()
	local stroke = { Color = Color3.new(1, 1, 1), Transparency = 0.1, Thickness = 1 }
	local box = mk("Frame", { BackgroundTransparency = 1, Visible = false, ZIndex = 4, BorderSizePixel = 0 }, gui)
	box.ClipsDescendants = false
	local boxStroke = mk("UIStroke", { Color = stroke.Color, Transparency = stroke.Transparency, Thickness = 1, ApplyStrokeMode = Enum.ApplyStrokeMode.Border }, box)

	local corners = {}
	for i = 1, 8 do
		corners[i] = mk("Frame", { BackgroundColor3 = Color3.new(1, 1, 1), Visible = false, ZIndex = 4 }, gui)
	end
	local nameLabel = mk("TextLabel", {
		BackgroundTransparency = 1, Font = FONT_ESP, TextSize = 14, TextScaled = false,
		TextColor3 = Color3.new(1, 1, 1), TextStrokeTransparency = 0.4, Visible = false, ZIndex = 4,
	}, gui)
	local distLabel = mk("TextLabel", {
		BackgroundTransparency = 1, Font = FONT_ESP, TextSize = 13, TextScaled = false,
		TextColor3 = Color3.fromRGB(220, 222, 230), TextStrokeTransparency = 0.5, Visible = false, ZIndex = 4,
	}, gui)
	local hpBg = mk("Frame", { BackgroundColor3 = Color3.fromRGB(10, 10, 14), BackgroundTransparency = 0.25, Visible = false, ZIndex = 4 }, gui)
	local hpFill = mk("Frame", { BackgroundColor3 = Color3.fromRGB(90, 220, 120), Visible = false, ZIndex = 5 }, hpBg)
	local tracer = mk("Frame", { AnchorPoint = Vector2.new(0.5, 0.5), BackgroundColor3 = Color3.new(1, 1, 1), BackgroundTransparency = 0.2, Visible = false, ZIndex = 4 }, gui)
	local arrow = mk("TextLabel", {
		BackgroundTransparency = 1, Text = "▶", Font = FONT_ESP, TextSize = 18,
		TextColor3 = Color3.fromRGB(255, 80, 80), Visible = false, ZIndex = 4,
	}, gui)
	local hVis = mk("Highlight", { Enabled = false, DepthMode = Enum.HighlightDepthMode.Occluded }, nil)
	local hWall = mk("Highlight", { Enabled = false, DepthMode = Enum.HighlightDepthMode.AlwaysOnTop }, nil)

	espCache[plr] = {
		box = box, boxStroke = boxStroke, corners = corners, name = nameLabel, dist = distLabel,
		hpBg = hpBg, hpFill = hpFill, tracer = tracer, arrow = arrow, hVis = hVis, hWall = hWall,
	}
	return espCache[plr]
end

local function isAlive(inst)
	if not inst then return false end
	local ok, destroyed = pcall(function() return inst:IsDestroyed() end)
	if ok then return not destroyed end
	return true
end

local function setHighlight(h, mode, color, char, depthMode)
	if not isAlive(h) then h = nil end
	if mode == "Disabled" or not char then
		if h then pcall(function() h.Enabled = false end) end
		return h
	end
	if not h then
		h = mk("Highlight", { Enabled = false, DepthMode = depthMode or Enum.HighlightDepthMode.Occluded })
	end
	local okParent = pcall(function() h.Parent = char end)
	if not okParent then return h end
	local ok = pcall(function()
		h.Enabled = true
		h.FillColor = color
		h.OutlineColor = color
		if mode == "Chams" then
			h.FillTransparency = 0.35
			h.OutlineTransparency = 0.05
		elseif mode == "Wireframe" then
			h.FillTransparency = 1
			h.OutlineTransparency = 0
		else -- Flat
			h.FillTransparency = 0
			h.OutlineTransparency = 1
		end
	end)
	if not ok then return h end
	return h
end

local function applyStyle(e, style, color)
	if style == "Filled" then
		e.box.Visible = false
		for _, c in ipairs(e.corners) do c.Visible = false end
		e.box.BackgroundTransparency = 0.65
		e.box.BackgroundColor3 = color
		e.boxStroke.Color = color
	elseif style == "Corners" then
		e.box.Visible = false
		e.box.BackgroundTransparency = 1
	else -- Default
		for _, c in ipairs(e.corners) do c.Visible = false end
		e.box.Visible = true
		e.box.BackgroundTransparency = 1
		e.boxStroke.Color = color
	end
end

local function drawCorners(e, x1, y1, x2, y2, color)
	local h = math.max(8, (y2 - y1) * 0.25)
	local w = math.max(8, (x2 - x1) * 0.25)
	local t = 2
	local pts = {
		{ x1, y1, w, t }, { x1, y1, t, h },       -- TL
		{ x2 - w, y1, w, t }, { x2 - t, y1, t, h }, -- TR
		{ x1, y2 - t, w, t }, { x1, y2 - h, t, h }, -- BL
		{ x2 - w, y2 - t, w, t }, { x2 - t, y2 - h, t, h }, -- BR
	}
	for i, p in ipairs(pts) do
		local f = e.corners[i]
		f.Visible = true
		f.BackgroundColor3 = color
		f.Position = UDim2.fromOffset(p[1], p[2])
		f.Size = UDim2.fromOffset(p[3], p[4])
	end
end

local function getScreenRect(char, cam)
	local head = char:FindFirstChild("Head")
	local root = char:FindFirstChild("HumanoidRootPart")
	if not (head and root) then return nil end
	local right = cam.CFrame.RightVector
	local topPos = head.Position + Vector3.new(0, head.Size.Y * 0.55, 0)
	local feetPos = root.Position - Vector3.new(0, 2.6, 0)
	local pL = feetPos - right * 0.95
	local pR = feetPos + right * 0.95
	local pts = { topPos, feetPos, pL, pR }
	local minX, maxX, minY, maxY = math.huge, -math.huge, math.huge, -math.huge
	local origin = cam.CFrame.Position
	for _, p in ipairs(pts) do
		if (p - origin):Dot(cam.CFrame.LookVector) <= 0 then return nil end
		local sp = cam:WorldToViewportSize(p)
		minX = math.min(minX, sp.X); maxX = math.max(maxX, sp.X)
		minY = math.min(minY, sp.Y); maxY = math.max(maxY, sp.Y)
	end
	if maxX - minX < 4 then return nil end
	return minX, minY, maxX, maxY
end

local function hideEntry(e)
	e.box.Visible = false
	for _, c in ipairs(e.corners) do c.Visible = false end
	e.name.Visible = false; e.dist.Visible = false
	e.hpBg.Visible = false; e.tracer.Visible = false; e.arrow.Visible = false
	e.hVis.Enabled = false; e.hWall.Enabled = false
end

local function updateEsp()
	local gui = getDrawGui()
	local cam = getCam()
	local enemyOn = CFG.esp.enabled
	local teamOn = CFG.teamEsp.enabled or (enemyOn and CFG.esp.teammates)
	if not enemyOn and not teamOn then
		for plr in pairs(espCache) do destroyEntry(plr) end
		return
	end
	local vp = cam and cam.ViewportSize or Vector2.new(1920, 1080)
	local center = Vector2.new(vp.X * 0.5, vp.Y * 0.5)
	local seen = {}
	for _, plr in ipairs(Players:GetPlayers()) do
		if plr ~= LocalPlayer then
			local char = plr.Character
			local hum = char and char:FindFirstChildOfClass("Humanoid")
			local root = char and char:FindFirstChild("HumanoidRootPart")
			local enemy = isEnemy(plr)
			local cfg = enemy and CFG.esp or CFG.teamEsp
			local active = enemy and enemyOn or (not enemy and teamOn)
			if char and hum and root and hum.Health > 0 and active and cam then
				local dist = (root.Position - cam.CFrame.Position).Magnitude
				if dist <= (enemy and cfg.maxDist or 5000) then
					seen[plr] = true
					local e = espCache[plr] or newEntry(plr)
					local rect = getScreenRect(char, cam)
					if rect then
						local x1, y1, x2, y2 = rect
						local color = enemy and CFG.esp.boxColor or CFG.teamEsp.color
						-- box
						if enemy then
							if CFG.esp.box == "Corners" then
								e.box.Visible = false
								drawCorners(e, x1, y1, x2, y2, color)
							else
								for _, c in ipairs(e.corners) do c.Visible = false end
								e.box.Visible = true
								e.box.Position = UDim2.fromOffset(x1, y1)
								e.box.Size = UDim2.fromOffset(x2 - x1, y2 - y1)
								if CFG.esp.box == "Filled" then
									e.box.BackgroundTransparency = 0.65
									e.box.BackgroundColor3 = color
								else
									e.box.BackgroundTransparency = 1
								end
								e.boxStroke.Color = color
							end
						else
							for _, c in ipairs(e.corners) do c.Visible = false end
							e.box.Visible = true
							e.box.Position = UDim2.fromOffset(x1, y1)
							e.box.Size = UDim2.fromOffset(x2 - x1, y2 - y1)
							e.box.BackgroundTransparency = 1
							e.boxStroke.Color = color
						end
						-- name
						local showName = enemy and CFG.esp.name
						if showName then
							e.name.Visible = true
							e.name.Text = plr.DisplayName ~= "" and plr.DisplayName or plr.Name
							e.name.Position = UDim2.fromOffset(x1, y1 - 17)
							e.name.Size = UDim2.fromOffset(x2 - x1, 16)
							e.name.TextColor3 = color
						else
							e.name.Visible = false
						end
						-- distance
						local showDist = enemy and CFG.esp.distance
						if showDist then
							e.dist.Visible = true
							e.dist.Text = tostring(math.floor(dist)) .. " st"
							e.dist.Position = UDim2.fromOffset(x1, y2 + 2)
							e.dist.Size = UDim2.fromOffset(x2 - x1, 15)
						else
							e.dist.Visible = false
						end
						-- health
						local showHp = enemy and CFG.esp.health
						if showHp then
							local ratio = math.clamp(hum.Health / math.max(1, hum.MaxHealth), 0, 1)
							e.hpBg.Visible = true
							e.hpBg.Position = UDim2.fromOffset(x1 - 6, y1)
							e.hpBg.Size = UDim2.fromOffset(3, y2 - y1)
							e.hpFill.Visible = true
							e.hpFill.Position = UDim2.new(0, 0, 1 - ratio, 0)
							e.hpFill.Size = UDim2.new(1, 0, ratio, 0)
							e.hpFill.BackgroundColor3 = Color3.fromRGB(255 * (1 - ratio) + 60, 220 * ratio + 40, 80)
						else
							e.hpBg.Visible = false
						end
						-- tracer
						if enemy and CFG.esp.tracer then
							local fromX, fromY = vp.X * 0.5, vp.Y - 2
							local toX, toY = (x1 + x2) * 0.5, y2
							local dx, dy = toX - fromX, toY - fromY
							local len = math.sqrt(dx * dx + dy * dy)
							e.tracer.Visible = len > 1
							e.tracer.Position = UDim2.fromOffset((fromX + toX) * 0.5, (fromY + toY) * 0.5)
							e.tracer.Size = UDim2.fromOffset(len, 1)
							e.tracer.Rotation = math.deg(math.atan2(dy, dx))
							e.tracer.BackgroundColor3 = CFG.esp.tracerColor
						else
							e.tracer.Visible = false
						end
						-- offscreen arrow
						if enemy and CFG.esp.arrow then
							local sp = cam:WorldToViewportSize(root.Position)
							local sx, sy = sp.X, sp.Y
							local depth = (root.Position - cam.CFrame.Position):Dot(cam.CFrame.LookVector)
							local onScreen = depth > 0 and sx >= 0 and sx <= vp.X and sy >= 0 and sy <= vp.Y
							if not onScreen then
								local dx, dy = sx - center.X, sy - center.Y
								if depth <= 0 then dx, dy = -dx, -dy end
								local ang = math.atan2(dy, dx)
								local radius = math.min(vp.X, vp.Y) * 0.4
								local ax = center.X + math.cos(ang) * radius
								local ay = center.Y + math.sin(ang) * radius
								e.arrow.Visible = true
								e.arrow.Position = UDim2.fromOffset(ax - 10, ay - 10)
								e.arrow.Size = UDim2.fromOffset(20, 20)
								e.arrow.Rotation = math.deg(ang)
								e.arrow.TextColor3 = CFG.esp.arrowColor
							else
								e.arrow.Visible = false
							end
						else
							e.arrow.Visible = false
						end
						-- chams
						e.hVis = setHighlight(e.hVis, enemy and CFG.esp.visMode or CFG.teamEsp.visMode,
							enemy and CFG.esp.visColor or CFG.teamEsp.visColor, char, Enum.HighlightDepthMode.Occluded)
						e.hWall = setHighlight(e.hWall, enemy and CFG.esp.wallMode or CFG.teamEsp.wallMode,
							enemy and CFG.esp.wallColor or CFG.teamEsp.wallColor, char, Enum.HighlightDepthMode.AlwaysOnTop)
					else
						hideEntry(e)
					end
				else
					destroyEntry(plr)
				end
			else
				destroyEntry(plr)
			end
		end
	end
	for plr in pairs(espCache) do
		if not seen[plr] and not Players:FindFirstChild(plr.Name) then destroyEntry(plr) end
	end
end

-- =========================================================================
-- АИМБОТ
-- =========================================================================
local function applyAim(cfg)
	local cam = getCam()
	if not cam then return end
	local best = collectTargets(cfg, true)
	if not best then return end
	if (best.pos - cam.CFrame.Position).Magnitude < 0.2 then return end
	if cfg.method == "Mouse" and type(mousemoverel) == "function" then
		local vp = cam.ViewportSize
		pcall(mousemoverel, best.screenPos.X - vp.X * 0.5, best.screenPos.Y - vp.Y * 0.5)
	else
		local alpha = 1 - (cfg.smoothing / 100) * 0.94
		if alpha < 0.03 then alpha = 0.03 end
		local goal = CFrame.lookAt(cam.CFrame.Position, best.pos)
		cam.CFrame = cam.CFrame:Lerp(goal, alpha)
	end
end

local function updateAim()
	if Win and Win._menuOpen then return end
	if CFG.aim.enabled then applyAim(CFG.aim) end
	if CFG.legit.enabled then applyAim(CFG.legit) end
end

local function updateFovRing()
	ensureFovRing()
	local cfg = CFG.aim.enabled and CFG.aim or (CFG.legit.enabled and CFG.legit or nil)
	local show = cfg ~= nil and cfg.showFov
	fovRing.Visible = show == true
	if show then
		fovRing.Size = UDim2.fromOffset(cfg.fov * 2, cfg.fov * 2)
		fovStroke.Color = cfg.fovColor
	end
end

-- =========================================================================
-- SILENT AIM (хук __namecall / mouse)
-- =========================================================================
local silentAvailable = false
local silentTarget = nil
local lastSilentRoll = 0

local function wrap(fn)
	if type(newcclosure) == "function" then return newcclosure(fn) end
	return fn
end

local function redirectArgs(remote, args)
	local target = silentTarget
	if not target then return args end
	local name = tostring(remote.Name):lower()
	if not (name:find("shoot") or name:find("fire") or name:find("bullet") or name:find("gun")
		or name:find("weapon") or name:find("attack") or name:find("hit") or name:find("damage")
		or name:find("swing") or name:find("melee") or name:find("launch") or name:find("throw")
		or name:find("shot") or name:find("aim")) then
		return args
	end
	local v3indexes = {}
	for i, a in ipairs(args) do
		if typeof(a) == "Vector3" then v3indexes[#v3indexes + 1] = i end
	end
	if #v3indexes == 0 then return args end
	if #v3indexes == 1 then
		args[v3indexes[1]] = target.pos
	else
		local origin = args[v3indexes[1]]
		local second = args[v3indexes[2]]
		if second.Magnitude <= 1.5 then
			-- направление (нормализовано) -> целим в цель
			args[v3indexes[2]] = (target.pos - origin).Unit
		else
			-- абсолютная позиция -> подменяем
			args[v3indexes[2]] = target.pos
		end
	end
	return args
end

local function setupSilentHooks()
	if not (type(getrawmetatable) == "function" and type(getnamecallmethod) == "function") then
		print("[cheat] silent aim: хуки недоступны в этом экзекуторе")
		return
	end
	local ok, mt = pcall(getrawmetatable, game)
	if not ok or type(mt) ~= "table" then
		print("[cheat] silent aim: метатаблица недоступна")
		return
	end
	pcall(setreadonly, mt, false)

	local oldNamecall = mt.__namecall
	if type(oldNamecall) ~= "function" then
		print("[cheat] silent aim: __namecall не найден")
		return
	end
	mt.__namecall = wrap(function(self, ...)
		local cfg = CFG.silent
		if cfg.enabled and not (Win and Win._menuOpen) and silentTarget then
			local method = getnamecallmethod()
			if method == "FireServer" or method == "InvokeServer" then
				if math.random(1, 100) <= cfg.chance then
					local args = redirectArgs(self, { ... })
					return oldNamecall(self, table.unpack(args))
				end
			end
		end
		return oldNamecall(self, ...)
	end)

	-- mouse.Hit / mouse.Target для игр, стреляющих по мыши
	do
		local okMouse, mouse = pcall(function() return LocalPlayer:GetMouse() end)
		local oldIndex = mt.__index
		if okMouse and mouse and type(oldIndex) == "function" then
			mt.__index = wrap(function(t, k)
				if t == mouse and CFG.silent.enabled and not (Win and Win._menuOpen) and silentTarget then
					if k == "Hit" then return CFrame.new(silentTarget.pos) end
					if k == "Target" then return silentTarget.part end
					if k == "UnitRay" then
						local cam = getCam()
						if cam then
							return Ray.new(cam.CFrame.Position, (silentTarget.pos - cam.CFrame.Position).Unit)
						end
					end
				end
				return oldIndex(t, k)
			end)
		end
	end
	silentAvailable = true
end

local function updateSilent()
	if not CFG.silent.enabled or (Win and Win._menuOpen) then
		silentTarget = nil
		return
	end
	local cfg = CFG.silent
	cfg.priority = "Distance"
	silentTarget = collectTargets(cfg, false)
end

-- =========================================================================
-- ТРИГГЕРБОТ
-- =========================================================================
local nextTriggerShot = 0

local function fireMouse()
	if type(mouse1click) == "function" then
		pcall(mouse1click)
		return
	end
	local vu = game:GetService("VirtualUser")
	if pcall(function() vu:ClickButton1(Vector2.new(0, 0)) end) then return end
	pcall(function()
		local cf = (getCam() and getCam().CFrame) or CFrame.new()
		vu:Button1Down(Vector2.new(0, 0), cf)
		vu:Button1Up(Vector2.new(0, 0), cf)
	end)
end

local function updateTrigger()
	local cfg = CFG.trigger
	if not cfg.enabled or (Win and Win._menuOpen) then return end
	local cam = getCam()
	if not cam then return end
	local now = os.clock()
	if now * 1000 < nextTriggerShot then return end
	local vp = cam.ViewportSize
	local ray = cam:ViewportPointToRay(vp.X * 0.5, vp.Y * 0.5)
	local exclude = {}
	local myChar = getChar()
	if myChar then table.insert(exclude, myChar) end
	local res = workspace:Raycast(ray.Origin, ray.Direction * 5000, rayParams(exclude))
	if not res then return end
	local model = res.Instance:FindFirstAncestorOfClass("Model")
	local owner = model and Players:GetPlayerFromCharacter(model)
	if not owner or owner == LocalPlayer then return end
	if cfg.teamCheck and not isEnemy(owner) then return end
	local char = owner.Character
	local hum = char and char:FindFirstChildOfClass("Humanoid")
	if not hum or hum.Health <= 0 then return end
	if cfg.hitbox ~= "All" then
		local center = Vector2.new(vp.X * 0.5, vp.Y * 0.5)
		local want = resolveHitbox(cfg.hitbox, char, center, cam)
		if not want or res.Instance ~= want then return end
	end
	if math.random(1, 100) > cfg.chance then return end
	nextTriggerShot = now * 1000 + cfg.delay
	fireMouse()
end

-- =========================================================================
-- ПЕРСОНАЖ: скорость / прыжок / ноуклип / урон от падения
-- =========================================================================
local orig = { walk = 24, jump = 50, saved = false }

local function onCharacter(char)
	orig.saved = false
	local hum = char:WaitForChild("Humanoid", 10)
	if not hum then return end
	orig.walk = hum.WalkSpeed
	orig.jump = hum.UseJumpPower and hum.JumpPower or hum.JumpHeight
	orig.saved = true

	if CFG.misc.speed then hum.WalkSpeed = CFG.misc.speedVal end
	if CFG.misc.jump then
		if hum.UseJumpPower then hum.JumpPower = CFG.misc.jumpVal else hum.JumpHeight = CFG.misc.jumpVal end
	end

	-- урон от падения: запомнили здоровье в полёте, восстановили при приземлении
	local airHealth = nil
	hum.StateChanged:Connect(function(_, new)
		if new == Enum.HumanoidStateType.Freefall then
			airHealth = hum.Health
		elseif new == Enum.HumanoidStateType.Landed then
			if CFG.misc.noFall and airHealth and hum.Health < airHealth then
				pcall(function() hum.Health = airHealth end)
			end
			airHealth = nil
		end
	end)
end

LocalPlayer.CharacterAdded:Connect(onCharacter)
if LocalPlayer.Character then task.spawn(onCharacter, LocalPlayer.Character) end

local function applyMovement()
	local hum = getHum()
	if not hum then return end
	if CFG.misc.speed then
		if hum.WalkSpeed ~= CFG.misc.speedVal then hum.WalkSpeed = CFG.misc.speedVal end
	elseif orig.saved and hum.WalkSpeed == CFG.misc.speedVal then
		hum.WalkSpeed = orig.walk
	end
	if CFG.misc.jump then
		if hum.UseJumpPower then
			if hum.JumpPower ~= CFG.misc.jumpVal then hum.JumpPower = CFG.misc.jumpVal end
		else
			if hum.JumpHeight ~= CFG.misc.jumpVal then hum.JumpHeight = CFG.misc.jumpVal end
		end
	elseif orig.saved then
		if hum.UseJumpPower and hum.JumpPower == CFG.misc.jumpVal then
			hum.JumpPower = orig.jump
		elseif not hum.UseJumpPower and hum.JumpHeight == CFG.misc.jumpVal then
			hum.JumpHeight = orig.jump
		end
	end
	-- bunny hop
	if CFG.misc.bhop and UserInputService:IsKeyDown(Enum.KeyCode.Space) then
		if hum:GetState() == Enum.HumanoidStateType.Landed or hum.FloorMaterial ~= Enum.Material.Air then
			hum.Jump = true
		end
	end
end

RunService.Stepped:Connect(function()
	if CFG.misc.noclip then
		local char = getChar()
		if char then
			for _, p in ipairs(char:GetDescendants()) do
				if p:IsA("BasePart") then p.CanCollide = false end
			end
		end
	end
end)

-- anti-afk
LocalPlayer.Idled:Connect(function()
	if not CFG.misc.antiafk then return end
	pcall(function()
		local vu = game:GetService("VirtualUser")
		vu:CaptureController()
		vu:ClickButton2(Vector2.new(0, 0))
	end)
end)

-- =========================================================================
-- МИР: FOV / свет / туман / блюр / третье лицо
-- =========================================================================
local savedLight = nil

local function applyWorld()
	local w = CFG.world
	if w.forceFov then
		local cam = getCam()
		if cam and cam.FieldOfView ~= w.fov then cam.FieldOfView = w.fov end
	end
	if w.fullbright or w.removeFog then
		if not savedLight then
			savedLight = {
				ambient = Lighting.Ambient, outdoor = Lighting.OutdoorAmbient,
				brightness = Lighting.Brightness, shadows = Lighting.GlobalShadows,
				fogStart = Lighting.FogStart, fogEnd = Lighting.FogEnd, fogColor = Lighting.FogColor,
			}
		end
		if w.fullbright then
			Lighting.Ambient = Color3.fromRGB(170, 170, 170)
			Lighting.OutdoorAmbient = Color3.fromRGB(170, 170, 170)
			Lighting.GlobalShadows = false
			Lighting.Brightness = 2
		end
		if w.removeFog then
			Lighting.FogStart = 0
			Lighting.FogEnd = 999999
		end
	elseif savedLight then
		Lighting.Ambient = savedLight.ambient
		Lighting.OutdoorAmbient = savedLight.outdoor
		Lighting.Brightness = savedLight.brightness
		Lighting.GlobalShadows = savedLight.shadows
		Lighting.FogStart = savedLight.fogStart
		Lighting.FogEnd = savedLight.fogEnd
		Lighting.FogColor = savedLight.fogColor
		savedLight = nil
	end

	-- третье лицо: удерживаем, пока включено (игры могут лочить обратно)
	if w.thirdPerson then
		pcall(function()
			LocalPlayer.CameraMode = Enum.CameraMode.Classic
			if LocalPlayer.CameraMaxZoomDistance < w.tpDist then
				LocalPlayer.CameraMaxZoomDistance = w.tpDist
			end
		end)
	end
end

local lastOverlayScan = 0
local function scanOverlays()
	local w = CFG.world
	if not (w.removeBlur or w.removeSun) then return end
	local now = os.clock()
	if now - lastOverlayScan < 0.5 then return end
	lastOverlayScan = now
	local roots = { Lighting }
	local cam = getCam()
	if cam then table.insert(roots, cam) end
	local pg = LocalPlayer:FindFirstChild("PlayerGui")
	if pg then table.insert(roots, pg) end
	for _, root in ipairs(roots) do
		pcall(function()
			for _, d in ipairs(root:GetDescendants()) do
				if w.removeBlur and (d:IsA("BlurEffect") or d:IsA("DepthOfFieldEffect")) then
					d.Enabled = false
				end
				if w.removeSun and d:IsA("SunRaysEffect") then
					d.Enabled = false
				end
			end
		end)
	end
end

local savedCam = nil

local function applyThirdPersonRestore()
	if not CFG.world.thirdPerson and savedCam then
		pcall(function()
			LocalPlayer.CameraMode = savedCam.mode
			LocalPlayer.CameraMaxZoomDistance = savedCam.maxZoom
			LocalPlayer.CameraMinZoomDistance = savedCam.minZoom
		end)
		savedCam = nil
	end
end

-- =========================================================================
-- FREECAM
-- =========================================================================
local fc = { yaw = 0, pitch = 0, pos = nil, keys = {}, looking = false, inited = false }

local function freecamInit()
	local cam = getCam()
	if not cam then return end
	fc.pos = cam.CFrame.Position
	local rx, ry, rz
	local ok = pcall(function() rx, ry, rz = cam.CFrame:ToEulerAnglesYXZ() end)
	if not ok or rx ~= rx then
		rx, ry, rz = cam.CFrame:ToEulerAnglesXYZ()
	end
	fc.pitch, fc.yaw = rx, ry
	fc.inited = true
end

local function updateFreecam(dt)
	local cfg = CFG.freecam
	if not cfg.enabled then
		if fc.inited then
			pcall(function() getCam().CameraType = Enum.CameraType.Custom end)
			fc.inited = false
			fc.keys = {}
		end
		return
	end
	local cam = getCam()
	if not cam then return end
	if not fc.inited then freecamInit() end
	cam.CameraType = Enum.CameraType.Scriptable

	local move = Vector3.new(0, 0, 0)
	if fc.keys.W then move = move + Vector3.new(0, 0, -1) end
	if fc.keys.S then move = move + Vector3.new(0, 0, 1) end
	if fc.keys.A then move = move + Vector3.new(-1, 0, 0) end
	if fc.keys.D then move = move + Vector3.new(1, 0, 0) end
	if fc.keys.Space then move = move + Vector3.new(0, 1, 0) end
	if fc.keys.Shift then move = move + Vector3.new(0, -1, 0) end

	local cf = CFrame.new(fc.pos) * CFrame.fromEulerAnglesYXZ(fc.pitch, fc.yaw, 0)
	if move.Magnitude > 0 then
		local speed = cfg.speed * (fc.keys.Shift and 2.5 or 1)
		fc.pos = fc.pos + cf:VectorToWorldSpace(move.Unit) * speed * dt
		cf = CFrame.new(fc.pos) * CFrame.fromEulerAnglesYXZ(fc.pitch, fc.yaw, 0)
	end
	cam.CFrame = cf
end

UserInputService.InputBegan:Connect(function(input, processed)
	if processed then return end
	local t = input.KeyCode
	if t == Enum.KeyCode.W then fc.keys.W = true
	elseif t == Enum.KeyCode.S then fc.keys.S = true
	elseif t == Enum.KeyCode.A then fc.keys.A = true
	elseif t == Enum.KeyCode.D then fc.keys.D = true
	elseif t == Enum.KeyCode.Space then fc.keys.Space = true
	elseif t == Enum.KeyCode.LeftShift then fc.keys.Shift = true end
	if input.UserInputType == Enum.UserInputType.MouseButton2 then fc.looking = true end
end)

UserInputService.InputEnded:Connect(function(input)
	local t = input.KeyCode
	if t == Enum.KeyCode.W then fc.keys.W = nil
	elseif t == Enum.KeyCode.S then fc.keys.S = nil
	elseif t == Enum.KeyCode.A then fc.keys.A = nil
	elseif t == Enum.KeyCode.D then fc.keys.D = nil
	elseif t == Enum.KeyCode.Space then fc.keys.Space = nil
	elseif t == Enum.KeyCode.LeftShift then fc.keys.Shift = nil end
	if input.UserInputType == Enum.UserInputType.MouseButton2 then fc.looking = false end
end)

UserInputService.InputChanged:Connect(function(input)
	if not CFG.freecam.enabled or not fc.looking then return end
	if input.UserInputType == Enum.UserInputType.MouseMovement then
		fc.yaw = fc.yaw - input.Delta.X * 0.004
		fc.pitch = math.clamp(fc.pitch - input.Delta.Y * 0.004, -math.rad(89), math.rad(89))
	end
end)

-- =========================================================================
-- КАСТОМНЫЙ ПРИЦЕЛ
-- =========================================================================
local function updateCrosshair()
	ensureCrosshair()
	local cfg = CFG.crosshair
	crossRoot.Visible = cfg.enabled
	if not cfg.enabled then return end
	local s, t = cfg.size, cfg.thickness
	local gap = 4
	for i = 1, 4 do crossLines[i].Visible = false end
	crossRing.Visible = false
	if cfg.style == "Cross" then
		crossLines[1].Visible = true
		crossLines[1].Position = UDim2.fromOffset(-(gap + s), -t / 2)
		crossLines[1].Size = UDim2.fromOffset(s, t)
		crossLines[2].Visible = true
		crossLines[2].Position = UDim2.fromOffset(gap, -t / 2)
		crossLines[2].Size = UDim2.fromOffset(s, t)
		crossLines[3].Visible = true
		crossLines[3].Position = UDim2.fromOffset(-t / 2, -(gap + s))
		crossLines[3].Size = UDim2.fromOffset(t, s)
		crossLines[4].Visible = true
		crossLines[4].Position = UDim2.fromOffset(-t / 2, gap)
		crossLines[4].Size = UDim2.fromOffset(t, s)
	elseif cfg.style == "Dot" then
		crossLines[1].Visible = true
		crossLines[1].Position = UDim2.fromOffset(-t / 2, -t / 2)
		crossLines[1].Size = UDim2.fromOffset(t, t)
	elseif cfg.style == "Circle" then
		crossRing.Visible = true
		crossRing.Position = UDim2.fromOffset(-s, -s)
		crossRing.Size = UDim2.fromOffset(s * 2, s * 2)
		crossRing:FindFirstChildOfClass("UIStroke").Color = cfg.color
		crossRing:FindFirstChildOfClass("UIStroke").Thickness = t
	else -- X
		crossLines[1].Visible = true
		crossLines[1].Position = UDim2.fromOffset(-s, -t / 2)
		crossLines[1].Size = UDim2.fromOffset(s * 2, t)
		crossLines[1].Rotation = 45
		crossLines[2].Visible = true
		crossLines[2].Position = UDim2.fromOffset(-s, -t / 2)
		crossLines[2].Size = UDim2.fromOffset(s * 2, t)
		crossLines[2].Rotation = -45
	end
	for i = 1, 4 do crossLines[i].BackgroundColor3 = cfg.color end
end

-- =========================================================================
-- ГЛАВНЫЙ ЦИКЛ
-- =========================================================================
local function onRender(_, dt)
	updateSilent()
	updateAim()
	updateFovRing()
	updateTrigger()
	updateEsp()
	applyMovement()
	applyWorld()
	applyThirdPersonRestore()
	scanOverlays()
	updateCrosshair()
	updateFreecam(dt)
end

-- =========================================================================
-- МЕНЮ
-- =========================================================================
Win = Library:AddWindow("Neverlose", "", "BloxStrike")
Win:SetScale("Auto")
Win:AddTabLabel("Aimbot")

-- ---------------- RAGE ----------------
local RageTab = Win:AddTab("Rage", "crosshair")

local Main = RageTab:AddSection("Main", "left")
local AimToggle = Main:AddToggle("Enabled", false, function(v) CFG.aim.enabled = v end)
AimToggle:SetTooltip("Rage aimbot. Бинд ставится ПКМ -> New Hotkey")
local AimSet = AimToggle:AddSettings()
AimSet:AddSlider("Field of View", 20, 600, 140, function(v) CFG.aim.fov = v end, " px")
AimSet:AddDropdown("Priority", { "FOV", "Distance", "Health" }, "FOV", function(v) CFG.aim.priority = v end)
AimSet:AddColorpicker("FOV Circle", Color3.fromRGB(255, 255, 255), function(c) CFG.aim.fovColor = c end)
AimSet:AddToggle("Show FOV Circle", true, function(v) CFG.aim.showFov = v end)
Main:AddDropdown("Method", { "Camera", "Mouse" }, "Camera", function(v) CFG.aim.method = v end)
Main:AddDropdown("Hitbox", { "Head", "Chest", "Stomach", "Nearest" }, "Head", function(v) CFG.aim.hitbox = v end)
Main:AddSlider("Smoothing", 0, 100, 35, function(v) CFG.aim.smoothing = v end, " %")
Main:AddToggle("Visible Check", true, function(v) CFG.aim.visibleOnly = v end)
Main:AddToggle("Team Check", true, function(v) CFG.aim.teamCheck = v end)
Main:AddSlider("Max Distance", 100, 5000, 2500, function(v) CFG.aim.maxDist = v end, " st")

local SilentSec = RageTab:AddSection("Silent Aim", "left")
local SilentToggle = SilentSec:AddToggle("Enabled", false, function(v) CFG.silent.enabled = v end)
SilentToggle:SetTooltip("Хук FireServer/mouse.Hit: пуля летит в цель без поворота камеры")
local SilentSet = SilentToggle:AddSettings()
SilentSet:AddSlider("Hit Chance", 0, 100, 100, function(v) CFG.silent.chance = v end, " %")
SilentSet:AddDropdown("Hitbox", { "Head", "Chest", "Stomach", "Nearest" }, "Head", function(v) CFG.silent.hitbox = v end)
SilentSec:AddToggle("Visible Check", true, function(v) CFG.silent.visibleOnly = v end)
SilentSec:AddToggle("Team Check", true, function(v) CFG.silent.teamCheck = v end)
SilentSec:AddSlider("Max Distance", 100, 5000, 1500, function(v) CFG.silent.maxDist = v end, " st")

local TrigSec = RageTab:AddSection("Triggerbot", "right")
local TrigToggle = TrigSec:AddToggle("Enabled", false, function(v) CFG.trigger.enabled = v end)
TrigToggle:SetTooltip("Стреляет, когда прицел на враге")
local TrigSet = TrigToggle:AddSettings()
TrigSet:AddSlider("Delay", 0, 500, 80, function(v) CFG.trigger.delay = v end, " ms")
TrigSet:AddSlider("Hit Chance", 0, 100, 100, function(v) CFG.trigger.chance = v end, " %")
TrigSec:AddDropdown("Hitbox", { "All", "Head", "Chest", "Stomach", "Nearest" }, "All", function(v) CFG.trigger.hitbox = v end)
TrigSec:AddToggle("Team Check", true, function(v) CFG.trigger.teamCheck = v end)

local OtherSec = RageTab:AddSection("Other", "right")
OtherSec:AddToggle("Silent Aim Hooks", true, function(v)
	if v and not silentAvailable then setupSilentHooks() end
end):SetTooltip("Включает перехват выстрелов. Требует getrawmetatable")

-- ---------------- LEGIT ----------------
local LegitTab = Win:AddTab("Legit", "mouse")
local LegitMain = LegitTab:AddSection("Aim Assist", "left")
local LegitToggle = LegitMain:AddToggle("Enabled", false, function(v) CFG.legit.enabled = v end)
LegitToggle:SetTooltip("Мягкий аим. Бинд: ПКМ -> New Hotkey (режим Hold = удержание)")
local LegitSet = LegitToggle:AddSettings()
LegitSet:AddSlider("Field of View", 5, 300, 60, function(v) CFG.legit.fov = v end, " px")
LegitSet:AddSlider("Smoothing", 0, 100, 75, function(v) CFG.legit.smoothing = v end, " %")
LegitSet:AddDropdown("Priority", { "FOV", "Distance", "Health" }, "FOV", function(v) CFG.legit.priority = v end)
LegitSet:AddToggle("Show FOV Circle", false, function(v) CFG.legit.showFov = v end)
LegitMain:AddDropdown("Hitbox", { "Head", "Chest", "Stomach", "Nearest" }, "Nearest", function(v) CFG.legit.hitbox = v end)
LegitMain:AddToggle("Visible Check", true, function(v) CFG.legit.visibleOnly = v end)
LegitMain:AddToggle("Team Check", true, function(v) CFG.legit.teamCheck = v end)
LegitMain:AddSlider("Max Distance", 100, 5000, 1500, function(v) CFG.legit.maxDist = v end, " st")

-- ---------------- VISUALS ----------------
Win:AddTabLabel("Common")
local VisTab = Win:AddTab("Visuals", "image")
local VisPlayer = VisTab:AddSubTab("Players", "user")

local PlayerEnemy = VisPlayer:AddSection("Enemy", "left")
local EspToggle = PlayerEnemy:AddToggle("Enabled", false, function(v) CFG.esp.enabled = v end)
EspToggle:SetTooltip("Боксы, имена, хп, дистанция на врагах")
local EspSet = EspToggle:AddSettings()
EspSet:AddSlider("Max Distance", 100, 5000, 2000, function(v) CFG.esp.maxDist = v end, " st")
EspSet:AddDropdown("Box Style", { "Default", "Corners", "Filled" }, "Default", function(v) CFG.esp.box = v end)
EspSet:AddColorpicker("Box Color", Color3.fromRGB(255, 255, 255), function(c) CFG.esp.boxColor = c end)
EspSet:AddToggle("Show Teammates", false, function(v) CFG.esp.teammates = v end)
PlayerEnemy:AddToggle("Name", true, function(v) CFG.esp.name = v end)
PlayerEnemy:AddToggle("Health Bar", true, function(v) CFG.esp.health = v end)
PlayerEnemy:AddToggle("Distance", true, function(v) CFG.esp.distance = v end)
PlayerEnemy:AddToggleColorpicker("Tracers", false, Color3.fromRGB(255, 255, 255),
	function(v) CFG.esp.tracer = v end, function(c) CFG.esp.tracerColor = c end)
PlayerEnemy:AddToggleColorpicker("Offscreen Arrow", false, Color3.fromRGB(255, 80, 80),
	function(v) CFG.esp.arrow = v end, function(c) CFG.esp.arrowColor = c end)

local PlayerModel = VisPlayer:AddSection("Enemy Model", "left")
PlayerModel:AddDropdownColorpicker("Player", { "Disabled", "Chams", "Wireframe", "Flat" }, Color3.fromRGB(120, 150, 255),
	function(o) CFG.esp.visMode = o end, function(c) CFG.esp.visColor = c end)
PlayerModel:AddDropdownColorpicker("Behind Walls", { "Disabled", "Chams", "Wireframe", "Flat" }, Color3.fromRGB(80, 255, 200),
	function(o) CFG.esp.wallMode = o end, function(c) CFG.esp.wallColor = c end)

local PlayerTeam = VisPlayer:AddSection("Teammate", "right")
local TeamToggle = PlayerTeam:AddToggle("Enabled", false, function(v) CFG.teamEsp.enabled = v end)
TeamToggle:AddSettings():AddColorpicker("Box Color", Color3.fromRGB(220, 225, 255), function(c) CFG.teamEsp.color = c end)
local PlayerTeamModel = VisPlayer:AddSection("Teammate Model", "right")
PlayerTeamModel:AddDropdownColorpicker("Player", { "Disabled", "Chams", "Wireframe", "Flat" }, Color3.fromRGB(220, 225, 255),
	function(o) CFG.teamEsp.visMode = o end, function(c) CFG.teamEsp.visColor = c end)
PlayerTeamModel:AddDropdownColorpicker("Behind Walls", { "Disabled", "Chams", "Wireframe", "Flat" }, Color3.fromRGB(255, 210, 180),
	function(o) CFG.teamEsp.wallMode = o end, function(c) CFG.teamEsp.wallColor = c end)

local VisWorld = VisTab:AddSubTab("World", "earth")
local WorldView = VisWorld:AddSection("View", "left")
WorldView:AddToggle("Force FOV", false, function(v) CFG.world.forceFov = v end)
WorldView:AddSlider("FOV", 60, 120, 90, function(v) CFG.world.fov = v end, "°")
local ThirdPerson = WorldView:AddToggle("Third Person", false, function(v)
	if v and not savedCam then
		savedCam = {
			mode = LocalPlayer.CameraMode,
			maxZoom = LocalPlayer.CameraMaxZoomDistance,
			minZoom = LocalPlayer.CameraMinZoomDistance,
		}
	end
	CFG.world.thirdPerson = v
end)
ThirdPerson:AddSettings():AddSlider("Distance", 20, 300, 120, function(v) CFG.world.tpDist = v end, " st")

local WorldLight = VisWorld:AddSection("Lighting", "right")
WorldLight:AddToggle("Fullbright", false, function(v) CFG.world.fullbright = v end)
WorldLight:AddToggle("Remove Fog", false, function(v) CFG.world.removeFog = v end)
WorldLight:AddToggle("Remove Blur", false, function(v) CFG.world.removeBlur = v end)
WorldLight:AddToggle("Remove Sun Rays", false, function(v) CFG.world.removeSun = v end)

local WorldHud = VisWorld:AddSection("HUD", "right")
local CrossToggle = WorldHud:AddToggle("Custom Crosshair", false, function(v) CFG.crosshair.enabled = v end)
local CrossSet = CrossToggle:AddSettings()
CrossSet:AddDropdown("Style", { "Cross", "Dot", "Circle", "X" }, "Cross", function(v) CFG.crosshair.style = v end)
CrossSet:AddColorpicker("Color", Color3.fromRGB(0, 255, 0), function(c) CFG.crosshair.color = c end)
CrossSet:AddSlider("Size", 2, 40, 10, function(v) CFG.crosshair.size = v end, " px")
CrossSet:AddSlider("Thickness", 1, 8, 2, function(v) CFG.crosshair.thickness = v end, " px")

-- ---------------- MISCELLANEOUS ----------------
local MiscTab = Win:AddTab("Miscellaneous", "gear")
local MiscMovement = MiscTab:AddSection("Movement", "left")
MiscMovement:AddToggle("Bunny Hop", false, function(v) CFG.misc.bhop = v end)
local SpeedToggle = MiscMovement:AddToggle("Speed", false, function(v) CFG.misc.speed = v end)
SpeedToggle:AddSettings():AddSlider("Value", 16, 200, 24, function(v) CFG.misc.speedVal = v end)
local JumpToggle = MiscMovement:AddToggle("Jump Power", false, function(v) CFG.misc.jump = v end)
JumpToggle:AddSettings():AddSlider("Value", 50, 300, 50, function(v) CFG.misc.jumpVal = v end)
MiscMovement:AddToggle("Noclip", false, function(v) CFG.misc.noclip = v end)
MiscMovement:AddToggle("No Fall Damage", false, function(v) CFG.misc.noFall = v end)

local MiscFeatures = MiscTab:AddSection("Features", "right")
MiscFeatures:AddToggle("Prevent AFK Kick", false, function(v) CFG.misc.antiafk = v end)
MiscFeatures:AddToggle("Free Cam", false, function(v)
	CFG.freecam.enabled = v
	if v then fc.inited = false end
end):SetTooltip("WASD + Space/Shift движение, ПКМ - обзор")
local FcSpeed = MiscFeatures:AddSlider("Freecam Speed", 5, 300, 45, function(v) CFG.freecam.speed = v end)
MiscFeatures:AddToggle("Unlock Spectating", false, function(v)
	if v then pcall(function() LocalPlayer.CameraMode = Enum.CameraMode.Classic end) end
end)

-- ---------------- INVENTORY (UI как в CS2) ----------------
local InvTab = Win:AddTab("Inventory", "layers")
InvTab:AddLoadout({
	team = "CT",
	onSelect = function(team, category, index, name) print("[loadout]", team, category, index, name) end,
	onTeam = function(team) print("[loadout] team", team) end,
})

-- ---------------- WATERMARK ----------------
Win:SetWatermark({
	positionPreset = "Top Right",
	show = { logo = true, name = true, ping = true, user = true, speed = false, time = false, fps = false, ram = false },
	order = { "logo", "name", "ping", "user", "speed", "time", "fps", "ram" },
})

print("[cheat] loaded - RShift: menu")

-- движки стартуют только после успешного построения меню
RunService:BindToRenderStep("NL_Cheat_Main", Enum.RenderPriority.Camera.Value + 1, onRender)
setupSilentHooks()
