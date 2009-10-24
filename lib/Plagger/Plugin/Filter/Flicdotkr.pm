package Plagger::Plugin::Filter::Flicdotkr;
use strict;
use base qw( Plagger::Plugin::Filter::Base );

use URI;
use URI::Find;
use Encode::Base58;

sub filter {
    my($self, $body) = @_;

    my $count = 0;
    my $opt = $self->conf->{be} || 'short';
    my $userid = $self->conf->{userid} || '';

    my $finder = URI::Find->new(sub {
        my ($uri, $orig_uri) = @_;
        if ($opt eq 'long' && $uri =~ /flic\.kr/) {
            $count++;
            return makealongerlink($orig_uri, $userid);
        }
        elsif ($opt eq 'short' && $uri =~ /www\.flickr\.com/) {
            $count++;
            return makeashorterlink($orig_uri);
        }
        else {
            return $orig_uri;
        }
    });

    $finder->find(\$body);
    ($count, $body);
}

sub makealongerlink {
    my ($orig_uri, $userid) = @_;

    my $uri = URI->new($orig_uri);
    my @args = split(/\//, $uri->path);
    my $photo_id = decode_base58( $args[-1] );

    return qq{http://www.flickr.com/photos/$userid/$photo_id/};
}

sub makeashorterlink {
    my ($orig_uri) = @_;

    my $uri = URI->new($orig_uri);
    my @args = split(/\//, $uri->path);
    my $encoded_id = encode_base58( $args[-1] );
    
    return qq{http://flic.kr/p/$encoded_id};
}

1;

__END__

=head1 NAME

Plagger::Plugin::Filter::Flicdotkr - convert URL by flic.kr

=head1 SYNOPSIS

  - module: Filter::Flicdotkr
    config:
      be: long
      userid: YOUR_ID

=head1 DESCRIPTION

This plugin replaces URL with flic.kr or flic.kr with OriginalURL.

=head1 CONFIG

=over 4

=item text_only

When set to 1, uses HTML::Parser to avoid replacing URL inside
HTML attributes. Defaults to 0.

=item be

When set to long, flic.kr extracted to Original URL.
When set to short, URL converted into flic.kr.

=item userid

Flickr user's NSID (the number with the '@' sign in it) or their
custom URL (if they've chosen one).

If you set "be" is long, it is required.

=back

=head1 AUTHOR

poppen

Tatsuhiko Miyagawa

=head1 SEE ALSO

L<Plagger>, L<HTML::Parser>

=cut
