# SYNTHETIC demo data only. These users and this notice are invented for
# local development and demos. They are NOT real students, NOT a real
# company, and NOT a real placement notice. Do not use them for any
# real-world accuracy or impact claim.
#
# Demo credentials (development only; change them before any shared use):
#   coordinator: coordinator@example.com / password1234
#   student:     student@example.com     / password1234

coordinator = User.find_or_create_by!(email: "coordinator@example.com") do |user|
  user.password = "password1234"
  user.role = "coordinator"
end

student = User.find_or_create_by!(email: "student@example.com") do |user|
  user.password = "password1234"
  user.role = "student"
  user.branch = "CSE"
  user.cgpa = 8.2
  user.class_x_percentage = 88
  user.class_xii_percentage = 85
  user.standing_arrears = false
end

Notice.find_or_create_by!(company: "Acme Technologies", category: "Software Development Engineer") do |notice|
  notice.drive_date = Date.new(2027, 2, 10)
  notice.eligible_branches = %w[CSE IT ECE]
  notice.minimum_cgpa = 7.5
  notice.minimum_class_x_percentage = 75
  notice.minimum_class_xii_percentage = 70
  notice.arrears_rule = "no_standing_arrears"
  notice.ctc = "12 LPA"
  notice.stipend = "₹30,000/month"
  notice.registration_deadline = Time.zone.local(2027, 1, 20, 23, 59)
  notice.registration_url = "https://example.com/acme-register"
  notice.location = "Bengaluru"
  notice.source_text = "SYNTHETIC demo notice text."
  notice.status = "published"
  notice.publisher = coordinator
end

puts "Seeded SYNTHETIC demo users: coordinator@example.com, student@example.com"
puts "Seeded SYNTHETIC demo notice: Acme Technologies (published)"
