module Helpers
  def query_string
    URI.parse(request.url).query
  end

  def get_display_text(column, id)
    t = "error!"
    
    if id == "unassigned" 
      t = "unassigned"
    else
      val = db.ex(data_sql.get_display_text_sql(column,id.sub('!','').sub('-','')))
      
      if val.count != 0 
        t = val[0]['displaytext']
      end
    end 
    
    t
  end

  def get_transfers
    db.ex(data_sql.transfer_sql(leader?))
  end
  
  def filter_columns 
    %w{
      a1p_real_gain 
      a1p_unchanged_gain
      a1p_real_loss 
      a1p_other_gain 
      a1p_other_loss 
      paying_real_gain 
      paying_real_loss 
      paying_other_gain 
      paying_other_loss 
      other_other_gain 
      other_other_loss
      a1p_newjoin
      a1p_rejoin
      a1p_to_other
      a1p_to_paying
      paying_real_net
      other_gain
      other_loss
      a1p_end_count
      a1p_start_count
      paying_end_count
      paying_start_count
      stopped_start_count
      stopped_real_gain
      stopped_unchanged_gain
      stopped_real_loss
      stopped_to_paying
      stopped_to_other
      stopped_other_gain
      stopped_end_count
      stopped_other_loss
      contributors
      income_net
      posted
      unposted
      }
  end

  def can_detail_cell?(column_name, value)
    (
      filter_columns.include? column_name
    ) && (value.to_i != 0 && value.to_i.abs < 500)
  end

  def can_export_cell?(column_name, value)
    (
      filter_columns.include? column_name
    ) && (value.to_i != 0)
  end
  
  def export_cell(row, column_name)
    export_column(column_name) + drill_down_cell(row)
  end
  
  def detail_cell(row, column_name)
    detail_column(column_name) + drill_down_cell(row)
  end
  
  def export_column(column_name)
    column_filter = "column=#{column_name}"
    
    "/export_member_details?#{query_string}&#{column_filter}&table=#{member_tables.first.first}"
  end
  
  def detail_column(column_name)
    column_filter = "column=#{column_name}"
    
    "/?#{query_string}&#{column_filter}"
  end

   def drill_down_cell(row)
     row_filter = h "#{Filter}[#{(params['group_by'] || 'branchid')}]=#{row['row_header1_id']}"
     
     "&" + row_filter  + "&" + (row_interval(row))
   end
   
  def row_interval(row)
    row_interval = ""

    if data_sql.query["interval"] != "none" 
      row_interval = "&intervalStart=#{row['period_start']}&intervalEnd=#{row['period_end']}"
    end

    row_interval
  end
       
  
    
  def bold_col?(column_name)
    [
      'paying_real_net',
      'running_paying_net',
      'a1p_real_gain'
    ].include?(column_name)
  end
  
  def tables
    params['column'].to_s == '' ? summary_tables : member_tables
  end

 def summary_tables
    hash = {
      'Summary' => [
        'row_header',
        'row_header1',
        'period_header',
        'a1p_real_gain',
        'a1p_to_other',
        'paying_start_count',
        'paying_real_gain',
        'paying_real_loss',
        'paying_real_net',
        'running_paying_net',
        'paying_end_count',
        (leader? ? 'contributors' : ''), 
        (leader? ? 'income_net' : '')
        ],
      'Paying' => [
        'row_header',
        'row_header1',
        'period_header',
        'paying_start_count',
        'paying_real_gain',
        'paying_real_loss',
        'paying_other_gain',
        'paying_other_loss',
        'paying_end_count',
        'paying_net'
        ] ,
      'A1p' => [
        'row_header',
        'row_header1',
        'period_header',
        'a1p_start_count',
        'a1p_newjoin',
        'a1p_rejoin',
        'a1p_real_gain',
        'a1p_unchanged_gain',
        'a1p_to_other',
        'a1p_to_paying',
        'a1p_other_gain',
        'a1p_other_loss',
        'a1p_end_count',
        'a1p_net'
        ],
      }
      shash = {
        'Stopped' =>
        [
        'row_header', 
        'row_header1', 
        'period_header',
        'stopped_start_count',
        'stopped_real_gain',
        'stopped_unchanged_gain',
        'stopped_to_other',
        'stopped_to_paying',
        'stopped_other_gain',
        'stopped_other_loss',
        'stopped_end_count'
        ]
      }
      
      shash2 = {
        'Status Updates' =>
        [
        'row_header', 
        'row_header1', 
        'period_header',
        'a1p_real_gain',
        'a1p_unchanged_gain',
        'a1p_to_other',
        'a1p_to_paying',
        'stopped_real_gain',
        'stopped_unchanged_gain',
        'stopped_to_other',
        'stopped_to_paying'
        ]
      }
      
      fhash = {
        'Financial' => 
          [
          'row_header',
          'row_header1',
          'period_header',
          'posted',
          'unposted',
          'income_net',
          'contributors',
          'annualisedavgcontribution'
          ]
    }
    if leader?
      hash = hash.merge(fhash);
    end
    
    if staff?
      hash = hash.merge(shash);
      if data_sql.query['group_by'] == 'statusstaffid' 
        hash = shash2
      end
    end
    
    hash
  end
 
  def member_tables
     hash = {
       'Member Summary' => [
         'row_header',
         'row_header1',
         'row_header2',
         'changedate',
         'member',
         'contactdetail',
         'oldstatus',
         'newstatus',
         'currentstatus',
         'oldcompany',
         'newcompany',
         'currentcompany'
         ], 
       'Organiser' => [
          'row_header',
          'row_header1',
          'row_header2',
          'changedate',
          'member',
          'oldorg',
          'neworg',
          'currentorg',
          'oldlead',
          'newlead',
          'currentlead'
          ]
     }
     
     fhash = {
       'Financial' => 
         [
         'row_header',
         'row_header1',
         'row_header2',
         'member',
         'posted',
         'unposted'
         ]
       }
       if leader?
         hash = hash.merge(fhash);
       end
   
       hash
   end
  
  def merge_cols(row, cols)
    row.reject{ |k | !cols.include?(k)  }.sort{ |a,b| cols.index(a[0]) <=> cols.index(b[0]) }
  end
  
  def tips
    {
      'paying_real_net' => "The number of members whose status became 'paying' during the period minus those that lost the 'paying' status", 
      'paying_end_count' => "The number of members with the 'paying' status at the end of the period.  '#{col_names['paying_end_count']}' is equal to '#{col_names['paying_start_count']}' plus '#{col_names['paying_real_gain']}' minus '#{col_names['paying_real_loss']}' plus '#{col_names['paying_other_gain']}' minus '#{col_names['paying_other_loss']}'.",
      'a1p_real_gain' => "The number of people who became 'awaiting first payment' during the period.  Most of these are new joiners (see '#{col_names['a1p_newjoin']}') but some may have already been members or become 'awaiting first payment' for administrative reasons (see '#{col_names['a1p_rejoin']}') .",
      'a1p_to_other' => "The number of 'awaiting first payment' members who were removed from the database during the period.",
      'paying_start_count' => "The number of members with the 'paying' status at the beginning of the period.",
      'paying_real_gain' => "The number of members whose status become 'paying' during the period.",
      'paying_real_loss' => "The number of members whose status ceased to be 'paying' during the period.",
      'income_net' => 'The amount of money posted against members by support staff during the period (without regard to the period the payment was remitted for).',
      'contributors' => 'The number of unique members to have contributed dues during the period.',
      'running_paying_net' => "The running total of '#{col_names['paying_real_net']}'.  Be careful to sort by the row header then '#{col_names['period_header']}' (the default sort) otherwise this column won't make sense.",
      'period_header' => "The intervals dividing '#{col_names['start_date']}' and '#{col_names['end_date']}' as selected by the user.  Beware that if '#{col_names['start_date']}' or '#{col_names['end_date']}' don't align to standard interval boundaries, the first or last interval will be shorter in duration.",
      'paying_other_gain' => "The number of paying members gained without involving a member status change and without affecting the union's bottom line.  e.g. transfers of sites between organisers. ",
      'paying_other_loss' => "The number of paying members lost without involving a member status change and without affecting the union's bottom line.  e.g. transfers of sites between organisers. ",
      'a1p_start_count' => "The number of members with the 'awaiting first payment' status at the beginning of the period.",
      'a1p_end_count' => "The number of members with the 'awaiting first payment' status at the end of the period.",
      'a1p_newjoin' => "The number of members who became 'awaiting first payment' during the period who have never been a member before.",
      'a1p_rejoin' => "The number of members who became 'awaiting first payment' during the period who have been a member before.",
      'a1p_to_paying' => "The number of members who stopped being 'awaiting first payment' during the period because they started paying.",
      'a1p_other_gain' => "The number of 'awaiting first payment' members gained without involving a member status change and without affecting the union's bottom line.  e.g. transfers of sites between organisers. ",
      'a1p_other_loss' => "The number of 'awaiting first payment' members lost without involving a member status change and without affecting the union's bottom line.  e.g. transfers of sites between organisers. ",
      'posted'  => "The amount of money posted to members during the period, including money reposted because of corrections (see '#{col_names['unposted']}).  NB corrections are applied to the period for which they money belongs in order to ensure historical consistency.",
      'unposted' => "The amount of money deducted during the period, usually because of undoing a payment.  Be aware that when an undone payment is reposted, the amount will appear in '#{col_names['posted']}'.",
      'annualisedavgcontribution' => "The total amount of money posted during the period, divided by the number of unique contributors, scaled to make the period equivalent to a year.  NB If, for any reason, money isn't received for a large portion of members for a large portion of the period, this figure will be low.  e.g.  Members were redistributed (think area changes) or reclassified (think industry changes) mid way through the period.",
      'stopped_start_count' => 'The number of members with the stopped paying status at the start of the period.', 
      'stopped_end_count' => 'The number of members with the stopped paying status at the end of the period.',
      'stopped_real_gain' => 'The number of members who changed to the stopped paying status during the period.',
      'stopped_real_loss' => 'The number of members who changed from the stopped paying status to something else during the period.',
      'stopped_other_gain' => 'The number of members with the stopped paying status who transfered into this group without changing status.',
      'stopped_other_loss' => 'The number of members with the stopped paying status who transfered out of this group without changing status.',
      'stopped_unchanged_gain' => 'The number of members who became stopped paying and still are stopped paying',
      'a1p_unchanged_gain' => 'The number of members who became awaiting first payment and still are awaiting first payment ',
      'stopped_to_paying' => "The number of 'stopped paying' members who resumed paying",
      'stopped_to_other' => "The number of 'stopped paying' members who got a new status (other than paying) probably due to some follow up process."
    }
  end
  
  def no_total
    
    nt = [
      'row_header',
      'row_header_id',
      'row_header1',
      'row_header1_id',
      'row_header2',
      'row_header2_id',
      'contributors', 
      'annualisedavgcontribution',
      'running_paying_net'
    ]
    
    if data_sql.query['interval'] != 'none'
      nt += [
        'paying_start_count',
        'paying_end_count',
        'period_header',
        'a1p_start_count',
        'a1p_end_count',
        'stopped_start_count',
        'stopped_end_count'
      ]
    end
    
    nt
  end
 
  def next_group_by
    hash = {
      'branchid'      => 'lead',
      'lead'          => 'org',
      'org'           => 'companyid',
      'state'         => 'areaid',
      'areaid'        => 'companyid',
      'feegroupid'    => 'companyid',
      'nuwelectorate' => 'org',
      'del'           => 'companyid',
      'hsr'           => 'companyid',
      'industryid'	  => 'companyid',
      'companyid'     => 'companyid',
      'statusstaffid' => 'companyid',
      'supportstaffid' => 'org'
    }

    URI.escape "group_by=#{hash[data_sql.query['group_by']]}"
  end

  def filters
    (params[Filter] || []).reject{ |column_name, value | value.empty? }
  end

  def filter_names
    params[FilterNames] || []
  end
    
  def drill_down_link_header(row)
    uri_join_queries drill_down(row), next_group_by
  end
  
  def drill_down_link_interval(row)
    # This one shows all week two without intervals
    #uri_join_queries row_interval(row), 'interval=none'
    
    # This one shows just the values of the row header futher broken down for the period without the running totals
    uri_join_queries drill_down(row), next_group_by, row_interval(row), 'interval=none'
  end
  
  def drill_down(row)
    row_header1_id = row['row_header1_id']
    row_header1 = row['row_header1']
    URI.escape "#{Filter}[#{data_sql.query['group_by']}]=#{row_header1_id}"
  end
  
  def uri_join_queries(*queries)
    if params == {}
      @uri + '?' + queries.join('&')
    else
      @uri + '&' + queries.join('&')
    end
  end
    
  def filter_value(value)
    value.sub('!','').sub('-','')
  end
  
  def safe_add(a, b)
    if (a =~ /\./) || (b =~ /\./ )
      a.to_f + b.to_f
    else
      a.to_i + b.to_i
    end
  end
  
  def line_chart_ok?
    data_sql.query['group_by'] != 'statusstaffid' && data_sql.series_count(@data) <= 30 && data_sql.query['column'].empty? && data_sql.query['interval'] != 'none'
  end

  def waterfall_chart_ok?
    cnt =  @data.reject{ |row | row["paying_real_gain"] == '0' && row["paying_real_loss"] == '0' }.count
    data_sql.query['group_by'] != 'statusstaffid' && data_sql.query['column'].empty? && data_sql.query['interval'] == 'none' && cnt > 0  && cnt <= 30
  end

  def row_header_id_list
    @data.group_by{ |row| row['row_header1_id'] }.collect{ | rh | rh[0] }.join(",")
  end


end

