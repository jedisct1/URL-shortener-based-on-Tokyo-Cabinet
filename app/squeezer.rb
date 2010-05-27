require "rubygems"
require "sinatra"
require "haml"
require "sass"
require "json"
require "digest/md5"
require "base64"
require "uri"
require "oklahoma_mixer"
require "rack/csrf"
require "rack/cache"

KEY = "insert a secret key here"

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
  haml :squeezer
end

post "/" do
  expires 3600, :private
  response["X-Content-Security-Policy"] = "allow self"
  uri = params[:uri] || ""
  uri.strip!
  uri = uri.gsub(%r(//+), "/").sub("/", "//")
  if uri.empty?
    status 406
    return "Il manque l'URI..."
  end
  uri = "http://#{uri}" unless /^(http|https|ftp|ftps):\/\/.+\./i.match(uri)
  begin
    puri = URI::parse(uri)
  rescue URI::InvalidURIError
    status 400
    return "URI qui n'en est pas vraiment une"
  end
  puri.scheme = puri.scheme.downcase
  puri.host = puri.host.downcase
  puri.path = "" if puri.path == "/"
  if puri.host == "sk.tl"
    status 406
    return "On bouclerait, ce serait ballot"
  end
  uri = puri.to_s
  sid = Base64::encode64(Digest::MD5.digest(KEY + uri)).tr("+/=", "-. ")[0..5].strip
  tc { |db| db[sid] = uri }
  @newuri = "http://sk.tl/#{sid}"
  haml :newuri_show
end

get "/:sid" do  
  sid = params[:sid].strip
  if sid.empty?
    status 406
    return "Il manque un identifiant"
  end
  uri = nil
  tc { |db| uri = db[sid] }
  if uri.nil?
    status 404
    return "Introuvable"
  end
  redirect uri
end

def tc(&block)
  OKMixer.open("../data/squeezer.tch") { |db| yield db }
end
