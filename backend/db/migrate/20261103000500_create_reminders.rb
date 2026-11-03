class CreateReminders < ActiveRecord::Migration[7.1]
  def change
    create_table :reminders do |t|
      t.references :user, null: false, foreign_key: true
      t.references :notice, null: false, foreign_key: true
      t.string :kind, null: false
      t.datetime :scheduled_at, null: false
      t.datetime :sent_at
      t.datetime :failed_at
      t.text :error_message
      t.timestamps

      t.check_constraint "kind IN ('publication', 'reminder_24h', 'reminder_2h')",
                         name: "reminders_kind_check"
    end

    # One reminder row per (student, notice, kind). This is the database-level
    # idempotency guarantee: duplicate publishes or duplicate job runs cannot
    # create a second row. It does NOT by itself guarantee exactly-once email
    # delivery (see README: a crash between sending and recording sent_at
    # can still duplicate an email).
    add_index :reminders, %i[user_id notice_id kind], unique: true
    add_index :reminders, :scheduled_at
    add_index :reminders, :sent_at
  end
end
