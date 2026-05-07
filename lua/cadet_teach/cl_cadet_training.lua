re.cadet_training = re.cadet_training or {}
re.cadet_training.client = re.cadet_training.client or {}

local clientState = re.cadet_training.client

surface.CreateFont("CadetTraining_Title", { -- Обработка шрифтов
	font = "Montserrat",
	size = 28,
	weight = 700,
	antialias = true,
	extended = true,
})

surface.CreateFont("CadetTraining_Body", {
	font = "Montserrat",
	size = 19,
	weight = 500,
	antialias = true,
	extended = true,
})

surface.CreateFont("CadetTraining_Small", {
	font = "Montserrat",
	size = 16,
	weight = 450,
	antialias = true,
	extended = true,
})

surface.CreateFont("CadetTraining_HUDTitle", {
	font = "Montserrat",
	size = 24,
	weight = 700,
	antialias = true,
	extended = true,
})

local function closeMenu()
	if IsValid(clientState.menu) then
		clientState.menu:Remove()
		clientState.menu = nil
	end
	gui.EnableScreenClicker(false)
end

local function sendChoice(choice)
	closeMenu()
	netstream.Start("CadetTraining_Select", {
		choice = choice,
	})
end

local function createChoiceButton(parent, title, desc, onClick) -- Создание UI для выбора типа обучения
	local button = vgui.Create("DButton", parent)
	button:SetText("")
	button:SetTall(160)
	button.Paint = function(self, w, h)
		local hovered = self:IsHovered()
		local top = hovered and Color(48, 95, 170, 235) or Color(24, 28, 40, 230)
		local bottom = hovered and Color(36, 70, 130, 235) or Color(18, 20, 30, 230)
		draw.RoundedBox(12, 0, 0, w, h, Color(12, 14, 22, 245))
		draw.RoundedBox(12, 2, 2, w - 4, h - 4, top)
		draw.RoundedBox(12, 2, h * 0.45, w - 4, h * 0.53, bottom)
		draw.SimpleText(title, "CadetTraining_Title", w / 2, 18, Color(255, 255, 255), TEXT_ALIGN_CENTER, TEXT_ALIGN_TOP)
		draw.DrawText(desc, "CadetTraining_Small", w / 2, 64, Color(220, 225, 235), TEXT_ALIGN_CENTER)
	end
	button.DoClick = onClick
	return button
end

local function openMenu()
	closeMenu()

	local frame = vgui.Create("DFrame") -- Создание Dframe
	frame:SetSize(ScrW(), ScrH())
	frame:SetTitle("")
	frame:ShowCloseButton(false)
	frame:SetDraggable(false)
	frame:MakePopup()
	frame.Paint = function(self, w, h)
		draw.RoundedBox(0, 0, 0, w, h, Color(4, 6, 10, 190))
	end

	local container = vgui.Create("DPanel", frame)
	container:SetSize(math.min(1320, ScrW() - 80), 460)
	container:Center()
	container.Paint = function(self, w, h)
		draw.RoundedBox(14, 0, 0, w, h, Color(10, 14, 22, 245))
		draw.RoundedBox(14, 2, 2, w - 4, h - 4, Color(14, 18, 30, 235))
		draw.RoundedBox(14, 8, 8, w - 16, 68, Color(26, 52, 92, 220))
		surface.SetDrawColor(90, 115, 170, 220)
		surface.DrawLine(20, 82, w - 20, 82)
	end

	local header = vgui.Create("DLabel", container)
	header:Dock(TOP)
	header:DockMargin(16, 20, 16, 6)
	header:SetTall(44)
	header:SetFont("CadetTraining_Title")
	header:SetText("Автоматическое обучение кадетов")
	header:SetTextColor(Color(255, 255, 255))
	header:SetContentAlignment(5)

	local info = vgui.Create("DLabel", container) -- Контейнер для текста
	local infoPanel = vgui.Create("DPanel", container)
	infoPanel:Dock(TOP)
	infoPanel:DockMargin(32, 8, 32, 16)
	infoPanel:SetTall(110)
	infoPanel.Paint = function(self, w, h)
		draw.RoundedBox(12, 0, 0, w, h, Color(18, 22, 34, 230))
		draw.RoundedBox(12, 2, 2, w - 4, h - 4, Color(24, 28, 42, 220))
		surface.SetDrawColor(90, 130, 200, 180)
		surface.DrawOutlinedRect(0, 0, w, h, 1)
	end

	info:Dock(FILL)
	info:DockMargin(16, 12, 16, 12)
	info:SetFont("CadetTraining_Body")
	info:SetText("Выберите вариант подготовки. Система проведет вас через ключевые объекты базы,\n" ..
		"покажет контрольные точки и завершит обучение переводом в назначенную профессию.\n" ..
		"Вы всегда можете пройти обучение повторно по команде супер-администратора.")
	info:SetTextColor(Color(210, 210, 210))
	info:SetContentAlignment(5)
	info:SetParent(infoPanel)

	local layout = vgui.Create("DPanel", container)
	layout:Dock(FILL)
	layout:DockMargin(20, 0, 20, 20)
	layout.Paint = nil

	local button1 = createChoiceButton(layout, "Начинающий", "Вы только прибыли во вселенную\nзвездных войн в Garry`s mod.\nПроходите полное обучение.", function() -- Кнопки сложностей (Для выбора направления обучения)
		sendChoice(1)
	end)

	local button2 = createChoiceButton(layout, "Профессионал", "Вы уже обучены базовым основам.\nБудет проведено лишь мелкое обучение\nбез вступительного этапа.", function()
		sendChoice(2)
	end)

	local button3 = createChoiceButton(layout, "Мастер", "Вы уже знаете все основы\nи готовы к службе.\nОбучение будет пропущено.", function()
		sendChoice(3)
	end)
	local buttonHeight = 180
	layout.OnSizeChanged = function(self, w, h)
		local buttonWidth = math.floor((w - 24) / 3)
		button1:SetSize(buttonWidth, buttonHeight)
		button1:SetPos(0, 0)
		button2:SetSize(buttonWidth, buttonHeight)
		button2:SetPos(buttonWidth + 12, 0)
		button3:SetSize(buttonWidth, buttonHeight)
		button3:SetPos((buttonWidth + 12) * 2, 0)
	end
	layout:InvalidateLayout(true)

	clientState.menu = frame
	gui.EnableScreenClicker(true)
end

local function pickArmsInFrontSequence(ent)
	if not IsValid(ent) then return -1 end
	for _, seqName in ipairs({
		"pose_standing_02",
		"pose_standing_01",
		"idle_all_01",
		"idle_subtle",
	}) do
		local seq = ent:LookupSequence(seqName)
		if seq and seq >= 0 then
			return seq
		end
	end
	return -1
end

local function openFinishChoiceMenu(teams)
	if IsValid(clientState.finishMenu) then
		clientState.finishMenu:Remove()
		clientState.finishMenu = nil
	end

	local frame = vgui.Create("DFrame")
	frame:SetSize(math.min(980, ScrW() - 80), math.min(640, ScrH() - 80))
	frame:Center()
	frame:SetTitle("")
	frame:ShowCloseButton(false)
	frame:SetDraggable(false)
	frame:MakePopup()
	frame.Paint = function(self, w, h)
		draw.RoundedBox(14, 0, 0, w, h, Color(10, 14, 22, 240))
		draw.RoundedBox(14, 2, 2, w - 4, h - 4, Color(18, 22, 34, 230))
		draw.RoundedBox(14, 6, 6, w - 12, 42, Color(36, 70, 130, 190))
		draw.SimpleText("Выберите профессию", "CadetTraining_Title", w / 2, 10, Color(255, 255, 255), TEXT_ALIGN_CENTER, TEXT_ALIGN_TOP)
	end

	local scroll = vgui.Create("DScrollPanel", frame)
	scroll:Dock(FILL)
	scroll:DockMargin(12, 56, 12, 12)

	local grid = vgui.Create("DIconLayout", scroll)
	grid:Dock(FILL)
	grid:SetSpaceX(12)
	grid:SetSpaceY(12)

	local panelW = 300
	local panelH = 360

	for _, item in ipairs(teams or {}) do
		local cube = vgui.Create("DButton", grid)
		cube:SetText("")
		cube:SetSize(panelW, panelH)
		cube.Paint = function(self, w, h)
			local hovered = self:IsHovered()
			draw.RoundedBox(12, 0, 0, w, h, hovered and Color(42, 80, 140, 230) or Color(20, 26, 40, 225))
			draw.RoundedBox(12, 2, 2, w - 4, h - 4, hovered and Color(58, 104, 176, 210) or Color(30, 38, 58, 210))
			draw.RoundedBox(10, 8, 8, w - 16, h - 70, Color(10, 14, 22, 215))
			draw.RoundedBox(10, 8, h - 56, w - 16, 42, Color(14, 20, 30, 235))
			draw.SimpleText(item.name or "Профессия", "CadetTraining_Body", w / 2, h - 35, Color(255, 255, 255), TEXT_ALIGN_CENTER, TEXT_ALIGN_CENTER)
		end

		local modelPanel = vgui.Create("DModelPanel", cube)
		modelPanel:SetPos(14, 14)
		modelPanel:SetSize(panelW - 28, panelH - 86)
		modelPanel:SetModel(item.model ~= "" and item.model or "models/player/kleiner.mdl")
		modelPanel:SetFOV(28)
		modelPanel:SetCamPos(Vector(48, 0, 64))
		modelPanel:SetLookAt(Vector(0, 0, 62))

		function modelPanel:LayoutEntity(ent)
			if not IsValid(ent) then return end
			ent:SetEyeTarget(self:GetCamPos())
			ent:SetAngles(Angle(0, 24, 0))
			local seq = pickArmsInFrontSequence(ent)
			if seq >= 0 and ent:GetSequence() ~= seq then
				ent:ResetSequence(seq)
				ent:SetCycle(0)
			end
			ent:FrameAdvance(FrameTime())
		end

		if IsValid(modelPanel.Entity) then
			modelPanel.Entity:SetSkin(0)
			modelPanel.Entity:SetBodygroup(0, 0)
		end

		cube.DoClick = function()
			netstream.Start("CadetTraining_SelectFinishTeam", { team = item.team })
			if IsValid(frame) then frame:Remove() end
		end
	end

	clientState.finishMenu = frame
end

local function getTeamModel()
	local cfg = re.cadet_training and re.cadet_training.config or {}
	local teamIndex = cfg.finish_team
	local job = re.jobs and teamIndex and re.jobs[teamIndex]

	if job then
		local rating = cfg.finish_rating
		if rating and job.FeatureRatings and job.FeatureRatings[rating] and isstring(job.FeatureRatings[rating].model) and job.FeatureRatings[rating].model ~= "" then
			return job.FeatureRatings[rating].model
		end
		if istable(job.WorldModel) and #job.WorldModel > 0 then
			return job.WorldModel[1]
		end
		if isstring(job.WorldModel) and job.WorldModel ~= "" then
			return job.WorldModel
		end
	end

	local ply = LocalPlayer()
	if IsValid(ply) then
		local model = ply:GetModel()
		if isstring(model) and model ~= "" then
			return model
		end
	end

	return "models/player/kleiner.mdl"
end

local function setupModelPanelCamera(panel)
	if not IsValid(panel) or not IsValid(panel.Entity) then return end
	local ent = panel.Entity
	ent:SetNoDraw(false)
	local mn, mx = ent:GetRenderBounds()
	local center = (mn + mx) * 0.5
	local radius = math.max(1, mn:Distance(mx) * 0.5)
	local headFocus = Vector(center.x, center.y, mn.z + (mx.z - mn.z) * 0.78)
	panel:SetLookAt(headFocus)
	panel:SetCamPos(headFocus + Vector(radius * 1.55, 0, radius * 0.42))
	panel:SetFOV(24)
end

local function stopTextWindowVoice()
	if clientState.textWindowVoice then
		if clientState.textWindowVoice.Stop then
			clientState.textWindowVoice:Stop()
		end
		clientState.textWindowVoice = nil
	end
end

local function playTextWindowVoice(soundPath)
	if not isstring(soundPath) or soundPath == "" then return end
	local ply = LocalPlayer()
	if not IsValid(ply) then return end

	local snd = CreateSound(ply, soundPath)
	if not snd then return end
	snd:Play()
	clientState.textWindowVoice = snd
end

local function showTextWindow(text, duration, voice)
	stopTextWindowVoice()
	if IsValid(clientState.textWindow) then
		clientState.textWindow:Remove()
		clientState.textWindow = nil
	end

	local frame = vgui.Create("DFrame")
	local frameWidth = math.min(760, ScrW() - 80)
	local frameHeight = 220
	frame:SetSize(frameWidth, frameHeight)
	frame:SetPos((ScrW() - frameWidth) / 2, math.max(20, ScrH() * 0.68 - frameHeight / 2))
	frame:SetTitle("")
	frame:ShowCloseButton(false)
	frame:SetDraggable(false)
	frame:SetMouseInputEnabled(false)
	frame:SetKeyboardInputEnabled(false)
	local cfg = re.cadet_training and re.cadet_training.config or {}
	local windowHeaderText = cfg.hud_title_text or "Обучение кадетов"
	frame.Paint = function(self, w, h)
		draw.RoundedBox(12, 0, 0, w, h, Color(10, 14, 22, 235))
		draw.RoundedBox(12, 2, 2, w - 4, h - 4, Color(18, 22, 34, 225))
		draw.RoundedBox(12, 6, 6, w - 12, 28, Color(36, 70, 130, 185))
		draw.SimpleText(windowHeaderText, "CadetTraining_Body", w / 2, 10, Color(230, 235, 245), TEXT_ALIGN_CENTER, TEXT_ALIGN_TOP)
	end
	local lastClick = 0
	frame.Think = function()
		if input.IsMouseDown(MOUSE_LEFT) and CurTime() > lastClick then
			lastClick = CurTime() + 0.2
			if IsValid(frame) then
				stopTextWindowVoice()
				frame:Remove()
			end
		end
	end

	local modelHolder = vgui.Create("DPanel", frame)
	modelHolder:Dock(LEFT)
	modelHolder:DockMargin(14, 28, 8, 20)
	modelHolder:SetWide(120)
	modelHolder.Paint = function(self, w, h)
		draw.RoundedBox(8, 0, 0, w, h, Color(8, 12, 20, 230))
		draw.RoundedBox(8, 2, 2, w - 4, h - 4, Color(14, 18, 30, 230))
		surface.SetDrawColor(80, 130, 220, 120)
		surface.DrawOutlinedRect(0, 0, w, h, 1)
	end

	local model = vgui.Create("DModelPanel", modelHolder)
	model:Dock(FILL)
	model:DockMargin(4, 0, 4, 4)
	model:SetModel(getTeamModel())
	model:SetFOV(26)
	model:SetMouseInputEnabled(false)
	model:SetPaintBackground(false)
	setupModelPanelCamera(model)
	model._nextRefresh = CurTime() + 0.1
	function model:Think()
		if self._nextRefresh > CurTime() then return end
		self._nextRefresh = CurTime() + 0.25
		if not IsValid(self.Entity) then return end
		setupModelPanelCamera(self)
	end
	function model:PreDrawModel(ent)
		render.SuppressEngineLighting(true)
		render.ResetModelLighting(1, 1, 1)
		for i = 0, 6 do
			render.SetModelLighting(i, 1.4, 1.4, 1.4)
		end
	end
	function model:PostDrawModel(ent)
		render.SuppressEngineLighting(false)
	end
	function model:LayoutEntity(ent)
		if not IsValid(ent) then return end
		ent:SetEyeTarget(self:GetCamPos())
		ent:SetAngles(Angle(0, 25, 0))
		local seq = pickArmsInFrontSequence(ent)
		if seq >= 0 and ent:GetSequence() ~= seq then
			ent:ResetSequence(seq)
			ent:SetCycle(0)
		end
		ent:FrameAdvance(FrameTime())
	end

	local label = vgui.Create("DLabel", frame)
	label:Dock(FILL)
	label:DockMargin(10, 22, 26, 26)
	label:SetText(text or "")
	label:SetFont("CadetTraining_Body")
	label:SetTextColor(Color(255, 255, 255))
	label:SetWrap(true)
	label:SetAutoStretchVertical(true)
	label:SetContentAlignment(8)
	label:SetMouseInputEnabled(false)

	local hint = vgui.Create("DLabel", frame)
	hint:Dock(BOTTOM)
	hint:DockMargin(16, 0, 16, 16)
	hint:SetTall(13)
	hint:SetFont("CadetTraining_Small")
	hint:SetText("ЛКМ - Пропускает данное окно.")
	hint:SetTextColor(Color(170, 170, 170))
	hint:SetContentAlignment(5)
	hint:SetMouseInputEnabled(false)

	clientState.textWindow = frame
	playTextWindowVoice(voice)

	if duration and duration > 0 then
		timer.Simple(duration, function()
			if IsValid(frame) then
				stopTextWindowVoice()
				frame:Remove()
			end
		end)
	end
end

local function normalizeVector(pos)
	if isvector(pos) then
		return pos
	end
	if istable(pos) then
		return Vector(pos.x or 0, pos.y or 0, pos.z or 0)
	end
	return Vector(0, 0, 0)
end

local function updateTarget(data)
	clientState.target = {
		pos = normalizeVector(data.pos),
		radius = data.radius or 200,
		title = data.title or "Цель",
	}
end

hook.Add("HUDPaint", "CadetTraining_HUD", function()
	if not clientState.target then
		return
	end

	local target = clientState.target
	local ply = LocalPlayer()
	if not IsValid(ply) then
		return
	end

	local distance = math.floor(ply:GetPos():Distance(target.pos)) -- Обработка меток относительно игрока по target.pos
	local boxX, boxY = 24, 24
	local boxW, boxH = 370, 102
	draw.RoundedBox(12, boxX, boxY, boxW, boxH, Color(8, 12, 20, 220))
	draw.RoundedBox(12, boxX + 2, boxY + 2, boxW - 4, boxH - 4, Color(16, 22, 36, 210))
	draw.RoundedBox(10, boxX + 8, boxY + 8, boxW - 16, 30, Color(34, 64, 118, 170))
	draw.SimpleText("Цель обучения", "CadetTraining_HUDTitle", boxX + boxW / 2, boxY + 9, Color(255, 255, 255), TEXT_ALIGN_CENTER, TEXT_ALIGN_TOP)
	draw.SimpleText(target.title, "CadetTraining_Body", boxX + boxW / 2, boxY + 46, Color(220, 224, 235), TEXT_ALIGN_CENTER, TEXT_ALIGN_TOP)
	draw.SimpleText("Дистанция: " .. distance .. "м", "CadetTraining_Body", boxX + boxW / 2, boxY + 72, Color(150, 205, 255), TEXT_ALIGN_CENTER, TEXT_ALIGN_TOP)
end)

hook.Add("PostDrawTranslucentRenderables", "CadetTraining_TargetMarker", function()
	local waypoints = (re.cadet_training.config and re.cadet_training.config.waypoints) or {}
	local ply = LocalPlayer()
	if not IsValid(ply) then
		return
	end

	local activeIndex
	if clientState.target and clientState.target.pos then
		for index, waypoint in ipairs(waypoints) do
			if waypoint.pos and clientState.target.pos:DistToSqr(normalizeVector(waypoint.pos)) < 1 then
				activeIndex = index
				break
			end
		end
	end

	for index, waypoint in ipairs(waypoints) do
		if waypoint.pos and activeIndex and index == activeIndex then
			local waypointPos = normalizeVector(waypoint.pos)
			local pos = waypointPos + Vector(0, 0, 24)
			local ang = Angle(0, ply:EyeAngles().y - 90, 90)
			local bgColor = Color(30, 90, 180, 220)
			local title = waypoint.title or ("Точка обучения " .. index)
			local orbColor = Color(80, 180, 255, 220)
			render.SetColorMaterial()
			render.DrawSphere(waypointPos + Vector(0, 0, 6), 16, 16, 16, orbColor)
			cam.IgnoreZ(true)
			cam.Start3D2D(pos, ang, 0.22)
				draw.RoundedBox(8, -170, -34, 340, 68, bgColor)
				draw.RoundedBox(8, -166, -30, 332, 60, Color(12, 12, 14, 180))
				draw.SimpleText(title, "CadetTraining_Title", 0, -6, Color(255, 255, 255), TEXT_ALIGN_CENTER, TEXT_ALIGN_CENTER)
			cam.End3D2D()
			cam.IgnoreZ(false)
		end
	end
end)

netstream.Hook("CadetTraining_OpenMenu", function() -- net соединения
	openMenu()
end)

netstream.Hook("CadetTraining_ShowText", function(data)
	showTextWindow(data.text or "", data.duration or 6, data.voice)
end)

netstream.Hook("CadetTraining_SetTarget", function(data)
	updateTarget(data)
end)

netstream.Hook("CadetTraining_ClearTarget", function()
	clientState.target = nil
end)

netstream.Hook("CadetTraining_Complete", function()
	clientState.target = nil
	stopTextWindowVoice()
	if IsValid(clientState.finishMenu) then
		clientState.finishMenu:Remove()
		clientState.finishMenu = nil
	end
end)

netstream.Hook("CadetTraining_OpenFinishChoice", function(teams)
	openFinishChoiceMenu(teams)
end)
