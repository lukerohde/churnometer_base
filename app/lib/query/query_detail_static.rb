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

require './lib/query/query_detail_base'

class QueryDetailStatic < QueryDetailBase
  # site_date may be nil.
  # app: The ChurnometerApp instance.
  # groupby_dimension: A DimensionUser instance.
  def initialize(app, churn_db, groupby_dimension, filter_column, member_date, site_date, filter_terms)
    super(app, churn_db, groupby_dimension, filter_column, filter_terms)
    @site_date = site_date
    @member_date = member_date
  end

  def self.filter_column_to_where_clause
    {
      '' => '', # empty filter column
      'paying' => 'where c.paying<>0',
      'green' => 'where c.green<>0',
      'orange' => 'where c.orange<>0',
      'a1p' => 'where c.a1p<>0',
      'stopped' => 'where c.stopped<>0',
      'other' => 'where c.other<>0',
      'waiver' => 'where c.waiver<>0',
      'member' => 'where c.member<>0',
      'membernofee' => 'where c.membernofee<>0',
      'memberfee' => 'where c.memberfee<>0',
      'nonpaying' => 'where c.nonpaying<>0'
    }
  end

  def query_string
    header1 = @groupby_dimension.column_base_name

    filter =
      if @site_date.nil?
        filter_terms()
      else
        work_site_dimension = @app.work_site_dimension

        modified_filter = FilterTerms.new

        site_query = QuerySitesAtDate.new(@app, @churn_db, @site_date, filter_terms())
        site_results = site_query.execute

        if site_results.num_tuples == 0
          modified_filter.append(work_site_dimension, 'none', false)
        else
          site_results.each do |record|
            modified_filter.append(work_site_dimension, record[work_site_dimension.column_base_name], false)
          end
        end

        # dbeswick: note: unlike other queries, detail_static doesn't keep the 'status' values in the
        # siteconstraint-modified filter.

        modified_filter
      end

    db = @churn_db.db

    # paying_db = db.quote(@app.member_paying_status_code)
    # a1p_db = db.quote(@app.member_awaiting_first_payment_status_code)
    # stoppedpay_db = db.quote(@app.member_stopped_paying_status_code)
    paying_db = db.sql_array(@app.paying_statuses)
    a1p_db = db.sql_array(@app.a1p_statuses)
    stoppedpay_db = db.sql_array(@app.stopped_statuses)

    sql = <<-EOS
      -- static detail query
      with lastchange as
      (
        -- finds all changes matching user criteria
        select
          max(changeid) changeid
        from
          memberfact
        where
          changedate < #{db.sql_date(@member_date)} -- we need to count every value since Churnobyls start to determine start_count.  But everything after enddate can be ignored.
        group by
          memberid

      )
      , userselections as
      (
        select
          *
        from
          #{db.quote_db(@source)}
        where
          changeid in (select changeid from lastchange)
          and net = 1 /* after change not before */
          #{sql_for_filter_terms(filter, true)}
      )
      , counts as
      (
        -- sum changes, if status doesnt change, then the change is a transfer
        select
          c.memberid
          , c.changeid::bigint
          , case when coalesce(#{db.quote_db(header1)}::varchar(50),'') = '' then 'unassigned' else #{db.quote_db(header1)}::varchar(50) end row_header
          , case when coalesce(status, '') = ANY (#{paying_db}) then 1 else 0 end::bigint paying
          , case when coalesce(status, '') = ANY (#{a1p_db}) then 1 else 0 end::bigint a1p
          , case when coalesce(status, '') = ANY (#{stoppedpay_db}) then 1 else 0 end::bigint stopped
          , case when waivernet <> 0 then 1 else 0 end::bigint waiver
          , case when membernet <> 0 then 1 else 0 end::bigint member
          , case when greennet <> 0 then 1 else 0 end::bigint green
          , case when orangenet <> 0 then 1 else 0 end::bigint orange
          , case when not (coalesce(status, '') = ANY (#{paying_db}) or coalesce(status, '') = ANY (#{a1p_db}) or coalesce(status, '') = ANY (#{stoppedpay_db}) or waivernet <> 0) then 1 else 0 end::bigint other
        from
          userselections c
      )
      select
        c.memberid
        , c.changeid
        , coalesce(d1.displaytext, c.row_header)::varchar(50) row_header -- c.row_header
        , c.row_header::varchar(20) row_header_id
        , c.paying
        , c.a1p
        , c.stopped
        , c.waiver
        , c.member
        , c.green
        , c.orange
        , c.other
      from
        counts c
        left join displaytext d1 on d1.attribute = #{db.quote(header1)} and d1.id = c.row_header
      #{self.class.filter_column_to_where_clause[@filter_column]}
      order by
        c.row_header asc
    EOS

    sql
  end
end
