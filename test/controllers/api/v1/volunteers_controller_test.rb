require "test_helper"

class Api::V1::VolunteersControllerTest < ActionDispatch::IntegrationTest
  setup do
    @village = Village.create!(name: "Test Village", setup_complete: true)
    @conference = Conference.create!(
      village: @village,
      name: "Test Conference",
      start_date: Date.tomorrow,
      end_date: Date.tomorrow + 2.days,
      conference_hours_start: "09:00",
      conference_hours_end: "17:00"
    )
    @program = Program.create!(name: "Test Program", village: @village)
    @conference_program = ConferenceProgram.create!(conference: @conference, program: @program)

    @volunteer = create_confirmed_user(email: "volunteer@example.com", handle: "vol1")
    @volunteer2 = create_confirmed_user(email: "volunteer2@example.com", handle: "vol2")
    @lead = create_confirmed_user(email: "lead@example.com")
    ConferenceRole.create!(user: @lead, conference: @conference, role_name: ConferenceRole::CONFERENCE_LEAD)

    3.times do |i|
      timeslot = Timeslot.create!(
        conference_program: @conference_program,
        start_time: Date.tomorrow.to_datetime + 9.hours + (i * 15).minutes,
        max_volunteers: 2
      )
      VolunteerSignup.create!(user: @volunteer, timeslot: timeslot)
      VolunteerSignup.create!(user: @volunteer2, timeslot: timeslot) if i.zero?
    end

    @token = @volunteer.api_tokens.create!(name: "test token")
  end

  def bearer(token)
    { "Authorization" => "Bearer #{token.plaintext_token}" }
  end

  # Authentication

  test "returns 401 without credentials" do
    get api_v1_conference_volunteers_url(@conference)
    assert_response :unauthorized
    assert_equal "unauthorized", JSON.parse(response.body)["error"]
  end

  test "returns 401 with an invalid token" do
    get api_v1_conference_volunteers_url(@conference),
        headers: { "Authorization" => "Bearer vlg_bogus" }
    assert_response :unauthorized
  end

  test "returns 401 with a revoked token" do
    @token.revoke!
    get api_v1_conference_volunteers_url(@conference), headers: bearer(@token)
    assert_response :unauthorized
  end

  test "authenticates with a valid bearer token" do
    get api_v1_conference_volunteers_url(@conference), headers: bearer(@token)
    assert_response :success
  end

  test "authenticates with a devise session" do
    sign_in @volunteer
    get api_v1_conference_volunteers_url(@conference)
    assert_response :success
  end

  # Payload and scoping

  test "volunteer sees only their own totals" do
    get api_v1_conference_volunteers_url(@conference), headers: bearer(@token)
    json = JSON.parse(response.body)

    assert_equal @conference.id, json["conference_id"]
    assert_equal "Test Conference", json["conference"]
    assert_equal 1, json["volunteers"].size
    entry = json["volunteers"].first
    assert_equal @volunteer.id, entry["user_id"]
    assert_equal "volunteer@example.com", entry["email"]
    assert_not entry.key?("name")
    assert_equal "vol1", entry["handle"]
    assert_equal 3, entry["shift_count"]
    assert_equal 0.75, entry["total_hours"]
  end

  test "volunteer may filter by their own user_id" do
    get api_v1_conference_volunteers_url(@conference, user_id: @volunteer.id),
        headers: bearer(@token)
    assert_response :success
    assert_equal 1, JSON.parse(response.body)["volunteers"].size
  end

  test "volunteer requesting another user_id gets 403" do
    get api_v1_conference_volunteers_url(@conference, user_id: @volunteer2.id),
        headers: bearer(@token)
    assert_response :forbidden
    assert_equal "forbidden", JSON.parse(response.body)["error"]
  end

  test "conference lead sees all volunteers" do
    lead_token = @lead.api_tokens.create!(name: "lead token")
    get api_v1_conference_volunteers_url(@conference), headers: bearer(lead_token)
    json = JSON.parse(response.body)

    assert_equal 2, json["volunteers"].size
    by_user = json["volunteers"].index_by { |v| v["user_id"] }
    assert_equal 3, by_user[@volunteer.id]["shift_count"]
    assert_equal 1, by_user[@volunteer2.id]["shift_count"]
    assert_equal 0.25, by_user[@volunteer2.id]["total_hours"]
  end

  test "conference lead may filter by user_id" do
    lead_token = @lead.api_tokens.create!(name: "lead token")
    get api_v1_conference_volunteers_url(@conference, user_id: @volunteer2.id),
        headers: bearer(lead_token)
    json = JSON.parse(response.body)

    assert_equal 1, json["volunteers"].size
    assert_equal @volunteer2.id, json["volunteers"].first["user_id"]
  end

  test "village admin sees all volunteers" do
    admin = create_confirmed_user(email: "admin@example.com")
    UserRole.create!(user: admin, role: Role.find_or_create_by!(name: Role::VILLAGE_ADMIN))
    admin_token = admin.api_tokens.create!(name: "admin token")

    get api_v1_conference_volunteers_url(@conference), headers: bearer(admin_token)
    assert_equal 2, JSON.parse(response.body)["volunteers"].size
  end

  test "returns 404 for an unknown conference" do
    get api_v1_conference_volunteers_url(conference_id: 999_999), headers: bearer(@token)
    assert_response :not_found
    assert_equal "not_found", JSON.parse(response.body)["error"]
  end

  test "signups from other conferences are not counted" do
    other_conference = Conference.create!(
      village: @village,
      name: "Other Conference",
      start_date: Date.tomorrow + 10.days,
      end_date: Date.tomorrow + 12.days,
      conference_hours_start: "09:00",
      conference_hours_end: "17:00"
    )
    other_cp = ConferenceProgram.create!(conference: other_conference, program: @program)
    other_timeslot = Timeslot.create!(
      conference_program: other_cp,
      start_time: (Date.tomorrow + 10.days).to_datetime + 9.hours,
      max_volunteers: 2
    )
    VolunteerSignup.create!(user: @volunteer, timeslot: other_timeslot)

    get api_v1_conference_volunteers_url(@conference), headers: bearer(@token)
    assert_equal 3, JSON.parse(response.body)["volunteers"].first["shift_count"]
  end

  # Show

  test "volunteer can show their own totals with their shifts" do
    get api_v1_conference_volunteer_url(@conference, @volunteer), headers: bearer(@token)
    assert_response :success
    json = JSON.parse(response.body)

    assert_equal @conference.id, json["conference_id"]
    assert_equal "Test Conference", json["conference"]
    assert_equal @volunteer.id, json["volunteer"]["user_id"]
    assert_equal "volunteer@example.com", json["volunteer"]["email"]
    assert_not json["volunteer"].key?("name")
    assert_equal 3, json["volunteer"]["shift_count"]
    assert_equal 0.75, json["volunteer"]["total_hours"]

    shifts = json["volunteer"]["shifts"]
    assert_equal 3, shifts.size
    assert_equal shifts.map { |s| s["starts_at"] }.sort, shifts.map { |s| s["starts_at"] }
    first = shifts.first
    assert_equal "Test Program", first["program"]
    assert_equal @volunteer.id, first["user_id"]
    assert first.key?("id")
    assert first.key?("ends_at")
  end

  test "volunteer showing another volunteer gets 403" do
    get api_v1_conference_volunteer_url(@conference, @volunteer2), headers: bearer(@token)
    assert_response :forbidden
  end

  test "conference lead can show any volunteer" do
    lead_token = @lead.api_tokens.create!(name: "lead token")
    get api_v1_conference_volunteer_url(@conference, @volunteer2), headers: bearer(lead_token)
    assert_response :success
    assert_equal 1, JSON.parse(response.body)["volunteer"]["shift_count"]
  end

  test "show returns zero totals for a volunteer with no signups" do
    lead_token = @lead.api_tokens.create!(name: "lead token")
    get api_v1_conference_volunteer_url(@conference, @lead), headers: bearer(lead_token)
    json = JSON.parse(response.body)

    assert_equal 0, json["volunteer"]["shift_count"]
    assert_equal 0.0, json["volunteer"]["total_hours"]
    assert_equal [], json["volunteer"]["shifts"]
  end

  test "show returns 404 for an unknown volunteer" do
    lead_token = @lead.api_tokens.create!(name: "lead token")
    get api_v1_conference_volunteer_url(@conference, id: 999_999), headers: bearer(lead_token)
    assert_response :not_found
  end
end
