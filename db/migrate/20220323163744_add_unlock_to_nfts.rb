class AddUnlockToNfts < ActiveRecord::Migration[7.0]
  def change
    add_column :nfts, :unlock, :string
  end
end
