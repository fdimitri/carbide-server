class Client
	attr_accessor	:websocket
	attr_accessor	:name
	attr_accessor	:chats
	attr_accessor	:documents
	
	def initialize(websocket)
		@websocket = websocket
		@documents = { }
		@chats = { }
		@name = ""
	end
	
	def sendMsg(msg)
		@websocket.send msg
	end	

	def addChat(chat)
		puts "Client::addChat()"
		puts YAML.dump(chat)
		@chats[chat] = chat
	end

	def removeChat(chat)
		@chats.delete(chat)
	end
	
	
	def addDocument(document)
		@documents[document] = document;
	end
	
	def removeDcoument(document)
		@documents.delete(document);		
	end
	
	def listeningToDocument(document)
		return TRUE
		if (@documents.has_key?(document))
			return TRUE
		end
		return FALSE
	end
end
