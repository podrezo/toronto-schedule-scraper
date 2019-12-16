require 'json'
require_relative 'schedule_parser'
path = File.expand_path('../spec/leisure.html', __FILE__)
# schedule = ScheduleParser.parse_swim_times('https://www.toronto.ca/data/parks/prd/swimming/dropin/leisure/index.html')
begin
  schedule = ScheduleParser.parse_swim_times(path)
  puts JSON.pretty_generate(schedule)
rescue UnexpectedHtmlContentException => e
  p e.message
end