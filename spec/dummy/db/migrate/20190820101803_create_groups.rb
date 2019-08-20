class CreateGroups < ActiveRecord::Migration[5.2]
  def change
    create_table :groups do |t|
      t.string :display_name, null: false
      t.integer :company_id, null: false

      t.timestamps null: false
    end
  end
end
