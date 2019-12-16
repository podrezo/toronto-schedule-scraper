#!/bin/bash
tmp_dir=$(mktemp -d -t toronto_schedule_scraper-XXXXXXXXXX)
echo $tmp_dir
cp -r .bundle index.rb schedule_parser.rb Gemfile Gemfile.lock $tmp_dir
zip_file=$(mktemp -t toronto_schedule_scraper-XXXXXXXXXX.zip --dry-run)

docker run -it --rm -v "$tmp_dir":/var/task lambci/lambda:build-ruby2.5 bundle install --without=development
pushd $tmp_dir
zip $zip_file -r .
popd
aws lambda update-function-code \
    --function-name arn:aws:lambda:us-east-1:234147186957:function:TorontoScheduleScraper \
    --zip-file "fileb://$zip_file" \
    --region us-east-1
