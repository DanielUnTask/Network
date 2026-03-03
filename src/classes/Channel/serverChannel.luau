--!strict
local ServerChannel = {}
ServerChannel.__index = ServerChannel

--- Directories
local Players = game:GetService("Players")
local Root = script.Parent.Parent.Parent

--- Dependencies
local Types = require(Root.types)
local External = require(Root.external)

--- Packages
local Task = External.Task
local Trove = External.Trove
local Signal = External.Signal

--- Types
type NetworkRemote<A... = (), B... = ()> = Types.NetworkRemoteServer & {
	Index: number,
	_event: RemoteEvent,
	_cache: { [string | number]: PrivateChannel<A..., B...> },
	_playerThreads: { [Player]: { [number]: { Yielded: thread, Timeout: thread }, Index: number } },

	_trove: typeof(Trove.new()),
	_destroying: boolean,
}

type PrivateChannel<A... = (), B... = ()> = Types.ServerChannel<A..., B...> & {
	Name: string,
	GUID: number,
	Remote: NetworkRemote<A..., B...>,

	ResponseValue: any?,
	ResponseTimeout: number?,
	OnServerInvoke: nil | Types.ServerResponse<A..., B...>,

	_trove: typeof(Trove.new()),
	_destroying: boolean,
}

--- Constructor
function ServerChannel.new<A..., B...>(
	channelName: string,
	networkRemote: NetworkRemote<A..., B...>
): Types.ServerChannel<A..., B...>
	local self = (setmetatable({}, ServerChannel) :: any) :: PrivateChannel<A..., B...>
	self.Remote = networkRemote
	self._trove = (Trove.new() :: any) :: typeof(Trove.new())

	self.Name = channelName
	self.GUID = networkRemote.Index
	self.OnServerEvent = (self._trove:Construct(Signal.new) :: any) :: Types.NetworkSignal<(Player, A...)>

	networkRemote._event:SetAttribute(channelName, self.GUID)
	networkRemote._cache[self.GUID] = self
	networkRemote._cache[channelName] = self
	networkRemote.Index += 1

	self._trove:Add(function()
		self.Remote._cache[self.Name] = nil
		self.Remote._cache[self.GUID] = nil
		self.Remote._event:SetAttribute(self.Name, nil)
	end)

	return (self :: any) :: Types.ServerChannel<A..., B...>
end

--- Public

function ServerChannel.Response<A..., B...>(self: PrivateChannel<A..., B...>, timeout: number?): Types.ServerChannel<A..., B...>
	self.ResponseTimeout = timeout or 10
	return (self :: any) :: Types.ServerChannel<A..., B...>
end

function ServerChannel.FireClient<A..., B...>(self: PrivateChannel<A..., B...>, player: Player, ...: A...): B...
	if player.Parent == Players then
		local remote = self.Remote

		if not self.ResponseTimeout then
			remote._event:FireClient(player, self.GUID, nil, ...)
		else
			local threadsForPlayer = remote._playerThreads[player]
			if not threadsForPlayer then
				threadsForPlayer = { Index = 0 }
				remote._playerThreads[player] = threadsForPlayer
			end

			local responseThread
			for _ = 1, 128 do
				responseThread = threadsForPlayer[threadsForPlayer.Index]
				if responseThread then
					threadsForPlayer.Index = (threadsForPlayer.Index + 1) % 128
					continue
				end
				break
			end

			if responseThread then
				error(`{player.Name} cannot have more than 128 threads in a pending state.`, 2)
			end

			local threadIndex = threadsForPlayer.Index
			threadsForPlayer[threadIndex] = {
				Yielded = coroutine.running(),
				Timeout = task.delay(self.ResponseTimeout, Task.defer, Task, function()
					local response = threadsForPlayer[threadIndex]
					if response then
						task.defer(response.Yielded, self.ResponseValue)
						threadsForPlayer[threadIndex] = nil
					end
				end),
			}

			threadsForPlayer.Index = (threadsForPlayer.Index + 1) % 128
			remote._event:FireClient(player, self.GUID, threadIndex, ...)
			return coroutine.yield()
		end
	end
end

function ServerChannel.FireAllClients<A..., B...>(self: PrivateChannel<A..., B...>, ...: A...)
	assert(not self.ResponseTimeout, "Invalid call: this method is not available in Invoke mode.")
	local remote = self.Remote
	remote._event:FireAllClients(self.GUID, nil, ...)
end

function ServerChannel.SetCallback<A..., B...>(self: PrivateChannel<A..., B...>, callback: Types.ServerResponse<A..., B...>)
	if not self.ResponseTimeout then
		return
	end
	self.OnServerInvoke = callback
end

function ServerChannel.Destroy<A..., B...>(self: PrivateChannel<A..., B...>)
	if self._destroying then
		return
	end

	self._destroying = true
	if not self.Remote._destroying then
		self.Remote._trove:Pop(self)
	end

	self._trove:Destroy()
end

return ServerChannel.new
