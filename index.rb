require 'json'
require_relative 'schedule_parser'

def scrape_schedule(event:, context:)
  body = JSON.parse(event['body'])
  return { statusCode: 400, body: 'Invalid URL' } if body['url'].nil?
  schedule = ScheduleParser.parse_swim_times(body['url'])
  { statusCode: 200, body: JSON.generate(schedule) }
end