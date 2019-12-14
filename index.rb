require 'json'
require 'nokogiri'

def scrape_schedule(event:, context:)
    { statusCode: 200, body: JSON.generate({ hello: "world" }) }
end