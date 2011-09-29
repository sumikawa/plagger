#!/usr/bin/perl 
use strict;
use warnings;

use Web::Scraper;
use URI;
use YAML;
#use Plagger;
#use Plagger::UserAgent;

my $stuff   = URI->new("http://lantis-net.com/srw_og/");
my $scraper = scraper {
    process '//title', 'title' => 'TEXT';
    process 'li#top > a', 'link' => '@href';
    process '.logo > h1 > img', 'image' => '@src';
    process_first '.box_01 > .left_01 > p', 'description' => 'TEXT';
#    process '//div.box_01//div.left_01[2]/p', 'author' => 'TEXT';
#    process 'div.copy', 'copyright' => 'TEXT';
    process '#radio', 'entry[]' => scraper {
        process '//h3/text()', 'title' => 'TEXT';
        process '.radiotext>p', 'body' => 'HTML';
        process '.date', 'date' => 'TEXT';
        process '.radiolink', 'enclosure[]' => scraper {
            #process 'a:nth-child(2)', 'url' => sub { $_->attr('href') };
            process '//a[2]', 'url' => sub { $_->attr('href') };
        };
    };
};

#$scraper->user_agent( Plagger::UserAgent->new );
my $result = $scraper->scrape($stuff);

binmode STDOUT, ":utf8";
print Dump $result;
