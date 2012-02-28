# Add error handling code to the Sinatra::Base
class Sinatra::Base   
  set :raise_errors, false
  set :show_exceptions, false

  not_found do
    erb :not_found
  end
  
  error do
    @error = env['sinatra.error']
    
    Pony.mail({
      :to   => Config['email_errors']['to'],
      :from => Config['email_errors']['from'],
      :subject => "[Error] #{@error.message}",
      :body => erb(:error_email, layout: false)
    })
    
    erb :error
  end
end