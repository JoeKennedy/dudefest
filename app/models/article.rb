class Article < ActiveRecord::Base
  include ModelConfig, ColumnSchedule
  mount_uploader :image, ImageUploader
  process_in_background :image

  after_initialize :initialize_article, on: :new
  before_validation :determine_status
  before_validation :sanitize

  belongs_to :column, inverse_of: :articles, counter_cache: true
  belongs_to :creator, class_name: 'User'
  belongs_to :editor, class_name: 'User'
  belongs_to :movie, inverse_of: :review
  has_many :article_authors, dependent: :destroy, inverse_of: :article,
                             autosave: true
  has_many :authors, through: :article_authors

  validates_associated :creator
  validates_associated :editor, allow_blank: true
  validates_associated :authors
  validates :title, presence: true, uniqueness: true, length: { in: 8..70 }
  validates :body, presence: true, uniqueness: true, length: { in: 300..15000 }
  validates :column, :creator, presence: true
  validates :authors, presence: true, on: :update
  validate :creator_is_author

  accepts_nested_attributes_for :article_authors

  rails_admin do
    object_label_method :title
    navigation_label 'Articles'
    configure :image, :jcrop
    configure :article_authors do
      visible false
    end

    list do
      sort_by 'status, date desc, created_at'
      include_fields :date, :column, :title, :authors, :status
      configure :date do
        strftime_format '%Y-%m-%d'
        column_width 75
      end
      configure :column do
        column_width 60
      end
      configure :status do
        column_width 95
      end
    end

    edit do
      field :column do
        associated_collection_scope do
          Proc.new { |scope|
            scope = scope.where.not(column: Column.movie.column)
          }
        end
      end
      include_fields :column, :title do
        read_only do
          bindings[:object].class == 'Article' && bindings[:object].movie.present?
        end
      end
      field :authors do
        orderable true
      end
      field :image do
        jcrop_options aspectRatio: 400.0/300.0
        fit_image true
      end
      field :remote_image_url do
        label 'Or Image URL'
      end
      field :image_old do
        read_only true
      end
      field :body, :rich_editor do
        config( { insert_many: true, allow_embed: true } )
        help 'Required. This is where your actual article goes dumbass.'
      end
      field :byline, :ck_editor do
        help 'Optional. If you don\'t want to use your default byline for '\
             'this article, then fill one out here.'
      end
      field :finalized do
        visible do
          binding[:object].class == 'Article' && bindings[:object].finalizable?
        end
      end
      field :published do
        visible do
          bindings[:object].class == 'Article' && bindings[:object].finalized?
        end
      end
    end

    nested do
      include_fields :column, :title, :authors do
        visible false
      end
    end

    create do
      configure :authors do
        visible false
      end
    end

    show do
      include_fields :column, :title, :authors, :status, :body
      configure :body do
        pretty_value do
          value.html_safe
        end
      end
    end
  end

  public
    def status?(base_status)
      base_status.to_s == self.status
    end

    def finalizable?
      if self.status.present? && self.status > '2'
        self.editor_or_admin? && !self.finalized?
      else
        false
      end
    end

    def display_title
      if Column.guyde == self.column
        self.column.column + ': ' + self.title
      else
        self.title
      end
    end

    def is_movie_review?
      self.column.present? && self.column.column == Column.movie
    end

    def display_date
      self.date.strftime('%B %d, %Y')
    end

    def type
      self.column.short_name.upcase
    end

    def display_image
      if self.image.present?
        self.image_url(:display).to_s
      elsif self.image_old.present?
        self.image_old 
      else
        self.column.image_url(:display).to_s
      end
    end

    def display_byline
      self.byline.blank? ? self.authors.map(&:byline).join('<br>') : self.byline
    end

    def display_authors
      self.authors.map(&:name).join(', ')
    end

    def author_and_date
      'By ' + self.display_authors + ' on ' + self.display_date
    end

    def editor_or_admin?
      self.editor == User.current || User.current.role?(:admin)
    end

    def public?
      tz = 'Eastern Time (US & Canada)'
      self.published? && self.date <= DateTime.now.in_time_zone(tz).to_date
    end

    def self.public
      self.order(date: :desc, creator_id: :asc).select { |a| a.public? }
    end

    def author_ids=(ids)
      ids = ids.map(&:to_i).select { |i| i > 0 }
      #ids |= [User.current.id] if self.new_record?
      unless ids == (current_ids = article_authors.map(&:author_id)) 
        (current_ids - ids).each { |id|
          article_authors.select { |aa|
            aa.author_id == id 
          }.first.mark_for_destruction
        }
        ids.each_with_index do |id, i|
          if current_ids.include? (id)
            article_authors.select { |aa| aa.author_id == id }.first.position = (i + 1)
          else
            article_authors.build( { author_id: id, position: (i + 1) } )
          end
        end
      end
    end

  private
    def initialize_article
      if self.new_record?
        self.creator ||= User.current
        self.article_authors.build(author: User.current, position: 1)
      end
    end

    def determine_status
      if self.new_record?
        self.finalized = self.published = false
        self.status = '1 - Created'
        self.editor = set_editor
      elsif self.published?
        self.status = '5 - Published'
        if self.published_at.nil?
          self.published_at = Time.now
          self.date = self.assign_date()
        end
      elsif self.finalized?
        self.status = '4 - Finalized'
        self.finalized_at ||= Time.now
      elsif self.editor == User.current || self.class.owner == User.current
        self.status = '2 - Edited'
        self.editor ||= User.current
        self.edited_at = Time.now
      elsif self.status?('2 - Edited') && self.creator == User.current
        self.status = '3 - Responded'
        self.responded_at = Time.now
      end
    end

    def creator_is_author
      unless article_authors.select { |aa| !aa.marked_for_destruction? }
                            .select { |aa| aa.author == self.creator }.present?
        errors.add(:authors, 'need to include the original author')
      end
    end

    def set_editor
      User.current == self.class.owner ? User.find(5) : self.class.owner
    end

    def is_movie_review?
      self.column.present? && self.column == Column.movie
    end

    def sanitize
      # Sanitize.clean!(self.title)
      # Sanitize.clean!(self.body, Sanitize::Config::RELAXED)
      if self.byline.present?
        Sanitize.clean!(self.byline, Sanitize::Config::BASIC)
      end
    end
end
