require './lib/settings.rb'

class ChurnPresenter_Form
  
  include ChurnPresenter_Helpers
  include Settings

  def initialize(app, request, group_dimensions)
    @app = app
    @request = request
    @group_dimensions = group_dimensions
  end
  
  def [](index)
    @request.params[index]
  end
  
  def filters
    if @filters.nil?
      @filters = Array.new
      
      f1 = @request.parsed_params[Filter].reject{ |column_name, id | id.empty? }
      f1 = f1.reject{ |column_name, id | column_name == 'status' }

      if !f1.nil?
        f1.each do |column_name, ids|
          Array(ids).each do |id|
            if (filter_value(id) != '')
              dimension = @group_dimensions.dimension_for_id(column_name)

              i = (Struct.new(:name, :group, :id, :display, :type)).new
              i[:name] = column_name
              i[:group] = dimension.name
              i[:id] = filter_value(id)
              i[:display] = @request.db.get_display_text(dimension, filter_value(id))
              i[:type] = (id[0] == '-' ? "disable" : ( id[0] == '!' ? "invert" : "apply" ))
              @filters << i
            end
          end
        end
      end 
    end
    
    @filters
  end
  
  def row_header_id_list
    @request.data.group_by{ |row| row['row_header1_id'] }.collect{ | rh | rh[0] }.join(",")
  end

  def output_group_selector(selected_group_id, control_name, control_id='')
    output = "<select name='#{control_name}' id='#{control_id}'>"

    @group_dimensions.sort_by { | d | d.name }.each do |dimension|
      attributes = 
        if dimension.id == selected_group_id
          "selected='selected'"
        else
          ""
        end
      
      output << "<option value='#{h dimension.id}' #{attributes}>#{h dimension.name}</option>"
    end

    output << "</select>"
    output
  end

  def output_filter_group_search_term_editor
    <<-EOS
			<input type=text id=search_term_add_text onfocus='$("#search_term_add_text").autocomplete("search");'/>
			<input type=hidden id=search_term_add_id_hidden />
		  <input type=hidden id=search_term_filter_count_hidden value=#{filters.count} />
    EOS
  end

  private

  def filter_value(value)
    value.sub('!','').sub('-','')
  end
  
end
