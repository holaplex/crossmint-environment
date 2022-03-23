class AddPriceToNfts < ActiveRecord::Migration[7.0]
  def change
    add_column :nfts, :price, :float, default: 0.0
    add_column :nfts, :currency, :string, default: "USD"
  end
end
