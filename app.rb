require 'openssl'
require 'securerandom'
require 'sinatra'

set :public_folder, __dir__ + '/static'

get '/' do
  @messages = []
  erb :index
end

post '/deploy' do
  unless params[:key].is_a?(Hash) && !params[:key][:filename].nil? && !params[:key][:tempfile].nil?
    halt 400
  end

  begin
    key = OpenSSL::PKey.read params[:key][:tempfile].read
    verified = Dir['keys/*'].any? do |filename|
      pubkey = OpenSSL::PKey.read File.read(filename)
      test_data = SecureRandom.alphanumeric(128)
      digest = OpenSSL::Digest::SHA256.new
      pubkey.verify(digest, key.sign(digest, test_data), test_data)
    end
    if verified
      pid = spawn '/var/apps/qpixel/deploy'
      Process.detach pid
      @status = true
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
