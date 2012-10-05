require './lib/dimension'

class ChurnometerApp
  attr_reader :dimensions

  class MissingConfigDataException < RuntimeError
    def initialize(message, churnometer_app)
      full_message = "#{message} in config file(s) #{churnometer_app.config_filenames.join(', ')}"
      super(full_message)
    end
  end

  def initialize
    # dbeswick: temporary, to ease migration to ChurnobylApp class.
    Object.const_set(:Config, config_hash().values.inject({}, :merge) )
  end

  # The first iteration of Churnometer retrieved its results by calling SQL functions.
  # Set 'use_new_query_generation_method: true' in config.yaml to use the new method that produces the 
  # same output, but builds the query string in the Ruby domain rather than SQL.
  def use_new_query_generation_method?
    config_value('use_new_query_generation_method') == true
  end

  # All available data dimensions.
  def dimensions
    @dimensions ||= custom_dimensions() + builtin_dimensions()
  end

  # Dimensions for Churnometer's internal use.
  def builtin_dimensions
    @builtin_dimensions ||=
      begin
        dimensions = Dimensions.new
        dimensions.add(Dimension.new('status'))
        dimensions
      end
  end

  # Dimensions that are defined by users in the config file.
  def custom_dimensions
    @custom_dimensions ||= 
      begin
        dimensions = Dimensions.new

        if !config_has_value?('dimensions')
          raise MissingConfigDataException.new("No 'dimensions' category was found", self)
        end

        dimensions.from_config_hash(config_value('dimensions'))

        dimensions
      end
  end

  # The dimensions that should be displayed to the user in the filter form's 'groupby' dropdown.
  def groupby_display_dimensions(is_leader, is_admin)
    roles = []

    if is_leader
      roles << 'leader'
    end
    
    if is_admin
      roles << 'admin'
    end

    final_dimensions = custom_dimensions().select do |dimension|
      dimension.roles_can_access?(roles)
    end

    Dimensions.new(final_dimensions)
  end

  # The dimension that expresses work site or company information.
  def work_site_dimension
    dimensions().dimension_for_id_mandatory(config_value('work_site_dimension_id'))
  end

  def config_filenames
    config_hash().keys
  end

  # This method is public mostly for the use of legacy code that uses the old settings method.
  #
  # When creating new config data, please create an accessor for that data that calls config_value and
  # returns appropriate data, rather than asking users of the data to call config_value themselves.
  #
  # i.e.: 
  #
  # churnometer_app.work_site_dimension
  #
  # instead of
  #
  # churnometer_app.dimensions[churnometer_app.config_value('work_site_dimension')]
  def config_value(config_key)
    config_hash().each_value do |hash|
      value = hash[config_key]
      return value if value
    end

    return nil
  end

  def config_has_value?(config_key)
    @config_hash.values.find{ |hash| hash.has_key?(config_key) } != nil
  end

protected
  def config_filename
    "./config/config.yaml"
  end

  def site_config_filename
    "./config/config_site.yaml"
  end

  def config_hash
    @config_hash ||= 
      begin
        config = {}

        if !File.exist?(config_filename())
          raise MissingConfigDataException.new("File not found", self)
        end

        yaml = File.read(config_filename())

        # Convert tabs to spaces so there's one less thing for users to get wrong.
        yaml.gsub!("\t", '    ')

        config[config_filename()] = YAML.load(yaml)

        if File.exist?(site_config_filename())
          yaml = File.read(site_config_filename())

          yaml.gsub!("\t", '    ')

          config[site_config_filename()] = YAML.load(yaml)
        end

        config
      end
  end
end


