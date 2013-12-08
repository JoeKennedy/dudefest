class CreateVideos < ActiveRecord::Migration
  def change
    create_table :videos do |t|
      t.string :title
      t.string :source
      t.date :date
      t.integer :reviewer_id
      t.datetime :reviewed_at
      t.boolean :reviewed
      t.integer :creator_id

      t.timestamps
    end
  end
end
