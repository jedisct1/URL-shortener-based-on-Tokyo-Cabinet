require "rubygems"
require "sinatra"
require "haml"
require "sass"
require "openssl"
require "base58"
require "uri"
require "oklahoma_mixer"
require "rack/csrf"
require "rack/cache"

KEY = "insert a secret key here"
DOMAIN = "sk.tl"

set :public_folder, File.dirname(__FILE__) + '/../public'
set :views, File.dirname(__FILE__) + '/views'
set :port, 4568
set :sessions, true
use Rack::Csrf, :raise => false

use Rack::Cache do
  set :verbose, false
  set :metastore, "heap:/"
  set :entitystore, "heap:/"  
end

get "/favicon.ico" do
  expires 86400, :public
end

get "/squeezer.css" do
  response["Content-Type"] = "text/css"
  expires 3600, :public
  sass :squeezer
end

get "/" do
  expires 3600, :private
  response["X-Content-Security-Policy"] = "allow 'self'"
  haml :squeezer
end

post "/" do
  expires 3600, :private
  response["X-Content-Security-Policy"] = "allow 'self'"
  uri = params[:uri] || ""
  uri.strip!
  uri = uri.gsub(%r(//+), "/").sub("/", "//")
  if uri.empty?
    status 406
    return "Missing URI"
  end
  uri = "http://#{uri}" unless /^(http|https|ftp|ftps):\/\/.+\./i.match(uri)
  begin
    puri = URI::parse(uri)
  rescue URI::InvalidURIError
    status 400
    return "Mmmm... doesn't look like a valid URI..."
  end
  puri.scheme = puri.scheme.downcase
  puri.host = puri.host.downcase
  puri.path = "" if puri.path == "/"
  if puri.host == DOMAIN
    status 406
    return "No need to shorten myself"
  end
  uri = puri.to_s
  sid = Base58::encode(OpenSSL::HMAC.hexdigest(OpenSSL::Digest.new("sha512"), KEY, uri)[0..10].to_i(16))
  tc { |db| db[sid] = uri }
  @newuri = "https://#{DOMAIN}/#{sid}"
  haml :newuri_show
end

get "/:sid" do
  response["X-Content-Security-Policy"] = "allow 'self'"  
  sid = params[:sid].strip
  if sid.empty?
    status 406
    return "Missing identifier"
  end
  uri = nil
  tc { |db| uri = db[sid] }
  if uri.nil?
    status 404
    return "Not found"
  end
  redirect uri
end

def tc(&block)
  OKMixer.open("../data/squeezer.tch") { |db| yield db }
end
