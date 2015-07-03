class AddFtypeToDirectoryEntry < ActiveRecord::Migration
  def change
    add_column :directory_entries, :ftype, :string
    remove_column :directory_entries, :type
  end
end
