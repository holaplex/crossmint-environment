require "google/apis/drive_v3"
require "googleauth"
require "googleauth/stores/file_token_store"
require "fileutils"

class Nft < ApplicationRecord
  belongs_to :collection, optional: true
  belongs_to :school, optional: true
  has_many :owned_nfts
  has_many :owners, through: :owned_nfts, source: :account
  has_one :conference, through: :school
  @@google_drive = nil

  def self.lookup(thing)
    candidate = self.where("final_url LIKE :ident", ident: "%#{thing}%").first
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
    if not File.exists?(options[:file]) or options[:force]
      identifier = get_identifier(options[:url])
      get_drive_file(identifier, options[:file])
      self.save
    end
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

  def metadata_filename
    "#{ENV['NFT_ASSETS_DIR']}/images/#{self.sku || get_identifier(source_url)}.json"
  end

  def metadata
    result = {
      name: self.name,
      symbol: "CLHP",
      description: self.description,
      seller_fee_basis_points: 1000,
      image: self.gallery_filename,
      animation_url: self.final_filename,
      external_url: "https://campuslegends.com/",
      attributes: [],
      collection: {
        name: self.collection.name,
        family: "Campus Legends"
      },
      properties: {
        files: [
          {
            file: self.final_filename,
            uri: self.final_url,
            type: "video/mp4"
          },
          {
            file: self.gallery_filename,
            uri: self.gallery_url,
            type: "image/jpeg"
          }
        ],
        category: "video",
        creators: [
          {
            share: 100,
            address: "C3nPuV9Js259Cyue6ptyR8xUTdRWFXRTntQCBJjFxTcm"
          }
        ]
      }
    }

    result
  end

  def write_metadata(options={force: false})
    result = true

    if not File.exists?(self.metadata_filename) or options[:force]
      File.write(self.metadata_filename, JSON.pretty_generate(self.metadata))
    end

    result
  end

end
