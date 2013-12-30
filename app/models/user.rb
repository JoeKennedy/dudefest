class User < ActiveRecord::Base
  ROLES = %w[admin editor reviewer writer reader]

  # Include default devise modules. Others available are:
  # :confirmable, :lockable, :timeoutable and :omniauthable
  devise :database_authenticatable,
       # :registerable, :recoverable, 
         :rememberable, :trackable, :validatable

  validates :username, presence: true, length: { in: 4..28 }, uniqueness: true
  validates :name, presence: true, length: { in: 6..40 }

  has_many :tips, foreign_key: 'creator_id'
  has_many :reviewed_tips, foreign_key: 'reviewer_id'
  has_many :events, foreign_key: 'creator_id'
  has_many :reviewed_events, foreign_key: 'reviewer_id'
  has_many :daily_videos, foreign_key: 'creator_id'
  has_many :reviewed_daily_videos, foreign_key: 'reviewer_id'
  has_many :things, foreign_key: 'creator_id'
  has_many :reviewed_things, foreign_key: 'reviewer_id'
  has_many :positions, foreign_key: 'creator_id'
  has_many :reviewed_positions, foreign_key: 'reviewer_id'
  has_many :articles, foreign_key: 'creator_id'
  has_many :edited_articles, foreign_key: 'editor_id'
  has_many :ratings, foreign_key: 'creator_id'
  has_many :reviewed_ratings, foreign_key: 'reviewer_id'
  has_many :movies, foreign_key: 'creator_id'

  rails_admin do
    object_label_method :username
    navigation_label 'Users'
    list do
      sort_by :username
      include_fields :username, :role, :tips_count, :daily_videos_count
      include_fields :positions_count, :events_count, :things_count
      include_fields :articles_count, :movies_count, :ratings_count

      configure :role do
        visible do
          User.current.role?(:admin)
        end
      end
      configure :tips_count do
        label 'Tips'
        column_width 40
      end
      configure :daily_videos_count do
        label 'Videos'
        column_width 55
      end
      configure :positions_count do
        label 'Positions'
        column_width 75
      end
      configure :events_count do
        label 'Events'
        column_width 55
      end
      configure :things_count do
        label 'Things'
        column_width 55
      end
      configure :articles_count do
        label 'Articles'
        column_width 60
      end
      configure :movies_count do
        label 'Movies'
        column_width 60
      end
      configure :ratings_count do
        label 'Ratings'
        column_width 60
      end
    end

    edit do
      include_fields :username, :name, :email, :password, :password_confirmation
      include_fields :role
      configure :role do
        visible do
          User.current.role? :admin
        end
      end
    end
  end

  public
    def role?(base_role)
      ROLES.index(base_role.to_s) >= ROLES.index(role)
    end

    def role_enum
      ROLES
    end

    def self.current
      Thread.current[:current_user]
    end

    def self.current=(user)
      Thread.current[:current_user] = user
    end
end
