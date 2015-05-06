grequire 'pty'
require 'yaml'
require 'io/console'

class TerminalBase
	attr_accessor	:clients
	attr_accessor	:termName
	
	def initialize(project, termName)
		@project = project
		@termName = termName
		@clients = { }
		puts "Terminal term #{termName} initialized"
		@output, @input, @pid = PTY.spawn("/bin/bash -l")
		@po = Thread.new {
			while 1 do
           	     @output.each_char { |c|
           	             sendToClientsChar(c)
           	     }
           	 end
        }	
	end

	def procMsg_inputChar(client, jsonMsg)
		localData = jsonMsg['inputChar']
		@input.print localData['data']
	end
	
	def sendToClientsChar(c)
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
			'commandSet' => 'term',
			'command' => 'userJoin',
			'userJoin' => {
				'term' => @termName,
				'user' => client.name,
			},
		}
		puts "Propogate message: "
		puts @clientPropagate.inspect
		@clientString = @clientPropagate.to_json
		sendToClients(@clientString)
		@clientMessage = { 
			'commandSet' => 'term',
			'command' => 'userList',
			'userList' => {
				'list' => getClientNames(),
				'term' => @termName,
			},
		}
		sendToClient(client, @clientMessage.to_json)
	end
	
	def remClient(client)
	  client.removeTerm(@termName)
		@clients.delete(client.websocket)
		@termMsg = {
			'commandSet' => 'term',
			'command' => 'userLeave',
			'userLeave' => {
	        		'term' => @termName,
			        'user' => client.name,
			},
		}
		@clientString = @termMsg.to_json
		sendToClients(@clientString)
	end
	
	def procMsg(client, jsonMsg)
		puts "Asked to process a message for myself: #{@termName} from client #{client.name}"
		if (!getClient(client.websocket) && jsonMsg['termCommand'] != 'joinChannel')
			puts "Client has not formally joined the channel -- this is OK in alpha state, adding client implicitly"
		end
		if (self.respond_to?("procMsg_#{jsonMsg['termCommand']}"))
			puts "Found a function handler for  #{jsonMsg['termCommand']}"
			self.send("procMsg_#{jsonMsg['termCommand']}", client, jsonMsg);
		elsif
			puts "There is no function to handle the incoming command #{jsonMsg['termCommand']}"
		end
	end

end
	