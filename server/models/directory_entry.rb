class DirectoryEntry < ActiveRecord::Base
  # Some really cool ActiveRecord stuff!
  belongs_to :owner, :class_name => "DirectoryEntry", :foreign_type => "DirectoryEntry", :foreign_key => "id"
  belongs_to :createdBy, class_name: "User", primary_key: "createdBy_id", foreign_key: "id"
  has_many :children, class_name: "DirectoryEntry", foreign_key: "owner_id", foreign_type: "DirectoryEntry"
  has_many :filechanges, class_name: "FileChange", foreign_key: "DirectoryEntry_id"
  after_initialize :mutexes

  def mutexes
    @dirMutex = Mutex.new
    @crdirMutex = Mutex.new
    @createFileMutex = Mutex.new
  end

  def create
    if (params[:owner_id].is_a?(Fixnum))
      # If we were passed an id, find the FD by ID
      #params[:owner_id] = DirectoryEntry.find_by_id(params[:owner_id])
    end
    @directoryEntry = DirectoryEntry.new(params)
    @directoryEntry.save!
  end
end

class DirectoryEntryHelper < DirectoryEntry
  def setOptions(projName, sProject)
    @ProjectName = projName
    @Project = sProject
  end

  def getRootDirectory
    # There should really only be one directory with no owner -- the root
    # directory. We'll give the system its own userid.
    a = DirectoryEntry.find_by_srcpath('/')
    if (!a)
      DirectoryEntry.create(:curName => @ProjectName, :owner_id => nil, :createdBy => nil, :srcpath => '/')
    end
    a = DirectoryEntry.find_by_srcpath('/')
    return a
  end

  def getBaseName(fileName)
    fileName = getDirArray(fileName);
    return fileName.last
  end

  def create(params)
    if (params[:owner_id].is_a?(Fixnum))
      params[:owner_id] = DirectoryEntry.find_by_id(params[:owner_id])
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
    return fileName
  end

  def getDirArray(dirName)
    rere = dirName.split(/(?<=[\/])/)
    #rere = dirName.split(/\//)
    #rere = rere[1..(rere.length - 1)].map {|s| s = s.gsub('/','')}
    rere.delete("");

    if (!rere || !rere.length)
      rere = ['/']
    end
    puts "rere: "  + rere.inspect.to_s
    puts YAML.dump(rere)
    #rere.map {|s| puts s.inspect }
    return rere
  end

  def dirExists(dirList)
		@dirMutex.synchronize {
			return(dirExistsBase(dirList))
		}
	end


  def dirExistsBase(dirList)
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
    srcPath = existingDirectories.join()
    if (srcPath[-1] == '/')
      srcPath = srcPath[0..(srcPath.length - 2)]
    end
    if (srcPath[0] != '/')
      srcPath = '/' + srcPath
    end

    if (exDir = DirectoryEntry.find_by_srcpath(srcPath))
      #puts "Found by srcPath!"
      return{:lastDir => exDir}
    end

    return(false)
  end

  def fileExists(srcPath)
    if (srcPath[0] != '/')
      srcPath = '/' + srcPath
    end
    if (srcPath[-1] == '/')
      srcPath = srcPath[0..(srcPath.length - 2)]
    end
    if (exDir = DirectoryEntry.find_by_srcpath(srcPath))
      #puts "Found by srcPath!"
      return{:lastDir => exDir}
    end
    return(false)
  end

  def calcCurrent
    #This function takes us from revision 0 to current, we have no "key frames", but those will be added in the future to reduce processing time
    myDocument = [];
    self.filechanges.each do |change|
      if (self.respond_to?("cmd_" + change.changeType))
        myDocument = self.send("cmd_" + change.changeType, myDocument, change)
      end
    end
    puts "calcCurrent gave me an " + YAML.dump(myDocument).to_s.length.to_s  + " byte document"
    return {:data => myDocument}
  end

  def cmd_setContents(myDocument, change)
    puts "cmd_setContents " + self.srcpath
    myDocument = YAML.load(change.changeData)
    return(myDocument)
  end

  def createFile(fileName, userId=nil, data=nil, mkdirp = false)
		puts "createFile(): Waiting for mutex "
		puts Time.now.to_f.to_s
		@createFileMutex.synchronize {
			puts "createFile(): Got mutex, running createFileBase() "
			puts Time.now.to_f.to_s
			return(createFileBase(fileName, userId, data, mkdirp))
		}
		puts "createFile(): Released mutex "
		puts Time.now.to_f.to_s
	end

  def createFileBase(fileName, userId=nil, data=nil, mkdirp = false)

    baseName = getBaseName(fileName)
    dirList = getDirectory(fileName)
    if (!(a = dirExists(dirList)))
      if (!mkdirp)
        puts "Directory does not exist " + dirList.join() + " .."
        puts "Could not create file #{fileName} under non-existing directory"
        return false
      else
        myDirList = dirList.join('')
        if (myDirList[0] != '/')
          myDirList = '/' + myDirList
        end
        puts "Attempting to create directory " + myDirList
        rval = mkDir(myDirList)
        a = dirExists(dirList)
  			if (!rval || !a)
  				puts "createFile() failed to create Directory!"
  				return FALSE
  			end
      end
    end
    x = DirectoryEntryHelper.find_by_srcpath(fileName)
    if (!x)
      puts "Couldn't find file by srcpath: #{fileName} in DB -- creating entry"
      # The file is NOT in the DB yet, add it!
      lastDir = a[:lastDir]
      newEntry = {:curName => baseName, :owner_id => lastDir.id, :createdBy_id => User.find_by_id(userId), :ftype => 'file', :srcpath => fileName }
      DirectoryEntryHelper.create(newEntry)
      x = DirectoryEntryHelper.find_by_srcpath(fileName)
    end
    if (x)
      # The file already exists in the db-- this is normal if we did a filesystem scan
      # on a second server boot, etc
      #puts "We have recorded " + x.filechanges.count.to_s + " filechanges to #{fileName}"
      if (data)
        puts "We were called with data, only setting data if filechanges.count == 0"
      end
      if ((x.filechanges.count == 0) && data)
        # This file had no data before, but has been seen.. it has 0 changes made to it, so we just load it from disk with "setContents" as our command
        # All of the changeTypes will directly correlate to existing C->S API calls
        puts "Filechange.create setContents data since x.filechanges.count == 0"
        if (userId == nil)
          userId = 1
        end
        FileChange.create(:changeType => "setContents", :changeData => YAML.dump(data), :startLine => 0, :startChar => 0, :DirectoryEntry_id => x.id, :revision => 0, :User_id => userId)
      elsif (x.filechanges.count > 0)
        # The database takes priority over the filesystem, although we may change this once we have a diff system in (so filesystem modifications affect the database)
        puts "Current filechanges.count: " + x.filechanges.count.to_s
        puts "Caling x.calcCurrent()"
        rval = x.calcCurrent()
        data = rval[:data]
        puts "Taking calcCurrent() and setting data to it"
      end
    end

    if (!@Project.getDocument(fileName))
      @Project.addDocument(fileName)
    end

    if (data.is_a?(String) || data)
      puts "Calling getDocument/setContents"
      doc = @Project.getDocument(fileName)
      doc.setContents(data)
    end
    return true
  end


  def mkDir(dirName, userId=nil)
    rere = getDirArray(dirName)
    puts "mkDir(#{dirName}) .. " + rere.inspect.to_s
    i = rere.length - 1

    while (i > 0)
      #			puts "In main loop, checking dirExists " + rere.take(rere.length - i).join() + " .. "
      while dirExists(rere.take(rere.length - i)) && i > 0
        #				puts "In while loop! Checking for " + (rere.take(rere.length - i)).join()
        i -= 1
      end
      #			puts "Calling createDirectory! " + rere.take(rere.length - i - 1).inspect.to_s + " : " + rere.take(rere.length - i).last.gsub('/','').inspect.to_s
      dirList = rere.take(rere.length - i - 1)
      # if (!rere.take(rere.length - i - 1))
      #   dirList = ['/']
      # end
      newdir = createDirectory(dirList, rere.take(rere.length - i).last.gsub('/',''), userId);
      i -= 1
    end
    #		puts " -- Done creating directories -- "
    # Return the last directory created (last in the chain, this makes things easier
    # if we code for the return value properly)
    return newdir
  end


  def createDirectory(dirList, dirName, userId=nil)
		@crdirMutex.synchronize {
			return(createDirectoryBase(dirList, dirName))
		}
	end

  def createDirectoryBase(dirList, dirName, userId=nil)
    # All but the last directory must exist, as opposed to mkdir which will automagically create directories a la "mkdir -p"
    # Ie if you want /server/testing/logs, you'd need to create /server, then /server/testing, then /server/testing/logs when calling this function
    # To make it slightly easier it takes an array ["/", "server","testing"] as the first argument, these directories should exist (and we check for that)
    # And it takes the new subdirectory name as the second argument, with the userId of the person creating the directory as an optional 3rd argument
    # userId may stay nil -- it will show up as "system generated" in that case
    puts "createDirectory() called to create #{dirName} under #{dirList.inspect}"
    srcPath =  dirList.map {|s| s.inspect}.join().gsub('"','').gsub('/','')
    existingDirectories = dirList.take(dirList.length);
    fullDirectory = existingDirectories
    fullDirectory << dirName
    a = dirExists(fullDirectory)
    if (a != false)
      puts "createDirectory(): Possible error: This directory #{dirName} has already been created! #{fullDirectory.inspect}"
      puts YAML.dump(a[:lastDir])
      # The directory has already been created/properly exists, return the directory model to the calling function}
      return a[:lastDir]
    else
      puts "createDirectory(): Directory does not exist -- #{dirName}, that's good, it means we can possibly create it (if the preceding directories exist)."
      # We used to have a message here. Once we do some good logging functions we'll put it back in, no more puts
    end

    a = dirExists(dirList)
    if (a != false)
      # All but the last directory exist in the correct pathing
      puts "createDirectory(): dirExists(dirList) was true"
      lastDir = a[:lastDir]
      puts YAML.dump(lastDir)
      newEntry = {:curName => dirName, :owner_id => lastDir.id, :createdBy => User.find_by_id(userId), :ftype => 'folder', :srcpath => dirList.map {|s| s.inspect}.join().gsub('"','') + dirName}
      newDir = DirectoryEntryHelper.create(newEntry)
    else
      puts "createDirectory(): Some number of directories in dirList did not exist, so we couldn't create the directory"
      # Some of the directories in dirList did not exist so we could not create the newest directory
      return false
    end
    puts "createDirectory(): Successfully created #{dirName} -- " + dirList.map {|s| s.inspect}.join().gsub('"','') + dirName
    #puts YAML.dump(newDir)
    # We successfully created the directory, return the directory model
    return newDir
  end
end

class FileTreeX < DirectoryEntryHelper
  def jsonTree(start = nil, parent = false, tprepend='', tappend='')
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
      newId = sanitizeName(type, tprepend, tappend)
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
      parent = "ft" + tprepend + "root0" + tappend
    end

    if (start != nil)
      start.children.each do |item|
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
        newId = sanitizeName(type, tprepend, tappend)
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
          jsonString << jsonTree(item, newId, tprepend, tappend)
        end
      end
    end

    if (/root/.match(parent))
      #We really only need ftroot0 here, as I found out through experimentation
      #Give me a break, I've been up for over 20 hours!
      return(jsonString.flatten.to_json)
    end
    return(jsonString)
  end

  def sanitizeName(name, tprepend='', tappend='')
		name += @@idIncrement.to_s
		@@idIncrement += 1
		return("ft" + tprepend + name + tappend)
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

  def procMsg_getFileTreeModalJSON(client, jsonMsg)
		puts "procMsg_getFileTreeModalJSON() Entry"
    puts YAML.dump(jsonTree(nil, false, '', 'modal'))
		@clientReply = {
			'commandSet' => 'FileTree',
			'command' => 'setFileTreeModalJSON',
			'setFileTreeModalJSON' => {
				'fileTree' => jsonTree(nil, false, '', 'modal'),
			}
		}
		@clientString = @clientReply.to_json
		@Project.sendToClient(client, @clientString)
		puts "procMsg_getFileTreeJSON() Exit"

	end

end
