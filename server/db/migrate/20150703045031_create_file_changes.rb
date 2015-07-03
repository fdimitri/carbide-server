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
      t.references :User, index: true, foreign_key: true
      t.references :DirectoryEntry, index: true, foreign_key: true
      t.integer :revision
      t.references :modifiedBy, index: true, foreign_key: true

      t.timestamps null: false
    end
  end
end
