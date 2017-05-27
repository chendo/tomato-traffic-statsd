FROM ruby:2.4.0

RUN mkdir /app
WORKDIR /app

ADD Gemfile* /app/

RUN bundle install

ADD tomato-traffic-statsd.rb /app/

CMD bundle exec ruby tomato-traffic-statsd.rb
