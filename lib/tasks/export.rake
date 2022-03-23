require 'smarter_csv'
require 'debug'
# 
# * N image files (each with a unique name or number)
# * N JSONs in the metaplex metadata standard (matching the name of the image files)
# * A JSON file containing an array of objects containing an 'email' and 'nft_name' property.
# Because users may have multiple NFTs, the same 'email' field can appear in multiple entries
# in this object. Same goes for 'nft_name', as I understand some NFTs are repeated.

namespace :export do

  desc "Export data for crossmint for REMINT.  Takes FILENAME as argument"
  task remint: :environment do

    # Overcome the shitty limitations of rake and rails.
    ARGV.each { |a| task a.to_sym do ; end }

    owners = []
    Nft.all.each do |nft|
      nft.owners.each do |owner|
        owners.push({ email: owner.email, nft_name: nft.sku, jpg: nft.gallery_filename, mp4: nft.final_filename })
      end
    end
    File.write(output, JSON.pretty_generate(owners))
  end

  desc "Export data for crossmint for drops"
  task crossmint: :environment do

    Nft.all.each do |nft|
      nft.write_metadata
    end
  end
end
