namespace :import do

  STDOUT.sync = true
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
    duplicates = []
    chunknum = 1
    filename = ARGV[1]
    filename ||= "../OG-ACCOUNTS/purchased.csv"
    options = { :chunk_size => 1500 }
    n = SmarterCSV.process(filename, options) do |chunk|
      puts "\nChunk #{chunknum}: Processed: #{processed}, Failures: #{failed.count}"
      chunknum += 1;
      chunk.each do |hash|
        processed += 1
        nft = Nft.where(final_url: hash[:final_url], name: hash[:name], sku: hash[:sku]).first_or_initialize(hash.slice(:description, :scarcity, :gallery_url, :final_url, :creator, :royalty_matrix, :legend, :sport, :award))

        if nft.errors.count > 0
          error_messages=[]
          nft.errors.each {|e| error_messages.push("#{e.attribute.to_s.capitalize} is #{e.type.to_s.gsub(/_/,' ')}") }
          failed.append("NFT #{hash[:final_url]} was NOT saved to the database: #{error_messages.to_sentence}")
        else
          if not nft.school and not hash[:school].blank?
            nft.school = School.where(name: hash[:school]).first_or_initialize(conference: Conference.where(name: hash[:conference]).first_or_initialize)
          end

          if not nft.collection and not hash[:collection].blank?
            nft.collection = Collection.where(name: hash[:collection]).first_or_initialize
          end
        end

        nft.save or raise "Hell"

        # Now attach this to the owner.
        account = Account.where(account_number: hash[:accounts].to_s).first
        if account
          # Please note that we assume that each line represents a valid purchase, period.
          # There is no idea of "Fred already bought this NFT, he couldn't have wanted more than one."
          onft = OwnedNft.create(nft: nft, account: account)
          count_it(".")
        else
          raise "Your file contains an account that doesn't exist in the system: #{hash[:accounts]}"
        end
      end
    end
    puts "Processed #{processed} records."
    if failed.length > 0
      puts "#{failed.length} failures to save."
      failed.each {|f| puts f}
    end

    if duplicates.length > 0
      puts "#{duplicates.length} duplicates found."
      puts "Already recorded purchases (OwnedNft): #{duplicates}"
    end
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

        (nft.save if nft) rescue debugger
      end
    end
    puts "Processed #{processed} records.  Number of failures: #{failed.count}"
    failed.each {|f| puts f}
  end

  desc "Get the NFT data from Google Drive"
  task assets: :environment do
    # Overcome the shitty limitations of rake and rails.
    ARGV.each { |a| task a.to_sym do ; end }

    # If there is an argument, it is a Drop Name.
    if ARGV[1].blank?
      base = Nft.all
    else
      base = Nft.where(drop_name: ARGV[1])
    end

    Nft.initialize_google_api

    base.each do |nft|
      print("#{nft.name} -> Gallery: ")
      got_file = nft.get_gallery_file rescue nil
      if got_file
        nft.update_mime_type_and_file(:gallery)
        print("#{nft.gallery_type} - #{nft.gallery_filename} ")
      else
        print("FAILED! ")
      end

      print("Final Media: ")
      got_file = nft.get_final_file rescue nil
      if got_file
        nft.update_mime_type_and_file(:final)
        print("#{nft.final_type} - #{nft.final_filename} ")
      else
        print("FAILED! ")
      end
      puts("")
    end
  end

  desc "Import a file of completed candymachine data from crossmint"
  task crossmint: :environment do
    # Overcome the shitty limitations of rake and rails.
    ARGV.each { |a| task a.to_sym do ; end }

    if ARGV[1].blank?
      raise "import:crossmint requires a filename for the input json data"
    end

    filename = ARGV[1]

    Nft.import_crossmint(filename)
  end

  desc "Import an xlsx (excel spreadsheet) of CampusLegends 'drop' data and process it"
  task campussheet: :environment do
    # Overcome the shitty limitations of rake and rails.
    ARGV.each { |a| task a.to_sym do ; end }

    if ARGV[1].blank?
      raise "import:campussheet requires a filename for the input json data"
    end

    filename = ARGV[1]

    xlsx = Roo::Spreadsheet.open(filename)
    tabs = xlsx.sheets

    tabs.each do |tab|
      sheet = xlsx.sheet(tab)
      last = sheet.last_row + 1

      # Advance our row number to the first row that has "NFT Name" in it.
      i = 0
      i += 1 while sheet.row(i)[0] != "NFT Name" && i < last

      headers = sheet.row(i)

      i += 2
      while i < last
        count_it
        nft = Nft.import_from_spreadsheet_row(sheet.row(i), headers, tab) if sheet.row(i)[0]
        i += 1
      end
    end
  end
end
