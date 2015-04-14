class ChatChannel
	attr_accessor	:clients
	attr_accessor	:roomName
	
	def initialize(project, roomName)
		@project = project
		@roomName = roomName
		@clients = { }
		puts "Chat room #{roomName} initialized"
	end

	def getClient(ws)
		if (@clients[ws])
			return(@clients[ws])
		elsif
			puts "Invalid client with socket: #{ws}"
			return FALSE
		end
	end
	
	def getClientByName(name)
		@clients.each do |websocket, client|
			if (client.name == name)
				return(client)
			end
		end
		return false
	end
	
	def getClientNames
		@clients.collect{|websocket, c| c.name}.sort
	end
	
	def addClient(client, ws)
		if (@clients[ws]) 
			puts "This client already exists"
		end
		if (getClientByName(client.name))
			puts "This client already exists by name"
			return false
		end
		@clients[ws] = client 
		@clientPropagate = {
			'commandSet' => 'chat',
			'command' => 'userJoin',
			'userJoin' => {
				'chat' => @roomName,
				'user' => client.name,
			},
		}
		puts "Propogate message: "
		puts @clientPropagate.inspect
		@clientString = @clientPropagate.to_json
		sendToClients(@clientString)
		@clientMessage = { 
			'commandSet' => 'chat',
			'command' => 'userList',
			'userList' => {
				'list' => getClientNames(),
				'chat' => @roomName,
			},
		}
		sendToClient(client, @clientMessage.to_json)
	end
	
	def remClient(client)
	  client.removeChat(@roomName)
		@clients.delete(client.websocket)
		@roomMsg = {
			'commandSet' => 'chat',
			'command' => 'userLeave',
			'userLeave' => {
	        		'chat' => @roomName,
			        'user' => client.name,
			},
		}
		@clientString = @roomMsg.to_json
		sendToClients(@clientString)
	end
	
	def procMsg(client, jsonMsg)
		puts "Asked to process a message for myself: #{@roomName} from client #{client.name}"
		if (!getClient(client.websocket) && jsonMsg['chatCommand'] != 'joinChannel')
			puts "Client has not formally joined the channel -- this is OK in alpha state, adding client implicitly"
		end
		if (self.respond_to?("procMsg_#{jsonMsg['chatCommand']}"))
			puts "Found a function handler for  #{jsonMsg['chatCommand']}"
			self.send("procMsg_#{jsonMsg['chatCommand']}", client, jsonMsg);
		elsif
			puts "There is no function to handle the incoming command #{jsonMsg['chatCommand']}"
		end
	end
	
	def procMsg_sendMessage(client, jsonMsg)
		puts "procMsg_sendMessage executing"
		@clientReply = {
			'commandSet' => 'chat',
			'commandReply' => true,
			'command' => 'sendMessage',
			'sendMessage' => {
					'status' => TRUE,
			},
		}
		@clientString = @clientReply.to_json
		sendToClient(client, @clientString)
		@clientPropagate = {
			'commandSet' => 'chat',
			'command' => 'sendMessage',
			'sendMessage' => {
				'chat' => @roomName,
				'user' => client.name,
				'msg' => sanitizeMsg((jsonMsg['sendMessage'])['msg'])
			},
		}
		puts "Propogate message: "
		puts @clientPropagate.inspect
		@clientString = @clientPropagate.to_json
		sendToClients(@clientString)
		
	end


  def sanitizeMsg(msg)
    return(msg.gsub("<","&lt;").gsub(">","&gt;"))
  end
  
	def procMsg_joinChannel(client, jsonmsg)
		puts "User joining channel, running addClient/Client::addChat"
		addClient(client, client.websocket)
		client.addChat(self)
	end


	def procMsg_leaveChannel(client, jsonmsg)
	  remClient(client) 
		@clientReply = {
			'commandSet' => 'chat',
			'commandReply' => true,
			'command' => 'leaveChannel',
			'leaveChannel' => {
					'status' => TRUE,
			}
		}
		@clientString = @clientReply.to_json
		sendToClient(client, @clientString)
	end		
	
	def sendToClient(client, msg)
		puts "Sending message to client " + msg.inspect
		client.websocket.send msg
	end

	def sendToClients(msg)
		t = []
		@clients.each do |websocket, client|
			t << Thread.new do
				puts "Thread launched to send message"
				websocket.send msg
			end
		end
		t.each do |thread|
			puts "Rejoining send message thread"
			thread.join
		end
	end
end
