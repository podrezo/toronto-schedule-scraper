#!/bin/bash
TMP_FILE=/tmp/toronto_schedule_scraper.zip

rm "$TMP_FILE"
docker run -it --rm -v "$PWD":/var/task lambci/lambda:build-ruby2.5 bundle install
zip "$TMP_FILE" -r .
aws lambda update-function-code \
    --function-name arn:aws:lambda:us-east-1:234147186957:function:TorontoScheduleScraper \
    --zip-file "fileb://$TMP_FILE" \
    --region us-east-1
