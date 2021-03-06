class FileChange < ActiveRecord::Base
  # belongs_to :createdBy, class_name: "User", primary_key: "z", foreign_key: "id"
  # has_many :children, class_name: "DirectoryEntry", foreign_key: "owner_id", foreign_type: "DirectoryEntry"

  belongs_to :User, class_name: "User", primary_key: "User_id", foreign_key: "id"
  belongs_to :DirectoryEntry, class_name: "DirectoryEntryHelper", primary_key: "DirectoryEntry_id", foreign_key: "id"
  #  has_one :DirectoryEntry, class_name: "DirectoryEntryHelper", primary_key: "DirectoryEntry_id"

  def self.create(params)
    puts "Entering FileChange::create() function"
    puts $Project.dump(params)

    if (params[:User_id].is_a?(Fixnum))
      #params[:User_id] = User.find_by_id(params[:User_id])
    end

    # if (params[:modifiedBy].is_a?(Fixnum))
    #   params[:modifiedBy] = User.find_by_id(params[:modifiedBy])
    # end

    if (params[:DirectoryEntry_id].is_a?(Fixnum))
      #params[:DirectoryEntry_id] = DirectoryEntry.find_by_id(params[:DirectoryEntry_id])
    end

    if (!params[:User_id])
      params[:User_id] = 1
    end
    if (!params[:DirectoryEntry_id])
      params[:DirectoryEntry_id] = 1
    end

    puts "FileChange::create(): Call new(params)"
    fileChange = FileChange.new(params)
    puts "FileChange::create(): Call save!"
    begin
      while (!fileChange.save!) do
        puts "Unable to fileChange.save.."
      end
    rescue Exception => e
      puts "!!!!!! fileChange.save error !!!!!!"
      puts $Project.dump(e)
    end

    puts "FileChange::create(): save! called, returning fileChange entry.."
    #puts $Project.dump(fileChange)
    #puts $Project.dump(fileChange.methods)
    #puts $Project.dump(fileChange.DirectoryEntry)
    #de = fileChange.DirectoryEntry
    return(fileChange)
  end

end

class FileChangeHelper < FileChange


end
