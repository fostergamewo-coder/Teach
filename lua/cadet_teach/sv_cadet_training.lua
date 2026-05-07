-- Инициализация таблиц для тренировки кадетов
re.cadet_training = re.cadet_training or {}
re.cadet_training.sessions = re.cadet_training.sessions or {}

-- Конфигурация тренировки кадетов
local config = re.cadet_training.config or {}

-- Функция нормализации данных: если это таблица — возвращаем как есть, если строка — парсим JSON, иначе возвращаем пустую таблицу
local function normalizeData(data)
	if istable(data) then
		return data
	end
	if isstring(data) then
		return util.JSONToTable(data) or {}
	end
	return {}
end

-- Функция обновления данных кадета в базе данных через callback
local function updateCadetData(ply, callback)
	if not IsValid(ply) then
		return
	end
	ply:UpdateCharData("cadet_training", function(pData)
		pData = normalizeData(pData)
		local cadetData = normalizeData(pData.cadet_training)
		callback(cadetData)
		return cadetData
	end)
end

-- Получение данных тренировки кадета из сетевых переменных игрока
local function getCadetData(ply)
	local data = ply:GetNetVar("data") or {}
	data = normalizeData(data)
	return normalizeData(data.cadet_training)
end

-- Установка данных кадета
local function setCadetData(ply, values)
	updateCadetData(ply, function(data)
		for key, value in pairs(values) do
			data[key] = value
		end
	end)
end

-- Очистка сессии тренировки для игрока
local function clearCadetSession(ply)
	re.cadet_training.sessions[ply] = nil
	if IsValid(ply) and ply.cadetTrainingTimerId then
		timer.Remove(ply.cadetTrainingTimerId)
		ply.cadetTrainingTimerId = nil
	end
end

-- Выбор финального рейтинга для игрока
local function pickFinishRating(job)
	if config.finish_rating then
		return config.finish_rating
	end
	if job and job.Type and DEFAULT_RATINGS and DEFAULT_RATINGS[job.Type] then
		return DEFAULT_RATINGS[job.Type]
	end
	return nil
end

-- Проверка, находится ли кадет за пределами "домашней" карты
local function isCadetOutsideHomeMap(ply)
	if not IsValid(ply) then return false end
	if not config.home_map or config.home_map == "" then return false end
	local job = re.jobs[ply:Team()]
	if not job or job.jobID ~= config.start_job_id then return false end
	return game.GetMap() ~= config.home_map
end

-- Временное изменение команды игрока (без сохранения в базе)
local function changePlayerTeamTemporary(ply, teamIndex)
	local finish_team = teamIndex or config.finish_team
	local job = finish_team and re.jobs[finish_team]
	if not finish_team or not job then
		return
	end

	local rating = pickFinishRating(job) or ply:GetNetVar("rating")
	local worldmodel = istable(job.WorldModel) and table.Random(job.WorldModel) or job.WorldModel
	local model = (job.FeatureRatings and rating and job.FeatureRatings[rating] and job.FeatureRatings[rating].model) or worldmodel

	local pos, ang = ply:GetPos(), ply:EyeAngles()
	ply:SetNetVar("model", model, NETWORK_PROTOCOL_PUBLIC)
	ply:SetTeam(finish_team)
	ply:Spawn()
	ply:SetPos(pos)
	ply:SetEyeAngles(ang)

	if rating then
		ply:SetNetVar("rating", rating, NETWORK_PROTOCOL_PUBLIC)
		ply:SetNWString("rating", rating)
	end
end

-- Постоянное изменение команды игрока (с сохранением в базе данных)
local function changePlayerTeamPersistent(ply, teamIndex)
	local finish_team = teamIndex or config.finish_team
	local job = finish_team and re.jobs[finish_team]
	if not finish_team or not job then
		return
	end

	local rating = pickFinishRating(job) or ply:GetNetVar("rating")
	local worldmodel = istable(job.WorldModel) and table.Random(job.WorldModel) or job.WorldModel
	local model = (job.FeatureRatings and rating and job.FeatureRatings[rating] and job.FeatureRatings[rating].model) or worldmodel

	local char_id = ply.ActiveCharacterID
	local team_id = job.jobID

	if char_id then
		MySQLite.query(string.format(
			"UPDATE re_characters SET team_id = %s, model = %s WHERE char_id = %s;",
			MySQLite.SQLStr(team_id),
			MySQLite.SQLStr(model),
			MySQLite.SQLStr(char_id)
		))

		-- Обновление локальных данных персонажей игрока
		for _, char in pairs(ply.Characters or {}) do
			if char.char_id == char_id then
				char.team_id = team_id
				char.team_index = finish_team
				char.model = model
				break
			end
		end
	end

	-- Применяем изменения временно, чтобы игрок сразу видел их
	changePlayerTeamTemporary(ply, finish_team)
end

-- Открытие меню выбора финальной команды после тренировки
local function openFinishChoiceMenu(ply)
	if not IsValid(ply) then
		return
	end

	local teams = {}
	for _, teamIndex in ipairs(config.finish_choice_teams or {}) do
		local job = re.jobs[teamIndex]
		if job then
			local previewModel = istable(job.WorldModel) and (job.WorldModel[1] or "") or (job.WorldModel or "")
			table.insert(teams, {
				team = teamIndex,
				name = team.GetName(teamIndex) or job.name or ("Профессия #" .. tostring(teamIndex)),
				model = previewModel,
			})
		end
	end

	-- Если нет команд для выбора, оставляем одну дефолтную
	if #teams == 0 then
		teams = { {
			team = config.finish_team,
			name = team.GetName(config.finish_team) or "Профессия",
			model = (re.jobs[config.finish_team] and (istable(re.jobs[config.finish_team].WorldModel) and re.jobs[config.finish_team].WorldModel[1] or re.jobs[config.finish_team].WorldModel)) or "",
		} }
	end

	netstream.Start(ply, "CadetTraining_OpenFinishChoice", teams)
end

-- Завершение тренировки для игрока
local function completeTraining(ply)
	if config.enabled == false then
		return
	end
	clearCadetSession(ply)
	setCadetData(ply, {
		completed = true,
		in_progress = false,
	})

	if config.finish_choice_enabled then
		openFinishChoiceMenu(ply)
	else
		changePlayerTeamPersistent(ply)
		if IsValid(ply) then
			netstream.Start(ply, "CadetTraining_Complete")
		end
	end
end

-- Отправка текущей цели (waypoint) игроку
local function sendTarget(ply, step)
	if not IsValid(ply) or not step then
		return
	end
	netstream.Start(ply, "CadetTraining_SetTarget", {
		pos = step.pos,
		radius = step.radius,
		title = step.title,
	})
end

-- Проверка, является ли объект стартовым для тренировки
local function isStartEntity(ent)
	if not IsValid(ent) then
		return false
	end
	local name = string.Trim(tostring(ent:GetName() or ""))
	local class = string.Trim(tostring(ent:GetClass() or ""))
	local startName = string.Trim(tostring(config.start_entity_name or ""))
	local startClass = string.Trim(tostring(config.start_entity_class or ""))

	if startClass ~= "" and class == startClass then
		return true
	end

	if startName ~= "" and (name == startName or ent.PrintName == startName) then
		return true
	end

	return false
end

-- Поиск стартового объекта тренировки на карте
local function findStartEntity()
	local startName = string.Trim(tostring(config.start_entity_name or ""))
	local startClass = string.Trim(tostring(config.start_entity_class or ""))

	for _, ent in ipairs(ents.GetAll()) do
		if IsValid(ent) then
			local class = string.Trim(tostring(ent:GetClass() or ""))
			local name = string.Trim(tostring(ent:GetName() or ""))
			if startClass ~= "" and class == startClass then
				return ent
			end
			if startName ~= "" and (name == startName or ent.PrintName == startName) then
				return ent
			end
		end
	end

	return nil
end

-- Отправка цели для начала тренировки (стартового объекта)
local function sendStartEntityTarget(ply, ent)
	if not IsValid(ply) then
		return
	end

	if not IsValid(ent) then
		netstream.Start(ply, "CadetTraining_ClearTarget")
		return
	end

	netstream.Start(ply, "CadetTraining_SetTarget", {
		pos = ent:GetPos(),
		radius = 120,
		title = config.start_entity_name ~= "" and config.start_entity_name or "Кадетская",
	})
end

-- Переход к следующему шагу тренировки
local function advanceStep(ply)
	local session = re.cadet_training.sessions[ply]
	if not session then
		return
	end
	local steps = config.waypoints or {}
	session.index = (session.index or 1) + 1
	setCadetData(ply, {
		step = session.index,
	})

	local nextStep = steps[session.index]
	if not nextStep then
		-- Если шагов больше нет, очищаем цель и показываем финальный текст
		netstream.Start(ply, "CadetTraining_ClearTarget")
		if config.final_text and config.final_text ~= "" then
			netstream.Start(ply, "CadetTraining_ShowText", {
				text = config.final_text,
				duration = config.final_text_duration or 6,
				voice = config.final_voice,
			})
			timer.Simple(config.final_text_duration or 6, function()
				if not IsValid(ply) then
					return
				end
				completeTraining(ply)
			end)
		else
			completeTraining(ply)
		end
		return
	end

	-- Отправляем следующую цель игроку
	sendTarget(ply, nextStep)
	session.waiting = false
end

-- Запуск цикла waypoints для игрока
local function beginWaypointLoop(ply)
	if not IsValid(ply) then
		return
	end

	local steps = config.waypoints or {}
	if #steps == 0 then
		completeTraining(ply)
		return
	end

	local session = re.cadet_training.sessions[ply] or {}
	if session.index == nil then
		-- Если есть стартовый объект — начинаем с 0, иначе сразу с 1 шага
		session.index = (config.start_entity_name and config.start_entity_name ~= "") and 0 or 1
	end

	local cadetData = getCadetData(ply)
	if cadetData and cadetData.choice == 2 and session.index == 0 then
		session.index = 1
		setCadetData(ply, { step = 1 })
	end

	session.waiting = false
	session.dialogue_pending = session.index == 0
	session.start_entity = session.start_entity or findStartEntity()
	re.cadet_training.sessions[ply] = session

	if session.index > 0 then
		sendTarget(ply, steps[session.index])
	else
		sendStartEntityTarget(ply, session.start_entity)
	end

	-- Таймер, проверяющий попадание игрока в радиус шага
	local timerId = "CadetTraining_Check_" .. ply:SteamID64()
	ply.cadetTrainingTimerId = timerId

	timer.Create(timerId, 0.2, 0, function()
		if not IsValid(ply) then
			clearCadetSession(ply)
			return
		end

		local currentSession = re.cadet_training.sessions[ply]
		if not currentSession or currentSession.waiting then
			return
		end
		if currentSession.dialogue_pending then
			return
		end

		local step = steps[currentSession.index]
		if not step or not step.pos then
			return
		end

		local radius = step.radius or 200
		if ply:GetPos():DistToSqr(step.pos) <= radius * radius then
			currentSession.waiting = true
			netstream.Start(ply, "CadetTraining_ClearTarget")
			local duration = step.text_duration or config.step_text_duration or 6
			netstream.Start(ply, "CadetTraining_ShowText", {
				text = step.text or "",
				duration = duration,
				voice = step.voice,
			})
			timer.Simple(duration, function()
				if not IsValid(ply) then
					return
				end
				advanceStep(ply)
			end)
		end
	end)
end

-- Хук на использование стартового объекта
hook.Add("PlayerUse", "CadetTraining_StartEntity", function(ply, ent)
	local session = re.cadet_training.sessions[ply]
	if not session or not session.dialogue_pending then
		return
	end
	if not isStartEntity(ent) then
		return
	end
	session.start_entity = ent

	session.dialogue_pending = false
	session.waiting = true
	netstream.Start(ply, "CadetTraining_ClearTarget")
	local duration = config.start_entity_duration or config.step_text_duration or 6
	timer.Simple(duration, function()
		if not IsValid(ply) then
			return
		end
		session.waiting = false
		advanceStep(ply)
	end)
end)

-- Запуск тренировки для игрока
local function startTraining(ply, choice)
	if not IsValid(ply) then
		return
	end

	local useStartEntityStep = (choice ~= 2) and (config.start_entity_name and config.start_entity_name ~= "")
	local initialStep = useStartEntityStep and 0 or 1
	setCadetData(ply, {
		choice = choice,
		completed = false,
		in_progress = true,
		step = initialStep,
	})

	-- Если выбор "пропустить" тренировку
	if choice == 3 then
		completeTraining(ply)
		return
	end

	-- Если выбор 1 — показываем вступительный текст
	if choice == 1 and config.intro_text and config.intro_text ~= "" then
		netstream.Start(ply, "CadetTraining_ShowText", {
			text = config.intro_text,
			duration = config.intro_duration or 6,
			voice = config.intro_voice,
		})
	end

	local startDelay = 0
	if choice == 1 then
		startDelay = (config.intro_duration or 0)
	end

	-- Запуск цикла waypoints с задержкой
	timer.Simple(startDelay, function()
		if not IsValid(ply) then
			return
		end
		beginWaypointLoop(ply)
	end)
end

-- Продолжение тренировки, если игрок уже начал её ранее
local function resumeTraining(ply, cadetData)
	if not cadetData or cadetData.completed then
		return
	end
	local choice = cadetData.choice
	if choice == 3 then
		completeTraining(ply)
		return
	end
	beginWaypointLoop(ply)
end

-- Выбор финальной команды через меню игроком
netstream.Hook("CadetTraining_SelectFinishTeam", function(ply, data)
	if config.enabled == false then
		return
	end
	if not IsValid(ply) then
		return
	end
	local teamIndex = tonumber(data and data.team)
	if not teamIndex then
		return
	end

	local allowed = false
	for _, t in ipairs(config.finish_choice_teams or {}) do
		if t == teamIndex then
			allowed = true
			break
		end
	end
	if not allowed and teamIndex ~= config.finish_team then
		return
	end

	if isCadetOutsideHomeMap(ply) then
		changePlayerTeamTemporary(ply, teamIndex)
	else
		changePlayerTeamPersistent(ply, teamIndex)
	end
	netstream.Start(ply, "CadetTraining_Complete")
end)

-- Выбор варианта старта тренировки через меню игроком
netstream.Hook("CadetTraining_Select", function(ply, data)
	if config.enabled == false then
		return
	end
	if not IsValid(ply) then
		return
	end
	local choice = tonumber(data and data.choice)
	if not choice or choice < 1 or choice > 3 then
		return
	end
	startTraining(ply, choice)
end)

-- Проверка после загрузки персонажа, нужно ли запускать тренировку
hook.Add("PostLoadCharacter", "CadetTraining_CheckStart", function(ply)
	if config.enabled == false then
		return
	end
	if not IsValid(ply) then
		return
	end
	local job = re.jobs[ply:Team()]
	if not job or job.jobID ~= config.start_job_id then
		return
	end

	-- Если игрок за пределами домашней карты и включено авто-предложение — открываем меню выбора финальной команды
	if config.auto_offer_outside_home and isCadetOutsideHomeMap(ply) then
		timer.Simple(1, function()
			if not IsValid(ply) then return end
			openFinishChoiceMenu(ply)
		end)
		return
	end

	local cadetData = getCadetData(ply)
	if cadetData.completed then
		return
	end

	-- Если тренировка уже в процессе — продолжаем
	if cadetData.in_progress and cadetData.choice then
		timer.Simple(1, function()
			if not IsValid(ply) then
				return
			end
			resumeTraining(ply, cadetData)
		end)
		return
	end

	-- Если ещё не начинали — открываем меню старта
	timer.Simple(1, function()
		if not IsValid(ply) then
			return
		end
		netstream.Start(ply, "CadetTraining_OpenMenu")
	end)
end)

-- Очистка сессии тренировки при выходе игрока
hook.Add("PlayerDisconnected", "CadetTraining_Cleanup", function(ply)
	clearCadetSession(ply)
end)

-- Команда для админов, открывающая меню тренировки
concommand.Add("cadet_training_menu", function(ply)
	if config.enabled == false then
		return
	end
	if not IsValid(ply) or not ply:IsSuperAdmin() then
		return
	end
	netstream.Start(ply, "CadetTraining_OpenMenu")
end)
