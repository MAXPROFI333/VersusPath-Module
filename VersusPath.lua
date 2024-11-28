local VersusPath = {}
VersusPath.__index = VersusPath
VersusPath._error_text = 'BRUH! Movement Failed :(\n'

--[[ TUTORIAL OUTDATED
	Small Description:
		YO! This is the advanced module to work with pathfinding service.
		This module was made by @badaboss|discord id: 
	How To Use It:
		How To Setup:
		VersusPath.new(
			Player Or Character, --Type Here NPC or Player Which You'd Like To Move
			{} Or nil, --Basic Params For PathfindingService:CreatePath
			{ --Advanced Params
				Debug=true Or false Or nil, --If rrue, Some Info Will Be Shown In Output
				MaxMoveTime=number Or nil, --Time After NPC Stops, If Not Finish Walking To The Waypoint
				VizualizePath=true Or false Or nil, --If true, Script Will Create Parts To Show Path
				VizualizePathSettings={  --Advanced Vizualize Path Settings
					WaypointTimeout=3 Or nil, --Time After Waypoint Destroys
					StepByStepGeneration=true, --If true, Waypoints Will Spawn When NPC Walk On It! If false or nil, All Waypoints Will Be Created At Once
					BreakWaypointAfterComplete=true Or false Or nil, --If true, After NPC Complete Waypoint Will Be Destroyed
					RemoveAfterFinish=true Or false Or nil, --If True, After Finish All Waypoints Will Be Destroyed
				}
			}
		) -- returns table
]]
VersusPath.ClassicalVizualizePartSettings = {
	Size = Vector3.new(1,1,1),
	Anchored = true,
	BrickColor = BrickColor.White(),
	Material = Enum.Material.Neon,
}
VersusPath.ClassicalTweenSettings = {
	TweenInfo = TweenInfo.new(0.6, Enum.EasingStyle.Sine),
	Properties = {
		Transparency = 0
	}
}

local Players = game:GetService("Players")
local PathfindingService = game:GetService("PathfindingService")
local Debris = game:GetService("Debris")
local TweenService = game:GetService("TweenService")

function VersusPath:Debug(type: string, ...)
	if self._Debug then -- Check if debug mode is on
		if self._DebugDisplay then -- Check if DebugDisplay setting is given
			if self._DebugDisplay[type] then -- Check if debug message type is allowed
				warn(...) -- Display information
			end
		else -- if debug settings is not given
			warn(...) -- Display information
		end	
	end
end
function VersusPath:SetupMovement(FinishPosition: Vector3|CFrame)
	if not self._Character:FindFirstChildOfClass('Humanoid') then -- check if character contains humanoid
		return 'Failed To Find Humanoid In Character'
	end
	self._Humanoid = self._Character:FindFirstChildOfClass('Humanoid') -- set humanoid 
	if typeof(FinishPosition) == 'CFrame' then -- check if position is cframe
		FinishPosition = FinishPosition.Position -- set position to cframe's position 
	end
	local Success, Error = pcall(function() -- pcall
		local PathFound = self._PathBase:ComputeAsync(self._Character:GetPivot().Position, FinishPosition) -- generating waypoints
	end)
	if Success and self._PathBase.Status == Enum.PathStatus.Success then -- check if generation is success
		return self._PathBase:GetWaypoints() -- returning waypoints
	else -- if failed
		if self._PathBase.Status ~= Enum.PathStatus.Success then
			Error = 'Path Way Not Found!'
		elseif not Error then
			Error = 'Pcall Not Gave Any Error ;['
		end
		return 'Path not computed! \n'.. Error
	end
end
function VersusPath:VizualizePath(Waypoints: {})
	for i, v: PathWaypoint in Waypoints do
		local WayPart = Instance.new('Part') --creating part
		WayPart.Position = v.Position --set part position to waypoint position
		WayPart.CanCollide = false --set part collision to false
		for i, v in self.ClassicalVizualizePartSettings do -- check all classical settings
			local success, result = pcall(function() --pcall
				WayPart[i] = self._VizualizePathSettings['Part_Settings'][i] --try to set part property
			end)
			if not success then -- on error
				WayPart[i] = v -- set classical property
			end
		end
		if self._VizualizePathSettings then -- check if VizualizePathSettings exist
			for i, v in self._VizualizePathSettings['Part_Settings'] or {} do -- check all in part settings
				if self.ClassicalVizualizePartSettings[i] == nil then -- check if property is not in classical settings
					local success, result = pcall(function()
						WayPart[i] = v -- try to set property
					end)
					if not success then
						self:Debug('PropertyFail', 'Property Set Error:\n',result) -- debug on fail
					end
				end
			end
			if self._VizualizePathSettings['TweenSpawn'] then -- if tween spawn is true
				local TweenSettings = self._VizualizePathSettings['TweenSettings'] or self.ClassicalTweenSettings -- tween settings
				local success, result = pcall(function()
					local Tween = TweenService:Create(WayPart, TweenSettings['TweenInfo'], TweenSettings['Properties']) -- try to tween
					Tween:Play()
				end)
				if not success then
					self:Debug('TweenFail', 'Waypoint Part Tween Failed :<\n',result) -- debug error on fail
				end
			end
			if self._VizualizePathSettings['WaypointTimeout'] then -- if waypoint timeout is given
				Debris:AddItem(WayPart, self._VizualizePathSettings['WaypointTimeout']) -- add waypoint timeout
			end
		end
		table.insert(self._VisualizedWaypoints, WayPart)
		WayPart.Parent = workspace
	end
end
function VersusPath:StopMovement()
	self.MoveTimeOut = true -- sets move timeout argument to true
	self._MoveFinishedEvent:Fire() -- fires skip of walk to the waypoint
end
function VersusPath:StartMovement(FinishPosition: Vector3|CFrame)
	local result = self:SetupMovement(FinishPosition) -- way generation
	if typeof(result) == 'table' then -- check if result is waypoints
		self.MoveTimeOut = false -- set movetimeout to false
		local MoveTimeoutTask = nil
		local FinishedWay = true 
		self._RunningPath = true
		if self._VizualizePath and self._VizualizePathSettings and not self._VizualizePathSettings['StepByStepGeneration'] then -- check if generation is not step by step
			self:VizualizePath(result) -- generate all waypoints
		end
		for number_of_waypoint: number, Waypoint: PathWaypoint in result do
			if self._VizualizePath and self._VizualizePathSettings and self._VizualizePathSettings['StepByStepGeneration'] then -- check if step by step generation is true
				self:VizualizePath({Waypoint}) -- spawn one waypoint
			end
			if self.MoveTimeOut then -- check if move time out
				FinishedWay = false -- set finished way property to false
				break -- stop movement for 
			end
			if self._MaxMoveTime then -- check if max movement time is given
				if MoveTimeoutTask then -- check if movetimeout task is exist
					task.cancel(MoveTimeoutTask) -- cancelling task
					MoveTimeoutTask = nil -- set property to nil
				end
				MoveTimeoutTask = task.delay(self._MaxMoveTime, function() -- creating new task which calls after time
					self:Debug('MoveTimeOut', self._error_text,'Move Time Out') -- send debug message 
					self.MoveTimeOut = true -- set movetimeout property to true 
				end)
			end
			if Waypoint.Action == Enum.PathWaypointAction.Jump then -- check if action is jump
				self._Humanoid:ChangeState(Enum.HumanoidStateType.Jumping) -- jump
			end
			self._Humanoid:MoveTo(Waypoint.Position)  -- move rig to waypoint
			local MoveConnection: RBXScriptConnection = self._Humanoid.MoveToFinished:Connect(function() -- connect move to finished event
				self._MoveFinishedEvent:Fire() -- fire move finish event
			end)
			self._MoveFinishedEvent.Event:Wait() -- wait until move finish event call
			MoveConnection:Disconnect() -- disconnect   disconnect move to finished event 
			if self._VizualizePathSettings and self._VizualizePathSettings['BreakWaypointAfterComplete'] then -- check if break waypoint after complete 
				self._VisualizedWaypoints[number_of_waypoint]:Destroy() -- break waypoint
			end
		end
		self._Humanoid:MoveTo(self._Character:GetPivot().Position) -- stop movement
		self._WayFinished:Fire(FinishedWay) -- fire event which gives argument finished or not
		if self._VizualizePath and self._VizualizePathSettings and self._VizualizePathSettings['RemoveAfterFinish'] then -- check if RemoveAfterFinish argument is true
			for i, v in self._VisualizedWaypoints do -- get visualized waypoints
				v:Destroy() -- break waypoint
			end
		end
		table.clear(self._VisualizedWaypoints)
		self._RunningPath = false
	else -- if result is not waypoints
		self:Debug('WayGenerationFail', self._error_text, result)
		return
	end
end
function VersusPath.new(
	Character: Model|Player, 
	PathParams: {}, 
	MoveParams:{
		Debug:boolean,
		DebugDisplay: {
			WayGenerationFail: boolean,
			MoveTimeOut: boolean,
			TweenFail: boolean,
			PropertyFail: boolean,
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
	local self = setmetatable({}, VersusPath) -- set metatable from VersusPath to empty table
	if typeof(Character) == 'Player' then --check if argument Character is Player
		if not Character.Character then --check if player hasn't a Character
			return --stop function
		end
		self._Character = Character.Character --sets _Character to player's Character
	else --if not type of argument Character is Player
		self._Character = Character --sets _Character to Character
	end
	for i, v in MoveParams do --work with all ellements in MoveParams
		self['_'..i] = v --put property into table
	end
	self._RunningPath = false -- creating "RunningPath" property
	self._WayFinished = Instance.new('BindableEvent') -- an creating advanced BindableEvent which calls on way finish and returns completed or not completed boolean
	self._MoveFinishedEvent = Instance.new('BindableEvent') -- one more event which answers to switch to next waypoint
	self._VisualizedWaypoints = {} -- creating table where will be Visualized Waypoints
	self._PathBase = PathfindingService:CreatePath(PathParams or {}) -- just creating path to generate waypoints
	return self --returning metatable self
end
return VersusPath