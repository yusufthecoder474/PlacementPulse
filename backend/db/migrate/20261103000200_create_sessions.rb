class CreateSessions < ActiveRecord::Migration[7.1]
  def change
    create_table :sessions do |t|
      t.references :user, null: false, foreign_key: true
      # SHA256 hex digest of the token. The plaintext token is returned to the
      # client exactly once at login and is never stored in the database.
      t.string :token_digest, null: false
      t.datetime :expires_at, null: false
      t.timestamps
    end

    add_index :sessions, :token_digest, unique: true
  end
end
