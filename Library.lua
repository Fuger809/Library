-- ModeGUI Library | окно, вкладки, элементы, темы
-- local Library = loadstring(game:HttpGet(".../Library.lua"))()

local Players = game:GetService("Players")
local UIS = game:GetService("UserInputService")
local Tween = game:GetService("TweenService")
local LocalPlayer = Players.LocalPlayer

local Library = { Version = "1.0.0", Options = {}, Themes = {}, Unloaded = false }
local genv = typeof(getgenv) == "function" and getgenv() or nil

-- ===== темы =====
local H = Color3.fromHex
local function theme(name, bg, card, accent, on, text, mute, sky)
	return {
		name = name, bg = bg, card = card, accent = accent, on = on, text = text, mute = mute, sky = sky,
		soft = bg:Lerp(accent, 0.28), off = card:Lerp(text, 0.14), danger = H("FB7185"),
	}
end

Library.Themes = {
	theme("Midnight", H("101117"), H("1C1E28"), H("818CF8"), H("34D399"), H("F6F7FB"), H("9499AA"),
		{ H("101117"), H("2E3054"), H("818CF8") }),
	theme("Snow Village", H("241C2A"), H("33283B"), H("F4A6C0"), H("FFC48A"), H("FFF0F5"), H("C6A6B8"),
		{ H("5E6E86"), H("E9B7CF"), H("FFD9A8") }),
	theme("Pink Fog", H("2C1621"), H("3F2030"), H("FF5C9A"), H("FF9BC0"), H("FFE6EE"), H("D29AAE"),
		{ H("7A2E45"), H("E0607F"), H("FFC3D3") }),
	theme("Meadow", H("EAF1FB"), H("FFFFFF"), H("B56CD1"), H("6DBE5A"), H("2B3250"), H("7480A0"),
		{ H("8FB4E3"), H("D58FD8"), H("8CCB5E") }),
	theme("Lavender", H("231D3F"), H("322A55"), H("B39DFF"), H("FF9EC4"), H("F3EEFF"), H("A99FD3"),
		{ H("8A6FD8"), H("C9A8F0"), H("FF9FB8") }),
	theme("Magenta Haze", H("2A0D2F"), H("3F1546"), H("E64FD8"), H("FF7EE8"), H("FFE8FC"), H("C690C6"),
		{ H("F05CC8"), H("C86ADB"), H("E8C8F0") }),
}

local C = Library.Themes[1]
Library.Theme = C.name

local painted, onTheme, onUnload, conns = {}, {}, {}, {}
local F = { reg = Enum.Font.Gotham, med = Enum.Font.GothamMedium, bold = Enum.Font.GothamBold }
Library.Fonts = F

function Library:Hook(c)
	table.insert(conns, c)
	return c
end

function Library:OnTheme(fn) table.insert(onTheme, fn) end
function Library:OnUnload(fn) table.insert(onUnload, fn) end
function Library:GetTheme() return C end

function Library:ThemeByName(name)
	for _, t in ipairs(self.Themes) do
		if t.name == name then return t end
	end
	return self.Themes[1]
end

function Library:SetTheme(t)
	C = type(t) == "table" and t or self:ThemeByName(t)
	self.Theme = C.name
	local keep = {}
	for _, p in ipairs(painted) do
		if p[1].Parent then
			p[1][p[2]] = C[p[3]]
			table.insert(keep, p)
		end
	end
	painted = keep
	for _, f in ipairs(onTheme) do f() end
end

-- строка "$key" в свойстве = цвет из текущей темы, перекрашивается при смене темы
local function new(class, props, parent)
	local inst = Instance.new(class)
	for k, v in pairs(props) do
		if k == "Corner" then
			Instance.new("UICorner", inst).CornerRadius = UDim.new(0, v)
		elseif k == "Stroke" then
			new("UIStroke", { Color = "$text", Transparency = v, ApplyStrokeMode = Enum.ApplyStrokeMode.Border }, inst)
		else
			if type(v) == "string" and v:sub(1, 1) == "$" and C[v:sub(2)] ~= nil then
				table.insert(painted, { inst, k, v:sub(2) })
				v = C[v:sub(2)]
			end
			inst[k] = v
		end
	end
	inst.Parent = parent
	return inst
end

local function label(parent, text, size, color, font, props)
	props = props or {}
	props.BackgroundTransparency = 1
	props.Text = text
	props.TextSize = size
	props.TextColor3 = color
	props.Font = font
	props.TextXAlignment = props.TextXAlignment or Enum.TextXAlignment.Left
	props.TextTruncate = props.TextTruncate or Enum.TextTruncate.AtEnd
	return new("TextLabel", props, parent)
end

Library.new, Library.label = new, label

local function isPress(i)
	return i.UserInputType == Enum.UserInputType.MouseButton1 or i.UserInputType == Enum.UserInputType.Touch
end

local function isMove(i)
	return i.UserInputType == Enum.UserInputType.MouseMovement or i.UserInputType == Enum.UserInputType.Touch
end

local function hasText(s) return type(s) == "string" and s ~= "" end

-- заголовок и описание в карточке; right = место справа под переключатель/поле
function Library.Caption(f, title, desc, right)
	if hasText(desc) then
		label(f, title or "", 14, "$text", F.med, { Position = UDim2.fromOffset(14, 12), Size = UDim2.new(1, -right, 0, 18) })
		label(f, desc, 12, "$mute", F.reg, { Position = UDim2.fromOffset(14, 30), Size = UDim2.new(1, -right, 0, 14) })
	else
		label(f, title or "", 14, "$text", F.med, { Position = UDim2.fromOffset(14, 12), Size = UDim2.new(1, -right, 0, 22) })
	end
end
local caption = Library.Caption

local notifyFn
function Library:Notify(text, duration)
	if notifyFn then notifyFn(tostring(text), duration or 2.2) else print(text) end
end

-- ===== опции: Library.Options[id].Value / :SetValue(v) / :OnChanged(fn) =====
local function option(id, o, kind, default)
	local opt = { Type = kind, Value = default, Callbacks = {} }
	if o.Callback then table.insert(opt.Callbacks, o.Callback) end
	function opt:OnChanged(fn) table.insert(self.Callbacks, fn) end
	function opt:Fire()
		for _, f in ipairs(self.Callbacks) do task.spawn(f, self.Value) end
	end
	if id then Library.Options[id] = opt end
	return opt
end

-- ===== вкладка =====
local tw = TweenInfo.new(0.16, Enum.EasingStyle.Quart)
local Tab = {}
Tab.__index = Tab

function Tab:AddCard(h)
	self.Order += 1
	return new("Frame", {
		LayoutOrder = self.Order, Size = UDim2.new(1, 0, 0, h),
		BackgroundColor3 = "$card", BorderSizePixel = 0, Corner = 12, Stroke = 0.9,
	}, self.Page)
end

function Tab:AddContainer()
	self.Order += 1
	return new("Frame", {
		LayoutOrder = self.Order, Size = UDim2.fromScale(1, 0),
		AutomaticSize = Enum.AutomaticSize.Y, BackgroundTransparency = 1,
	}, self.Page)
end

function Tab:AddParagraph(o)
	local f = self:AddCard(0)
	f.AutomaticSize = Enum.AutomaticSize.Y
	new("UIPadding", {
		PaddingTop = UDim.new(0, 12), PaddingBottom = UDim.new(0, 12), PaddingLeft = UDim.new(0, 14), PaddingRight = UDim.new(0, 14),
	}, f)
	new("UIListLayout", { Padding = UDim.new(0, 4), SortOrder = Enum.SortOrder.LayoutOrder }, f)
	local t = label(f, o.Title or "", 14, "$text", F.med, { LayoutOrder = 1, Size = UDim2.new(1, 0, 0, 18) })
	local c = label(f, o.Content or "", 12, "$mute", F.reg, {
		LayoutOrder = 2, Size = UDim2.fromScale(1, 0), AutomaticSize = Enum.AutomaticSize.Y,
		TextWrapped = true, TextTruncate = Enum.TextTruncate.None,
	})
	return {
		SetTitle = function(_, s) t.Text = s end,
		SetContent = function(_, s) c.Text = s end,
	}
end

function Tab:AddButton(o)
	local f = self:AddCard(hasText(o.Description) and 64 or 46)
	caption(f, o.Title, o.Description, 50)
	label(f, "›", 20, "$mute", F.bold, {
		AnchorPoint = Vector2.new(1, 0.5), Position = UDim2.new(1, -16, 0.5, 0), Size = UDim2.fromOffset(20, 24),
		TextXAlignment = Enum.TextXAlignment.Right,
	})
	local b = new("TextButton", { Size = UDim2.fromScale(1, 1), BackgroundTransparency = 1, AutoButtonColor = false, Text = "" }, f)
	b.MouseEnter:Connect(function() f.BackgroundColor3 = C.soft end)
	b.MouseLeave:Connect(function() f.BackgroundColor3 = C.card end)
	b.MouseButton1Click:Connect(function()
		if o.Callback then task.spawn(o.Callback) end
	end)
	return b
end

function Tab:AddToggle(id, o)
	local f = self:AddCard(hasText(o.Description) and 64 or 46)
	caption(f, o.Title, o.Description, 80)
	local track = new("TextButton", {
		AnchorPoint = Vector2.new(1, 0.5), Position = UDim2.new(1, -14, 0.5, 0), Size = UDim2.fromOffset(46, 26),
		AutoButtonColor = false, Text = "", Corner = 13,
	}, f)
	local knob = new("Frame", {
		AnchorPoint = Vector2.new(0.5, 0.5), Size = UDim2.fromOffset(20, 20),
		BackgroundColor3 = Color3.new(1, 1, 1), BorderSizePixel = 0, Corner = 10,
	}, track)

	local opt = option(id, o, "Toggle", o.Default == true)
	local function paint(animate)
		local pos = opt.Value and UDim2.new(1, -13, 0.5, 0) or UDim2.new(0, 13, 0.5, 0)
		local col = opt.Value and C.on or C.off
		if animate then
			Tween:Create(knob, tw, { Position = pos }):Play()
			Tween:Create(track, tw, { BackgroundColor3 = col }):Play()
		else
			knob.Position, track.BackgroundColor3 = pos, col
		end
	end
	function opt:SetValue(v)
		self.Value = v == true
		paint(true)
		self:Fire()
	end
	Library:OnTheme(paint)
	paint()
	track.MouseButton1Click:Connect(function() opt:SetValue(not opt.Value) end)
	return opt
end

function Tab:AddSlider(id, o)
	local minV, maxV = o.Min or 0, o.Max or 100
	local mult = 10 ^ (o.Rounding or 0)
	local f = self:AddCard(hasText(o.Description) and 84 or 68)
	caption(f, o.Title, o.Description, 90)
	local box = new("TextBox", {
		AnchorPoint = Vector2.new(1, 0), Position = UDim2.new(1, -12, 0, 12), Size = UDim2.fromOffset(58, 24),
		BackgroundColor3 = "$bg", TextColor3 = "$text", Font = F.med, TextSize = 13, ClearTextOnFocus = false, Corner = 8,
	}, f)
	local hit = new("TextButton", {
		Position = UDim2.new(0, 14, 1, -30), Size = UDim2.new(1, -28, 0, 20),
		BackgroundTransparency = 1, AutoButtonColor = false, Text = "",
	}, f)
	local track = new("Frame", {
		AnchorPoint = Vector2.new(0, 0.5), Position = UDim2.fromScale(0, 0.5), Size = UDim2.new(1, 0, 0, 4),
		BackgroundColor3 = "$off", BorderSizePixel = 0, Corner = 4,
	}, hit)
	local fill = new("Frame", { Size = UDim2.fromScale(0, 1), BackgroundColor3 = "$accent", BorderSizePixel = 0, Corner = 4 }, track)
	local knob = new("Frame", {
		AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.fromScale(0, 0.5), Size = UDim2.fromOffset(14, 14),
		BackgroundColor3 = Color3.new(1, 1, 1), BorderSizePixel = 0, Corner = 7,
	}, track)
	new("UIStroke", { Color = "$accent", Thickness = 1.5 }, knob)

	local opt = option(id, o, "Slider", math.clamp(o.Default or minV, minV, maxV))
	local function draw()
		local a = (opt.Value - minV) / (maxV - minV)
		fill.Size = UDim2.fromScale(a, 1)
		knob.Position = UDim2.fromScale(a, 0.5)
		box.Text = tostring(opt.Value)
	end
	function opt:SetValue(n)
		n = tonumber(n)
		if n then
			n = math.clamp(math.floor(n * mult + 0.5) / mult, minV, maxV)
			if n ~= self.Value then
				self.Value = n
				self:Fire()
			end
		end
		draw()
	end

	local sliding = false
	local function at(x)
		local w = track.AbsoluteSize.X
		if w > 0 then opt:SetValue(minV + (maxV - minV) * math.clamp((x - track.AbsolutePosition.X) / w, 0, 1)) end
	end
	hit.InputBegan:Connect(function(i)
		if isPress(i) then sliding = true at(i.Position.X) end
	end)
	Library:Hook(UIS.InputChanged:Connect(function(i)
		if sliding and isMove(i) then at(i.Position.X) end
	end))
	Library:Hook(UIS.InputEnded:Connect(function(i)
		if isPress(i) then sliding = false end
	end))
	box.FocusLost:Connect(function() opt:SetValue(box.Text) end)
	draw()
	return opt
end

function Tab:AddInput(id, o)
	local f = self:AddCard(hasText(o.Description) and 92 or 76)
	caption(f, o.Title, o.Description, 28)
	local box = new("TextBox", {
		Position = UDim2.new(0, 12, 1, -40), Size = UDim2.new(1, -24, 0, 28),
		BackgroundColor3 = "$bg", TextColor3 = "$text", PlaceholderColor3 = "$mute", PlaceholderText = o.Placeholder or "",
		Font = F.reg, TextSize = 13, TextXAlignment = Enum.TextXAlignment.Left, ClearTextOnFocus = false,
		Text = o.Default or "", Corner = 8,
	}, f)
	new("UIPadding", { PaddingLeft = UDim.new(0, 10) }, box)

	local opt = option(id, o, "Input", box.Text)
	opt.Box = box
	function opt:SetValue(s)
		self.Value = tostring(s)
		box.Text = self.Value
		self:Fire()
	end
	box.FocusLost:Connect(function() opt:SetValue(box.Text) end)
	return opt
end

-- ===== окно =====
function Library:CreateWindow(o)
	o = o or {}
	if genv and type(genv.__ModeGUI_Unload) == "function" then pcall(genv.__ModeGUI_Unload) end

	local HEADER, SIDE_W = 64, 150
	local host = LocalPlayer:WaitForChild("PlayerGui")
	if typeof(gethui) == "function" then
		local ok, h = pcall(gethui)
		if ok and typeof(h) == "Instance" then host = h end
	end
	if host:FindFirstChild("ModeGUI") then host.ModeGUI:Destroy() end

	local gui = new("ScreenGui", {
		Name = "ModeGUI", ResetOnSpawn = false, IgnoreGuiInset = true,
		DisplayOrder = 999, ZIndexBehavior = Enum.ZIndexBehavior.Sibling,
	}, host)

	local win = new("Frame", {
		AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.fromScale(0.5, 0.5),
		Size = o.Size or UDim2.fromOffset(580, 460), BackgroundColor3 = "$bg",
		Active = true, ClipsDescendants = true, Corner = 18, Stroke = 0.85,
	}, gui)
	local scale = new("UIScale", { Scale = 0.94 }, win)

	local header = new("Frame", { Size = UDim2.new(1, 0, 0, HEADER), BackgroundTransparency = 1 }, win)
	local dragZone = new("TextButton", {
		Size = UDim2.new(1, -96, 1, 0), BackgroundTransparency = 1, AutoButtonColor = false, Text = "",
	}, header)
	label(header, o.Title or "ModeGUI", 17, "$text", F.bold, { Position = UDim2.fromOffset(20, 12), Size = UDim2.new(1, -120, 0, 22) })
	label(header, o.SubTitle or "", 12, "$mute", F.reg, { Position = UDim2.fromOffset(20, 34), Size = UDim2.new(1, -120, 0, 16) })
	new("Frame", {
		Position = UDim2.new(0, 18, 1, -1), Size = UDim2.new(1, -36, 0, 1),
		BackgroundColor3 = "$text", BackgroundTransparency = 0.9, BorderSizePixel = 0,
	}, header)

	local function iconBtn(text, x, hoverKey)
		local b = new("TextButton", {
			AnchorPoint = Vector2.new(1, 0.5), Position = UDim2.new(1, x, 0.5, 0), Size = UDim2.fromOffset(30, 30),
			BackgroundColor3 = "$card", TextColor3 = "$mute", AutoButtonColor = false,
			Font = F.bold, TextSize = 16, Text = text, Corner = 10,
		}, header)
		b.MouseEnter:Connect(function() b.BackgroundColor3, b.TextColor3 = C[hoverKey], C.text end)
		b.MouseLeave:Connect(function() b.BackgroundColor3, b.TextColor3 = C.card, C.mute end)
		return b
	end
	local btnMin = iconBtn("–", -52, "soft")
	local btnClose = iconBtn("×", -14, "danger")

	local side = new("ScrollingFrame", {
		Position = UDim2.fromOffset(0, HEADER), Size = UDim2.new(0, SIDE_W, 1, -HEADER),
		BackgroundTransparency = 1, BorderSizePixel = 0,
		CanvasSize = UDim2.new(), AutomaticCanvasSize = Enum.AutomaticSize.Y,
		ScrollBarThickness = 3, ScrollBarImageColor3 = "$accent",
		ScrollingDirection = Enum.ScrollingDirection.Y,
		VerticalScrollBarInset = Enum.ScrollBarInset.None,
	}, win)
	new("UIListLayout", { Padding = UDim.new(0, 4), SortOrder = Enum.SortOrder.LayoutOrder }, side)
	new("UIPadding", { PaddingLeft = UDim.new(0, 12), PaddingTop = UDim.new(0, 14) }, side)
	label(side, "РАЗДЕЛЫ", 11, "$mute", F.bold, { LayoutOrder = 0, Size = UDim2.new(1, -24, 0, 16) })
	new("Frame", {
		Position = UDim2.fromOffset(SIDE_W, HEADER), Size = UDim2.new(0, 1, 1, -HEADER),
		BackgroundColor3 = "$text", BackgroundTransparency = 0.92, BorderSizePixel = 0,
	}, win)

	local content = new("Frame", {
		Position = UDim2.fromOffset(SIDE_W, HEADER), Size = UDim2.new(1, -SIDE_W, 1, -HEADER), BackgroundTransparency = 1,
	}, win)
	local pageTitle = label(content, "", 18, "$text", F.bold, { Position = UDim2.fromOffset(18, 14), Size = UDim2.new(1, -36, 0, 22) })
	local pageHint = label(content, "", 13, "$mute", F.reg, { Position = UDim2.fromOffset(18, 36), Size = UDim2.new(1, -36, 0, 16) })

	local toastBox = new("Frame", {
		AnchorPoint = Vector2.new(0, 1), Position = UDim2.new(0, 16, 1, -12), Size = UDim2.new(1, -56, 0, 30),
		BackgroundColor3 = "$soft", Visible = false, ZIndex = 5, Corner = 10,
	}, content)
	local toast = label(toastBox, "", 13, "$text", F.med, {
		Position = UDim2.fromOffset(12, 0), Size = UDim2.new(1, -24, 1, 0), ZIndex = 6,
	})
	local toastId = 0
	notifyFn = function(text, duration)
		toastId += 1
		local id = toastId
		toast.Text = text
		toastBox.Visible = true
		task.delay(duration, function()
			if not Library.Unloaded and id == toastId then toastBox.Visible = false end
		end)
	end

	local grip = new("TextButton", {
		AnchorPoint = Vector2.new(1, 1), Position = UDim2.new(1, -6, 1, -4), Size = UDim2.fromOffset(18, 18),
		BackgroundTransparency = 1, AutoButtonColor = false, Font = F.bold, TextSize = 14,
		TextColor3 = "$mute", Text = "◢", ZIndex = 10,
	}, win)

	local bubble = new("TextButton", {
		Visible = false, AnchorPoint = Vector2.new(1, 1), Position = UDim2.new(1, -22, 1, -22),
		Size = UDim2.fromOffset(54, 54), BackgroundColor3 = "$bg", TextColor3 = "$text",
		AutoButtonColor = false, Font = F.bold, TextSize = 16, Text = o.Icon or (o.Title or "M"):sub(1, 1),
		ZIndex = 20, Corner = 16,
	}, gui)
	new("UIStroke", { Color = "$accent", Thickness = 1.5 }, bubble)

	local Window = { Root = win, Gui = gui, Tabs = {} }
	self.Window = Window

	-- вкладки
	local current
	local function showTab(tab)
		current = tab
		for _, t in ipairs(Window.Tabs) do
			local on = t == tab
			t.Page.Visible = on
			t.Button.BackgroundColor3 = C.soft
			t.Button.BackgroundTransparency = on and 0 or 1
			t.Button.Bar.BackgroundTransparency = on and 0 or 1
			t.Button.Caption.TextColor3 = on and C.text or C.mute
		end
		pageTitle.Text = tab.Title
		pageHint.Text = tab.Hint
	end
	Library:OnTheme(function() if current then showTab(current) end end)

	function Window:AddTab(t)
		t = t or {}
		local tab = setmetatable({ Title = t.Title or "Tab", Hint = t.Hint or t.Description or "", Order = 0 }, Tab)
		tab.Page = new("ScrollingFrame", {
			Position = UDim2.fromOffset(14, 62), Size = UDim2.new(1, -22, 1, -70),
			BackgroundTransparency = 1, BorderSizePixel = 0, Visible = false,
			CanvasSize = UDim2.new(), AutomaticCanvasSize = Enum.AutomaticSize.Y,
			ScrollBarThickness = 3, ScrollBarImageColor3 = "$accent", ScrollingDirection = Enum.ScrollingDirection.Y,
		}, content)
		new("UIListLayout", { Padding = UDim.new(0, 8), SortOrder = Enum.SortOrder.LayoutOrder }, tab.Page)
		new("UIPadding", {
			PaddingTop = UDim.new(0, 2), PaddingLeft = UDim.new(0, 2), PaddingRight = UDim.new(0, 10), PaddingBottom = UDim.new(0, 48),
		}, tab.Page)

		local b = new("TextButton", {
			LayoutOrder = #self.Tabs + 1, Size = UDim2.new(1, -12, 0, 36), BackgroundTransparency = 1,
			AutoButtonColor = false, Text = "", Corner = 10,
		}, side)
		new("Frame", {
			Name = "Bar", AnchorPoint = Vector2.new(0, 0.5), Position = UDim2.new(0, 8, 0.5, 0),
			Size = UDim2.fromOffset(3, 14), BackgroundColor3 = "$accent", BorderSizePixel = 0, Corner = 2,
		}, b)
		label(b, tab.Title, 14, C.mute, F.med, { Name = "Caption", Position = UDim2.fromOffset(20, 0), Size = UDim2.new(1, -24, 1, 0) })
		b.MouseButton1Click:Connect(function() showTab(tab) end)
		b.MouseEnter:Connect(function() if current ~= tab then b.BackgroundTransparency = 0.5 end end)
		b.MouseLeave:Connect(function() if current ~= tab then b.BackgroundTransparency = 1 end end)
		tab.Button = b

		table.insert(self.Tabs, tab)
		if not current then showTab(tab) end
		return tab
	end

	function Window:SelectTab(x)
		for i, t in ipairs(self.Tabs) do
			if x == i or x == t.Title or x == t then return showTab(t) end
		end
	end

	-- размер, масштаб, сворачивание
	local openTween
	function Window:SetScale(s)
		if openTween then openTween:Cancel() openTween = nil end
		scale.Scale = s
	end

	function Window:SetSize(w, h)
		win.Size = UDim2.fromOffset(math.clamp(w, 440, 1000), math.clamp(h, 340, 760))
	end

	function Window:Minimize(v)
		win.Visible = not v
		bubble.Visible = v
	end

	btnClose.MouseButton1Click:Connect(function() Library:Unload() end)
	btnMin.MouseButton1Click:Connect(function() Window:Minimize(true) end)
	bubble.MouseButton1Click:Connect(function() Window:Minimize(false) end)

	local mode, start, startPos, startSize
	local function begin(m)
		return function(i)
			if not isPress(i) then return end
			mode, start, startPos = m, i.Position, win.Position
			startSize = Vector2.new(win.Size.X.Offset, win.Size.Y.Offset)
		end
	end
	dragZone.InputBegan:Connect(begin("move"))
	grip.InputBegan:Connect(begin("size"))

	Library:Hook(UIS.InputChanged:Connect(function(i)
		if not mode or not isMove(i) then return end
		local d = i.Position - start
		if mode == "move" then
			win.Position = startPos + UDim2.fromOffset(d.X, d.Y)
		else
			local s = scale.Scale
			local w = math.clamp(startSize.X + d.X / s, 440, 1000)
			local h = math.clamp(startSize.Y + d.Y / s, 340, 760)
			win.Size = UDim2.fromOffset(w, h)
			win.Position = startPos + UDim2.fromOffset((w - startSize.X) * s / 2, (h - startSize.Y) * s / 2)
		end
	end))
	Library:Hook(UIS.InputEnded:Connect(function(i)
		if isPress(i) then mode = nil end
	end))

	local key = o.MinimizeKey or Enum.KeyCode.RightShift
	Library:Hook(UIS.InputBegan:Connect(function(i, typing)
		if not typing and i.KeyCode == key then Window:Minimize(win.Visible) end
	end))

	openTween = Tween:Create(scale, TweenInfo.new(0.34, Enum.EasingStyle.Quint), { Scale = 1 })
	openTween:Play()

	if genv then genv.__ModeGUI_Unload = function() Library:Unload() end end
	return Window
end

function Library:Unload()
	if self.Unloaded then return end
	self.Unloaded = true
	for _, f in ipairs(onUnload) do pcall(f) end
	for _, c in ipairs(conns) do c:Disconnect() end
	if self.Window then self.Window.Gui:Destroy() end
	if genv then genv.__ModeGUI_Unload = nil end
end

return Library
