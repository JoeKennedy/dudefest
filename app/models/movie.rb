class Movie < ApplicationRecord
  include CurrentUser, WeeklyOutput

  before_validation :initialize_movie, on: :create
  before_validation :set_review
  before_validation :sanitize
  after_destroy :destroy_review

  has_paper_trail
  has_many :movie_genres, dependent: :destroy
  has_many :genres, through: :movie_genres
  has_one :review, class_name: 'Article', inverse_of: :movie
  has_many :credits, dependent: :destroy, inverse_of: :movie, autosave: true
  has_many :name_variants, through: :credits
  has_many :ratings, inverse_of: :movie, dependent: :destroy
  belongs_to :creator, class_name: 'User', inverse_of: :movies,
                       counter_cache: true

  validates_associated :review
  validates_associated :genres
  validates_associated :ratings
  validates_associated :name_variants
  validates :genres, presence: true
  validates :title, presence: true, uniqueness: true, length: { in: 3..60 }
  validates :release_date, :review, :genres, :ratings, presence: true
  # This is no longer necessary, as we're doing more recent films
  # validate :at_least_two_ratings
  validate :at_least_one_name_variant

  accepts_nested_attributes_for :review, :ratings, :credits

  rails_admin do
    object_label_method :title
    navigation_label 'Movies'
    configure :credits do
      visible false
    end

    list do
      sort_by :title
      include_fields :title, :reviewed_ratings
      field :unreviewed_ratings do
        sortable 'ratings_count - reviewed_ratings'
      end
      field :average_rating do
        sortable 'total_rating / reviewed_ratings'
      end
      field :your_rating do
        formatted_value do
          object.rating_by(current_user).try(:rating)
        end
      end
      field :your_rating_reviewed, :boolean do
        label 'Rating reviewed'
        formatted_value do
          object.rating_by(current_user).try(:reviewed)
        end
        pretty_value do
          # Has to override the boolean pretty_value method
          case formatted_value
          when nil   then %(<span class='label label-default'>&#x2012;</span>)
          when false then %(<span class='label label-danger'>&#x2718;</span>)
          when true  then %(<span class='label label-success'>&#x2713;</span>)
          end.html_safe
        end
      end
      include_fields :reviewed_ratings, :average_rating, :unreviewed_ratings,
                     :your_rating, :your_rating_reviewed do
        column_width 50
      end
    end

    edit do
      include_fields :title, :release_date, :genres, :name_variants
      configure :title do
        help 'Required. CAPITALIZE IT. If you reference any other movies in '\
             'your review, capitalize their names too.'
      end
      configure :release_date do
        help 'Required. Should be the BoxOfficeMojo.com release date.'
      end
      configure :genres do
        help ('Required. Try to do at most two genres.<br>'\
              'Three is acceptable, but should be used sparingly.').html_safe
      end
      configure :name_variants do
        label 'Dudes'
        orderable true
        help ('Required. If there aren\'t any dudes in it, put N/A.<br>'\
              'If there are dudes in it, list them in order of importance.<br>'\
              'Feel free to list nicknames or pseudonyms or what not.<br>'\
              'Like Sir Nicholas Cage, The Fresh Prince, The guy from '\
              '_______, etc.').html_safe
      end
      include_fields :review, :ratings
      configure :review do
        active true
      end
      configure :ratings do
        active true
      end
      field :weekly_output do
        read_only true
        help 'Remember to add one to your ratings output, even if you\'re '\
             'the one who reviewed the movie!'
      end
    end
  end

  public
    def complete_ratings 
      self.ratings.where(reviewed: true)
    end 

    def title_with_year
      self.title.upcase + ' (' + self.release_date.year.to_s + ')'
    end

    def author_and_date
      r = self.review
      'Reviewed by ' + r.display_authors + '<br>on ' + r.display_date
    end

    def average_rating
      if self.reviewed_ratings.present? && self.reviewed_ratings > 0
        '%.2f' % (self.total_rating / self.reviewed_ratings)
      else
        nil
      end
    end

    def unreviewed_ratings
      self.ratings_count.to_i - self.reviewed_ratings.to_i 
    end

    def name_variant_ids=(ids)
      ids = ids.map(&:to_i).select { |i| i > 0 }
      unless ids == (current_ids = credits.map(&:name_variant_id)) 
        (current_ids - ids).each { |id|
          credits.select { |c| 
            c.name_variant_id == id 
          }.first.mark_for_destruction
        }
        ids.each_with_index do |id, i|
          if current_ids.include? (id)
            credits.select { |c| c.name_variant_id == id }.first.position = (i + 1)
          else
            credits.build( { name_variant_id: id, position: (i + 1) } )
          end
        end
      end
    end

    # Necessary for rails_admin review booleans
    # def creatable?; self.review.present? ? self.review.creatable? : true end
    # def rewritable?; self.review.present? ? self.review.rewritable? : false end
    # def finalizable?; self.review.nil? ? false : self.review.finalizable? end
    # def finalized?; self.review.present? ? self.review.finalized? : false end
    # def reviewed?; self.review.present? ? self.review.reviewed? : false end
    # def published?; self.review.present? ? self.review.published? : false end

    # Necessary for rails_admin ratings boolean
    # def revie#wable?
    #   self.ratings.any? ? self.ratings.first.owner_or_admin? : false
    # end

    def destroy_review  
      self.review.destroy if self.review && !self.review.destroyed?
    end

    def rating_by(user)
      self.ratings.find_by(creator: user)
    end

    def self.finalized
      self.includes(:review).order('articles.date desc')
                            .select { |m| m.review.public? }
    end

    def self.top(x)
      self.where.not(reviewed_ratings: 0)
          .order('total_rating / reviewed_ratings desc')
          .select { |m| m.review.public? }.first(x)
    end

    def self.bottom(x)
      self.where.not(reviewed_ratings: 0)
          .order('total_rating / reviewed_ratings')
          .select { |m| m.review.public? }.first(x)
    end

  private
    def initialize_movie
      if self.new_record?
        self.reviewed_ratings ||= self.total_rating ||= 0 
        self.creator = self.current_user
      end
    end

    def set_review
      if self.review.present?
        self.review.column = Column.movie if self.new_record?
        self.review.title = 'Review of ' + self.title
      end
    end

    def at_least_two_ratings
      if self.review.published? && self.reviewed_ratings < 2
        errors.add(:review, 'needs at least 2 reviewed ratings')
      end
    end

    def at_least_one_name_variant
      if self.credits.select { |c| !c.marked_for_destruction? }.size < 1
        errors.add(:name_variants, 'need to have least 1')
      end
    end

    def sanitize
      self.title = Sanitize.fragment(self.title)
    end

end
