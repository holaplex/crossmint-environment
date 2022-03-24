require 'smarter_csv'
require 'debug'

namespace :import do

  STDOUT.sync = true
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

  desc "Import accounts from a CSV file"
  task accounts: :environment do
    # Overcome the shitty limitations of rake and rails.
    ARGV.each { |a| task a.to_sym do ; end }

    # Process the accounts file.
    processed = 0
    failed = []
    chunknum = 1
    filename = ARGV[1]
    options = { :chunk_size => 500 }
    n = SmarterCSV.process(filename, options) do |chunk|
      puts "\nChunk #{chunknum}: Processed: #{processed}, Failures: #{failed.count}"
      chunknum += 1;
      chunk.each do |hash|
        print "."
        processed += 1
        account = Account.where(account_number: hash[:account_number]).first_or_create(hash)
        if account.errors.count > 0
          error_messages=[]
          account.errors.each {|e| error_messages.push("#{e.attribute.to_s.capitalize} is #{e.type.to_s.gsub(/_/,' ')}") }
          failed.append("Account #{hash[:account_number]} was NOT saved to the database: #{error_messages.to_sentence}")
        end
      end
    end
    puts "Processed #{processed} records.  Number of failures: #{failed.count}"
    failed.each {|f| puts f}
  end

  desc "Import information about purchased NFTs from a CSV file"
  task purchased: :environment do
    # Overcome the shitty limitations of rake and rails.
    ARGV.each { |a| task a.to_sym do ; end }

    # Process the purchased file.
    processed = 0
    failed = []
    chunknum = 1
    filename = ARGV[1]
    options = { :chunk_size => 500 }
    n = SmarterCSV.process(filename, options) do |chunk|
      puts "\nChunk #{chunknum}: Processed: #{processed}, Failures: #{failed.count}"
      chunknum += 1;
      chunk.each do |hash|
        count_it
        processed += 1
        nft = Nft.where(final_url: hash[:final_url]).first_or_create(hash.slice(:name, :description, :sku, :scarcity, :gallery_url, :final_url, :creator, :royalty_matrix, :legend, :sport, :award))

        if nft.errors.count > 0
          error_messages=[]
          nft.errors.each {|e| error_messages.push("#{e.attribute.to_s.capitalize} is #{e.type.to_s.gsub(/_/,' ')}") }
          failed.append("NFT #{hash[:final_url]} was NOT saved to the database: #{error_messages.to_sentence}")
        else
          # Fix missing name for recovery.
          nft.name ||= hash[:name]
          nft.description ||= hash[:description]
          if not nft.school and not hash[:school].blank?
            nft.school = School.where(name: hash[:school]).first_or_create(conference: Conference.where(name: hash[:conference]).first_or_create)
          end
          if not nft.collection and not hash[:collection].blank?
            nft.collection = Collection.where(name: hash[:collection]).first_or_create
          end
          nft.save
          
          # Now attach this to the owner.
          account = Account.where(account_number: hash[:accounts]).first
          OwnedNft.where(nft: nft, account: account).first_or_create if account
        end
      end
    end
    puts "Processed #{processed} records.  Number of failures: #{failed.count}"
    failed.each {|f| puts f}
  end

  desc "Import information about NFT drops from a CSV file"
  task nfts: :environment do
    # Overcome the shitty limitations of rake and rails.
    ARGV.each { |a| task a.to_sym do ; end }

    # Process the NFT file.
    processed = 0
    warn_duplicates = false
    failed = []
    chunknum = 1
    filename = ARGV[1]
    warn_duplicates = true if ARGV[2] == "warn"
    options = { :chunk_size => 500,
                :key_mapping => { nft_name: :name, nft_description: :description, :"edition_/_scarcity" => :scarcity,
                                  gallery_image: :gallery_url, final_media: :final_url, gallery_image_asset: :gallery_url, final_media_asset: :final_url }
              }
    n = SmarterCSV.process(filename, options) do |chunk|
      puts "\nChunk #{chunknum}: Processed: #{processed}, Failures: #{failed.count}"
      chunknum += 1;
      chunk.each do |hash|
        next if hash[:name].blank? and hash[:final_url].blank?
        count_it
        processed += 1
        if not hash[:price].blank?
          p = hash[:price].sub(/[$\t ]/,"").to_f rescue nil
          hash[:price] = p
        end
        if not hash[:fan_ranking_points].blank? and hash[:fan_ranking_points].is_a?(String)
          hash[:fan_ranking_points] = hash[:fan_ranking_points].gsub(/[^0-9\.]/,'').to_i rescue nil
        end

        fields = hash.slice(:name, :description, :sku, :upi, :scarcity, :gallery_url, :fan_ranking_points, :unlock, :final_url, :creator, :royalty_matrix, :legend, :sport, :award, :price, :drop_name)

        nft = Nft.where(final_url: hash[:final_url]).first_or_initialize(fields)
        
        if nft.errors.count > 0
          error_messages=[]
          nft.errors.each {|e| error_messages.push("#{e.attribute.to_s.capitalize} is #{e.type.to_s.gsub(/_/,' ')}") }
          failed.append("NFT #{hash[:final_url]} was NOT saved to the database: #{error_messages.to_sentence}")
        else
          if warn_duplicates and not nft.new_record?
            puts "Duplicate Record Found!  #{nft.as_json}"
            exit
          end
          if not nft.school and not hash[:school].blank?
            nft.school = School.where(name: hash[:school]).first_or_initialize(conference: Conference.where(name: hash[:conference]).first_or_initialize)
          end
          if not nft.collection and not hash[:collection].blank?
            nft.collection = Collection.where(name: hash[:collection]).first_or_initialize
          end
        end

        nft.save if nft
      end
    end
    puts "Processed #{processed} records.  Number of failures: #{failed.count}"
    failed.each {|f| puts f}
  end

  desc "Get the NFT data from Google Drive"
  task assets: :environment do
    Nft.initialize_google_api
    Nft.all.each do |nft|
      print("#{nft.name} -> jpg:")
      (nft.get_gallery_file rescue (print "FAILED"; nil)) if not nft.gallery_filename
      print("done; mp4:")
      (nft.get_final_file rescue (print "FAILED"; nil)) if not nft.final_filename
      puts("done.")
    end
  end
end
