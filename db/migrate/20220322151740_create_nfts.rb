class CreateNfts < ActiveRecord::Migration[7.0]
  def change
    create_table :nfts do |t|
      t.string :name
      t.string :description
      t.string :sku
      t.integer :scarcity
      t.references :collection, null: true, foreign_key: true
      t.string :gallery_url
      t.string :gallery_filename
      t.string :final_url
      t.string :final_filename
      t.string :creator
      t.integer :royalty_matrix
      t.string :legend
      t.references :school, null: true, foreign_key: true
      t.string :sport
      t.string :award

      t.timestamps
    end
  end
end
