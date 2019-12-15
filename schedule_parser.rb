require 'rubygems'
require 'time'
require 'date'
require 'nokogiri'
require 'open-uri'

class ScheduleParser
  def self.parse_swim_times(url)
    doc = Nokogiri::HTML(open(url))
    locations = doc.css('.pfrProgramDescrList .pfrListing').map do |location_html|
      Location.new(location_html)
    end
  end
end

class UnexpectedHtmlContentException < StandardError
  def initialize(parser_step="custom", html="This is a custom exception")
    @parser_step = parser_step
    super(html)
  end
end

class Location
  def initialize(html)
    @html = html
    raise UnexpectedHtmlContentException.new('location',html) unless valid?
    @location_id = html.attribute('data-id').value
    @weeks = html.css('table tbody tr').map do |week_html|
      Week.new(week_html)
    end
  end
  
  def valid?
    headings = @html.css('table thead tr th').map do |heading|
      heading.text.strip
    end
    headings == ['Program', 'Sun', 'Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat']
  end

  def to_json
    {
      location_id: @location_id,
      weeks: @weeks.map(&:to_json)
    }
  end
end

class Week
  def initialize(html)
    @html = html
    raise UnexpectedHtmlContentException.new('week',html) unless valid_header?
    @program_identifer = html.css('td').first.css('div strong').text.strip
    # The gsub is necessary because sometimes the words are broken up inside with newlines
    week_identifier = html.css('td').first.css('> strong').text.strip.gsub(/\s+/, ' ')
    from_date = week_identifier.match(/^[A-Z][a-z]{2} \d{1,2}/)[0]
    # If the date specified is more than 3 months in the past, it can be assumed to be for the next year
    if (Time.now - Time.parse(from_date)) > 60*60*24*7*4*3
      @week_start = Time.parse("#{from_date} #{Time.now.year+1}")
    else
      @week_start = Time.parse("#{from_date}")
    end
    raise UnexpectedHtmlContentException.new('week',html) unless valid_week_start?
    @days = html.css('td')[1..7].each_with_index.map do |day_html, index|
      # For each day offset from Sunday, add a day to the "week_start" so we know what day this is
      seconds_to_add = index * 60*60*24
      Day.new(day_html, @week_start + seconds_to_add)
    end
  end

  def valid_header?
    columns = @html.css('td').map do |column|
      column.attribute('data-info').value
    end
    columns == ['Program', 'Sun', 'Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat']
  end
  def valid_week_start?
    # Because every table starts at sunday, we expect the date range specified to always begin on a Sunday
    @week_start.strftime("%w") == "0"
  end

  def to_json
    {
      program_identifer: @program_identifer,
      week_start: @week_start,
      days: @days.map(&:to_json).compact
    }
  end
end

class Day
  def initialize(html, date)
    @html = html
    @date = date
    @has_time = @html.text.match(/[0-9]/)
    raise UnexpectedHtmlContentException.new('day',html) unless valid?
    @times = html.children.select do |node|
      node.is_a? Nokogiri::XML::Text
    end
    .map(&:text)
    .map do |time_range_string|
      TimeRange.new(time_range_string, @date)
    end
  end
  
  def valid?
    ['Sun', 'Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat'].include?(@html.attribute('data-info').value)
  end

  def to_json
    return nil unless @has_time
    {
      times: @times.map(&:to_json)
    }
  end
end

class TimeRange
  TIME_RANGE_REGEXP = /(\d{1,2})(:(\d{1,2}))?(am|pm)? - (\d{1,2})(:(\d{1,2}))?(am|pm)?/
  def initialize(range_string, date)
    @range_string = range_string
    raise UnexpectedHtmlContentException.new('location',html) unless valid?
    normalized_times = TimeRange.normalize_times(range_string)
    @from = TimeRange.add_hours_to_date(normalized_times[0], date)
    @to = TimeRange.add_hours_to_date(normalized_times[1], date)
  end
  
  def valid?
    @range_string.match(TIME_RANGE_REGEXP)
  end

  # Take a time range string and convert it to an array of two normalized times
  # Example: normalize_times('6-8pm') # oututs ['6:00pm', '8:00pm']
  def self.normalize_times(time_range)
    regexp_match = TIME_RANGE_REGEXP.match(time_range)
    raise "input string '#{input}' is not in correct format" if regexp_match.nil?
    from_hr = regexp_match[1]
    from_min = regexp_match[3] || '00'
    from_ampm = regexp_match[4]
    to_hr = regexp_match[5]
    to_min = regexp_match[7] || '00'
    to_ampm = regexp_match[8]

    from_ampm ||= to_ampm
    to_ampm ||= from_ampm

    ["#{from_hr}:#{from_min}#{from_ampm}", "#{to_hr}:#{to_min}#{to_ampm}"]
  end

  def self.add_hours_to_date(hours, date)
    date_string = date.strftime('%Y-%m-%d')
    Time.parse("#{date_string} #{hours}")
  end

  def to_json
    {
      from: @from,
      to: @to
    }
  end
end