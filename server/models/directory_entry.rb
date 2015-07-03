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
    a = DirectoryEntry.find_by_id(36)
    #FIX THIS HACK
    puts YAML.dump(a)
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
    if (1)
      params[:owner] = DirectoryEntry.find_by_id(params[:owner])
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
			return TRUE
		end
		if (dirList.length == 0)
			return TRUE
		end
		existingDirectories = dirList;
		puts "dirExists() dump dirList:"
		puts YAML.dump(dirList)
		puts "-------------------------"

		lastDir = dirList.drop(dirList.length - 1).map { |s| s.inspect }.join().gsub('"','').gsub('/','');

		if (existingDirectories[0] == '/')
			existingDirectories = existingDirectories[1..(existingDirectories.length+1)]
		end

		puts existingDirectories.map { |s| puts s + " -- Iterator" }
    rootDir = getRootDirectory()
    thisdir = nil
    if (!rootDir)
      puts "@rootDir was not found?"
      YAML.dump(rootDir)
      return FALSE
    else
      puts "@rootDir was found!"
      YAML.dump(rootDir)
    end
    prevdir = rootDir
    puts "rootDir:"
    puts YAML.dump(rootDir)

    puts "prevdir:"
    puts YAML.dump(prevdir)
    dirIDs = []
    dirIDs << prevdir.id;
		existingDirectories.map{ |s|
			s = s.gsub('/','')
      if (!(thisdir = DirectoryEntry.find_by_curName(s)))
        return FALSE
      end
      thisdir.children.each do |cdir|
        if (cdir.curName == s)
          prevdir = cdir
          dirIDs << cdir.id
          puts "Iterating through children"
          puts YAML.dump(cdir)
          break;
        end
      end
      if (prevdir == thisdir)
        return FALSE
      end

      puts "Found directory #{thisdir.curName}"
    }
		puts "Full directory tree intact.."
		return {:idChain => dirIDs, :lastDir => thisdir}
	end

  def createFile(fileName, data=nil)
		baseName = getBaseName(fileName)
		dirList = getDirectory(fileName)
		if (!(a = dirExists(dirList)))
			puts "Directory does not exist " + dirList.join() + " .."
			return FALSE
		end
    puts "Found parent directory"
    puts YAML.dump(a[:lastdir])

		@Project.addDocument(fileName)

		if (data)
			doc = @Project.getDocument(fileName)
			doc.setContents(data)
		end
		return TRUE
	end

end
