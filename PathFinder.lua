--//Services
local PathfindingService = game:GetService("PathfindingService")
local RunService = game:GetService("RunService")
local Players = game:GetService("Players")


--//Variables
local Module = {}
local LP = Players.LocalPlayer


--//Functions
function ShallowCopy(Waypoint : PathWaypoint)
	return {
		Position = Waypoint.Position,
		Action = Waypoint.Action,
		Label = Waypoint.Label
	}
end

function Module.new(Character : Model)
	local self = setmetatable({}, {
		__index = function(self, index)
			if index == "DestinationReached" then
				return rawget(self, "Reached").Event
			else
				return Module[index]
			end
		end,
	})

	self.Path = PathfindingService:CreatePath({
		AgentRadius = 5,
		AgentHeight = 6
	})
	self.Params = RaycastParams.new()
	
	self.Reached = Instance.new("BindableEvent")
	self.CancelPath = Instance.new("BindableEvent")
	self.Connections = {}
	self.Waypoints = {}
	
	self.Character = Character or LP.Character
	self.Params.FilterDescendantsInstances = {self.Character}
	
	if not Character then	
		LP.CharacterAdded:Connect(function()
			self.Character = LP.Character
			self.Params.FilterDescendantsInstances = {self.Character}
		end)
		
		LP.CharacterRemoving:Connect(function()
			self:StopPath()
			self.EndPoint = nil
		end)
	end

	return self
end

function Module:GetRoot()
	if not self.Character then
		LP.CharacterAdded:Wait()
		task.wait()
	end
	
	return self.Character:WaitForChild("HumanoidRootPart", 2)
end

function Module:GetHumanoid()
	if not self.Character then
		LP.CharacterAdded:Wait()
		task.wait()
	end
	
	return self.Character:WaitForChild("Humanoid", 2)
end

function Module:AddConnection(event)
	self.Connections[#self.Connections + 1] = event
	
	return event
end

function Module:ClearAllConnections()
	for _, Connection in pairs(self.Connections) do
		Connection:Disconnect()
	end
	
	table.clear(self.Connections)
end

function Module:ClearWaypoints()
	if #self.Waypoints == 0 then return end
	
	for _, Waypoint : BasePart in pairs(self.Waypoints) do
		Waypoint:Destroy()
	end

	table.clear(self.Waypoints)
end

function Module:HasReached()
	if not self.EndPoint then return false end
	
	return (self:GetRoot().Position - self.EndPoint).Magnitude < 4
end

function Module:StopPath()
	self.CancelPath:Fire()
	self:ClearWaypoints()
	self.EndPoint = nil
end

function Module:CheckIfStuck()
	local Root = self:GetRoot()
	local Raycast = workspace:Raycast(Root.Position, Root.CFrame.LookVector * 2.5, self.Params)
	
	if Raycast then
		return true
	end
end

function Module:WalkPath(EndPoint)
	if self.EndPoint == EndPoint then return end
	
	self:StopPath()
	
	task.wait()
	
	local Root = self:GetRoot()
	local Humanoid = self:GetHumanoid()
	
	self.Path:ComputeAsync(Root.Position, EndPoint)

	local Waypoints = self.Path:GetWaypoints()
	
	self.EndPoint = EndPoint
	
	task.spawn(function()
		local PathCanceled = false
		local CancelEvent = self:AddConnection(self.CancelPath.Event:Once(function()
			PathCanceled = true
			Humanoid:Move(Vector3.new())
		end))
		
		if self.Visualize then
			for _, Waypoint : PathWaypoint in pairs(Waypoints) do				
				local NewWaypoint = Instance.new("Part")

				NewWaypoint.Anchored = true
				NewWaypoint.CanCollide = false
				NewWaypoint.Material = Enum.Material.Neon
				NewWaypoint.Size = Vector3.one
				NewWaypoint.Position = Waypoint.Position
				NewWaypoint.Color = Waypoint.Action == Enum.PathWaypointAction.Jump and BrickColor.Green().Color or NewWaypoint.Color

				NewWaypoint.Parent = workspace

				table.insert(self.Waypoints, NewWaypoint)
			end
		end
		
		local CurrentWaypoint = ShallowCopy(Waypoints[1])
		local LastDistance
		
		repeat
			RunService.RenderStepped:Wait()
			
			if PathCanceled then
				break
			end
			
			local RawDistance = CurrentWaypoint.Position - Root.Position
			local Distance = (RawDistance * Vector3.new(1, 0, 1)).Magnitude
			local MoveDirection = RawDistance.Unit
			
			Humanoid:Move(MoveDirection)
			
			if LastDistance then
				local Difference = math.abs(LastDistance - Distance)
				
				if Difference < 0.1 and self:CheckIfStuck() then
					Humanoid.Jump = true
				end
			end
			
			if not CurrentWaypoint.Jumped and Distance < 5 and CurrentWaypoint.Action == Enum.PathWaypointAction.Jump then
				Humanoid.Jump = true
				CurrentWaypoint.Jumped = true
			end
			
			if Distance < 2 then
				table.remove(Waypoints, 1)
				
				if #Waypoints > 0 then
					CurrentWaypoint = ShallowCopy(Waypoints[1])
				end
			end
			
			LastDistance = Distance
		until #Waypoints == 0 
		
		CancelEvent:Disconnect()
		self:ClearWaypoints()
		self.Reached:Fire()
	end)
end


--//Script
return Module