class AddFtypeToDirectoryEntry < ActiveRecord::Migration
  def change
    add_column :directory_entries, :ftype, :string
  end
end
