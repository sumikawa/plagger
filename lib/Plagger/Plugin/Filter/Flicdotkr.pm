package Plagger::Plugin::Filter::Flicdotkr;
use strict;
use base qw( Plagger::Plugin::Filter::Base );

use URI::Find;
use Encode::Base58;

sub filter {
    my($self, $body) = @_;

    my $count = 0;
    my $opt = $self->conf->{be} || 'short';
    my $userid = $self->conf->{userid} || '';

    my $finder = URI::Find->new(sub {
        my ($uri, $orig_uri) = @_;
        if ($opt eq 'long' && $uri =~ /flic\.kr\/p\/(\w+)/) {
            $count++;
            my $photo_id = decode_base58($1);
            return qq{http://www.flickr.com/photos/$userid/$photo_id/};
        }
        elsif ($opt eq 'short' && $uri =~ /www\.flickr\.com\/photos\/\w+\/(\d+)/) {
            $count++;
            my $encoded_id = encode_base58($1);
            return qq{http://flic.kr/p/$encoded_id};
        }
        else {
            return $orig_uri;
        }
    });

    $finder->find(\$body);
    ($count, $body);
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
