
workers Integer(ENV['WEB_CONCURRENCY'] || 2)
threads_count = Integer(ENV['MAX_THREADS'] || 5)
threads threads_count, threads_count

app_dir = File.expand_path("../..", __FILE__)
preload_app!

rackup      "#{app_dir}/config.ru"
port        ENV['PORT']     || 9292
rack_env = ENV['RACK_ENV'] || "production"
environment rack_env

# Set up socket location
bind "unix://#{app_dir}/pids/puma.sock"

# Logging
stdout_redirect "#{app_dir}/log/puma.stdout.log", "#{app_dir}/log/puma.stderr.log", true

# Set master PID and state locions
pidfile "#{app_dir}/pids/puma.pid"
state_path "#{app_dir}/pids/puma.state"

#daemonize
activate_control_app "unix://#{app_dir}/pids/pumactl.sock", { no_token: true }

on_worker_boot do
  # Worker specific setup for Rails 4.1+
  # See: https://devcenter.heroku.com/articles/
  # deploying-rack-applications-with-the-puma-web-server#on-worker-boot
  #  ActiveRecord::Base.establish_connection
end
