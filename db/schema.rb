# This file is auto-generated from the current state of the database. Instead
# of editing this file, please use the migrations feature of Active Record to
# incrementally modify your database, and then regenerate this schema definition.
#
# This file is the source Rails uses to define your schema when running `bin/rails
# db:schema:load`. When creating a new database, `bin/rails db:schema:load` tends to
# be faster and is potentially less error prone than running all of your
# migrations from scratch. Old migrations may fail to apply correctly if those
# migrations use external dependencies or application code.
#
# It's strongly recommended that you check this file into your version control system.

ActiveRecord::Schema[7.0].define(version: 2022_03_25_194632) do
  # These are extensions that must be enabled in order to support this database
  enable_extension "plpgsql"

  create_table "accounts", force: :cascade do |t|
    t.string "shopify_number"
    t.string "account_number"
    t.string "email"
    t.string "first_name"
    t.string "last_name"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
  end

  create_table "collections", force: :cascade do |t|
    t.string "name"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
  end

  create_table "conferences", force: :cascade do |t|
    t.string "name"
    t.string "long_name"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
  end

  create_table "nfts", force: :cascade do |t|
    t.string "name"
    t.string "description"
    t.string "sku"
    t.integer "scarcity"
    t.bigint "collection_id"
    t.string "gallery_url"
    t.string "gallery_filename"
    t.string "final_url"
    t.string "final_filename"
    t.string "creator"
    t.integer "royalty_matrix"
    t.string "legend"
    t.bigint "school_id"
    t.string "sport"
    t.string "award"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.integer "fan_ranking_points", default: 0
    t.float "price", default: 0.0
    t.string "currency", default: "USD"
    t.string "upi"
    t.string "unlock"
    t.string "drop_name"
    t.string "gallery_type"
    t.string "final_type"
    t.string "cm_address"
    t.string "cm_image_url"
    t.string "cm_video_url"
    t.string "clientId"
    t.index ["collection_id"], name: "index_nfts_on_collection_id"
    t.index ["school_id"], name: "index_nfts_on_school_id"
  end

  create_table "owned_nfts", force: :cascade do |t|
    t.bigint "account_id", null: false
    t.bigint "nft_id", null: false
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["account_id"], name: "index_owned_nfts_on_account_id"
    t.index ["nft_id"], name: "index_owned_nfts_on_nft_id"
  end

  create_table "schools", force: :cascade do |t|
    t.string "name"
    t.bigint "conference_id", null: false
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["conference_id"], name: "index_schools_on_conference_id"
  end

  add_foreign_key "nfts", "collections"
  add_foreign_key "nfts", "schools"
  add_foreign_key "owned_nfts", "accounts"
  add_foreign_key "owned_nfts", "nfts"
  add_foreign_key "schools", "conferences"
end
