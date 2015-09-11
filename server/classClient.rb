class Client
	attr_accessor	:websocket
	attr_accessor	:name
	attr_accessor	:chats
	attr_accessor	:documents
	attr_accessor	:terms
	attr_accessor :userId
	attr_accessor :user
	attr_accessor :taskBoards

	def initialize(websocket)
		@websocket = websocket
		@documents = { }
		@chats = { }
		@name = ""
		@terms = { }
		@userId = 1
		@user = User.find_by_id(@userId)
	end

	def sendMsg(msg)
		@websocket.send msg
	end

	def addChat(chat)
		@chats[chat] = chat
	end

	def removeChat(chat)
		@chats.delete(chat)
	end

	def addTask(taskName)
		@taskBoards[taskName] = taskName
	end

	def removeTask(taskName)
		@taskBoards.delete(taskName)
	end


	def addTerm(term)
		@terms[term] = term
	end

	def removeTerm(term)
		@terms.delete(term)
	end

	def addDocument(document)
		@documents[document] = document;
	end

	def removeDocument(document)
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
