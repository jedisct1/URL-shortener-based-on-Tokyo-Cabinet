require "rack/cache"
require "sass/plugin/rack"
require "./squeezer.rb"

set :run, false
set :environment, :production

use Rack::Cache do
  set :verbose, false
  set :metastore, "heap:/"
  set :entitystore, "heap:/"
end

run Sinatra::Application
