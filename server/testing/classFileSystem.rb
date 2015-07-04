require 'json'
require 'yaml'


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
    dirs = Dir.entries(directoryName).select { |f| ((File.directory? f) && f != '.' && f != '..')}
    return dirs
  end


  def buildTree(path=@baseDirectory, name=nil)
    data = {'name' => (name || path)}
    data['children'] = children = []
    if (path == @baseDirectory)
      data['type'] = 'root'
    end
    Dir.foreach(path) do |entry|
      next if (entry == '..' || entry == '.')
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
      if (tree['type'] == 'file')
        if ((/\.(rb|html|php|out|save|log|js|txt|css|scss|coffee|md|rdoc|htaccess)/.match(tree['name'])) || (/Rakefile|Gemfile|README|LICENSE|config|COMMIT_EDITMSG|HEAD|index|desc/.match(tree['name'])))
          puts "Attempting to open file: " + @baseDirectory + tree['fullpath']
          fd = File.open(@baseDirectory + tree['fullpath'], "rb");
          data = fd.read
          fd.close
          @fileTree.createFile(tree['name'], data)
          puts "createFile #{tree['name']}"
        else
          @fileTree.createFile(tree['name'])
        end
      elsif (tree['type'] == 'directory')
        @fileTree.mkDir(tree['name'])
        puts "mkDir #{tree['name']}"
        createFileTree(value)
      end
      return
    end



    tree['children'].each do |value, k|
      next if (!(value.is_a?(Hash) || value.is_a?(Array)))
      next if (value['type'] == 'file')
      if (value['type'] == 'directory')
        puts "mkDir #{value['fullPath']}"
        @fileTree.mkDir(value['fullPath'])
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
        if ((/\.(rb|html|php|out|save|log|js|txt|css|scss|coffee|md|rdoc|htaccess)/.match(value['name'])) || (/Rakefile|Gemfile|README|LICENSE|config|COMMIT_EDITMSG|HEAD|index|desc/.match(value['name'])))
          puts "Attempting to open file: " + @baseDirectory + value['fullPath']
          fd = File.open(@baseDirectory + value['fullPath'], "rb");
          data = fd.read
          fd.close
          @fileTree.createFile(value['fullPath'], data)
          puts "createFile #{value['fullPath']} with data"
        else
          @fileTree.createFile(value['fullPath'])
          puts "createFile #{value['fullPath']} without data"
        end
      else
        puts "Unknown type #{value['type']}"
      end
    end


  end
end
