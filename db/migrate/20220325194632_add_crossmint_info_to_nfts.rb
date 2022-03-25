class AddCrossmintInfoToNfts < ActiveRecord::Migration[7.0]
  def change
    add_column :nfts, :cm_address, :string
    add_column :nfts, :cm_image_url, :string
    add_column :nfts, :cm_video_url, :string
    add_column :nfts, :clientId, :string
  end
end
