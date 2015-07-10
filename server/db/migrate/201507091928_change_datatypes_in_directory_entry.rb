class ChangeDatatypesInDirectoryEntry < ActiveRecord::Migration
  def up
    change_column :directory_entries, :srcpath, :string
    change_column :file_changes, :changeData, :binary, :limit => 16.megabyte
  end
end
