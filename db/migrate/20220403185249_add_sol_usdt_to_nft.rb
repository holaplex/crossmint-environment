class AddSolUsdtToNft < ActiveRecord::Migration[7.0]
  def change
    add_column :nfts, :price_in_sol, :float
    add_column :nfts, :sol_usdt, :float
    add_column :nfts, :sol_usdt_when, :datetime
  end
end
