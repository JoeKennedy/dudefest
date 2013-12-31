# RailsAdmin config file. Generated on November 24, 2013 19:57
# See github.com/sferik/rails_admin for more informations

RailsAdmin.config do |config|
  config.authorize_with :cancan

  #included = ['User', 'Tip', 'Event', 'Position', 'ThingCategory',
  #                   'Thing', 'DailyVideo', 'Article', 'Column', 'Genre',
  #                   'NameVariant']
  INCLUDED = %w(User Tip Event Position ThingCategory Thing DailyVideo Article
                Column Genre NameVariant Movie Rating Model)

  ################  Global configuration  ################

  # Set the admin name here (optional second array element will appear in red). For example:
  config.main_app_name = ['Dudefest', 'Douchebag Central (Admin Page)']
  # or for a more dynamic name:
  # config.main_app_name = Proc.new { |controller| [Rails.application.engine_name.titleize, controller.params['action'].titleize] }

  # RailsAdmin may need a way to know who the current user is]
  config.current_user_method { current_user } # auto-generated

  # If you want to track changes on your models:
  INCLUDED.each do |model|
    config.audit_with :history, model
  end

  # Or with a PaperTrail: (you need to install it first)
  # config.audit_with :paper_trail, 'User'

  # Display empty fields in show views:
  # config.compact_show_view = false

  # Number of default rows per-page:
  # config.default_items_per_page = 20

  # Exclude specific models (keep the others):
  # config.excluded_models = ['Event', 'Position', 'Thing', 'ThingCategory', 'Tip', 'User', 'Video']

  #config.excluded_models =
  #Dir.glob(Rails.root.join('app/models/concerns/**.rb')).map { |p| 
  #  'Concerns::' + File.basename(p, '.rb').camelize
  #}

  #config.excluded_models += ['MovieGenre']
  #config.included_models = %w(User Tip Event Position ThingCategory Thing DailyVideo Article
  #                            Movie Column Genre NameVariant)

  config.included_models = INCLUDED

end