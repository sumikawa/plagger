package Plagger::Plugin::Filter::RewriteEnclosureURL2;
use strict;
use base qw( Plagger::Plugin );

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

    $self->conf->{rewrite} or Plagger->context->error("config 'rewrite' is not set.");
    $self->conf->{rewrite} = [ $self->conf->{rewrite} ] unless ref $self->conf->{rewrite};
}

sub filter {
    my($self, $context, $args) = @_;

    for my $enclosure ($args->{entry}->enclosures) {
      for my $rewrite (@{ $self->conf->{rewrite} }) {
        $context->log(info => "enclosure URL before set to " . $enclosure->url);
        my $url = $enclosure->url;
        $url =~ s/^$rewrite->{local}/$rewrite->{url}/;
        $enclosure->url($url);
        $context->log(info => "enclosure URL set to " . $enclosure->url);
        }
    }
}

1;

__END__

=head1 NAME

Plagger::Plugin::Filter::RewriteEnclosureURL - Rewrite enclosure URL for republishing

=head1 SYNOPSIS

  - module: Filter::FetchEnclosure
    config:
      dir: /home/miyagawa/public_html

  - module: Filter::RewriteEnclosureURL
    config:
      rewrite:
        - local: /home/miyagawa/public_html/
          url:   http://rock/~miyagawa/

=head1 DESCRIPTION

This plugin rewrites enclosure URL using rewrite rule.

=head1 CONFIG

=over 4

=item rewrite

List of hash that defines rule to rewrite URL. C<local> to represent
local path, which should match with enclosure's local_path and C<url>
to represent publicly accessible HTTP base URL.

In this example, I</home/miyagawa/public_html/foo.mp3> is rewritten to
I<http://rock/~miyagawa/foo.mp3>.

=back

=head1 AUTHOR

Tatsuhiko Miyagawa

=head1 SEE ALSO

L<Plagger>

=cut

