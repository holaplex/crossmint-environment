class AddUpiToNfts < ActiveRecord::Migration[7.0]
  def change
    add_column :nfts, :upi, :string
  end
end
