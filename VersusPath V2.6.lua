local VersusPath = {}
VersusPath.__index = VersusPath

local Settings = require(script.Settings)

--[[
	Small Description:
		YO! This is the advanced module to work with pathfinding service.
		This module was made by Max/badaboss:
			Roblox Profile Link: https://www.roblox.com/users/1482715996/profile
			Discord Username|Id: badaboss|990909484924817438
	How To Use:
	local character_movement = VersusPath.new(
		Character Or Player, 
	)
	character_movement:StartMovement(CFrame Or Vector3(Position))
]]
local Players = game:GetService("Players")
local PathfindingService = game:GetService("PathfindingService")
local Debris = game:GetService("Debris")
local TweenService = game:GetService("TweenService")
-- connect all needable services

function VersusPath:Debug(type: string, ...)
	if not self._Debug then
		return
	end
	-- stop if debug mode is not on
	if self._DebugDisplay and not self._DebugDisplay[type] then
		return
	end
	-- stop if some debug setting is off
	warn(...)
	--this function is used to warn if some action happens
end
function VersusPath:SetupMovement(FinishPosition: Vector3|CFrame)
	if typeof(FinishPosition) == 'CFrame' then
		FinishPosition = FinishPosition.Position
	end
	--if cframe then take position from cframe
	local PathFound = self._PathBase:ComputeAsync(self._Character:GetPivot().Position, FinishPosition)
	-- generating path from character to given position
	if self._PathBase.Status == Enum.PathStatus.Success then
		return self._PathBase:GetWaypoints()
		--returning table with generated waypoints
	else
		self:Debug('WayGenerationFail', 'Path Way Not Found!')
		--debugging error about path generation fail
	end
	--this function is made to generate path from character to given position
end
function VersusPath:VizualizePath(Waypoints: {})
	if not self._VizualizePath then
		return
	end
	-- stop if not vizualize path
	local PartSettings: {}? = (self._VizualizePathSettings and self._VizualizePathSettings['Part_Settings']) or nil
	local TweenSettings: {}? = (self._VizualizePathSettings and self._VizualizePathSettings['TweenSettings']) or Settings.ClassicalTweenSettings
	local TweenSpawn: boolean? = (self._VizualizePathSettings and self._VizualizePathSettings['TweenSpawn']) or nil
	local WaypointTimeout: number? = (self._VizualizePathSettings and self._VizualizePathSettings['WaypointTimeout']) or nil
	-- connect all settings to reduce lines
	for i, v: PathWaypoint in Waypoints do
		local WayPart = Instance.new('Part')
		WayPart.Position = v.Position
		WayPart.CanCollide = false
		-- creating part & set up basic settings
		for i, v in Settings.ClassicalVizualizePartSettings do
			WayPart[i] = (PartSettings and PartSettings[i]) or v
		end
		-- set properties from classical settings or given settings
		for i, v in PartSettings or {} do
			if Settings.ClassicalVizualizePartSettings[i] then
				continue
			end
			WayPart[i] = v
		end
		-- set properties which is not in classical settings
		-- creating part which show where's rig moving
		if TweenSpawn then
			local Tween = TweenService:Create(WayPart, TweenSettings['TweenInfo'], TweenSettings['Properties']) 
			Tween:Play()
			-- tweening part
		end
		if WaypointTimeout then
			Debris:AddItem(WayPart, WaypointTimeout)
		end
		-- setting up timeout after part destroys 
		table.insert(self._VisualizedWaypoints['Current'], WayPart)
		WayPart.Parent = workspace
		-- store part into current visualized waypoints and put parent to workspace
	end
end
function VersusPath:ClearVizualizedPath(type:'Stored'|'Current'|'All', Waypoint:number?)
	if not self._VizualizePath then
		return
	end
	-- stop if not vizualize path
	local Waypoints = (type == 'All' and {table.unpack(self._VisualizedWaypoints['Stored']), table.unpack(self._VisualizedWaypoints['Current'])}) or self._VisualizedWaypoints[type]
	for i, v: BasePart in (Waypoints[Waypoint] and {Waypoints[Waypoint]}) or Waypoints do
		if v:IsA("BasePart") then
			v:Destroy()
		end
	end
	-- destroys selected type vizualized waypoints
	if type == 'All' then
		for i, v: VisualizedWaypointsTable in self._VisualizedWaypoints do
			if typeof(v) == 'table' and not Waypoint then
				table.clear(v)
			else
				if table.find(v, Waypoints[Waypoint]) then
					Waypoints[table.find(v, Waypoints[Waypoint])] = nil
				end
			end
			-- clear full table or selected waypoint only
		end
	else
		if not Waypoint then
			table.clear(Waypoints)
		else
			Waypoints[Waypoint] = nil
		end
		-- clear full table or selected waypoint only
	end
	-- clear selected type table 
end
function VersusPath:StoreVizualizedWaypoints() --function to store vizualized waypoints
	for i, v in self._VisualizedWaypoints['Current'] do
		table.insert(self._VisualizedWaypoints['Stored'], v)
	end
	-- stores current waypoints to stored waypoints
	table.clear(self._VisualizedWaypoints['Current'])
	-- clear all old current waypoints
end
function VersusPath:IsMovementRunning()
	return self._MovementFunction and coroutine.status(self._MovementFunction) ~= 'dead'
	-- function which help to check if currently is running a path
end
function VersusPath:StopMovement(Success:boolean) -- function that stops npc movement
	if not self._MovementFunction then
		return
	end
	-- stop if currently not active or finished MovementFunction
	task.cancel(self._MovementFunction) -- stop current run function
	-- bug with task cancel error was fixed
	self._MovementFunction = nil
	self._Humanoid:MoveTo(self._Character:GetPivot().Position)
	-- stops movement
	if self.MoveTimeoutTask then
		task.cancel(self.MoveTimeoutTask) -- stop timeout task
		self.MoveTimeoutTask = nil
	end
	if self._VizualizePathSettings and self._VizualizePathSettings['RemoveAfterFinish'] then
		self:ClearVizualizedPath('Current')
	else
		self:StoreVizualizedWaypoints()
	end
	-- clear or store waypoints
	self._WayFinished:Fire(Success or false)
	self:Debug('MovementFinished', self._Character.Name)
	-- fire event which gives argument finished or not & debugging info
end
function VersusPath:Break() -- function to break old meta with settings
	self:StopMovement()
	self:ClearVizualizedPath('All')
	-- stop movement and clear all vizulized waypoints
	setmetatable(self, nil)
	table.clear(self)
	-- set meta to nil and clear all in self
end
function VersusPath:StartMovement(FinishPosition: Vector3|CFrame) -- function that start npc movement
	self:StopMovement()
	self._MovementFunction = task.spawn(function()
		local result = self:SetupMovement(FinishPosition)
		if typeof(result) ~= 'table' then -- check if result isn't waypoints
			return
		end
		if self._VizualizePathSettings and not self._VizualizePathSettings['StepByStepGeneration'] then
			self:VizualizePath(result)
		end
		-- generate all waypoints at one time
		for number_of_waypoint: number, Waypoint: PathWaypoint in result do
			if self._VizualizePathSettings and self._VizualizePathSettings['StepByStepGeneration'] then -- check if step by step generation is true
				self:VizualizePath({Waypoint})
			end
			-- step by step waypoint spawn
			if self._MaxMoveTime then
				if self.MoveTimeoutTask then
					task.cancel(self.MoveTimeoutTask)
					self.MoveTimeoutTask = nil
				end
				self.MoveTimeoutTask = task.delay(self._MaxMoveTime, function()
					self:Debug('MoveTimeOut','Move Time Out')
					self:StopMovement()
				end)
				-- shuts old timeout and spawns new one
			end
			if Waypoint.Action == Enum.PathWaypointAction.Jump then
				self._Humanoid:ChangeState(Enum.HumanoidStateType.Jumping)
			end
			-- if action is jump then jump
			local finish
			repeat
				self._Humanoid:MoveTo(Waypoint.Position)
				finish = self._Humanoid.MoveToFinished:Wait()
				task.wait()
			until
			finish
			-- moving character to the waypoint
			self._WaypointReached:Fire(number_of_waypoint)
			self:Debug('WaypointReached','Reached Waypoint Number ', number_of_waypoint)
			-- fires event when waypoint reached
			if self._VizualizePathSettings and self._VizualizePathSettings['BreakWaypointAfterComplete'] then
				self:ClearVizualizedPath('Current', number_of_waypoint)
			end
			-- break completed waypoint if on in settings
		end
	end)
	while self:IsMovementRunning() do
		task.wait()
	end
	self:StopMovement(true)
	-- wait until stop running
end
function VersusPath.new(
	Character: Model|Player, 
	PathParams: {}, 
	MoveParams:{Debug:boolean,
		DebugDisplay: {
			WayGenerationFail: boolean,
			MoveTimeOut: boolean,
			MovementFinished: boolean,
			SetupMovementFail: boolean,
			WaypointReached: boolean,
		},
		MaxMoveTime:number,
		VizualizePath:boolean, 
		VizualizePathSettings:
			{
				WaypointTimeout: number,
				StepByStepGeneration: boolean,
				BreakWaypointAfterComplete: boolean, 
				RemoveAfterFinish:boolean,
				TweenSpawn: boolean, 
				Part_Settings: {},
				TweenSettings: 
				{
					TweenInfo:TweenInfo,
					Properties:{}
				}
			}
	}?)
	local self = setmetatable({}, VersusPath)
	if typeof(Character) == 'Player' then
		if not Character.Character then
			return
		end
		self._Character = Character.Character
	else
		self._Character = Character
	end
	-- gets character from player or just sets character
	if not self._Character:FindFirstChildOfClass('Humanoid') then
		self:Debug('SetupMovementFail', 'Character does not contains humanoid!')
		return
	end
	-- debugging some error if not humanoid in character
	self._Humanoid = self._Character:FindFirstChildOfClass('Humanoid')
	-- this part of code gets character to future manipulate with it
	for i, v in MoveParams do
		self['_'..i] = v
	end
	-- this part of code insert all given properties to future manipulate with them
	self._WayFinished = Instance.new('BindableEvent')
	self._WaypointReached = Instance.new('BindableEvent')
	-- create bindables that call on action & return info
	self._VisualizedWaypoints = {
		Current = {},
		Stored = {}
	}
	self._PathBase = PathfindingService:CreatePath(PathParams or {})
	return self
end -- main function that setups meta with all settings & functions in
return VersusPath