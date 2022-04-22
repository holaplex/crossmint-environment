# README

Manage metadata and assets for creating NFT drops.  This is like a scripting environment for NFTs.
Normally, you start with CSV files that other people give you.  Then you use a series of rake tasks to:
* load metadata about NFTs into the database
* load information about purchasers into the database
* pull physical assets from whereever they live into local storage
* print out metadata JSON about the NFTs
* print out CandyMachine configs for the NFTs
* add watermarks to files?

```bash
convert app/assets/images/watermark.png -background "rgba(0,0,0,0)"  -rotate 335 -resize '160%'  -alpha set -background none -channel A -evaluate multiply 0.4 +channel app/assets/images/watermark-45.png

fmpeg -i test.mp4 -i app/assets/images/watermark-45.png -filter_complex "overlay=-350:-300" test-wm.mp4

for file in *.mp4; do ffmpeg -i $file -i ../../app/assets/images/watermark-45.png -filter_complex "overlay=-350:-300" $(basename $file .mp4)-wm.mp4; done
```



# Get Started
```
./start-developing
docker compose up -d db
./start-developing
```

# What you need before you start
You're going to need Ruby 2.7.5 at least.  I recommend `rbenv`

## OS-X Prerequisites
```
brew install rbenv
rbenv install 2.7.5
```

You're going to need `libmagic`:
```
brew install libmagic
```

That's all.

## Ubuntu Prerequisites
I can't remember right now how to install rbenv on linux, but it isn't hard.

# Normal Usage



## Do a "Remint"

You need a CSV file with the "right" headers.


First order of business - move CSV data into database.

```
bundle exec rake import:accounts ../OG-ACCOUNTS/accounts.csv
```

Second, import information about NFTs

```
bundle exec rake import:purchased ../OG-ACCOUNTS/purchased.csv
```

Great, now get all of the files that are referenced by the NFTs.  When you first run this command, a URL will be printed on the screen, and instructions for how you should authorize in order to get an authorization token back.  Paste the URL into a browser, and then you should be redirected to something that doesn't work, but has the auth code in it.  You copy and past that back, and then you shouldn't need to reauthorize for quite a while.

```
bundle exec rake import:assets
```

Now that all of the data is there, print the json file that goes with it.  Put it in the format that Crossmint asked for:

A google drive with:
* N image files (each with a unique name or number)
* N JSONs in the metaplex metadata standard (matching the name of the image files)
* A JSON file containing an array of objects containing an 'email' and 'nft_name' property. Because users may have multiple NFTs, the same 'email' field can appear in multiple entries in this object. Same goes for 'nft_name', as I understand some NFTs are repeated

With that we'll create the appropriate NFTs, store them in user wallets, and later on give you a JSON file that maps emails to SOL wallets (edited).

```
bundle exec rake export:crossmint
```

