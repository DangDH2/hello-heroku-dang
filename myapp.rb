require "sinatra/base"
require 'force'
require "omniauth"
require "omniauth-salesforce"
require 'pg'


class MyApp < Sinatra::Base

  configure do
    enable :logging
    enable :sessions
    set :show_exceptions, false
    set :session_secret, 'SECRET'
  end

  use OmniAuth::Builder do
    provider :salesforce, '3MVG9ZL0ppGP5UrANLO8HYBR8B8FgZExewEiDzHjbViVJzYnWR4itmKIDI6gx4325dVbzXbHEJbwEbddJ2x7l', '8725184704941093944'
  end

  before /^(?!\/(auth.*))/ do   
    redirect '/authenticate' unless session[:instance_url]
  end


  helpers do
    def client
      @client ||= Force.new instance_url:  session['instance_url'], 
                            oauth_token:   session['token'],
                            refresh_token: session['refresh_token'],
                            client_id:     '3MVG9ZL0ppGP5UrANLO8HYBR8B8FgZExewEiDzHjbViVJzYnWR4itmKIDI6gx4325dVbzXbHEJbwEbddJ2x7l',
                            client_secret: '8725184704941093944'
    end

  end


  get '/' do
    logger.info "Visited home page"
    @accounts= client.query("select Id, Name from Account")    

    uri = URI.parse(ENV['DATABASE_URL'])
    postgres = PG.connect(uri.hostname, uri.port, nil, nil, uri.path[1..-1], uri.user, uri.password)

    @lcaccounts  = postgres.exec('SELECT ID,Name,Description FROM helloherokudang.account')
    
    erb :index
  end


  get '/authenticate' do
    redirect "/auth/salesforce"
  end


  get '/auth/salesforce/callback' do
    logger.info "#{env["omniauth.auth"]["extra"]["display_name"]} just authenticated"
    credentials = env["omniauth.auth"]["credentials"]
    session['token'] = credentials["token"]
    session['refresh_token'] = credentials["refresh_token"]
    session['instance_url'] = credentials["instance_url"]
    redirect '/'
  end

  get '/auth/failure' do
    params[:message]
  end

  get '/unauthenticate' do
    session.clear 
    'Goodbye - you are now logged out'
  end

  error Force::UnauthorizedError do
    redirect "/auth/salesforce"
  end

  error do
    "There was an error.  Perhaps you need to re-authenticate to /authenticate ?  Here are the details: " + env['sinatra.error'].name
  end

  run! if app_file == $0

end
