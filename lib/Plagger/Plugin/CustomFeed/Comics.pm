# Plagger::Plugin::CustomFeed::Comics
package Plagger::Plugin::CustomFeed::Comics;
use strict;
use base qw( Plagger::Plugin );

#use Encode;
use utf8;
use DateTime::Format::Strptime;
use Plagger::UserAgent;
use URI::Escape;
use Text::CSV_XS;

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
    $feed->type('comics');
    $feed->title('コミックス');
    $feed->link('http://www.mangaoh.co.jp/download/index.php');

    my $showndate = DateTime->today->add(days => 3);
    my $bookdate = $showndate->clone();
    my $body = "";

    my $filename = 'comic' . sprintf("%04d", $showndate->year) .
	sprintf("%02d", $showndate->month) . '.csv';
    my $url = sprintf("http://www.mangaoh.co.jp/download/$filename");
    my $file = $self->cache->path_to($filename);

    my $ua = Plagger::UserAgent->new;
    my $res = $ua->mirror($url => $file);

    if ($res->is_error){
	$context->log( error => $res->status_line );
	return;
    }

    open my $fh, "<:encoding(shift-jis)", $file
	or return $context->log(error => "$file: $!");

    my $authflag = 0;
    my $csv=Text::CSV_XS->new({binary=>1});

    while (<$fh>) {
	my $status=$csv->parse($_);
	my ($company, $date, $title, $author, $price, $genre) = $csv->fields();
	my ($year, $month, $day) = split('/', $date);
	next if ($month == 0);

	if ($day eq "上") { $day = "10"; };
	if ($day eq "中") { $day = "20"; };
	if ($day eq "下") { $day = "28"; };
	if ($day eq "未") { $day = "28"; };
	$bookdate->set(month => $month, day => $day);
	if (DateTime->compare($showndate, $bookdate) == 0) {
		next if ($genre =~ "耽美");
		next if ($genre =~ "成年");
	    $title =~ tr/Ａ-Ｚａ-ｚ０-９（）！？　/A-Za-z0-9()!? /;
	    my $keywords = $author;
	    utf8::encode($keywords);
	    $keywords =~s /(\W)/'%' . unpack('H2',$1)/eg;
	    $keywords =~s /\s/+/g;
	    utf8::decode($keywords);
	    my $link = 'http://www.amazon.co.jp/exec/obidos/search-handle-url/index=books-jp&rank=+daterank&field-keywords=' . $keywords;
	    $body = $body . $author . ' / ' . "<a href=\"$link\">" . $title  . "</a>" . ' (' . $company . ")<br />\n";
	}
    }
    close($fh);

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

Plagger::Plugin::CustomFeed::Comics - Custom feed for Manga releasing date in Japan

=head1 SYNOPSIS

  - module: CustomFeed::Comics

=head1 DESCRIPTION

This plugin fetches comic releasing date from MANGAOH CLUB (L<http://http://www.mangaoh.co.jp/download/index.php>).

=head1 AUTHOR

Munechika Sumikawa

=head1 SEE ALSO

L<Plagger>

=cut
