class AddSrcpathToDirectoryEntry < ActiveRecord::Migration
  def change
    add_column :directory_entries, :srcpath, :text
  end
end
