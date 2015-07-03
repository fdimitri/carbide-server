class DirectoryEntry < ActiveRecord::Base
  # Some really cool ActiveRecord stuff!
  belongs_to :owner, class_name: "DirectoryEntry"
  belongs_to :createdBy, class_name: "User"
  has_many :children, class_name: "DirectoryEntry", foreign_key: "owner_id"
  has_many :filechanges, class_name: "FileChange", foreign_key: "DirectoryEntry_id"

  def create
    if (params[:owner].is_a(FixNum))
      # If we were passed an id, find the FD by ID
      params[:owner] = DirectoryEntry.find_by_id(params[:owner])
    end
    @directoryEntry = DirectoryEntry.new(params)
    @directoryEntry.save!
  end

  def getRootDirectory
    # There should really only be one directory with no owner -- the root
    # directory. We'll give the system its own userid.
    a = DirectoryEntry.find_by_owner_id(nil)
    return a
  end

end

class DirectoryEntryHelper < DirectoryEntry
  def setOptions(projName, sProject)
    @ProjectName = projName
    @Project = sProject
  end

	def getBaseName(fileName)
		fileName = getDirArray(fileName);
		return fileName.last
	end

  def create(params)
    if (params[:owner].is_a?(FixNum))
      params[:owner] = DirectoryEntry.find_by_id(params[:owner])
    end
    params.each do |key, value|
      puts "#{key} has " + value.class.to_s
    end
    @directoryEntry = DirectoryEntry.new(params)
    @directoryEntry.save!
  end


	def getDirectory(fileName)
		fileName = getDirArray(fileName);
		fileName = fileName.take(fileName.length - 1)
		fileName.map
		if (fileName.drop(1).length == 0)
			return(['/'])
		end
		return fileName.drop(1)
	end

  def getDirArray(dirName)
    # This is actually bad regex for a Directory Array.. not sure why I did
    # exactly this, as it doesn't make sense now. Refactor this.
		rere = dirName.split(/(?<=[\/])/)
		#rere = rere.map {|s| s = s.to_s.gsub('/','')}
		rere.delete("");
		#rere.map {|s| puts s.inspect }
		return rere
	end

  def dirExists(dirList)
		if (dirList.length == 1 && dirList[0] == '/')
      # The root directory always exists! Theoretically.
			return {:lastDir => getRootDirectory() }
		end
		if (dirList.length == 0)
      # No length could happen with some older versions of FileTree, we'll
      # keep it just in case.
      return {:lastDir => getRootDirectory() }
		end
		existingDirectories = dirList;

		lastDir = dirList.drop(dirList.length - 1).map { |s| s.inspect }.join().gsub('"','').gsub('/','');

		if (existingDirectories[0] == '/')
      # Drop the leading slash, we don't need it
			existingDirectories = existingDirectories[1..(existingDirectories.length)]
		end

    rootDir = getRootDirectory()
    thisdir = nil
    if (!rootDir)
      # This should not ever happen.
      puts "@rootDir was not found?"
      return false
    end

    prevdir = rootDir

		existingDirectories.map{ |s|
			s = s.gsub('/','')
      puts "Checking for existence of #{s}"
      if (!(thisdir = DirectoryEntry.find_by_curName(s)))
        # There are NO directories by this name (we have to check for repeats
        # and proper pathing otherwise) -- so we can safely abort all of our
        # other tests
        return false
      end
      thisdir.children.each do |cdir|
        # Iterate through children
        next if (cdir.curName != s)
        # Bypass if it's not what we're looking for
        if (cdir.curName == s)
          prevdir = cdir
        end
        # Set the prev directory to the current directory for the next loop
        # Iteration
      end
      if (prevdir == thisdir)
        # We haven't updated prevdir, so we have a pathing failure
        return false
      end
      # If we got here we're on the right path, keep checking
    }
		# The full directory tree inquired about is intact
		return {:lastDir => thisdir}
	end

  def createFile(fileName, userId=nil, data=nil)
		baseName = getBaseName(fileName)
		dirList = getDirectory(fileName)
		if (!(a = dirExists(dirList)))
			puts "Directory does not exist " + dirList.join() + " .."
      puts "Could not create file #{fileName} under non-existing directory"
      # We could implicitly mkDir() here, but I don't think that's a good
      # design paradigm
			return false
		end
    x = DirectoryEntry.find_by_srcpath(fileName)
    if (x)
      # The file already exists in the db-- this is normal if we did a filesystem scan
      # on a second server boot, etc

      # If the Project is not aware of the document it means we haven't loaded any data for it
      # This is subject to change in the near future when the server will check the database first..
      # This is the case where it exists in the DB, but we have no way to hold data in the DB yet.
      if (!@Project.getDocument(fileName))
        @Project.addDocument(fileName)
    		if (data)
    			doc = @Project.getDocument(fileName)
    			doc.setContents(data)
    		end
        return true
        # createFile was technically a success
      end
      return false
      # createFile failed due to file already existing -- this shouldn't happen.
    end

    # The file is NOT in the DB yet, add it!
    lastDir = a[:lastDir]
    newEntry = {:curName => baseName, :owner => lastDir, :createdBy => User.find_by_id(userId), :ftype => 'file', :srcpath => fileName }

    DirectoryEntryHelper.create(newEntry)

		@Project.addDocument(fileName)
		if (data)
			doc = @Project.getDocument(fileName)
			doc.setContents(data)
		end
		return true
	end

  def mkDir(dirName, userId=nil)
    rere = getDirArray(dirName)
		i = rere.length - 1

		while (i > 0)
#			puts "In main loop, checking dirExists " + rere.take(rere.length - i).join() + " .. "
			while dirExists(rere.take(rere.length - i)) && i > 0
#				puts "In while loop! Checking for " + (rere.take(rere.length - i)).join()
				i -= 1
			end
#			puts "Calling createDirectory! " + rere.take(rere.length - i - 1).inspect.to_s + " : " + rere.take(rere.length - i).last.gsub('/','').inspect.to_s
			newdir = createDirectory(rere.take(rere.length - i - 1), rere.take(rere.length - i).last.gsub('/',''), userId);
			i -= 1
		end
#		puts " -- Done creating directories -- "
    # Return the last directory created (last in the chain, this makes things easier
    # if we code for the return value properly)
		return newdir
	end


  def createDirectory(dirList, dirName, userId=nil)
		# All but the last directory must exist, as opposed to mkdir which will automagically create directories a la "mkdir -p"
    # Ie if you want /server/testing/logs, you'd need to create /server, then /server/testing, then /server/testing/logs when calling this function
    # To make it slightly easier it takes an array ["/server","/testing"] as the first argument, these directories should exist (and we check for that)
    # And it takes the new subdirectory name as the second argument, with the userId of the person creating the directory as an optional 3rd argument
    # userId may stay nil -- it will show up as "system generated" in that case
		puts "createDirectory() called to create #{dirName} under #{dirList.inspect}"
		puts dirList.map {|s| s.inspect}.join().gsub('"','').gsub('/','')
		existingDirectories = dirList.take(dirList.length);
    fullDirectory = existingDirectories
    fullDirectory << dirName
    a = dirExists(fullDirectory)
    if (a != false)
      # The directory has already been created/properly exists, return the directory model to the calling function}
      return a[:lastDir]
    else
      # We used to have a message here. Once we do some good logging functions we'll put it back in, no more puts
    end

    a = dirExists(dirList)
    if (a != false)
      # All but the last directory exist in the correct pathing
      lastDir = a[:lastDir]
      newEntry = {:curName => dirName, :owner => lastDir, :createdBy => User.find_by_id(userId), :ftype => 'folder', :srcpath => dirList.map {|s| s.inspect}.join().gsub('"','') + dirName}
      newDir = DirectoryEntryHelper.create(newEntry)
    else
      # Some of the directories in dirList did not exist so we could not create the newest directory
      return false
    end
    # We successfully created the directory, return the directory model
    return newDir
	end
end

class FileTreeX < DirectoryEntryHelper
  def jsonTree(start = nil, parent = false)
		if (parent == false)
			@@idIncrement = 0
		end
    if (start == nil)
      start = getRootDirectory()
      if (start == nil)
        puts "FileTreeX getRootDirectory() failed"
        return
      end
    end

    jsonString = []
    if (start == getRootDirectory())
      type = 'root'
      ec = 'jsTreeRoot'
      icon = "jstree-folder"
      parent = "#"
      newId = sanitizeName(type)
      myJSON = [
        'id' => newId,
        'parent' => parent,
        'text' => start.curName,
        'type' => type,
        'li_attr' => {
          "class" => ec,
          #We need to Keep track of the srcPath.. perhaps in the DB
          'srcPath' => start.srcpath,
        },
      ]
      jsonString << myJSON
    end
    if (parent == "#")
      parent = "ftroot0"
    end

		if (start != nil)
      start.children.each do |item|
        #FIX THIS HACK
        if (item.ftype == 'folder')
          type = 'folder'
          ec = 'jsTreeFolder'
          data = 'js'
          icon = 'jstree-folder'
        elsif (item.ftype == 'file')
          type = 'file'
          ec = 'jsTreeFile'
          icon = "jstree-file"
        else
          puts "Unknown type"
          type = 'file'
          ec = 'jsTreeFile'
          icon = "jstree-file"
        end
        newId = sanitizeName(type)
        myJSON = [
          'id' => newId,
          'parent' => parent,
          'text' => item.curName,
          'type' => type,
          'li_attr' => {
            "class" => ec,
            #We need to Keep track of the srcPath.. perhaps in the DB
            "srcPath" => item.srcpath,
          },
        ]
        jsonString << myJSON
        if (item.children.count > 0)
          jsonString << jsonTree(item, newId)
        end
      end
    end

		if (parent == 'ftroot0')
      #We really only need ftroot0 here, as I found out through experimentation
      #Give me a break, I've been up for over 20 hours!
			return(jsonString.flatten.to_json)
		end
		return(jsonString)
	end

  def sanitizeName(name)
    # Add an incrementing counter to each name so they're all unique
		name += @@idIncrement.to_s
		@@idIncrement += 1
		return("ft" + name)
	end

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
    # This is currently the only client message we process, we will have to write
    # Move, delete, rename, etc. as well HERE and their supporting functions.
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
