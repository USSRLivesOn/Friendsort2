require 'net/http'
require 'sinatra'
require 'koala'

require File.dirname(__FILE__) + "/seam_carver"

enable :sessions
set :raise_errors, false
set :show_exceptions, false

FACEBOOK_SCOPE = 'friends_photos'

unless ENV["FACEBOOK_APP_ID"] && ENV["FACEBOOK_SECRET"]
  abort("missing env vars: please set FACEBOOK_APP_ID and FACEBOOK_SECRET with your app credentials")
end

before do
  # HTTPS redirect
  if settings.environment == :production && request.scheme != 'https'
    redirect "https://#{request.env['HTTP_HOST']}"
  end
end

helpers do
  def host
    request.env['HTTP_HOST']
  end

  def scheme
    request.scheme
  end

  def url_no_scheme(path = '')
    "//#{host}#{path}"
  end

  def url(path = '')
    "#{scheme}://#{host}#{path}"
  end

  def authenticator
    @authenticator ||= Koala::Facebook::OAuth.new(ENV["FACEBOOK_APP_ID"], ENV["FACEBOOK_SECRET"], url("/auth/facebook/callback"))
  end

end

# the facebook session expired! reset ours and restart the process
error(Koala::Facebook::APIError) do
  session[:access_token] = nil
  redirect "/auth/facebook"
end

get "/" do
  # Get base API Connection
  @graph  = Koala::Facebook::API.new(session[:access_token])

  # Get public details of current application
  @app  =  @graph.get_object(ENV["FACEBOOK_APP_ID"])

  if session[:access_token]
    @user    = @graph.get_object("me")
    @friends = @graph.get_connections('me', 'friends')

    #photo_metadata = @graph.fql_multiquery({
    #    "owners" => "SELECT owner, cover_object_id FROM album WHERE owner in (SELECT uid2 FROM friend WHERE uid1 = me()) AND type = 'profile'",
    #    "image_metadata" => "SELECT object_id, images FROM photo WHERE object_id IN (SELECT cover_object_id FROM #owners)"
    #})
    #photo_owners = {}
    #photo_metadata["owners"].each do |owner_picture_map|
    #  photo_owners[owner_picture_map["cover_object_id"]] = owner_picture_map["owner"]
    #end
    #@photo_dimensions = {}
    #photo_metadata["image_metadata"].each do |object_images_map|
    #  if !object_images_map["images"].nil?
    #    @photo_dimensions[photo_owners[object_images_map["object_id"]]] = {
    #        :width => object_images_map["images"].first["width"],
    #        :height => object_images_map["images"].first["height"] }
    #  end
    #end
  end
  erb :index
end


get "/test" do
  erb :index2
end

# Proxy FB images, since canvas tag ignores access-control-allow-origin header
get "/image_proxy" do
  source_uri = 'http://graph.facebook.com/' + params[:friend_id] + '/picture?type=large'
  response = get_response(source_uri)
  content_type 'image/jpeg' # Always true? TODO: detect mime type
  if params[:max_y]
    img = SeamCarver.new(response.body)
    img.carve(params[:max_y].to_i)
  else
    response.body
  end
end

# Follow redirects up to <limit> times
def get_response(uri, limit = 5)
  response = Net::HTTP.get_response(URI(uri))
  case response
  when Net::HTTPSuccess then
    response
  when Net::HTTPRedirection then
    location = response['location']
    get_response(location, limit - 1)
  else
    response.value
  end
end

get "/sign_out" do
  session[:access_token] = nil
  redirect '/'
end

get "/auth/facebook" do
  session[:access_token] = nil
  redirect authenticator.url_for_oauth_code(:permissions => FACEBOOK_SCOPE)
end

get '/auth/facebook/callback' do
	session[:access_token] = authenticator.get_access_token(params[:code])
	redirect '/'
end
