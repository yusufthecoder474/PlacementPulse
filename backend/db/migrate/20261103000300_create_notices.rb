class CreateNotices < ActiveRecord::Migration[7.1]
  def change
    create_table :notices do |t|
      t.string :company
      t.string :category
      t.date :drive_date
      t.string :eligible_branches, array: true, default: []
      t.decimal :minimum_cgpa, precision: 4, scale: 2
      t.decimal :minimum_class_x_percentage, precision: 5, scale: 2
      t.decimal :minimum_class_xii_percentage, precision: 5, scale: 2
      t.string :arrears_rule
      t.string :ctc
      t.string :stipend
      t.datetime :registration_deadline
      t.string :registration_url
      t.string :location
      # Raw coordinator-pasted text. Kept for audit/debugging and returned
      # only to coordinators; never included in student-facing responses.
      t.text :source_text
      # [{ "field" => "...", "message" => "..." }] for fields the parser
      # could not settle. Empty after a successful publish.
      t.jsonb :uncertainties, default: []
      # Fields the coordinator explicitly confirmed as "no requirement"
      # (for example, no minimum CGPA). Missing + unrestricted is publishable;
      # missing + not unrestricted blocks publication.
      t.string :unrestricted_fields, array: true, default: []
      t.string :status, null: false, default: "draft"
      t.references :publisher, foreign_key: { to_table: :users }
      t.timestamps

      t.check_constraint "status IN ('draft', 'published')", name: "notices_status_check"
      t.check_constraint "arrears_rule IS NULL OR arrears_rule IN ('no_standing_arrears', 'standing_arrears_allowed')",
                         name: "notices_arrears_rule_check"
      t.check_constraint "minimum_cgpa IS NULL OR (minimum_cgpa >= 0 AND minimum_cgpa <= 10)",
                         name: "notices_minimum_cgpa_range_check"
      t.check_constraint "minimum_class_x_percentage IS NULL OR (minimum_class_x_percentage >= 0 AND minimum_class_x_percentage <= 100)",
                         name: "notices_minimum_class_x_range_check"
      t.check_constraint "minimum_class_xii_percentage IS NULL OR (minimum_class_xii_percentage >= 0 AND minimum_class_xii_percentage <= 100)",
                         name: "notices_minimum_class_xii_range_check"
    end

    add_index :notices, :status
    add_index :notices, :registration_deadline
    add_index :notices, :company
  end
end
