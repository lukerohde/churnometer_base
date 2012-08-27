require './lib/churn_db'
require 'json'

class ServiceRequestHandlerAutocomplete
  def initialize(churnobyl_app)
    services = { 
      'displaytext' => ServiceAutocompleteDisplaytext
    }

    churnobyl_app.get "/services/autocomplete/:handler_name" do |handler_name|
      content_type :json

      service_class = services[handler_name]
      if service_class.nil?
        "No autocomplete handler for '#{handler_name}'"
      else
        service = service_class.new(ChurnDB.new, params)
        service.execute
      end
    end
  end
end
