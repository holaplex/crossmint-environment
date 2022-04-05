require "google/apis/drive_v3"
require "googleauth"
require "googleauth/stores/file_token_store"
require "fileutils"
require "uri"
require "net/http"

class Nft < ApplicationRecord
  belongs_to :collection, optional: true
  belongs_to :school, optional: true
  has_one :conference, through: :school
  has_many :owned_nfts
  has_many :owners, through: :owned_nfts, source: :account
  @@google_drive = nil
  @@google_creds = nil

  def self.lookup(thing)
    candidate = self.where(sku: thing).first
    candidate ||= self.where(upi: thing).first
    candidate ||= self.where("final_url LIKE :ident", ident: "%#{thing}%").first
    candidate ||= self.where("gallery_url LIKE :ident", ident: "%#{thing}%").first
    candidate ||= self.where(name: thing).first
  end
      
  def self.import_crossmint(filename)
    data = JSON.parse(File.read(filename))

    data.each do |hash|
      nft = self.where(upi: hash["upi"]).first
      if nft
        nft.cm_address   = hash["cmAddr"]
        nft.cm_image_url = hash["image"]
        nft.cm_video_url = hash["video"]
        nft.clientId = hash["clientId"]
        nft.save
      end
    end
  end

  def self.initialize_google_api
    if not @@google_drive
      @@google_drive = Google::Apis::DriveV3::DriveService.new
      @@google_drive.client_options.application_name = "Crossmint Puller"
    end
    @@google_drive.authorization = self.google_authorize
  end
  
  def get_drive_metadata(file_id)
    # I hate google almost as much as I hate DHH.
    self.class.initialize_google_api if not @@google_drive
    uri = URI("https://www.googleapis.com/drive/v3/files/#{file_id}?supportsAllDrives=true&key=#{@@google_creds[:client_id]}")
    headers  = {
      "Authorization" => "Bearer #{@@google_creds[:access_token]}",
      "Accept" => "application/json"
    }
    https = Net::HTTP.new(uri.host,uri.port)
    https.use_ssl = true
    req = Net::HTTP::Get.new(uri, headers)
    response = JSON.parse(https.request(req).body) rescue nil
  end

  def get_drive_file(id, output_filename)
    self.class.initialize_google_api if not @@google_drive
    response = @@google_drive.get_file(id, supports_all_drives: true, download_dest: output_filename)
  end

  def get_gallery_file(options = { force: false })
    maybe_make_gallery_filename
    get_file(force: options[:force], url: self.gallery_url, file: self.gallery_filename)
  end

  def get_final_file(options = { force: false })
    maybe_make_final_filename
    get_file(force: options[:force], url: self.final_url, file: self.final_filename)
  end

  def get_file(options = {})
    result = true
    if not File.exists?(options[:file]) or options[:force]
      identifier = get_identifier(options[:url])
      get_drive_file(identifier, options[:file])
      result = self.save
    end
    result
  end

  ##
  # Ensure valid credentials, either by restoring from the saved credentials
  # files or intitiating an OAuth2 authorization. If authorization is required,
  # the user's default browser will be launched to approve the request.
  #
  # @return [Google::Auth::UserRefreshCredentials] OAuth2 credentials
  def self.google_authorize
    client_id = Google::Auth::ClientId.from_file(ENV['CREDENTIALS_PATH'])
    token_store = Google::Auth::Stores::FileTokenStore.new(file: "token.yaml")
    authorizer = Google::Auth::UserAuthorizer.new(client_id, Google::Apis::DriveV3::AUTH_DRIVE, token_store, "http://localhost:1/")
    user_id = "default"
    credentials = authorizer.get_credentials(user_id)
    if credentials.nil?
      url = authorizer.get_authorization_url
      $stderr.puts ""
      $stderr.puts "-----------------------------------------------"
      $stderr.puts "Requesting authorization for '#{user_id}'"
      $stderr.puts "Open the following URL in your browser and authorize the application."
      $stderr.puts url
      $stderr.puts
      $stderr.puts "At the end the browser will fail to connect to http://localhost:1/?code=SOMECODE&scope=..."
      $stderr.puts "Copy the value of SOMECODE from the address and paste it below"

      code = $stdin.readline.chomp
      $stderr.puts "-----------------------------------------------"
      credentials = authorizer.get_and_store_credentials_from_code(user_id: user_id, code: code)
    end
    @@google_creds = ActiveSupport::HashWithIndifferentAccess.new(JSON.parse(YAML.load_file("token.yaml")["default"]))
    credentials
  end

  def get_identifier(source_url)
    items = source_url.split("/").reverse
    items.shift(1) if items[0] =~ /view/
    items[0].sub(/[?].*$/, '')
  end

  def make_old_image_filename(source_url, extension)
    "#{ENV['NFT_ASSETS_DIR']}/images/#{get_identifier(source_url)}.#{extension}"
  end
  
  def make_image_filename(source_url, extension)
    # Except, we are ignoring the ID in the source URL, and using the SKU instead.
    # "#{ENV['NFT_ASSETS_DIR']}/images/#{get_identifier(source_url)}.#{extension}"
    "#{ENV['NFT_ASSETS_DIR']}/images/#{self.sku || get_identifier(source_url)}.#{extension}"
  end

  def maybe_make_final_filename
    self.final_filename ||= make_image_filename(self.final_url, "mp4")
  end

  def maybe_make_gallery_filename
    self.gallery_filename ||= make_image_filename(self.gallery_url, "jpg")
  end

  def update_mime_types
    update_mime_type_and_file(:gallery)
    update_mime_type_and_file(:final)
  end

  def update_mime_type_and_file(tag)
    magic = FileMagic.new(FileMagic::MAGIC_MIME)
    t = (tag.to_s + "_type")
    f = (tag.to_s + "_filename")

    # If the file doesn't exist, we're fickt.
    raise "The #{tag} file for NFT<#{self.id}> doesn't exist!" if not File.exists?(self.send(f))

    # Get the file's mime type and store it.
    self.send("#{t}=", magic.file(self.send(f)).split(";").first)

    # Check that the file's extension matches the mime type.
    wanted  = self.send(t).split("/").second
    current = File.extname(self.send(f)).downcase.delete('.')

    if (wanted != current)
      newname = self.send(f).chomp(".#{current}") + ".#{wanted}"
      File.rename(self.send(f), newname)
      self.send("#{f}=", newname)
    end

    # Finally, save changes, if any.
    save
  end
  
  def metadata_filename
    "#{ENV['NFT_ASSETS_DIR']}/images/#{self.sku || get_identifier(final_url)}.json"
  end

  def candymachine_config_filename
    "#{ENV['NFT_ASSETS_DIR']}/images/#{self.sku || get_identifier(final_url)}-candymachine.json"
  end

  def nft_attributes
    result = [
      { trait_type: "school", value: self.school&.name },
      { trait_type: "conference", value: self.conference&.name },
      { trait_type: "scarcity", value: self.scarcity }
    ]

    result.push({ trait_type: "sku", value: self.sku }) if not self.sku.blank?
    result.push({ trait_type: "upi", value: self.upi }) if not self.upi.blank?
    result.push({ trait_type: "sport", value: self.sport }) if not self.sport.blank?
    result.push({ trait_type: "unlock", value: self.unlock }) if not self.unlock.blank?
    result.push({ trait_type: "award", value: self.award }) if not self.award.blank?

    result
  end
  
  def metadata

    result = {
      name: self.name,
      symbol: "CLHP",
      description: self.description,
      seller_fee_basis_points: 1000,
      image: self.gallery_filename,
      external_url: "https://campuslegends.com/",
      attributes: self.nft_attributes,

      collection: {
        name: self.collection&.name,
        family: "Campus Legends"
      },

      properties: {
        files: [
          {
            file: self.final_filename,
            uri: self.final_url,
            type: self.final_type
          },
          {
            file: self.gallery_filename,
            uri: self.gallery_url,
            type: self.gallery_type
          }
        ],
        category: self.final_type.split("/").first,
        creators: [
          {
            share: 100,
            address: "C3nPuV9Js259Cyue6ptyR8xUTdRWFXRTntQCBJjFxTcm"
          }
        ],
      }
    }

    result[:animation_url] = self.final_filename if result[:category] == "video"

    result
  end

  def get_golive_date
    the_date = Date.today
    if self.drop_name
      date_part = self.drop_name.split(" ")[0]
      if date_part =~ /^[0-9][0-9]-[0-9][0-9]-[0-9][0-9]$/
        mm,dd,yy = date_part.split("-")
        yy = "20" + yy
        the_date = Date.new(yy.to_i, mm.to_i, dd.to_i)
      end
    end
    the_date
  end
      

  def candymachine_config

    result = {
      price: self.get_sol_price,
      number: self.scarcity,
      gatekeeper: nil,
      solTreasuryAccount: "2YZwtDSEeu3Tnmh6bbPwWWXJywTX9jGW6jbb1Sn2Z9Pj",
      goLiveDate: self.get_golive_date,
      endSettings: nil,
      whitelistMintSettings: nil,
      hiddenSettings: nil,
      storage: "nft-storage",
      ipfsInfuraProjectId: nil,
      ipfsInfuraSecret: nil,
      nftStorageKey: nil,
      awsS3Bucket: nil,
      noRetainAuthority: false,
      noMutable: false
    }

    result
  end
  
  def write_metadata(options={force: false})
    result = true

    if not File.exists?(self.metadata_filename) or options[:force]
      result = File.write(self.metadata_filename, JSON.pretty_generate(self.metadata))
    end

    result
  end

  $sol_usdt = nil
  $sol_usdt_when = nil
  def write_candymachine_config(options={force: false})
    result = true
    if not File.exists?(self.candymachine_config_filename) or options[:force]
      self.price_in_sol = self.get_sol_price
      self.sol_usdt = $sol_usdt
      self.sol_usdt_when = $sol_usdt_when
      self.save
      result = File.write(self.candymachine_config_filename, JSON.pretty_generate(self.candymachine_config))
    end

    result
  end

  def get_sol_price
    if not $sol_usdt
      uri = URI("https://api.binance.com/api/v3/ticker/price")
      params = { symbol: "SOLUSDT" }
      uri.query = URI.encode_www_form(params)
      res = Net::HTTP.get_response(uri)
      hash = JSON.parse(res.body) if res.is_a?(Net::HTTPSuccess)
      $sol_usdt = hash['price'].to_f if hash
      $sol_usdt_when = Time.new.in_time_zone("GMT")
    end

    if $sol_usdt
      self.sol_usdt = $sol_usdt
      self.sol_usdt_when = $sol_usdt_when
      (self.price / $sol_usdt).round(2)
    else
      0.0
    end
  end

  def as_json(options={})
    self.price_in_sol ||= self.get_sol_price
    self.save
    result = ActiveSupport::HashWithIndifferentAccess.new(super)

    if options[:frontend]
      result[:upi] = result[:upi].to_i
      result[:rarity] = self.scarcity
      result[:usdPrice] = "$#{self.price}"
      result[:solPrice] = "$#{self.price_in_sol}"
      result[:id] = SecureRandom.uuid
      result[:image] = self.cm_image_url || self.gallery_url
      result[:video] = self.cm_video_url || self.final_url
      result[:candyMachineAddress] = self.cm_address

      result.delete(:sku)
      result.delete(:collection_id)
      result.delete(:scarcity)
      result.delete(:price)
      result.delete(:created_at)
      result.delete(:updated_at)
      result.delete(:currency)
      result.delete(:currency)
      result.delete(:school_id)
      result.delete(:price_in_sol)
      result.delete(:gallery_url)
      result.delete(:final_url)
      result.delete(:gallery_filename)
      result.delete(:final_filename)
      result.delete(:gallery_type)
      result.delete(:final_type)
      result.delete(:cm_image_url)
      result.delete(:cm_video_url)
      result.delete(:cm_address)

      result[:collection] = self.collection&.name if self.collection
      result[:conference] = self.conference.name if self.conference
      result[:school] = self.school.name if self.school
      result[:clientId] = self.clientId
    end

    if options[:only]
      result = {}
      options[:only].each {|s| result[s] = self.send(s)}
    end
    result
  end

  def self.import_from_spreadsheet_row(row, headers, drop_name=nil)

    map = {
      nft_name: :name, nft_description: :description, :"edition_/_scarcity" => :scarcity, edition_scarcity: :scarcity,
      gallery_image: :gallery_url, final_media: :final_url, gallery_image_asset: :gallery_url,
      final_media_asset: :final_url
    }

    hash = {}
    row.each_with_index do |val, idx|
      sym = headers[idx].parameterize.gsub(/[-]/, '_').to_sym
      sym = map[sym] if map[sym]
      hash[sym] = val
    end

    self.import_from_hash(hash, drop_name)
  end

  def self.import_from_hash(hash, drop_name=nil)
    if not hash[:price].blank? and hash[:price].is_a?(String)
      p = hash[:price].sub(/[$\t ]/,"").to_f rescue nil
      hash[:price] = p
    end

    if not hash[:fan_ranking_points].blank? and hash[:fan_ranking_points].is_a?(String)
      hash[:fan_ranking_points] = hash[:fan_ranking_points].gsub(/[^0-9\.]/,'').to_i rescue nil
    end

    fields = hash.slice(:name, :description, :sku, :upi, :scarcity, :gallery_url, :fan_ranking_points, :unlock, :final_url, :creator, :royalty_matrix, :legend, :sport, :award, :price, :drop_name)

    nft = Nft.where(final_url: hash[:final_url]).first_or_initialize(fields)

    if nft.errors.count > 0
      raise "#{hash[:name]} had errors!"
    else
      nft.drop_name ||= drop_name
      nft.upi = nft.upi.gsub(/[.][0-9]$/,"") if not nft.upi.blank?
      if not nft.school and not hash[:school].blank?
        nft.school = School.where(name: hash[:school]).first_or_initialize(conference: Conference.where(name: hash[:conference]).first_or_initialize)
      end
      if not nft.collection and not hash[:collection].blank?
        nft.collection = Collection.where(name: hash[:collection]).first_or_initialize
      end
    end

    (nft.save if nft) rescue debugger

    nft
  end
end
