class CreateDirectoryEntries < ActiveRecord::Migration
  def change
    create_table :directory_entries do |t|
      t.string :curName
      t.integer :owner_id, :index => true, :foreign_key => true
      t.integer :createdBy_id, :index => true,  :foreign_key => true
      t.timestamps null: false
    end
    add_foreign_key :directory_entries, :directory_entries, :column => 'owner_id', :primary_key => 'id'
    add_foreign_key :directory_entries, :users, :column => 'createdBy_id', :primary_key => 'id'
  end
end
