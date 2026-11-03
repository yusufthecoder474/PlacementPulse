class CreateRegistrations < ActiveRecord::Migration[7.1]
  def change
    create_table :registrations do |t|
      t.references :user, null: false, foreign_key: true
      t.references :notice, null: false, foreign_key: true
      t.string :status, null: false, default: "registered"
      t.datetime :registered_at
      t.timestamps
    end

    # A student has at most one registration row per notice. This unique
    # index (not just a model validation) is what makes the "I Registered"
    # action idempotent under concurrent requests.
    add_index :registrations, %i[user_id notice_id], unique: true
  end
end
