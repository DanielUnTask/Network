--!strict
local ClientChannel = {}
ClientChannel.__index = ClientChannel

--- Directories
local Root = script.Parent.Parent.Parent

--- Dependencies
local Types = require(Root.types)
local External = require(Root.external)

--- Packages
local Task = External.Task
local Trove = External.Trove
local Signal = External.Signal

--- Types
type NetworkRemote<A... = (), B... = ()> = Types.NetworkRemoteClient & {
	_event: RemoteEvent,
	_cache: { [string | number]: PrivateChannel<A..., B...> },
	_threads: { [number]: { Yielded: thread, Timeout: thread }, Index: number },

	_trove: typeof(Trove.new()),
	_destroying: boolean,
}

type PrivateChannel<A... = (), B... = ()> = Types.ClientChannel<A..., B...> & {
	Name: string,
	GUID: number,
	Remote: NetworkRemote<A..., B...>,

	ResponseValue: any?,
	ResponseTimeout: number?,
	OnClientInvoke: nil | Types.ClientResponse<A..., B...>,

	_trove: typeof(Trove.new()),
	_destroying: boolean,
	_removing: boolean,
}

--- Constructor
function ClientChannel.new<A..., B...>(
	channelName: string,
	networkRemote: NetworkRemote<A..., B...>
): Types.ClientChannel<A..., B...>
	local self = (setmetatable({}, ClientChannel) :: any) :: PrivateChannel<A..., B...>
	self.Remote = networkRemote
	self._trove = (Trove.new() :: any) :: typeof(Trove.new())

	self.Name = channelName
	self.GUID = networkRemote._event:GetAttribute(channelName)
	self.OnClientEvent = (self._trove:Construct(Signal.new) :: any) :: Types.NetworkSignal<(A...)>

	networkRemote._cache[channelName] = self
	if self.GUID then
		networkRemote._cache[self.GUID] = self
	end

	self._trove:Add(function()
		self.Remote._cache[self.Name] = nil
		if self.Remote._cache[self.GUID] then
			self.Remote._cache[self.GUID] = nil
		end
	end)

	return (self :: any) :: Types.ClientChannel<A..., B...>
end

--- Public

function ClientChannel.Response<A..., B...>(self: PrivateChannel<A..., B...>, timeout: number?): Types.ClientChannel<A..., B...>
	self.ResponseTimeout = timeout or 10
	return (self :: any) :: Types.ClientChannel<A..., B...>
end

function ClientChannel.FireServer<A..., B...>(self: PrivateChannel<A..., B...>, ...: A...): B...
	local remote = self.Remote
	if not self.ResponseTimeout then
		remote._event:FireServer(...)
	else
		local responseThread
		for _ = 1, 128 do
			responseThread = remote._threads[remote._threads.Index]
			if responseThread then
				remote._threads.Index = (remote._threads.Index % 128)
				continue
			end
			break
		end

		if responseThread then
			error(`cannot have more than 128 threads in a pending state.`, 2)
		end

		local threadIndex = remote._threads.Index
		remote._threads[threadIndex] = {
			Yielded = coroutine.running(),
			Timeout = task.delay(self.ResponseTimeout, Task.defer, Task, function()
				local invokeResponse = remote._threads[threadIndex]
				if invokeResponse then
					task.defer(invokeResponse.Yielded, self.ResponseValue)
					remote._threads[threadIndex] = nil
				end
			end),
		}

		remote._threads.Index = (remote._threads.Index + 1) % 128
		remote._event:FireServer(self.GUID, threadIndex, ...)
		return coroutine.yield()
	end
end

function ClientChannel.SetCallback<A..., B...>(self: PrivateChannel<A..., B...>, callback: Types.ClientResponse<A..., B...>)
	if not self.ResponseTimeout then
		return
	end
	self.OnClientInvoke = callback
end

function ClientChannel.Destroy<A..., B...>(self: PrivateChannel<A..., B...>)
	if self._destroying then
		return
	end

	self._destroying = true
	if not self.Remote._destroying and not self._removing then
		self.Remote._trove:Pop(self)
	end

	self._trove:Destroy()
end

return ClientChannel.new
