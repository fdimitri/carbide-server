class DirectoryEntry < ActiveRecord::Base
  belongs_to :owner, class_name: "DirectoryEntry"
  belongs_to :createdBy, class_name: "User"
  has_many :children, class_name: "DirectoryEntry", foreign_key: "owner_id"
  has_many :filechanges, class_name: "FileChange", foreign_key: "DirectoryEntry_id"

  def create
    puts "Create Params:"
    puts YAML.dump(params)
    if (params[:owner].is_a(FixNum))
      params[:owner] = DirectoryEntry.find_by_id(params[:owner])
    end
    @directoryEntry = DirectoryEntry.new(params)
    @directoryEntry.save!
  end

  def getRootDirectory
    a = DirectoryEntry.find_by_owner_id(nil)
    #FIX THIS HACK
    #puts YAML.dump(a)
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
    puts "Create Params:"
    puts YAML.dump(params)
    #FIX THIS HACK
    if (1)
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
		rere = dirName.split(/(?<=[\/])/)
		#rere = rere.map {|s| s = s.to_s.gsub('/','')}
		rere.delete("");
		#rere.map {|s| puts s.inspect }
		return rere
	end

  def dirExists(dirList)
		if (dirList.length == 1 && dirList[0] == '/')
      puts "dirList Length was 1 and element 0 was ''/''.. returning root"
			return {:lastDir => getRootDirectory() }
		end
		if (dirList.length == 0)
      puts "dirList Length was 0.. returning root"
      return {:lastDir => getRootDirectory() }
		end
		existingDirectories = dirList;
		puts "dirExists() dump dirList:"
		puts YAML.dump(dirList)
		puts "-------------------------"

		lastDir = dirList.drop(dirList.length - 1).map { |s| s.inspect }.join().gsub('"','').gsub('/','');

		if (existingDirectories[0] == '/')
      puts "Element 0 was /, dropping element 0"
      puts "Old existingDirectories:" + existingDirectories.inspect.to_s
			existingDirectories = existingDirectories[1..(existingDirectories.length)]
      puts "New existingDirectories:" + existingDirectories.inspect.to_s
		end

		puts existingDirectories.map { |s| puts s + " -- Iterator" }
    rootDir = getRootDirectory()
    thisdir = nil
    if (!rootDir)
      puts "@rootDir was not found?"
      return false
    end
    prevdir = rootDir
    #puts "rootDir:"
    #puts YAML.dump(rootDir)

    #puts "prevdir:"
    #puts YAML.dump(prevdir)
    dirIDs = []
    dirIDs << [prevdir.id];

		existingDirectories.map{ |s|
			s = s.gsub('/','')
      puts "Checking for existence of #{s}"
      if (!(thisdir = DirectoryEntry.find_by_curName(s)))
        puts "Definitely does not exist anywhere, return false"
        return false
      end
      thisdir.children.each do |cdir|
        next if (cdir.curName != s)
        if (cdir.curName == s)
          prevdir = cdir
          dirIDs << [cdir.id]
          puts "Iterating through children"
          #puts YAML.dump(cdir)
        end
      end
      if (prevdir == thisdir)
        puts "dirExists returning false"
        return false
      end

      puts "Found directory #{thisdir.curName}"
    }
		puts "Full directory tree intact.."
		return {:idChain => dirIDs, :lastDir => thisdir}
	end

  def createFile(fileName, userId=nil, data=nil)
		baseName = getBaseName(fileName)
		dirList = getDirectory(fileName)
		if (!(a = dirExists(dirList)))
			puts "Directory does not exist " + dirList.join() + " .."
      puts "Could not create file #{fileName} under non-existing directory"
			return false
		end
    x = DirectoryEntry.find_by_srcpath(fileName)
    if (x)
      puts "File already exists!"
      return false
    end

    lastDir = a[:lastDir]
    newEntry = {:curName => baseName, :owner => lastDir, :createdBy => User.find_by_id(userId), :ftype => 'file', :srcpath => fileName }
    puts YAML.dump(newEntry)

    DirectoryEntryHelper.create(newEntry)
    puts "Found parent directory"
    puts YAML.dump(a[:lastdir])

		@Project.addDocument(fileName)

		if (data)
			doc = @Project.getDocument(fileName)
			doc.setContents(data)
		end
		return TRUE
	end

  def mkDir(dirName, userId=nil)
    rere = getDirArray(dirName)
    puts "mkDir(): Result from getDirArray():"
		puts rere.inspect
		i = rere.length - 1

		while (i > 0)
			puts "In main loop, checking dirExists " + rere.take(rere.length - i).join() + " .. "
			while dirExists(rere.take(rere.length - i)) && i > 0
				puts "In while loop! Checking for " + (rere.take(rere.length - i)).join()
				i -= 1
			end
			puts "Calling createDirectory! " + rere.take(rere.length - i - 1).inspect.to_s + " : " + rere.take(rere.length - i).last.gsub('/','').inspect.to_s
			newdir = createDirectory(rere.take(rere.length - i - 1), rere.take(rere.length - i).last.gsub('/',''), userId);
			i -= 1
		end
		puts " -- Done creating directories -- "
		return newdir
	end


  def mkDir2(dirName, userId=nil)
    rere = getDirArray(dirName)
    puts rere.inspect
    i = rere.length

    while (i > 0)
      puts "In main loop, checking dirExists " + rere.take(rere.length - i).join() + " .. "
      while ((dirExists(rere.take(rere.length - i)) != false) && i > 0)
        puts "In while loop! Checking for " + (rere.take(rere.length - i)).join()
        puts "Existing so far: " + rere[0..(i - rere.length)].join()
        i -= 1
      end
      puts "Calling createDirectory! for " + rere.take(rere.length - i + 1).last.gsub('/','')
      newdir = createDirectory(rere.take(rere.length - i - 1), rere.take(rere.length - i).last.gsub('/',''), userId);
      i -= 1
    end
    puts " -- Done creating directories -- "
    return newdir
  end

  def createDirectory(dirList, dirName, userId=nil)
		# All but the last directory must exist
		puts "createDirectory() called to create #{dirName} under #{dirList.inspect}"
		puts dirList.map {|s| s.inspect}.join().gsub('"','').gsub('/','')
		existingDirectories = dirList.take(dirList.length);
		puts "Existing Directories: " + existingDirectories.inspect + " " + existingDirectories.length.to_s
    puts YAML.dump(existingDirectories)
    fullDirectory = existingDirectories
    fullDirectory << dirName
    a = dirExists(fullDirectory)
    if (a != false)
      puts "Directory already exists! Bailing!"
      return a[:lastDir]
    else
      puts "Good, directory does not exist elsewhere"
    end
    puts "createDirectory dirList:"
    puts YAML.dump(dirList)
    a = dirExists(dirList)
    if (a != false)
      puts "dirExists(dirList) was true"
      lastDir = a[:lastDir]
      newEntry = {:curName => dirName, :owner => lastDir, :createdBy => User.find_by_id(userId), :ftype => 'folder', :srcpath => dirList.map {|s| s.inspect}.join().gsub('"','') + dirName}
      newDir = DirectoryEntryHelper.create(newEntry)
    else
      puts "Some directories did not exist.. cannot create this directory directly"
      return false
    end
    puts "Successfully created dirName under " + dirList.inspect
    puts YAML.dump(newDir)
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

		if (parent == false)
			puts "Returning as JSON"
			return(jsonString.flatten.to_json)
		end
		return(jsonString)
	end

  def sanitizeName(name)
		name += @@idIncrement.to_s
		@@idIncrement += 1
		return("ft" + name)
	end

end
