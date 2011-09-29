#!/usr/bin/env perl

use strict;
use warnings;
use Web::Scraper;
use URI;
use DateTime;
use YAML;

my $stuff = URI->new(
    "http://transit.livedoor.com/traffic_info/kantou"
);

my $result = scraper {
    process '//title', 'title' => 'TEXT';
    process '//table[@class="information_trafic01"]//tr[position() != 1]',
        'entry[]' => scraper {
            process '//th[@class="trafficinfo"]/text()', 'date' => ['TEXT', \&mk_date];
            process '//td[@class="trafficinfo"][1]/text()', 'title' => 'TEXT';
            process '//td[@class="trafficinfo"][2]/text()', 'body' => 'TEXT';
        };
}->scrape($stuff);

$result->{link} = $stuff;

binmode STDOUT, ":utf8";
print YAML::Dump $result;

sub mk_date {
    my $input = shift;
    return unless ($input =~ m!(\d+)/(\d+) (\d+):(\d+)!);

    my $month = $1;
    my $day = $2;
    my $hour = $3;
    my $minute = $4;

    my $today = DateTime->now(time_zone => 'Asia/Tokyo')->truncate(to => 'day');
    my $this = $today->clone->set(month => $month, day => $day,
                                  hour => $hour, minute => $minute
    );
    my $last = $this->clone->subtract(years => 1);
    my $next = $this->clone->add(years => 1);
    my @date = sort { DateTime::Duration->compare($a->[1], $b->[1], $today) }
               map { [$_->[0], $_->[1]->is_positive ? $_->[1] : $_->[1]->inverse ] }
               map { [$_, $today - $_] } ($this, $last, $next);

    return $date[0]->[0]->iso8601();
}
