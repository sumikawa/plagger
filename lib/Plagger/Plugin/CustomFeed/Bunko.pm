# Plagger::Plugin::CustomFeed::Bunko
# $Id$
package Plagger::Plugin::CustomFeed::Bunko;
use strict;
use base qw( Plagger::Plugin );

#use Encode;
use utf8;
use DateTime::Format::Strptime;
use Plagger::UserAgent;
use URI::Escape;

sub register {
    my($self, $context) = @_;
    $context->register_hook(
        $self,
        'subscription.load' => \&load,
    );
}

sub load {
    my($self, $context) = @_;

    my $feed = Plagger::Feed->new;
       $feed->aggregator(sub { $self->aggregate(@_) });
    $context->subscription->add($feed);
}

sub aggregate {
    my($self, $context, $args) = @_;

    my $feed = Plagger::Feed->new;
    $feed->type('bunko');
    $feed->title('文庫本発売日');
    $feed->link('http://www.taiyosha.co.jp/bunko/');

    my $showndate = DateTime->today->add(days => 3);
    my $bookdate = $showndate->clone();
    my $body = "";

    for (my $i = 1; $i < 4; $i++) {
	my $filename = 'bunko' . sprintf("%02d", $showndate->year - 2000) .
	    sprintf("%02d", $showndate->month) . '_cyo' . $i . '.html';
	my $url = "http://www.taiyosha.co.jp/bunko/$filename";
	my $file = $self->cache->path_to($filename);

	my $ua = Plagger::UserAgent->new;
	my $res = $ua->mirror($url => $file);

	if ($res->is_error){
	    $context->log( error => $res->status_line );
	    return;
	}

	open my $fh, "<:encoding(shift-jis)", $file
	    or return $context->log(error => "$file: $!");

	my ($author, $title, $company, $date);

	while (<$fh>) {
	    m!<TD WIDTH=100 BGCOLOR=#efefef>(.*)<br></TD>!
		and $author = $1;
	    m!<TD WIDTH=200 BGCOLOR=#efefef>(.*)<br></TD>!
		and $title = $1;
	    m!<TD WIDTH=140 BGCOLOR=#efefef>(.*)<br>(.*)</TD>!
		and $company = $1 . ' ' . $2;
	    m!<TD WIDTH=50 BGCOLOR=#efefef>(.*)<br></TD>!
		and $date = $1;

	    m!^</TR>!
		and do {
		    my ($month, $day) = split('/', $date);
		    next if (($month eq "") || ($day eq ""));
		    if ($day eq "上") { $day = "10"; };
		    if ($day eq "中") { $day = "20"; };
		    if ($day eq "下") { $day = "28"; };
		    if ($day eq "未定") { $day = "28"; };
		    $bookdate->set(month => $month, day => $day);
		    if (DateTime->compare($showndate, $bookdate) == 0) {
#			next if ($title =~ "（成）");
#			next if ($author =~ "アンソロジー");
			$title =~ tr/Ａ-Ｚａ-ｚ０-９（）！？　/A-Za-z0-9()!? /;
			my $keywords = $author;
			utf8::encode($keywords);
			$keywords =~s /(\W)/'%' . unpack('H2',$1)/eg;
			$keywords =~s /\s/+/g;
			utf8::decode($keywords);
			my $link = 'http://www.amazon.co.jp/exec/obidos/search-handle-url/index=books-jp&rank=+daterank&field-keywords=' . $keywords;
			$body = $body . $author . ' / ' . "<A HREF=\"$link\">" . $title  . "</A>" . ' (' . $company . ")<BR>\n";
		    }
	    }
	}
	close($fh);
    }
    my $entry = Plagger::Entry->new;
    $entry->body($body);
    $entry->date($showndate);
    $entry->title($showndate->ymd . "の新刊");
    $feed->add_entry($entry);

    $context->update->add($feed);
}

sub get_value {
    my($self, $item, $key) = @_;

    my $value = $item->{$key};
    $value = '---' if ref $value;
    $value;
}

1;

__END__

=head1 NAME

Plagger::Plugin::CustomFeed::NetLadio - Custom feed for livedoor Internet ladio

=head1 SYNOPSIS

  - module: CustomFeed::NetLadio
    config:
      limit: 5
      sort: tims
      order: asc

=head1 DESCRIPTION

This plugin fetches programs from livedoor Internet ladio(L<http://live.ladio.livedoor.com/>).

=head1 CONFIG

=over 4

=item limit

Number of programs.

=item sort

Sort item.

=over 4

=item url

URL column specified with broadcasting tool

=item gnl

Genre column specified with broadcasting tool

=item nam

Title column specified with broadcasting tool

=item tit

Name of a song information now at the time of transmit by broadcasting tool

=item mnt

Mount point

=item tims

Start of the broadcasting time

=item cln

Number of present listeners

=item clns

Number of total listeners that Icecast1.3 faction outputs

=item srv

Delivery server host name

=item prt

Delivery server port number

=item bit

Bit rate

=back

=item order

The permutation order.

=over 4

=item asc

Ascending order

=item desc

Descending order

=back

=back

=head1 AUTHOR

Motokazu Sekine (CHEEBOW)

=head1 SEE ALSO

L<Plagger>

=cut
