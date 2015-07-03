class CreateDirectoryEntries < ActiveRecord::Migration
  def change
    create_table :directory_entries do |t|
      t.string :curName
      t.references :owner, index: true, foreign_key: true
      t.references :createdBy, index: true, foreign_key: true

      t.timestamps null: false
    end
  end
end
