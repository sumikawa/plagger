package Plagger::Plugin::Filter::Flicdotkr;
use strict;
use base qw( Plagger::Plugin::Filter::Base );

use URI::Find;
use WWW::Shorten::Flickr;

sub filter {
    my ( $self, $body ) = @_;

    my $count = 0;

    my $finder = URI::Find->new(
        sub {
            my ( $uri, $orig_uri ) = @_;
            if ( $uri =~ /flic\.kr\/p\/\w+/ ) {
                $count++;
                return WWW::Shorten::Flickr::makealongerlink($uri);
            }
            elsif ( $uri =~ /www\.flickr\.com\/photos\/\w+\/\d+/ ) {
                $count++;
                return WWW::Shorten::Flickr::makeashorterlink($uri);
            }
            else {
                return $orig_uri;
            }
        }
    );

    $finder->find( \$body );
    ( $count, $body );
}

1;

__END__

=head1 NAME

Plagger::Plugin::Filter::Flicdotkr - convert URL by flic.kr

=head1 SYNOPSIS

  - module: Filter::Flicdotkr

=head1 DESCRIPTION

This plugin replaces URL with flic.kr or flic.kr with OriginalURL.

=head1 CONFIG

=over 4

=item text_only

When set to 1, uses HTML::Parser to avoid replacing URL inside
HTML attributes. Defaults to 0.

=back

=head1 AUTHOR

poppen

Tatsuhiko Miyagawa

=head1 SEE ALSO

L<Plagger>, L<HTML::Parser>

=cut
