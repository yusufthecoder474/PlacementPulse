class CreateUsers < ActiveRecord::Migration[7.1]
  def change
    create_table :users do |t|
      t.string :email, null: false
      t.string :password_digest, null: false
      t.string :role, null: false, default: "student"
      t.string :branch
      t.decimal :cgpa, precision: 4, scale: 2
      t.decimal :class_x_percentage, precision: 5, scale: 2
      t.decimal :class_xii_percentage, precision: 5, scale: 2
      t.boolean :standing_arrears, null: false, default: false
      t.timestamps

      t.check_constraint "role IN ('student', 'coordinator')", name: "users_role_check"
      t.check_constraint "cgpa IS NULL OR (cgpa >= 0 AND cgpa <= 10)", name: "users_cgpa_range_check"
      t.check_constraint "class_x_percentage IS NULL OR (class_x_percentage >= 0 AND class_x_percentage <= 100)",
                         name: "users_class_x_range_check"
      t.check_constraint "class_xii_percentage IS NULL OR (class_xii_percentage >= 0 AND class_xii_percentage <= 100)",
                         name: "users_class_xii_range_check"
    end

    # Case-insensitive uniqueness: "Student@Example.com" and
    # "student@example.com" must not become two accounts.
    add_index :users, "LOWER(email)", unique: true, name: "index_users_on_lower_email"
  end
end
