FROM ruby:2.3

MAINTAINER Ryan Moore <moorer@udel.edu>

RUN gem install bundler

RUN \curl -sSL https://github.com/mooreryan/ZetaHunter/archive/v0.0.7.tar.gz \
    | tar -v -C /home -xz

RUN bundle install --gemfile /home/ZetaHunter-0.0.7/Gemfile

CMD ["ruby", "/home/ZetaHunter-0.0.7/zeta_hunter.rb", "--help"]
