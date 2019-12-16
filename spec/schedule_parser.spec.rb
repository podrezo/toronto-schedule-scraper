require 'minitest/autorun'
require 'nokogiri'
require 'ostruct'
require_relative '../schedule_parser'

describe ScheduleParser do
  describe Location do
    it 'Can get location ID' do
      html = Nokogiri::HTML('''
        <html>
        <div class="pfrListing" data-id="891">
          <h2><a href="/data/parks/prd/facilities/complex/891/index.html#tab=dropin">Memorial Pool and Health Club</a></h2>
          <table>
            <thead>
              <tr class="header">
                <th scope="col"> Program </th>
                <th scope="col"> Sun </th>
                <th scope="col"> Mon </th>
                <th scope="col"> Tue </th>
                <th scope="col"> Wed </th>
                <th scope="col"> Thu </th>
                <th scope="col"> Fri </th>
                <th scope="col"> Sat </th>
              </tr>
            </thead>
          </table>
        </div>
        </html>
      ''').css('div')
      result = Location.new(html)
      _(result.to_json).must_equal({
        location_id: '891',
        weeks: []
      })
    end
    it 'Will fail when headers are wrong' do
      html = Nokogiri::HTML('''
        <html>
        <div class="pfrListing" data-id="891">
          <h2><a href="/data/parks/prd/facilities/complex/891/index.html#tab=dropin">Memorial Pool and Health Club</a></h2>
          <table>
            <thead>
              <tr class="header">
                <th scope="col"> Program </th>
                <th scope="col"> Sun </th>
                <th scope="col"> Mon </th>
                <th scope="col"> Tues </th>
                <th scope="col"> Wed </th>
                <th scope="col"> Thu </th>
                <th scope="col"> Fri </th>
                <th scope="col"> Sat </th>
              </tr>
            </thead>
          </table>
        </div>
        </html>
      ''').css('div')
      _(-> { Location.new(html) }).must_raise UnexpectedHtmlContentException
    end
  end

  describe Week do
    it 'Can get the week start date correctly' do
      html = Nokogiri::HTML('''
        <tr>
          <td scope="row" data-info="Program">
            <div class="coursenamemobiletable"><strong>Width Swim - Older Adult</strong> (60 yrs +)</div>
            <strong>Jan 3 to Jan 9 </strong>
          </td>
          <td data-info="Sun"> &nbsp; </td>
          <td data-info="Mon"> &nbsp; </td>
          <td data-info="Tue"> &nbsp; </td>
          <td data-info="Wed"> &nbsp; </td>
          <td data-info="Thu"> &nbsp; </td>
          <td data-info="Fri"> &nbsp; </td>
          <td data-info="Sat"> &nbsp; </td>
        </tr>
      ''').css('tr')
      Time.stub :now, Time.parse('2020-12-26 00:00:00 -0500') do
        result = Week.new(html)
        _(result.to_json).must_equal({
          program_identifer: 'Width Swim - Older Adult',
          week_start: Time.parse('2021-01-03 00:00:00 -0500'),
          days: []
        })
      end
    end

    it 'Will be invalid if the week does not start on Sunday' do
      html = Nokogiri::HTML('''
        <tr>
          <td scope="row" data-info="Program">
            <div class="coursenamemobiletable"><strong>Width Swim - Older Adult</strong> (60 yrs +)</div>
            <strong>Jan 4 to Jan 10 </strong>
          </td>
          <td data-info="Sun"></td>
          <td data-info="Mon"></td>
          <td data-info="Tue"></td>
          <td data-info="Wed"></td>
          <td data-info="Thu"></td>
          <td data-info="Fri"></td>
          <td data-info="Sat"></td>
        </tr>
      ''').css('tr')
      Time.stub :now, Time.parse('2020-12-26 00:00:00 -0500') do
        _(-> { Week.new(html) }).must_raise UnexpectedHtmlContentException
      end
    end

    it 'Will be invalid if the days of the headers are wrong' do
      html = Nokogiri::HTML('''
        <tr>
          <td scope="row" data-info="Prograaam">
            <div class="coursenamemobiletable"><strong>Width Swim - Older Adult</strong> (60 yrs +)</div>
            <strong>Jan 3 to Jan 9 </strong>
          </td>
          <td data-info="Sun"></td>
          <td data-info="Mon"></td>
          <td data-info="Tue"></td>
          <td data-info="Wed"></td>
          <td data-info="Thu"></td>
          <td data-info="Fri"></td>
          <td data-info="Sat"></td>
        </tr>
      ''').css('tr')
      Time.stub :now, Time.parse('2020-12-26 00:00:00 -0500') do
        _(-> { Week.new(html) }).must_raise UnexpectedHtmlContentException
      end
    end
  end

  describe Day do
    it 'Will fail if the day does not have valid day of week in data-info' do
      html = Nokogiri::HTML('<td data-info="Xyz">8 - 8:55am</td>').css('td')
      _(-> { Day.new(html, Time.parse('September 6 2015')) }).must_raise StandardError
    end

    it 'Will produce nil when there are no times' do
      html = Nokogiri::HTML('<td data-info="Tue"> &nbsp; </td>').css('td')
      
      TimeRange.stub :new, OpenStruct.new(to_json: true)   do
        result = Day.new(html, Time.parse('July 1 2015'))
        assert_nil(result.to_json)
      end
    end

    it 'Can identify single time' do
      html = Nokogiri::HTML('<td data-info="Tue">8 - 8:55am</td>').css('td')
      
      TimeRange.stub :new, OpenStruct.new(to_json: true)   do
        result = Day.new(html, Time.parse('July 1 2015'))
        _(result.to_json).must_equal({
          times: [true]
        })
      end
    end
    it 'Can identify two times' do
      html = Nokogiri::HTML('<td data-info="Mon">3:15 - 3:55pm<br />8:15 - 9:10pm</td>').css('td')
      
      TimeRange.stub :new, OpenStruct.new(to_json: true)   do
        result = Day.new(html, Time.parse('July 1 2015'))
        _(result.to_json).must_equal({
          times: [true, true]
        })
      end
    end
    it 'Can identify three times' do
      html = Nokogiri::HTML('<td data-info="Mon">3:15 - 3:55pm<br />8:15 - 9:10pm<br />10:00pm - 11:00pm</td>').css('td')
      
      TimeRange.stub :new, OpenStruct.new(to_json: true)   do
        result = Day.new(html, Time.parse('July 1 2015'))
        _(result.to_json).must_equal({
          times: [true, true, true]
        })
      end
    end
  end

  describe TimeRange do
    it 'Can parse AM to AM' do
      result = TimeRange.new('8 - 8:55am', Time.parse('July 1 2015'))
      _(result.to_json).must_equal({
        from: Time.parse('2015-07-01 8:00:00 -0400'),
        to: Time.parse('2015-07-01 8:55:00 -0400')
      })
    end

    it 'Can parse PM to PM' do
      result = TimeRange.new('3:15 - 3:55pm', Time.parse('July 1 2015'))
      _(result.to_json).must_equal({
        from: Time.parse('2015-07-01 15:15:00 -0400'),
        to: Time.parse('2015-07-01 15:55:00 -0400')
      })
    end

    it 'Can parse AM to PM' do
      result = TimeRange.new('11:40am - 12:30pm', Time.parse('July 1 2015'))
      _(result.to_json).must_equal({
        from: Time.parse('2015-07-01 11:40:00 -0400'),
        to: Time.parse('2015-07-01 12:30:00 -0400')
      })
    end
  end
end