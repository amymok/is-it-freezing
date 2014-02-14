Bundler.require(:default, ENV['RACK_ENV'])
require 'active_support/cache'
require 'action_view'

Dotenv.load if defined?(Dotenv)

CITY = ENV['CITY']
STATE = ENV['STATE']
API_KEY = ENV['WUNDERGROUND_API_KEY']
ENDPOINT = 'http://api.wunderground.com/api/%s/conditions/q/%s/%s.json' % [API_KEY,STATE,CITY]

Connection = Faraday.new(url: ENDPOINT) do |conn|
  conn.response :caching do
    ActiveSupport::Cache::MemoryStore.new(expires_in: 300)
  end

  conn.response :json
  conn.response :logger

  conn.adapter Faraday.default_adapter
end

class CurrentWeather < Struct.new(:response)
  include ActionView::Helpers::DateHelper

  SNOW_INDICATOR = "snow".freeze
   FREEZE_TEMP = 32.0
   WARM_TEMP = 60.0
   HOT_TEMP = 80.0

  # CITY_STATE = response['current_observation']['display_location']['full']

  def self.update(conn)
    new(conn.get.body)
  end

  def city_state
    response['current_observation']['display_location']['full']
  end

  def snowing?
    weather = response['current_observation']['weather'].downcase
    weather.include?(SNOW_INDICATOR) ? "Yep" : "Nope"
  end

   def freezing?
    temp_f = response['current_observation']['temp_f']
    case
    when temp_f <= FREEZE_TEMP
      "Yup!"
    when temp_f > FREEZE_TEMP && temp_f <= WARM_TEMP
      "Nope, but it is still a bit chilly"
    when temp_f > WARM_TEMP && temp_f <= HOT_TEMP
      "Nope, it is super nice and warm outside!"
    else
      "Nope, it is burning hot!!"
    end
   end

  def last_updated 
    time_ago_in_words Time.at(response['current_observation']['local_epoch'].to_i)
  end

  def icon_url
    response['current_observation']['icon_url']
  end
end

get '/' do
  @weather = CurrentWeather.update(Connection)
  erb :index
end
