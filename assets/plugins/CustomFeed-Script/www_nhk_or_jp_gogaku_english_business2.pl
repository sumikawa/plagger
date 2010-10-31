#!/usr/bin/env perl

use strict;
use warnings;

use Web::Scraper;
use URI;
use YAML;
#use Plagger::UserAgent;

my $stuff   = URI->new(
    "http://www.nhk.or.jp/gogaku/english/business2/index.html"
);

my $scraper = scraper {
    process '//h1/img', 'title' => '@alt';
    process '//h1/img', 'image' => '@src',
    process '//div[@id="con-procontent"]/p[1]', 'description' => 'TEXT';
    process '//div[@id="eng-bus-audionow"]/div[@class="eng-bus-audnwlink" and p ]',
        'entry[]' => scraper {
            process '//a/text()', 'title' => 'TEXT';
            process '//a/text()', 'body' => 'TEXT';
            process '//a', 'enclosure[]' => scraper {
                process '//a', 'url' => '@href';
            };
        };
};

#$scraper->user_agent( Plagger::UserAgent->new );
my $result = $scraper->scrape($stuff);
$result->{link} = "$stuff";

binmode STDOUT, ":utf8";
print Dump $result;
