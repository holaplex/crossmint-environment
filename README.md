# README

```
./start-developing
docker compose up -d db
./start-developing
```

first
  *  order of business - move CSV data into database.

```
bundle exec rake import:accounts ../OG-ACCOUNTS/accounts.csv
```

Next, import information about NFTs

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

