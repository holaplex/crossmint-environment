class AddFanRankingPointsToNfts < ActiveRecord::Migration[7.0]
  def change
    add_column :nfts, :fan_ranking_points, :integer, default: 0
  end
end
