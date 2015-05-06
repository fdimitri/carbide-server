require 'em-websocket'
require 'json'
require 'yaml'

require './classClient.rb'
require './classChat.rb'
require './classFileTree.rb'
require './classDocument.rb'
require './classTerminal.rb'
class String
  def is_json?
    begin
      !!JSON.parse(self)
    rescue
      false
    end
  end
end




class Project
	attr_accessor	:clients
	attr_accessor	:documents
	attr_accessor	:chats
	attr_accessor	:FileTree
	def initialize(projectName)
		@chats = { } 
		@clients = { } 
		@documents = { }
		@terminals = { }
		@projectName = projectName
		@FileTree = FileTree.new(projectName, self);
		@FileTree.mkDir("/server/source");
		@FileTree.mkDir("/client/html");
		@FileTree.createFile("/server/source/test.rb");
		@FileTree.createFile("/server/source/server.rb");
		@FileTree.createFile("/server/source/cProject.rb");
		@FileTree.createFile("/server/source/cFileTree.rb");
		@FileTree.createFile("/server/source/cDocument.rb");
		@FileTree.createFile("/client/html/testView.html");
		@FileTree.printTree()
		puts @FileTree.htmlTree()
		puts @FileTree.jsonTree()
		procMsg_getChatListJSON()
	end

	def start(opts = { })
		EventMachine::WebSocket.start(:host => "0.0.0.0", :port => 8080) do |ws|
		  ws.onopen    { addClient(ws) }
		  ws.onmessage { |msg| handleMessage(ws, msg) }
		  ws.onclose   { removeClient(ws) }
		end
	end

	def handleMessage(ws, msg)
		if (msg.is_json?)
			jsonString = JSON.parse(msg)
			if (jsonString['commandSet'] == 'document')
				puts "This message corresponds to a document"
				if (!jsonString['documentTarget'].nil?) 
					docTarget = jsonString['documentTarget']
				elsif (!jsonString['document'].nil?)
					docTarget = jsonString['document']
				elsif (!jsonString['targetDocument'].nil?)
					docTarget = jsonString['targetDocument']
				else
					puts "There was no document or documentTarget in jsonString"
					puts YAML.dump(jsonString)
					return false;
				end

				if (doc = getDocument(docTarget))
					doc.procMsg(getClient(ws), jsonString);
				else
					puts "handleMessage couldn't getDocument() -- document " + docTarget + " doesn't exist as far as we know"
				end
			elsif (jsonString['commandSet'] == 'chat')
				puts "This message corresponds to a chat for #{jsonString['chatTarget']}"
				if (chat = getChat(jsonString['chatTarget']))
					chat.procMsg(getClient(ws), jsonString)
				else
					puts "We should create a new chat since it doesn't exist"
					chat = addChat(jsonString['chatTarget'])
					chat.procMsg(getClient(ws), jsonString)
				end
			elsif (jsonString['commandSet'] == 'FileTree')
				@FileTree.procMsg(getClient(ws), jsonString)
			elsif (!jsonString['commandSet'] || jsonString['commandSet'] == 'base')
				puts "This message is general context"
				if (self.respond_to?("procMsg_#{jsonString['command']}"))
					puts "Found a function handler for  #{jsonString['command']}"
					self.send("procMsg_#{jsonString['command']}", (ws), jsonString);
				elsif
					puts "There is no function to handle the incoming command #{jsonString['command']}"
				end
			end
		elsif
			puts "Message was either invalid JSON or another format"
			
		end

	end

	
	def addTerm(termName)
		puts "addTerm called with #{termName}"
		term = Terminal.new(self, termName);
		@terminals[termName] = term;
		return (getTerminal(termName))
	end
	
	def getTerminal(termName)
		puts "getTerminal called with #{termName}"
		if (@terminals[termName]) 
			return @terminals[termName];
		end
		return FALSE
	end
	
	
	def procMsg_openTerminal(ws,msg)
		localMsg = msg['openTerminal']
		termName = localMsg['termName']
		puts "procMsg Open Terminal #{termName}"
		if (!getTerminal(termName))
			puts "Creating terminal"
			addTerm(termName)
		end
		puts YAML.dump(@clients)
		client = @clients[ws]
		puts "Set client = @clients(ws)"
		client.addTerm(termName)
		puts "Adding client to terminal"
		@terminals[termName].addClient(client,ws)
	end
		
	def procMsg_closeTerminal(ws,msg)
	end
	
	def procMsg_openDocument(ws, msg) 
		docName = msg["documentName"]
		client = @clients[ws]
		client.addDocument(docName)
		@documents[docname].addClient(client)
	end
	
	def procMsg_closeDocument(ws, msg)
	end
	
	def procMsg_hintActiveDocument(ws, msg)
	end
	
	def procMsg_getFileTree(ws, msg)
		return(@fileTree.getFileTreeJSON(ws, msg))
	end
	
	def procMsg_getChatList(ws, msg)
		names = chatNames()
		clientReply = {
			'commandSet' => 'reply',
			'commandType' => 'chat',
			'command' => 'getChatList',
			'getChatList' => {
				'status' => true,
				'chatList' => names,
			},
		}
		clientString = clientReply.to_json
		sendToClient(ws, clientString)
	end

	def procMsg_getChatListJSON(client = false, jsonMsg = false)
		counter = 0;
		jsonString = [
			'id' => 'chatroot',
			'parent' => '#',
			'text' => 'Chat Rooms',
			'type' => 'root',
			'li_attr' => {
				'class' => 'jsRoot',
			},
		]
		@chats.collect{ |c|
			myJSON = [
				'id' => 'chat' + ++counter.to_s,
				'parent' => 'chatroot',
				'text' => c.roomName,
				'type' => 'chat',
				'li_attr' => {
					"class" => 'jsChat',
				},
			]
			jsonString << myJSON
		}
		if (client != false)
			jsonString = jsonString.to_json
			sendToClient(ws, jsonString)
			return true
		end
		YAML.dump(jsonString);
		return true
	end

	
	def addDocument(documentName)
		document = Document.new(self, documentName);
		@documents[documentName] = document;
		return getDocument(documentName)
	end
	
	def getDocument(documentName)
		if (@documents[documentName]) 
			return @documents[documentName];
		end
		puts "Invalid document name: #{documentName}"
		return FALSE
	end
	
	def addChat(chatName)
		chat = ChatChannel.new(self, chatName)
		@chats[chatName] = chat
		return getChat(chatName)
	end
	
	
	def getChat(chatName)
		if (@chats[chatName])
			return @chats[chatName];
		end
		puts "Invalid chatroom name: #{chatName}"
		return FALSE
	end
	
	
	def getClient(ws)
		if (@clients[ws])
			return(@clients[ws])
		elsif
			puts "Invalid client with socket: #{ws}"
			return FALSE
		end
	end
	
	def addClient(ws)
		client = Client.new(ws);
		client.name = assignName("User");
		@clients[ws] = client;
	end

def removeClient(ws)
  puts "Remove client -- we should inform chat and document listeners of this event"
  client = @clients[ws]
  client.chats.each do |key, value|
    puts "Remove client #{client.name} from #{value.roomName}"
    value.remClient(client)
  end
  client = @clients.delete(ws);
end

	def sendToClients(type, info) 
		sendAll(info)
	end

	def sendToClientsListeningExcept(oclient, document, msg)
		@clients.each do |websocket, client|
			if (oclient != client && client.listeningToDocument(document))
				websocket.send msg
			end
		end
	end

	def sendToClientsListeningExceptWS(ws, document, msg)
		@clients.each do |websocket, client|
			if (!(websocket == ws) && client.listeningToDocument(document))
				websocket.send msg
			else
				puts "sendToClientsListeningExceptWS(): Skipping client"
			end
		end
	end
	
	def sendToClientsExcept(oclient, msg)
		@clients.each do |websocket, client|
			if (oclient != client)
				websocket.send msg
			end
		end
	end
	
	def sendAll(msg)
		@clients.each do |websocket, client|
			websocket.send msg
		end
		puts "Sent to all: #{msg}"
	end

	def sendToClient(client, msg)
		client.websocket.send msg
	end
	
	def chatNames
		@chats.collect{|key, c| c.name}.sort
	end
	
	def clientNames
		@clients.collect{|websocket, c| c.name}.sort
	end

	def assignName(rName)
		existing_names = self.clientNames
		if existing_names.include?(rName)
			i = 1
			while existing_names.include?(rName + i.to_s)
				i+= 1
			end
			rName += i.to_s
		end
		puts "New client connected: #{rName}"
		return rName
	end	
end



puts "Starting up.."

myProject = Project.new('Mockup')
myProject.start() 
