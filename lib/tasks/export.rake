require 'smarter_csv'
require 'debug'
# 
# * N image files (each with a unique name or number)
# * N JSONs in the metaplex metadata standard (matching the name of the image files)
# * A JSON file containing an array of objects containing an 'email' and 'nft_name' property.
# Because users may have multiple NFTs, the same 'email' field can appear in multiple entries
# in this object. Same goes for 'nft_name', as I understand some NFTs are repeated.

namespace :export do

  $counter = 0
  
  def count_it
    $counter += 1;
    if $counter % 10 == 0
      print("#{$counter}")
      puts("") if $counter % 50 == 0
    else
      print(".")
    end
  end

  desc "Export data for crossmint for REMINT.  Takes FILENAME as argument"
  task remint: :environment do

    # Overcome the shitty limitations of rake and rails.
    ARGV.each { |a| task a.to_sym do ; end }

    owners = []
    Nft.all.each do |nft|
      nft.owners.each do |owner|
        owners.push({ email: owner.email, nft_name: nft.upi || nft.sku, jpg: nft.gallery_filename, mp4: nft.final_filename })
      end
    end
    File.write(output, JSON.pretty_generate(owners))
  end

  desc "Export data for crossmint for drops"
  task crossmint: :environment do

    # Overcome the shitty limitations of rake and rails.
    ARGV.each { |a| task a.to_sym do ; end }

    # If there is an argument, it is a Drop Name.
    if ARGV[1].blank?
      base = Nft.all
    else
      base = Nft.where(drop_name: ARGV[1])
    end

    puts "Writing metadata json for #{base.count} NFTs..."

    base.each do |nft|
      count_it
      nft.write_metadata
    end
  end

  desc "Export data for frontend for drops"
  task frontend: :environment do

    # Overcome the shitty limitations of rake and rails.
    ARGV.each { |a| task a.to_sym do ; end }

    # If there is an argument, it is a Drop Name.
    drop_name = ""
    if ARGV[1].blank?
      base = Nft.all
    else
      drop_name = ARGV[1]
      base = Nft.where(drop_name: drop_name)
    end

    puts "Writing frontend configuration data for #{base.count} NFTs..."
    output = base.as_json(frontend: true)
    File.write("frontend-#{drop_name.parameterize}.json", JSON.pretty_generate(output))
  end
  
  desc "Export data for candymachine configs for drops"
  task candymachines: :environment do

    # Overcome the shitty limitations of rake and rails.
    ARGV.each { |a| task a.to_sym do ; end }

    # If there is an argument, it is a Drop Name.
    if ARGV[1].blank?
      base = Nft.all
    else
      base = Nft.where(drop_name: ARGV[1])
    end

    puts "Writing CandyMachine configuration data for #{base.count} NFTs..."
    base.each do |nft|
      count_it
      nft.write_candymachine_config
    end
  end
end
