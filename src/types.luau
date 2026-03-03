--!strict
--!optimize 2

--- Utils Types

--[=[
   @type ClientResponse (A...) -> B...
]=]
export type ClientResponse<A..., B...> = (A...) -> B...

--[=[
   @type ServerResponse (A...) -> B...
]=]
export type ServerResponse<A..., B...> = (player: Player, A...) -> B...

--- Public Types

--[=[
   @interface NetworkConnection
   .Connected boolean
   .Disconnect (self, NetworkConnection) -> ()
   .Destroy (self, NetworkConnection) -> ()
]=]
export type NetworkConnection<A... = ()> = {
	Connected: boolean,
	Disconnect: (self: NetworkConnection<A...>) -> (),
	Destroy: (self: NetworkConnection<A...>) -> (),
}

--[=[
   @interface NetworkSignal
   .Wait (self, NetworkSignal) -> A...
   .Fire (self, NetworkSignal, A...) -> ()
   .Once (self, NetworkSignal, callback) -> ()
   .Connect (self, NetworkSignal, callback) -> ()
   .DisconnectAll (self, NetworkSignal) -> ()
   .Destroy (self, NetworkSignal) -> ()
]=]
export type NetworkSignal<A... = ()> = {
	Wait: (self: NetworkSignal<A...>) -> A...,
	Fire: (self: NetworkSignal<A...>, A...) -> (),
	Once: (self: NetworkSignal<A...>, callback: (A...) -> ()) -> NetworkConnection<A...>,
	Connect: (self: NetworkSignal<A...>, callback: (A...) -> ()) -> NetworkConnection<A...>,
	DisconnectAll: (self: NetworkSignal<A...>) -> (),
	Destroy: (self: NetworkSignal<A...>) -> (),
}

--[=[
   @interface ServerChannel
   .OnServerEvent NetworkSignal
   .SetCallback (self, ServerChannel, ServerResponse) -> ()
   .FireClient (self, ServerChannel, player, A...) -> B...
   .FireAllClients (self, ServerChannel, A...) -> ()
   .Response: (self: ServerChannel, timeout: number?) -> ServerChannel,
   .Destroy (self, ServerChannel) -> ()
]=]
export type ServerChannel<A... = (), B... = ()> = {
	OnServerEvent: NetworkSignal<(Player, A...)>,
	SetCallback: (self: ServerChannel<A..., B...>, callback: ServerResponse<A..., B...>) -> (),
	FireClient: (self: ServerChannel<A..., B...>, player: Player, A...) -> B...,
	FireAllClients: (self: ServerChannel<A..., B...>, A...) -> (),
	Response: (self: ServerChannel<A..., B...>, timeout: number?) -> ServerChannel<A..., B...>,
	Destroy: (self: ServerChannel<A..., B...>) -> (),
}

--[=[
   @interface ClientChannel
   .OnClientEvent NetworkSignal
   .SetCallback (self, ClientChannel, ClientResponse) -> ()
   .FireServer (self, ClientChannel, A...) -> B...
   .Response: (self: ClientChannel, timeout: number?) -> ClientChannel,
   .Destroy (self, ClientChannel) -> ()
]=]
export type ClientChannel<A... = (), B... = ()> = {
	OnClientEvent: NetworkSignal<A...>,
	SetCallback: (self: ClientChannel<A..., B...>, callback: ClientResponse<A..., B...>) -> (),
	FireServer: (self: ClientChannel<A..., B...>, A...) -> B...,
	Response: (self: ClientChannel<A..., B...>, timeout: number?) -> ClientChannel<A..., B...>,
	Destroy: (self: ClientChannel<A..., B...>) -> (),
}

--[=[
   @interface NetworkRemoteServer
   .Get (self, channelName) -> ServerChannel
   .Destroy (self) -> ()
]=]
export type NetworkRemoteServer = {
	Get: <A..., B...>(self: NetworkRemoteServer, channelName: string) -> ServerChannel<A..., B...>,
	Destroy: (self: NetworkRemoteServer) -> (),
}

--[=[
   @interface NetworkRemoteClient
   .Get (self, channelName) -> ClientChannel
   .Destroy (self) -> ()
]=]
export type NetworkRemoteClient = {
	Get: <A..., B...>(self: NetworkRemoteClient, channelName: string) -> ClientChannel<A..., B...>,
	Destroy: (self: NetworkRemoteClient) -> (),
}

--[=[
   @interface Network
   .client (name, customParent) -> NetworkRemoteClient
   .server (name, customParent) -> NetworkRemoteServer
   .signal () -> NetworkSignal
   .wrapSignal (signal) -> NetworkSignal
]=]
export type Network = {
	client: (name: string, customParent: Folder?) -> NetworkRemoteClient,
	server: (name: string, customParent: Folder?) -> NetworkRemoteServer,
	signal: <A...>() -> NetworkSignal<A...>,
	wrapSignal: <A...>(signal: RBXScriptSignal | NetworkSignal<A...>) -> NetworkSignal<A...>,
}

return nil
