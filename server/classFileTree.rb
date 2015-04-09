

class FileTreeBase
	def initialize(projectName, sProject)
		@Project = sProject
		@projectName = projectName
		@fileTree = {
			'/' => {
				'niceName' => @projectName,
				'type' => 'directory',
				'children' => {
				}
			}
		}
	end
	
	def getBaseName(fileName)
		fileName = getDirArray(fileName);
		return fileName.last
	end
	
	def getDirectory(fileName)
		fileName = getDirArray(fileName);
		fileName = fileName.take(fileName.length - 1)
		fileName.map
		return fileName.drop(1)
	end
	
	def printTree()
		puts @fileTree.inspect
		#puts htmlTree(@fileTree)
	end

	def sanitizeName(name)
		name += @@idIncrement.to_s
		@@idIncrement += 1
		return("ft" + name)
		
	end

	def jsonTree(start = @fileTree, parent = false)
		if (parent == false) 
			@@idIncrement = 0
		end
		jsonString = []
		if (start != false)
			start.each do |key, value|
				if value.class.to_s == 'Hash' 
					if (key == '/')
						type = 'root'
						ec = 'jsTreeRoot'						
						icon = "jstree-folder"
						parent = "#"
					elsif (value['type'] == 'directory')
						type = 'folder'
						ec = 'jsTreeFolder'
						data = 'js'
						icon = "jstree-folder"
					else
						type = 'file'
						ec = 'jsTreeFile'
						icon = "jstree-file"
					end

					if (value['niceName']) 
						name = value['niceName']
					else
						name = key
					end

					newId = sanitizeName(type)
					myJSON = [
						'id' => newId,
						'parent' => parent,
						'text' => name,
						'type' => type,
						'li_attr' => {
							"class" => ec,
							"srcPath" => value['srcPath']
						},
					]
					jsonString << myJSON
					if value.has_key?("children")
						jsonString << jsonTree(value['children'], newId)
					end
				else
					puts "Value class was not hash? " + value.class.to_s + " -- " + value.inspect
				end
			end
		end
		if (parent == '#')
			puts "Returning as JSON"
			return(jsonString.flatten.to_json)
		end
		return(jsonString)

	end		
	
	def htmlTree(start = @fileTree)
		@outputText = "";
		if (start != false)
			start.each do |key, value|
				if value.class.to_s == 'Hash' 
					if (key == '/')
						type = 'root'
						ec = 'jsTreeRoot'
						
						icon = "jstree-folder"
					elsif (value['type'] == 'directory')
						type = 'folder'
						ec = 'jsTreeFolder'
						data = 'js'
						icon = "jstree-folder"
					else
						type = 'file'
						ec = 'jsTreeFile'
						icon = "jstree-file"
					end
					if value.has_key?("children")
						htmlType = "<ul><li>"
						htmlEnd = "</li></ul>"
					else
						htmlType = "<ul><li>"
						htmlEnd = "</li></ul>"
					end

					if (value['niceName']) 
						@outputText += "#{htmlType}#{value['niceName']}"
					else
						@outputText += "#{htmlType}#{key}"
					end

					if value.has_key?("children")
						@outputText += htmlTree(value['children'])
					else
						puts "No children for " + value.inspect
					end
					@outputText += "#{htmlEnd}"
				else
					puts "Value class was not hash? " + value.class.to_s + " -- " + value.inspect
				end
			end
		end

		return(@outputText)
	end
		
	def htmlTreeChildren(value)
		outputText = "";
		value.each do |ckey, cvalue|
			outputText += "<li>#{ckey}"
			if cvalue.class == 'hash' && cvalue.has_key?('children')
				outputText += htmlTree(cvalue['children']);
			else
				puts cvalue.inspect
				puts "Failed, either not a hash or no children"
			end
			outputText += "</li>"
		end
		return(outputText)
	end

	def createFile(fileName)
		baseName = getBaseName(fileName)
		dirList = getDirectory(fileName)
		if (!dirExists(dirList))
			puts "Directory does not exist " + dirList.join() + " .."
			return FALSE
		end
		
		puts "createFile() called to create #{fileName} under " + dirList.join('')

		existingDirectories = dirList.take(dirList.length);
		@start = @fileTree['/'];
		puts "Existing Directories" + existingDirectories.inspect + " " + existingDirectories.length.to_s
		if existingDirectories.length > 1
			existingDirectories.map{ |s|
				s = s.gsub('/','');
				if (!@start['children'].nil?)
					if (!@start['children'][s].nil?)
						@start = @start['children'][s]
					else
						puts "ERROR: start[children][#{s}] was nil!"
					end
				end
			}
		end
		newObject = {
			baseName => {
					'type' => 'file',
					'revision' => 0,
					'document' => 'NYI',
					'srcPath' => fileName,
			}
		}
		if !@start['children'].nil?
			puts "Start has children, calling merge"
			@start['children'] = @start['children'].update(newObject);
		elsif
			puts "Start has no children, just setting children=newObject"
			@start['children'] = @start['children'].update(newObject);
		end
		@Project.addDocument(fileName)
		return TRUE

	end
	
	def rmFile(fileName)
	end
	
	def rnFile(fileName, newName)
	end
	
	def mvFile(fileName, newName)
	end

	def getDirArray(dirName)
		rere = dirName.split(/(?<=[\/])/)
		#rere = rere.map {|s| s = s.to_s.gsub('/','')}
		rere.delete("");
		#rere.map {|s| puts s.inspect }
		return rere
	end
	
	def mkDir(dirName)
		rere = getDirArray(dirName)
		puts rere.inspect
		i = rere.length - 1
		
		while (i > 0)
			puts "In main loop, checking dirExists " + rere.take(rere.length - i).join() + " .. "
			while dirExists(rere.take(rere.length - i)) && i > 0
				puts "In while loop!"
				i -= 1
			end
			puts "Calling createDirectory!"
			createDirectory(rere.take(rere.length - i), rere.take(rere.length - i + 1).last.gsub('/',''));
			i -= 1
		end
		puts " -- Done creating directories -- "
		puts @fileTree
	end
	
	def createDirectory(dirList, dirName)
		# All but the last directory must exist
		puts "createDirectory() called to create #{dirName} under #{dirList.inspect}"
		puts dirList.map {|s| s.inspect}.join().gsub('"','').gsub('/','');
		puts @fileTree
		existingDirectories = dirList.take(dirList.length);
		@start = @fileTree['/'];
		puts "Existing Directories" + existingDirectories.inspect + " " + existingDirectories.length.to_s
		if existingDirectories.length > 1
			existingDirectories.map{ |s|
				s = s.gsub('/','');
				if (!@start['children'].nil?)
					if (!@start['children'][s].nil?)
						@start = @start['children'][s]
					else
						puts "ERROR: start[children][#{s}] was nil!"
					end
				end
			}
		end
		newObject = {
			dirName => {
					'type' => 'directory',
					'children' => {
					},
			}
		}
		if !@start['children'].nil?
			puts "Start has children, calling merge"
			@start['children'] = @start['children'].update(newObject);
		elsif
			puts "Start has no children, just setting children=newObject"
			@start['children'] = @start['children'].update(newObject);
		end
		
		puts @fileTree.inspect
	end
	
	def dirExists(dirList)
		existingDirectories = dirList;
		lastDir = dirList.drop(dirList.length - 1).map { |s| s.inspect }.join().gsub('"','').gsub('/','');
		#puts "Last dir: #{lastDir}"
		@start = @fileTree['/'];
		existingDirectories.map{ |s|
			s = s.gsub('/','')
			if (!@start['children'])  
				puts "Has no children, not even going to look past #{s}"
				return FALSE
			end
			if (!@start['children'].has_key?(s))
				puts "start has no child named #{s}"
				return FALSE
			end
			if (@start['children'].has_key?(s))
				@start = @start['children'][s]
				puts "OK.."
			end
	
		} 
		puts "Full directory tree intact.."
		return TRUE
		
	end
end

class FileTree < FileTreeBase
	def procMsg(client, jsonMsg)
		puts "Asked to process a message for myself: from client #{client.name}"
		if (self.respond_to?("procMsg_#{jsonMsg['command']}"))
			puts "Found a function handler for  #{jsonMsg['command']}"
			self.send("procMsg_#{jsonMsg['command']}", client, jsonMsg);
		elsif
			puts "There is no function to handle the incoming command #{jsonMsg['command']}"
		end
	end
	def procMsg_getFileTreeJSON(client, jsonMsg)
		@clientReply = {
			'commandSet' => 'FileTree',
			'command' => 'setFileTreeJSON',
			'setFileTreeJSON' => {
				'fileTree' => jsonTree(),
			}
		}
		@clientString = @clientReply.to_json
		@Project.sendToClient(client, @clientString)
	end	
end