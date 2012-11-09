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

require './lib/churn_db'
require 'open3.rb'

class DatabaseManager

  def db 
    @db
  end

  def initialize(app)
    @dimensions = app.custom_dimensions
    @db = Db.new(app)
    @app = app
    
    @paying_db = @db.quote(@app.member_paying_status_code)
    @a1p_db = @db.quote(@app.member_awaiting_first_payment_status_code)
    @stopped_db = @db.quote(@app.member_stopped_paying_status_code)
  end

  def dimensions
    @dimensions 
  end

  def app
    @app
  end

  def temp_fix
    sql = <<-SQL
      update 
        memberfact 
      set
        oldstatus = lower(trim(oldstatus))
        , newstatus = lower(trim(newstatus))
    SQL
    
    dimensions.each { |d| sql << <<-SQL }
      , old#{d.column_base_name} = lower(trim(old#{d.column_base_name}))
      , new#{d.column_base_name} = lower(trim(new#{d.column_base_name}))
    SQL
    
    sql << <<-SQL
    ;
      update 
        memberfacthelper
      set
        , status = lower(trim(status))
    SQL
    
    dimensions.each { |d| sql << <<-SQL }
      , #{d.column_base_name} = lower(trim(#{d.column_base_name}))
    SQL
    
    sql << "; update displaytext set id = lower(trim(id))"
    
    sql
  end

  def migrate_rebuild_without_indexes_sql()
    sql = <<-SQL
      drop table if exists importing;
      select 0 as importing into importing;
   
      drop function if exists insertmemberfact();
      drop function if exists updatememberfacthelper();
      
      drop view if exists memberchangefromlastchange;
      drop view if exists memberchangefrommembersourceprev;
      drop view if exists lastchange;
      drop view if exists memberfacthelperquery;

      drop table if exists memberfact_migration;
      drop table if exists membersourceprev_migration;
      drop table if exists memberfacthelper_migration;
      
      alter table memberfact rename to memberfact_migration;
      alter table membersourceprev rename to membersourceprev_migration;
      alter table memberfacthelper rename to memberfacthelper_migration;
     
      #{rebuild_membersource_sql};
      #{rebuild_membersourceprev_sql};
      #{memberfact_sql};
      
      #{lastchange_sql};
      #{memberchangefromlastchange_sql};
      #{memberchangefrommembersourceprev_sql};
      #{memberfacthelperquery_sql};
      #{memberfacthelper_sql}
      
      #{updatememberfacthelper_sql};
      #{insertmemberfact_sql};
    SQL
  end
  
  def rebuild_from_scratch_without_indexes_sql()
    sql = <<-SQL
      drop table if exists importing;
      select 0 as importing into importing;
   
      drop function if exists inserttransactionfact();
      drop function if exists updatedisplaytext();
      drop function if exists insertmemberfact();
      drop function if exists updatememberfacthelper();
      
      drop view if exists memberchangefromlastchange;
      drop view if exists memberchangefrommembersourceprev;
      drop view if exists lastchange;
      drop view if exists memberfacthelperquery;

      drop table if exists memberfact_migration;
      drop table if exists membersourceprev_migration;
      drop table if exists memberfacthelper_migration;
      
      drop table if exists transactionfact_migration;
      drop table if exists transactionsourceprev_migration;
      drop table if exists displaytext_migration;
      
      alter table transactionfact rename to transactionfact_migration;
      alter table transactionsourceprev rename to transactionsourceprev_migration;
      alter table displaytext rename to displaytext_migration;

	    alter table memberfact rename to memberfact_migration;
      alter table membersourceprev rename to membersourceprev_migration;
      alter table memberfacthelper rename to memberfacthelper_migration;
      
      #{memberfact_sql};
      #{rebuild_membersourceprev_sql};
      #{rebuild_membersource_sql};
      
      #{displaytext_sql};
      #{rebuild_transactionsourceprev_sql};
      #{transactionfact_sql};
      
      #{rebuild_displaytextsource_sql};
      #{rebuild_transactionsource_sql};
      
      #{lastchange_sql};
      #{memberchangefromlastchange_sql};
      #{memberchangefrommembersourceprev_sql};
      #{memberfacthelperquery_sql};
      #{memberfacthelper_sql}
      
      #{updatememberfacthelper_sql};
      #{insertmemberfact_sql};
      #{updatedisplaytext_sql};
      #{inserttransactionfact_sql};      
    SQL
  end
  
  
  def rebuild()
    db.ex(rebuild_from_scratch_without_indexes_sql)
    db.ex(rebuild_most_indexes_sql)
    db.ex(rebuild_memberfacthelper_indexes_sql)
    
    # ANALYSE and VACUUM have to be run as separate database calls
    str = <<-SQL
      ANALYSE memberfact;
      ANALYSE memberfact;
      ANALYSE memberfacthelper;
      ANALYSE transactionfact;
      ANALYSE displaytext;
      ANALYSE membersource;
      ANALYSE membersourceprev;
      ANALYSE transactionsource;
      ANALYSE transactionsourceprev;
      ANALYSE displaytextsource;
      
      VACUUM memberfact;
      VACUUM memberfacthelper;
      VACUUM transactionfact;
      VACUUM displaytext;
      VACUUM membersource;
      VACUUM membersourceprev;
      VACUUM transactionsource;
      VACUUM transactionsourceprev;
      VACUUM displaytextsource;
    SQL
    
    str.split("\n").each { |cmd| db.ex(cmd) }
  end
  
  def rebuild_displaytextsource_sql
    sql = <<-SQL
      drop table if exists displaytextsource;
      
      create table displaytextsource
      (
        attribute varchar(255) not null
        , id varchar(255) null
        , displaytext varchar(255) null
      );
          
    SQL
  end
  
  def rebuild_displaytextsource
    db.ex(rebuild_displaytextsource_sql)
  end
  
  def displaytext_sql
    sql = <<-SQL
      create table displaytext
      (
        attribute varchar(255) not null
        , id varchar(255) null
        , displaytext varchar(255) null
      );
         
    SQL
  end
  
  def displaytext
    db.ex(displaytext_sql)
  end
  
  def membersource_sql
    sql = <<-SQL
      create table membersource 
      (
          memberid varchar(255) not null 
          , status varchar(255) not null
    
    SQL
      
    dimensions.each { |d| sql << <<-REPEAT } 
        , #{d.column_base_name} varchar(255) null
    REPEAT
    
    sql << <<-SQL
      )
      
    SQL
  end
  
  def rebuild_membersource_sql
    sql = <<-SQL
      drop table if exists membersource;
      #{membersource_sql};
    SQL
  end
  
  def empty_membersource
    db.ex("delete from membersource");
  end

  def rebuild_membersource
    db.ex(rebuild_membersource_sql)
  end
  
  def rebuild_membersourceprev_sql
    sql = rebuild_membersource_sql.gsub('membersource', 'membersourceprev')
  end
  
  def rebuild_membersourceprev
    db.ex(rebuild_membersourceprev_sql)
  end

  def memberfact_sql
    sql = <<-SQL
      create table memberfact
      (
        changeid BIGSERIAL PRIMARY KEY
        , changedate timestamp not null
        , memberid varchar(255) not null
        , oldstatus varchar(255) null
        , newstatus varchar(255) null
    SQL

    dimensions.each { | d | sql << <<-REPEAT }
        , old#{d.column_base_name} varchar(255) null
        , new#{d.column_base_name} varchar(255) null
    REPEAT

    sql << <<-SQL
      );
    SQL
  end

  def lastchange_sql
    sql = <<-SQL
      create view lastchange as
        select
          changeid
          , changedate
          , memberid
          , newstatus status
    SQL

    dimensions.each { |d| sql << <<-REPEAT }
          , new#{d.column_base_name} as #{d.column_base_name}
    REPEAT

    sql << <<-SQL
        from 
          memberfact 
        where (
          memberfact.changeid IN (
            select 
              max(memberfact.changeid) AS max 
            from  
              memberfact 
            group by  
              memberfact.memberid
          )
        );
    SQL
  end

  def memberchangefromlastchange_sql

    sql = <<-SQL
      -- find changes, adds and deletions in latest data
      create or replace view memberchangefromlastchange as 
      -- find members who've changed in latest data
      select
        now() as changedate
        , old.memberid
        , trim(lower(old.status)) as oldstatus
        , trim(lower(new.status)) as newstatus
    SQL
    
    dimensions.each { |d| sql << <<-REPEAT }
        , trim(lower(old.#{d.column_base_name})) as old#{d.column_base_name}
        , trim(lower(new.#{d.column_base_name})) as new#{d.column_base_name}
    REPEAT

    sql << <<-SQL
      from
        lastchange old
        inner join membersource new on old.memberid = new.memberid
      where
        trim(lower(coalesce(old.status, ''))) <> trim(lower(coalesce(new.status, '')))
    SQL

    dimensions.each { |d| sql << <<-REPEAT }
        OR trim(lower(coalesce(old.#{d.column_base_name}, ''))) <> trim(lower(coalesce(new.#{d.column_base_name}, '')))
    REPEAT
    
    sql << <<-SQL
      UNION ALL
      -- find members missing in latest data
      select
        now() as changedate
        , old.memberid
        , trim(lower(old.status)) as oldstatus
        , null as newstatus
    SQL

    dimensions.each { |d| sql << <<-REPEAT }
        , trim(lower(old.#{d.column_base_name})) as old#{d.column_base_name}
        , null as new#{d.column_base_name}
    REPEAT

    sql << <<-SQL
      from
        lastchange old
      where
        not old.memberid in (
          select
            memberid
          from
            membersource
        )
        AND not (
          -- if all values for the member's last change are null
          --, then the member has already been inserted as missing 
          -- and doesn't need to be inserted again
          old.status is null
    SQL

    dimensions.each { |d| sql << <<-REPEAT }
          AND old.#{d.column_base_name} is null
    REPEAT

    sql << <<-SQL
        )
      UNION ALL
      -- find members appearing in latest data
      select
        now() as changedate
        , new.memberid
        , null as oldstatus
        , trim(lower(new.status)) as newstatus
    SQL

    dimensions.each { |d| sql << <<-REPEAT }
        , null as old#{d.column_base_name}
        , trim(lower(new.#{d.column_base_name})) as new#{d.column_base_name}
    REPEAT

    sql << <<-SQL
      from
        membersource new
      where
        not new.memberid in (
          select
            lastchange.memberid
          from
            lastchange
        )
    SQL
  end
  
  def memberchangefrommembersourceprev_sql
    memberchangefromlastchange_sql.gsub('lastchange', 'membersourceprev')
  end

  def insertmemberfact_sql

    sql = <<-SQL
      CREATE OR REPLACE FUNCTION insertmemberfact(import_date timestamp) RETURNS void 
	    AS $BODY$begin

        -- don't run the import if nothing is ready for comparison
        if 0 = (select count(*) from membersource) then 
	        return; 
        end if;     

        insert into memberfact (
          changedate
          , memberid
          , oldstatus
          , newstatus
    SQL

    dimensions.each { |d| sql << <<-REPEAT }
          , old#{d.column_base_name}
          , new#{d.column_base_name}
    REPEAT

    sql << <<-SQL
        )
        select
          import_date
          , memberid
          , oldstatus
          , newstatus
    SQL

    dimensions.each { |d| sql << <<-REPEAT }
          , old#{d.column_base_name}
          , new#{d.column_base_name}
    REPEAT

    sql << <<-SQL
        from
          memberchangefromlastchange;

        -- finalise import, so running this again won't do anything
        delete from memberSourcePrev;
        insert into memberSourcePrev select * from memberSource;
        delete from memberSource;

      end$BODY$
        LANGUAGE plpgsql
        COST 100
        CALLED ON NULL INPUT
        SECURITY INVOKER
        VOLATILE;
    SQL
  end

  def updatememberfacthelper_sql
    <<-SQL 
    CREATE OR REPLACE FUNCTION updatememberfacthelper() RETURNS void 
      AS $BODY$begin
        -- update memberfacthelper with new facts (helper is designed for fast aggregration)
        insert into memberfacthelper
        select 
          * 
        from 
          memberfacthelperquery h
        where 
          -- only insert facts we haven't already inserted
          changeid not in (select changeid from memberfacthelper)
          and       (
		    -- only include people who've been an interesting status
        exists (
          select
            1
          from 
            memberfact mf
          where
            mf.memberid = h.memberid
            and (
              oldstatus = #{@paying_db}
              or oldstatus = #{@stopped_db}
              or oldstatus = #{@a1p_db}
              or newstatus = #{@paying_db}
              or newstatus = #{@stopped_db}
              or newstatus = #{@a1p_db}
            )
        )
        -- or have paid something since tracking begun
        or exists (
          select
            1
          from
            transactionfact tf
          where
            tf.memberid = h.memberid
        )
      );
    
        -- as new status changes happen, next status changes need to be updated
        update
          memberfacthelper
        set
          duration = h.duration
          , _changeid = h._changeid
          , _changedate = h._changedate
        from
          memberfacthelperquery h
        where
          memberfacthelper.changeid = h.changeid
          and memberfacthelper.net = h.net
          and (
            coalesce(memberfacthelper.duration,0) <> coalesce(h.duration,0)
            or coalesce(memberfacthelper._changeid,0) <> coalesce(h._changeid,0)
            or coalesce(memberfacthelper._changedate, '1/1/1900') <> coalesce(h._changedate, '1/1/1900') 
          );

      end$BODY$
        LANGUAGE plpgsql
        COST 100
        CALLED ON NULL INPUT
        SECURITY INVOKER
        VOLATILE;
    SQL
  end


  def memberfacthelperquery_sql

    sql = <<-SQL
      create or replace view memberfacthelperquery as
      with mfnextstatuschange as
      (
        -- find the next status change for each statuschange
        select 
          lead(changeid)  over (partition by memberid order by changeid) nextstatuschangeid
          , mf.*
        from 
          memberfact mf
        where 
          coalesce(mf.oldstatus,'') <> coalesce(mf.newstatus,'')
      )
      , nextchange as (
        select 
          c.changeid
          , n.changeid nextchangeid
          , n.changedate nextchangedate
          , n.newstatus nextstatus
          , (coalesce(n.changedate::date, current_date) - c.changedate::date)::int nextduration
        from 
          mfnextstatuschange c
        left join memberfact n on c.nextstatuschangeid = n.changeid
      )
      select
        memberfact.changeid
        , changedate
        , memberid      
        , -1 as net
        , 0 as gain
        , 1 as loss
        , coalesce(oldstatus, '') as status
        , coalesce(newstatus, '') as _status
        , case when coalesce(oldstatus, '') <> coalesce(newstatus, '')
            then -1 else 0 end as statusdelta
        , 0 as a1pgain
        , case when coalesce(oldstatus, '') = #{@a1p_db} and coalesce(newstatus, '') <> #{@a1p_db}
            then -1 else 0 end as a1ploss
        , 0 as payinggain
        , case when coalesce(oldstatus, '') = #{@paying_db} and coalesce(newstatus, '') <> #{@paying_db}
          then -1 else 0 end as payingloss
        , 0 as stoppedgain
        , case when coalesce(oldstatus, '') = #{@stopped_db} and coalesce(newstatus, '') <> #{@stopped_db}
            then -1 else 0 end as stoppedloss
        , 0 as othergain
        , case when 
            NOT (coalesce(oldstatus, '') = #{@a1p_db} and coalesce(newstatus, '') <> #{@a1p_db})
            AND NOT (coalesce(oldstatus, '') = #{@paying_db} and coalesce(newstatus, '') <> #{@paying_db})
            AND NOT (coalesce(oldstatus, '') = #{@stopped_db} and coalesce(newstatus, '') <> #{@stopped_db})
            then -1 else 0 end as otherloss
    SQL
  
    dimensions.each { |d| sql << <<-REPEAT }
          , coalesce(old#{d.column_base_name}, '') #{d.column_base_name}
          , case when coalesce(old#{d.column_base_name}, '') <> coalesce(new#{d.column_base_name}, '')
              then -1 else 0 end as #{d.column_base_name}delta 
    REPEAT

    sql << <<-SQL
        , nextchangeid _changeid
        , nextchangedate _changedate
        , nextduration duration
      from 
        memberfact
        left join nextchange on memberfact.changeid = nextchange.changeid

      UNION ALL

      select
        memberfact.changeid
        , changedate
        , memberid
        , 1 as net
        , 1 as gain
        , 0 as loss
        , coalesce(newstatus, '') as status
        , coalesce(oldstatus, '') as _status
        , case when coalesce(oldstatus, '') <> coalesce(newstatus, '')
            then 1 else 0 end as statusdelta
        , case when coalesce(oldstatus, '') <> #{@a1p_db} and coalesce(newstatus, '') = #{@a1p_db}
            then 1 else 0 end as a1pgain
        , 0 as a1ploss
        , case when coalesce(oldstatus, '') <> #{@paying_db} and coalesce(newstatus, '') = #{@paying_db}
          then 1 else 0 end as payinggain
        , 0 as payingloss
        , case when coalesce(oldstatus, '') <> #{@stopped_db} and coalesce(newstatus, '') = #{@stopped_db}
            then 1 else 0 end as stoppedgain
        , 0 as stoppedloss
        , case when 
            NOT (coalesce(oldstatus, '') <> #{@a1p_db} and coalesce(newstatus, '') = #{@a1p_db})
            AND NOT (coalesce(oldstatus, '') <> #{@paying_db} and coalesce(newstatus, '') = #{@paying_db})
            AND NOT (coalesce(oldstatus, '') <> #{@stopped_db} and coalesce(newstatus, '') = #{@stopped_db})
            then 1 else 0 end as othergain
        , 0 as otherloss
    SQL
  
    dimensions.each { |d| sql << <<-REPEAT }
          , coalesce(new#{d.column_base_name}, '') #{d.column_base_name}
          , case when coalesce(old#{d.column_base_name}, '') <> coalesce(new#{d.column_base_name}, '')
              then 1 else 0 end as #{d.column_base_name}delta 
    REPEAT

    sql << <<-SQL
        , nextchangeid _changeid
        , nextchangedate _changedate
        , nextduration duration
      from 
        memberfact
       left join nextchange on memberfact.changeid = nextchange.changeid
    SQL
  end
  
  def memberfacthelper_subset_sql
    <<-SQL
      (
		    -- only include people who've been an interesting status
        exists (
          select
            1
          from 
            memberfact mf
          where
            mf.memberid = h.memberid
            and (
              oldstatus = #{@paying_db}
              or oldstatus = #{@stopped_db}
              or oldstatus = #{@a1p_db}
              or newstatus = #{@paying_db}
              or newstatus = #{@stopped_db}
              or newstatus = #{@a1p_db}
            )
        )
        -- or have paid something since tracking begun
        or exists (
          select
            1
          from
            transactionfact tf
          where
            tf.memberid = h.memberid
        )
      )
    SQL
  end
  
  def memberfacthelper_sql
    sql = <<-SQL
      drop table if exists memberfacthelper;
      create table memberfacthelper as 
      select 
        * 
      from 
        memberfacthelperquery h
      where 
        #{memberfacthelper_subset_sql};
    SQL
  end
  
  def transactionfact_sql
    <<-SQL
      create table transactionfact
      (
        id varchar(255) not null
        , creationdate timestamp not null
        , memberid varchar(255) not null
        , userid varchar(255) not null
        , amount money not null
        , changeid bigint not null
      );
    SQL
  end
  
  def transactionfact
    db.ex(transactionfact_sql)
  end
  
  def transactionsource_sql
    sql = <<-SQL
      create table transactionsource
      (
        id varchar(255) not null
        , creationdate timestamp not null
        , memberid varchar(255) not null
        , userid varchar(255) not null
        , amount money not null
      );
    SQL
  end
  
  def rebuild_transactionsource_sql
    sql = <<-SQL
      drop table if exists transactionsource;
      
      #{transactionsource_sql}
    SQL
  end
  
  def rebuild_transactionsource
    db.ex(rebuild_transactionsource_sql)
  end
  
   def transactionsourceprev_sql
    transactionsource_sql.gsub("transactionsource", "transactionsourceprev")
  end
  
  def transactionsourceprev
    db.ex(transactionsourceprev_sql)
  end
  
  def rebuild_transactionsourceprev_sql
    rebuild_transactionsource_sql.gsub("transactionsource", "transactionsourceprev")
  end
  
  def rebuild_transactionsourceprev
    db.ex(transactionsourceprev_sql)
  end
  
  def inserttransactionfact_sql
    <<-SQL
      CREATE OR REPLACE FUNCTION inserttransactionfact(import_date timestamp) RETURNS void 
	    AS $BODY$begin
        
        -- don't run the import if nothing has been imported for comparison
        if 0 = (select count(*) from transactionsource) then 
          return;
        end if;  
        
        insert into 
          transactionfact (
              id
              , creationdate
              , memberid
              , userid 
              , amount
              , changeid
            )
            
        -- insert any transactions that have appeared since last comparison
        select 
          t.id
          , import_date 
          , t.memberid
          , t.userid
          , t.amount
          , (
            -- assign dimensions of latest change to the transaction
            select 
              max(changeid) changeid 
            from 
              memberfact m 
            where 
              m.memberid = t.memberid
          ) changeid
        from 
          transactionSource t 
        where 
          not id in (select id from transactionSourcePrev)
          
        union all
        
        -- insert negations for any transactions that have been deleted since last comparison
        select 
          t.id
          , import_date
          , t.memberid
          , t.userid
          , 0::money-t.amount
          , (
            -- assign dimensions of deleted transaction to the negated transaction
            select 
              changeid
            from
              transactionfact
            where
              transactionfact.id = t.id
          ) changeid
        from 
          transactionSourcePrev t 
        where 
          not id in (select id from transactionSource)  
        ;
        
        -- finalise import, so running this again won't do anything
        delete from transactionSourcePrev;
        insert into transactionSourcePrev select * from transactionSource;
        delete from transactionSource;
        
      end;$BODY$
        LANGUAGE plpgsql
        COST 100
        CALLED ON NULL INPUT
        SECURITY INVOKER
        VOLATILE;
    SQL
  end
  
  def updatedisplaytext_sql
    sql = <<-SQL
      CREATE OR REPLACE FUNCTION public.updatedisplaytext() RETURNS void 
        AS $BODY$
      begin
        -- don't run the import if nothing is ready for comparison
        if 0 = (select count(*) from displaytextsource) then 
          return;
        end if;
        
        
        update 
          displaytext 
        set
          displaytext = d2.displaytext
        from
         displaytextsource d2  
        where
          displaytext.id = d2.id 
          and displaytext.attribute = d2.attribute
          and displaytext.displaytext <> d2.displaytext
        ;
        
        insert into displaytext
        select
          *
        from
         displaytextsource d
        where
          not exists (select 1 from displaytext where attribute = d.attribute and id=d.id);
        
        -- delete to make way for next import
        delete from displaytextsource;
      end 
      $BODY$
        LANGUAGE plpgsql
        COST 100
        CALLED ON NULL INPUT
        SECURITY INVOKER
        VOLATILE;
    SQL
  end
  
  def insertdisplaytext
    db.ex(insertdisplaytext_sql)
  end
  
  def rebuild_most_indexes_sql()
    sql = <<-SQL 
      drop index if exists "displaytext_attribute_idx";
	    drop index if exists "displaytext_id_idx";
      drop index if exists "displaytext_attribute_id_idx";

      drop index if exists "memberfact_changeid_idx";
      drop index if exists "memberfact_memberid_idx";
      drop index if exists "memberfact_oldstatus_idx";
      drop index if exists "memberfact_newstatus_idx";
      
      drop index if exists "transactionfact_memberid_idx";
      drop index if exists "transactionfact_changeid_idx";
    SQL
    
    
    sql << <<-SQL
      CREATE INDEX "displaytext_attribute_idx" ON "displaytext" USING btree(attribute ASC NULLS LAST);
      CREATE INDEX "displaytext_id_idx" ON "displaytext" USING btree(id ASC NULLS LAST);
      CREATE INDEX "displaytext_attribute_id_idx" ON "displaytext" USING btree(attribute ASC, id ASC NULLS LAST);
      CREATE INDEX "membersource_memberid_idx" ON "membersource" USING btree(memberid ASC NULLS LAST);

      CREATE INDEX "memberfact_changeid_idx" ON "memberfact" USING btree(changeid ASC NULLS LAST);
      CREATE INDEX "memberfact_memberid_idx" ON "memberfact" USING btree(memberid ASC NULLS LAST);
      CREATE INDEX "memberfact_oldstatus_idx" ON "memberfact" USING btree(oldstatus ASC NULLS LAST);
      CREATE INDEX "memberfact_newstatus_idx" ON "memberfact" USING btree(newstatus ASC NULLS LAST);
    
      
      CREATE INDEX "transactionfact_memberid_idx" ON "transactionfact" USING btree(memberid ASC NULLS LAST);
      CREATE INDEX "transactionfact_changeid_idx" ON "transactionfact" USING btree(changeid ASC NULLS LAST);
    SQL
  end
  
  def rebuild_memberfacthelper_indexes_sql()
    sql = "" 
    dimensions.each { |d| sql << <<-REPEAT }
      drop index if exists "memberfacthelper_#{d.column_base_name}_idx" ;
    REPEAT
  
    sql << <<-SQL
      drop index if exists "memberfacthelper_changeid_idx";
      drop index if exists "memberfacthelper_memberid_idx";
      drop index if exists "memberfacthelper_changedate_idx";
    
      CREATE INDEX "memberfacthelper_changeid_idx" ON "memberfacthelper" USING btree(changeid ASC NULLS LAST);
      CREATE INDEX "memberfacthelper_memberid_idx" ON "memberfacthelper" USING btree(memberid ASC NULLS LAST);
      CREATE INDEX "memberfacthelper_changedate_idx" ON "memberfacthelper" USING btree(changedate ASC NULLS LAST);
    SQL
    
    dimensions.each { |d| sql << <<-REPEAT }
      CREATE INDEX "memberfacthelper_#{d.column_base_name}_idx" ON "memberfacthelper" USING btree(#{d.column_base_name} ASC NULLS LAST);
    REPEAT
  
    sql
  end
  
  
  def migrate_regression_generalise_to_base
    <<-SQL
      insert into membersourceprev
      (
      col0
      ,col1
      ,col10
      ,col11
      ,col12
      ,col13
      ,col14
      ,col15
      ,col16
      ,col17
      ,col18
      ,col2
      ,col3
      ,col4
      ,col5
      ,col6
      ,col7
      ,col8
      ,col9
      ,memberid
      ,status
      )
      select
      branchid
      , industryid
      , feegroupid
      , state
      , nuwelectorate
      , statusstaffid
      , supportstaffid
      , employerid
      , hostemployerid
      , employmenttypeid
      , paymenttypeid
      , lead
      , org
      , areaid
      , companyid
      , agreementexpiry
      , del
      , hsr
      , gender
      , memberid
      , status
      from
      membersourceprev_migration;
      
      delete from memberfact_migration where not memberid in (select distinct memberid from memberfacthelper_migration) ;
      
      insert into memberfact
      (
      changedate
      , changeid
      , memberid
      , newcol0
      , newcol1
      , newcol10
      , newcol11
      , newcol12
      , newcol13
      , newcol14
      , newcol15
      , newcol16
      , newcol17
      , newcol18
      , newcol2
      , newcol3
      , newcol4
      , newcol5
      , newcol6
      , newcol7
      , newcol8
      , newcol9
      , newstatus
      , oldcol0
      , oldcol1
      , oldcol10
      , oldcol11
      , oldcol12
      , oldcol13
      , oldcol14
      , oldcol15
      , oldcol16
      , oldcol17
      , oldcol18
      , oldcol2
      , oldcol3
      , oldcol4
      , oldcol5
      , oldcol6
      , oldcol7
      , oldcol8
      , oldcol9
      , oldstatus
      )
      
      select
      changedate
      , changeid
      , memberid
      , newcol0
      , newcol1
      , newcol10
      , newcol11
      , newcol12
      , newcol13
      , newcol14
      , newcol15
      , newcol16
      , newcol17
      , newcol18
      , newcol2
      , newcol3
      , newcol4
      , newcol5
      , newcol6
      , newcol7
      , newcol8
      , newcol9
      , newstatus
      , oldcol0
      , oldcol1
      , oldcol10
      , oldcol11
      , oldcol12
      , oldcol13
      , oldcol14
      , oldcol15
      , oldcol16
      , oldcol17
      , oldcol18
      , oldcol2
      , oldcol3
      , oldcol4
      , oldcol5
      , oldcol6
      , oldcol7
      , oldcol8
      , oldcol9
      , oldstatus
      from 
      memberfact_migration
      ;
      
      
      insert into displaytext
      (
      attribute
      , id
      , displaytext
      )
      select
      attribute
      , id
      , displaytext
      from displaytext_migration;
      
      insert into transactionfact
      (
      id
      , creationdate
      , memberid
      , userid
      , amount
      , changeid
      )
      select 
      transactionid
      , creationdate
      , memberid
      , staffid
      , amount
      , changeid
      from 
      transactionfact_migration
      
      ;
      
      insert into memberfacthelper (
      changeid
      , memberid
      , changedate
      , net
      , gain
      , loss
      , status
      , _status
      , statusdelta
      , payinggain
      , payingloss
      , a1pgain
      , a1ploss
      , stoppedgain
      , stoppedloss
      , othergain
      , otherloss
      , col0
      , col0delta
      , col1
      , col1delta
      , col2
      , col2delta
      , col3
      , col3delta
      , col4
      , col4delta
      , col5
      , col5delta
      , col6
      , col6delta
      , col7
      , col7delta
      , col8
      , col8delta
      , col9
      , col9delta
      , col10
      , col10delta
      , col11
      , col11delta
      , col12
      , col12delta
      , col13
      , col13delta
      , col14
      , col14delta
      , col15
      , col15delta
      , col16
      , col16delta
      , col17
      , col17delta
      , col18
      , col18delta
      , duration
      , _changeid
      , _changedate
      )
      
      select 
      changeid
      , memberid
      , changedate
      , net
      , gain
      , loss
      , status
      , _status
      , statusdelta
      , payinggain
      , payingloss
      , a1pgain
      , a1ploss
      , stoppedgain
      , stoppedloss
      , othergain
      , otherloss
      , col0
      , col0delta
      , col1
      , col1delta
      , col2
      , col2delta
      , col3
      , col3delta
      , col4
      , col4delta
      , col5
      , col5delta
      , col6
      , col6delta
      , col7
      , col7delta
      , col8
      , col8delta
      , col9
      , col9delta
      , col10
      , col10delta
      , col11
      , col11delta
      , col12
      , col12delta
      , col13
      , col13delta
      , col14
      , col14delta
      , col15
      , col15delta
      , col16
      , col16delta
      , col17
      , col17delta
      , col18
      , col18delta
      , duration
      , _changeid
      , _changedate
      from 
      memberfacthelper_migration;
      
      drop table memberfact_migration;
      drop table memberfacthelper_migration;
      drop table membersourceprev_migration;
      drop table displaytext_migration;
      drop table transactionfact_migration;
      

    SQL
  end
  
  def migrate_membersourceprev_sql(mapping)
    
    sql = <<-SQL
    
      insert into membersourceprev
      (
        memberid
        , status
    SQL
    
    mapping.each { | oldvalue, newvalue | sql << <<-REPEAT }
        , #{newvalue}  
    REPEAT
    
    sql << <<-SQL
      )
      select
        memberid
        , status
    SQL
    
    mapping.each { | oldvalue, newvalue | sql << <<-REPEAT }
        , #{oldvalue}  
    REPEAT
    
    sql << <<-SQL
      from
        membersourceprev_migration;
    SQL
  end
  
    
  def migrate_memberfact_sql(mapping)
    
    sql = <<-SQL
    
      insert into memberfact
      (
        changeid
        , changedate
        , memberid
        , oldstatus
        , newstatus
    SQL
    
    mapping.each { | oldvalue, newvalue | sql << <<-REPEAT }
        , old#{newvalue}  
        , new#{newvalue}  
    REPEAT
    
    sql << <<-SQL
      )
      select
        changeid
        , changedate
        , memberid
        , oldstatus
        , newstatus
    SQL
    
    mapping.each { | oldvalue, newvalue | sql << <<-REPEAT }
        , old#{oldvalue}  
        , new#{oldvalue}  
    REPEAT
    
    sql << <<-SQL
      from
        memberfact_migration;
        
      SELECT setval('memberfact_changeid_seq', (SELECT MAX(changeid) FROM memberfact));
    SQL
  end
  
  # ASU to NUW back-porting migration
  def migrate_transactionfact_sql
    <<-SQL
    
      insert into transactionfact
      (
        id
        , creationdate
        , memberid
        , userid
        , amount
        , changeid
      )
      select 
        transactionid
        , creationdate
        , memberid
        , staffid
        , coalesce(amount,0::money)
        , changeid
      from 
        transactionfact_migration;
    SQL
  end
  
  # ASU to NUW back-porting migration
  def migrate_transactionsourceprev_sql
    <<-SQL
    
      insert into transactionsourceprev
      (
        id
        , creationdate
        , memberid
        , userid
        , amount
      )
      select 
        transactionid
        , creationdate
        , memberid
        , staffid
        , coalesce(amount,0::money)
      from 
        transactionsourceprev_migration;
    SQL
  end
  
  # ASU to NUW back-porting migration
  def migrate_displaytext_sql
    <<-SQL
    
      insert into displaytext
      (
        attribute
        , id
        , displaytext
      )
      select
        attribute
        , id
        , displaytext
      from 
        displaytext_migration;
    SQL
  end
  
  
  def migrate_dimstart_sql(migration_spec)
    sql = ""
    
    migration_spec.each do | k, v |
      case v.to_s
      when "CREATE"
        sql << "insert into dimstart (dimension, startdate) select '#{k.to_s}', current_date; \n";
      when "DELETE"
        sql << "delete from dimstart where dimension = '#{k.to_s}'; \n" ;
      else
        sql << "update dimstart set dimension = '#{v.to_s}' where dimension = '#{k.to_s}'; \n" if (k.to_s != v.to_s); 
      end
    end
    sql
  end
  
  def migration_yaml_spec
    m = {}
    result = nil
    
    # retreive current db schema, action = delete by default
    columns = db.ex("select column_name from information_schema.columns where table_name='membersourceprev';")
    columns.each do |row|
      if !['memberid', 'status'].include?(row['column_name'])
        m[row['column_name']] = 'DELETE'
      end
    end
      
    # match dimensions to db columns, if a dimensions isn't in db list, create it
    # any unmatched db columns, will remain deleted
    dimensions().each do | d |
      if m.has_key?(d.column_base_name)
        m[d.column_base_name] = d.column_base_name 
      else
        m[d.column_base_name] = 'CREATE' 
      end
    end
        
    result = m.to_yaml() if (m.count{ |k,v| v == 'DELETE' || v == 'CREATE' } > 0)
  end
  
  def parse_migration(yaml_spec)
    migration_spec = YAML.load(yaml_spec)
    
    # make sure columns being mapped are present in both db and config
    mapping = migration_spec.select{ |k,v| v.to_s != "DELETE" && v.to_s != "CREATE"}
    dimension_names = dimensions.collect { |d| d.column_base_name }
    
    column_data = db.ex("select column_name from information_schema.columns where table_name='membersourceprev';")
    columns = column_data.collect { |row| row['column_name'] }
    
    mapping.each do |k,v|
      raise "Reporting dimension #{v} not found in config/config.yaml" if !dimension_names.include?(v)
      raise "Reporting dimension #{k} not found in database" if !columns.include?(k)
    end
    
    migration_spec
  end
   
  # ASU to NUW specific migration (replaced below!)
  def migrate_nuw_sql(migration_spec)
    mapping = migration_spec.select{ |k,v| v.to_s != "DELETE" && v.to_s != "CREATE"}
    
    <<-SQL
      #{rebuild_from_scratch_without_indexes_sql()}
      #{migrate_membersourceprev_sql(mapping)}
      #{migrate_memberfact_sql(mapping)}
      #{migrate_transactionfact_sql()}
      #{migrate_transactionsourceprev_sql()}
      #{migrate_displaytext_sql()}
      #{migrate_dimstart_sql(migration_spec)}
      #{rebuild_most_indexes_sql()}
    SQL
  end
  
  def migrate_sql(migration_spec)
    mapping = migration_spec.select{ |k,v| v.to_s != "DELETE" && v.to_s != "CREATE"}
    
    <<-SQL
      #{migrate_rebuild_without_indexes_sql()}
      #{migrate_membersourceprev_sql(mapping)}
      #{migrate_memberfact_sql(mapping)}
      #{migrate_dimstart_sql(migration_spec)}
      #{rebuild_most_indexes_sql()}
    SQL
  end
  
  def migrate(migration_spec)
    db.ex(migrate_nuw_sql(migration_spec))
    db.ex("vacuum memberfact");
    db.ex("vacuum membersourceprev");
    db.ex("vacuum transactionfact");
    db.ex("vacuum transactionsourceprev");
    db.ex("vacuum displaytext");
    db.ex("vacuum memberfacthelper");
    
    db.ex("analyse memberfact");
    db.ex("analyse membersourceprev");
    db.ex("analyse transactionfact");
    db.ex("analyse transactionsourceprev");
    db.ex("analyse displaytext");
    db.ex("analyse memberfacthelper");

    # with lots of data memberfacthelper can be impossibly slow to rebuild
    db.ex("select updatememberfacthelper();");
    db.ex(rebuild_memberfacthelper_indexes_sql());
    db.ex("vacuum memberfacthelper");
    db.ex("analyse memberfacthelper");
  end
end
