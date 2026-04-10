import "date"
import "timezone"
option task = {
  name: "producer.daily.schedule",
  every: 15m,
  offset: 2m
}

stop  = date.truncate(t: now(), unit: 15m)

start = date.add(d: -20m, to: stop)

from(bucket: "producer")
  |> range(start: start, stop: stop)
  |> to(bucket: "producer.daily", org: "data-center")