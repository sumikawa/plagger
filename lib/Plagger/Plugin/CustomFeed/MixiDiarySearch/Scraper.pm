package Plagger::Plugin::CustomFeed::MixiDiarySearch::Scraper;
use strict;
use base qw( Plagger::Plugin );

use Encode;
use Plagger::UserAgent;
use Plagger::Util qw( decode_content );
use Web::Scraper;

sub register {
    my($self, $context) = @_;
    $context->register_hook(
        $self,
        'customfeed.handle' => \&handle,
    );
}

sub handle {
    my($self, $context, $args) = @_;

    if ($args->{feed}->url =~ m!^http://mixi\.jp/search_diary\.pl\?.*keyword=!) {
        $self->aggregate($context, $args);
        return 1;
    }

    return;
}

sub aggregate {
    my($self, $context, $args) = @_;

    my $scraper = scraper {
	process '//ul[@class="list clearfix"]/li', 'entry[]' => scraper {
	    process 'div.listIcon a', 'link' => '@href';
	    process 'div.listIcon img', 'photo' => '@src';
	    process 'div.listIcon span.name a', 'name' => 'TEXT';
	    process 'div.heading a.name', 'title' => 'TEXT';
	    process 'span.date', 'date' => 'TEXT';
	    process 'p.description', 'body' => 'HTML';
	};
	process 'div.pageList02 a', next_link => '@href';
	result 'entry', 'next_link';
    };

    my $url = $args->{feed}->url;
    $context->log(info => "GET $url");

    my $agent = Plagger::UserAgent->new;

    my $now = Plagger::Date->now;
    my $current = $now->year;
    my $date_format = decode("utf-8", "%Y %m月%d日 %H:%M");

    my %query = URI->new($url)->query_form;

    # heh, this is a "Cache"
    my $title = "mixi: Search for " . decode("euc-jp", $query{keyword});
    unless ($self->conf->{mixi_tos_paranoia}) {
	$title .= " (Cache)";
    }

    my $feed = $args->{feed};
    $feed->title($title);
    $feed->link($url);

 PAGE: {
	my $res = $agent->fetch($url, $self);
	if ($res->is_error) {
	    $context->log(error => "GET $url failed: " . $res->status_code);
	    return;
	}
	my $content = decode_content($res);

	my $result = $scraper->scrape($content);

	for my $data (@{$result->{entry}}) {
	    next unless ($data->{name});

	    $data->{date} = Plagger::Date->strptime($date_format, "$current $data->{date}");
	    $data->{date}->set_time_zone('Asia/Tokyo');

	    # one year ago, if the parsed datetime is in the future
	    if ($data->{date} > $now) {
		$data->{date}->subtract(years => 1);
	    }

	    my $entry = Plagger::Entry->new;

	    $entry->title($data->{title});
	    $entry->link( URI->new_abs($data->{link}, $url) );
	    $entry->date($data->{date});

	    unless ($self->conf->{mixi_tos_paranoia}) {
		$entry->body($data->{body});
		$entry->icon({ url => URI->new_abs($data->{photo}, $url) });
		$entry->author($data->{name});
	    }

	    $feed->add_entry($entry);
	    $context->log(debug => "Add $data->{link} ($data->{title})");
	}

	if ($self->conf->{follow_next_link} && $result->{next_link}) {
	    my $url = URI->new_abs($result->{next_link}, $url);
	    redo PAGE;
	}
    }

    $context->update->add($feed);
}

1;
