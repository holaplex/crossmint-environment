# unused.rake: -*- Ruby -*-  DESCRIPTIVE TEXT.
# 
#  Copyright (c) 2022 Brian J. Fox Opus Logica, Inc.
#  Author: Brian J. Fox (bfox@opuslogica.com)
#  Birthdate: Tue Mar 22 16:10:19 2022.
namespace :unused do
  desc "Move the old filenames to the new SKU names"
  task modernize: :environment do
    Nft.all.each do |nft|
      old_final = nft.make_old_image_filename(nft.final_url, "mp4")
      new_final = nft.make_image_filename(nft.final_url, "mp4")

      if File.exists?(old_final)
        File.rename(old_final, new_final)
        nft.final_filename = new_final
        nft.save
      end

      old_gallery = nft.make_old_image_filename(nft.gallery_url, "jpg")
      new_gallery = nft.make_image_filename(nft.gallery_url, "jpg")

      if File.exists?(old_gallery)
        File.rename(old_gallery, new_gallery)
        nft.gallery_filename = new_gallery
        nft.save
      end
    end
  end
end
