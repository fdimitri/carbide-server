class AddRevisionToDirectoryEntry < ActiveRecord::Migration
  def change
    add_column :directory_entries, :curRevision, :integer
  end
end
