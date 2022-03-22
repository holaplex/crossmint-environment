class CreateAccounts < ActiveRecord::Migration[7.0]
  def change
    create_table :accounts do |t|
      t.string :shopify_number
      t.string :account_number
      t.string :email
      t.string :first_name
      t.string :last_name

      t.timestamps
    end
  end
end
