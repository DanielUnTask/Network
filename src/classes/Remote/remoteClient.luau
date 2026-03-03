--!strict
local RemoteClient = {}
RemoteClient.__index = RemoteClient

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
type NetworkRemoteClient = Types.NetworkRemoteClient
type ClientChannel<A... = (), B... = ()> = Types.ClientChannel<A..., B...>

type PrivateChannel<A... = (), B... = ()> = ClientChannel<A..., B...> & {
	Name: string,
	GUID: number,
	ResponseTimeout: number?,
	OnClientInvoke: nil | Types.ClientResponse<A..., B...>,
	_removing: boolean,
}

type PrivateRemote<A... = (), B... = ()> = NetworkRemoteClient & {
	Name: string,
	_event: RemoteEvent,
	_cache: { [string | number]: PrivateChannel<A..., B...> },
	_threads: { [number]: { Yielded: thread, Timeout: thread }, Index: number },

	_trove: typeof(Trove.new()),
	_destroying: boolean,
	_setup: (self: PrivateRemote<A..., B...>) -> (),
}

--- Constructor
function RemoteClient.new<A..., B...>(remoteName: string, parent: Folder): NetworkRemoteClient
	local self = (setmetatable({}, RemoteClient) :: any) :: PrivateRemote<A..., B...>
	self._trove = (Trove.new() :: any) :: typeof(Trove.new())

	self.Name = remoteName
	self._event = parent:WaitForChild(remoteName) :: RemoteEvent

	self._cache = {}
	self._threads = { Index = 0 }

	self:_setup()
	return (self :: any) :: NetworkRemoteClient
end

--- Private
function RemoteClient._setup<A..., B...>(self: PrivateRemote<A..., B...>)
	local function answer(attribute: PrivateChannel<A..., B...>, threadIndex: number, ...)
		if not attribute.OnClientInvoke then
			return
		end
		local values = { attribute.OnClientInvoke(...) }
		self._event:FireServer(attribute.GUID, threadIndex + 128, table.unpack(values))
	end

	self._trove:Connect(self._event.OnClientEvent, function(guid: number, threadIndex: number?, ...)
		local attribute = self._cache[guid]
		if not attribute then
			return
		end

		if threadIndex and threadIndex >= 0 then
			if attribute.ResponseTimeout then
				if threadIndex < 128 then
					Task:defer(answer, attribute, threadIndex, ...)
					return
				end

				threadIndex -= 128
				local responseThread = self._threads[threadIndex]
				if responseThread then
					task.cancel(responseThread.Timeout)
					task.defer(responseThread.Yielded, ...)
					self._threads[threadIndex] = nil
				end
				return
			end
		end

		attribute.OnClientEvent:Fire(...)
	end)

	self._trove:Add(function()
		self._destroying = true
	end)

	self._trove:Connect(self._event.AttributeChanged, function(attribute: string)
		local channel = self._cache[attribute]
		if not channel then
			return
		end
		if self._cache[channel.GUID] then
			self._cache[channel.GUID] = nil
		end
		local index = self._event:GetAttribute(channel.Name)
		if not index then
			channel._removing = true
			self._trove:Remove(channel)
			return
		end
		channel.GUID = index
		self._cache[channel.GUID] = channel
	end)

	self._trove:AttachToInstance(self._event)
end

--- Public
function RemoteClient.Get<A..., B...>(self: PrivateRemote<A..., B...>, channelName: string): ClientChannel<A..., B...>
	if self._cache[channelName] then
		return (self._cache[channelName] :: any) :: ClientChannel<A..., B...>
	end
	return (self._trove:Construct(Channels.ClientChannel, channelName, self :: any) :: any) :: ClientChannel<A..., B...>
end

function RemoteClient.Destroy<A..., B...>(self: PrivateRemote<A..., B...>)
	if self._destroying then
		return
	end

	self._trove:Destroy()
end

return RemoteClient.new
