#  Churnometer - A dashboard for exploring a membership organisations turn-over/churn
#  Copyright (C) 2012-2013 Lucas Rohde (freeChange)
#  lukerohde@gmail.com
#
#  Churnometer is free software: you can redistribute it and/or modify
#  it under the terms of the GNU Affero General Public License as published by
#  the Free Software Foundation, either version 3 of the License, or
#  (at your option) any later version.
#
#  Churnometer is distributed in the hope that it will be useful,
#  but WITHOUT ANY WARRANTY; without even the implied warranty of
#  MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
#  GNU Affero General Public License for more details.
#
#  You should have received a copy of the GNU Affero General Public License
#  along with Churnometer.  If not, see <http://www.gnu.org/licenses/>.

require 'spreadsheet'

module ChurnPresenter_Helpers
  include Rack::Utils
  alias_method :h, :escape_html # needed for build_url - refactor

  # common totals
  def paying_start_total
    # group_by is used so only the first row of running total is summed
    t=0
    @request.data.group_by{ |row| row['row_header1'] }.each do | row, v |
      t += v[0]['paying_start_count'].to_i
    end
    t
  end

  def paying_end_total
    # group_by is used so only the first row of running totals is summed
    t=0
    @request.data.group_by{ |row| row['row_header1'] }.each do | row, v |
      t += v[v.count-1]['paying_end_count'].to_i
    end
    t
  end

  def paying_a1p_start_total
    t=0
    @request.data.group_by{ |row| row['row_header1'] }.each do | row, v |
      t += (v[0]['paying_start_count'].to_i + v[0]['a1p_start_count'].to_i)
    end
    t
  end

  def paying_a1p_end_total
    # group_by is used so only the first row of running totals is summed
    t=0
    @request.data.group_by{ |row| row['row_header1'] }.each do | row, v |
      t += (v[v.count - 1]['paying_end_count'].to_i + v[v.count - 1]['a1p_end_count'].to_i)
    end
    t
  end

  def member_start_total
    t = 0
    @request.data.group_by { |row| row['row_header1'] }.each do |row, v|
      t += v[0]['member_start_count'].to_i
    end

    t
  end

  def member_end_total
    t = 0
    @request.data.group_by { |row| row['row_header1'] }.each do |row, v|
      t += v[0]['member_end_count'].to_i
    end

    t
  end

  def paying_transfers_total
    # group_by is used so only the first row of running totals is summed
    t=0
    @request.data.group_by{ |row| row['row_header1'] }.each do | row, v |
      t += v[0]['paying_other_gain'].to_i + v[0]['paying_other_loss'].to_i
    end
    t
  end



  # common drill downs

  def drill_down_header(row, churnometer_app)
    groupby_column_id = @request.groupby_column_id

    {
      "#{Filter}[#{groupby_column_id}]" => row['row_header1_id'],
      "group_by" => @app.next_drilldown_dimension(@request.groupby_dimension).id
    }
  end

  def build_url(query_hashes)
    #TODO refactor out params if possible, or put this function somewhere better, with params maybe

    # build uri from params - rejecting filters & lock because they need special treatment
    query = @request.parsed_params.reject{ |k,v| v.empty? }.reject{ |k, v| k == Filter}.reject{ |k, v| k == "lock"}

    # flatten filters, rejecting status - TODO get rid of status
    (@request.parsed_params[Filter] || {}).reject{ |k,v| v.empty? }.reject{ |k,v| k == 'status'}.each do |k, vs|
      Array(vs).each_with_index do |v, x|
        if (query_hashes || {}).has_key?("#{Filter}[#{k}]")
          if v != query_hashes["#{Filter}[#{k}]"]
            # when drilling down, disable any item of the same filter type with a different value
            query["#{Filter}!#{x}[#{k}]"] = '-' + v
          else
            # when drilling down, remove any item of the same filter type and value because it'll be merged back later
          end

        else
          query["#{Filter}!#{x}[#{k}]"] = v
        end
      end
    end

    # flatten lock
    (@request.parsed_params["lock"] || {}).reject{ |k,v| v.empty? }.each do |k, v|
      query["lock[#{k}]"] = v
    end

    # merge new items
    query.merge! (query_hashes || {})

    # remove any empty/blanked-out items
    query = query.reject{ |k,v| v.nil? }

    # make uri string
    uri = '/?'
    query.each do |key, value|
      uri += "&#{h key}=#{h value}"
    end

    uri.sub('/?&', '?')
  end

  def format_date(date)
    if date.nil? || date == '1900-01-01'
      ''
    else
      Date.parse(date).strftime(DateFormatDisplay)
    end
  end

  # exporting - expects an array of hash
  def excel(data)
     # todo refactor this and ChurnPresenter_table.to_excel - consider common table format
     book = Spreadsheet::Excel::Workbook.new
     sheet = book.create_worksheet

     # Add header
     data[0].each_with_index do |hash, x|
       sheet[0, x] = (col_names[hash.first] || hash.first)
     end

     # Add data
     data.each_with_index do |row, y|
       row.each_with_index do |hash,x|
         if filter_columns.include?(hash.last)
           sheet[y + 1, x] = hash.last.to_f
         else
           sheet[y + 1, x] = hash.last
         end
       end
     end

     path = "tmp/data.xls"
     book.write path

     path
   end

   def browser
    user_agent =  request.env['HTTP_USER_AGENT'].downcase

    @browser ||= begin
      if user_agent.index('msie') && !user_agent.index('opera') && !user_agent.index('webtv')
        'ie'+user_agent[user_agent.index('msie')+5].chr
      elsif user_agent.index('gecko/')
          'gecko'
      elsif user_agent.index('opera')
          'opera'
      elsif user_agent.index('konqueror')
          'konqueror'
      elsif user_agent.index('ipod')
          'ipod'
      elsif user_agent.index('ipad')
          'ipad'
      elsif user_agent.index('iphone')
          'iphone'
      elsif user_agent.index('chrome/')
          'chrome'
      elsif user_agent.index('applewebkit/')
          'safari'
      elsif user_agent.index('googlebot/')
          'googlebot'
      elsif user_agent.index('msnbot')
          'msnbot'
      elsif user_agent.index('yahoo! slurp')
          'yahoobot'
      #Everything thinks it's mozilla, so this goes last
      elsif user_agent.index('mozilla/')
          'gecko'
      else
          'unknown'
      end
    end

    return @browser
  end
end
