#

class Client
	attr_accessor	:websocket
	attr_accessor	:name
	attr_accessor	:chats
	attr_accessor	:documents
	attr_accessor	:terms

	def initialize(websocket)
		@websocket = websocket
		@documents = { }
		@chats = { }
		@name = ""
		@terms = { }
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
