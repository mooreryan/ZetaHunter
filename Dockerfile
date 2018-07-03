FROM ruby:2.3.7-stretch

MAINTAINER Ryan Moore <moorer@udel.edu>

RUN gem install bundler

RUN \curl -sSL https://github.com/mooreryan/ZetaHunter/archive/v1.0.1.tar.gz \
    | tar -v -C /home -xz

RUN mv /home/ZetaHunter-1.0.1 /home/ZetaHunter

RUN bundle install --gemfile /home/ZetaHunter/Gemfile

CMD ["ruby", "/home/ZetaHunter/zeta_hunter.rb", "--help"]
