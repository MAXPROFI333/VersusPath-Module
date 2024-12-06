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
	VersusPath.new(
		Character Or Player, 
		{},
		{},
	)
]]
local Players = game:GetService("Players")
local PathfindingService = game:GetService("PathfindingService")
local Debris = game:GetService("Debris")
local TweenService = game:GetService("TweenService")

function VersusPath:Debug(type: string, ...)
	if self._Debug then
		if self._DebugDisplay then
			if self._DebugDisplay[type] then
				warn(...)
			end
		else
			warn(...)
		end	
	end
	--this function is used to warn if some action happens
end
function VersusPath:SetupMovement(FinishPosition: Vector3|CFrame)
	if typeof(FinishPosition) == 'CFrame' then
		FinishPosition = FinishPosition.Position
	end
	--if cframe then take position from cframe
	local Success, Error = pcall(function()
		local PathFound = self._PathBase:ComputeAsync(self._Character:GetPivot().Position, FinishPosition)
	end)
	-- generating path from character to given position
	if Success and self._PathBase.Status == Enum.PathStatus.Success then
		return self._PathBase:GetWaypoints()
		--returning table with generated waypoints
	else
		if self._PathBase.Status ~= Enum.PathStatus.Success then
			self:Debug('WayGenerationFail', 'Path Way Not Found!')
			--debugging error about path generation fail
		end
	end
	--this function is made to generate path from character to given position
end
function VersusPath:VizualizePath(Waypoints: {})
	if not self._VizualizePath then
		return
	end
	for i, v: PathWaypoint in Waypoints do
		local WayPart = Instance.new('Part')
		WayPart.Position = v.Position
		WayPart.CanCollide = false
		for i, v in Settings.ClassicalVizualizePartSettings do
			local success, result = pcall(function()
				WayPart[i] = self._VizualizePathSettings['Part_Settings'][i]
			end)
			if not success then
				WayPart[i] = v
			end
		end
		-- creating part which show where's rig moving
		for i, v in (self._VizualizePathSettings and self._VizualizePathSettings['Part_Settings']) or {} do -- check all in part settings
			if Settings.ClassicalVizualizePartSettings[i] == nil then -- check if property is not in classical settings
				local success, result = pcall(function()
					WayPart[i] = v
				end)
				if not success then
					self:Debug('PropertyFail', 'Property Set Error:\n',result)
				end
			end
		end
		if self._VizualizePathSettings then
			if self._VizualizePathSettings['TweenSpawn'] then
				local TweenSettings = self._VizualizePathSettings['TweenSettings'] or Settings.ClassicalTweenSettings -- tween settings
				local success, result = pcall(function()
					local Tween = TweenService:Create(WayPart, TweenSettings['TweenInfo'], TweenSettings['Properties']) -- try to tween
					Tween:Play()
				end)
				if not success then
					self:Debug('TweenFail', 'Waypoint Part Tween Failed :<\n',result) -- debug error on fail
				end
				-- tweening part
			end
			if self._VizualizePathSettings['WaypointTimeout'] then
				Debris:AddItem(WayPart, self._VizualizePathSettings['WaypointTimeout'])
			end
			-- setting up timeout after part destroys 
		end
		table.insert(self._VisualizedWaypoints['Current'], WayPart)
		WayPart.Parent = workspace
	end
end
function VersusPath:ClearVizualizedPath(type:'Stored'|'Current'|'All', Waypoint:number?) -- function that clear vizualized waypoints
	if not self._VizualizePath then
		return
	end
	local LastDestroyed
	local Waypoints = (type == 'All' and {table.unpack(self._VisualizedWaypoints['Stored']), table.unpack(self._VisualizedWaypoints['Current'])}) or self._VisualizedWaypoints[type]
	for i, v: BasePart in (Waypoints[Waypoint] and {Waypoints[Waypoint]}) or Waypoints do
		if v:IsA("BasePart") then
			v:Destroy()
			LastDestroyed = v
		end
	end
	if type == 'All' then
		for i, v: VisualizedWaypointsTable in self._VisualizedWaypoints do
			if typeof(v) == 'table' and not Waypoint then
				table.clear(v)
			else
				if table.find(v, Waypoints[Waypoint]) then
					Waypoints[table.find(v, Waypoints[Waypoint])] = nil
				end
			end
		end
	else
		if not Waypoint then
			table.clear(Waypoints)
		else
			Waypoints[Waypoint] = nil
		end
	end
end
function VersusPath:StoreVizualizedWaypoints()
	for i, v in self._VisualizedWaypoints['Current'] do
		table.insert(self._VisualizedWaypoints['Stored'], v)
	end
	table.clear(self._VisualizedWaypoints['Current'])
	-- stores current waypoints to stored waypoints
end
function VersusPath:IsMovementRunning()
	return self._MovementFunction and coroutine.status(self._MovementFunction) ~= 'dead'
end
function VersusPath:StopMovement(Success:boolean)
	if not self._MovementFunction then
		return
	end
	print('finish movement')
	pcall(task.cancel, self._MovementFunction)
	self._MovementFunction = nil
	self._Humanoid:MoveTo(self._Character:GetPivot().Position)
	-- stops movement
	if self.MoveTimeoutTask then
		pcall(task.cancel, self.MoveTimeoutTask)
		self.MoveTimeoutTask = nil
	end
	if self._VizualizePathSettings and self._VizualizePathSettings['RemoveAfterFinish'] then
		self:ClearVizualizedPath('Current')
	else
		self:StoreVizualizedWaypoints()
	end
	--cancel MoveTimeout
	self._WayFinished:Fire(Success or false)
	self:Debug('MovementFinished', self._Character.Name)
	-- fire event which gives argument finished or not
end
function VersusPath:Break()
	self:StopMovement()
	self:ClearVizualizedPath('All')
	setmetatable(self, nil)
	table.clear(self)
end
function VersusPath:StartMovement(FinishPosition: Vector3|CFrame)
	self:StopMovement()
	self._MovementFunction = task.spawn(function()
		local result = self:SetupMovement(FinishPosition)
		if typeof(result) ~= 'table' then -- check if result is waypoints
			return
		end
		if self._VizualizePathSettings and not self._VizualizePathSettings['StepByStepGeneration'] then -- check if generation is not step by step
			self:VizualizePath(result)
		end
			-- generate all waypoints at one time
		for number_of_waypoint: number, Waypoint: PathWaypoint in result do
			if self._VizualizePathSettings and self._VizualizePathSettings['StepByStepGeneration'] then -- check if step by step generation is true
				self:VizualizePath({Waypoint})
			end
			-- step by step waypoint spawn
			-- stops movement
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
			local finish
			repeat
				self._Humanoid:MoveTo(Waypoint.Position)
				finish = self._Humanoid.MoveToFinished:Wait()
				task.wait()
			until
			finish
			self._WaypointReached:Fire(number_of_waypoint)
			-- moving character through the path
			-- stops movement
			if self._VizualizePathSettings and self._VizualizePathSettings['BreakWaypointAfterComplete'] then
				self:ClearVizualizedPath('Current', number_of_waypoint)
			end
			-- break completed waypoint
		end
		self:StopMovement(true)
	end)
	while self:IsMovementRunning() do
		print(self:IsMovementRunning())
		task.wait()
	end
end
function VersusPath.new(
	Character: Model|Player, 
	PathParams: {}, 
	MoveParams:{Debug:boolean,
		DebugDisplay: {
			WayGenerationFail: boolean,
			MoveTimeOut: boolean,
			TweenFail: boolean,
			PropertyFail: boolean,
			MovementFinished: boolean,
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
	})
	local self = setmetatable({}, VersusPath)
	if typeof(Character) == 'Player' then
		if not Character.Character then
			return
		end
		self._Character = Character.Character
	else
		self._Character = Character
	end
	if not self._Character:FindFirstChildOfClass('Humanoid') then
		self:Debug('SetupMovementFail', 'Character does not contains humanoid!')
		return
	end
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
end
export type VisualizedWaypointsTable = {[number]: BasePart}
return VersusPath