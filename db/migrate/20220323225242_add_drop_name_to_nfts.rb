class AddDropNameToNfts < ActiveRecord::Migration[7.0]
  def change
    add_column :nfts, :drop_name, :string
  end
end
