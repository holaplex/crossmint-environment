class AddPriceToNfts < ActiveRecord::Migration[7.0]
  def change
    add_column :nfts, :price, :float
    add_column :nfts, :currency, :string
  end
end
