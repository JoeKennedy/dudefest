class HomeController < ApplicationController
  def index
    @daily_video = DailyVideo.of_the_day
    @thing = Thing.of_the_day
    @tip = Tip.of_the_day
    @position = Position.of_the_day
    @events = Event.this_day
  end
end
