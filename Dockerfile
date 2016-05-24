FROM ruby:2.3

MAINTAINER Ryan Moore <moorer@udel.edu>

RUN gem install bundler

RUN \curl -sSL https://github.com/mooreryan/ZetaHunter/archive/v0.0.13.tar.gz \
    | tar -v -C /home -xz

RUN mv /home/ZetaHunter-0.0.13 /home/ZetaHunter

RUN bundle install --gemfile /home/ZetaHunter/Gemfile

CMD ["ruby", "/home/ZetaHunter/zeta_hunter.rb", "--help"]
