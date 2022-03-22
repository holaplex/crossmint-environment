class CreateOwnedNfts < ActiveRecord::Migration[7.0]
  def change
    create_table :owned_nfts do |t|
      t.references :account, null: false, foreign_key: true
      t.references :nft, null: false, foreign_key: true

      t.timestamps
    end
  end
end
