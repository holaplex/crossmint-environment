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
  
  def count_it(with_char=".")
    $counter += 1;
    if $counter % 10 == 0
      print("#{$counter}")
      puts("") if $counter % 50 == 0
    else
      print(with_char)
    end
  end

  desc "Export data for crossmint for REMINT.  Takes FILENAME as argument"
  task remint: :environment do

    # Overcome the shitty limitations of rake and rails.
    ARGV.each { |a| task a.to_sym do ; end }

    owners = []
    output = ARGV[1] || "remint.json"
    
    Nft.all.each do |nft|
      nft.owners.each do |owner|
        owners.push({ email: owner.email, nft_name: nft.name, metadata_json: nft.metadata_filename, jpg: nft.gallery_filename, mp4: nft.final_filename })
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

  # Find and export owners who have purchased multiple copies of specific NFTs.
  task multiples: :environment do
    output = "mint_purchased.json"
    # Brute force this - it's not clever, but it works.
    remint_these = []
    owners = []
    Account.all.each do |owner|
      base = owner.nfts.where(drop_name: "Remint Missed")

      if base.count > base.uniq.count
        # This account has duplicate purchases of NFTs in it.
        # Collect the duplicates for reminting.
        count_it("R")

        owners.push(owner)
        the_list = base.to_ary

        # For every element in the array, if there is a duplicate of that element
        # in the remainder of the array, we need to mint another one for this
        # account.
        while not the_list.empty?
          nft = the_list.pop
          if the_list.include?(nft)
            entry = { email: owner.email, nft_name: nft.upi || nft.sku, jpg: nft.gallery_filename }
            entry[:mp4] = nft.final_filename if nft.final_type == "video/mp4"
            remint_these.push(entry)
          end
        end
      else
        count_it(".")
      end
    end

    puts ""
    puts "#{owners.length} Owners will receive #{remint_these.length} NFTs"
    File.write(output, JSON.pretty_generate(remint_these))
  end
end
