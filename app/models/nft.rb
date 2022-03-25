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
    candidate ||= self.where("final_url LIKE :ident", ident: "%#{thing}%").first
    candidate ||= self.where("gallery_url LIKE :ident", ident: "%#{thing}%").first
    candidate ||= self.where(name: thing).first
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
        name: self.collection.name,
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

  def candymachine_config

    result = {
      price: self.get_sol_price,
      number: self.scarcity,
      gatekeeper: nil,
      solTreasuryAccount: "2YZwtDSEeu3Tnmh6bbPwWWXJywTX9jGW6jbb1Sn2Z9Pj",
      goLiveDate: "25 Mar 2022 16:00:00 GMT",
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

  def write_candymachine_config(options={force: false})
    result = true
    
    if not File.exists?(self.candymachine_config_filename) or options[:force]
      result = File.write(self.candymachine_config_filename, JSON.pretty_generate(self.candymachine_config))
    end

    result
  end

  def get_sol_price
    uri = URI("https://api.binance.com/api/v3/ticker/price")
    params = { symbol: "SOLUSDT" }
    uri.query = URI.encode_www_form(params)
    res = Net::HTTP.get_response(uri)
    hash = JSON.parse(res.body) if res.is_a?(Net::HTTPSuccess)
    sol_price = hash['price'].to_f if hash
    if sol_price
      (self.price / sol_price).round(2)
    else
      0.0
    end
  end

  def as_json(options={})
    result = super
    if options[:only]
      result = {}
      options[:only].each {|s| result[s] = self.send(s)}
    end
    result
  end
end
