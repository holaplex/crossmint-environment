class AddMimeTypesToNfts < ActiveRecord::Migration[7.0]
  def change
    add_column :nfts, :gallery_type, :string
    add_column :nfts, :final_type, :string
  end
end
