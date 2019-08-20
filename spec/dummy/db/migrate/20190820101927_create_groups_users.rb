class CreateGroupsUsers < ActiveRecord::Migration[5.2]
  def change
    create_table :groups_users do |t|
      t.integer :group_id, null: false
      t.integer :user_id, null: false

      t.timestamps null: false
    end
  end
end
