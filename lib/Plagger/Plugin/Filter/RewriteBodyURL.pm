package Plagger::Plugin::Filter::RewriteBodyURL;
use strict;
use base qw( Plagger::Plugin );
use Encode;

use HTML::Entities;

sub register {
    my($self, $context) = @_;
    $context->register_hook(
        $self,
        'update.entry.fixup' => \&filter,
    );
}

sub init {
    my $self = shift;
    $self->SUPER::init(@_);
}

sub filter {
    my($self, $context, $args) = @_;

    my $entry = $args->{entry};

    my %url2enclosure = map { $_->url => $_ } $entry->enclosures;

    my $output;
    my $p = HTML::Parser->new(api_version => 3);
    $p->handler( default => sub { $output .= $_[0] }, "text" );
    $p->handler( start => sub {
	my($tag, $attr, $attrseq, $text) = @_;

	if (my $url = $attr->{src}) {
	    if (my $enclosure = $url2enclosure{$url}) {
		$attr->{src} = $enclosure->local_path;
	    }
	    $output .= $self->generate_tag($tag, $attr, $attrseq);
	} else {
	    $output .= $text;
	}
		 }, "tag, attr, attrseq, text");

    $p->parse($entry->body);
    $p->eof;
    $entry->body($output);
}

sub generate_tag {
    my($self, $tag, $attr, $attrseq) = @_;

    return "<$tag " .
        join(' ', map { $_ eq '/' ? '/' : sprintf qq(%s="%s"), $_, encode_entities($attr->{$_}, q(<>"')) } @$attrseq) .
        '>';
}

1;

__END__

=head1 NAME

Plagger::Plugin::Filter::RewriteBodyURL - Rewrite URL of entry body to Enclosure local_path

=head1 SYNOPSIS

  - module: Filter::RewriteBodyURL

=head1 DESCRIPTION

=head1 AUTHOR

TERAMOTO Masahiro

=head1 SEE ALSO

L<Plagger>, L<HTML::Parser>

=cut
