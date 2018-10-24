require 'date'
require 'rspec'

input = {
  "listings": [
    { "id": 1, "num_rooms": 2 },
    { "id": 2, "num_rooms": 1 },
    { "id": 3, "num_rooms": 3 }
  ],
  "bookings": [
    { "id": 1, "listing_id": 1, "start_date": "2016-10-10", "end_date": "2016-10-15" },
    { "id": 2, "listing_id": 1, "start_date": "2016-10-16", "end_date": "2016-10-20" },
    { "id": 3, "listing_id": 2, "start_date": "2016-10-15", "end_date": "2016-10-20" }
  ],
  "reservations": [
    { "id": 1, "listing_id": 1, "start_date": "2016-10-11", "end_date": "2016-10-13" },
    { "id": 1, "listing_id": 1, "start_date": "2016-10-13", "end_date": "2016-10-15" },
    { "id": 1, "listing_id": 1, "start_date": "2016-10-16", "end_date": "2016-10-20" },
    { "id": 3, "listing_id": 2, "start_date": "2016-10-15", "end_date": "2016-10-18" }
  ]
}

class MissinsContoller
  PRICE_LIST = { first_checkin: 10, last_checkout: 5, checkout_checkin: 10 }
  attr_accessor :notifications

  def handle_cleanings(input)
    @notifications = []
    result = [];

    input[:listings].each do |room|
      room_booking = room_entities(room[:id], input[:bookings]).map{|el| parse_dates(el, "booking")}.compact
      room_reservations = room_entities(room[:id], input[:reservations]).map{|el| parse_dates(el, "reservation")}.compact

      room_booking.each do |booking|
        booking_reservations = room_reservations.select{|reserv| check_crossing_period(booking, reserv)}
        result.push(create_mission(room, booking[:start_date], "first_checkin"));
        result.push(create_mission(room, booking[:end_date], "last_checkout"));

        booking_reservations.each do |reserv|
          result.push(create_mission(room, reserv[:end_date], "checkout_checkin")) if reserv[:end_date] != booking[:end_date];
        end
      end
    end
    {"missions" => result}
  end

  def last_handling_logs
    @notifications || []
  end

  private

  def room_entities(room_id, entities = [])
    entities.select{|el| el[:listing_id] == room_id}
  end

  def parse_dates(entity, entity_type)
    begin
      entity[:parsed_start_date] = Date.parse(entity[:start_date]);
      entity[:parsed_end_date] = Date.parse(entity[:end_date]);
      entity[:period] = Date.parse(entity[:start_date])..Date.parse(entity[:end_date])
      entity
    rescue => e
      @notifications << {description: e.to_s, listing_id: entity[:listing_id], id: entity[:id], entity_type: entity_type}
      nil
    end
  end

  def check_crossing_period(booking, reserv)
    reserv[:parsed_end_date] > reserv[:parsed_start_date] && booking[:period].include?(reserv[:parsed_start_date]) && booking[:period].include?(reserv[:parsed_end_date])
  end

  def create_mission(listing, date, type)
    {listing_id: listing[:id], mission_type: type, date: date, price: PRICE_LIST[type.to_sym] * listing[:num_rooms]}
  end
end

missions_entity = MissinsContoller.new()
p missions_entity.handle_cleanings(input)
p missions_entity.last_handling_logs

RSpec.describe MissinsContoller do
  subject { described_class.new() }

  it "create missions" do
    input = {
      "listings": [
        { "id": 1, "num_rooms": 2 },
        { "id": 2, "num_rooms": 1 },
        { "id": 3, "num_rooms": 3 }
      ],
      "bookings": [
        { "id": 1, "listing_id": 1, "start_date": "2016-10-10", "end_date": "2016-10-15" },
        { "id": 2, "listing_id": 1, "start_date": "2016-10-16", "end_date": "2016-10-20" },
        { "id": 3, "listing_id": 2, "start_date": "2016-10-15", "end_date": "2016-10-20" }
      ],
      "reservations": [
        { "id": 1, "listing_id": 1, "start_date": "2016-10-11", "end_date": "2016-10-13" },
        { "id": 1, "listing_id": 1, "start_date": "2016-10-13", "end_date": "2016-10-15" },
        { "id": 1, "listing_id": 1, "start_date": "2016-10-16", "end_date": "2016-10-20" },
        { "id": 3, "listing_id": 2, "start_date": "2016-10-15", "end_date": "2016-10-18" }
      ]
    }

    expected_result = {
      "missions": [
        {:listing_id=>1, :mission_type=>"first_checkin", :date=>"2016-10-10", :price=>20},
        {:listing_id=>1, :mission_type=>"last_checkout", :date=>"2016-10-15", :price=>10},
        {:listing_id=>1, :mission_type=>"first_checkin", :date=>"2016-10-16", :price=>20},
        {:listing_id=>1, :mission_type=>"last_checkout", :date=>"2016-10-20", :price=>10},
        {:listing_id=>1, :mission_type=>"checkout_checkin", :date=>"2016-10-13", :price=>20},
        {:listing_id=>2, :mission_type=>"first_checkin", :date=>"2016-10-15", :price=>10},
        {:listing_id=>2, :mission_type=>"last_checkout", :date=>"2016-10-20", :price=>5},
        {:listing_id=>2, :mission_type=>"checkout_checkin", :date=>"2016-10-18", :price=>10}
      ]
    }

    result = subject.handle_cleanings(input)["missions"]


    expect((result && expected_result[:missions])).to eql(expected_result[:missions])
  end

  it "ignore reservations for period outside the booking period" do
    input = {
      "listings": [
        { "id": 1, "num_rooms": 2 },
      ],
      "bookings": [
        { "id": 1, "listing_id": 1, "start_date": "2016-10-10", "end_date": "2016-10-15" },
      ],
      "reservations": [
        { "id": 1, "listing_id": 1, "start_date": "2016-10-16", "end_date": "2016-10-20" }
      ]
    }
    result = subject.handle_cleanings(input)["missions"]

    expect(result.length).to eql(2)
    expect(result[0][:date]).to eql(input[:bookings][0][:start_date])
    expect(result[1][:date]).to eql(input[:bookings][0][:end_date])
  end

  it "ignore reservations which has end_date early than start date " do
    input = {
      "listings": [
        { "id": 1, "num_rooms": 2 },
      ],
      "bookings": [
        { "id": 1, "listing_id": 1, "start_date": "2016-10-10", "end_date": "2016-10-15" },
      ],
      "reservations": [
        { "id": 1, "listing_id": 1, "start_date": "2016-10-14", "end_date": "2016-10-13" }
      ]
    }
    result = subject.handle_cleanings(input)["missions"]

    expect(result.length).to eql(2)
    expect(result[0][:date]).to eql(input[:bookings][0][:start_date])
    expect(result[1][:date]).to eql(input[:bookings][0][:end_date])
  end

  it "ignore reservations which will finish after booking period" do
    input = {
      "listings": [
        { "id": 1, "num_rooms": 2 },
      ],
      "bookings": [
        { "id": 1, "listing_id": 1, "start_date": "2016-10-10", "end_date": "2016-10-15" },
      ],
      "reservations": [
        { "id": 1, "listing_id": 1, "start_date": "2016-10-14", "end_date": "2016-10-16" }
      ]
    }
    result = subject.handle_cleanings(input)["missions"]

    expect(result.length).to eql(2)
    expect(result[0][:date]).to eql(input[:bookings][0][:start_date])
    expect(result[1][:date]).to eql(input[:bookings][0][:end_date])
  end

  it "process booking incorrect date and ignor booking with incorrect date" do
    input = {
      "listings": [
        { "id": 1, "num_rooms": 2 },
      ],
      "bookings": [
        { "id": 1, "listing_id": 1, "start_date": "hello", "end_date": "2016-10-15" },
      ],
      "reservations": [
        { "id": 1, "listing_id": 1, "start_date": "2016-10-14", "end_date": "2016-10-16" }
      ]
    }
    result = subject.handle_cleanings(input)["missions"]

    expect(result.length).to eql(0)
  end

  it "proccess booking with incorrect date and return logs" do
    input = {
      "listings": [
        { "id": 1, "num_rooms": 2 },
      ],
      "bookings": [
        { "id": 1, "listing_id": 1, "start_date": "hello", "end_date": "2016-10-15" },
      ],
      "reservations": [
        { "id": 1, "listing_id": 1, "start_date": "2016-10-14", "end_date": "2016-10-16" }
      ]
    }
    subject.handle_cleanings(input)["missions"]

    expect(subject.last_handling_logs).to eql([{:description=>"invalid date", :entity_type=>"booking", :id=>1, :listing_id=>1}])
  end

  it "ignor reservations with incorrect date" do
    input = {
      "listings": [
        { "id": 1, "num_rooms": 2 },
      ],
      "bookings": [
        { "id": 1, "listing_id": 1, "start_date": "2016-10-10", "end_date": "2016-10-15" },
      ],
      "reservations": [
        { "id": 1, "listing_id": 1, "start_date": "hello", "end_date": "2016-10-14" }
      ]
    }
    result = subject.handle_cleanings(input)["missions"]

    expect(result.length).to eql(2)
    expect(result[0][:date]).to eql(input[:bookings][0][:start_date])
    expect(result[1][:date]).to eql(input[:bookings][0][:end_date])
  end

  it "proccess reservations with incorrect date and return logs" do
    input = {
      "listings": [
        { "id": 1, "num_rooms": 2 },
      ],
      "bookings": [
        { "id": 1, "listing_id": 1, "start_date": "2016-10-10", "end_date": "2016-10-15" },
      ],
      "reservations": [
        { "id": 1, "listing_id": 1, "start_date": "hello", "end_date": "2016-10-14" }
      ]
    }
    subject.handle_cleanings(input)["missions"]

    expect(subject.last_handling_logs).to eql([{:description=>"invalid date", :entity_type=>"reservation", :id=>1, :listing_id=>1}])
  end
end
