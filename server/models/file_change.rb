class FileChange < ActiveRecord::Base
  belongs_to :User
  belongs_to :DirectoryEntry
  belongs_to :modifiedBy, class_name: "User"
end
