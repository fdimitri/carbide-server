class CreateFileChanges < ActiveRecord::Migration
  def change
    create_table :file_changes do |t|
      t.string :changeType
      t.text :changeData
      t.integer :startLine
      t.integer :startChar
      t.integer :endLine
      t.integer :endChar
      t.timestamp :mtime
      t.integer :User_id, index: true, foreign_key: true
      t.integer :DirectoryEntry_id, index: true, foreign_key: true
      t.integer :revision
      t.timestamps null: false
    end
    add_foreign_key :file_changes, :directory_entries, :column => 'DirectoryEntry_id', :primary_key => 'id'
    add_foreign_key :file_changes, :users, :column => 'User_id', :primary_key => 'id'

  end
end
