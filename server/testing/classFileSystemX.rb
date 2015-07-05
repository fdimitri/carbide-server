require 'json'
require 'yaml'

# This is a file system scanner that makes calls to the psuedo-file system in
# the database, it may be called at any time to import new files.

class FileSystemBase
  def initialize(baseDirectory, fileTree)
    @fileTree = fileTree
    @baseDirectory = baseDirectory
  end

  def getFilesFromDirectory(directoryName)
    files = Dir.entries(directoryName).select { |f| !File.directory? f }
    return files
  end

  def getDirectoriesFromDirectory(directoryName)
    puts "getDirectoriesFromDirectory(#{directoryName})"
    dirs = Dir.entries(directoryName).select { |f| ((File.directory? f) && f != '.' && f != '..')}
    puts YAML.dump(dirs)
    return dirs
  end


  def buildTree(path=@baseDirectory, name=nil)
    data = {'name' => (name || path)}
    data['children'] = children = []
    if (path == @baseDirectory)
      data['type'] = 'root'
    end
    Dir.foreach(path) do |entry|
      next if (entry == '..' || entry == '.' )
      full_path = File.join(path, entry)
      if File.directory?(full_path)
        newEntry = buildTree(full_path, entry)
        newEntry['type'] = File.ftype(full_path)
        newEntry['fullPath'] = stripPath(full_path)
        children << newEntry
      else
        newEntry = {'name' => entry, 'type' => File.ftype(full_path), 'fullPath' => stripPath(full_path) }
        children << newEntry
      end
    end
    return data
  end

  def stripPath(path)
    newPath = path.gsub(@baseDirectory, "")
    return newPath
  end

  def createFileTree(tree)
    # puts YAML.dump(tree)
    if (!tree['children'])
      puts tree
      # This should never happen.. deprecate this entire if block, we never call
      # createFileTree(value) when value['type'] == file, although files will
      # not have children they will not see this function as the tree parameter
      if (tree['type'] == 'file')
        if ((/\.(rb|html|php|out|save|log|js|txt|css|scss|coffee|md|rdoc|htaccess|c|rd|cpp)$/.match(tree['name'])) || (/akefile|Gemfile|README|LICENSE|config|MANIFEST|COMMIT_EDITMSG|HEAD|index|desc/.match(tree['name'])))
          puts "Attempting to open file: " + @baseDirectory + tree['fullpath']
          fd = File.open(@baseDirectory + tree['fullpath'], "rb");
          data = fd.read.force_encoding('utf-8')
          fd.close
          @fileTree.createFile(tree['name'], 1, data)
          puts "createFile #{tree['name']}"
        else
          @fileTree.createFile(tree['name'])
        end

      elsif (tree['type'] == 'directory')
        # This is possible.. but we don't need to createFileTree(value) since we
        # have no children.. removed, case: Directory with no files or directories.
        @fileTree.mkDir(tree['name'])
        puts "createFileTree(): mkDir(1) #{tree['name']}"
        #createFileTree(value)
      end
      return
    end



    tree['children'].each do |value, k|
      next if (!(value.is_a?(Hash) || value.is_a?(Array)))
      next if (value['type'] == 'file')
      if (value['type'] == 'directory')
        # If the directory exists, do not try to create it again -- but still call
        # createFileTree(value) as it may have children that we have not encountered before
        if (!@fileTree.fileExists(value['fullPath']))
          puts "createFileTree(): mkDir(2) #{value['fullPath']}"
          @fileTree.mkDir(value['fullPath'])
        end
        createFileTree(value)
      elsif (value['type'] == 'root')
        #createFileTree(value)
      else
        puts "Unknown type #{value['type']}"
      end
    end

    tree['children'].each do |value, k|
      next if (!(value.is_a?(Hash) || value.is_a?(Array)))
      next if (value['type'] == 'directory')
      if (value['type'] == 'file')
        # If the file already exists in the database, DO NOTHING!
        next if (@fileTree.fileExists(value['fullPath']))

        if ((/\.(rb|html|php|out|save|log|js|txt|css|scss|coffee|md|rdoc|htaccess|c|rd|cpp)$/.match(value['name'])) || (/^([RM]akefile|Gemfile|README|LICENSE|config|MANIFEST|COMMIT_EDITMSG|HEAD|index|desc)/.match(value['name'])))
          # If it's a file that matches out hacked in regex, let's read it and pass the data along to createFile()
          puts "Attempting to open file: " + @baseDirectory + value['fullPath']
          fd = File.open(@baseDirectory + value['fullPath'], "rb");
          data = fd.read
          fd.close
          @fileTree.createFile(value['fullPath'], nil, data)
          puts "createFile #{value['fullPath']} with data"
        else
          # If we don't like the name or file extension, we just create a file with no data entry.. we should really load all files, but we don't deal with binaries yet
          # The Document abstraction doesn't allow for that, we really need a File abstraction instead
          # In fact, we don't even properly deal with non ASCII-8 files, we need to do some encoding checks to see if they're UTF-8, or have a JPEG header, etc.
          # We may have to shell out to GNU's 'file' for that, or build a Gem wrapper for 'file' if such a thing does not exist
          @fileTree.createFile(value['fullPath'])
          puts "createFile #{value['fullPath']} without data"
        end
      else
        # We shouldn't encounter this.
        puts "Unknown type #{value['type']}"
      end
    end


  end
end
