class FileChange < ActiveRecord::Base
  belongs_to :User
  belongs_to :DirectoryEntry
  belongs_to :modifiedBy, class_name: "User"

  def self.create(params)
    puts "Entering create function"
    puts YAML.dump(params)
    if (params[:User].is_a?(Fixnum))
      params[:User] = User.find_by_id(params[:User])
    end

    if (params[:modifiedBy].is_a?(Fixnum))
      params[:modifiedBy] = User.find_by_id(params[:modifiedBy])
    end

    if (params[:DirectoryEntry].is_a?(Fixnum))
      params[:DirectoryEntry] = DirectoryEntry.find_by_id(params[:DirectoryEntry])
    end
    fileChange = FileChange.new(params)
    fileChange.save!
    return(params)
  end
end

class FileChangeHelper < FileChange



end
