require "bundler"
require "pp"
Bundler.require

router = ENV.fetch('TOMATO_HOST')
session_id = ENV.fetch('TOMATO_SESSION_ID', nil)
user = ENV.fetch('TOMATO_USER', 'root')
pass = ENV.fetch('TOMATO_PASS', nil)
statsd_host = ENV.fetch('STATSD_HOST', 'localhost')
statsd_port = ENV.fetch('STATSD_POST', '8125').to_i
statsd_namespace = ENV.fetch('STATSD_NAMESPACE', 'router')


interval = ENV.fetch('INTERVAL', '1').to_f
device_refresh_interval = ENV.fetch('DEVICE_REFRESH_INTERVAL', 60).to_i

statsd = Datadog::Statsd.new(statsd_host, statsd_port)
statsd.namespace = statsd_namespace
api = Tomato::API.new(router, user: user, pass: pass, session_id: session_id)

last = api.iptraffic

loop do
  time = Time.now
  begin
    now = api.iptraffic
    output = Hash[now.map do |ip, now_values|
      deltas = now_values.map do |key, now_value|
        case key
        # Everything but tcpconn/udpconn are absolute
        when :tcpconn, :udpconn
          [key, now_value]
        else
          [key, now_value - last.fetch(ip, {}).fetch(key, 0)]
        end
      end
      [ip, Hash[deltas]]
    end]

    output.each do |ip, values|
      tags = ["ip:#{ip}"]
      statsd.batch do |s|
        values.each do |key, value|
          case key
          when :tcpconn, :udpconn
            s.gauge(key, value, tags: tags)
          else
            s.count(key, value, tags: tags)
          end
        end
      end
    end
    puts JSON.dump(output)

    last = now
  rescue StandardError => ex
    $stderr.puts ex.inspect
  end
  sleep [time + interval - Time.now, 0].max
end
