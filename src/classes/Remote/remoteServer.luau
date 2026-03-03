--!strict
local RemoteServer = {}
RemoteServer.__index = RemoteServer

--- Services
local Players = game:GetService("Players")

--- Directories
local Root = script.Parent.Parent.Parent

--- Dependencies
local Types = require(Root.types)
local External = require(Root.external)
local Channels = require(Root.classes.Channel)

--- Packages
local Task = External.Task
local Trove = External.Trove

--- Types
type NetworkRemoteServer = Types.NetworkRemoteServer
type ServerChannel<A... = (), B... = ()> = Types.ServerChannel<A..., B...>

type PrivateChannel<A... = (), B... = ()> = ServerChannel<A..., B...> & {
	GUID: number,
	ResponseTimeout: number,
	OnServerInvoke: nil | Types.ServerResponse<A..., B...>,
}

type PrivateRemote<A... = (), B... = ()> = NetworkRemoteServer & {
	Name: string,
	Index: number,

	_saveFolder: Instance,
	_event: RemoteEvent,
	_cache: { [string | number]: PrivateChannel<A..., B...> },
	_playerThreads: { [Player]: { [number]: { Yielded: thread, Timeout: thread }, Index: number } },

	_trove: typeof(Trove.new()),
	_destroying: boolean,
	_setup: (self: PrivateRemote<A..., B...>) -> (),
}

--- Constructor
function RemoteServer.new<T...>(remoteName: string, parent: Instance): NetworkRemoteServer
	local self = (setmetatable({}, RemoteServer) :: any) :: PrivateRemote<T...>
	self._trove = (Trove.new()) :: typeof(Trove.new())

	self.Name = remoteName
	self.Index = 0

	self._saveFolder = parent
	self._event = (self._trove:Construct(Instance, "RemoteEvent") :: any) :: RemoteEvent

	self._cache = {}
	self._playerThreads = { Index = 0 }

	self:_setup()
	return (self :: any) :: NetworkRemoteServer
end

--- Private
function RemoteServer._setup<A..., B...>(self: PrivateRemote<A..., B...>)
	local function answer(attribute: PrivateChannel<A..., B...>, player: Player, threadIndex: number, ...)
		if not attribute.OnServerInvoke or player.Parent ~= Players then
			return
		end
		local values = { attribute.OnServerInvoke(...) }
		self._event:FireClient(player, attribute.GUID, threadIndex + 128, table.unpack(values))
	end

	self._trove:Connect(self._event.OnServerEvent, function(player: Player, guid: number, threadIndex: number?, ...)
		local attribute = self._cache[guid]
		if not attribute then
			return
		end

		if threadIndex and threadIndex >= 0 then
			if attribute.ResponseTimeout then
				if threadIndex < 128 then
					Task:defer(answer, attribute, player, threadIndex, ...)
					return
				end

				threadIndex -= 128
				local responseThread = self._playerThreads[player][threadIndex]
				if responseThread then
					task.cancel(responseThread.Timeout)
					task.defer(responseThread.Yielded, ...)
					self._playerThreads[player][threadIndex] = nil
				end

				return
			end
		end

		attribute.OnServerEvent:Fire(player, ...)
	end)

	self._trove:Connect(Players.PlayerRemoving, function(player: Player)
		local threadTable = self._playerThreads[player]
		if not threadTable then
			return
		end
		self._playerThreads[Players] = nil
		for _, thread in threadTable do
			if typeof(thread) == "number" then
				continue
			end
			task.cancel(thread.Timeout)
			task.cancel(thread.Yielded)
		end
	end)

	self._trove:Add(function()
		for _, threadTable in self._playerThreads do
			if typeof(threadTable) == "number" then
				continue
			end

			for _, thread in threadTable do
				if typeof(thread) == "number" then
					continue
				end
				task.cancel(thread.Timeout)
				task.cancel(thread.Yielded)
			end
		end
		self._playerThreads = {}
	end)

	self._event.Name = self.Name
	self._event.Parent = self._saveFolder
end

--- Public Methods
function RemoteServer.Get<A..., B...>(self: PrivateRemote<A..., B...>, attributeName: string): ServerChannel<A..., B...>
	if self._cache[attributeName] then
		return (self._cache[attributeName] :: any) :: ServerChannel<A..., B...>
	end
	return (
		self._trove:Construct(Channels.ServerChannel, attributeName, self :: any) :: any
	) :: ServerChannel<A..., B...>
end

function RemoteServer.Destroy<T...>(self: PrivateRemote<T...>)
	if self._destroying then
		return
	end
	self._destroying = true
	self._trove:Destroy()
end

return RemoteServer.new
