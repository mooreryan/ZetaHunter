# Installing ZetaHunter #

This mini tutorial will walk you through installing `ZetaHunter`
starting from a clean install of Lubuntu (a lightweight version of
Ubuntu). Depending on how your computer is set up, you may not need to
complete every step. These same steps should work on any Linux system
or on OSX with some minor tweaks.

*Note*: A line starting with `$` indicates a terminal commnad. This
means that you should enter that line into the terminal (without the
trailing `$`).

Install `curl`

    $ sudo apt-get curl

*Note*: Use whatever package manager comes with your OS (`yum`,
 `homebrew`, `macports`, etc).

## Install Ruby Version Manager ##

Install [RVM](https://rvm.io/) (Ruby version manager)

    $ gpg --keyserver hkp://keys.gnupg.net --recv-keys 409B6B1796C275462A1703113804BB82D39DC0E3

*Note*: In some cases, your computer may have `gpg2` instead of `gpg`.

    $ \curl -sSL https://get.rvm.io | bash -s stable

    $ source /home/mooreryan/.rvm/scripts/rvm

Check the installation by typing

    $ which rvm

You should see something like this

    /home/mooreryan/.rvm/bin/rvm

## Install Ruby ##

Install [Ruby](https://www.ruby-lang.org/en/) (A snazzy programming
language)

    $ rvm install 2.3

*Note*: This could take a bit of time depending on the number of required
packages that your system already has installed.

You can check this by typing

    $ which ruby

If you get something like

    /home/mooreryan/.rvm/rubies/ruby-2.3.0/bin/ruby

`gem` should automatically install with Ruby, but just double check.

    $ which gem

and you should see

    /home/mooreryan/.rvm/rubies/ruby-2.3.0/bin/gem

Finally, type

    $ rvm current

and you should see `ruby-2.3.0`.

## Install ZetaHunter and its dependencies ##

Install [Bundler](http://bundler.io/), which is used to manage
dependencies for Ruby projects.

    $ gem install bundler

Download the latest release from the release tab. Let's assume this is
version `0.0.6`.

    $ mkdir ~/vendor
    $ mv ~/Downloads/ZetaHunter-0.0.6.tar.gz ~/vendor
    $ cd ~/vendor
    $ tar xzf ZetaHunter-0.0.6.tar.gz
    $ cd ZetaHunter-0.0.6

Install the Ruby dependencies for `ZetaHunter`.

    $ bundle install

If everything went well, you can now run `ZetaHunter`! Try it out....

    $ ruby zeta_hunter.rb -h

And you should see the help screen.
