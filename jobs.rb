require 'date'

PRICE_LIST = { first_checkin: 10, last_checkout: 5, checkout_checkin: 10 }

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

def handle_cleanings(input)
  result = [];

  input[:listings].each do |room|
    room_booking = parse_dates(input[:bookings].select{|owner_room| owner_room[:listing_id] == room[:id]})
    room_reservations = parse_dates(input[:reservations].select{|reserv| reserv[:listing_id] == room[:id]})

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

def parse_dates(entities)
  entities.map do |entity|
    entity[:parsed_start_date] = Date.parse(entity[:start_date]);
    entity[:parsed_end_date] = Date.parse(entity[:end_date]);
    entity[:period] = Date.parse(entity[:start_date])..Date.parse(entity[:end_date])
    entity
  end
end

def check_crossing_period(booking, reserv)
  reserv[:parsed_end_date] > reserv[:parsed_start_date] && booking[:period].include?(reserv[:parsed_start_date]) && booking[:period].include?(reserv[:parsed_end_date])
end

def create_mission(listing, date, type)
  {listing_id: listing[:id], mission_type: type, date: date, price: PRICE_LIST[type.to_sym] * listing[:num_rooms]}
end

p handle_cleanings(input)
