require 'openssl'
require 'securerandom'
require 'sinatra'
require_relative 'deploy'

deployer = Deploy.new

def verify_key(tempfile)
  key = OpenSSL::PKey.read tempfile.read
  Dir['keys/*'].any? do |filename|
    pubkey = OpenSSL::PKey.read File.read(filename)
    test_data = SecureRandom.alphanumeric(128)
    digest = OpenSSL::Digest::SHA256.new
    pubkey.verify(digest, key.sign(digest, test_data), test_data)
  end
end

set :public_folder, __dir__ + '/static'

get '/' do
  @messages = []
  erb :index
end

get '/output' do
  @messages = []
  erb :output
end

post '/deploy' do
  unless params[:key].is_a?(Hash) && !params[:key][:filename].nil? && !params[:key][:tempfile].nil?
    halt 400
  end

  begin
    verified = verify_key params[:key][:tempfile]
    if verified
      status, message = deployer.trigger
      @status = status
      @messages = [message]
      erb :index
    else
      @status = false
      @messages = ['Unrecognized key provided.']
      erb :index
    end
  rescue => ex
    @status = false
    @messages = [ex.message]
    erb :index
  end
end

post '/output' do
  unless params[:key].is_a?(Hash) && !params[:key][:filename].nil? && !params[:key][:tempfile].nil?
    halt 400
  end

  begin
    verified = verify_key params[:key][:tempfile]
    if verified
      @status = true
      @output = File.read('/var/apps/qpixel/deploy_output.log')
      erb :output
    else
      @status = false
      @messages = ['Unrecognized key provided.']
      erb :output
    end
  rescue => ex
    @status = false
    @messages = [ex.message]
  end
end
