# This file should ensure all the record data needed to run the application in production.
# The data can then be loaded with the bin/rails db:seed command (or created alongside the database with db:setup).
#
# Example:
#
#   ["Action", "Comedy", "Drama", "Horror"].each do |genre_name|
#     MovieGenre.find_or_create_by!(name: genre_name)
#   end

# Clear existing data (optional - comment out if you want to preserve data)
# Village.destroy_all
# User.destroy_all
# Conference.destroy_all
# ConferenceRole.destroy_all
# UserRole.destroy_all
# Role.destroy_all

# Create or find village
village = Village.find_or_create_by!(name: "Ham Radio Village") do |v|
  v.setup_complete = true
end

# Create or find village admin role
village_admin_role = Role.find_or_create_by!(name: Role::VILLAGE_ADMIN)

# Create village admin
village_admin = User.find_or_create_by!(email: "admin@example.com") do |u|
  u.password = "password"
  u.password_confirmation = "password"
  u.name = "Village Administrator"
end
UserRole.find_or_create_by!(user: village_admin, role: village_admin_role)

# Create conference
conference = Conference.find_or_create_by!(name: "DEF CON 32", village: village) do |c|
  c.country = "US"
  c.state = "NV"
  c.city = "Las Vegas"
  c.start_date = Date.new(2024, 8, 8)
  c.end_date = Date.new(2024, 8, 11)
  c.conference_hours_start = Time.parse("09:00")
  c.conference_hours_end = Time.parse("18:00")
end

# Create conference lead (coordinator)
conference_lead = User.find_or_create_by!(email: "coordinator@example.com") do |u|
  u.password = "password"
  u.password_confirmation = "password"
  u.name = "Conference Coordinator"
end
ConferenceRole.find_or_create_by!(
  user: conference_lead,
  conference: conference,
  role_name: ConferenceRole::CONFERENCE_LEAD
)

# Create conference admins
conference_admin1 = User.find_or_create_by!(email: "admin1@example.com") do |u|
  u.password = "password"
  u.password_confirmation = "password"
  u.name = "Conference Admin One"
end
ConferenceRole.find_or_create_by!(
  user: conference_admin1,
  conference: conference,
  role_name: ConferenceRole::CONFERENCE_ADMIN
)

conference_admin2 = User.find_or_create_by!(email: "admin2@example.com") do |u|
  u.password = "password"
  u.password_confirmation = "password"
  u.name = "Conference Admin Two"
end
ConferenceRole.find_or_create_by!(
  user: conference_admin2,
  conference: conference,
  role_name: ConferenceRole::CONFERENCE_ADMIN
)

# Create volunteers
5.times do |i|
  volunteer = User.find_or_create_by!(email: "volunteer#{i + 1}@example.com") do |u|
    u.password = "password"
    u.password_confirmation = "password"
    u.name = "Volunteer #{i + 1}"
  end
end

puts "Seeds created successfully!"
puts "Village: #{village.name}"
puts "Village Admin: #{village_admin.email}"
puts "Conference: #{conference.name}"
puts "Conference Lead: #{conference_lead.email}"
puts "Conference Admins: #{conference_admin1.email}, #{conference_admin2.email}"
puts "Volunteers: volunteer1@example.com through volunteer5@example.com"
puts "\nAll users have password: password"
