# campus.rake: -*- Ruby -*-  DESCRIPTIVE TEXT.
# 
#  Copyright (c) 2022 Brian J. Fox Opus Logica, Inc.
#  Author: Brian J. Fox (bfox@opuslogica.com)
#  Birthdate: Mon May 16 10:32:36 2022.
namespace :campus do
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

  desc "Build watermarked versions of the FINAL image/movie for the mentioned drop"
  task watermark: :environment do
    # Overcome the shitty limitations of rake and rails.
    ARGV.each { |a| task a.to_sym do ; end }

    # If there is an argument, it is a Drop Name.
    if ARGV[1].blank?
      base = Nft.all
    else
      base = Nft.where(drop_name: ARGV[1])
    end

    base.each do |nft|
      marker = "w" 
      if not nft.has_watermark?
        marker = "W"
        nft.make_watermark
      end
      count_it(marker)
    end
  end
end
