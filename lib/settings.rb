require 'date'
require 'yaml'

# Short names to help shorten URL
Filter = "f"
FilterNames = "fn"
MonthlyTransferWarningThreshold = Float(1.0 * 2.0 / 36.0); # 100% of the membership churns from development to growth and back every 3 years 
DateFormatDisplay = "%e %B %Y"
DateFormatPicker = "'d MM yy'"
DateFormatDB = "%Y-%m-%d"
MaxMemberList = 500

EarliestStartDate = Date.new(2011,8,14)

module Settings
  # Return the ChurnometerApp instance
  def app
    @app
  end

  def query_defaults
    if auth().staff?
      start_date = (Time.now-(60*24*3600)).strftime("1 %B %Y")
      end_date =  (Time.parse(Time.now.strftime("%Y-%m-01"))-24*3600).strftime(DateFormatDisplay)
    else
      start_date = Date.parse('2011-8-14').strftime(DateFormatDisplay)
      end_date = Time.now.strftime(DateFormatDisplay)
    end
    
    defaults = {
      'group_by' => app().groupby_default_dimension.id,
      'startDate' => start_date,
      'endDate' => end_date,
      'column' => '',
      'interval' => 'none',
      Filter => {
        'status' => [
           app().member_paying_status_code,
           app().member_awaiting_first_payment_status_code,
           app().member_stopped_paying_status_code
        ] # todo - get rid of this because exceptions are required for it when displaying filters
      }
    }
  end

  # The default class used to execute summary queries.
  # Classes that should be used to handle summary queries for specific groups.
  def summary_query_class_groupby_overrides
    {
    }    
  end

  def query_class_for_group(group_column_name)
    query_class_symbol = 
      if summary_query_class_groupby_overrides().has_key?(group_column_name)
        summary_query_class_groupby_overrides()[group_column_name]
      else
        app().summary_query_class
      end
        
    query_class = eval(query_class_symbol.to_s)
  end

  def interval_names
    [
      ["none", "Off"],
      ["week", "Weekly"],
      ["month", "Monthly"],
    ]
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
          'stopped_to_other',
          (@request.auth.leader? ? 'contributors' : ''), 
          (@request.auth.leader? ? 'income_net' : '')
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
        
      shash_option = {
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

      fhash_option = {
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

      if @request.auth.staff? or @request.auth.leader?
        hash = hash.merge(shash_option)
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
           'oldstatus',
           'newstatus',
           'currentstatus',
           'oldcompanyid',
           'newcompanyid',
           'currentcompanyid'
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
         if @request.auth.leader?
           hash = hash.merge(fhash);
         end
         
         hash
     end
     
     def col_names 
       # dbeswick: temporary until Settings is refactored away.
       raise "Class '#{self.class}' must provide the churnometer app instance in @app because it mixes in the Settings module." if @app.nil?

       row_header_col_name = @request.groupby_column_name.downcase

       hash = {
         'row_header1'     => row_header_col_name,
         'row_header'     => row_header_col_name,
         'a1p_real_gain'   => 'total cards in',
         'a1p_to_other'    => 'cards failed',
         'paying_start_count' => 'paying at start date',
         'paying_real_gain'  => 'started paying',
         'paying_real_loss'  => 'ceased paying',
         'a1p_start_count' => 'a1p at start date',
         'a1p_end_count' => 'a1p at end date',
         'paying_real_net'   => 'paying net',
         'paying_end_count'  => 'paying at end date',
         'posted'            => 'income posted',
         'unposted'            => 'income corrections',
         'income_net'            => 'income net',
         'running_paying_net'  => 'paying net (running total)',
         'paying_other_loss'   => 'paying transfers out',
         'paying_other_gain'   => 'paying transfers in',
         'a1p_other_gain'     => 'a1p transfers in',
         'a1p_other_loss'     => 'a1p transfers out',
         'a1p_newjoin'        => 'cards in (new)',
         'a1p_rejoin'         => 'cards in (rejoin)',
         'a1p_to_paying'     => 'a1p started paying',
         #'a1p_real_loss'     => 'a1p never paid',
         'period_header'       => "#{@request.params['interval']} beginning",
         'start_date'          => 'start date',
         'end_date'          => 'end date',
         'annualisedavgcontribution' => 'estimated annual contribution',
         'contributors'  => 'unique contributors',
         'stopped_start_count' => 'stopped paying at start date', 
         'stopped_end_count' => 'stopped paying at end date',
         'stopped_real_gain' => 'became stopped paying',
         'stopped_real_loss' => 'ceased stopped paying',
         'stopped_other_gain' => 'stopped paying transfers in',
         'stopped_other_loss' => 'stopped paying transfers out',
         'stopped_to_paying' => 'stopped paying resumed paying',
         'stopped_to_other' => 'stopped paying followed up',
         'stopped_unchanged_gain' => 'became stopped paying not followed up',
         'a1p_unchanged_gain' => 'cards in not followed up',
         'contactdetail' => 'current contact detail',
         'followupnotes' => 'follow up notes',
         'payrollcontactdetail' => 'payroll/hr contact',
         'lateness' => 'current payment status',
         'paymenttype' => 'payment type',
         'paymenttypeid' => 'payment type',
         'newemployer' => 'current employer',
         'currentstatus' => 'current status',
         'newcompany' => 'current site',
         'paidto' => 'current paid to date',
         'oldcompanyid' => 'old site',
         'oldorg' => 'old organiser',
         'oldemployerid' => 'old employer',
         'neworg' => "new organiser"
         }
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
         transactions
         }
     end
     
     def bold_col?(column_name)
       [
         'paying_real_net',
         'running_paying_net',
         'a1p_real_gain',
         'stopped_unchanged_gain',
         'a1p_unchanged_gain',
         'transactions',
         (!@request.auth.staff? ? 'stopped_to_other' : '')
         
       ].include?(column_name)
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
         'running_paying_net', 
         'lateness',
         'paymenttype',
         'paymenttypeid',
         'paidto',
         'followupnotes',
         'contactdetail',
         'newemployer',
         'payrollcontactdetail'
       ]

       if @request.params['interval'] != 'none'
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

     def date_cols
       [
         'period_header', 
         'paidto', 
         'changedate'
       ]
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
         'stopped_unchanged_gain' => 'The number of members who became stopped paying during the selected period and are still are stopped paying',
         'a1p_unchanged_gain' => 'The number of members who became awaiting first payment during the selected period and are still are awaiting first payment ',
         'stopped_to_paying' => "The number of 'stopped paying' members who resumed paying",
         'stopped_to_other' => "The number of 'stopped paying' members who got a new status (other than paying) probably due to some follow up process.",
         'transactions' => "The number of individual transactions that were posted against members.  A out of pay payment will usually contain numerous transactions.",
         'lateness' => "The remittance status of each employer with at least one OOP member attached. The next due date is determined from the '#{col_names['paidto']}' plus the average duration between payments (multipled by the number of unposted payments) plus half this average duration to allow for processing.",
         'paidto' => "The date up to which money has been posted.  The employer may have paid past this date but unposted payment don't count toward the '#{col_names['paidto']}' because the '#{col_names['paidto']}' is determined during payment posting.",
         'paymenttype' => 'Code representing either out of pay, direct debit, credit card or personal (invoice)',
      }
     end

end
